import AppKit
import Testing
import Foundation
@testable import IPTVPlayer

/// Real libmpv, synthetic lavfi source (no network, no display): proves the engine links, loads and plays.
@Test func enginePlaysSyntheticSource() async throws {
    let p = MPVPlayer(subLang: nil, audioLang: nil)
    defer { p.shutdown() }
    p.setProperty("vo", "null")
    p.load("av://lavfi:testsrc=size=320x240:rate=25", start: 0)
    var pos = 0.0
    for _ in 0..<40 {
        try await Task.sleep(for: .milliseconds(100))
        pos = p.double("time-pos") ?? 0
        if pos > 0.5 { break }
    }
    #expect(pos > 0.5, "time-pos stayed at \(pos)")
    #expect(p.tracks().contains { $0.type == "video" })
    p.togglePause()
    try await Task.sleep(for: .milliseconds(300))
    #expect(p.flag("pause"))
}

@Test func endFileErrorIsReportedForUnplayableSource() async throws {
    let p = MPVPlayer(subLang: nil, audioLang: nil)
    defer { p.shutdown() }
    p.setProperty("vo", "null")
    nonisolated(unsafe) var sawError = false
    p.onEndFile = { isError in if isError { sawError = true } }
    p.load(URL(string: "file:///nonexistent/definitely-not-here.mkv")!, start: 0)
    for _ in 0..<40 where !sawError { try await Task.sleep(for: .milliseconds(100)) }
    #expect(sawError)
}

/// Real OpenGL rendering: the video view must actually draw decoded frames (not just play audio/clock).
@MainActor @Test func videoViewDrawsNonBlackFrames() async throws {
    _ = NSApplication.shared
    let p = MPVPlayer(subLang: nil, audioLang: nil)
    let v = MPVVideoView(player: p)
    defer { p.shutdown() }
    let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 240), styleMask: [.borderless], backing: .buffered, defer: false)
    w.contentView = v
    w.alphaValue = 0.01          // visible to the window server (needed for GL drawing) but practically invisible
    w.orderFrontRegardless()
    var brightest = 0
    var frames = 0
    v.onFrame = { r, g, b in frames += 1; brightest = max(brightest, Int(r) + Int(g) + Int(b)) }
    p.load("av://lavfi:testsrc=size=320x240:rate=25", start: 0)
    for _ in 0..<50 where brightest <= 30 { try await Task.sleep(for: .milliseconds(100)) }
    #expect(frames > 0, "no frame was drawn")
    #expect(brightest > 30, "frames were drawn but all black (max rgb sum \(brightest))")
    w.orderOut(nil)
}

@Test func externalHebrewSubtitleFileBecomesSelectableTrack() async throws {
    let srt = FileManager.default.temporaryDirectory.appendingPathComponent("iptvmac-test-\(UUID().uuidString).srt")
    try "1\n00:00:00,000 --> 00:00:05,000\nשלום עולם\n".write(to: srt, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: srt) }
    let p = MPVPlayer(subLang: "he", audioLang: nil)
    defer { p.shutdown() }
    p.setProperty("vo", "null")
    p.load("av://lavfi:testsrc=size=320x240:rate=25", start: 0)
    try await Task.sleep(for: .milliseconds(500))
    p.addSubtitle(srt)
    var sub: Track?
    for _ in 0..<30 where sub == nil {
        try await Task.sleep(for: .milliseconds(100))
        sub = p.tracks().first { $0.type == "sub" }
    }
    #expect(sub != nil, "external subtitle did not appear in the track list")
    #expect(sub?.selected == true)
    p.setProperty("sid", "no")
    try await Task.sleep(for: .milliseconds(200))
    #expect(p.tracks().first { $0.type == "sub" }?.selected == false)
}

/// Picture-in-Picture moves the single video view into another window; frames must keep being drawn there.
@MainActor @Test func videoKeepsDrawingAfterMovingToAnotherWindow() async throws {
    _ = NSApplication.shared
    func makeWindow() -> NSWindow {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 240), styleMask: [.borderless], backing: .buffered, defer: false)
        w.alphaValue = 0.01
        w.contentView = NSView()
        w.orderFrontRegardless()
        return w
    }
    let p = MPVPlayer(subLang: nil, audioLang: nil)
    let v = MPVVideoView(player: p)
    defer { p.shutdown() }
    let a = makeWindow(), b = makeWindow()
    v.frame = a.contentView!.bounds; v.autoresizingMask = [.width, .height]
    a.contentView!.addSubview(v)
    var brightest = 0
    var frames = 0
    v.onFrame = { r, g, b in frames += 1; brightest = max(brightest, Int(r) + Int(g) + Int(b)) }
    p.load("av://lavfi:testsrc=size=320x240:rate=25", start: 0)
    for _ in 0..<50 where brightest <= 30 { try await Task.sleep(for: .milliseconds(100)) }
    #expect(brightest > 30, "no non-black frame before the move")

    v.removeFromSuperview()
    v.frame = b.contentView!.bounds
    b.contentView!.addSubview(v)
    a.orderOut(nil)
    brightest = 0; frames = 0
    for _ in 0..<50 where brightest <= 30 { try await Task.sleep(for: .milliseconds(100)) }
    #expect(frames > 0, "no frames drawn after the move")
    #expect(brightest > 30, "frames after the move were black (max rgb sum \(brightest))")
    b.orderOut(nil)
}
