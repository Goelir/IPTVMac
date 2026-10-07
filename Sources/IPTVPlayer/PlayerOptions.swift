import Foundation

/// How the video fills the window; the raw value is the stored preference ("videoScale").
public enum VideoScale: String, CaseIterable {
    case fit, fill, stretch

    /// mpv `panscan`: 1 crops the picture until it fills the window.
    public var panscan: Double { self == .fill ? 1 : 0 }
    /// mpv `keepaspect`: off stretches the picture to the window.
    public var keepAspect: Bool { self != .stretch }
    public var next: VideoScale { self == .fit ? .fill : self == .fill ? .stretch : .fit }
}

/// How much the player reads ahead of the playback position; the raw value is the stored preference ("bufferSize").
/// `normal` is what the player always used.
public enum BufferSize: String, CaseIterable {
    case small, normal, large

    /// mpv `demuxer-max-bytes`.
    public var maxBytes: Int { self == .small ? 16 << 20 : self == .normal ? 64 << 20 : 256 << 20 }
    /// mpv `demuxer-readahead-secs`.
    public var readaheadSecs: Int { self == .small ? 8 : self == .normal ? 20 : 60 }
}

extension MPVPlayer {
    public func apply(_ s: VideoScale) {
        setProperty("panscan", String(s.panscan))
        setProperty("keepaspect", s.keepAspect ? "yes" : "no")
    }

    public func apply(_ b: BufferSize) {
        setProperty("demuxer-max-bytes", String(b.maxBytes))
        setProperty("demuxer-readahead-secs", String(b.readaheadSecs))
    }
}
