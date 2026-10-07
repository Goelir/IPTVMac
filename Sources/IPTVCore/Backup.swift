import Foundation
import GRDB

public enum BackupError: Error, Equatable { case invalid, unsupportedVersion, tooLarge }

/// Playlists (no passwords: they stay in the private database), favorites and watch history as one JSON file.
/// Importing merges into what is already there.
public struct Backup: Codable, Equatable, Sendable {
    public static let version = 1
    public static let maxBytes = 10_000_000

    public var version: Int
    public var created: Date
    public var playlists: [Playlist]

    public struct Playlist: Codable, Equatable, Sendable {
        public var name: String
        public var kind: AccountKind
        public var server: String?, username: String?, url: String?
        public var favorites: [Favorite]
        public var history: [Watched]
    }
    public struct Favorite: Codable, Equatable, Sendable, FetchableRecord { public var type: ItemType; public var streamId: String }
    public struct Watched: Codable, Equatable, Sendable, FetchableRecord {
        public var type: ItemType; public var streamId: String
        public var position: Double, duration: Double
        public var updated: Date
    }

    init(playlists: [Playlist]) {
        version = Self.version
        created = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))     // the file stores whole seconds
        self.playlists = playlists
    }

    // MARK: Export

    public static func make(_ db: Database) throws -> Backup {
        Backup(playlists: try Account.order(Column("id")).fetchAll(db).map { a in
            Playlist(name: a.name, kind: a.kind, server: a.server, username: a.username, url: a.url,
                     favorites: try Favorite.fetchAll(db, sql: "SELECT type, streamId FROM favorite WHERE accountId = ? ORDER BY type, streamId", arguments: [a.id]),
                     history: try Watched.fetchAll(db, sql: "SELECT type, streamId, position, duration, updated FROM history WHERE accountId = ? ORDER BY type, streamId", arguments: [a.id]))
        })
    }

    public func encoded() throws -> Data {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try e.encode(self)
    }

    /// The file holds playlist addresses (an M3U link can carry a login): owner-only, never readable while the mode is still the default.
    public func write(to url: URL) throws {
        let data = try encoded()
        try Data().write(to: url)                                                   // creates or empties the file first
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        try data.write(to: url)                                                     // not atomic: keeps this file and its mode
    }

    // MARK: Import

    public static func read(from url: URL, maxBytes: Int = maxBytes) throws -> Backup {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int ?? 0
        guard size <= maxBytes else { throw BackupError.tooLarge }
        return try decode(Data(contentsOf: url), maxBytes: maxBytes)
    }

    /// A file from outside is untrusted: size, version, shape, and playlist addresses (an M3U link must be http(s), never file://).
    public static func decode(_ data: Data, maxBytes: Int = maxBytes) throws -> Backup {
        guard data.count <= maxBytes else { throw BackupError.tooLarge }
        struct Header: Decodable { var version: Int }
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        guard let header = try? d.decode(Header.self, from: data) else { throw BackupError.invalid }
        guard header.version == version else { throw BackupError.unsupportedVersion }
        guard let b = try? d.decode(Backup.self, from: data), b.playlists.allSatisfy(\.isValid) else { throw BackupError.invalid }
        return b
    }

    /// Playlists are matched by source (Xtream: server + username, M3U: link), else added. Favorites are added; a resume point
    /// is replaced only by a newer one. Returns the playlists that were added (they still need a sync, and an Xtream password).
    @discardableResult
    public func merge(into db: Database) throws -> [Account] {
        var known = try Account.fetchAll(db), added: [Account] = []
        for p in playlists {
            var account = known.first(where: p.isSource(of:))
            if account == nil {
                var a = p.kind == .xtream ? Account(name: p.name, kind: .xtream, server: p.server, username: p.username)
                                          : Account(name: p.name, kind: .m3u, url: p.url)
                try a.insert(db)
                known.append(a); added.append(a); account = a
            }
            guard let aid = account?.id else { continue }
            for f in p.favorites {
                try db.execute(sql: "INSERT OR IGNORE INTO favorite (accountId,type,streamId) VALUES (?,?,?)", arguments: [aid, f.type, f.streamId])
            }
            for h in p.history {
                try db.execute(sql: """
                    INSERT INTO history (accountId,type,streamId,position,duration,updated) VALUES (?,?,?,?,?,?)
                    ON CONFLICT(accountId,type,streamId) DO UPDATE SET position=excluded.position, duration=excluded.duration, updated=excluded.updated
                    WHERE excluded.updated > history.updated
                    """, arguments: [aid, h.type, h.streamId, h.position, h.duration, h.updated])
            }
        }
        return added
    }
}

private extension Backup.Playlist {
    var isValid: Bool {
        let source = kind == .xtream ? !(username ?? "").isEmpty && Self.web(server, bare: true) : Self.web(url, bare: false)
        return source && history.allSatisfy { $0.duration > 0 && $0.position >= 0 }
    }

    /// http(s) only. An Xtream server may be typed without a scheme (host:port); a playlist link may not.
    static func web(_ s: String?, bare: Bool) -> Bool {
        guard var t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return false }
        if bare && !t.contains("://") { t = "http://" + t }
        guard let u = URL(string: t) else { return false }
        return ["http", "https"].contains(u.scheme?.lowercased() ?? "") && u.host?.isEmpty == false
    }

    func isSource(of a: Account) -> Bool {
        guard a.kind == kind else { return false }
        func trim(_ s: String?) -> String { (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
        func server(_ s: String?) -> String { trim(s).trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased() }
        return kind == .xtream ? server(a.server) == server(self.server) && trim(a.username) == trim(username) : trim(a.url) == trim(url)
    }
}
