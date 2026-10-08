import Testing
import Foundation
import CoreGraphics
@testable import IPTVPlayer

// MARK: raw frame -> image

private func bgr0(_ w: Int, _ h: Int, stride: Int? = nil, b: UInt8 = 0, g: UInt8 = 0, r: UInt8 = 0) -> Data {
    let s = stride ?? w * 4
    var d = Data(count: s * h)
    for y in 0..<h { for x in 0..<w { let o = y * s + x * 4; d[o] = b; d[o + 1] = g; d[o + 2] = r } }
    return d
}

/// The first pixel as r, g, b, drawn through CoreGraphics (what the screen would show).
private func firstPixel(_ img: CGImage) -> [UInt8] {
    var px = [UInt8](repeating: 0, count: 4)
    let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
    return px
}

@Test func rawFrameBecomesAnImageWithTheRightColours() throws {
    let img = try #require(PreviewImage.make(width: 4, height: 3, stride: 16, format: "bgr0", data: bgr0(4, 3, b: 10, g: 20, r: 200)))
    #expect(img.width == 4 && img.height == 3)
    #expect(firstPixel(img) == [200, 20, 10, 255], "bgr0 is blue, green, red in memory")
}

@Test func rawFrameWithPaddedRowsKeepsTheRowLength() throws {
    let img = try #require(PreviewImage.make(width: 3, height: 2, stride: 16, format: "bgr0", data: bgr0(3, 2, stride: 16, r: 255)))
    #expect(img.width == 3 && img.height == 2 && img.bytesPerRow == 16)
}

@Test(arguments: [
    (0, 10, 40, "bgr0", 400), (10, 0, 40, "bgr0", 400), (-1, 10, 40, "bgr0", 400), (10, -5, 40, "bgr0", 400),
    (10, 10, 39, "bgr0", 400),                                    // stride shorter than a row
    (10, 10, 40, "bgr0", 399),                                    // data shorter than stride * height
    (10, 10, 0, "bgr0", 400), (10, 10, -40, "bgr0", 400),
    (10, 10, 40, "rgb24", 400), (10, 10, 40, "", 400),            // unknown pixel format
    (100_000, 10, 400_000, "bgr0", 400),                          // absurd width
    (10, 100_000, 40, "bgr0", 400),                               // absurd height
    (Int.max, 2, Int.max, "bgr0", 400),                           // multiplication overflows
    (4, Int.max, 16, "bgr0", 400),
])
func hostileRawFramesAreRefusedNotCrashed(_ w: Int, _ h: Int, _ stride: Int, _ format: String, _ size: Int) {
    #expect(PreviewImage.make(width: w, height: h, stride: stride, format: format, data: Data(count: size)) == nil)
}

// MARK: time buckets

@Test func shortVideosUseOneSecondBucketsAndLongOnesFiveSeconds() {
    #expect(PreviewBuckets.size(forDuration: 90) == 1)
    #expect(PreviewBuckets.size(forDuration: 599) == 1)
    #expect(PreviewBuckets.size(forDuration: 600) == 5)
    #expect(PreviewBuckets.size(forDuration: 7200) == 5)
    #expect(PreviewBuckets.size(forDuration: 0) == 1)
}

@Test func timesInTheSameBucketShareAKeyAndTheBucketStartsAtItsFirstSecond() {
    #expect(PreviewBuckets.key(time: 12.1, duration: 90) == PreviewBuckets.key(time: 12.9, duration: 90))
    #expect(PreviewBuckets.key(time: 12.9, duration: 90) != PreviewBuckets.key(time: 13.0, duration: 90))
    #expect(PreviewBuckets.key(time: 61, duration: 3600) == PreviewBuckets.key(time: 64.9, duration: 3600))
    #expect(PreviewBuckets.key(time: 64.9, duration: 3600) != PreviewBuckets.key(time: 65, duration: 3600))
    #expect(PreviewBuckets.time(forKey: PreviewBuckets.key(time: 64.9, duration: 3600), duration: 3600) == 60)
    #expect(PreviewBuckets.key(time: -3, duration: 90) == 0 && PreviewBuckets.key(time: .nan, duration: 90) == 0)
    #expect(PreviewBuckets.key(time: 500, duration: 90) == PreviewBuckets.key(time: 90, duration: 90), "past the end is the last bucket")
}

@Test func theLastBucketIsCapturedBeforeTheEndOfTheFile() {
    #expect(PreviewBuckets.captureTime(forKey: 90, duration: 90.5) == 89.5, "a seek to the very end has no frame to show")
    #expect(PreviewBuckets.captureTime(forKey: 3, duration: 90) == 3)
    #expect(PreviewBuckets.captureTime(forKey: 0, duration: 0.5) == 0)
    #expect(PreviewBuckets.captureTime(forKey: 718, duration: 3600) == 3590)
}

// MARK: debounce and coalescing

private func waitTime(_ a: PreviewGate.Action) -> Double? { if case .wait(let s) = a { s } else { nil } }

@Test func firstRequestWaitsForTheDebounceThenFires() {
    var g = PreviewGate(debounce: 0.12)
    #expect(g.want(5, now: 100) == true, "the caller must schedule a wake-up")
    #expect(abs((waitTime(g.wake(now: 100.05)) ?? -1) - 0.07) < 0.001)
    #expect(g.wake(now: 100.12) == .fire(5))
    #expect(g.wake(now: 100.2) == .idle)
}

@Test func aBurstOfRequestsFiresOnlyTheLatestOneAfterTheLastPause() {
    var g = PreviewGate(debounce: 0.12)
    #expect(g.want(1, now: 0) == true)
    #expect(g.want(2, now: 0.05) == false, "one wake-up is already scheduled")
    #expect(g.want(3, now: 0.10) == false)
    #expect(abs((waitTime(g.wake(now: 0.12)) ?? -1) - 0.10) < 0.001, "the pause restarts with every request")
    #expect(g.wake(now: 0.22) == .fire(3))
    #expect(g.wake(now: 0.30) == .idle)
}

@Test func requestsWhileBusyKeepOnlyTheNewestAndNeedAFreshWakeUp() {
    var g = PreviewGate(debounce: 0.12)
    _ = g.want(1, now: 0)
    #expect(g.wake(now: 0.12) == .fire(1))
    #expect(g.want(2, now: 0.3) == true, "after a fire the next request arms a new wake-up")
    #expect(g.want(3, now: 0.31) == false)
    #expect(g.wake(now: 0.43) == .fire(3), "2 was replaced, never queued")
    #expect(g.wake(now: 0.9) == .idle)
}

@Test func cancelDropsThePendingRequest() {
    var g = PreviewGate(debounce: 0.12)
    _ = g.want(4, now: 0)
    g.cancel()
    #expect(g.wake(now: 1) == .idle)
    #expect(g.want(5, now: 2) == true)
    #expect(g.wake(now: 2.12) == .fire(5))
}
