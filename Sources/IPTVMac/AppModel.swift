import Foundation
import Observation
import GRDB
import IPTVCore

enum SearchScopeChoice: String, CaseIterable { case category, type, everywhere }

struct PlayRequest: Identifiable {
    let id = UUID()
    var title: String
    var url: URL
    var isLive: Bool
    var item: Item?
    var episodeKey: String?     // history key for episodes: "ep:<episodeId>"
    var start: Double = 0
}

@MainActor @Observable
final class AppModel {
    let db: AppDatabase
    let secrets: SecretStore = KeychainSecretStore()
    var accounts: [Account] = []
    var account: Account? { didSet { favoriteKeys = []; loadCategories(); loadFavorites(); scheduleSearch() } }
    var tab: ItemType = .live { didSet { selectedCategory = "__all"; loadCategories(); scheduleSearch() } }
    var categories: [IPTVCore.Category] = []
    var selectedCategory = "__all" { didSet { scheduleSearch() } }
    var searchText = "" { didSet { scheduleSearch() } }
    var scope: SearchScopeChoice = .category { didSet { scheduleSearch() } }
    var results: [Item] = []
    var syncing = false
    var syncMessage: String?
    var playing: PlayRequest?
    var openSeries: Item?
    var showGuide = false
    var favoriteKeys: Set<String> = []
    var epgNow: [String: String] = [:]
    private var searchTask: Task<Void, Never>?

    init() {
        do { db = try AppDatabase(path: try AppDatabase.defaultPath()) }
        catch { fatalError("Cannot open database: \(error)") }
    }

    func start() async {
        loadAccounts()
        if account != nil { await sync() }
    }

    func loadAccounts() {
        accounts = (try? db.dbQueue.read { try Account.order(Column("id")).fetchAll($0) }) ?? []
        if account == nil || !accounts.contains(where: { $0.id == account?.id }) { account = accounts.first }
    }

    func loadCategories() {
        guard let aid = account?.id else { categories = []; return }
        let t = tab
        categories = (try? db.dbQueue.read {
            try IPTVCore.Category.filter(Column("accountId") == aid && Column("type") == t.rawValue).order(Column("id")).fetchAll($0)
        }) ?? []
    }

    func loadFavorites() {
        guard let aid = account?.id else { return }
        favoriteKeys = (try? db.dbQueue.read { try UserData.favoriteKeys($0, accountId: aid) }) ?? []
    }

    func scheduleSearch() {
        searchTask?.cancel()
        guard let aid = account?.id else { results = []; return }
        let text = searchText, tab = tab, cat = selectedCategory, scope = scope
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(text.isEmpty ? 0 : 100))
            if Task.isCancelled { return }
            let rows: [Item] = (try? await db.dbQueue.read { d in
                if text.isEmpty && cat == "__fav" { return try UserData.favorites(d, accountId: aid, type: tab) }
                if text.isEmpty && cat == "__hist" { return try UserData.continueWatching(d, accountId: aid, type: tab) }
                let special = cat.hasPrefix("__")
                let type: ItemType? = (scope == .everywhere && !text.isEmpty) ? nil : tab
                let catId: String? = (scope == .category && !special) ? cat : nil
                return try Search.run(d, SearchRequest(accountId: aid, text: text, type: type, categoryId: catId))
            }) ?? []
            if !Task.isCancelled { results = rows }
        }
    }

    func sync() async {
        guard let a = account, let aid = a.id else { return }
        syncing = true; syncMessage = nil
        defer { syncing = false }
        do { try await SyncService(db: db).sync(account: a, password: secrets.password(for: aid)) }
        catch { syncMessage = error.localizedDescription }
        loadCategories(); scheduleSearch()
    }

    func addAccount(_ a: Account, password: String?) async {
        var a = a
        do {
            try await db.dbQueue.write { try a.insert($0) }
            if let p = password, let id = a.id { try secrets.setPassword(p, for: id) }
        } catch { syncMessage = error.localizedDescription; return }
        loadAccounts()
        account = accounts.first { $0.id == a.id }
        await sync()
    }

    func deleteAccount(_ a: Account) {
        guard let id = a.id else { return }
        _ = try? db.dbQueue.write { try Account.deleteOne($0, key: id) }
        secrets.deletePassword(for: id)
        loadAccounts()
    }

    // MARK: Playback

    func xtreamURLs() -> XtreamURLs? {
        guard let a = account, a.kind == .xtream, let id = a.id else { return nil }
        return XtreamURLs(server: a.server ?? "", username: a.username ?? "", password: secrets.password(for: id) ?? "")
    }

    func streamURL(_ item: Item) -> URL? {
        if let d = item.directURL { return URL(string: d) }
        return xtreamURLs()?.stream(type: item.type, id: item.streamId, ext: item.containerExt)
    }

    func progress(type: ItemType, streamId: String) -> Double {
        guard let aid = account?.id else { return 0 }
        let p: Double?? = try? db.dbQueue.read { try UserData.progress($0, accountId: aid, type: type, streamId: streamId) }
        return (p ?? nil) ?? 0
    }

    func play(_ item: Item) {
        if item.type == .series && item.directURL == nil { openSeries = item; return }
        guard let url = streamURL(item) else { syncMessage = IPTVError.badConfig.localizedDescription; return }
        playing = PlayRequest(title: item.name, url: url, isLive: item.type == .live, item: item,
                              start: item.type == .live ? 0 : progress(type: item.type, streamId: item.streamId))
    }

    func playEpisode(_ e: Episode, of series: Item) {
        guard let url = xtreamURLs()?.series(id: e.streamId, ext: e.containerExt) else { return }
        playing = PlayRequest(title: "\(series.name) — \(e.title)", url: url, isLive: false, item: series,
                              episodeKey: "ep:\(e.streamId)", start: progress(type: .series, streamId: "ep:\(e.streamId)"))
    }

    func saveProgress(_ r: PlayRequest, position: Double, duration: Double) {
        guard !r.isLive, let aid = account?.id, let item = r.item else { return }
        let sid = r.episodeKey ?? item.streamId
        _ = try? db.dbQueue.write { try UserData.saveProgress($0, accountId: aid, type: item.type, streamId: sid, position: position, duration: duration) }
    }

    // MARK: Favorites and EPG

    func isFavorite(_ i: Item) -> Bool { favoriteKeys.contains("\(i.type.rawValue):\(i.streamId)") }

    func toggleFavorite(_ i: Item) {
        guard let aid = account?.id else { return }
        _ = try? db.dbQueue.write { try UserData.toggleFavorite($0, accountId: aid, type: i.type, streamId: i.streamId) }
        loadFavorites()
        if selectedCategory == "__fav" { scheduleSearch() }
    }

    func loadEPGNow(_ item: Item) async {
        guard item.type == .live, epgNow[item.streamId] == nil, let urls = xtreamURLs() else { return }
        if let t = try? await XtreamClient(urls: urls).epgNow(streamId: item.streamId) { epgNow[item.streamId] = t }
    }
}
