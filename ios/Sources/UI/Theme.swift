import SwiftUI
import UIKit
import ImageIO
import IPTVCore

// The look of the app, in one place. Same family as the Mac app and the website (one violet, quiet surfaces, content first),
// built from iOS parts: system text styles (Dynamic Type), system materials for bars, semantic colors for text.

enum Brand {
    /// Light, dark, and the Increase Contrast versions of both (nil = the same as without it).
    private static func color(_ light: UInt32, _ dark: UInt32, high: (UInt32, UInt32)? = nil) -> Color {
        func ui(_ h: UInt32) -> UIColor { UIColor(red: CGFloat((h >> 16) & 255) / 255, green: CGFloat((h >> 8) & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: 1) }
        return Color(uiColor: UIColor { t in
            let d = t.userInterfaceStyle == .dark
            if let high, t.accessibilityContrast == .high { return ui(d ? high.1 : high.0) }
            return ui(d ? dark : light)
        })
    }
    /// Screen ground: a cool off-white, and a deep broadcast blue (the website's "On air" family, a little darker for long viewing).
    static let canvas = color(0xF4F6FA, 0x0B1426)
    /// Rows and grouped forms.
    static let surface = color(0xFFFFFF, 0x121E35, high: (0xFFFFFF, 0x18284A))
    /// Chips, logo tiles, the quiet fill under things.
    static let raised = color(0xE8ECF3, 0x1A2944, high: (0xD5DCE8, 0x2A3E64))
    /// Corner radii: small parts (chips, badges, buttons) and content (posters, cards). No capsules for controls.
    static let radiusSmall: CGFloat = 7
    static let radiusCard: CGFloat = 10
    /// The violet for text and glyphs (the fill violet is too dark for text on dark grounds).
    static let accentText = Color("AccentText")
}

// MARK: Motion and haptics

private struct MotionModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduce
    let animation: Animation, value: V
    func body(content: Content) -> some View { content.animation(reduce ? nil : animation, value: value) }
}

extension View {
    /// `.animation(_:value:)` that does nothing when Reduce Motion is on.
    func motion<V: Equatable>(_ animation: Animation = .smooth(duration: 0.25), value: V) -> some View { modifier(MotionModifier(animation: animation, value: value)) }
    func brandRows() -> some View { listRowBackground(Brand.surface) }
    /// The house button shape: small corners. Content buttons only: toolbar buttons keep the system's Liquid Glass capsule.
    func squared() -> some View { buttonBorderShape(.roundedRectangle(radius: Brand.radiusSmall)) }
    /// iPad: a centered form-sized sheet instead of a phone-style card hanging off one edge (iOS 18+; before that the system default).
    @ViewBuilder func formSheet() -> some View { if #available(iOS 18.0, *) { presentationSizing(.form) } else { self } }
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func press() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func failure() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

/// A press that answers: a small shrink, nothing at all with Reduce Motion.
struct PressStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    @Environment(\.accessibilityReduceMotion) private var reduce
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduce ? scale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(reduce ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: Placeholders

private struct Pulse: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var dim = false
    func body(content: Content) -> some View {
        content.opacity(dim && !reduce ? 0.45 : 1)
            .onAppear { if !reduce { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { dim = true } } }
    }
}
extension View { func pulsing() -> some View { modifier(Pulse()) } }

let placeholderFill = LinearGradient(colors: [Color.primary.opacity(0.10), Color.primary.opacity(0.04)], startPoint: .top, endPoint: .bottom)

/// Grey shapes where the first sync has not delivered anything yet (one pulse for the whole group).
struct SkeletonResults: View {
    let posters: Bool
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            if posters {
                LazyVGrid(columns: PosterGrid.columns(regular: sizeClass == .regular), spacing: 18) {
                    ForEach(0..<12, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(placeholderFill).aspectRatio(2.0 / 3.0, contentMode: .fit)
                            RoundedRectangle(cornerRadius: 3).fill(placeholderFill).frame(height: 10)
                            RoundedRectangle(cornerRadius: 3).fill(placeholderFill).frame(width: 60, height: 10)
                        }
                    }
                }.padding(.horizontal, 16).padding(.top, 8)
            } else {
                VStack(spacing: 14) {
                    ForEach(0..<9, id: \.self) { _ in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(placeholderFill).frame(width: 52, height: 52)
                            VStack(alignment: .leading, spacing: 8) {
                                RoundedRectangle(cornerRadius: 3).fill(placeholderFill).frame(width: 170, height: 12)
                                RoundedRectangle(cornerRadius: 3).fill(placeholderFill).frame(width: 110, height: 10)
                            }
                            Spacer()
                        }.padding(.horizontal, 16)
                    }
                }.padding(.vertical, 12)
            }
        }
        .scrollDisabled(true).pulsing().accessibilityHidden(true)
    }
}

// MARK: Artwork

