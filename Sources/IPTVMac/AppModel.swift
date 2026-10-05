import Foundation
import AppKit
import Observation
import GRDB
import IPTVCore

enum UpdateStatus: Equatable { case none, available, downloading, ready, failed(String), upToDate, devBuild }

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
    let secrets: SecretStore
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
    var player: PlayerModel?
    var pip = false
    var openSeries: Item?
    var showGuide = false
    var favoriteKeys: Set<String> = []
    var epgNow: [String: String] = [:]
    private var searchTask: Task<Void, Never>?
    private var pipController: PiPController?

    // MARK: Updates
    var update: AppUpdate?
    var updateStatus: UpdateStatus = .none
    var updateBannerDismissed = false
    private var stagedApp: URL?
    private var swapScheduled = false

    init() {
        do { db = try AppDatabase(path: try AppDatabase.defaultPath()) }
        catch { fatalError("Cannot open database: \(error)") }
        secrets = DatabaseSecretStore(db: db)
    }

    func start() async {
        clearStaleUpdate()
        Task { await updateLoop() }
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
        let saved: Account
        do {
            saved = try await db.dbQueue.write { d in var x = a; try x.insert(d); return x }
            if let p = password, let id = saved.id { try secrets.setPassword(p, for: id) }
        } catch { syncMessage = error.localizedDescription; return }
        loadAccounts()
        account = accounts.first { $0.id == saved.id }
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
        startPlayback(PlayRequest(title: item.name, url: url, isLive: item.type == .live, item: item,
                                  start: item.type == .live ? 0 : progress(type: item.type, streamId: item.streamId)))
    }

    func playEpisode(_ e: Episode, of series: Item) {
        guard let url = xtreamURLs()?.series(id: e.streamId, ext: e.containerExt) else { return }
        startPlayback(PlayRequest(title: "\(series.name) — \(e.title)", url: url, isLive: false, item: series,
                                  episodeKey: "ep:\(e.streamId)", start: progress(type: .series, streamId: "ep:\(e.streamId)")))
    }

    func startPlayback(_ r: PlayRequest) {
        if pip { exitPiP() }
        // replace() saves the old position through onSaveProgress, which reads `playing`: switch only afterwards.
        if let p = player { p.replace(with: r); playing = r; return }
        playing = r
        let p = PlayerModel(request: r)
        p.onSaveProgress = { [weak self] pos, dur in
            guard let self, let cur = self.playing else { return }
            self.saveProgress(cur, position: pos, duration: dur)
        }
        player = p
    }

    func stopPlayback() {
        pipController?.dismiss(); pipController = nil
        player?.close(); player = nil
        pip = false
        playing = nil
    }

    func enterPiP() {
        guard let p = player, !pip else { return }
        pip = true
        let c = PiPController(model: p, title: playing?.title ?? "",
                              onReturn: { [weak self] in self?.exitPiP() },
                              onClose: { [weak self] in self?.stopPlayback() })
        pipController = c
        c.show()
    }

    func exitPiP() {
        pipController?.dismiss(); pipController = nil
        pip = false
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

// MARK: - Updates
extension AppModel {
    private static func flag(_ key: String) -> Bool { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
    var autoCheckUpdates: Bool { Self.flag("autoCheckUpdates") }
    var autoInstallUpdates: Bool { Self.flag("autoInstallUpdates") }
    var currentVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0" }
    /// `swift run` builds have no app bundle to replace, so updates are only for the installed app.
    var isInstalledApp: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    private var updateDir: URL {
        (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))?
            .appendingPathComponent("IPTVMac/update") ?? FileManager.default.temporaryDirectory.appendingPathComponent("IPTVMac-update")
    }

    /// A staged copy left by a run that never applied it is dropped; it is downloaded again if still needed.
    func clearStaleUpdate() { try? FileManager.default.removeItem(at: updateDir) }

    func updateLoop() async {
        while !Task.isCancelled {
            if autoCheckUpdates { await checkForUpdates(manual: false) }
            try? await Task.sleep(for: .seconds(6 * 3600))
        }
    }

    func checkForUpdates(manual: Bool) async {
        guard isInstalledApp else { if manual { updateStatus = .devBuild }; return }
        if updateStatus == .downloading || updateStatus == .ready { return }
        do {
            if let u = try await UpdateChecker.check(current: currentVersion) {
                update = u; updateBannerDismissed = false; updateStatus = .available
                if autoInstallUpdates || manual { await installUpdate() }
            } else if manual { updateStatus = .upToDate }
        } catch { if manual { updateStatus = .failed(error.localizedDescription) } }
    }

    /// Downloads, verifies and stages the new app next to the data folder. Nothing is replaced until restart/quit.
    func installUpdate() async {
        guard let u = update else { return }
        let appFolder = Bundle.main.bundleURL.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: appFolder.path) else {
            updateStatus = .failed("\(appFolder.path) is not writable"); return
        }
        updateStatus = .downloading
        do {
            let dmg = try await UpdateChecker.downloadDMG(u)
            defer { try? FileManager.default.removeItem(at: dmg) }
            let dir = updateDir
            stagedApp = try await Task.detached { try UpdateInstaller.stage(dmg: dmg, expectedVersion: u.version, into: dir) }.value
            updateStatus = .ready
        } catch { updateStatus = .failed(error.localizedDescription) }
    }

    func restartToUpdate() {
        guard let staged = stagedApp, !swapScheduled else { return }
        do {
            swapScheduled = true
            try UpdateInstaller.scheduleSwap(pid: getpid(), target: Bundle.main.bundleURL, staged: staged, relaunch: true)
            NSApp.terminate(nil)
        } catch { swapScheduled = false; updateStatus = .failed(error.localizedDescription) }
    }

    /// Called when the app quits: a staged update is installed right after exit (no relaunch).
    func applyStagedUpdateOnQuit() {
        guard let staged = stagedApp, !swapScheduled else { return }
        swapScheduled = true
        _ = try? UpdateInstaller.scheduleSwap(pid: getpid(), target: Bundle.main.bundleURL, staged: staged, relaunch: false)
    }
}
