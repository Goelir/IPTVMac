import AppKit
import Testing
import Foundation
@testable import IPTVMac

private func image(_ gray: UInt8) -> CGImage {
    let ctx = CGContext(data: nil, width: 8, height: 4, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(gray: CGFloat(gray) / 255, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 4))
    return ctx.makeImage()!
}

// MARK: what may open a second connection

@Test(arguments: [
    ("file:///Users/me/Movies/a%20b.mkv", false, "/Users/me/Movies/a b.mkv"),     // downloads always get previews
    ("file:///Users/me/Movies/a.mkv", true, "/Users/me/Movies/a.mkv"),
    ("/Users/me/Movies/a.mkv", false, "/Users/me/Movies/a.mkv"),                    // a plain local path
    ("http://host:8080/movie/u/p/1.mkv", false, nil),                               // the provider may allow one connection: only with the setting
    ("http://host:8080/movie/u/p/1.mkv", true, "http://host:8080/movie/u/p/1.mkv"),
    ("https://host/movie/u/p/1.mkv", false, nil),
    ("https://host/movie/u/p/1.mkv", true, "https://host/movie/u/p/1.mkv"),
    ("rtmp://host/live/x", true, nil), ("udp://239.1.1.1:1234", true, nil), ("rtsp://host/x", true, nil),
] as [(String, Bool, String?)])
func previewSourcePolicy(_ url: String, _ networkAllowed: Bool, _ expected: String?) throws {
    let u = try #require(URL(string: url))
    #expect(PreviewSource.path(for: u, isLive: false, networkAllowed: networkAllowed) == expected)
}

@Test func liveStreamsNeverGetPreviews() throws {
    let u = try #require(URL(string: "http://host/live/u/p/1.ts"))
    #expect(PreviewSource.path(for: u, isLive: true, networkAllowed: true) == nil)
    #expect(PreviewSource.path(for: URL(fileURLWithPath: "/a.ts"), isLive: true, networkAllowed: true) == nil)
}

// MARK: the model between the seek bar and the previewer

@MainActor @Test func withoutASourceTheBubbleIsJustATimeLabel() {
    let p = SeekPreview()
    defer { p.shutdown() }
    var asked = 0
    p.hover(10, duration: 100) { asked += 1; return nil }
    #expect(p.look == .none)
    p.hover(11, duration: 100) { asked += 1; return nil }
    #expect(asked == 2, "the setting can be switched on while watching, so it is asked again")
}

@MainActor @Test func aUnplayableSourceShowsAPlaceholderThenSilentlyGivesUpForTheItem() async throws {
    let p = SeekPreview()
    defer { p.shutdown() }
    var opened = 0
    func open() -> String? { opened += 1; return "/nonexistent/definitely-not-here.mkv" }
    p.hover(10, duration: 100, source: open)
    #expect(p.look == .loading, "a neutral placeholder while the previewer starts")
    for _ in 0..<150 where p.look == .loading { try await Task.sleep(for: .milliseconds(40)) }
    #expect(p.look == .none, "after the failure the bar is a plain seek bar")
    p.hover(20, duration: 100, source: open)
    p.hover(30, duration: 100, source: open)
    #expect(opened == 1 && p.look == .none, "no second attempt for this item")
    p.reset()
    p.hover(10, duration: 100, source: open)
    #expect(opened == 2, "a new item gets a new chance")
}

@MainActor @Test func aFrameIsShownAndRememberedPerTimeBucket() {
    let p = SeekPreview()
    defer { p.shutdown() }
    let a = image(50), b = image(200)
    p.hover(10.4, duration: 100) { "/nonexistent.mkv" }
    p.received(time: 10, image: a, duration: 100)
    #expect(p.look == .image(a))
    p.hover(40, duration: 100) { "/nonexistent.mkv" }
    p.received(time: 40, image: b, duration: 100)
    #expect(p.look == .image(b))
    p.hover(10.9, duration: 100) { "/nonexistent.mkv" }
    #expect(p.look == .image(a), "a bucket seen before comes from the cache at once")
    p.hover(10.9, duration: 100) { nil }
}

@MainActor @Test func longVideosCacheInFiveSecondBuckets() {
    let p = SeekPreview()
    defer { p.shutdown() }
    let a = image(50)
    p.hover(63, duration: 3600) { "/nonexistent.mkv" }
    p.received(time: 60, image: a, duration: 3600)
    p.hover(200, duration: 3600) { "/nonexistent.mkv" }
    p.hover(64.9, duration: 3600) { "/nonexistent.mkv" }
    #expect(p.look == .image(a))
}

