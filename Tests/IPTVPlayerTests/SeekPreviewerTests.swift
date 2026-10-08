import Testing
import Foundation
import CoreGraphics
@testable import IPTVPlayer

/// Collects what a previewer delivers; the callbacks arrive on the previewer's own queue.
private final class Frames: @unchecked Sendable {
    private let lock = NSLock()
    private var all: [(time: Double, image: CGImage)] = []
    private var failures = 0
    var list: [(time: Double, image: CGImage)] { lock.withLock { all } }
    var failureCount: Int { lock.withLock { failures } }
    func add(_ t: Double, _ i: CGImage) { lock.withLock { all.append((t, i)) } }
    func fail() { lock.withLock { failures += 1 } }
    func wait(count: Int, seconds: Double = 10) async -> Bool {
        for _ in 0..<Int(seconds * 50) where list.count < count { try? await Task.sleep(for: .milliseconds(20)) }
        return list.count >= count
    }
    func waitForFailure(seconds: Double) async -> Bool {
        for _ in 0..<Int(seconds * 50) where failureCount == 0 { try? await Task.sleep(for: .milliseconds(20)) }
        return failureCount > 0
    }
}

private func previewer(_ source: String, _ f: Frames, debounce: Double = 0.05, loadTimeout: Double = 8, idleClose: Double = 20) -> SeekPreviewer {
    SeekPreviewer(source: source, width: 160, loadTimeout: loadTimeout, debounce: debounce, idleClose: idleClose,
                  onFrame: { f.add($0, $1) }, onFailure: { f.fail() })
}

/// The test video, or the test is cancelled (shown as skipped) on a machine that cannot encode one.
private func rampVideo() async throws -> URL {
    if let url = await makeBrightnessRampVideo() { return url }
    try Test.cancel("this machine cannot encode a test video")
}

@Suite(.serialized) struct SeekPreviewerTests {
    @Test func twoDifferentTimesGiveTwoDifferentFrames() async throws {
        let video = try await rampVideo()
        defer { try? FileManager.default.removeItem(at: video) }
        let f = Frames(), p = previewer(video.path, f)
        defer { p.shutdown(wait: true) }
        p.request(2.5)
        #expect(await f.wait(count: 1), "no frame for 2.5 s")
        p.request(9.5)
        #expect(await f.wait(count: 2), "no frame for 9.5 s")
        let early = try #require(f.list.first), late = try #require(f.list.last)
        #expect(early.time == 2.5 && late.time == 9.5, "the frames come back labelled with the time they were asked for")
        #expect(early.image.width == 160 && early.image.height == 90, "scaled to the thumbnail width, aspect kept: \(early.image.width)x\(early.image.height)")
        let a = centreGray(early.image), b = centreGray(late.image)
        #expect(abs(a - (20 + 18 * 2)) < 30, "frame at 2.5 s is gray \(a)")
        #expect(abs(b - (20 + 18 * 9)) < 30, "frame at 9.5 s is gray \(b)")
        #expect(b > a + 60)
        #expect(gray(late.image, x: 80, yFromTop: 2) < 40 && gray(late.image, x: 80, yFromTop: 85) > 150, "the picture is upright: black strip on top")
    }

    @Test func aBurstOfRequestsDeliversTheLatestTimeAndNotOneFramePerRequest() async throws {
        let video = try await rampVideo()
        defer { try? FileManager.default.removeItem(at: video) }
        let f = Frames(), p = previewer(video.path, f, debounce: 0.15)
        defer { p.shutdown(wait: true) }
        p.request(1)
        #expect(await f.wait(count: 1), "no first frame")
        for t in stride(from: 2.0, through: 11.0, by: 0.5) { p.request(t); try await Task.sleep(for: .milliseconds(10)) }
        #expect(await f.wait(count: 2))
        try await Task.sleep(for: .milliseconds(500))
        #expect(f.list.last?.time == 11, "the newest wanted time wins")
        #expect(f.list.count <= 4, "the burst was coalesced, got \(f.list.map(\.time))")
    }

    @Test func shutdownWhileARequestIsInFlightIsSafeAndReleasesTheEngine() async throws {
        let video = try await rampVideo()
        defer { try? FileManager.default.removeItem(at: video) }
        for delay in [0, 20, 80, 200] {   // before the debounce, while the engine opens, while it seeks
            let f = Frames(), p = previewer(video.path, f, debounce: 0.01)
            p.request(5)
            try await Task.sleep(for: .milliseconds(delay))
            p.shutdown(wait: true)
            p.request(7); p.shutdown(wait: true); p.shutdown()   // after shutdown everything is a no-op
            #expect(SeekPreviewer.liveEngines == 0, "engine leaked after shutdown at +\(delay) ms")
            let n = f.list.count
            try await Task.sleep(for: .milliseconds(300))
            #expect(f.list.count == n, "a frame was delivered after shutdown")
        }
    }

