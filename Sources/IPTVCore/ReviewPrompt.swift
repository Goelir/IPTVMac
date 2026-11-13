import Foundation

/// When the iPhone and iPad app may ask for an App Store rating: only after real use (5 sessions of at least 5 minutes, at least
/// 3 days after the first launch), only after the player was closed, and at most once per app version. The system still decides
/// whether the dialog shows at all (at most 3 times a year, never when the user turned rating requests off).
public struct ReviewPrompt {
    public static let viewsNeeded = 5
    public static let minWatch: TimeInterval = 5 * 60
    public static let daysNeeded: TimeInterval = 3

    private let d: UserDefaults
    public init(defaults: UserDefaults = .standard) { d = defaults }

    var views: Int { d.integer(forKey: "review.views") }

    /// Called at every start; only the first one is kept.
    public func noteLaunch(now: Date = .now) {
        if d.object(forKey: "review.firstLaunch") == nil { d.set(now, forKey: "review.firstLaunch") }
    }

    /// The player was closed after `watched` seconds; from 5 minutes on it counts as a real view.
    public func notePlayback(watched: TimeInterval) {
        if watched >= Self.minWatch { d.set(views + 1, forKey: "review.views") }
    }

    /// True at most once per version, when the conditions hold; asking records the version.
    public func shouldAsk(version: String, now: Date = .now) -> Bool {
        guard views >= Self.viewsNeeded, d.string(forKey: "review.askedVersion") != version,
              let first = d.object(forKey: "review.firstLaunch") as? Date,
              now.timeIntervalSince(first) >= Self.daysNeeded * 86_400 else { return false }
        d.set(version, forKey: "review.askedVersion")
        return true
    }
}