@MainActor @Test func resetForgetsEverythingAndShutdownStopsForGood() {
    let p = SeekPreview()
    p.hover(10, duration: 100) { "/nonexistent.mkv" }
    p.received(time: 10, image: image(9), duration: 100)
    p.reset()
    #expect(p.look == .none)
    p.hover(10, duration: 100) { nil }
    #expect(p.look == .none, "the cache of the old item is gone")
    p.shutdown()
    var asked = 0
    p.hover(10, duration: 100) { asked += 1; return "/nonexistent.mkv" }
    p.received(time: 10, image: image(9), duration: 100)
    #expect(asked == 0 && p.look == .none, "nothing is used after shutdown")
}

@MainActor @Test func releaseDropsTheEngineButKeepsTheFramesAndAllowsALaterHover() {
    let p = SeekPreview()
    defer { p.shutdown() }
    let a = image(50)
    p.hover(10, duration: 100) { "/nonexistent.mkv" }
    p.received(time: 10, image: a, duration: 100)
    p.release()
    #expect(p.look == .image(a))
    var asked = 0
    p.hover(30, duration: 100) { asked += 1; return "/nonexistent.mkv" }
    #expect(asked == 1, "hovering again starts a fresh previewer")
}

@MainActor @Test func unknownDurationOrTimeDoNothing() {
    let p = SeekPreview()
    defer { p.shutdown() }
    var asked = 0
    p.hover(10, duration: 0) { asked += 1; return "/nonexistent.mkv" }
    p.hover(.nan, duration: 100) { asked += 1; return "/nonexistent.mkv" }
    #expect(asked == 0 && p.look == .none)
}

// MARK: wiring in the player

private func request(_ url: String, live: Bool = false) -> PlayRequest {
    PlayRequest(title: "t", url: URL(string: url) ?? URL(fileURLWithPath: url), isLive: live, item: nil)
}

@MainActor @Test func aNetworkItemGetsNoPreviewUnlessTheSettingIsOn() async throws {
    let d = UserDefaults.standard
    defer { d.removeObject(forKey: "seekPreview") }
    d.removeObject(forKey: "seekPreview")
    let pm = PlayerModel(request: request("http://127.0.0.1:9/movie/u/p/1.mkv"))   // nothing listens on port 9
    defer { pm.close() }
    pm.duration = 100
    pm.previewHover(10)
    #expect(pm.preview.look == .none, "the setting is off by default: no second connection")
    d.set(true, forKey: "seekPreview")
    pm.previewHover(10)
    #expect(pm.preview.look == .loading, "switched on while watching: the next hover starts the preview")
    for _ in 0..<150 where pm.preview.look == .loading { try await Task.sleep(for: .milliseconds(40)) }
    #expect(pm.preview.look == .none, "a connection that cannot be opened silently turns the preview off for this item")
}

@MainActor @Test func aLocalFileGetsPreviewsWithoutAnySetting() {
    UserDefaults.standard.removeObject(forKey: "seekPreview")
    let pm = PlayerModel(request: PlayRequest(title: "t", url: URL(fileURLWithPath: "/nonexistent/download.mkv"), isLive: false, item: nil))
    defer { pm.close() }
    pm.duration = 100
    pm.previewHover(10)
    #expect(pm.preview.look == .loading)
}

@MainActor @Test func aLiveStreamNeverGetsAPreviewEvenWithTheSettingOn() {
    let d = UserDefaults.standard
    defer { d.removeObject(forKey: "seekPreview") }
    d.set(true, forKey: "seekPreview")
    let pm = PlayerModel(request: request("http://127.0.0.1:9/live/u/p/1.ts", live: true))
    defer { pm.close() }
    pm.duration = 100
    pm.previewHover(10)
    #expect(pm.preview.look == .none)
}

@MainActor @Test func changingTheItemDropsTheOldPreviewAndClosingStopsItForGood() {
    let pm = PlayerModel(request: PlayRequest(title: "a", url: URL(fileURLWithPath: "/nonexistent/a.mkv"), isLive: false, item: nil))
    pm.duration = 100
    pm.previewHover(10)
    pm.preview.received(time: 10, image: image(9), duration: 100)
    #expect(pm.preview.look != .none)
    pm.replace(with: PlayRequest(title: "b", url: URL(fileURLWithPath: "/nonexistent/b.mkv"), isLive: false, item: nil))
    #expect(pm.preview.look == .none, "the next episode must not show the last one's frames")
    pm.duration = 100
    pm.previewHover(10)
    #expect(pm.preview.look == .loading, "and gets its own previewer")
    pm.close()
    #expect(pm.preview.look == .none)
    pm.previewHover(10)
    pm.replace(with: PlayRequest(title: "c", url: URL(fileURLWithPath: "/nonexistent/c.mkv"), isLive: false, item: nil))
    pm.duration = 100
    pm.previewHover(10)
    #expect(pm.preview.look == .none, "a closed player never starts a previewer again")
}
