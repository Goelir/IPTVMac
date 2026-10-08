import SwiftUI
import IPTVPlayer

/// The numbers behind the seek bar and its hover bubble, kept out of the views so they can be tested.
enum SeekBarMath {
    /// 0...1 for a pointer at `x` on a bar `width` wide; garbage (NaN, infinity, a bar without width) is 0.
    static func fraction(x: CGFloat, width: CGFloat) -> Double {
        guard x.isFinite, width.isFinite, width > 0 else { return 0 }
        return min(max(Double(x / width), 0), 1)
    }

    static func fraction(of value: Double, in total: Double) -> Double {
        guard value.isFinite, total.isFinite, total > 0 else { return 0 }
        return min(max(value / total, 0), 1)
    }

    static func time(x: CGFloat, width: CGFloat, duration: Double) -> Double {
        duration.isFinite && duration > 0 ? fraction(x: x, width: width) * duration : 0
    }

    /// Left edge of the bubble in the player's coordinates: centred on the marker, `margin` away from both edges of the player.
    /// A bubble wider than the player sticks to the left margin.
    static func bubbleLeft(center: CGFloat, width: CGFloat, container: CGFloat, margin: CGFloat) -> CGFloat {
        max(margin, min(center - width / 2, container - width - margin))
    }

    /// Where the bubble's little pointer sits inside the bubble: under the marker, but `inset` away from the rounded corners.
    static func pointerX(center: CGFloat, left: CGFloat, width: CGFloat, inset: CGFloat) -> CGFloat {
        max(inset, min(center - left, width - inset))
    }

    /// "1:05", or "1:02:05" from one hour on.
    static func format(_ seconds: Double) -> String {
        let t = seconds.isFinite ? Int(max(seconds, 0)) : 0
        return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t % 3600 / 60, t % 60) : String(format: "%d:%02d", t / 60, t % 60)
    }
}

/// Progress bar of the player: click or drag to seek, hover to see where (a marker and, when the item has them, a thumbnail).
/// It always runs left to right, also in right-to-left languages, like the bar of any video player.
struct SeekBar: View {
    let position: Double
    let duration: Double
    let preview: SeekPreview
    /// Width of the player the bubble has to stay inside (0 = not known yet).
    let containerWidth: CGFloat
    /// True while the pointer is over the bar or the bar is dragged: the controls must stay visible.
    @Binding var active: Bool
    let onSeek: (Double) -> Void
    /// The time under the pointer, for the thumbnail.
    let onHover: (Double) -> Void
    /// Accessibility: +1 or -1 skip step.
    let onSkip: (Double) -> Void

    @State private var hoverX: CGFloat?
    @State private var shownX: CGFloat = 0            // the last pointer position, so the bubble can fade out where it was
    @State private var dragging = false
    @State private var dragFraction = 0.0
    @State private var settling: Double?              // the fraction just seeked to, shown until the player's position catches up
    @State private var lastSeek = Date.distantPast
    @State private var size = CGSize(width: 1, height: 24)
    @State private var frame = CGRect.zero             // in the player's coordinate space ("player")
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let height: CGFloat = 24
    private static let margin: CGFloat = 8
    /// The bubble's tip floats this far above the bar: the controls panel's own padding (8) plus a gap.
    private static let lift: CGFloat = 14

    private var width: CGFloat { max(size.width, 1) }
    private var hovering: Bool { hoverX != nil || dragging }
    private var fraction: Double { dragging ? dragFraction : settling ?? SeekBarMath.fraction(of: position, in: duration) }

