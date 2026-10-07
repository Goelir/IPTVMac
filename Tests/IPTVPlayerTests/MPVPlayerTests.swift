import AppKit
import Testing
import Foundation
@testable import IPTVPlayer

/// Synthetic lavfi source by default; set IPTV_TEST_VIDEO to a real file to run the same tests with engines that lack lavfi.
let testVideo = ProcessInfo.processInfo.environment["IPTV_TEST_VIDEO"] ?? "av://lavfi:testsrc=size=320x240:rate=25"

/// Real libmpv, synthetic lavfi source (no network, no display): proves the engine links, loads and plays.
@Test func enginePlaysSyntheticSource() async throws {
    let p = MPVPlayer(subLang: nil, audioLang: nil)
    defer { p.shutdown() }
    p.setProperty("vo", "null")
    p.load(testVideo, start: 0)
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
    #expect(p.lastError?.isEmpty == false, "the failure reason must be available to show in the UI")
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
    p.load(testVideo, start: 0)
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
    p.load(testVideo, start: 0)
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
    p.load(testVideo, start: 0)
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

/// The UI keeps timers and retry tasks that can fire after the player was closed.
@Test func callsAfterShutdownAreSafeNoOps() {
    let p = MPVPlayer(subLang: nil, audioLang: nil)
    p.shutdown()
    #expect(p.double("time-pos") == nil)
    #expect(p.string("mpv-version") == nil)
    #expect(p.flag("pause") == false)
    #expect(p.isAtEnd == false)
    #expect(p.tracks().isEmpty)
    p.setProperty("pause", "yes")
    p.load("/nonexistent.mkv", start: 0)
    p.togglePause(); p.seek(by: 1); p.seek(to: 1)
    p.shutdown()
}

/// With keep-open the player stops at the end without an end-file event; live retry depends on seeing it.
@Test func isAtEndTurnsTrueWhenTheFileEnds() async throws {
    let wav = FileManager.default.temporaryDirectory.appendingPathComponent("iptvmac-end-\(UUID().uuidString).wav")
    func le32(_ v: Int) -> Data { withUnsafeBytes(of: UInt32(v).littleEndian) { Data($0) } }
    func le16(_ v: Int) -> Data { withUnsafeBytes(of: UInt16(v).littleEndian) { Data($0) } }
    let bytes = 8000 * 2
    var d = Data("RIFF".utf8); d += le32(36 + bytes); d += Data("WAVEfmt ".utf8)
    d += le32(16); d += le16(1); d += le16(1); d += le32(8000); d += le32(16000); d += le16(2); d += le16(16)
    d += Data("data".utf8); d += le32(bytes); d += Data(count: bytes)
    try d.write(to: wav)
    defer { try? FileManager.default.removeItem(at: wav) }
    let p = MPVPlayer(subLang: nil, audioLang: nil)
    defer { p.shutdown() }
    p.setProperty("vo", "null")
    p.load(wav.path, start: 0)
    #expect(p.isAtEnd == false)
    for _ in 0..<60 where !p.isAtEnd { try await Task.sleep(for: .milliseconds(100)) }
    #expect(p.isAtEnd, "eof-reached never became true")
}

@Test func doubleSpeedAdvancesTwiceAsFast() async throws {
    let p = MPVPlayer(subLang: nil, audioLang: nil)
    defer { p.shutdown() }
    p.setProperty("vo", "null"); p.setProperty("ao", "null")
    p.load(testVideo, start: 0)
    for _ in 0..<40 where (p.double("time-pos") ?? 0) < 0.3 { try await Task.sleep(for: .milliseconds(100)) }
    p.setProperty("speed", "2")
    #expect(p.double("speed") == 2)
    let t0 = p.double("time-pos") ?? 0
    try await Task.sleep(for: .seconds(1))
    let advanced = (p.double("time-pos") ?? 0) - t0
    #expect(advanced > 1.5, "advanced \(advanced)s in 1s at 2x")
}

/// The speed picker: the value PlayerModel.setSpeed hands to mpv really becomes the engine's `speed`, and playback runs at that rate.
@Test(arguments: [0.5, 1.5, 4.0])
func speedPropertyBecomesThePickedSpeedAndPlaybackFollowsIt(_ speed: Double) async throws {
    let p = MPVPlayer(subLang: nil, audioLang: nil)
    defer { p.shutdown() }
    p.setProperty("vo", "null"); p.setProperty("ao", "null")
    #expect(p.string("audio-pitch-correction") == "yes", "the voice must keep its natural pitch at any speed")
    #expect(p.double("speed") == 1)
    p.load(testVideo, start: 0)
    for _ in 0..<40 where (p.double("time-pos") ?? 0) < 0.3 { try await Task.sleep(for: .milliseconds(100)) }
    p.setProperty("speed", String(PlaybackSpeed.normalized(speed)))
    #expect(p.double("speed") == speed)
    let clock = ContinuousClock()
    let t0 = p.double("time-pos") ?? 0, w0 = clock.now
    try await Task.sleep(for: .seconds(1))
    let advanced = (p.double("time-pos") ?? 0) - t0
    let d = (clock.now - w0).components
    let wall = Double(d.seconds) + Double(d.attoseconds) / 1e18
    #expect(abs(advanced / wall - speed) < speed * 0.25, "advanced \(advanced)s in \(wall)s at \(speed)x")
    p.setProperty("speed", "1")
    #expect(p.double("speed") == 1)
}

/// The 2x button must not break subtitles: through the real OpenGL path the subtitle is drawn into the frames at 1x and at 2x.
@MainActor @Test(arguments: [1.0, 2.0])
func subtitleIsDrawnIntoFramesAtSpeed(_ speed: Double) async throws {
    _ = NSApplication.shared
    let srt = FileManager.default.temporaryDirectory.appendingPathComponent("iptvmac-draw-\(UUID().uuidString).srt")
    try "1\n00:00:02,000 --> 00:00:08,000\n{\\an5}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\n".write(to: srt, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: srt) }
    let p = MPVPlayer(subLang: nil, audioLang: nil)
    let v = MPVVideoView(player: p)
    defer { p.shutdown() }
    p.setProperty("ao", "null"); p.setProperty("sub-scale", "4"); p.setProperty("speed", String(speed))
    let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 240), styleMask: [.borderless], backing: .buffered, defer: false)
    w.contentView = v; w.alphaValue = 0.01; w.orderFrontRegardless()
    var inCue = 0, litInCue = 0
    v.onFrame = { r, g, b in
        let t = p.double("time-pos") ?? 0
        if t > 3 && t < 7 { inCue += 1; if Int(r) + Int(g) + Int(b) > 300 { litInCue += 1 } }
    }
    p.load("av://lavfi:color=c=black:size=320x240:rate=25", start: 0)
    for _ in 0..<60 where (p.double("time-pos") ?? 0) < 0.2 { try await Task.sleep(for: .milliseconds(100)) }
    p.addSubtitle(srt)
    for _ in 0..<80 where (p.double("time-pos") ?? 0) < 7.2 { try await Task.sleep(for: .milliseconds(100)) }
    #expect(inCue > 0, "speed \(speed): no frames drawn while the cue was active")
    #expect(litInCue > 0, "speed \(speed): \(inCue) frames drawn during the cue but the subtitle never appeared")
    w.orderOut(nil)
}

