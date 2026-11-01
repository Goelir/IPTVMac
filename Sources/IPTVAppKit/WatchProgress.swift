import Foundation
import GRDB
import IPTVCore

/// A title that can be resumed, with how far along it is (and, for a series, the episode that was last watched).
public struct ContinueEntry: Identifiable, Equatable {
    public var item: Item
    public var fraction: Double?                     // 0...1, nil when unknown
    public var season: Int?, episode: Int?
    /// For a series: the episode that was left (stream id and title), so the entry resumes it, and where in it.
    public var episodeId: String?
    public var episodeTitle: String?
    public var position: Double?, duration: Double?
    public var id: Int64? { item.id }

    public init(item: Item, fraction: Double? = nil, season: Int? = nil, episode: Int? = nil,
                episodeId: String? = nil, episodeTitle: String? = nil, position: Double? = nil, duration: Double? = nil) {
        self.item = item; self.fraction = fraction; self.season = season; self.episode = episode
        self.episodeId = episodeId; self.episodeTitle = episodeTitle; self.position = position; self.duration = duration
    }

    /// Seconds still to watch, when the length is known.
    public var secondsLeft: Double? {
        guard let p = position, let d = duration, d > 0 else { return nil }
        return max(d - p, 0)
    }
}

extension ContinueEntry {
    /// "S2 E5 · 23 min left": where the title was left. The three formats are the platform's localized strings
    /// ("S%d E%d", "%@ left", "%d min"). Nil when nothing is known.
    public func caption(episode: String, left: String, minutes: String) -> String? {
        let ep = season.flatMap { s in self.episode.map { String(format: episode, s, $0) } }
        let time = secondsLeft.map { String(format: left, String(format: minutes, max(1, Int(($0 / 60).rounded(.up))))) }
        let line = [ep, time].compactMap { $0 }.joined(separator: " · ")
        return line.isEmpty ? nil : line
    }
}

public struct EpisodeProgress: Equatable {
    public var position: Double, duration: Double
    public var rank: Int                             // 0 = watched longest ago; the highest rank is the latest
    public var fraction: Double { duration > 0 ? min(max(position / duration, 0), 1) : 0 }
    public var isWatched: Bool { fraction > 0.95 }
}

public enum WatchProgress {
    /// The continue-watching list of one type with progress, newest first (the shelf shows the first `limit`).
    public static func continueEntries(_ db: Database, accountId: Int64?, type: ItemType, limit: Int = 20) throws -> [ContinueEntry] {
        try UserData.continueWatching(db, accountId: accountId, type: type).prefix(limit).map { item in
            if type == .series, let r = try Row.fetchOne(db, sql: """
                SELECT h.position, h.duration, e.season, e.number, e.streamId AS epId, e.title AS epTitle FROM history h
                JOIN episode e ON e.accountId = h.accountId AND h.streamId = 'ep:' || e.streamId
                WHERE e.accountId = ? AND e.seriesId = ? AND h.type = 'series' ORDER BY h.updated DESC, h.rowid DESC LIMIT 1
                """, arguments: [item.accountId, item.streamId]) {
                return ContinueEntry(item: item, fraction: fraction(r["position"], r["duration"]), season: r["season"], episode: r["number"],
                                     episodeId: r["epId"], episodeTitle: r["epTitle"], position: r["position"], duration: r["duration"])
            }
            let r = try Row.fetchOne(db, sql: "SELECT position, duration FROM history WHERE accountId = ? AND type = ? AND streamId = ?",
                                     arguments: [item.accountId, item.type.rawValue, item.streamId])
            return ContinueEntry(item: item, fraction: r.flatMap { fraction($0["position"], $0["duration"]) }, position: r?["position"], duration: r?["duration"])
        }
    }

    private static func fraction(_ p: Double, _ d: Double) -> Double? { d > 0 ? min(max(p / d, 0), 1) : nil }

    /// The episodes of a series that the app has already fetched (opening the series caches them), in watching order.
    public static func cachedEpisodes(_ db: Database, accountId: Int64, seriesId: String) throws -> [Episode] {
        try Episode.fetchAll(db, sql: "SELECT * FROM episode WHERE accountId = ? AND seriesId = ? ORDER BY season, number", arguments: [accountId, seriesId])
    }

    /// Resume points of a series' episodes, keyed by the episode's stream id.
    public static func episodeProgress(_ db: Database, accountId: Int64) throws -> [String: EpisodeProgress] {
        let rows = try Row.fetchAll(db, sql: """
            SELECT streamId, position, duration FROM history WHERE accountId = ? AND type = 'series' AND streamId LIKE 'ep:%' ORDER BY updated, rowid
            """, arguments: [accountId])
        var out: [String: EpisodeProgress] = [:]
        for (i, r) in rows.enumerated() {
            let sid: String = r["streamId"]
            out[String(sid.dropFirst(3))] = EpisodeProgress(position: r["position"], duration: r["duration"], rank: i)
        }
        return out
    }

    /// What the series screen offers first: the episode left halfway (resume), else the one after the last finished, else the first.
    /// nil once every episode up to the last one is watched.
    public static func upNext(_ episodes: [Episode], progress: [String: EpisodeProgress]) -> (episode: Episode, resume: Bool)? {
        let ordered = episodes.sorted { ($0.season, $0.number) < ($1.season, $1.number) }
        guard let first = ordered.first else { return nil }
        let seen = ordered.compactMap { e in progress[e.streamId].map { (e, $0) } }
        guard let (last, p) = seen.max(by: { $0.1.rank < $1.1.rank }) else { return (first, false) }
        if !p.isWatched && p.position >= 5 { return (last, true) }
        return EpisodeQueue.next(after: last.streamId, in: ordered).map { ($0, false) }
    }
}
