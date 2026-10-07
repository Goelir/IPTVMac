import SwiftUI
import IPTVPlayer

/// Controls-bar pill with the current playback speed; opens the scrolling speed picker.
struct SpeedButton: View {
    let speed: Double
    let set: (Double) -> Void
    @Binding var open: Bool

    var body: some View {
        let tint: Color = speed == 1 ? .white : .yellow
        Button { open.toggle() } label: {
            Text(PlaybackSpeed.label(speed)).font(.callout.weight(.bold)).monospacedDigit().foregroundStyle(tint)
                .frame(minWidth: 36).padding(.horizontal, 8).padding(.vertical, 3)
                .background { Capsule().fill(.yellow.opacity(speed == 1 ? 0 : 0.18)) }
                .overlay { Capsule().strokeBorder(tint.opacity(0.45)) }
                .contentShape(Capsule())
        }
        .help(L("player.speed"))
        .accessibilityLabel(L("player.speed")).accessibilityValue(PlaybackSpeed.label(speed))
        .popover(isPresented: $open, arrowEdge: .top) { SpeedPicker(speed: speed, set: set, close: { open = false }) }
    }
}

/// Telegram-style picker: a scrolling list of presets (the current one checked), a slider for in-between values and a reset.
struct SpeedPicker: View {
    let speed: Double
    let set: (Double) -> Void
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(L("player.speed")).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.vertical, 12)
            presets
            Divider()
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "tortoise.fill")
                    Slider(value: Binding(get: { speed }, set: set), in: PlaybackSpeed.range)
                        .accessibilityLabel(L("player.speed")).accessibilityValue(PlaybackSpeed.label(speed))
                    Image(systemName: "hare.fill")
                }.foregroundStyle(.secondary)
                HStack {
                    Button(L("player.speedReset")) { set(1); close() }.buttonStyle(.bordered).disabled(speed == 1)
                    Spacer()
                    Text(PlaybackSpeed.label(speed)).font(.title3.weight(.semibold)).monospacedDigit()
                }
            }.padding(14)
        }
        .frame(width: 250)
        .foregroundStyle(.primary)
    }

    private var presets: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(PlaybackSpeed.presets, id: \.self) { v in
                        SpeedRow(value: v, selected: abs(v - speed) < 0.001) { set(v); close() }.id(v)
                    }
                }.padding(.horizontal, 8).padding(.vertical, 16)
            }
            .frame(height: 196)
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.07),
                                         .init(color: .black, location: 0.93), .init(color: .clear, location: 1)],
                                 startPoint: .top, endPoint: .bottom))
            .onAppear { proxy.scrollTo(PlaybackSpeed.presets.min { abs($0 - speed) < abs($1 - speed) }, anchor: .center) }
        }
    }
}

private struct SpeedRow: View {
    let value: Double
    let selected: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark").font(.caption.weight(.bold)).frame(width: 14).opacity(selected ? 1 : 0)
                Text(PlaybackSpeed.label(value)).monospacedDigit()
                if value == 1 { Text(L("player.speedNormal")).opacity(0.65) }
                Spacer()
            }
            .font(.body.weight(selected ? .semibold : .regular))
            .foregroundStyle(selected ? Color.accentColor : .primary)
            .padding(.horizontal, 8).frame(height: 28)
            .background { RoundedRectangle(cornerRadius: 6).fill(selected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(hover ? 0.08 : 0)) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
