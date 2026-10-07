/// Decides when the window may be toggled in or out of full screen. AppKit silently drops a toggle issued while a transition
/// runs (and while a sheet is closing or the window is minimized/hidden), and `styleMask.fullScreen` is stale during one,
/// so a request is kept until the window can take it and is judged against the state at that moment.
public struct FullscreenSync: Sendable {
    private var wanted: Bool?
    public private(set) var busy = false
    private var entered = false                      // we leave only the full screen we entered ourselves

    public init() {}

    public mutating func want(_ on: Bool) { wanted = on }
    public mutating func transitionStarted() { busy = true }
    public mutating func transitionEnded(isFull: Bool) { busy = false; if !isFull { entered = false } }
    /// The window is gone: nothing it was doing applies to the next one.
    public mutating func reset() { self = FullscreenSync() }

    /// True when the caller must call `toggleFullScreen` now (the transition is then marked as running).
    public mutating func next(isFull: Bool, ready: Bool) -> Bool {
        guard let on = wanted, ready, !busy else { return false }
        wanted = nil
        guard on != isFull, on || entered else { return false }
        entered = on; busy = true
        return true
    }
}
