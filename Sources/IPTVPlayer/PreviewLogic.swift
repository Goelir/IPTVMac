import Foundation
import CoreGraphics

/// Raw `screenshot-raw` bytes (always bgr0) to an image. Every number comes from mpv but is checked anyway: a wrong stride must not read out of bounds.
enum PreviewImage {
    static let maxSide = 4096

    static func make(width: Int, height: Int, stride: Int, format: String, data: Data) -> CGImage? {
        guard format == "bgr0", (1...maxSide).contains(width), (1...maxSide).contains(height) else { return nil }
        let (row, o1) = width.multipliedReportingOverflow(by: 4)
        let (total, o2) = stride.multipliedReportingOverflow(by: height)
        guard !o1, !o2, stride >= row, total <= data.count, let provider = CGDataProvider(data: data.prefix(total) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: stride, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}

/// Thumbnails are cached per time bucket: 1 s for videos under 10 minutes, 5 s for longer ones.
public enum PreviewBuckets {
    public static func size(forDuration d: Double) -> Double { d >= 600 ? 5 : 1 }

    public static func key(time: Double, duration: Double) -> Int {
        guard time.isFinite else { return 0 }
        let t = max(0, duration > 0 ? min(time, duration) : time)
        return Int(t / size(forDuration: duration))
    }

    /// First second of the bucket: the time the thumbnail is taken at.
    public static func time(forKey k: Int, duration: Double) -> Double { Double(k) * size(forDuration: duration) }

    /// Where the frame of a bucket is taken: a second before the end at the latest, because a seek to the very end has no frame to show.
    public static func captureTime(forKey k: Int, duration: Double) -> Double { min(time(forKey: k, duration: duration), max(0, duration - 1)) }
}

/// Debounce and coalescing for the previewer, with the clock passed in. Only the newest wanted time is kept, never a queue.
struct PreviewGate {
    enum Action: Equatable { case idle, wait(TimeInterval), fire(Double) }
    let debounce: TimeInterval
    private var pending: Double?
    private var last: TimeInterval = 0
    private var armed = false

    init(debounce: TimeInterval) { self.debounce = debounce }

    /// Records the latest wanted time. True when the caller must schedule a wake-up (none is armed yet).
    mutating func want(_ time: Double, now: TimeInterval) -> Bool {
        pending = time; last = now
        defer { armed = true }
        return !armed
    }

    /// The wake-up: fire the newest time once the pointer paused for `debounce`, or say how long to wait more.
    mutating func wake(now: TimeInterval) -> Action {
        guard let t = pending else { armed = false; return .idle }
        let due = last + debounce
        if now + 1e-9 < due { return .wait(due - now) }
        pending = nil; armed = false
        return .fire(t)
    }

    mutating func cancel() { pending = nil }
}