    @Test func shutdownWithoutAnyRequestNeverCreatesAnEngine() {
        let f = Frames(), p = previewer("/nonexistent.mp4", f)
        p.shutdown(wait: true)
        #expect(SeekPreviewer.liveEngines == 0)
    }

    @Test func anUnplayableSourceFailsOnceAndThenStaysQuiet() async throws {
        let f = Frames(), p = previewer("/nonexistent/definitely-not-here.mkv", f)
        defer { p.shutdown(wait: true) }
        p.request(3)
        #expect(await f.waitForFailure(seconds: 6), "onFailure never came")
        #expect(SeekPreviewer.liveEngines == 0, "the failed engine is destroyed")
        p.request(4); p.request(5)
        try await Task.sleep(for: .milliseconds(400))
        #expect(f.failureCount == 1 && f.list.isEmpty, "a failed previewer is disabled")
    }

    @Test func aNetworkSourceWithRangeSupportGivesFrames() async throws {
        let video = try await rampVideo()
        defer { try? FileManager.default.removeItem(at: video) }
        let server = try #require(TinyHTTPServer(body: try Data(contentsOf: video), ranges: true))
        defer { server.stop() }
        let f = Frames(), p = previewer("http://127.0.0.1:\(server.port)/movie/u/p/1.mp4", f)
        defer { p.shutdown(wait: true) }
        p.request(2.5)
        #expect(await f.wait(count: 1), "no frame over http")
        p.request(9.5)
        #expect(await f.wait(count: 2))
        let a = centreGray(try #require(f.list.first).image), b = centreGray(try #require(f.list.last).image)
        #expect(b > a + 60, "frames over http: gray \(a) then \(b)")
        #expect(server.connectionCount >= 1)
    }

    @Test func aServerWithoutRangeSupportTurnsThePreviewOffInsteadOfRepeatingTheFirstFrame() async throws {
        let video = try await rampVideo()
        defer { try? FileManager.default.removeItem(at: video) }
        let server = try #require(TinyHTTPServer(body: try Data(contentsOf: video), ranges: false))
        defer { server.stop() }
        let f = Frames(), p = previewer("http://127.0.0.1:\(server.port)/movie/u/p/1.mp4", f)
        defer { p.shutdown(wait: true) }
        p.request(9)
        #expect(await f.waitForFailure(seconds: 6), "an unseekable source must disable the preview")
        #expect(f.list.isEmpty && SeekPreviewer.liveEngines == 0)
    }

    @Test func aHostThatNeverAnswersTimesOutAndDisablesThePreview() async throws {
        let f = Frames(), p = previewer("http://192.0.2.1/never.mp4", f, loadTimeout: 1)   // TEST-NET-1: nothing answers there
        defer { p.shutdown(wait: true) }
        let t0 = Date()
        p.request(3)
        #expect(await f.waitForFailure(seconds: 6), "no failure after the timeout")
        #expect(Date().timeIntervalSince(t0) < 5, "the timeout was ignored")
        #expect(SeekPreviewer.liveEngines == 0)
    }

    @Test func anIdleEngineIsReleasedAndComesBackOnTheNextRequest() async throws {
        let video = try await rampVideo()
        defer { try? FileManager.default.removeItem(at: video) }
        let f = Frames(), p = previewer(video.path, f, idleClose: 0.5)
        defer { p.shutdown(wait: true) }
        p.request(3)
        #expect(await f.wait(count: 1))
        #expect(SeekPreviewer.liveEngines == 1)
        for _ in 0..<100 where SeekPreviewer.liveEngines != 0 { try await Task.sleep(for: .milliseconds(20)) }
        #expect(SeekPreviewer.liveEngines == 0, "the connection is released when nobody hovers")
        p.request(8)
        #expect(await f.wait(count: 2), "no frame after the engine was released")
        #expect(f.failureCount == 0)
    }

    @Test func thePreviewEngineKeepsTheSameHardeningAsThePlayer() async throws {
        let video = try await rampVideo()
        defer { try? FileManager.default.removeItem(at: video) }
        let f = Frames(), p = previewer(video.path, f)
        defer { p.shutdown(wait: true) }
        p.request(1)
        #expect(await f.wait(count: 1))
        for (k, v) in EngineOptions.hardened where k != "network-timeout" {
            #expect(p.optionValue(k) == v, "\(k)")
        }
        #expect(p.optionValue("tls-verify") == "yes")
        #expect(p.optionValue("ao") == "null" && p.optionValue("aid") == "no" && p.optionValue("sid") == "no")
        #expect(p.optionValue("hr-seek") == "no")
    }
}
