import SwiftUI

// Shared look of the app: quiet surfaces, one hover language, motion that switches off with Reduce Motion.
// Everything here is cheap enough for rows of a list that holds thousands of items (no timers, no blur).

/// `.animation(_:value:)` that does nothing when the user turned on Reduce Motion.
private struct MotionModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduce
    let animation: Animation
    let value: V
    func body(content: Content) -> some View { content.animation(reduce ? nil : animation, value: value) }
}

extension View {
    func motion<V: Equatable>(_ animation: Animation = .smooth(duration: 0.22), value: V) -> some View {
        modifier(MotionModifier(animation: animation, value: value))
    }
}

/// Soft background that appears under the pointer.
private struct HoverHighlight: ViewModifier {
    @State private var hover = false
    let radius: CGFloat
    func body(content: Content) -> some View {
        content
            .background { RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Color.primary.opacity(hover ? 0.07 : 0)) }
            .onHover { hover = $0 }
            .motion(.easeOut(duration: 0.12), value: hover)
    }
}

extension View {
    func hoverHighlight(radius: CGFloat = 8) -> some View { modifier(HoverHighlight(radius: radius)) }
}

/// Round icon button: a faint disc under the pointer, a darker one and a small press while clicked.
struct IconButtonStyle: ButtonStyle {
    var tint: Color = .primary
    var size: CGFloat = 28
    func makeBody(configuration: Configuration) -> some View { IconButtonBody(configuration: configuration, tint: tint, size: size) }
}

private struct IconButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let tint: Color
    let size: CGFloat
    @State private var hover = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        configuration.label
            .frame(width: size, height: size)
            .background(Circle().fill(tint.opacity(configuration.isPressed ? 0.28 : hover ? 0.16 : 0)))
            .scaleEffect(configuration.isPressed && !reduce ? 0.92 : 1)
            .opacity(enabled ? 1 : 0.4)
            .contentShape(Circle())
            .onHover { hover = $0 }
            .animation(reduce ? nil : .easeOut(duration: 0.12), value: hover)
            .animation(reduce ? nil : .easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// Thin bar under the toolbar for "syncing" and "sync failed".
struct StatusStrip: View {
    enum Kind { case busy, warning }
    let kind: Kind
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            switch kind {
            case .busy: ProgressView().controlSize(.small)
            case .warning: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
            Text(text).font(.callout).lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .combine)
    }
}

/// Download progress: a slim bar whose fill glides between updates. Grey while paused.
struct DownloadBar: View {
    let progress: Double
    var paused = false

    var body: some View {
        let p = min(max(progress, 0), 1)
        Capsule().fill(Color.primary.opacity(0.12))
            .frame(height: 5)
            .overlay {
                GeometryReader { g in
                    Capsule().fill(paused ? Color.secondary : Color.accentColor)
                        .frame(width: max(g.size.height, g.size.width * p))
                        .frame(maxWidth: .infinity, alignment: .leading)   // leading: fills from the right in right-to-left layouts
                }
            }
            .motion(.linear(duration: 0.4), value: p)
            .accessibilityElement()
            .accessibilityValue("\(Int(p * 100))%")
    }
}

// MARK: - Placeholders

/// One slow pulse for a whole group of placeholders (a single animation, not one per cell).
private struct Pulse: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var dim = false
    func body(content: Content) -> some View {
        content
            .opacity(dim && !reduce ? 0.45 : 1)
            .onAppear { if !reduce { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { dim = true } } }
    }
}

private extension View { func pulsing() -> some View { modifier(Pulse()) } }

let placeholderFill = LinearGradient(colors: [Color.primary.opacity(0.10), Color.primary.opacity(0.04)], startPoint: .top, endPoint: .bottom)

/// Skeleton shown instead of an empty screen while the first sync is still running.
struct SkeletonResults: View {
    let posters: Bool
    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 16)]

    var body: some View {
        ScrollView {
            if posters {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach(0..<12, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(placeholderFill).aspectRatio(2.0 / 3.0, contentMode: .fit)
                            RoundedRectangle(cornerRadius: 3).fill(placeholderFill).frame(height: 10)
                            RoundedRectangle(cornerRadius: 3).fill(placeholderFill).frame(width: 70, height: 10)
                        }
                    }
                }.padding(12)
            } else {
                VStack(spacing: 6) {
                    ForEach(0..<9, id: \.self) { _ in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(placeholderFill).frame(width: 44, height: 44)
                            VStack(alignment: .leading, spacing: 6) {
                                RoundedRectangle(cornerRadius: 3).fill(placeholderFill).frame(width: 180, height: 11)
                                RoundedRectangle(cornerRadius: 3).fill(placeholderFill).frame(width: 110, height: 9)
                            }
                            Spacer()
                        }.padding(.horizontal, 18).padding(.vertical, 6)
                    }
                }.padding(.vertical, 8)
            }
        }
        .scrollDisabled(true)
        .pulsing()
        .accessibilityHidden(true)
    }
}

/// Logo or poster that fades in when it has loaded; a calm symbol before that and when there is none.
struct Artwork: View {
    let url: URL?
    let symbol: String
    var fill = false
    var symbolFont: Font = .title3
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: reduce ? nil : .easeOut(duration: 0.25))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: fill ? .fill : .fit).transition(.opacity)
            default:
                Image(systemName: symbol).font(symbolFont).foregroundStyle(.tertiary)
            }
        }
    }
}
