import SwiftUI
import IPTVPlayer

/// Playback speed: the presets as chips (reusing PlaybackSpeed, like the Mac picker), a slider for in-between values, and a reset.
struct SpeedSheet: View {
    let player: PhonePlayer
    @Environment(\.dismiss) private var dismiss
    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    Text(L("player.speed")).font(.headline)
                    Spacer()
                    Text(PlaybackSpeed.label(player.speed)).font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(player.speed == 1 ? Color.primary : .yellow)
                }
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(PlaybackSpeed.presets, id: \.self) { v in
                        let selected = abs(v - player.speed) < 0.001
                        Button { player.setSpeed(v); player.interact() } label: {
                            Text(PlaybackSpeed.label(v)).font(.body.weight(selected ? .bold : .regular).monospacedDigit())
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(selected ? Color.accentColor.opacity(0.9) : Color.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .foregroundStyle(selected ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                HStack(spacing: 10) {
                    Image(systemName: "tortoise.fill")
                    Slider(value: Binding(get: { player.speed }, set: { player.setSpeed($0) }), in: PlaybackSpeed.range)
                        .accessibilityLabel(L("player.speed")).accessibilityValue(PlaybackSpeed.label(player.speed))
                    Image(systemName: "hare.fill")
                }.foregroundStyle(.secondary)
                HStack {
                    Button(L("player.speedReset")) { player.setSpeed(1) }.buttonStyle(.bordered).squared().disabled(player.speed == 1)
                    Spacer()
                    Button(L("player.close")) { dismiss() }.buttonStyle(.borderedProminent).squared()
                }
            }
            .padding(20)
        }
        .presentationDetents([.height(340), .large])
        .presentationDragIndicator(.visible)
    }
}

/// Subtitle size and delay, applied while the sheet is open so the effect is seen on the picture behind it.
struct SubtitleAdjustSheet: View {
    let player: PhonePlayer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text(L("player.subtitleAdjust")).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
            Stepper(value: Binding(get: { player.subScale }, set: { player.subScale = (min(max($0, 0.5), 2) * 10).rounded() / 10 }), in: 0.5...2, step: 0.1) {
                HStack { Text(L("settings.subscale")); Spacer(); Text("\(Int((player.subScale * 100).rounded()))%").monospacedDigit().foregroundStyle(.secondary) }
            }
            Stepper(value: Binding(get: { player.subDelay }, set: { player.subDelay = (min(max($0, -10), 10) * 10).rounded() / 10 }), in: -10...10, step: 0.1) {
                HStack { Text(L("settings.subdelay")); Spacer(); Text(String(format: "%+.1f", player.subDelay)).monospacedDigit().foregroundStyle(.secondary) }
            }
            HStack {
                Button(L("player.speedReset")) { player.subScale = 1; player.subDelay = 0 }.buttonStyle(.bordered).squared().disabled(player.subScale == 1 && player.subDelay == 0)
                Spacer()
                Button(L("player.close")) { dismiss() }.buttonStyle(.borderedProminent).squared()
            }
        }
        .padding(20)
        .presentationDetents([.height(250), .medium])
        .presentationDragIndicator(.visible)
    }
}
