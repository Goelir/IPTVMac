import Foundation
import CoreGraphics
import Observation
import IPTVPlayer

/// Which sources may get seek-bar previews. A preview is a second connection to the source: downloads (local files) always get it,
/// network sources only when the user allowed it (many providers allow one connection and a second one can break playback).
enum PreviewSource {
    static func path(for url: URL, isLive: Bool, networkAllowed: Bool) -> String? {
        guard !isLive else { return nil }
        if url.isFileURL || (url.scheme == nil && url.path.hasPrefix("/")) { return url.path }
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return networkAllowed ? url.absoluteString : nil
    }
}

/// What the hover bubble shows above the seek bar: the cached or latest frame, a neutral placeholder until the first one arrives,
/// or only the time when this item has no previews.
@MainActor @Observable
final class SeekPreview {
    enum Look: Equatable {
        case none, loading, image(CGImage)
        static func == (a: Look, b: Look) -> Bool {
            switch (a, b) {
            case (.none, .none), (.loading, .loading): true
            case (.image(let x), .image(let y)): x === y
            default: false
            }
        }
    }

    private(set) var image: CGImage?
    private var active = false
    var look: Look { image.map { .image($0) } ?? (active ? .loading : .none) }

    @ObservationIgnored private var previewer: SeekPreviewer?
    @ObservationIgnored private var failedForItem = false   // this item could not be opened: a plain seek bar until the next item
    @ObservationIgnored private var closed = false          // the player is closed: nothing is used any more
    @ObservationIgnored private var generation = 0          // frames of a previewer that was replaced or shut down are ignored
    @ObservationIgnored private var duration = 0.0
    @ObservationIgnored private let cache = NSCache<NSNumber, CGImage>()

    init() { cache.totalCostLimit = 6 << 20 }

    /// The pointer is over `time`. `source` is asked only when no previewer is running.
    func hover(_ time: Double, duration: Double, source: () -> String?) {
        guard !closed, !failedForItem, duration > 0, time.isFinite else { return }
        self.duration = duration
        let key = NSNumber(value: PreviewBuckets.key(time: time, duration: duration))
        let hit = cache.object(forKey: key)
        if let hit { image = hit }
        if previewer == nil {
            guard let path = source() else { image = nil; return }
            start(path)
        }
        if hit == nil { previewer?.request(PreviewBuckets.captureTime(forKey: key.intValue, duration: duration)) }
    }

    /// A frame arrived for the bucket of `time`.
    func received(time: Double, image: CGImage, duration: Double) {
        guard !closed else { return }
        cache.setObject(image, forKey: NSNumber(value: PreviewBuckets.key(time: time, duration: duration)), cost: image.bytesPerRow * image.height)
        self.image = image
    }

    /// Drops the engine (and its connection) but keeps the frames: Picture-in-Picture, or the player view going away.
    func release() { stop(); active = false }

    /// A new item: forget the old frames and give previews a new chance.
    func reset() { stop(); cache.removeAllObjects(); image = nil; active = false; failedForItem = false }

    func shutdown() { closed = true; reset() }

    private func stop() {
        generation += 1
        previewer?.shutdown()
        previewer = nil
    }

    private func start(_ path: String) {
        generation += 1
        let gen = generation
        active = true
        previewer = SeekPreviewer(source: path, onFrame: { [weak self] t, img in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.frame(gen, t, img) } }
        }, onFailure: { [weak self] in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.failed(gen) } }
        })
    }

    private func frame(_ gen: Int, _ t: Double, _ img: CGImage) {
        if gen == generation { received(time: t, image: img, duration: duration) }
    }

    private func failed(_ gen: Int) {
        guard gen == generation else { return }
        stop(); active = false; image = nil; failedForItem = true
    }
}
