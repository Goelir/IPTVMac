import SwiftUI
import SafariServices
import IPTVCore
import IPTVAppKit

// What the provider says about a title is untrusted: shown as plain text (`Text(verbatim:)`, never markdown), and the only link
// ever opened is the YouTube address the model builds from a validated video id.

struct TrailerLink: Identifiable { let url: URL; var id: URL { url } }

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
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
        // wraps instead of truncating at large text sizes
        let parts: [(String, String, String?)] = [
            info.year.map { (String($0), "\(L("info.year")): \($0)", nil) },
            info.rating.map { let s = $0.formatted(.number.precision(.fractionLength(1))); return (s, "\(L("info.rating")): \(s)", "star.fill") },
            info.durationMinutes.map { let s = Self.duration($0); return (s, "\(L("info.duration")): \(s)", nil) },
            info.genre.map { ($0, "\(L("info.genre")): \($0)", nil) },
        ].compactMap { $0 }
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { ForEach(parts.indices, id: \.self) { chip(parts[$0]) } }
            VStack(alignment: .leading, spacing: 4) { ForEach(parts.indices, id: \.self) { chip(parts[$0]) } }
        }
        .font(.subheadline).foregroundStyle(.secondary)
    }

    private func chip(_ p: (String, String, String?)) -> some View {
        HStack(spacing: 3) {
            if let sym = p.2 { Image(systemName: sym).imageScale(.small).foregroundStyle(.yellow) }
            Text(verbatim: p.0).monospacedDigit().lineLimit(1)
        }
        .fixedSize().accessibilityElement(children: .ignore).accessibilityLabel(p.1)
    }
}

private struct SkeletonBars: View {
    let widths: [CGFloat]      // .infinity = full width, 0 = a gap between paragraphs
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(widths.indices, id: \.self) { i in
                if widths[i] == 0 { Color.clear.frame(height: 8) }
                else { RoundedRectangle(cornerRadius: 3).fill(placeholderFill).frame(maxWidth: widths[i] == .infinity ? .infinity : widths[i], minHeight: 11, maxHeight: 11) }
            }
        }.pulsing().accessibilityHidden(true)
    }
}

/// The favorite and trailer buttons beside Play, as round bordered buttons (44 pt).
private struct IconAction: View {
    let symbol: String
    let label: String
    var tint: Color = .primary
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.body.weight(.semibold)).foregroundStyle(tint).frame(width: 48, height: 48)
                .background(Brand.raised, in: Circle()).contentShape(Circle())
        }
        .buttonStyle(PressStyle(scale: 0.92)).accessibilityLabel(label)
    }
}

/// Play beside the round buttons; with big text the round buttons move under it (a button that wraps its label mid-word is no button).
private struct ActionRow<Primary: View, Secondary: View>: View {
    @ViewBuilder let primary: Primary
    @ViewBuilder let secondary: Secondary
    @Environment(\.dynamicTypeSize) private var type
    var body: some View {
        if type.isAccessibilitySize { VStack(alignment: .leading, spacing: 10) { primary; HStack(spacing: 10) { secondary } } }
        else { HStack(spacing: 10) { primary; secondary } }
    }
}

/// Poster beside the text; with big text the poster sits above it (the text would otherwise be squeezed into a sliver).
private struct HeaderStack<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.dynamicTypeSize) private var type
    var body: some View {
        if type.isAccessibilitySize { VStack(alignment: .leading, spacing: 12) { content } }
        else { HStack(alignment: .top, spacing: 16) { content } }
    }
}

