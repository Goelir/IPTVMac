import Foundation
import CoreGraphics
import CLibMPV

/// A second, hidden libmpv instance that only grabs small frames for the seek bar's hover preview.
/// It opens the same source as the player (a second connection for network sources: the app asks for it only when the user allows it),
/// does keyframe seeks and returns the frame as an image. All mpv work runs on its own serial queue, never on the caller's thread.
/// Requests are debounced and coalesced (only the newest time is processed), the engine opens on the first request and closes after
/// `idleClose` seconds without one. If the source cannot be opened within `loadTimeout`, `onFailure` is called once and the previewer stays off.
/// `onFrame` and `onFailure` are called on the previewer's queue and never after `shutdown()`.
public final class SeekPreviewer: @unchecked Sendable {
    private let source: String
    private let width: Int
    private let loadTimeout: TimeInterval
    private let idleClose: TimeInterval
    private let onFrame: @Sendable (Double, CGImage) -> Void
    private let onFailure: @Sendable () -> Void
    private let queue = DispatchQueue(label: "seek-previewer", qos: .userInitiated)

    private let lock = NSLock()                  // guards gate, stopped, failed and wakeHandle (shutdown() and request() come from other threads)
    private var gate: PreviewGate
    private var stopped = false
    private var failed = false
    private var wakeHandle: OpaquePointer?       // the live engine, for mpv_wakeup from shutdown(); cleared before the engine is destroyed
    private var engine: OpaquePointer?           // touched on `queue` only
    private var idle: DispatchWorkItem?          // queue only

    /// Engines created and not yet destroyed (test seam for leaks).
    nonisolated(unsafe) private static var live = 0
    private static let liveLock = NSLock()
    static var liveEngines: Int { liveLock.withLock { live } }
    private static func bump(_ d: Int) { liveLock.withLock { live += d } }

    public init(source: String, width: Int = 320, loadTimeout: TimeInterval = 8, debounce: TimeInterval = 0.12, idleClose: TimeInterval = 20,
                onFrame: @escaping @Sendable (Double, CGImage) -> Void, onFailure: @escaping @Sendable () -> Void) {
        self.source = source; self.width = width; self.loadTimeout = loadTimeout; self.idleClose = idleClose
        self.onFrame = onFrame; self.onFailure = onFailure
        gate = PreviewGate(debounce: debounce)
    }

    deinit { if let h = engine { Self.bump(-1); mpv_terminate_destroy(h) } }

    /// The newest wanted time wins; the frame arrives through `onFrame` a moment after the pointer stops.
    public func request(_ time: Double) {
        lock.lock(); defer { lock.unlock() }
        guard !stopped, !failed, time.isFinite else { return }
        if gate.want(max(0, time), now: Self.now) { schedule(after: gate.debounce) }
    }

    /// Stops for good and releases the engine on the previewer's queue (`wait`: until it is gone; never from `onFrame`, for tests).
    public func shutdown(wait: Bool = false) {
        lock.lock()
        stopped = true; gate.cancel()
        if let h = wakeHandle { mpv_wakeup(h) }      // a request that waits for mpv returns at once
        lock.unlock()
        if wait { queue.sync { closeEngine() } } else { queue.async { [self] in closeEngine() } }
    }

    /// Reads an option back from the live engine (nil without one).
    func optionValue(_ name: String) -> String? { queue.sync { engine.flatMap { property($0, name) } } }

    private func property(_ h: OpaquePointer, _ name: String) -> String? {
        guard let p = mpv_get_property_string(h, name) else { return nil }
        defer { mpv_free(p) }
        return String(cString: p)
    }

    // MARK: queue

    private static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
    private var isStopped: Bool { lock.withLock { stopped } }

    private func schedule(after s: TimeInterval) {
        queue.asyncAfter(deadline: .now() + s) { [weak self] in self?.wake() }
    }

    private func wake() {
        let action: PreviewGate.Action = lock.withLock { stopped || failed ? .idle : gate.wake(now: Self.now) }
        switch action {
        case .idle: break
        case .wait(let s): schedule(after: s)
        case .fire(let t): process(t)
        }
    }

    private func process(_ t: Double) {
        idle?.cancel(); idle = nil
        guard let h = openEngine() else { return }
        guard drain(h) else { return fail() }
        guard command(h, ["seek", String(t), "absolute+keyframes"]) >= 0 else { return }
        switch pump(h, timeout: loadTimeout, until: { $0 == MPV_EVENT_PLAYBACK_RESTART }) {
        case .done: break
        case .timeout, .stopped: return        // this frame is skipped; the next hover tries again
        case .failed: return fail()
        }
        guard let image = grab(h), !isStopped else { return }
        onFrame(t, image)
        guard idleClose > 0 else { return }
        let item = DispatchWorkItem { [weak self] in self?.closeEngine() }
        idle = item
        queue.asyncAfter(deadline: .now() + idleClose, execute: item)
    }

