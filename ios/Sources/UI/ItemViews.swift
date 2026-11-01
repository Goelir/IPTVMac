import SwiftUI
import IPTVCore
import IPTVAppKit

/// Which playlist an item comes from; only shown while All playlists is on.
struct PlaylistBadge: View {
    @Environment(PhoneModel.self) private var model
    let item: Item
    /// On a poster the badge sits on arbitrary artwork, so it gets its own dark ground.
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

// MARK: Channels

private struct ChannelLogo: View {
    let item: Item
    var body: some View {
        ZStack {
            Brand.raised
            ArtworkImage(url: DebugArt.url(item), maxPixel: 160, fill: false) { Monogram(name: item.name) }.padding(6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// What is on now (with how far along it is) and what comes next, when the provider has a guide for the channel.
private struct ProgramLine: View {
    @Environment(PhoneModel.self) private var model
    @Environment(\.dynamicTypeSize) private var type
    let item: Item
    var body: some View {
        let p = model.epgPrograms(item)
        if let now = p.now, type.isAccessibilitySize {              // big text: the titles get the room, the bar goes
            VStack(alignment: .leading, spacing: 2) {
                Text(now.title).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                if let next = p.next { Text("\(L("epg.next")): \(next.title)").font(.caption).foregroundStyle(.secondary).lineLimit(2) }
            }
        } else if let now = p.now {
            VStack(alignment: .leading, spacing: 4) {
                Text(now.title).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 8) {
                    ProgressBar(value: now.end > now.start ? Date().timeIntervalSince(now.start) / now.end.timeIntervalSince(now.start) : 0,
                                height: 3, track: Color.primary.opacity(0.12)).frame(width: 56)
                    if let next = p.next { Text("\(L("epg.next")): \(next.title)").font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                }
            }
        }
    }
}

struct ChannelRow: View {
    let item: Item
    /// In a List the swipe action toggles the favorite; elsewhere the row carries a star button.
    var inList = true
    @Environment(PhoneModel.self) private var model
    @Environment(UIState.self) private var ui
    @ScaledMetric(relativeTo: .body) private var logo = 52

    var body: some View {
        let fav = model.isFavorite(item)
        let current = ui.lastPlayedID == item.id
        HStack(spacing: 4) {
            Button { Haptics.tap(); RecentSearches().add(model.searchText); model.play(item) } label: {
                HStack(spacing: 12) {
                    ChannelLogo(item: item).frame(width: min(logo, 76), height: min(logo, 76))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name).font(.body.weight(.medium)).foregroundStyle(current ? Brand.accentText : Color.primary).lineLimit(2)
                        ProgramLine(item: item)
                    }
                    Spacer(minLength: 6)
                    PlaylistBadge(item: item)
                    if item.tvArchive { Image(systemName: "clock.arrow.circlepath").imageScale(.small).foregroundStyle(.secondary) }
                    if fav && inList { Image(systemName: "star.fill").imageScale(.small).foregroundStyle(.yellow) }
                }
                .padding(.vertical, 4).frame(minHeight: 56).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if !inList {
                Button { Haptics.tap(); model.toggleFavorite(item) } label: {
                    Image(systemName: fav ? "star.fill" : "star").foregroundStyle(fav ? Color.yellow : Color.secondary).frame(width: 44, height: 44)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain).accessibilityLabel(L(fav ? "fav.remove" : "fav.add"))
            }
        }
        .padding(.horizontal, inList ? 0 : 16)
        .background(!inList && current ? Color.accentColor.opacity(0.12) : Color.clear)
        .contextMenu {
            Button { model.play(item) } label: { Label(L("info.play"), systemImage: "play.fill") }
            Button { Haptics.tap(); model.toggleFavorite(item) } label: { Label(L(fav ? "fav.remove" : "fav.add"), systemImage: fav ? "star.slash" : "star") }
        }
        .accessibilityAction(named: Text(L(fav ? "fav.remove" : "fav.add"))) { model.toggleFavorite(item) }
        .accessibilityValue(fav ? L("cat.favorites") : "")
        .task(id: item.id) { await model.loadEPGNow(item) }
    }
}

// MARK: Posters

struct PosterImage: View {
    let item: Item
    var url: URL?
    var maxPixel = 420
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        Color.clear.aspectRatio(2.0 / 3.0, contentMode: .fit)
            .overlay { ArtworkImage(url: url ?? DebugArt.url(item), maxPixel: maxPixel) { Monogram(name: item.name, font: .title2) } }
            .clipShape(shape)
            .overlay { shape.strokeBorder(Color.primary.opacity(0.10), lineWidth: 1) }
            .accessibilityHidden(true)
    }
}

struct PosterCell: View {
    let item: Item
    /// Set on the Continue watching page: the episode and the minute the title was left at. A tap resumes it.
    var entry: ContinueEntry? = nil
    @Environment(PhoneModel.self) private var model
    @Environment(UIState.self) private var ui

    var body: some View {
        let fav = model.isFavorite(item)
        let current = ui.lastPlayedID == item.id
        let caption = entry.flatMap { $0.caption(episode: L("series.epShort"), left: L("downloads.eta"), minutes: L("unit.minutesShort")) }
        Button { RecentSearches().add(model.searchText); if let entry { model.resume(entry) } else { ui.open(item, model: model) } } label: {
            VStack(alignment: .leading, spacing: 6) {
                PosterImage(item: item)
                    .overlay(alignment: .topLeading) { PlaylistBadge(item: item, onArtwork: true).padding(5) }
                    .overlay(alignment: .topTrailing) {
                        if fav { Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow).padding(5).background(Color.black.opacity(0.62), in: Circle()).padding(5) }
                    }
                    .overlay { if current { RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.accentColor, lineWidth: 3) } }
                    .overlay(alignment: .bottom) {
                        if let f = entry?.fraction { ProgressBar(value: f).padding(.horizontal, 8).padding(.bottom, 8).shadow(color: .black.opacity(0.4), radius: 2, y: 1) }
                    }
                Text(item.name).font(.subheadline).foregroundStyle(.primary).lineLimit(entry == nil ? 2 : 1, reservesSpace: entry == nil).multilineTextAlignment(.leading)
                if let caption { Text(caption).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel([item.name, caption].compactMap { $0 }.joined(separator: ", "))
        .contextMenu {
            if item.type == .movie { Button { model.play(item) } label: { Label(L("info.play"), systemImage: "play.fill") } }
            if model.hasInfo(item) && item.type == .movie { Button { ui.openInfo = item } label: { Label(L("info.details"), systemImage: "info.circle") } }
            Button { Haptics.tap(); model.toggleFavorite(item) } label: { Label(L(fav ? "fav.remove" : "fav.add"), systemImage: fav ? "star.slash" : "star") }
        }
        .accessibilityAction(named: Text(L(fav ? "fav.remove" : "fav.add"))) { model.toggleFavorite(item) }
        .accessibilityValue(fav ? L("cat.favorites") : "")
    }
}

/// Titles that were started and not finished, with how far along they are.
struct ContinueShelf: View {
    let entries: [ContinueEntry]
    @ScaledMetric private var width = 128.0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("cat.continue")).font(.title3.weight(.semibold)).accessibilityAddTraits(.isHeader).padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(entries) { ContinueCard(entry: $0).frame(width: min(width, 200)) }
                }.padding(.horizontal, 16)
            }
        }
    }
}

private struct ContinueCard: View {
    let entry: ContinueEntry
    @Environment(PhoneModel.self) private var model

    var body: some View {
        let label = entry.caption(episode: L("series.epShort"), left: L("downloads.eta"), minutes: L("unit.minutesShort"))
        Button { model.resume(entry) } label: {
            VStack(alignment: .leading, spacing: 6) {
                PosterImage(item: entry.item)
                    .overlay(alignment: .bottom) {
                        if let f = entry.fraction { ProgressBar(value: f).padding(.horizontal, 8).padding(.bottom, 8).shadow(color: .black.opacity(0.4), radius: 2, y: 1) }
                    }
                Text(entry.item.name).font(.subheadline).foregroundStyle(.primary).lineLimit(1)
                if let label { Text(label).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([entry.item.name, label].compactMap { $0 }.joined(separator: ", "))
        .accessibilityValue(entry.fraction.map { "\(Int($0 * 100))%" } ?? "")
        .accessibilityAddTraits(.isButton)
    }
}
