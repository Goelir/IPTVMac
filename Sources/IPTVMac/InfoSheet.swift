import SwiftUI
import IPTVCore

// What the provider says about a movie or series. Everything in it is untrusted: shown as plain text (`Text(verbatim:)`,
// never markdown or links), and the only thing ever opened is the YouTube link AppModel builds from a validated video id.

/// Poster with the look of the grid cells: placeholder ground, hairline border, artwork that fades in.
struct PosterImage: View {
    let url: URL?
    let width: CGFloat
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        Color.clear.aspectRatio(2.0 / 3.0, contentMode: .fit)
            .overlay { ZStack { Rectangle().fill(placeholderFill); Artwork(url: url, symbol: "film", fill: true, symbolFont: .largeTitle) } }
            .clipShape(shape)
            .overlay { shape.strokeBorder(Color.primary.opacity(0.10), lineWidth: 1) }
            .frame(width: width)
            .accessibilityHidden(true)
    }
}

/// Year, rating (a star and the number), duration and genre: whichever the provider has.
struct InfoMetaLine: View {
    let info: ItemInfo

    static func hasAny(_ i: ItemInfo) -> Bool { i.year != nil || i.rating != nil || i.durationMinutes != nil || i.genre != nil }

    static func duration(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return String(format: L("unit.minutesShort"), m) }
        if m == 0 { return String(format: L("unit.hoursShort"), h) }
        return String(format: L("unit.hoursShort"), h) + " " + String(format: L("unit.minutesShort"), m)
    }

    var body: some View {
        HStack(spacing: 14) {
            if let y = info.year {
                let label = "\(L("info.year")): \(y)"
                Text(String(y)).fixedSize().accessibilityLabel(label)
            }
            if let r = info.rating {
                let s = r.formatted(.number.precision(.fractionLength(1)))
                let label = "\(L("info.rating")): \(s)"
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").imageScale(.small).foregroundStyle(.yellow)
                    Text(s).monospacedDigit()
                }
                .fixedSize().accessibilityElement(children: .ignore).accessibilityLabel(label)
            }
            if let m = info.durationMinutes {
                let s = Self.duration(m)
                let label = "\(L("info.duration")): \(s)"
                Text(s).fixedSize().accessibilityLabel(label)
            }
            if let g = info.genre {
                let label = "\(L("info.genre")): \(g)"
                Text(verbatim: g).lineLimit(1).truncationMode(.tail).help(g).accessibilityLabel(label)
            }
        }
        .font(.callout).foregroundStyle(.secondary)
    }
}

