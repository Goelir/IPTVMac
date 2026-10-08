import Foundation
import GRDB

/// What the provider says about a movie or series (`get_vod_info` / `get_series_info`). The server is untrusted: text is plain,
/// length-capped and stripped of control characters, images pass `RemoteImage.safeURL`, the trailer is only a YouTube video id.
public struct ItemInfo: Codable, Equatable, Sendable {
    public var title: String?
    public var plot: String?
    public var cast: String?
    public var director: String?
    public var genre: String?
    public var country: String?
    public var releaseDate: String?
    public var year: Int?
    /// 0...10 (nil when the provider has none; panels send 0 or "" for "unrated").
    public var rating: Double?
    public var durationMinutes: Int?
    public var trailerID: String?
    public var posterURL: URL?
    public var backdropURL: URL?

    public init() {}

    /// Anything worth a details page. Images do not count: the list already shows the poster.
    public var hasContent: Bool {
        plot != nil || cast != nil || director != nil || genre != nil || country != nil || year != nil
            || rating != nil || durationMinutes != nil || trailerID != nil
    }

    /// Always built by us from the validated id, never taken from the provider.
    public var trailerURL: URL? {
        guard let id = trailerID, Self.isVideoID(id) else { return nil }
        return URL(string: "https://www.youtube.com/watch?v=" + id)
    }

