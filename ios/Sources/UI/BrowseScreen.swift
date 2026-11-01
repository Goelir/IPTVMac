import SwiftUI
import IPTVCore
import IPTVAppKit

/// One of Live / Movies / Series: large title, search with scopes, category chips, the list or the poster grid.
/// The shared model holds one result list (for the type that is open), so a screen that is not the open one draws nothing.
struct BrowseScreen: View {
    let type: ItemType
    @Environment(PhoneModel.self) private var model
    @State private var recents = RecentSearches().items

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Group {
                if model.tab == type { BrowseContent(type: type) } else { Color.clear }
            }
            .background(Brand.canvas)
            .navigationTitle(AppSection(type).title)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { PlaylistMenu() } }
            .searchable(text: $model.searchText, prompt: Text(L("search.prompt")))
            .searchScopes($model.scope, activation: .onSearchPresentation) {
                Text(L("scope.category")).tag(SearchScopeChoice.category)
                Text(L("scope.type")).tag(SearchScopeChoice.type)
                Text(L("scope.everywhere")).tag(SearchScopeChoice.everywhere)
            }
            .searchSuggestions {
                if model.searchText.isEmpty && !recents.isEmpty {
                    Section(L("search.recent")) {
                        ForEach(recents, id: \.self) { Label($0, systemImage: "clock.arrow.circlepath").searchCompletion($0) }
                        Button(L("clear.confirm"), role: .destructive) { RecentSearches().clear(); recents = [] }
                    }
                }
            }
            .onSubmit(of: .search) { RecentSearches().add(model.searchText); recents = RecentSearches().items }
            .onChange(of: model.searchText) { _, t in if t.isEmpty { recents = RecentSearches().items } }
        }
    }
}

/// Below the title: sync status, the chips, then the results. While searching the chips give way to the scope bar.
private struct BrowseContent: View {
    let type: ItemType
    @Environment(PhoneModel.self) private var model
    @Environment(UIState.self) private var ui
    @Environment(\.isSearching) private var searching

    var body: some View {
        VStack(spacing: 0) {
            if model.syncing && !ui.pulling {
                StatusStrip(kind: .busy, text: syncStatusText(model.syncProgress)).transition(.move(edge: .top).combined(with: .opacity))
            }
            if let m = model.syncMessage {
                StatusStrip(kind: .warning, text: "\(L("sync.failed")): \(m). \(L("sync.notUpdated"))", action: (L("player.retry"), { Task { await model.sync() } }))
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            if !searching { CategoryChips(type: type).transition(.opacity) }
            ResultsView(type: type)
        }
        .motion(value: model.syncing)
        .motion(value: model.syncMessage)
        .motion(value: searching)
    }
}

/// Playlist switcher (only with more than one source) and a refresh.
struct PlaylistMenu: View {
    @Environment(PhoneModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        @Bindable var model = model
        if model.accounts.count > 1 {
            Menu {
                Picker(L("playlist.label"), selection: $model.playlist) {
                    Label(L("playlist.all"), systemImage: "square.stack.3d.up").tag(Account?.none)
                    ForEach(model.accounts) { Text($0.name).tag(Optional($0)) }
                }.pickerStyle(.inline)
                Button { Task { await model.sync() } } label: { Label(L("sync.now"), systemImage: "arrow.clockwise") }.disabled(model.syncing)
            } label: {
                Image(systemName: model.allPlaylists ? "square.stack.3d.up.fill" : "square.stack.3d.up")
            }
            .accessibilityLabel(L("playlist.label"))
            .accessibilityValue(model.playlist?.name ?? L("playlist.all"))
        } else if sizeClass == .regular {
            Button { Task { await model.sync() } } label: { Image(systemName: "arrow.clockwise") }
                .disabled(model.syncing).accessibilityLabel(L("sync.now"))
        }
    }
}

// MARK: Category chips

private struct CategoryChips: View {
    let type: ItemType
    @Environment(PhoneModel.self) private var model
    @Environment(UIState.self) private var ui
    @State private var showAll = false
    @ScaledMetric(relativeTo: .subheadline) private var barHeight = 48

    private struct Chip: Identifiable { let tag: String; let title: String; var symbol: String?; var id: String { tag } }

    private var chips: [Chip] {
        var l = [Chip(tag: "__all", title: L("cat.all")), Chip(tag: "__fav", title: L("cat.favorites"), symbol: "star.fill")]
        if type != .live { l.append(Chip(tag: "__hist", title: L("cat.continue"), symbol: "clock.fill")) }
        let selected = model.categories.first { model.categoryTag($0) == model.selectedCategory }
        if let selected { l.append(Chip(tag: model.categoryTag(selected), title: selected.name)) }   // the choice stays in sight
        for c in model.categories.prefix(24) where c.id != selected?.id { l.append(Chip(tag: model.categoryTag(c), title: c.name)) }
        return l
    }

