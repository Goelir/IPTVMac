import Foundation
import Testing
import GRDB
@testable import IPTVCore

/// An Xtream playlist ("t", http://h, u) and an M3U one with a favorite and a resume point each.
private func seeded() throws -> (db: AppDatabase, xtream: Int64, m3u: Int64) {
    let (db, x) = try makeDB()
    let m = try addAccount(db, "list")
    try db.dbQueue.write { d in
        _ = try UserData.toggleFavorite(d, accountId: x, type: .live, streamId: "7")
        _ = try UserData.toggleFavorite(d, accountId: m, type: .movie, streamId: "http://h/m.mp4")
        try UserData.saveProgress(d, accountId: x, type: .movie, streamId: "9", position: 120, duration: 600)
        try UserData.saveProgress(d, accountId: m, type: .series, streamId: "ep:3", position: 30, duration: 100)
    }
    return (db, x, m)
}

private func snapshot(_ db: AppDatabase) throws -> Backup { try db.dbQueue.read { try Backup.make($0) } }
private func accountCount(_ db: AppDatabase) throws -> Int { try db.dbQueue.read { try Account.fetchCount($0) } }
private func tmp(_ name: String) -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("iptvmac-\(UUID().uuidString)-\(name)") }

@Test func backupRoundTripsPlaylistsFavoritesAndHistoryIntoAFreshDatabase() throws {
    let (src, _, _) = try seeded()
    let data = try snapshot(src).encoded()
    let restored = try Backup.decode(data)
    let dst = try AppDatabase()
    let added = try dst.dbQueue.write { try restored.merge(into: $0) }
    #expect(added.count == 2)
    let b = try snapshot(dst)
    #expect(b.playlists.map(\.name) == ["t", "list"])
    #expect(b.playlists[0].kind == .xtream && b.playlists[0].server == "http://h" && b.playlists[0].username == "u")
    #expect(b.playlists[1].kind == .m3u && b.playlists[1].url == "http://h/list.m3u")
    #expect(b.playlists.map(\.favorites) == restored.playlists.map(\.favorites))
    #expect(b.playlists[0].favorites == [.init(type: .live, streamId: "7")])
    #expect(b.playlists[0].history.map(\.streamId) == ["9"] && b.playlists[0].history[0].position == 120 && b.playlists[0].history[0].duration == 600)
    #expect(b.playlists[1].history.map(\.streamId) == ["ep:3"])
}

@Test func importingTheSameBackupAgainAddsNothing() throws {
    let (src, _, _) = try seeded()
    let backup = try Backup.decode(snapshot(src).encoded())
    let dst = try AppDatabase()
    for _ in 0..<2 { _ = try dst.dbQueue.write { try backup.merge(into: $0) } }
    #expect(try accountCount(dst) == 2)
    #expect(try snapshot(dst).playlists.map(\.favorites.count) == [1, 1])
    #expect(try snapshot(dst).playlists.map(\.history.count) == [1, 1])
    let again = try src.dbQueue.write { try backup.merge(into: $0) }       // into the database it came from
    #expect(again.isEmpty)
    #expect(try accountCount(src) == 2)
}

@Test func importMatchesAnExistingPlaylistBySourceAndMergesItsUserData() throws {
    let (src, _, _) = try seeded()
    var backup = try Backup.decode(snapshot(src).encoded())
    backup.playlists[0].name = "Renamed"; backup.playlists[0].server = "HTTP://H/"           // same server, typed differently
    backup.playlists[0].favorites.append(.init(type: .live, streamId: "8"))
    let (dst, x) = try makeDB()
    try dst.dbQueue.write { d in _ = try UserData.toggleFavorite(d, accountId: x, type: .live, streamId: "1") }
    let added = try dst.dbQueue.write { try backup.merge(into: $0) }
    #expect(added.map(\.name) == ["list"])                                    // the Xtream playlist was matched, the M3U one is new
    let b = try snapshot(dst)
    #expect(b.playlists.map(\.name) == ["t", "list"])                         // the existing playlist keeps its name
    #expect(b.playlists[0].favorites.map(\.streamId) == ["1", "7", "8"])      // merged, nothing lost
}