/// keep-open pauses the player at the end of a file; the next file (next episode, another channel) must start playing.
@Test func nextFileStartsPlayingAfterTheEndOfTheFirst() async throws {
    let p = MPVPlayer(subLang: nil, audioLang: nil)
    defer { p.shutdown() }
    p.setProperty("vo", "null"); p.setProperty("ao", "null")
    p.load("av://lavfi:testsrc=size=320x240:rate=25:d=1", start: 0)
    for _ in 0..<60 where !p.isAtEnd { try await Task.sleep(for: .milliseconds(100)) }
    #expect(p.isAtEnd, "the first file never reached its end")
    p.load(testVideo, start: 0)
    var pos = 0.0
    for _ in 0..<40 where pos < 0.5 { try await Task.sleep(for: .milliseconds(100)); pos = p.double("time-pos") ?? 0 }
    #expect(pos > 0.5, "the second file did not start playing (time-pos \(pos), paused \(p.flag("pause")))")
    #expect(!p.flag("pause"))
}

/// Untrusted provider: HTTPS certificates must be verified and scripting switched off.
@Test func engineIsHardenedForUntrustedStreams() {
    let p = MPVPlayer(subLang: nil, audioLang: nil)
    defer { p.shutdown() }
    #expect(p.string("tls-verify") == "yes")
    #expect(p.string("tls-ca-file") == "/etc/ssl/cert.pem")
    #expect(FileManager.default.fileExists(atPath: "/etc/ssl/cert.pem"))
    #expect(p.string("ytdl") == "no")
    #expect(p.string("load-scripts") == "no")
    #expect(p.string("embeddedfonts") == "no")
}

@Test func httpsWithAValidCertificateStillPlaysAndABadOneIsRefused() async throws {
    guard ProcessInfo.processInfo.environment["IPTV_NETWORK_TESTS"] != nil else { return }   // needs the internet
    func tryLoad(_ url: String) async throws -> (played: Bool, failed: Bool) {
        let p = MPVPlayer(subLang: nil, audioLang: nil)
        defer { p.shutdown() }
        p.setProperty("vo", "null"); p.setProperty("ao", "null")
        nonisolated(unsafe) var failed = false
        p.onEndFile = { if $0 { failed = true } }
        p.load(url, start: 0)
        var played = false
        for _ in 0..<150 where !played && !failed { try await Task.sleep(for: .milliseconds(100)); played = (p.double("time-pos") ?? 0) > 0.3 }
        return (played, failed)
    }
    let good = try await tryLoad("https://github.com/Goelir/IPTVMac/releases/download/v0.3.4/IPTVMac-demo-en.mp4")
    #expect(good.played, "a valid certificate must still play")
    let bad = try await tryLoad("https://self-signed.badssl.com/")
    #expect(bad.failed && !bad.played, "a self-signed certificate must be refused")
}