    var body: some View {
        HStack(spacing: 0) {
            Button { showAll = true } label: {
                Image(systemName: "line.3.horizontal.decrease").font(.system(size: 17, weight: .semibold))     // an icon: it does not grow with the text
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .accessibilityLabel(L("cat.title"))
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(chips) { c in
                            ChipButton(title: c.title, symbol: c.symbol, selected: model.selectedCategory == c.tag) {
                                Haptics.select(); model.selectedCategory = c.tag
                            }.id(c.tag)
                        }
                    }
                    .padding(.trailing, 16)
                }
                .onChange(of: model.selectedCategory) { _, tag in withAnimation(.smooth(duration: 0.25)) { proxy.scrollTo(tag, anchor: .center) } }
            }
        }
        .padding(.leading, 4)
        .frame(height: min(barHeight, 96))
        .background(.bar)
        .sheet(isPresented: $showAll) { CategorySheet() }
        .onChange(of: ui.debugSheet) { _, s in if s == "categories" { showAll = true } }
    }
}

struct ChipButton: View {
    let title: String
    var symbol: String?
    let selected: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol { Image(systemName: symbol).imageScale(.small) }
                Text(title).lineLimit(1)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(selected ? Color.white : Color.primary)
            .padding(.horizontal, 14).frame(minHeight: 34)
            .background(selected ? Color.accentColor : Brand.raised, in: Capsule())
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.95))
        .animation(reduce ? nil : .smooth(duration: 0.2), value: selected)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// Every category, with a field to filter them; grouped by playlist in All mode.
private struct CategorySheet: View {
    @Environment(PhoneModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    Section {
                        row("__all", L("cat.all"), "square.grid.2x2")
                        row("__fav", L("cat.favorites"), "star")
                        if model.tab != .live { row("__hist", L("cat.continue"), "clock") }
                    }.brandRows()
                }
                let cats = model.categories.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
                if model.allPlaylists {
                    ForEach(model.accounts) { a in
                        let mine = cats.filter { $0.accountId == a.id }
                        if !mine.isEmpty { Section(a.name) { ForEach(mine) { c in row(model.categoryTag(c), c.name, nil) } }.brandRows() }
                    }
                } else if !cats.isEmpty {
                    Section { ForEach(cats) { c in row(model.categoryTag(c), c.name, nil) } }.brandRows()
                } else if !query.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .scrollContentBackground(.hidden).background(Brand.canvas)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text(L("cat.filter")))
            .navigationTitle(L("cat.title")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("player.close")) { dismiss() } } }
        }
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible).formSheet()
    }

    private func row(_ tag: String, _ title: String, _ symbol: String?) -> some View {
        Button {
            Haptics.select(); model.selectedCategory = tag; dismiss()
        } label: {
            HStack {
                if let symbol { Image(systemName: symbol).foregroundStyle(Color.accentColor).frame(width: 24) }
                Text(title).foregroundStyle(.primary).lineLimit(2)
                Spacer()
                if model.selectedCategory == tag { Image(systemName: "checkmark").foregroundStyle(Color.accentColor).fontWeight(.semibold) }
            }
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityAddTraits(model.selectedCategory == tag ? [.isSelected] : [])
    }
}

// MARK: Results

struct ResultsView: View {
    let type: ItemType
    @Environment(PhoneModel.self) private var model

    var body: some View {
        let results = model.results
        let everywhere = model.scope == .everywhere && !model.searchText.isEmpty
        let stale = !everywhere && (results.first.map { $0.type != type } ?? false)   // the other section's list, for a frame after a tab change
        let phase = stale ? 3 : results.isEmpty ? (model.syncing ? 1 : 0) : 2
        Group {
            switch phase {
            case 3: Color.clear
            case 1: SkeletonResults(posters: type != .live).transition(.opacity)
            case 0: EmptyResults(type: type).transition(.opacity)
            default:
                if everywhere { GroupedItems(groups: ItemType.allCases.map { t in (t, results.filter { $0.type == t }) }).transition(.opacity) }
                else if type == .live { ChannelList(items: results).transition(.opacity) }
                else { PosterScroll(type: type, items: results).transition(.opacity) }
            }
        }
        .motion(.easeOut(duration: 0.2), value: phase)
    }
}

private struct EmptyResults: View {
    let type: ItemType
    @Environment(PhoneModel.self) private var model

    var body: some View {
        @Bindable var model = model
        if !model.searchText.isEmpty {
            ContentUnavailableView.search(text: model.searchText)
        } else if model.selectedCategory == "__fav" {
            ContentUnavailableView { Label(L("empty.favorites"), systemImage: "star") } description: { Text(L(type == .live ? "empty.favorites.live" : "empty.favorites.hint")) }
                actions: { Button(L("cat.all")) { model.selectedCategory = "__all" }.buttonStyle(.bordered) }
        } else if model.selectedCategory == "__hist" {
            ContentUnavailableView { Label(L("empty.continue"), systemImage: "clock") } description: { Text(L("empty.continue.hint")) }
                actions: { Button(L("cat.all")) { model.selectedCategory = "__all" }.buttonStyle(.bordered) }
        } else {
            ContentUnavailableView { Label(L("empty.none"), systemImage: AppSection(type).symbol) } description: { Text(L("empty.none.hint")) }
                actions: { Button(L("sync.now")) { Task { await model.sync() } }.buttonStyle(.borderedProminent) }
        }
    }
}