    private func openEngine() -> OpaquePointer? {
        if let e = engine { return e }
        guard !isStopped, let h = mpv_create() else { return nil }
        func opt(_ k: String, _ v: String) { mpv_set_option_string(h, k, v) }
        for (k, v) in EngineOptions.hardened { opt(k, v) }
        opt("network-timeout", String(max(1, Int(loadTimeout.rounded(.up)))))
        opt("vo", "null"); opt("ao", "null"); opt("aid", "no"); opt("sid", "no")
        opt("pause", "yes"); opt("hr-seek", "no"); opt("hwdec", "no"); opt("keep-open", "yes")
        opt("sub-auto", "no"); opt("audio-file-auto", "no"); opt("osd-level", "0")
        opt("demuxer-max-bytes", String(8 << 20)); opt("demuxer-max-back-bytes", String(4 << 20)); opt("demuxer-readahead-secs", "1")
        opt("vf", "scale=\(width):-2")
        guard mpv_initialize(h) >= 0 else { mpv_terminate_destroy(h); fail(); return nil }
        let alive: Bool = lock.withLock { if !stopped { wakeHandle = h }; return !stopped }
        guard alive else { mpv_terminate_destroy(h); return nil }
        engine = h
        Self.bump(1)
        var loaded = false
        guard command(h, ["loadfile", source, "replace"]) >= 0,
              pump(h, timeout: loadTimeout, until: { if $0 == MPV_EVENT_FILE_LOADED { loaded = true }; return loaded && $0 == MPV_EVENT_PLAYBACK_RESTART }) == .done
        else { if !isStopped { fail() } else { closeEngine() }; return nil }
        // Every frame would be the first one: a stream that cannot seek (no range requests, a live-like VOD) gets no previews.
        guard property(h, "seekable") == "yes" else { fail(); return nil }
        return h
    }

    private func closeEngine() {
        idle?.cancel(); idle = nil
        guard let h = engine else { return }
        engine = nil
        lock.withLock { wakeHandle = nil }         // after this nobody calls mpv_wakeup on the handle
        Self.bump(-1)
        mpv_terminate_destroy(h)
    }

    private func fail() {
        let first: Bool = lock.withLock { defer { failed = true; gate.cancel() }; return !failed && !stopped }
        closeEngine()
        if first { onFailure() }
    }

    private enum Outcome { case done, timeout, stopped, failed }

    /// Waits for an event `done` accepts. An end-of-file or shutdown while waiting means the source cannot be played.
    private func pump(_ h: OpaquePointer, timeout: TimeInterval, until done: (mpv_event_id) -> Bool) -> Outcome {
        let deadline = Self.now + timeout
        while true {
            if isStopped { return .stopped }
            let left = deadline - Self.now
            if left <= 0 { return .timeout }
            guard let ev = mpv_wait_event(h, min(left, 0.25)) else { continue }
            switch ev.pointee.event_id {
            case MPV_EVENT_NONE: continue
            case MPV_EVENT_END_FILE, MPV_EVENT_SHUTDOWN: return .failed
            case let id: if done(id) { return .done }
            }
        }
    }

    /// Throws away stale events (a late restart would be taken for the next seek's). False when the source ended meanwhile.
    private func drain(_ h: OpaquePointer) -> Bool {
        while let ev = mpv_wait_event(h, 0), ev.pointee.event_id != MPV_EVENT_NONE {
            if ev.pointee.event_id == MPV_EVENT_END_FILE || ev.pointee.event_id == MPV_EVENT_SHUTDOWN { return false }
        }
        return true
    }

    private func command(_ h: OpaquePointer, _ args: [String]) -> Int32 {
        let c = args.map { strdup($0) }
        defer { c.forEach { free($0) } }
        var ptrs: [UnsafePointer<CChar>?] = c.map { UnsafePointer($0) } + [nil]
        return mpv_command(h, &ptrs)
    }

    /// `screenshot-raw` answers a map with w, h, stride, format and the pixels as a byte array.
    private func grab(_ h: OpaquePointer) -> CGImage? {
        let args: [String] = ["screenshot-raw", "video"]
        let strings = args.map { strdup($0) }
        defer { strings.forEach { free($0) } }
        var items = strings.map { s -> mpv_node in var n = mpv_node(); n.format = MPV_FORMAT_STRING; n.u.string = s; return n }
        var result = mpv_node()
        let rc: Int32 = items.withUnsafeMutableBufferPointer { buf in
            var list = mpv_node_list(num: Int32(buf.count), values: buf.baseAddress, keys: nil)
            return withUnsafeMutablePointer(to: &list) { lp in
                var root = mpv_node(); root.format = MPV_FORMAT_NODE_ARRAY; root.u.list = lp
                return mpv_command_node(h, &root, &result)
            }
        }
        guard rc >= 0 else { return nil }
        defer { mpv_free_node_contents(&result) }
        guard result.format == MPV_FORMAT_NODE_MAP, let map = result.u.list?.pointee, map.num > 0, let keys = map.keys, let values = map.values else { return nil }
        var w = 0, hgt = 0, stride = 0, format = "", pixels: Data?
        for i in 0..<Int(map.num) {
            guard let k = keys[i] else { continue }
            let v = values[i]
            switch String(cString: k) {
            case "w" where v.format == MPV_FORMAT_INT64: w = Int(v.u.int64)
            case "h" where v.format == MPV_FORMAT_INT64: hgt = Int(v.u.int64)
            case "stride" where v.format == MPV_FORMAT_INT64: stride = Int(v.u.int64)
            case "format" where v.format == MPV_FORMAT_STRING: format = v.u.string.map { String(cString: $0) } ?? ""
            case "data" where v.format == MPV_FORMAT_BYTE_ARRAY:
                if let ba = v.u.ba?.pointee, let p = ba.data, ba.size > 0, ba.size <= 1 << 28 { pixels = Data(bytes: p, count: ba.size) }
            default: break
            }
        }
        guard let pixels else { return nil }
        return PreviewImage.make(width: w, height: hgt, stride: stride, format: format, data: pixels)
    }
}
