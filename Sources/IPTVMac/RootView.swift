import SwiftUI
import IPTVCore

struct RootView: View {
    @Environment(AppModel.self) var model
    @State private var catFilter = ""

    var body: some View {
        @Bindable var model = model
        Group {
            if model.accounts.isEmpty { OnboardingView(isFirstRun: true) } else { main(model: $model) }
        }
        .sheet(isPresented: $model.showGuide) { OnboardingView(isFirstRun: false) }
        .sheet(item: $model.openSeries) { SeriesView(series: $0) }
        .sheet(item: $model.passwordPrompt) { PasswordPrompt(account: $0) }
        .overlay { if let r = model.playing, !model.pip, let pm = model.player { PlayerScreen(request: r, pm: pm) } }
    }

    @ViewBuilder
    private func main(model: Bindable<AppModel>) -> some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                TextField(L("cat.filter"), text: $catFilter).textFieldStyle(.roundedBorder).padding(8)
                List(selection: model.selectedCategory) {
                    Label(L("cat.all"), systemImage: "square.grid.2x2").tag("__all")
                    Label(L("cat.favorites"), systemImage: "star").tag("__fav")
                    Label(L("cat.continue"), systemImage: "clock").tag("__hist")
                    Section {
                        ForEach(model.wrappedValue.categories.filter {
                            catFilter.isEmpty || $0.name.localizedCaseInsensitiveContains(catFilter)
                        }) { c in Text(c.name).lineLimit(1).tag(c.remoteId) }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            VStack(spacing: 0) {
                UpdateBanner()
                if model.wrappedValue.syncing { ProgressView(L("sync.running")).padding(6) }
                if let m = model.wrappedValue.syncMessage {
                    Text("\(L("sync.failed")): \(m). \(L("sync.notUpdated"))").font(.caption).foregroundStyle(.red).padding(6)
                }
                ResultsView()
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
                    }.pickerStyle(.segmented).frame(width: 300)
                }
                ToolbarItem {
                    if model.wrappedValue.accounts.count > 1 {
                        Picker("", selection: model.account) {
                            ForEach(model.wrappedValue.accounts) { Text($0.name).tag(Optional($0)) }
                        }
                    }
                }
                ToolbarItem { Button { Task { await model.wrappedValue.sync() } } label: { Image(systemName: "arrow.clockwise") } }
            }
        }
    }
}
