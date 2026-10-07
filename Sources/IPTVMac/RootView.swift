import SwiftUI
import IPTVCore

struct RootView: View {
    @Environment(AppModel.self) var model
    @State private var catFilter = ""
    @State private var columns = NavigationSplitViewVisibility.all

    var body: some View {
        @Bindable var model = model
        Group {
            if model.accounts.isEmpty { OnboardingView(isFirstRun: true) } else { main(model: $model) }
        }
        .sheet(isPresented: $model.showGuide) { OnboardingView(isFirstRun: false) }
        .sheet(item: $model.openSeries) { SeriesView(series: $0) }
        .sheet(isPresented: $model.showDownloads) { DownloadsView() }
        .sheet(item: $model.passwordPrompt) { PasswordPrompt(account: $0) }
    }

    @ViewBuilder
    private func main(model: Bindable<AppModel>) -> some View {
        NavigationSplitView(columnVisibility: $columns) {
            VStack(spacing: 0) {
                TextField(L("cat.filter"), text: $catFilter).textFieldStyle(.roundedBorder).padding(8)
                List(selection: model.selectedCategory) {
                    Label(L("cat.all"), systemImage: "square.grid.2x2").tag("__all")
                    Label(L("cat.favorites"), systemImage: "star").tag("__fav")
                    Label(L("cat.continue"), systemImage: "clock").tag("__hist")
                    let cats = model.wrappedValue.categories.filter { catFilter.isEmpty || $0.name.localizedCaseInsensitiveContains(catFilter) }
                    if model.wrappedValue.allPlaylists {
                        ForEach(model.wrappedValue.accounts) { a in       // one header per playlist
                            let mine = cats.filter { $0.accountId == a.id }
                            if !mine.isEmpty {
                                Section(a.name) {
                                    ForEach(mine) { c in Text(c.name).lineLimit(1).tag(model.wrappedValue.categoryTag(c)) }
                                }
                            }
                        }
                    } else {
                        Section {
                            ForEach(cats) { c in Text(c.name).lineLimit(1).tag(model.wrappedValue.categoryTag(c)) }
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            VStack(spacing: 0) {
                if let r = model.wrappedValue.playing, !model.wrappedValue.pip, let pm = model.wrappedValue.player {
                    // Inside the detail column: the tabs, search and Back stay in the toolbar while watching.
                    PlayerScreen(request: r, pm: pm)
                } else {
                    UpdateBanner()
                    if model.wrappedValue.syncing { ProgressView(L("sync.running")).padding(6) }
                    if let m = model.wrappedValue.syncMessage {
                        Text("\(L("sync.failed")): \(m). \(L("sync.notUpdated"))").font(.caption).foregroundStyle(.red).padding(6)
                    }
                    ResultsView()
                }
            }
            .searchable(text: model.searchText, prompt: L("search.prompt"))
            .searchScopes(model.scope) {
                Text(L("scope.category")).tag(SearchScopeChoice.category)
                Text(L("scope.type")).tag(SearchScopeChoice.type)
                Text(L("scope.everywhere")).tag(SearchScopeChoice.everywhere)
            }
            .toolbar {
                // Lives in the window toolbar, so it works whatever the video view covers.
                ToolbarItem(placement: .navigation) {
                    if model.wrappedValue.playing != nil {
                        Button { model.wrappedValue.stopPlayback() } label: { Label(L("player.back"), systemImage: "chevron.backward") }
                            .keyboardShortcut(.cancelAction).help(L("player.back"))
                    }
                }
                ToolbarItem(placement: .principal) {
                    Picker("", selection: model.tab) {
                        Text(L("tab.live")).tag(ItemType.live)
                        Text(L("tab.movies")).tag(ItemType.movie)
                        Text(L("tab.series")).tag(ItemType.series)
                    }.pickerStyle(.segmented).frame(width: 240)
                }
                ToolbarItem {
                    if model.wrappedValue.accounts.count > 1 {
                        Menu {
                            Picker(L("playlist.label"), selection: model.playlist) {
                                Label(L("playlist.all"), systemImage: "square.stack.3d.up").tag(Account?.none)
                                ForEach(model.wrappedValue.accounts) { Text($0.name).tag(Optional($0)) }
                            }.pickerStyle(.inline)
                        } label: {
                            Label(model.wrappedValue.playlist?.name ?? L("playlist.all"), systemImage: "square.stack.3d.up").labelStyle(.titleAndIcon)
                        }.help(L("playlist.label"))
                    }
                }
                ToolbarItem {
                    Button { model.wrappedValue.showDownloads = true } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down.circle")
                            if model.wrappedValue.downloads.activeCount > 0 { Text("\(model.wrappedValue.downloads.activeCount)").font(.caption).monospacedDigit() }
                        }
                    }.help(L("downloads.title"))
                }
                ToolbarItem { Button { Task { await model.wrappedValue.sync() } } label: { Image(systemName: "arrow.clockwise") }.disabled(model.wrappedValue.syncing) }
            }
        }
        .onChange(of: model.wrappedValue.playerFullscreen) { _, full in columns = full ? .detailOnly : .automatic }
    }
}
