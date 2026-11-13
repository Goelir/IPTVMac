import SwiftUI
import IPTVPlayer

/// Feedback for the touch gestures: the skip ripple on the side that was tapped, the brightness/volume level, a centred toast
/// (video scale), the 2x badge while holding, and the time card while dragging to scrub. All of it is `allowsHitTesting(false)`.
struct PlayerHUD: View {
    let player: PhonePlayer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let skip = player.skipHUD { SkipRipple(side: skip.side, label: skip.label).id(skip.id).transition(.opacity) }
            if let level = player.levelHUD { LevelHUD(kind: level.kind, value: level.value).transition(.opacity) }
            if let drag = player.dragScrub {
                SeekBubble(time: SeekBarMath.format(drag.time), delta: delta(drag.delta), look: player.preview.look)
                    .frame(maxHeight: .infinity, alignment: .top).padding(.top, 56)
                    .transition(.opacity)
            }
            if player.boosting {
                Label("2×", systemImage: "forward.fill").font(.callout.weight(.semibold).monospacedDigit()).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8).playerSurface(radius: 16)
                    .frame(maxHeight: .infinity, alignment: .top).padding(.top, 56).transition(.opacity)
            }
            if let toast = player.toast {
                HStack(spacing: 8) {
                    if let s = toast.symbol { Image(systemName: s) }
                    Text(toast.text)
                }
                .font(.callout.weight(.semibold)).foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 10).playerSurface(radius: 16)
                .id(toast.id).transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: player.skipHUD?.id)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: player.toast?.id)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: player.levelHUD == nil)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: player.dragScrub == nil)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: player.boosting)
        .allowsHitTesting(false)
    }

    private func delta(_ d: Double) -> String { (d < 0 ? "\u{2212}" : "+") + SeekBarMath.format(abs(d)) }
}

/// A soft half-disc on the tapped side with the running total ("+10", "+20"...). With Reduce Motion it only fades.
private struct SkipRipple: View {
    let side: PlayerGestures.Side
    let label: String
    @State private var grown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { g in
            let left = side == .left
            let w = g.size.width / 2
            ZStack {
                Circle().fill(.white.opacity(0.14))
                    .frame(width: g.size.height * 1.8, height: g.size.height * 1.8)
                    .scaleEffect(reduceMotion || grown ? 1 : 0.5)
                    .offset(x: left ? -w / 2 : w / 2)
                VStack(spacing: 4) {
                    Image(systemName: left ? "backward.fill" : "forward.fill").font(.title2)
                    Text(label).font(.headline.monospacedDigit())
                }
                .foregroundStyle(.white).shadow(color: .black.opacity(0.4), radius: 4)
            }
            .frame(width: w, height: g.size.height)
            .clipped()
            .frame(width: g.size.width, height: g.size.height, alignment: left ? .leading : .trailing)
        }
        .environment(\.layoutDirection, .leftToRight)      // the side is the physical side of the tap, in every language
        .onAppear { withAnimation(.easeOut(duration: 0.3)) { grown = true } }
    }
}

/// Brightness (left edge) and volume (right edge): a slim vertical level with its icon.
private struct LevelHUD: View {
    let kind: PhonePlayer.LevelKind
    let value: Double

    var body: some View {
        let left = kind == .brightness
        VStack(spacing: 10) {
            Image(systemName: icon).font(.callout).frame(width: 24, height: 24)
            ZStack(alignment: .bottom) {
                Capsule().fill(.white.opacity(0.25))
                Capsule().fill(.white).frame(height: max(6, 110 * value))
            }
            .frame(width: 6, height: 110)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 14).padding(.horizontal, 12)
        .playerSurface(radius: 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: left ? .leading : .trailing)
        .padding(left ? .leading : .trailing, 28)
        .environment(\.layoutDirection, .leftToRight)      // brightness on the physical left, volume on the right, in every language
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L(left ? "player.brightness" : "player.volume"))
        .accessibilityValue("\(Int((value * 100).rounded()))%")
    }

    private var icon: String {
        if kind == .brightness { return value < 0.5 ? "sun.min.fill" : "sun.max.fill" }
        return value == 0 ? "speaker.slash.fill" : value < 0.34 ? "speaker.wave.1.fill" : value < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
    }
}
