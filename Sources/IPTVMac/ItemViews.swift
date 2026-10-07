import SwiftUI
import IPTVCore

/// Which playlist an item comes from; only shown while All playlists is on.
struct PlaylistBadge: View {
    @Environment(AppModel.self) var model
    let item: Item
    /// On a poster the badge sits on arbitrary artwork, so it gets its own dark ground instead of the system tint.
    var onArtwork = false
    var body: some View {
        if model.allPlaylists, let name = model.playlist(id: item.accountId)?.name {
            Text(name).font(.caption2.weight(.medium)).lineLimit(1)
                .foregroundStyle(onArtwork ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(onArtwork ? Color.black.opacity(0.62) : Color.primary.opacity(0.08), in: Capsule())
        }
    }
}

struct ChannelRow: View {
    @Environment(AppModel.self) var model
    let item: Item
    @State private var hover = false
    var body: some View {
        let isFav = model.isFavorite(item)
        let current = model.lastPlayedID == item.id
        HStack(spacing: 12) {
            Artwork(url: item.iconURL, symbol: "tv")
                .padding(4)
                .frame(width: 44, height: 44)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).lineLimit(1)
                if let now = model.epgTitle(item) { Text(now).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            }
            Spacer()
            PlaylistBadge(item: item)
            if item.tvArchive { Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary) }
            Button { model.toggleFavorite(item) } label: {
                Image(systemName: isFav ? "star.fill" : "star").contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain).foregroundStyle(isFav ? Color.yellow : Color.secondary)
            .accessibilityLabel(L(isFav ? "fav.remove" : "fav.add"))
            .motion(value: isFav)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(current ? Color.accentColor.opacity(hover ? 0.22 : 0.14) : Color.primary.opacity(hover ? 0.07 : 0))
        }
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .motion(.easeOut(duration: 0.12), value: hover)
        .onTapGesture { model.play(item) }
        .contextMenu { Button(model.isFavorite(item) ? L("fav.remove") : L("fav.add")) { model.toggleFavorite(item) } }
        .task { await model.loadEPGNow(item) }
    }
}

struct PosterCell: View {
    @Environment(AppModel.self) var model
    @Environment(\.accessibilityReduceMotion) private var reduce
    let item: Item
    @State private var hover = false
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        VStack(alignment: .leading, spacing: 6) {
            Color.clear.aspectRatio(2.0 / 3.0, contentMode: .fit)
                .overlay {
                    ZStack {
                        Rectangle().fill(placeholderFill)
                        Artwork(url: item.iconURL, symbol: "film", fill: true, symbolFont: .largeTitle)
                    }
                }
                .clipShape(shape)
                .overlay { shape.strokeBorder(Color.primary.opacity(hover ? 0.28 : 0.10), lineWidth: 1) }
                .overlay { if model.lastPlayedID == item.id { shape.strokeBorder(Color.accentColor, lineWidth: 3) } }
                .overlay(alignment: .topLeading) { PlaylistBadge(item: item, onArtwork: true).padding(5) }
                .shadow(color: .black.opacity(hover ? 0.35 : 0), radius: hover ? 10 : 0, y: hover ? 5 : 0)
                .scaleEffect(hover && !reduce ? 1.035 : 1)
            Text(item.name).font(.callout).lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
        }
        .contentShape(Rectangle())
        .zIndex(hover ? 1 : 0)
        .onHover { hover = $0 }
        .animation(reduce ? nil : .smooth(duration: 0.18), value: hover)
        .onTapGesture { model.play(item) }
        .contextMenu {
            Button(model.isFavorite(item) ? L("fav.remove") : L("fav.add")) { model.toggleFavorite(item) }
            if item.type == .movie { Button(L("downloads.add")) { model.download(item) } }
        }
    }
}

struct ResultsView: View {
    @Environment(AppModel.self) var model
    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 16)]

    private func title(_ t: ItemType) -> String {
        switch t { case .live: L("tab.live"); case .movie: L("tab.movies"); case .series: L("tab.series") }
    }

    var body: some View {
        let groups = Dictionary(grouping: model.results, by: \.type)
        let phase = model.results.isEmpty ? (model.syncing ? 1 : 0) : 2
        Group {
        if model.results.isEmpty && model.syncing {
            SkeletonResults(posters: model.tab != .live).transition(.opacity)
        } else if model.results.isEmpty {
            ContentUnavailableView {
                Label(L("empty.results"), systemImage: "magnifyingglass")
            } description: {
                if !model.searchText.isEmpty { Text("\u{201C}\(model.searchText)\u{201D}") }
            } actions: {
                if !model.searchText.isEmpty { Button(L("clear.confirm")) { model.searchText = "" } }
            }.transition(.opacity)
        } else {
            ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8, pinnedViews: .sectionHeaders) {
                    ForEach(ItemType.allCases, id: \.self) { t in
                        if let items = groups[t] {
                            Section {
                                if t == .live {
                                    ForEach(items) { ChannelRow(item: $0) }
                                } else {
                                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                                        ForEach(items) { PosterCell(item: $0) }
                                    }.padding(.horizontal, 12)
                                }
                            } header: {
                                if groups.count > 1 {
                                    Text(title(t)).font(.headline).padding(8)
                                        .frame(maxWidth: .infinity, alignment: .leading).background(.bar)
                                }
                            }
                        }
                    }
                }
            }
            .onAppear {   // back from the player: show the row that was playing instead of the top of the list
                guard let id = model.scrollTarget else { return }
                model.scrollTarget = nil
                let key: Int64? = id   // rows are identified by Item.id, an Optional: scrollTo must get the same type
                if model.results.contains(where: { $0.id == key }) { DispatchQueue.main.async { proxy.scrollTo(key, anchor: .center) } }
            }
            }.transition(.opacity)
        }
        }
        .motion(.easeOut(duration: 0.2), value: phase)
    }
}