struct InfoSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let item: Item
    @State private var phase = Phase.loading
    @State private var attempt = 0

    enum Phase: Equatable { case loading, loaded(ItemInfo), failed(String) }

    private var info: ItemInfo? { if case .loaded(let i) = phase { i } else { nil } }

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            PosterImage(url: item.iconURL ?? info?.posterURL, width: 180)
            VStack(alignment: .leading, spacing: 14) {
                header
                if let info { if InfoMetaLine.hasAny(info) { InfoMetaLine(info: info).transition(.opacity) } }
                else if phase == .loading { SkeletonBars(widths: [150], height: 12) }
                actions
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(24)
        .frame(minWidth: 640, idealWidth: 680, minHeight: 440, idealHeight: 480)
        .motion(value: phase)
        .task(id: attempt) { await load() }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.title2.weight(.semibold)).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                if let t = info?.title, t.caseInsensitiveCompare(item.name) != .orderedSame {
                    Text(verbatim: t).font(.callout).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 12)
            Button(L("player.close")) { dismiss() }.keyboardShortcut(.cancelAction)
        }
    }

    private var actions: some View {
        let fav = model.isFavorite(item)
        return HStack(spacing: 8) {
            Button { play() } label: { Label(L("info.play"), systemImage: "play.fill") }
                .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            if let info, info.trailerURL != nil {
                Button { model.openTrailer(info) } label: { Label(L("info.trailer"), systemImage: "play.rectangle") }
                    .buttonStyle(.bordered).transition(.opacity)
            }
            Button { model.toggleFavorite(item) } label: {
                Label(L(fav ? "fav.remove" : "fav.add"), systemImage: fav ? "star.fill" : "star").labelStyle(.iconOnly)
                    .foregroundStyle(fav ? Color.yellow : Color.primary)
            }
            .buttonStyle(.bordered).help(L(fav ? "fav.remove" : "fav.add"))
            if item.type == .movie {
                Button { model.download(item) } label: { Label(L("downloads.add"), systemImage: "arrow.down.circle").labelStyle(.iconOnly) }
                    .buttonStyle(.bordered).help(L("downloads.add"))
            }
        }
        .motion(value: fav)
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text(L("info.loading")).font(.callout).foregroundStyle(.secondary) }
                SkeletonBars(widths: [.infinity, .infinity, .infinity, 260, 0, 120, 200], height: 11)
            }
            .accessibilityElement(children: .ignore).accessibilityLabel(L("info.loading"))
            .transition(.opacity)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 10) {
                Label { Text(L("info.error")) } icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
                Text(message).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                Button(L("player.retry")) { attempt += 1 }.buttonStyle(.bordered)
            }
            .transition(.opacity)
        case .loaded(let i) where i.hasContent:
            facts(i).transition(.opacity)
        case .loaded:
            Label { Text(L("info.empty")) } icon: { Image(systemName: "info.circle") }
                .font(.callout).foregroundStyle(.secondary).transition(.opacity)
        }
    }

    private func facts(_ i: ItemInfo) -> some View {
        let rows = [(L("info.director"), i.director), (L("info.cast"), i.cast), (L("info.country"), i.country)].compactMap { l, v in v.map { (l, $0) } }
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let plot = i.plot {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("info.plot")).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).accessibilityAddTraits(.isHeader)
                        Text(verbatim: plot).lineSpacing(3).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if !rows.isEmpty {
                    Grid(alignment: .topLeading, horizontalSpacing: 14, verticalSpacing: 8) {
                        ForEach(rows, id: \.0) { label, value in
                            GridRow {
                                Text(label).foregroundStyle(.secondary)
                                Text(verbatim: value).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }.font(.callout)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func load() async {
        phase = .loading
        do {
            let i = try await model.loadInfo(item, refresh: attempt > 0)
            if !Task.isCancelled { phase = .loaded(i) }
        } catch {
            if !Task.isCancelled { phase = .failed(error.localizedDescription) }
        }
    }

    /// A movie plays at once. A series opens its episode list; that is a second sheet, which SwiftUI only shows once this one is gone.
    private func play() {
        let item = item, model = model
        dismiss()
        if item.type == .series {
            Task { try? await Task.sleep(for: .milliseconds(350)); model.play(item) }
        } else {
            model.play(item)
        }
    }
}

/// Grey bars standing in for text while the details load (they pulse slowly, or stay still with Reduce Motion).
private struct SkeletonBars: View {
    let widths: [CGFloat]      // .infinity = full width, 0 = a gap between paragraphs
    let height: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(widths.enumerated()), id: \.offset) { _, w in
                if w == 0 { Color.clear.frame(height: height) }
                else {
                    RoundedRectangle(cornerRadius: 3).fill(placeholderFill)
                        .frame(maxWidth: w == .infinity ? .infinity : w, minHeight: height, maxHeight: height)
                }
            }
        }
        .pulsing().accessibilityHidden(true)
    }
}

/// Top of the series screen: cover, meta line and the plot (scrolls when long).
struct SeriesHeader: View {
    let series: Item
    let info: ItemInfo

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            PosterImage(url: series.iconURL ?? info.posterURL, width: 84)
            VStack(alignment: .leading, spacing: 8) {
                if InfoMetaLine.hasAny(info) { InfoMetaLine(info: info) }
                if let plot = info.plot {
                    ViewThatFits(in: .vertical) {
                        Text(verbatim: plot).font(.callout)
                        ScrollView { Text(verbatim: plot).font(.callout).frame(maxWidth: .infinity, alignment: .leading) }
                    }
                    .textSelection(.enabled).frame(maxHeight: 84)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
