import Foundation

/// A deadline with injected time (the player polls it). Setting 0 minutes or fewer means Off.
public struct SleepTimer: Equatable {
    private var deadline: Date?
    public init() {}

    public var isActive: Bool { deadline != nil }
    public mutating func set(minutes: Int, now: Date) { deadline = minutes > 0 ? now.addingTimeInterval(Double(minutes) * 60) : nil }
    public mutating func cancel() { deadline = nil }

    /// Seconds left (never negative); nil when off.
    public func remaining(now: Date) -> TimeInterval? { deadline.map { max($0.timeIntervalSince(now), 0) } }
    /// Whole minutes left, rounded up, so "1" is shown until the very end; nil when off.
    public func remainingMinutes(now: Date) -> Int? { remaining(now: now).map { Int(($0 / 60).rounded(.up)) } }
    public func expired(now: Date) -> Bool { deadline.map { now >= $0 } ?? false }
}
