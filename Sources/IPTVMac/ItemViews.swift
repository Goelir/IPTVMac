import SwiftUI
import IPTVCore

struct ChannelRow: View {
    @Environment(AppModel.self) var model
    let item: Item
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: item.iconURL) { $0.resizable().scaledToFit() } placeholder: {
                Image(systemName: "tv").foregroundStyle(.secondary)
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).lineLimit(1)
                if let now = model.epgNow[item.streamId] { Text(now).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            }
            Spacer()
            if item.tvArchive { Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary) }
            Button { model.toggleFavorite(item) } label: {
                Image(systemName: model.isFavorite(item) ? "star.fill" : "star")
            }.buttonStyle(.plain).foregroundStyle(model.isFavorite(item) ? .yellow : .secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { model.play(item) }
        .contextMenu { Button(model.isFavorite(item) ? L("fav.remove") : L("fav.add")) { model.toggleFavorite(item) } }
        .task { await model.loadEPGNow(item) }
    }
}

struct PosterCell: View {
    @Environment(AppModel.self) var model
    let item: Item
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: item.iconURL) { $0.resizable().scaledToFill() } placeholder: {
                Rectangle().fill(.quaternary).overlay(Image(systemName: "film").foregroundStyle(.secondary))
            }
            .aspectRatio(2.0 / 3.0, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 8))
            Text(item.name).font(.callout).lineLimit(2)
        }
        .contentShape(Rectangle())
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
        if model.results.isEmpty && !model.syncing {
            ContentUnavailableView(L("empty.results"), systemImage: "magnifyingglass")
        } else {
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
        }
    }
}
