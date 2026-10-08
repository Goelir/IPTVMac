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
            rememberPlaylist()
            if !allPlaylists { playlistChanged() }              // in All mode `account` is only the playlist to return to
        }
    }
    /// All playlists at once (results, search, favorites, continue watching and the category list span every account).
    var allPlaylists = false {
        didSet { guard allPlaylists != oldValue else { return }; rememberPlaylist(); playlistChanged() }
    }
    /// The toolbar switcher: nil = all playlists.
    var playlist: Account? {
        get { allPlaylists ? nil : account }
        set { if let a = newValue { account = a; allPlaylists = false } else { allPlaylists = true } }
    }
    private var scopeAccountId: Int64? { allPlaylists ? nil : account?.id }
    private var hasPlaylist: Bool { allPlaylists || account != nil }
    private static let playlistKey = "playlist"      // "all" or an account id

    private func rememberPlaylist() {
        UserDefaults.standard.set(allPlaylists ? "all" : account?.id.map(String.init), forKey: Self.playlistKey)
    }

    private func playlistChanged() {
        if playing != nil { stopPlayback() }                    // progress/favorites/credentials belong to the account that started it
        selectedCategory = "__all"; searchText = ""            // a category id of account A means nothing in B
        favoriteKeys = []; loadCategories(); loadFavorites(); scheduleSearch()
    }

    var tab: ItemType = .live { didSet { leavePlayerForBrowsing(); selectedCategory = "__all"; loadCategories(); scheduleSearch() } }
    var categories: [IPTVCore.Category] = []
    var selectedCategory = "__all" { didSet { leavePlayerForBrowsing(); scheduleSearch() } }
    var searchText = "" { didSet { leavePlayerForBrowsing(); scheduleSearch() } }
    var scope: SearchScopeChoice = .category { didSet { scheduleSearch() } }
    var results: [Item] = []
    /// The last item played, and (set only when the player closes onto the list) the row the list scrolls back to.
    var lastPlayedID: Int64?
    var scrollTarget: Int64?
    var syncing = false
    var syncMessage: String?
    var playing: PlayRequest?
    var player: PlayerModel?
    var pip = false
    var openSeries: Item?
    var openInfo: Item?              // the provider's details sheet (movies and series of Xtream playlists)
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
    private var epgNow: [String: String] = [:]      // "accountId:streamId" -> program title
    private var epgStamp: [String: Date] = [:]
    private var epgInFlight: Set<String> = []
    var schedule: [EPGEntry] = []      // current + upcoming programs of the channel being watched
    private var searchTask: Task<Void, Never>?
    private var pipController: PiPController?
    private var fullscreen = FullscreenSync()
    @ObservationIgnored private weak var window: NSWindow?     // the main window, reported by WindowReader (not guessed from NSApp.windows)
    @ObservationIgnored var openMainWindow: (() -> Void)?      // creates the window again after it was closed
    private var reopening = false

    var openFullscreen: Bool { UserDefaults.standard.object(forKey: "openFullscreen") as? Bool ?? true }
    /// True while the video fills the window (sidebar hidden too).
    var playerFullscreen: Bool { playing != nil && !pip && openFullscreen }

    /// The main window reports itself here: Settings and the PiP panel are never mistaken for it, and a window created
    /// again after a close joins the playback that is still running.
    func attach(_ w: NSWindow) {
        guard window !== w else { return }
        window = w; reopening = false
        applyFullscreen(); updateToolbar()
    }

    /// Dock click, File > Show Window, PiP return: the window comes back (created again if it was closed).
    func showMainWindow() {
        NSApp.unhide(nil); NSApp.activate(ignoringOtherApps: true)
        if let w = window { if w.isMiniaturized { w.deminiaturize(nil) }; w.makeKeyAndOrderFront(nil) }
        else if !reopening {
            reopening = true; openMainWindow?()
            Task { try? await Task.sleep(for: .seconds(2)); reopening = false }   // never stay blocked if no window came
        }
    }

    /// While the video is full screen the window toolbar (tabs, search) is hidden too; it is back as soon as either ends.
    func updateToolbar() {
        guard let w = window, let tb = w.toolbar else { return }
        let hide = playerFullscreen && w.styleMask.contains(.fullScreen)
        if tb.isVisible == hide { tb.isVisible = !hide }
    }

    /// Full screen only for the main window. AppKit drops a toggle issued mid-transition, with a sheet closing or while
    /// the window is minimized/hidden, so FullscreenSync keeps the request until a window event says it can be applied.
    private func setFullscreen(_ on: Bool) { fullscreen.want(on); applyFullscreen() }

    private func applyFullscreen() {
        guard let w = window, fullscreen.next(isFull: w.styleMask.contains(.fullScreen), ready: w.isVisible && w.attachedSheet == nil) else { return }
        w.toggleFullScreen(nil)
        Task { try? await Task.sleep(for: .seconds(4)); if fullscreen.busy { fullscreenEnded() } }   // a transition AppKit never reports must not block the next one
    }

    private func fullscreenEnded() {
        fullscreen.transitionEnded(isFull: window?.styleMask.contains(.fullScreen) ?? false)
        updateToolbar()
        Task { applyFullscreen() }          // AppKit still drops a toggle issued from inside the did-notification: next turn
    }

    private func windowEvent(_ n: Notification) {
        if let o = n.object as? NSWindow, o !== window { return }       // Settings, the PiP panel, sheets
        switch n.name {
        case NSWindow.willEnterFullScreenNotification, NSWindow.willExitFullScreenNotification: fullscreen.transitionStarted()
        case NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification: fullscreenEnded()
        case NSWindow.willCloseNotification:
            guard let w = window else { return }
            Task {   // a close during a full-screen transition posts this and is then refused: only a window that is really gone counts
                try? await Task.sleep(for: .milliseconds(200))
                guard window === w, !w.isVisible, !NSApp.isHidden else { return }
                window = nil; fullscreen.reset()
                if playing != nil && !pip { stopPlayback() }             // nobody sees or controls it any more; a floating PiP keeps going
            }
        default: updateToolbar(); applyFullscreen()                      // sheet closed, window shown/restored, app unhidden
        }
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
        for n in [NSWindow.willEnterFullScreenNotification, NSWindow.willExitFullScreenNotification, NSWindow.didEnterFullScreenNotification,
                  NSWindow.didExitFullScreenNotification, NSWindow.didEndSheetNotification, NSWindow.didDeminiaturizeNotification,
                  NSWindow.didBecomeKeyNotification, NSWindow.willCloseNotification, NSApplication.didUnhideNotification] {
            NotificationCenter.default.addObserver(forName: n, object: nil, queue: .main) { [weak self] n in
                MainActor.assumeIsolated { self?.windowEvent(n) }
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
        Task { await refreshLoop() }
        loadAccounts()
        if account != nil { await sync() }
    }

    func loadAccounts() {
        accounts = (try? db.dbQueue.read { try Account.order(Column("id")).fetchAll($0) }) ?? []
        if account == nil {                                     // launch: reopen the last choice (read before `account` rewrites it)
            let r = Account.restore(UserDefaults.standard.string(forKey: Self.playlistKey), from: accounts)
            if r.all { allPlaylists = true }
            account = r.account
        } else if !accounts.contains(where: { $0.id == account?.id }) { account = accounts.first }
        if accounts.count < 2 { allPlaylists = false }
    }

    func loadCategories() {
        guard hasPlaylist else { categories = []; return }
        let t = tab, aid = scopeAccountId
        categories = categoryFilter.visible((try? db.dbQueue.read {
            var q = IPTVCore.Category.filter(Column("type") == t.rawValue)
            if let aid { q = q.filter(Column("accountId") == aid) }
            return try q.order(Column("accountId"), Column("id")).fetchAll($0)
        }) ?? [])
    }

    func loadFavorites() {
        guard hasPlaylist else { return }
        let aid = scopeAccountId
        favoriteKeys = (try? db.dbQueue.read { try UserData.favoriteKeys($0, accountId: aid) }) ?? []
    }

    /// In All mode a category is tagged "<accountId>|<remoteId>" (remote ids repeat across playlists); otherwise by remote id alone.
    func categoryTag(_ c: IPTVCore.Category) -> String { allPlaylists ? "\(c.accountId)|\(c.remoteId)" : c.remoteId }

    func scheduleSearch() {
        searchTask?.cancel()
        guard hasPlaylist else { results = []; return }
        let text = searchText, tab = tab, cat = selectedCategory, scope = scope, all = allPlaylists, aid = scopeAccountId, hide = categoryFilter
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(text.isEmpty ? 0 : 100))
            if Task.isCancelled { return }
            let rows: [Item] = (try? await db.dbQueue.read { d in
                let found: [Item]
                if text.isEmpty && cat == "__fav" { found = try UserData.favorites(d, accountId: aid, type: tab) }
                else if text.isEmpty && cat == "__hist" { found = try UserData.continueWatching(d, accountId: aid, type: tab) }
                else {
                    var owner = aid, catId: String? = nil
                    if scope == .category && !cat.hasPrefix("__") {
                        if !all { catId = cat }
                        else if let bar = cat.firstIndex(of: "|") { owner = Int64(cat[..<bar]); catId = String(cat[cat.index(after: bar)...]) }
                    }
                    let type: ItemType? = (scope == .everywhere && !text.isEmpty) ? nil : tab
                    found = try Search.run(d, SearchRequest(accountId: owner, text: text, type: type, categoryId: catId))
                }
                return try hide.visible(found, in: d)
            }) ?? []
            if !Task.isCancelled { results = rows }
        }
    }

    func hasPassword(_ a: Account) -> Bool {
        guard a.kind == .xtream, let id = a.id else { return true }
        return secrets.password(for: id) != nil  // "" = deliberately no password
    }

    private var syncGen = 0
    @ObservationIgnored var lastSync: Date?                     // read by the auto-refresh loop (AppModel+Data.swift)

    /// Syncs the shown playlist, or every playlist one after the other in All mode.
    func sync() async { await sync(allPlaylists ? accounts : account.map { [$0] } ?? []) }

    func sync(_ targets: [Account]) async {
        lastSync = Date()                                       // an attempt counts: a failing provider is not retried every minute
        if let a = targets.first(where: { !hasPassword($0) }) { passwordPrompt = a }
        let ready = targets.filter(hasPassword)
        guard !ready.isEmpty else { return }
        syncGen += 1; let gen = syncGen
        syncing = true; syncMessage = nil
        defer { if gen == syncGen { syncing = false } }
        var failures: [String] = []
        for a in ready {
            guard let aid = a.id else { continue }
            do { try await SyncService(db: db).sync(account: a, password: secrets.password(for: aid)) }
            catch { failures.append(ready.count > 1 ? "\(a.name): \(error.localizedDescription)" : error.localizedDescription) }
            guard gen == syncGen else { return }                // a newer sync owns the UI state now
        }
        syncMessage = failures.isEmpty ? nil : failures.joined(separator: "; ")
        loadCategories(); scheduleSearch()
    }

    func savePassword(_ password: String, for a: Account) async {
        guard let id = a.id else { return }
        do { try secrets.setPassword(password, for: id) } catch { syncMessage = error.localizedDescription; return }
        passwordPrompt = nil
        await sync([a])   // saving a password must not switch the selected playlist (that stops the playback)
    }

    func addAccount(_ a: Account, password: String?) async {
        let saved: Account
        do {
            saved = try await db.dbQueue.write { d in var x = a; try x.insert(d); return x }
            if let p = password, let id = saved.id { try secrets.setPassword(p, for: id) }
        } catch { syncMessage = error.localizedDescription; return }
        loadAccounts()
        let added = accounts.first { $0.id == saved.id }
        if !allPlaylists { account = added }
        await sync(added.map { [$0] } ?? [])
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
        if allPlaylists {                                       // still All: the deleted playlist's rows are gone
            if selectedCategory.hasPrefix("\(id)|") { selectedCategory = "__all" }
            loadCategories(); loadFavorites(); scheduleSearch()
        }
    }

    // MARK: Playback

    func playlist(id: Int64) -> Account? { accounts.first { $0.id == id } }

    /// URLs for an Xtream account: the one that owns the item/series, else the current account.
    func xtreamURLs(for accountId: Int64? = nil) -> XtreamURLs? {
        let owner = accountId.flatMap(playlist(id:)) ?? account
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

    func progress(accountId: Int64, type: ItemType, streamId: String) -> Double {
        let p: Double?? = try? db.dbQueue.read { try UserData.progress($0, accountId: accountId, type: type, streamId: streamId) }
        return (p ?? nil) ?? 0
    }

    func play(_ item: Item) {
        if let a = playlist(id: item.accountId), !hasPassword(a) { passwordPrompt = a; return }
        if item.type == .series && item.directURL == nil { openSeries = item; return }
        guard let url = streamURL(item) else { syncMessage = IPTVError.badConfig.localizedDescription; return }
        startPlayback(PlayRequest(title: item.name, url: url, isLive: item.type == .live, item: item,
                                  start: item.type == .live ? 0 : progress(accountId: item.accountId, type: item.type, streamId: item.streamId)))
    }

    /// Movies only: live streams never end, and a series is downloaded per episode.
    func download(_ item: Item) {
        if let a = playlist(id: item.accountId), !hasPassword(a) { passwordPrompt = a; return }
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
                                  episodeKey: "ep:\(e.streamId)", start: progress(accountId: series.accountId, type: .series, streamId: "ep:\(e.streamId)")))
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
        if let id = r.item?.id { lastPlayedID = id }
        if pip { exitPiP() }
        if openFullscreen { setFullscreen(true) }
        // replace() saves the old position through onSaveProgress, which reads `playing`: switch only afterwards.
        if let p = player { p.replace(with: r); playing = r; return }
        playing = r
        let p = PlayerModel(request: r)
        p.onSaveProgress = { [weak self] pos, dur, background in
            guard let self, let cur = self.playing else { return }
            self.saveProgress(cur, position: pos, duration: dur, background: background)
        }
        p.onEndChanged = { [weak self] ended in self?.episodeEndChanged(ended) }
        p.onSleep = { [weak self] in self?.stopPlayback() }
        player = p
    }

    func stopPlayback() {
        cancelUpNext()
        if playing != nil && !pip { scrollTarget = lastPlayedID }   // the list comes back: land on the channel/title that was playing
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
                              onReturn: { [weak self] in self?.exitPiP(); self?.showMainWindow() },
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

    /// `background`: periodic saves go through asyncWrite so the main thread never waits behind a catalog sync holding the writer;
    /// saves on stop/close/quit stay synchronous so they are on disk before the app exits.
    func saveProgress(_ r: PlayRequest, position: Double, duration: Double, background: Bool = false) {
        guard !r.isLive, let item = r.item else { return }
        let aid = item.accountId
        let sid = r.episodeKey ?? item.streamId
        let write: @Sendable (Database) throws -> Void = { try UserData.saveProgress($0, accountId: aid, type: item.type, streamId: sid, position: position, duration: duration) }
        if background { db.dbQueue.asyncWrite(write, completion: { _, _ in }) } else { _ = try? db.dbQueue.write(write) }
    }

    // MARK: Favorites and EPG

    func isFavorite(_ i: Item) -> Bool { favoriteKeys.contains(UserData.favoriteKey(accountId: i.accountId, type: i.type, streamId: i.streamId)) }

    func toggleFavorite(_ i: Item) {
        let aid = i.accountId
        Task {   // async: the writer may be busy with a catalog sync
            _ = try? await db.dbQueue.write { try UserData.toggleFavorite($0, accountId: aid, type: i.type, streamId: i.streamId) }
            loadFavorites()
            if selectedCategory == "__fav" { scheduleSearch() }
        }
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

    func epgTitle(_ i: Item) -> String? { epgNow["\(i.accountId):\(i.streamId)"] }

    /// "Now" per channel (keyed by playlist and stream id): refreshed after 5 minutes, fetched once at a time per channel.
    func loadEPGNow(_ item: Item) async {
        let key = "\(item.accountId):\(item.streamId)"
        guard item.type == .live, !epgInFlight.contains(key), let urls = xtreamURLs(for: item.accountId) else { return }
        if let t = epgStamp[key], Date().timeIntervalSince(t) < 300 { return }
        epgInFlight.insert(key); defer { epgInFlight.remove(key) }
        let title = try? await XtreamClient(urls: urls).epgNow(streamId: item.streamId)
        guard !Task.isCancelled else { return }
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