@Test func importKeepsTheNewerResumePoint() throws {
    let (db, a) = try makeDB()
    let day = Date(timeIntervalSince1970: 1_800_000_000)
    func backup(_ pos: Double, _ updated: Date) -> Backup {
        Backup(playlists: [.init(name: "t", kind: .xtream, server: "http://h", username: "u", url: nil, favorites: [],
                                 history: [.init(type: .movie, streamId: "9", position: pos, duration: 600, updated: updated)])])
    }
    try db.dbQueue.write { d in
        try backup(100, day).merge(into: d)
        try backup(50, day.addingTimeInterval(-86400)).merge(into: d)         // older: ignored
    }
    #expect(try db.dbQueue.read { try UserData.progress($0, accountId: a, type: .movie, streamId: "9") } == 100)
    _ = try db.dbQueue.write { try backup(300, day.addingTimeInterval(86400)).merge(into: $0) }
    #expect(try db.dbQueue.read { try UserData.progress($0, accountId: a, type: .movie, streamId: "9") } == 300)
}

@Test func backupNeverContainsPasswords() throws {
    let (db, x, _) = try seeded()
    try DatabaseSecretStore(db: db).setPassword("s3cr3t-pw", for: x)
    let data = try snapshot(db).encoded()
    #expect(!String(decoding: data, as: UTF8.self).contains("s3cr3t-pw"))
    let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(Set(root.keys) == ["version", "created", "playlists"])
    let p = try #require((root["playlists"] as? [[String: Any]])?.first)
    #expect(Set(p.keys) == ["name", "kind", "server", "username", "favorites", "history"])     // no password, no url for Xtream
}

@Test func garbageEmptyAndWrongShapedFilesAreRejected() throws {
    for bad in ["not json", "", "[]", "{}", #"{"version":1}"#, #"{"version":1,"created":"x","playlists":[{"name":"a"}]}"#] {
        #expect(throws: BackupError.invalid) { try Backup.decode(Data(bad.utf8)) }
    }
}

@Test func otherVersionsAreRejected() throws {
    for v in [0, 2, 99, -1] {
        let json = #"{"version":\#(v),"created":"2026-10-07T10:00:00Z","playlists":[]}"#
        #expect(throws: BackupError.unsupportedVersion) { try Backup.decode(Data(json.utf8)) }
    }
}

@Test func oversizedFilesAreRejectedBeforeParsing() throws {
    let data = try snapshot(try seeded().db).encoded()
    #expect(throws: BackupError.tooLarge) { try Backup.decode(data, maxBytes: data.count - 1) }
    _ = try Backup.decode(data, maxBytes: data.count)
    let big = tmp("big.json")
    defer { try? FileManager.default.removeItem(at: big) }
    try Data(count: Backup.maxBytes + 1).write(to: big)
    #expect(throws: BackupError.tooLarge) { try Backup.read(from: big) }
}

@Test func playlistsWithUnsafeOrMissingSourcesAreRejected() throws {
    func decode(_ p: Backup.Playlist) throws { _ = try Backup.decode(Backup(playlists: [p]).encoded()) }
    func list(_ url: String?) -> Backup.Playlist { .init(name: "a", kind: .m3u, server: nil, username: nil, url: url, favorites: [], history: []) }
    try decode(list("https://h/a.m3u"))
    let bad: [String?] = ["file:///etc/passwd", "file://localhost/etc/hosts", "ftp://h/a.m3u", "h/a.m3u", "", nil]
    for u in bad { #expect(throws: BackupError.invalid) { try decode(list(u)) } }
    #expect(throws: BackupError.invalid) { try decode(.init(name: "x", kind: .xtream, server: nil, username: "u", url: nil, favorites: [], history: [])) }
    #expect(throws: BackupError.invalid) { try decode(.init(name: "x", kind: .xtream, server: "file:///x", username: "u", url: nil, favorites: [], history: [])) }
    try decode(.init(name: "x", kind: .xtream, server: "host.example:8080", username: "u", url: nil, favorites: [], history: []))
}

@Test func exportedFileIsOwnerOnlyAndOverwritesCompletely() throws {
    let backup = try snapshot(try seeded().db)
    let url = tmp("backup.json")
    defer { try? FileManager.default.removeItem(at: url) }
    try Data(repeating: 65, count: 1_000_000).write(to: url)                 // an existing, longer, world-readable file
    try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
    try backup.write(to: url)
    let perms = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
    #expect(perms == 0o600)
    #expect(try Backup.read(from: url) == backup)
    #expect(try Data(contentsOf: url) == backup.encoded())                  // no tail of the old, longer file
}
