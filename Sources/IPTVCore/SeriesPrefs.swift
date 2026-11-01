import Foundation
import GRDB

/// What the user chose while watching one series, kept for its next episodes: the playback speed and the subtitle language.
/// (A new episode of a series would otherwise start at normal speed with the provider's default subtitles.)
public struct SeriesPrefs: Equatable, Sendable {
    /// nil: normal speed.
    public var speed: Double?
    /// nil: the user never chose; the player's own defaults apply.
    public var subtitle: SubtitleChoice?

    public init(speed: Double? = nil, subtitle: SubtitleChoice? = nil) { self.speed = speed; self.subtitle = subtitle }

    public var isEmpty: Bool { speed == nil && subtitle == nil }
}

public enum SubtitleChoice: Equatable, Sendable {
    case off
    /// The language of the track, as the player reports it ("eng", "heb"), or its title when it has no language.
    case language(String)

    var stored: String {
        switch self { case .off: return "off"; case .language(let l): return "lang:\(l)" }
    }

    init?(stored: String?) {
        guard let s = stored else { return nil }
        if s == "off" { self = .off } else if s.hasPrefix("lang:"), s.count > 5 { self = .language(String(s.dropFirst(5))) } else { return nil }
    }

    /// The choice that picking `track` (nil = "off") stands for.
    public static func of(lang: String?, title: String?) -> SubtitleChoice? {
        if let l = lang?.trimmingCharacters(in: .whitespaces), !l.isEmpty { return .language(l.lowercased()) }
        if let t = title?.trimmingCharacters(in: .whitespaces), !t.isEmpty { return .language(t.lowercased()) }
        return nil
    }
}

/// What to do with the subtitles of a new episode.
public enum SubtitleAction: Equatable, Sendable {
    case off
    case track(Int)
}

public enum SeriesPrefsLogic {
    /// The subtitle track of this episode that matches the saved choice, or "off". Nil when the choice is not there (the series has no
    /// track in that language in this episode): the player's default stays. `tracks` are the subtitle tracks only.
    public static func action(for choice: SubtitleChoice?, tracks: [(id: Int, lang: String?, title: String?)]) -> SubtitleAction? {
        switch choice {
        case nil: return nil
        case .off?: return .off
        case .language(let wanted)?:
            let w = wanted.lowercased()
            if let t = tracks.first(where: { $0.lang?.lowercased() == w }) { return .track(t.id) }
            if let t = tracks.first(where: { $0.title?.lowercased() == w }) { return .track(t.id) }
            return nil
        }
    }
}

extension UserData {
    public static func seriesPrefs(_ db: Database, accountId: Int64, seriesId: String) throws -> SeriesPrefs {
        guard let r = try Row.fetchOne(db, sql: "SELECT speed, subtitle FROM series_prefs WHERE accountId=? AND seriesId=?", arguments: [accountId, seriesId]) else { return SeriesPrefs() }
        return SeriesPrefs(speed: r["speed"], subtitle: SubtitleChoice(stored: r["subtitle"]))
    }

    /// Empty preferences remove the row.
    public static func saveSeriesPrefs(_ db: Database, accountId: Int64, seriesId: String, prefs: SeriesPrefs) throws {
        if prefs.isEmpty {
            try db.execute(sql: "DELETE FROM series_prefs WHERE accountId=? AND seriesId=?", arguments: [accountId, seriesId])
            return
        }
        try db.execute(sql: """
            INSERT INTO series_prefs (accountId, seriesId, speed, subtitle) VALUES (?,?,?,?)
            ON CONFLICT(accountId, seriesId) DO UPDATE SET speed=excluded.speed, subtitle=excluded.subtitle
            """, arguments: [accountId, seriesId, prefs.speed, prefs.subtitle?.stored])
    }
}
