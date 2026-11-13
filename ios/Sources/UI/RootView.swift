import SwiftUI
import StoreKit
import IPTVCore
import IPTVAppKit

/// First run: the welcome and add-source flow. Afterwards: tabs on a phone, a split view with the categories in the sidebar on an iPad
/// (and a large phone turned sideways). The player covers everything while something plays.
struct RootView: View {
    @Environment(PhoneModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hiddenCategoryWords") private var hiddenWords = ""
    /// The layout follows the size class, except while the player is open: on a Plus or Pro Max the player turns the phone to landscape,
    /// which would swap the tabs for the split view underneath and lose the place in the list.
    @State private var split: Bool?
    @State private var ui = UIState()
    @AppStorage("appearance") private var appearance = "system"
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        @Bindable var model = model
        @Bindable var ui = ui
        Group {
            if model.accounts.isEmpty { OnboardingView() }
            else if split ?? (sizeClass == .regular) { SplitLayout() }
            else { TabLayout() }
        }
        .preferredColorScheme(appearance == "light" ? .light : appearance == "dark" ? .dark : nil)
        .overlay { if let p = model.player { PlayerScreen(player: p).transition(.opacity) } }
        .environment(ui)                     // after the overlay: the player opens the details sheets too
        .sheet(item: $model.openSeries) { SeriesScreen(series: $0) }
        .sheet(item: $ui.openInfo) { DetailSheet(item: $0) }
        .sheet(item: $model.passwordPrompt) { PasswordSheet(account: $0) }
        .onChange(of: model.playing?.id) {
            if let item = model.playing?.item { ui.lastPlayedID = item.id }
            if model.playing != nil { model.openSeries = nil; ui.openInfo = nil } else { ui.scrollTarget = ui.lastPlayedID }
            // the App Store rating request: only right after the player closed, never while watching (ReviewPrompt has the rules)
            if model.playing == nil, ReviewPrompt().shouldAsk(version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") {
                Task { try? await Task.sleep(for: .seconds(1)); if model.playing == nil { requestReview() } }   // after the player's fade-out, unless something started again
            }
        }
        .onChange(of: ui.section) {
            model.searchText = ""
            if let t = ui.section.itemType, t != model.tab { model.tab = t }
        }
        .onChange(of: sizeClass) { if model.player == nil { split = sizeClass == .regular } }
        .onChange(of: model.player == nil) { _, closed in
            guard closed else { return }   // the phone turns back after the player; then catch up with anything that changed meanwhile
            Task { try? await Task.sleep(for: .seconds(1)); if model.player == nil { split = sizeClass == .regular } }
        }
        .onChange(of: scenePhase) { _, phase in
            // "Only when the app opens": iOS usually resumes the app instead of starting it again, so coming back counts as opening
            // once the last sync is more than 6 hours old
            guard phase == .active, model.refreshHours == 0, !model.syncing, !model.accounts.isEmpty, model.playing == nil,
                  Date().timeIntervalSince(model.lastSync ?? .distantPast) > 6 * 3600 else { return }
            Task { await model.sync() }
        }
        .task(id: ContinueKey(all: model.allPlaylists, account: model.account?.id, syncing: model.syncing, idle: model.playing == nil, count: model.accounts.count, removed: model.continueChanged, hidden: hiddenWords)) {
            await ui.reloadContinue(model)
        }
        .task {
            #if DEBUG
            await DebugLaunch.run(model, ui)
            #endif
        }
    }

    private struct ContinueKey: Hashable { var all: Bool; var account: Int64?; var syncing: Bool; var idle: Bool; var count: Int; var removed: Int; var hidden: String }
}

// MARK: iPhone

private struct TabLayout: View {
    @Environment(UIState.self) private var ui

    var body: some View {
        @Bindable var ui = ui
        TabView(selection: $ui.section) {
            ForEach(AppSection.allCases, id: \.self) { s in
                Group {
                    switch s {
                    case .live, .movies, .series: BrowseScreen(type: s.itemType ?? .live)
                    case .library: LibraryScreen()
                    case .settings: SettingsScreen()
                    }
                }
                .tabItem { Label(s.title, systemImage: s.symbol) }
                .tag(s)
            }
        }
    }
}

// MARK: iPad, and a large phone in landscape

private struct SplitLayout: View {
    @Environment(UIState.self) private var ui
    @State private var columns = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            Sidebar()
        } detail: {
            switch ui.section {
            case .live, .movies, .series: BrowseScreen(type: ui.section.itemType ?? .live)
            case .library: LibraryScreen()
            case .settings: SettingsScreen()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

private enum SidebarItem: Hashable { case section(AppSection), category(String) }

private struct Sidebar: View {
    @Environment(PhoneModel.self) private var model
    @Environment(UIState.self) private var ui
    @State private var filter = ""

    private var selection: Binding<SidebarItem?> {
        Binding(
            get: {
                if ui.section.itemType != nil, model.selectedCategory != "__all" { return .category(model.selectedCategory) }
                return .section(ui.section)
            },
            set: { new in
                switch new {
                case .section(let s):
                    if s.itemType != nil, ui.section == s { model.selectedCategory = "__all" }
                    ui.section = s
                case .category(let tag): model.selectedCategory = tag
                case nil: break
                }
            })
    }

    var body: some View {
        List(selection: selection) {
            Section {
                ForEach([AppSection.live, .movies, .series], id: \.self) { s in
                    Label(s.title, systemImage: s.symbol).tag(SidebarItem.section(s)).font(.body.weight(.semibold))
                    if ui.section == s { children(for: s) }
                }
            }
            Section {
                Label(AppSection.library.title, systemImage: AppSection.library.symbol).tag(SidebarItem.section(.library))
                Label(AppSection.settings.title, systemImage: AppSection.settings.symbol).tag(SidebarItem.section(.settings))
            }
        }
        .navigationTitle(L("app.name"))
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Brand.canvas)
    }

    @ViewBuilder private func children(for s: AppSection) -> some View {
        let cats = model.categories.filter { filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter) }
        Label(L("cat.favorites"), systemImage: "star").tag(SidebarItem.category("__fav")).padding(.leading, 12)
        if s != .live { Label(L("cat.continue"), systemImage: "clock").tag(SidebarItem.category("__hist")).padding(.leading, 12) }
        if model.categories.count > 8 {
            TextField(L("cat.filter"), text: $filter).textFieldStyle(.roundedBorder).font(.subheadline).padding(.leading, 12)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
        }
        if model.allPlaylists {
            ForEach(model.accounts) { a in
                let mine = cats.filter { $0.accountId == a.id }
                if !mine.isEmpty {
                    Text(a.name).font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.leading, 12).padding(.top, 6)
                    ForEach(mine) { c in Text(c.name).lineLimit(1).tag(SidebarItem.category(model.categoryTag(c))).padding(.leading, 12) }
                }
            }
        } else {
            ForEach(cats) { c in Text(c.name).lineLimit(1).tag(SidebarItem.category(model.categoryTag(c))).padding(.leading, 12) }
        }
    }
}