    var body: some View {
        let h: CGFloat = hovering ? 6 : 4
        let thumb: CGFloat = hovering ? 14 : 10
        ZStack(alignment: .leading) {
            Capsule().fill(.white.opacity(0.22)).frame(height: h)
            if let x = hoverX, duration > 0 {
                Capsule().fill(.white.opacity(0.4)).frame(width: min(max(x, 0), width), height: h)
            }
            Capsule().fill(.white).frame(width: width * fraction, height: h)
            Circle().fill(.white).frame(width: thumb, height: thumb).offset(x: width * fraction - thumb / 2)
                .shadow(color: .black.opacity(0.3), radius: 2)
            if let x = hoverX, duration > 0 {
                RoundedRectangle(cornerRadius: 1).fill(.white).frame(width: 2, height: 16).offset(x: min(max(x, 0), width) - 1)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovering)
        .frame(height: Self.height)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            guard !dragging else { return }
            switch phase {
            case .active(let p): move(to: p.x)
            case .ended: hoverX = nil
            }
        }
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { v in
                guard duration > 0 else { return }
                dragging = true
                move(to: v.location.x)
                dragFraction = SeekBarMath.fraction(x: v.location.x, width: width)
                if Date().timeIntervalSince(lastSeek) > 0.1 { lastSeek = Date(); onSeek(dragFraction * duration) }
            }
            .onEnded { v in
                guard dragging else { return }
                let f = SeekBarMath.fraction(x: v.location.x, width: width)
                onSeek(f * duration)
                settling = f
                dragging = false
                if !CGRect(origin: .zero, size: size).insetBy(dx: 0, dy: -12).contains(v.location) { hoverX = nil }   // released away from the bar
            })
        .onChange(of: position) { if let f = settling, abs(position - f * duration) < 2 { settling = nil } }
        .task(id: settling) {   // or give up waiting for the player
            guard settling != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            settling = nil
        }
        .onChange(of: hovering) { active = hovering }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("player")) } action: { frame = $0 }
        .overlay(alignment: .bottomLeading) { bubble }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("player.seekBar"))
        .accessibilityValue(String(format: L("player.seekValue"), SeekBarMath.format(position), SeekBarMath.format(duration)))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onSkip(1)
            case .decrement: onSkip(-1)
            @unknown default: break
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func move(to x: CGFloat) {
        hoverX = x
        shownX = min(max(x, 0), width)
        if duration > 0 { onHover(SeekBarMath.time(x: x, width: width, duration: duration)) }
    }

    @ViewBuilder private var bubble: some View {
        let look = preview.look
        let w = SeekBubble.width(for: look)
        let center = frame.minX + shownX
        let left = containerWidth > 0 ? SeekBarMath.bubbleLeft(center: center, width: w, container: containerWidth, margin: Self.margin) : center - w / 2
        let visible = hoverX != nil && duration > 0
        SeekBubble(time: SeekBarMath.format(SeekBarMath.time(x: shownX, width: width, duration: duration)), look: look,
                   pointerX: SeekBarMath.pointerX(center: center, left: left, width: w, inset: SeekBubble.cornerInset))
            .opacity(visible ? 1 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: visible)   // only the fade animates, not the movement
            .offset(x: left - frame.minX, y: -(Self.height + Self.lift))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The floating card above the bar: thumbnail (or a neutral placeholder) and the time, with a pointer toward the marker.
private struct SeekBubble: View {
    let time: String
    let look: SeekPreview.Look
    let pointerX: CGFloat

    static let thumb = CGSize(width: 176, height: 99)
    static let pad: CGFloat = 6
    static let radius: CGFloat = 10
    static let pointer = CGSize(width: 12, height: 5)
    static let cornerInset = radius + pointer.width / 2
    /// Fixed sizes, so the bubble neither jumps when the frame arrives nor needs measuring to stay inside the player.
    static func width(for look: SeekPreview.Look) -> CGFloat { look == .none ? 72 : thumb.width + 2 * pad }

    var body: some View {
        VStack(spacing: 5) {
            switch look {
            case .none: EmptyView()
            case .loading: RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.white.opacity(0.08)).frame(width: Self.thumb.width, height: Self.thumb.height)
            case .image(let cg):
                Image(decorative: cg, scale: 1).resizable().interpolation(.medium).aspectRatio(contentMode: .fit)
                    .frame(width: Self.thumb.width, height: Self.thumb.height).background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            Text(time).font(.system(size: 12, weight: .medium).monospacedDigit()).foregroundStyle(.white)
        }
        .padding(look == .none ? EdgeInsets(top: 5, leading: 6, bottom: 5, trailing: 6) : EdgeInsets(top: Self.pad, leading: Self.pad, bottom: Self.pad + 1, trailing: Self.pad))
        .padding(.bottom, Self.pointer.height)
        .frame(width: Self.width(for: look))
        .background { BubbleShape(radius: Self.radius, pointerX: pointerX, pointer: Self.pointer).fill(.black.opacity(0.82)) }
        .overlay { BubbleShape(radius: Self.radius, pointerX: pointerX, pointer: Self.pointer).stroke(.white.opacity(0.14), lineWidth: 1) }
        .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
    }
}

/// A rounded rectangle with a small triangle under its bottom edge, drawn as one outline so the stroke has no seam.
private struct BubbleShape: Shape {
    let radius: CGFloat
    let pointerX: CGFloat
    let pointer: CGSize

    func path(in r: CGRect) -> Path {
        let b = CGRect(x: r.minX, y: r.minY, width: r.width, height: max(r.height - pointer.height, 0))
        let px = max(b.minX + radius + pointer.width / 2, min(r.minX + pointerX, b.maxX - radius - pointer.width / 2))
        var p = Path()
        p.move(to: CGPoint(x: b.minX + radius, y: b.minY))
        p.addArc(tangent1End: CGPoint(x: b.maxX, y: b.minY), tangent2End: CGPoint(x: b.maxX, y: b.maxY), radius: radius)
        p.addArc(tangent1End: CGPoint(x: b.maxX, y: b.maxY), tangent2End: CGPoint(x: b.minX, y: b.maxY), radius: radius)
        p.addLine(to: CGPoint(x: px + pointer.width / 2, y: b.maxY))
        p.addLine(to: CGPoint(x: px, y: b.maxY + pointer.height))
        p.addLine(to: CGPoint(x: px - pointer.width / 2, y: b.maxY))
        p.addArc(tangent1End: CGPoint(x: b.minX, y: b.maxY), tangent2End: CGPoint(x: b.minX, y: b.minY), radius: radius)
        p.addArc(tangent1End: CGPoint(x: b.minX, y: b.minY), tangent2End: CGPoint(x: b.maxX, y: b.minY), radius: radius)
        p.closeSubpath()
        return p
    }
}
