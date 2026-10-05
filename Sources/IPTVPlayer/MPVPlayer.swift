import Foundation
import CLibMPV

public struct Track: Identifiable, Equatable {
    public let id: Int
    public let type: String
    public let lang: String?
    public let title: String?
    public let selected: Bool
}

public final class MPVPlayer {
    public let handle: OpaquePointer
    public var onEndFile: ((Bool) -> Void)?
    public var onTeardown: (() -> Void)?
    private var quitting = false
    private let loopDone = DispatchSemaphore(value: 0)
    private var shutDown = false

    public init(subLang: String?, audioLang: String?) {
        handle = mpv_create()!
        func opt(_ k: String, _ v: String) { mpv_set_option_string(handle, k, v) }
        opt("vo", "libmpv")
        opt("hwdec", "videotoolbox")
        opt("cache", "yes")
        opt("demuxer-max-bytes", "64MiB")
        opt("demuxer-readahead-secs", "20")
        opt("network-timeout", "15")
        opt("stream-lavf-o", "reconnect=1,reconnect_streamed=1,reconnect_delay_max=5")
        opt("sub-auto", "fuzzy")
        opt("keep-open", "yes")
        if let s = subLang, !s.isEmpty { opt("slang", s) }
        if let a = audioLang, !a.isEmpty { opt("alang", a) }
        mpv_initialize(handle)
        startEventLoop()
    }

    private func startEventLoop() {
        let t = Thread { [unowned self] in
            while !self.quitting {
                guard let ev = mpv_wait_event(self.handle, 0.5) else { continue }
                switch ev.pointee.event_id {
                case MPV_EVENT_END_FILE:
                    let d = ev.pointee.data.assumingMemoryBound(to: mpv_event_end_file.self).pointee
                    if d.reason != MPV_END_FILE_REASON_STOP && d.reason != MPV_END_FILE_REASON_REDIRECT {
                        self.onEndFile?(d.reason == MPV_END_FILE_REASON_ERROR)
                    }
                case MPV_EVENT_SHUTDOWN: self.quitting = true
                default: break
                }
            }
            self.loopDone.signal()
        }
        t.name = "mpv-events"
        t.start()
    }

    private func command(_ args: [String]) {
        let c = args.map { strdup($0) }
        defer { c.forEach { free($0) } }
        var ptrs: [UnsafePointer<CChar>?] = c.map { UnsafePointer($0) } + [nil]
        mpv_command(handle, &ptrs)
    }

    public func load(_ url: URL, start: Double) { load(url.absoluteString, start: start) }

    /// Any mpv source string (URL, path, or `av://lavfi:...`).
    public func load(_ source: String, start: Double) {
        setProperty("start", start > 1 ? String(Int(start)) : "none")
        command(["loadfile", source, "replace"])
    }
    public func togglePause() { command(["cycle", "pause"]) }
    public func seek(by s: Double) { command(["seek", String(s), "relative"]) }
    public func seek(to s: Double) { command(["seek", String(s), "absolute"]) }
    public func addSubtitle(_ url: URL) { command(["sub-add", url.path, "select"]) }

    public func setProperty(_ name: String, _ value: String) { mpv_set_property_string(handle, name, value) }

    public func string(_ name: String) -> String? {
        guard let p = mpv_get_property_string(handle, name) else { return nil }
        defer { mpv_free(p) }
        return String(cString: p)
    }
    public func double(_ name: String) -> Double? {
        var v = 0.0
        return mpv_get_property(handle, name, MPV_FORMAT_DOUBLE, &v) >= 0 ? v : nil
    }
    public func flag(_ name: String) -> Bool { string(name) == "yes" }

    public func tracks() -> [Track] {
        let n = Int(string("track-list/count") ?? "0") ?? 0
        return (0..<n).compactMap { i in
            guard let id = Int(string("track-list/\(i)/id") ?? ""), let type = string("track-list/\(i)/type") else { return nil }
            return Track(id: id, type: type, lang: string("track-list/\(i)/lang"),
                         title: string("track-list/\(i)/title"), selected: string("track-list/\(i)/selected") == "yes")
        }
    }

    public func shutdown() {
        guard !shutDown else { return }
        shutDown = true
        quitting = true
        mpv_wakeup(handle)
        loopDone.wait()
        onTeardown?()
        mpv_terminate_destroy(handle)
    }
}
