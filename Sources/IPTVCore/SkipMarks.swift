import Foundation
import GRDB

/// Where the intro and the credits of a series are, as the user marked them once (providers do not publish this). The marks belong to
/// the series, so every episode of it offers the skip buttons at the same places.
public struct SkipMarks: Equatable, Sendable {
    /// Seconds from the start of an episode where the intro begins (nil: at the very start) and where the real content begins.
    public var introStart: Double?
    public var introEnd: Double?
    /// Seconds before the end of an episode where the credits begin (the length of the credits, so it also fits episodes of other lengths).
    public var creditsLen: Double?

    public init(introStart: Double? = nil, introEnd: Double? = nil, creditsLen: Double? = nil) {
        self.introStart = introStart; self.introEnd = introEnd; self.creditsLen = creditsLen
    }

    public var isEmpty: Bool { introStart == nil && introEnd == nil && creditsLen == nil }
}

/// What the player offers at this moment.
public enum SkipOffer: Equatable, Sendable {
    /// "Skip intro": seek to this second.
    case intro(to: Double)
    /// "Skip credits": go to the next episode, or to the end when there is none.
    case credits
}

public enum SkipLogic {
    /// The button to show at `position`, if any. `duration` is 0 while it is unknown.
    public static func offer(_ m: SkipMarks, position: Double, duration: Double) -> SkipOffer? {
        guard position.isFinite, position >= 0 else { return nil }
        if let end = m.introEnd, end > 1 {
            let start = m.introStart ?? 0
            if position >= start && position < end - 1 && (duration <= 0 || end < duration * 0.6) { return .intro(to: end) }
        }
        if let len = m.creditsLen, len >= 5, duration > 0, len <= duration * 0.5,
           position >= duration - len, position < duration - 2 { return .credits }
        return nil
    }

    /// Marking "the intro starts here". An intro end that is no longer after it is dropped. Always accepted in the first half.
    public static func markIntroStart(_ m: SkipMarks, position: Double, duration: Double) -> SkipMarks? {
        guard position >= 0, duration <= 0 || position < duration * 0.5 else { return nil }
        var n = m
        n.introStart = position < 1 ? nil : position
        if let e = n.introEnd, e <= position + 2 { n.introEnd = nil }
        return n
    }

    /// Marking "the intro ends here": after its start, and not past the middle of the episode.
    public static func markIntroEnd(_ m: SkipMarks, position: Double, duration: Double) -> SkipMarks? {
        guard position > (m.introStart ?? 0) + 2, duration <= 0 || position < duration * 0.6 else { return nil }
        var n = m
        n.introEnd = position
        return n
    }

    /// Marking "the credits start here": at least 5 seconds before the end, and not in the first half.
    public static func markCredits(_ m: SkipMarks, position: Double, duration: Double) -> SkipMarks? {
        guard duration > 0, position >= duration * 0.5, duration - position >= 5 else { return nil }
        var n = m
        n.creditsLen = duration - position
        return n
    }
}

extension UserData {
    public static func skipMarks(_ db: Database, accountId: Int64, seriesId: String) throws -> SkipMarks {
        guard let r = try Row.fetchOne(db, sql: "SELECT introStart, introEnd, creditsLen FROM series_marks WHERE accountId=? AND seriesId=?",
                                       arguments: [accountId, seriesId]) else { return SkipMarks() }
        return SkipMarks(introStart: r["introStart"], introEnd: r["introEnd"], creditsLen: r["creditsLen"])
    }

    /// An empty set of marks removes the row.
    public static func saveSkipMarks(_ db: Database, accountId: Int64, seriesId: String, marks: SkipMarks) throws {
        if marks.isEmpty {
            try db.execute(sql: "DELETE FROM series_marks WHERE accountId=? AND seriesId=?", arguments: [accountId, seriesId])
            return
        }
        try db.execute(sql: """
            INSERT INTO series_marks (accountId, seriesId, introStart, introEnd, creditsLen) VALUES (?,?,?,?,?)
            ON CONFLICT(accountId, seriesId) DO UPDATE SET introStart=excluded.introStart, introEnd=excluded.introEnd, creditsLen=excluded.creditsLen
            """, arguments: [accountId, seriesId, marks.introStart, marks.introEnd, marks.creditsLen])
    }
}
