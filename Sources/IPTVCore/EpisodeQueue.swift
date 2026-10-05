import Foundation

public enum EpisodeQueue {
    /// The episode that follows `streamId` in watching order (season, then episode number), or nil after the last one.
    public static func next(after streamId: String, in episodes: [Episode]) -> Episode? {
        let ordered = episodes.sorted { ($0.season, $0.number) < ($1.season, $1.number) }
        guard let i = ordered.firstIndex(where: { $0.streamId == streamId }), i + 1 < ordered.count else { return nil }
        return ordered[i + 1]
    }
}