extension View {
    /// Pull to refresh: the system spinner is the progress, so the strip stays away meanwhile.
    func syncRefreshable(_ model: PhoneModel, _ ui: UIState) -> some View {
        refreshable {
            ui.pulling = true
            await model.sync()
            ui.pulling = false
            if model.syncMessage == nil { Haptics.success() } else { Haptics.failure() }
        }
    }
}

struct ChannelList: View {
    let items: [Item]
    @Environment(PhoneModel.self) private var model
    @Environment(UIState.self) private var ui

    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(items) { item in
                    ChannelRow(item: item)
                        .listRowBackground(ui.lastPlayedID == item.id ? Color.accentColor.opacity(0.12) : Color.clear)
                        .listRowSeparatorTint(Color.primary.opacity(0.08))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            let fav = model.isFavorite(item)
                            Button { Haptics.tap(); model.toggleFavorite(item) } label: { Label(L(fav ? "fav.remove" : "fav.add"), systemImage: fav ? "star.slash.fill" : "star.fill") }
                                .tint(.yellow)
                        }
                }
            }
            .listStyle(.plain).scrollContentBackground(.hidden)
            .syncRefreshable(model, ui)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: ui.scrollTarget) { _, id in scrollBack(proxy, id) }
            .onAppear { scrollBack(proxy, ui.scrollTarget) }
        }
    }

    private func scrollBack(_ proxy: ScrollViewProxy, _ id: Int64?) {
        guard let id else { return }
        ui.scrollTarget = nil
        let key: Int64? = id   // rows are identified by Item.id, an Optional: scrollTo must get the same type
        if items.contains(where: { $0.id == key }) { DispatchQueue.main.async { proxy.scrollTo(key, anchor: .center) } }
    }
}

struct PosterScroll: View {
    let type: ItemType
    let items: [Item]
    @Environment(PhoneModel.self) private var model
    @Environment(UIState.self) private var ui
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ScaledMetric private var scale = 1.0

    var body: some View {
        let shelf = model.selectedCategory == "__all" && model.searchText.isEmpty ? ui.continueEntries(type) : []
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    if !shelf.isEmpty { ContinueShelf(entries: shelf) }
                    LazyVGrid(columns: PosterGrid.columns(regular: sizeClass == .regular, scale: min(scale, 1.6)), spacing: 18) {
                        ForEach(items) { PosterCell(item: $0, entry: $0.id.flatMap { model.continueInfo[$0] }) }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 12).padding(.bottom, 24)
            }
            .syncRefreshable(model, ui)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: ui.scrollTarget) { _, id in scrollBack(proxy, id) }
            .onAppear { scrollBack(proxy, ui.scrollTarget) }
        }
    }

    private func scrollBack(_ proxy: ScrollViewProxy, _ id: Int64?) {
        guard let id else { return }
        ui.scrollTarget = nil
        let key: Int64? = id
        if items.contains(where: { $0.id == key }) { DispatchQueue.main.async { proxy.scrollTo(key, anchor: .center) } }
    }
}

/// Mixed results (search everywhere, the library): a section per type, channels as rows, titles as a grid.
struct GroupedSections: View {
    let groups: [(ItemType, [Item])]
    var alwaysHeaders = false
    var pinned = true
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ScaledMetric private var scale = 1.0

    var body: some View {
        let shown = groups.filter { !$0.1.isEmpty }
        ForEach(shown, id: \.0) { type, items in
            Section {
                if type == .live { ForEach(items) { ChannelRow(item: $0, inList: false) } }
                else {
                    LazyVGrid(columns: PosterGrid.columns(regular: sizeClass == .regular, scale: min(scale, 1.6)), spacing: 18) { ForEach(items) { PosterCell(item: $0) } }
                        .padding(.horizontal, 16).padding(.bottom, 12)
                }
            } header: {
                if shown.count > 1 || alwaysHeaders {
                    Text(AppSection(type).title).font(pinned ? .title3.weight(.semibold) : .subheadline.weight(.semibold)).foregroundStyle(pinned ? Color.primary : Color.secondary)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.horizontal, 16).padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading).background(pinned ? AnyShapeStyle(.bar) : AnyShapeStyle(.clear))
                }
            }
        }
    }
}

struct GroupedItems: View {
    let groups: [(ItemType, [Item])]
    var body: some View {
        ScrollView { LazyVStack(alignment: .leading, spacing: 8, pinnedViews: .sectionHeaders) { GroupedSections(groups: groups) } }
            .scrollDismissesKeyboard(.interactively)
    }
}
