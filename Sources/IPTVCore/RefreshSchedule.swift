import Foundation

public enum RefreshSchedule {
    /// Auto refresh of the playlists. `hours` 0 = only when the app opens (never due here). No previous sync, or a clock that
    /// jumped back, counts as due.
    public static func isDue(hours: Int, lastSync: Date?, now: Date) -> Bool {
        guard hours > 0 else { return false }
        guard let last = lastSync else { return true }
        let elapsed = now.timeIntervalSince(last)
        return elapsed < 0 || elapsed >= Double(hours) * 3600
    }
}