/// Logos and posters: downloaded once, shrunk to what the screen needs (a provider's 1500 px poster would cost 9 MB of memory per cell),
/// kept in memory while scrolling and in the shared URL cache between launches ("Clear image cache" empties both).
final class ImageStore: @unchecked Sendable {
    static let shared = ImageStore()
    private let cache = NSCache<NSString, UIImage>()
    private let lock = NSLock()
    private var inflight: [String: Task<UIImage?, Never>] = [:]
    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.urlCache = URLCache.shared; c.requestCachePolicy = .returnCacheDataElseLoad
        c.timeoutIntervalForRequest = 15; c.httpMaximumConnectionsPerHost = 6
        return URLSession(configuration: c)
    }()
    init() { cache.totalCostLimit = 96 * 1024 * 1024 }

    private func key(_ url: URL, _ px: Int) -> String { "\(px)|\(url.absoluteString)" }
    func cached(_ url: URL, maxPixel px: Int) -> UIImage? { cache.object(forKey: key(url, px) as NSString) }
    func clear() { cache.removeAllObjects() }

    func image(_ url: URL, maxPixel px: Int) async -> UIImage? {
        let k = key(url, px)
        if let hit = cache.object(forKey: k as NSString) { return hit }
        lock.lock()
        let task: Task<UIImage?, Never>
        if let t = inflight[k] { task = t } else {
            task = Task.detached(priority: .utility) { [session, cache] in
                guard let (data, resp) = try? await session.data(from: url), (resp as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
                      data.count < 12_000_000 else { return nil }
                let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                                             kCGImageSourceThumbnailMaxPixelSize: px, kCGImageSourceShouldCacheImmediately: true]
                guard let src = CGImageSourceCreateWithData(data as CFData, nil), let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
                let img = UIImage(cgImage: cg)
                cache.setObject(img, forKey: k as NSString, cost: cg.width * cg.height * 4)
                return img
            }
            inflight[k] = task
        }
        lock.unlock()
        let img = await task.value
        lock.lock(); inflight[k] = nil; lock.unlock()
        return img
    }
}

enum DebugArt {
    /// Screenshots only: the demo provider runs on this Mac, and `Item.iconURL` rightly refuses local addresses.
    static func url(_ item: Item) -> URL? {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "demoImages"), let s = item.icon { return URL(string: s) }
        #endif
        return item.iconURL
    }
}

/// An image that fades in when it has loaded; `placeholder` shows before that and when there is none.
struct ArtworkImage<Placeholder: View>: View {
    let url: URL?
    var maxPixel = 480
    var fill = true
    @ViewBuilder let placeholder: () -> Placeholder
    @State private var image: UIImage?
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        ZStack {
            placeholder().opacity(image == nil ? 1 : 0).animation(reduce ? nil : .easeOut(duration: 0.12), value: image == nil)
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: fill ? .fill : .fit).transition(.opacity)
            }
        }
        .task(id: url) {
            guard let url else { image = nil; return }
            if let hit = ImageStore.shared.cached(url, maxPixel: maxPixel) { image = hit; return }
            image = nil
            let loaded = await ImageStore.shared.image(url, maxPixel: maxPixel)
            if !Task.isCancelled { withAnimation(reduce ? nil : .easeOut(duration: 0.25)) { image = loaded } }
        }
    }
}

/// What stands in for a missing logo or poster: the first letters on a tile whose hue comes from the name (always the same one).
struct Monogram: View {
    let name: String
    var font: Font = .headline

    static func initials(_ name: String) -> String {
        let words = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber })   // "  " has none
        let letters = words.prefix(2).compactMap(\.first)
        return (letters.isEmpty ? String(name.trimmingCharacters(in: .whitespaces).prefix(1)) : String(letters)).uppercased()
    }
    /// Teal to broadcast blue, quiet enough for a wall of them; stable across launches (Swift's own hash is not).
    static func hue(_ name: String) -> Double {
        var h: UInt32 = 5381
        for u in name.unicodeScalars { h = h &* 33 &+ u.value }
        return 0.50 + 0.18 * Double(h % 1000) / 1000
    }

    var body: some View {
        let h = Self.hue(name)
        ZStack {
            LinearGradient(colors: [Color(hue: h, saturation: 0.42, brightness: 0.66), Color(hue: (h + 0.03).truncatingRemainder(dividingBy: 1), saturation: 0.55, brightness: 0.40)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(Self.initials(name)).font(font.weight(.semibold)).foregroundStyle(.white).minimumScaleFactor(0.5).lineLimit(1).padding(4)
        }
        .accessibilityHidden(true)
    }
}

// MARK: Bars

/// Under the navigation bar: "Syncing…" and "Sync failed".
struct StatusStrip: View {
    enum Kind { case busy, warning }
    let kind: Kind
    let text: String
    var action: (title: String, run: () -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            switch kind {
            case .busy: ProgressView().controlSize(.small)
            case .warning: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).imageScale(.small)
            }
            Text(text).font(.footnote).lineLimit(3).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let action { Button(action.title, action: action.run).font(.footnote.weight(.semibold)).frame(minHeight: 44) }
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .contain)
    }
}

/// A slim progress bar; fills from the leading edge (so from the right in right-to-left languages).
struct ProgressBar: View {
    let value: Double
    var height: CGFloat = 4
    var track: Color = .white.opacity(0.35)
    var body: some View {
        let p = min(max(value, 0), 1)
        let bar = RoundedRectangle(cornerRadius: 1.5, style: .continuous)
        bar.fill(track).frame(height: height)
            .overlay(alignment: .leading) { GeometryReader { g in bar.fill(Color.accentColor).frame(width: max(height, g.size.width * p)) } }
            .accessibilityElement().accessibilityValue("\(Int(p * 100))%")
    }
}