    static func isVideoID(_ s: String) -> Bool { s.range(of: #"^[A-Za-z0-9_-]{6,20}\z"#, options: .regularExpression) != nil }

    /// `response` is the whole answer; the details sit under `info` (a panel with nothing sends `"info": []`).
    public init(response: [String: Any]) {
        guard let d = response["info"] as? [String: Any] else { return }
        func pick<T>(_ keys: [String], _ f: (Any?) -> T?) -> T? {
            for k in keys { if let r = f(d[k]) { return r } }
            return nil
        }
        func text(_ keys: [String], _ max: Int) -> String? { pick(keys) { Self.text($0, max) } }
        title = text(["name", "o_name"], 300)
        plot = text(["plot", "description"], 4000)
        cast = text(["cast", "actors"], 500)
        director = text(["director"], 200)
        genre = text(["genre"], 200)
        country = text(["country"], 100)
        if let (s, y) = pick(["releasedate", "release_date", "releaseDate", "year"], { Self.date($0) }) { releaseDate = s; year = y }
        rating = Self.rating(d)
        durationMinutes = Self.minutes(d)
        trailerID = pick(["youtube_trailer"]) { Self.trailer($0) }
        posterURL = Self.image(["movie_image", "cover_big", "cover"], d)
        backdropURL = Self.image(["backdrop_path", "backdrop"], d)
    }

    // MARK: Tolerant readers (strings, numbers, arrays, null, booleans: whatever the panel sent)

    private static func string(_ v: Any?) -> String? {
        if let n = v as? NSNumber, CFGetTypeID(n) == CFBooleanGetTypeID() { return nil }
        if let a = v as? [Any] { return a.prefix(50).compactMap(string).joined(separator: ", ") }
        return str(v).map { String($0.prefix(20_000)) }      // a hostile value never costs more than this to read
    }

    /// Plain text only: no control or bidi-override characters, blank runs shortened, capped. Shown verbatim, never interpreted.
    static func text(_ v: Any?, _ max: Int) -> String? {
        guard let raw = string(v) else { return nil }
        var out = String.UnicodeScalarView()
        for u in String(raw.prefix(max * 4)).replacingOccurrences(of: "\r\n", with: "\n").unicodeScalars {
            switch u.value {
            case 0x0A, 0x09: out.append(u)
            case 0x0D, 0x2028, 0x2029: out.append("\n")
            case 0x202A...0x202E, 0x2066...0x2069: continue
            default: if u.properties.generalCategory != .control { out.append(u) }
            }
        }
        var s = String(out).trimmingCharacters(in: .whitespacesAndNewlines)
        while s.contains("\n\n\n") { s = s.replacingOccurrences(of: "\n\n\n", with: "\n\n") }
        if s.count > max { s = String(s.prefix(max - 1)).trimmingCharacters(in: .whitespacesAndNewlines) + "…" }
        return s.isEmpty ? nil : s
    }

    private static func firstNumber(_ s: String?) -> Double? {
        guard let s, let r = s.range(of: #"-?\d+(?:[.,]\d+)?"#, options: .regularExpression) else { return nil }
        return Double(s[r].replacingOccurrences(of: ",", with: "."))
    }

    private static func date(_ v: Any?) -> (String, Int)? {
        guard let s = text(v, 40), let r = s.range(of: #"(?<!\d)(?:18|19|20)\d{2}(?!\d)"#, options: .regularExpression), let y = Int(s[r]) else { return nil }
        return (s, y)
    }

    private static func rating(_ d: [String: Any]) -> Double? {
        func round1(_ x: Double) -> Double { (x * 10).rounded() / 10 }
        if let r = firstNumber(string(d["rating"])), r > 0, r <= 100 { return round1(r <= 10 ? r : r / 10) }   // a few panels use 0-100
        if let five = firstNumber(string(d["rating_5based"])), five > 0, five <= 5 { return round1(five * 2) }
        return nil
    }

    /// Minutes from seconds, "01:45:00", "105 min", "1h 45m" or a bare number (more than 600 is seconds). Over 24 h is a broken value.
    private static func minutes(_ d: [String: Any]) -> Int? {
        func ok(_ m: Double) -> Int? { m.isFinite && m >= 0.5 && m <= 1440 ? Int(m.rounded()) : nil }
        func count(_ pattern: String, _ s: String) -> Int? {
            guard let r = s.range(of: pattern, options: .regularExpression) else { return nil }
            return Int(s[r].filter(\.isNumber))
        }
        func parse(_ s: String) -> Int? {
            if s.contains(":") {
                let p = s.split(separator: ":", omittingEmptySubsequences: false).map { Double($0.trimmingCharacters(in: .whitespaces)) }
                guard p.count == 2 || p.count == 3, !p.contains(where: { $0 == nil }) else { return nil }
                let v = p.compactMap { $0 }
                return ok((v[0] * 3600 + v[1] * 60 + (v.count == 3 ? v[2] : 0)) / 60)
            }
            let h = count(#"\d+\s*h"#, s), m = count(#"\d+\s*m"#, s)
            if h != nil || m != nil { return ok(Double(h ?? 0) * 60 + Double(m ?? 0)) }
            guard let n = firstNumber(s) else { return nil }
            return ok(n > 600 ? n / 60 : n)
        }
        if let secs = firstNumber(string(d["duration_secs"])), let m = ok(secs / 60) { return m }
        return ["duration", "runtime", "episode_run_time"].lazy.compactMap { string(d[$0]).flatMap(parse) }.first
    }

    /// A video id, or a link to one on YouTube (from which only the id is kept).
    private static func trailer(_ v: Any?) -> String? {
        guard let s = string(v)?.trimmingCharacters(in: .whitespacesAndNewlines), s.count <= 300 else { return nil }
        if isVideoID(s) { return s }
        guard let c = URLComponents(string: s), ["http", "https"].contains(c.scheme?.lowercased() ?? ""),
              let host = c.host?.lowercased() else { return nil }
        let path = c.path.split(separator: "/").map(String.init)
        let id: String?
        switch host {
        case "youtu.be": id = path.first
        case "youtube.com", "www.youtube.com", "m.youtube.com":
            id = path == ["watch"] ? c.queryItems?.first { $0.name == "v" }?.value : (path.count == 2 && path[0] == "embed" ? path[1] : nil)
        default: id = nil
        }
        return id.flatMap { isVideoID($0) ? $0 : nil }
    }

    /// The first safe link among the fields; a value may be a string or an array (`backdrop_path`), possibly empty.
    private static func image(_ keys: [String], _ d: [String: Any]) -> URL? {
        func links(_ v: Any?) -> [String] {
            if let a = v as? [Any] { return a.prefix(20).flatMap(links) }
            return str(v).map { [$0] } ?? []
        }
        return keys.lazy.flatMap { links(d[$0]) }.compactMap(RemoteImage.safeURL).first
    }
}

/// The cache behind `SyncService.info`: parsed details per (playlist, type, stream id), valid for 14 days.
public enum ItemInfoStore {
    public static let ttl: TimeInterval = 14 * 86_400

    /// `maxAge: nil` also returns an expired copy (for when the network fails). A row that cannot be read counts as missing.
    public static func cached(_ db: Database, accountId: Int64, type: ItemType, streamId: String,
                              now: Date = Date(), maxAge: TimeInterval? = ttl) throws -> ItemInfo? {
        guard let row = try Row.fetchOne(db, sql: "SELECT json, fetched FROM item_info WHERE accountId=? AND type=? AND streamId=?",
                                         arguments: [accountId, type.rawValue, streamId]) else { return nil }
        let fetched: Date = row["fetched"]
        if let maxAge, now.timeIntervalSince(fetched) > maxAge { return nil }
        let json: String = row["json"]
        guard var info = try? JSONDecoder().decode(ItemInfo.self, from: Data(json.utf8)) else { return nil }
        // The row outlives the app version that wrote it: links and the video id are checked again, whatever the file says.
        info.posterURL = RemoteImage.safeURL(info.posterURL?.absoluteString)
        info.backdropURL = RemoteImage.safeURL(info.backdropURL?.absoluteString)
        if let id = info.trailerID, !ItemInfo.isVideoID(id) { info.trailerID = nil }
        return info
    }

    public static func save(_ db: Database, accountId: Int64, type: ItemType, streamId: String, info: ItemInfo, now: Date = Date()) throws {
        try db.execute(sql: "DELETE FROM item_info WHERE fetched < ?", arguments: [now.addingTimeInterval(-ttl)])   // titles nobody opens do not pile up
        let json = String(decoding: try JSONEncoder().encode(info), as: UTF8.self)
        try db.execute(sql: """
            INSERT INTO item_info (accountId,type,streamId,json,fetched) VALUES (?,?,?,?,?)
            ON CONFLICT(accountId,type,streamId) DO UPDATE SET json=excluded.json, fetched=excluded.fetched
            """, arguments: [accountId, type.rawValue, streamId, json, now])
    }
}