/// A movie (or any title that is not a series): poster, facts and a Play button.
struct DetailSheet: View {
    @Environment(PhoneModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let item: Item
    @State private var phase = Phase.loading
    @State private var attempt = 0
    @State private var trailer: TrailerLink?

    enum Phase: Equatable { case loading, loaded(ItemInfo), failed(String), unavailable }
    private var info: ItemInfo? { if case .loaded(let i) = phase { i } else { nil } }

    var body: some View {
        let fav = model.isFavorite(item)
        let resumable = model.progress(accountId: item.accountId, type: item.type, streamId: item.streamId) > 0
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HeaderStack {
                        PosterImage(item: item, url: DebugArt.url(item) ?? info?.posterURL, maxPixel: 480).frame(width: 112)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.name).font(.title2.weight(.bold)).fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                            if let t = info?.title, t.caseInsensitiveCompare(item.name) != .orderedSame { Text(verbatim: t).font(.subheadline).foregroundStyle(.secondary) }
                            if let info, InfoMetaLine.hasAny(info) { InfoMetaLine(info: info).transition(.opacity) }
                            else if phase == .loading { SkeletonBars(widths: [140]) }
                            PlaylistBadge(item: item)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ActionRow {
                        if model.playing?.item?.id != item.id {   // opened from the player: "Play" would only restart the movie that is playing
                            Button { Haptics.press(); dismiss(); model.play(item) } label: {
                                HStack(spacing: 8) { Image(systemName: "play.fill"); Text(L(resumable ? "info.resume" : "info.play")) }.font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 36)
                            }
                            .buttonStyle(.borderedProminent).squared().controlSize(.large)
                        }
                    } secondary: {
                        if let url = info?.trailerURL { IconAction(symbol: "play.rectangle", label: L("info.trailer")) { trailer = TrailerLink(url: url) }.transition(.opacity) }
                        IconAction(symbol: fav ? "star.fill" : "star", label: L(fav ? "fav.remove" : "fav.add"), tint: fav ? .yellow : .primary) {
                            Haptics.tap(); model.toggleFavorite(item)
                        }
                    }
                    .motion(value: fav)
                    content
                }
                .padding(16).padding(.top, 4)
            }
            .background(alignment: .top) { backdrop }
            .background(Brand.canvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").symbolRenderingMode(.hierarchical).font(.title2).frame(width: 44, height: 44) }
                        .accessibilityLabel(L("player.close"))
                }
            }
        }
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible).formSheet()
        .motion(value: phase)
        .task(id: attempt) { await load() }
        .sheet(item: $trailer) { SafariView(url: $0.url).ignoresSafeArea() }
    }

    @ViewBuilder private var backdrop: some View {
        if let url = info?.backdropURL {
            ArtworkImage(url: url, maxPixel: 900) { Color.clear }
                .frame(height: 280).clipped().opacity(0.4)
                .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
                .accessibilityHidden(true).transition(.opacity)
        }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .unavailable: EmptyView()
        case .loading:
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text(L("info.loading")).font(.callout).foregroundStyle(.secondary) }
                SkeletonBars(widths: [.infinity, .infinity, .infinity, 240, 0, 120, 200])
            }.accessibilityElement(children: .ignore).accessibilityLabel(L("info.loading"))
        case .failed(let message):
            VStack(alignment: .leading, spacing: 10) {
                Label { Text(L("info.error")) } icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
                Text(message).font(.caption).foregroundStyle(.secondary)
                Button(L("player.retry")) { attempt += 1 }.buttonStyle(.bordered).squared()
            }
        case .loaded(let i) where i.hasContent: facts(i)
        case .loaded: Label { Text(L("info.empty")) } icon: { Image(systemName: "info.circle") }.font(.callout).foregroundStyle(.secondary)
        }
    }

    private func facts(_ i: ItemInfo) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if let plot = i.plot {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("info.plot")).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).accessibilityAddTraits(.isHeader)
                    Text(verbatim: plot).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                }
            }
            ForEach([(L("info.director"), i.director), (L("info.cast"), i.cast), (L("info.country"), i.country)].compactMap { l, v in v.map { (l, $0) } }, id: \.0) { label, value in
                VStack(alignment: .leading, spacing: 3) {
                    Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Text(verbatim: value).font(.callout).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func load() async {
        guard model.hasInfo(item) else { phase = .unavailable; return }
        if attempt == 0, let c = await model.cachedInfo(item) { phase = .loaded(c) } else { phase = .loading }
        do {
            let i = try await model.loadInfo(item, refresh: attempt > 0)
            if !Task.isCancelled { phase = .loaded(i) }
        } catch {
            if !Task.isCancelled, info == nil { phase = .failed(error.localizedDescription) }
        }
    }
}

/// A series: cover, facts, what to watch next, and the episodes by season with how far each one is.
struct SeriesScreen: View {
    @Environment(PhoneModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let series: Item
    @State private var episodes: [Episode] = []
    @State private var progress: [String: EpisodeProgress] = [:]
    @State private var info: ItemInfo?
    @State private var loading = true
    @State private var error: String?
    @State private var season = 1
    @State private var trailer: TrailerLink?
    @State private var attempt = 0

    private var seasons: [Int] { Array(Set(episodes.map(\.season))).sorted() }
    private var upNext: (episode: Episode, resume: Bool)? { WatchProgress.upNext(episodes, progress: progress) }

    var body: some View {
        NavigationStack {
            List {
                Section { header }.listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                if loading {
                    Section { HStack { Spacer(); ProgressView(); Spacer() }.padding(.vertical, 24) }.listRowBackground(Color.clear)
                } else if let error {
                    Section {
                        ContentUnavailableView { Label(L("info.error"), systemImage: "exclamationmark.triangle.fill") } description: { Text(error) }
                            actions: { Button(L("player.retry")) { attempt += 1 }.buttonStyle(.bordered).squared() }
                    }.listRowBackground(Color.clear)
                } else if episodes.isEmpty {
                    Section { ContentUnavailableView(L("series.noEpisodes"), systemImage: "rectangle.stack") }.listRowBackground(Color.clear)
                } else {
                    if seasons.count > 1 { Section { seasonChips }.listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
                    Section { ForEach(episodes.filter { $0.season == season }.sorted { $0.number < $1.number }) { episodeRow($0) } }.brandRows()
                }
            }
            .listStyle(.insetGrouped).scrollContentBackground(.hidden).background(Brand.canvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").symbolRenderingMode(.hierarchical).font(.title2).frame(width: 44, height: 44) }
                        .accessibilityLabel(L("player.close"))
                }
            }
        }
        .presentationDetents([.large]).presentationDragIndicator(.visible).formSheet()
        .motion(value: loading)
        .task(id: attempt) { await load() }
        .sheet(item: $trailer) { SafariView(url: $0.url).ignoresSafeArea() }
    }

    private var header: some View {
        let fav = model.isFavorite(series)
        return VStack(alignment: .leading, spacing: 14) {
            HeaderStack {
                PosterImage(item: series, url: DebugArt.url(series) ?? info?.posterURL, maxPixel: 420).frame(width: 100)
                VStack(alignment: .leading, spacing: 8) {
                    Text(series.name).font(.title2.weight(.bold)).fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                    if let info, InfoMetaLine.hasAny(info) { InfoMetaLine(info: info) }
                    PlaylistBadge(item: series)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let plot = info?.plot { Text(verbatim: plot).font(.callout).lineLimit(5).fixedSize(horizontal: false, vertical: true) }
            ActionRow {
                if let next = upNext {
                    Button { play(next.episode) } label: {
                        HStack(spacing: 8) { Image(systemName: "play.fill"); Text(String(format: L(next.resume ? "series.continueEp" : "series.playEp"), next.episode.season, next.episode.number)) }
                            .font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.borderedProminent).squared().controlSize(.large)
                }
            } secondary: {
                if let url = info?.trailerURL { IconAction(symbol: "play.rectangle", label: L("info.trailer")) { trailer = TrailerLink(url: url) } }
                IconAction(symbol: fav ? "star.fill" : "star", label: L(fav ? "fav.remove" : "fav.add"), tint: fav ? .yellow : .primary) { Haptics.tap(); model.toggleFavorite(series) }
            }
            .motion(value: fav)
        }
    }

    private var seasonChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(seasons, id: \.self) { s in
                    ChipButton(title: "\(L("series.season")) \(s)", selected: season == s) { Haptics.select(); season = s }
                }
            }.padding(.horizontal, 16)
        }
    }

    private func episodeRow(_ e: Episode) -> some View {
        let p = progress[e.streamId]
        let isNext = upNext?.episode.streamId == e.streamId
        return Button { play(e) } label: {
            HStack(spacing: 12) {
                Text("\(e.number)").font(.body.weight(.semibold).monospacedDigit()).foregroundStyle(.secondary).frame(minWidth: 30, alignment: .trailing)
                VStack(alignment: .leading, spacing: 4) {
                    Text(e.title).foregroundStyle(.primary).lineLimit(2).multilineTextAlignment(.leading)
                    if isNext { Text(L("next.title")).font(.caption.weight(.semibold)).foregroundStyle(Brand.accentText) }
                    if let p, !p.isWatched, p.fraction > 0.01 {
                        HStack(spacing: 8) {
                            ProgressBar(value: p.fraction, height: 3, track: Color.primary.opacity(0.12)).frame(maxWidth: 140)
                            Text(String(format: L("downloads.eta"), String(format: L("unit.minutesShort"), max(1, Int(((p.duration - p.position) / 60).rounded(.up))))))
                                .font(.caption).foregroundStyle(.secondary).monospacedDigit().lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 8)
                if p?.isWatched == true { Image(systemName: "checkmark.circle.fill").foregroundStyle(.secondary).accessibilityLabel(L("series.watched")) }
                else { Image(systemName: "play.fill").imageScale(.small).foregroundStyle(isNext ? Color.accentColor : Color.secondary.opacity(0.6)).accessibilityHidden(true) }
            }
            .frame(minHeight: 48).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityElement(children: .combine)
    }

    private func play(_ e: Episode) { Haptics.press(); dismiss(); model.playEpisode(e, of: series) }

    private func load() async {
        loading = true; error = nil
        guard let a = model.playlist(id: series.accountId) else { error = IPTVError.badConfig.localizedDescription; loading = false; return }
        info = await model.cachedInfo(series)        // from an earlier visit; the episodes request below refreshes it for free
        do {
            episodes = try await SyncService(db: model.db).episodes(account: a, password: a.id.flatMap { model.secrets.password(for: $0) }, seriesId: series.streamId)
            progress = (try? await model.db.dbQueue.read { try WatchProgress.episodeProgress($0, accountId: series.accountId) }) ?? [:]
            season = upNext?.episode.season ?? seasons.first ?? 1
        } catch { self.error = error.localizedDescription }
        loading = false
        if let fresh = await model.cachedInfo(series) { info = fresh }
    }
}
