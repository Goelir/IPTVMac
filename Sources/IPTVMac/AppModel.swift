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
    var account: Account? {
        didSet {
            guard account?.id != oldValue?.id else { return }
            if playing != nil { stopPlayback() }               // progress/favorites/credentials belong to the account that started it
            epgNow = [:]; epgStamp = [:]; epgInFlight = []
            selectedCategory = "__all"; searchText = ""        // a category id of account A means nothing in B
            favoriteKeys = []; loadCategories(); loadFavorites(); scheduleSearch()
        }
    }
    var tab: ItemType = .live { didSet { leavePlayerForBrowsing(); selectedCategory = "__all"; loadCategories(); scheduleSearch() } }
    var categories: [IPTVCore.Category] = []
    var selectedCategory = "__all" { didSet { leavePlayerForBrowsing(); scheduleSearch() } }
    var searchText = "" { didSet { leavePlayerForBrowsing(); scheduleSearch() } }
    var scope: SearchScopeChoice = .category { didSet { scheduleSearch() } }
    var results: [Item] = []
    var syncing = false
    var syncMessage: String?
    var playing: PlayRequest?
    var player: PlayerModel?
    var pip = false
    var openSeries: Item?
    var showGuide = false
    var showDownloads = false
    /// Episodes of the series being watched (set when an episode starts from the series screen) and the next-episode countdown.
    var episodeQueue: [Episode] = []
    var upNext: Episode?
    var upNextSeconds = 0
    private var upNextTask: Task<Void, Never>?
    var autoNextEpisode: Bool { UserDefaults.standard.object(forKey: "autoNextEpisode") as? Bool ?? true }
    let downloads = DownloadManager()
    /// Set when an Xtream account has no stored password (e.g. after upgrading from the Keychain version).
    var passwordPrompt: Account?
    var favoriteKeys: Set<String> = []
    var epgNow: [String: String] = [:]
    private var epgStamp: [String: Date] = [:]
    private var epgInFlight: Set<String> = []
    var schedule: [EPGEntry] = []      // current + upcoming programs of the channel being watched
    private var searchTask: Task<Void, Never>?
    private var pipController: PiPController?
    private var enteredFullscreen = false

    var openFullscreen: Bool { UserDefaults.standard.object(forKey: "openFullscreen") as? Bool ?? true }
    /// True while the video fills the window (sidebar hidden too).
    var playerFullscreen: Bool { playing != nil && !pip && openFullscreen }

    /// Full screen only for the main window (never the floating PiP panel). `enteredFullscreen` makes us leave only what we entered.
    private var mainWindow: NSWindow? { NSApp.windows.first { $0.isVisible && !($0 is NSPanel) && $0.canBecomeMain } }

    /// While the video is full screen the window toolbar (tabs, search) is hidden too; it is back as soon as either ends.
    func updateToolbar() {
        guard let w = mainWindow, let tb = w.toolbar else { return }
        let hide = playerFullscreen && w.styleMask.contains(.fullScreen)
        if tb.isVisible == hide { tb.isVisible = !hide }
    }

    private func setFullscreen(_ on: Bool, tries: Int = 10) {
        guard let w = mainWindow else { return }
        if w.attachedSheet != nil, tries > 0 {   // a window ignores full-screen requests while a sheet (e.g. the episode list) is closing
            Task { try? await Task.sleep(for: .milliseconds(200)); if on == (self.playing != nil && self.openFullscreen) { self.setFullscreen(on, tries: tries - 1) } }
            return
        }
        let isFull = w.styleMask.contains(.fullScreen)
        if on == isFull { return }
        if on { enteredFullscreen = true; w.toggleFullScreen(nil) }
        else if enteredFullscreen { enteredFullscreen = false; w.toggleFullScreen(nil) }
    }

    // MARK: Updates
    var update: AppUpdate?
    var updateStatus: UpdateStatus = .none
    var updateBannerDismissed = false
    private var stagedApp: URL?
    private var swapScheduled = false

    init() {
        do {
            let r = try AppDatabase.openRecovering(path: try AppDatabase.defaultPath())
            db = r.db; dbMovedAside = r.movedAside
        } catch {
            let a = NSAlert()
            a.messageText = L("db.error.title"); a.informativeText = "\(error.localizedDescription)\n\n\(L("db.error.body"))"
            a.runModal(); exit(1)
        }
        secrets = DatabaseSecretStore(db: db)
        for n in [NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification] {
            NotificationCenter.default.addObserver(forName: n, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateToolbar() }
            }
        }
    }

    private var started = false
    private var dbMovedAside: String?

    func start() async {
        guard !started else { return }                          // every new window runs .task again: sync/update loop/staged update must not
        started = true
        if let aside = dbMovedAside {
            let a = NSAlert(); a.messageText = L("db.recovered.title"); a.informativeText = String(format: L("db.recovered.body"), aside); a.runModal()
        }
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

    func hasPassword(_ a: Account) -> Bool {
        guard a.kind == .xtream, let id = a.id else { return true }
        return secrets.password(for: id) != nil  // "" = deliberately no password
    }

    private var syncGen = 0

    func sync() async {
        guard let a = account, let aid = a.id else { return }
        if !hasPassword(a) { passwordPrompt = a; return }
        syncGen += 1; let gen = syncGen
        syncing = true; syncMessage = nil
        defer { if gen == syncGen { syncing = false } }
        var failure: String?
        do { try await SyncService(db: db).sync(account: a, password: secrets.password(for: aid)) }
        catch { failure = error.localizedDescription }
        guard gen == syncGen else { return }                    // a newer sync owns the UI state now
        syncMessage = failure
        loadCategories(); scheduleSearch()
    }

    func savePassword(_ password: String, for a: Account) async {
        guard let id = a.id else { return }
        do { try secrets.setPassword(password, for: id) } catch { syncMessage = error.localizedDescription; return }
        passwordPrompt = nil
        if account?.id != id { account = accounts.first { $0.id == id } }
        await sync()
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
        if playing?.item?.accountId == id { stopPlayback() }
        _ = try? db.dbQueue.write { d in
            try d.execute(sql: "DELETE FROM favorite WHERE accountId = ?", arguments: [id])   // M3U ids are full URLs with credentials
            try d.execute(sql: "DELETE FROM history WHERE accountId = ?", arguments: [id])
            _ = try Account.deleteOne(d, key: id)
        }
        secrets.deletePassword(for: id)
        loadAccounts()
    }

    // MARK: Playback

    /// URLs for an Xtream account: the one that owns the item/series, else the current account.
    func xtreamURLs(for accountId: Int64? = nil) -> XtreamURLs? {
        let owner = accountId.flatMap { id in accounts.first { $0.id == id } } ?? account
        guard let a = owner, a.kind == .xtream, let id = a.id else { return nil }
        return XtreamURLs(server: a.server ?? "", username: a.username ?? "", password: secrets.password(for: id) ?? "")
    }

    func streamURL(_ item: Item) -> URL? {
        if let d = item.directURL { return Self.safeStreamURL(d) }
        return xtreamURLs(for: item.accountId)?.stream(type: item.type, id: item.streamId, ext: item.containerExt)
    }

    /// An M3U entry is untrusted: mpv would also open fd://, file://, edl://, memory:// ... so only network schemes pass.
    static func safeStreamURL(_ s: String) -> URL? {
        guard let u = URL(string: s.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https", "rtmp", "rtmps", "rtsp", "udp", "rtp", "mms", "mmsh"].contains(u.scheme?.lowercased() ?? ""),
              u.host?.isEmpty == false else { return nil }
        return u
    }

    func progress(type: ItemType, streamId: String) -> Double {
        guard let aid = account?.id else { return 0 }
        let p: Double?? = try? db.dbQueue.read { try UserData.progress($0, accountId: aid, type: type, streamId: streamId) }
        return (p ?? nil) ?? 0
    }

    func play(_ item: Item) {
        if let a = account, !hasPassword(a) { passwordPrompt = a; return }
        if item.type == .series && item.directURL == nil { openSeries = item; return }
        guard let url = streamURL(item) else { syncMessage = IPTVError.badConfig.localizedDescription; return }
        startPlayback(PlayRequest(title: item.name, url: url, isLive: item.type == .live, item: item,
                                  start: item.type == .live ? 0 : progress(type: item.type, streamId: item.streamId)))
    }

    /// Movies only: live streams never end, and a series is downloaded per episode.
    func download(_ item: Item) {
        if let a = account, !hasPassword(a) { passwordPrompt = a; return }
        guard item.type == .movie, let url = streamURL(item) else { return }
        downloads.add(title: item.name, url: url, ext: item.containerExt ?? url.pathExtension)
    }

    func download(_ episodes: [Episode], of series: Item) {
        guard let urls = xtreamURLs(for: series.accountId), downloads.ensureFolder() else { return }
        for e in episodes.sorted(by: { ($0.season, $0.number) < ($1.season, $1.number) }) {
            let url = urls.series(id: e.streamId, ext: e.containerExt)
            downloads.add(title: String(format: "%@ S%02dE%02d %@", series.name, e.season, e.number, e.title), url: url, ext: e.containerExt)
        }
    }

    func playEpisode(_ e: Episode, of series: Item, in all: [Episode]? = nil) {
        guard let url = xtreamURLs(for: series.accountId)?.series(id: e.streamId, ext: e.containerExt) else { return }
        cancelUpNext()
        if let all { episodeQueue = all }
        startPlayback(PlayRequest(title: "\(series.name) — \(e.title)", url: url, isLive: false, item: series,
                                  episodeKey: "ep:\(e.streamId)", start: progress(type: .series, streamId: "ep:\(e.streamId)")))
    }

    /// The episode ended: count down 5 s, then play the next one (cancelled by Cancel, by seeking back, or by leaving the player).
    func episodeEndChanged(_ ended: Bool) {
        guard ended else { cancelUpNext(); return }
        guard autoNextEpisode, upNext == nil, let r = playing, let key = r.episodeKey, let series = r.item,
              let next = EpisodeQueue.next(after: String(key.dropFirst(3)), in: episodeQueue) else { return }
        upNext = next
        upNextTask = Task { [weak self] in
            for s in stride(from: 5, through: 1, by: -1) {
                self?.upNextSeconds = s
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            guard let self else { return }
            self.playEpisode(next, of: series, in: self.episodeQueue)
        }
    }

    func playUpNextNow() {
        guard let next = upNext, let series = playing?.item else { return }
        playEpisode(next, of: series, in: episodeQueue)
    }

    func cancelUpNext() { upNextTask?.cancel(); upNextTask = nil; upNext = nil }

    func startPlayback(_ r: PlayRequest) {
        defer { updateToolbar() }
        cancelUpNext()                                           // a pending "up next" must not replace what the user picked now
        if pip { exitPiP() }
        if openFullscreen { setFullscreen(true) }
        // replace() saves the old position through onSaveProgress, which reads `playing`: switch only afterwards.
        if let p = player { p.replace(with: r); playing = r; return }
        playing = r
        let p = PlayerModel(request: r)
        p.onSaveProgress = { [weak self] pos, dur in
            guard let self, let cur = self.playing else { return }
            self.saveProgress(cur, position: pos, duration: dur)
        }
        p.onEndChanged = { [weak self] ended in self?.episodeEndChanged(ended) }
        player = p
    }

    func stopPlayback() {
        cancelUpNext()
        pipController?.dismiss(); pipController = nil
        player?.close(); player = nil
        pip = false
        playing = nil
        setFullscreen(false)
        updateToolbar()
    }

    /// Choosing a tab/category or searching while watching shows the list; the video keeps playing in the floating window.
    func leavePlayerForBrowsing() { if playing != nil && !pip { enterPiP() } }

    func enterPiP() {
        guard let p = player, !pip else { return }
        cancelUpNext()
        pip = true
        setFullscreen(false)
        updateToolbar()
        let c = PiPController(model: p, title: playing?.title ?? "",
                              onReturn: { [weak self] in guard let s = self else { return }; if s.mainWindow == nil { s.stopPlayback() } else { s.exitPiP() } },
                              onClose: { [weak self] in self?.stopPlayback() })
        pipController = c
        c.show()
    }

    func exitPiP() {
        pipController?.dismiss(); pipController = nil
        pip = false
        if playing != nil && openFullscreen { setFullscreen(true) }
        updateToolbar()
    }

    func saveProgress(_ r: PlayRequest, position: Double, duration: Double) {
        guard !r.isLive, let item = r.item else { return }
        let aid = item.accountId
        let sid = r.episodeKey ?? item.streamId
        _ = try? db.dbQueue.write { try UserData.saveProgress($0, accountId: aid, type: item.type, streamId: sid, position: position, duration: duration) }
    }

    // MARK: Favorites and EPG

    func isFavorite(_ i: Item) -> Bool { favoriteKeys.contains("\(i.type.rawValue):\(i.streamId)") }

    func toggleFavorite(_ i: Item) {
        let aid = i.accountId
        _ = try? db.dbQueue.write { try UserData.toggleFavorite($0, accountId: aid, type: i.type, streamId: i.streamId) }
        loadFavorites()
        if selectedCategory == "__fav" { scheduleSearch() }
    }

    /// Keeps `schedule` fresh for the live channel being watched; ends when the calling task is cancelled.
    func watchSchedule(of item: Item) async {
        schedule = []
        guard item.type == .live, let urls = xtreamURLs(for: item.accountId) else { return }
        while !Task.isCancelled {
            if let l = try? await XtreamClient(urls: urls).epgShort(streamId: item.streamId, limit: 3) { schedule = l }
            try? await Task.sleep(for: .seconds(60))
        }
    }

    /// "Now" per channel: refreshed after 5 minutes, fetched once at a time per channel, cleared on account change.
    func loadEPGNow(_ item: Item) async {
        let key = item.streamId
        guard item.type == .live, !epgInFlight.contains(key), let urls = xtreamURLs(for: item.accountId) else { return }
        if let t = epgStamp[key], Date().timeIntervalSince(t) < 300 { return }
        epgInFlight.insert(key); defer { epgInFlight.remove(key) }
        let aid = account?.id
        let title = try? await XtreamClient(urls: urls).epgNow(streamId: key)
        guard !Task.isCancelled, account?.id == aid else { return }
        epgStamp[key] = Date()
        epgNow[key] = title ?? nil
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
                if updateStatus == .downloading || updateStatus == .ready { return }   // another check finished while this one was waiting
                update = u; updateBannerDismissed = false; updateStatus = .available
                if autoInstallUpdates || manual { await installUpdate() }
            } else if manual { updateStatus = .upToDate }
        } catch { if manual { updateStatus = .failed(error.localizedDescription) } }
    }

    /// Downloads, verifies and stages the new app next to the data folder. Nothing is replaced until restart/quit.
    func installUpdate() async {
        guard let u = update, updateStatus != .downloading else { return }
        let appFolder = Bundle.main.bundleURL.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: appFolder.path) else {
            updateStatus = .failed("\(appFolder.path) is not writable"); return
        }
        updateStatus = .downloading
        do {
            let dmg = try await UpdateChecker.downloadDMG(u)
            defer { try? FileManager.default.removeItem(at: dmg) }
            let dir = updateDir
            let id = Bundle.main.bundleIdentifier, cur = currentVersion
            stagedApp = try await Task.detached { try UpdateInstaller.stage(dmg: dmg, expectedVersion: u.version, into: dir, expectedBundleID: id, currentVersion: cur) }.value
            updateStatus = .ready
        } catch { updateStatus = .failed(error.localizedDescription) }
    }

    func restartToUpdate() {
        guard let staged = stagedApp, !swapScheduled else { return }
        guard FileManager.default.fileExists(atPath: staged.path) else {
            stagedApp = nil; updateStatus = .failed("The downloaded update is gone; check for updates again"); return
        }
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
