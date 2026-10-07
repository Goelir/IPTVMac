import Foundation

/// The playback speeds the player offers: the preset list of the picker, the allowed range and the rounding of a free value.
public enum PlaybackSpeed {
    public static let presets: [Double] = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4]
    public static let range: ClosedRange<Double> = 0.25...4

    /// Clamped to `range` and rounded to 0.05, so the value shown and the value mpv gets are the same.
    public static func normalized(_ s: Double) -> Double {
        guard s.isFinite else { return 1 }
        return (min(max(s, range.lowerBound), range.upperBound) * 20).rounded() / 20
    }

    /// The next preset above (or below) `s`; a value between presets (1.15) steps to its neighbour, the ends stay put.
    public static func step(from s: Double, up: Bool) -> Double {
        let v = normalized(s)
        return (up ? presets.first { $0 > v } : presets.last { $0 < v }) ?? (up ? range.upperBound : range.lowerBound)
    }

    /// "1×", "1.5×", "0.25×" (always a dot, whatever the UI language).
    public static func label(_ s: Double) -> String { String(format: "%g×", s) }
}
