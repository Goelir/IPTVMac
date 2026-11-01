import Foundation
import Observation
import GRDB
import IPTVCore

// The platform-neutral part of the app model (accounts, categories, search, favorites, sync, playlists/All mode, info, backup,
// progress, EPG), shared by the macOS app (`AppModel`, Sources/IPTVMac) and the iOS app (`PhoneModel`, ios/Sources).
// No AppKit/UIKit here: windows, full screen, PiP, alerts, updates and downloads live in the platform's subclass.

public enum SearchScopeChoice: String, CaseIterable { case category, type, everywhere }

public enum ClearKind: String, CaseIterable, Identifiable { case history, favorites, images; public var id: String { rawValue } }

public struct PlayRequest: Identifiable {
    public let id = UUID()
    public var title: String
    public var url: URL
    public var isLive: Bool
    public var item: Item?
    public var episodeKey: String?     // history key for episodes: "ep:<episodeId>"
    public var start: Double = 0
    public init(title: String, url: URL, isLive: Bool, item: Item? = nil, episodeKey: String? = nil, start: Double = 0) {
        self.title = title; self.url = url; self.isLive = isLive; self.item = item; self.episodeKey = episodeKey; self.start = start
    }
}

@MainActor @Observable
open class LibraryModel {
    public let db: AppDatabase
    public let secrets: SecretStore
    /// Set when the database file was corrupt and moved aside at launch (the platform tells the user).
    public let dbMovedAside: String?
    public var accounts: [Account] = []
    public var account: Account? {
        didSet {
            guard account?.id != oldValue?.id else { return }
            rememberPlaylist()
            if !allPlaylists { playlistChanged() }              // in All mode `account` is only the playlist to return to
        }
    }
    /// All playlists at once (results, search, favorites, continue watching and the category list span every account).
    public var allPlaylists = false {
        didSet { guard allPlaylists != oldValue else { return }; rememberPlaylist(); playlistChanged() }
    }
    /// The toolbar switcher: nil = all playlists.
    public var playlist: Account? {
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

    public var tab: ItemType = .live { didSet { leavePlayerForBrowsing(); selectedCategory = "__all"; loadCategories(); scheduleSearch() } }
    public var categories: [IPTVCore.Category] = []
    public var selectedCategory = "__all" { didSet { leavePlayerForBrowsing(); scheduleSearch() } }
    public var searchText = "" { didSet { leavePlayerForBrowsing(); scheduleSearch() } }
    public var scope: SearchScopeChoice = .category { didSet { scheduleSearch() } }
    public var results: [Item] = []
    public var syncing = false
    /// How far the running sync is, 0...1 (every playlist counted in All mode); nil when none is running.
    public private(set) var syncProgress: Double?
    public var syncMessage: String?
    public var playing: PlayRequest?
    public var openSeries: Item?
    /// Set when an Xtream account has no stored password (e.g. after upgrading from the Keychain version).
    public var passwordPrompt: Account?
    public var favoriteKeys: Set<String> = []
    private var epgNow: [String: String] = [:]      // "accountId:streamId" -> program title
    private var epgStamp: [String: Date] = [:]
    private var epgEntries: [String: [EPGEntry]] = [:]   // current + next program, for the phone's rows
    private var epgInFlight: Set<String> = []
    public var schedule: [EPGEntry] = []      // current + upcoming programs of the channel being watched
    private var searchTask: Task<Void, Never>?

    /// `secrets` defaults to the database-backed store; tests pass `AppDatabase()` (in memory) and a `MemorySecretStore`.
    public init(db: AppDatabase, secrets: SecretStore? = nil, dbMovedAside: String? = nil) {
        self.db = db
        self.secrets = secrets ?? DatabaseSecretStore(db: db)
        self.dbMovedAside = dbMovedAside
    }

    // MARK: Platform hooks (the defaults are for a platform without a player to manage)

    /// Called when browsing state changes (tab, category, search): the macOS app moves a running video to a floating window.
    open func leavePlayerForBrowsing() {}
    /// Starts playing `r`; the platform replaces this with its player.
    open func startPlayback(_ r: PlayRequest) { playing = r }
    open func stopPlayback() { playing = nil }

    // MARK: Launch

    private var started = false

    /// Loads the accounts, starts the auto-refresh loop and syncs the shown playlist. Runs once, whatever number of windows ask.
    open func start() async {
        guard !started else { return }
        started = true
        Task { await refreshLoop() }
        loadAccounts()
        if account != nil { await sync() }
    }

    public func loadAccounts() {
        accounts = (try? db.dbQueue.read { try Account.order(Column("id")).fetchAll($0) }) ?? []
        if account == nil {                                     // launch: reopen the last choice (read before `account` rewrites it)
            let r = Account.restore(UserDefaults.standard.string(forKey: Self.playlistKey), from: accounts)
            if r.all { allPlaylists = true }
            account = r.account
        } else if !accounts.contains(where: { $0.id == account?.id }) { account = accounts.first }
        if accounts.count < 2 { allPlaylists = false }
    }

    public func loadCategories() {
        guard hasPlaylist else { categories = []; return }
        let t = tab, aid = scopeAccountId
        categories = categoryFilter.visible((try? db.dbQueue.read {
            var q = IPTVCore.Category.filter(Column("type") == t.rawValue)
            if let aid { q = q.filter(Column("accountId") == aid) }
            return try q.order(Column("accountId"), Column("id")).fetchAll($0)
        }) ?? [])
    }

    public func loadFavorites() {
        guard hasPlaylist else { return }
        let aid = scopeAccountId
        favoriteKeys = (try? db.dbQueue.read { try UserData.favoriteKeys($0, accountId: aid) }) ?? []
    }

    /// In All mode a category is tagged "<accountId>|<remoteId>" (remote ids repeat across playlists); otherwise by remote id alone.
    public func categoryTag(_ c: IPTVCore.Category) -> String { allPlaylists ? "\(c.accountId)|\(c.remoteId)" : c.remoteId }

    /// While the Continue watching category is shown: where each title was left (by item id).
    public private(set) var continueInfo: [Int64: ContinueEntry] = [:]

    public func scheduleSearch() {
        searchTask?.cancel()
        guard hasPlaylist else { results = []; return }
        let text = searchText, tab = tab, cat = selectedCategory, scope = scope, all = allPlaylists, aid = scopeAccountId, hide = categoryFilter
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(text.isEmpty ? 0 : 100))
            if Task.isCancelled { return }
            let (rows, info): ([Item], [Int64: ContinueEntry]) = (try? await db.dbQueue.read { d in
                var info: [Int64: ContinueEntry] = [:]
                let found: [Item]
                if text.isEmpty && cat == "__fav" { found = try UserData.favorites(d, accountId: aid, type: tab) }
                else if text.isEmpty && cat == "__hist" {
                    let e = try WatchProgress.continueEntries(d, accountId: aid, type: tab, limit: .max)
                    info = Dictionary(e.compactMap { x in x.item.id.map { ($0, x) } }, uniquingKeysWith: { a, _ in a })
                    found = e.map(\.item)
                }
                else {
                    var owner = aid, catId: String? = nil
                    if scope == .category && !cat.hasPrefix("__") {
                        if !all { catId = cat }
                        else if let bar = cat.firstIndex(of: "|") { owner = Int64(cat[..<bar]); catId = String(cat[cat.index(after: bar)...]) }
                    }
                    let type: ItemType? = (scope == .everywhere && !text.isEmpty) ? nil : tab
                    found = try Search.run(d, SearchRequest(accountId: owner, text: text, type: type, categoryId: catId))
                }
                return (try hide.visible(found, in: d), info)
            }) ?? ([], [:])
            if !Task.isCancelled { results = rows; continueInfo = info }
        }
    }

    public func hasPassword(_ a: Account) -> Bool {
        guard a.kind == .xtream, let id = a.id else { return true }
        return secrets.password(for: id) != nil  // "" = deliberately no password
    }

    // MARK: Subscription

    /// What each Xtream panel said about its subscription (the expiry date), by playlist id. The last answers are kept in the defaults, so a
    /// date shows at once and offline; the settings screen refreshes them (one login request per playlist).
    public private(set) var subscriptions: [Int64: SubscriptionInfo] = LibraryModel.savedSubscriptions()
    private static let subscriptionsKey = "subscriptions"

    private static func savedSubscriptions() -> [Int64: SubscriptionInfo] {
        guard let d = UserDefaults.standard.data(forKey: subscriptionsKey),
              let m = try? JSONDecoder().decode([String: SubscriptionInfo].self, from: d) else { return [:] }
        return Dictionary(uniqueKeysWithValues: m.compactMap { k, v in Int64(k).map { ($0, v) } })
    }

    private func saveSubscriptions() {
        let m = Dictionary(uniqueKeysWithValues: subscriptions.map { (String($0.key), $0.value) })
        UserDefaults.standard.set(try? JSONEncoder().encode(m), forKey: Self.subscriptionsKey)
    }

    /// Asks the panel again. A failed request (offline, wrong password, a panel without the field) keeps what was known.
    public func refreshSubscription(_ a: Account) async {
        guard a.kind == .xtream, let id = a.id, hasPassword(a),
              let urls = XtreamURLs(server: a.server ?? "", username: a.username ?? "", password: secrets.password(for: id) ?? "") else { return }
        guard let info = try? await XtreamClient(urls: urls).subscription(), info != subscriptions[id] else { return }
        subscriptions[id] = info
        saveSubscriptions()
    }

    // MARK: Sync

    private var syncGen = 0
    @ObservationIgnored public var lastSync: Date?                     // read by the auto-refresh loop

    /// Syncs the shown playlist, or every playlist one after the other in All mode.
    public func sync() async { await sync(allPlaylists ? accounts : account.map { [$0] } ?? []) }

    public func sync(_ targets: [Account]) async {
        lastSync = Date()                                       // an attempt counts: a failing provider is not retried every minute
        if let a = targets.first(where: { !hasPassword($0) }) { passwordPrompt = a }
        let ready = targets.filter(hasPassword)
        guard !ready.isEmpty else { return }
        syncGen += 1; let gen = syncGen
        syncing = true; syncMessage = nil; syncProgress = 0
        defer { if gen == syncGen { syncing = false; syncProgress = nil } }
        var failures: [String] = []
        for (index, a) in ready.enumerated() {
            guard let aid = a.id else { continue }
            let share = 1 / Double(ready.count), base = Double(index) * share      // All mode: the playlists go one after the other
            let report: @Sendable (Double) -> Void = { [weak self] p in
                Task { @MainActor in
                    guard let self, gen == self.syncGen, base + p * share > (self.syncProgress ?? 0) else { return }
                    self.syncProgress = base + p * share
                }
            }
            do { try await SyncService(db: db).sync(account: a, password: secrets.password(for: aid), progress: report) }
            catch { failures.append(ready.count > 1 ? "\(a.name): \(error.localizedDescription)" : error.localizedDescription) }
            guard gen == syncGen else { return }                // a newer sync owns the UI state now
        }
        syncMessage = failures.isEmpty ? nil : failures.joined(separator: "; ")
        loadCategories(); scheduleSearch()
    }

    public func savePassword(_ password: String, for a: Account) async {
        guard let id = a.id else { return }
        do { try secrets.setPassword(password, for: id) } catch { syncMessage = error.localizedDescription; return }
        passwordPrompt = nil
        await sync([a])   // saving a password must not switch the selected playlist (that stops the playback)
    }

    public func addAccount(_ a: Account, password: String?) async {
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

    public func deleteAccount(_ a: Account) {
        guard let id = a.id else { return }
        if playing?.item?.accountId == id { stopPlayback() }
        _ = try? db.dbQueue.write { d in
            try d.execute(sql: "DELETE FROM favorite WHERE accountId = ?", arguments: [id])   // M3U ids are full URLs with credentials
            try d.execute(sql: "DELETE FROM history WHERE accountId = ?", arguments: [id])
            _ = try Account.deleteOne(d, key: id)
        }
        secrets.deletePassword(for: id)
        if subscriptions.removeValue(forKey: id) != nil { saveSubscriptions() }
        loadAccounts()
        if allPlaylists {                                       // still All: the deleted playlist's rows are gone
            if selectedCategory.hasPrefix("\(id)|") { selectedCategory = "__all" }
            loadCategories(); loadFavorites(); scheduleSearch()
        }
    }

    // MARK: Playback requests

    public func playlist(id: Int64) -> Account? { accounts.first { $0.id == id } }

    /// URLs for an Xtream account: the one that owns the item/series, else the current account.
    public func xtreamURLs(for accountId: Int64? = nil) -> XtreamURLs? {
        let owner = accountId.flatMap(playlist(id:)) ?? account
        guard let a = owner, a.kind == .xtream, let id = a.id else { return nil }
        return XtreamURLs(server: a.server ?? "", username: a.username ?? "", password: secrets.password(for: id) ?? "")
    }

    public func streamURL(_ item: Item) -> URL? {
        if let d = item.directURL { return Self.safeStreamURL(d) }
        return xtreamURLs(for: item.accountId)?.stream(type: item.type, id: item.streamId, ext: item.containerExt)
    }

    /// An M3U entry is untrusted: mpv would also open fd://, file://, edl://, memory:// ... so only network schemes pass.
    nonisolated public static func safeStreamURL(_ s: String) -> URL? {
        guard let u = URL(string: s.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https", "rtmp", "rtmps", "rtsp", "udp", "rtp", "mms", "mmsh"].contains(u.scheme?.lowercased() ?? ""),
              u.host?.isEmpty == false else { return nil }
        return u
    }

    public func progress(accountId: Int64, type: ItemType, streamId: String) -> Double {
        let p: Double?? = try? db.dbQueue.read { try UserData.progress($0, accountId: accountId, type: type, streamId: streamId) }
        return (p ?? nil) ?? 0
    }

    /// A movie, channel or direct-URL entry plays (through `startPlayback`); a series opens its episode list (`openSeries`).
    public func play(_ item: Item) {
        if let a = playlist(id: item.accountId), !hasPassword(a) { passwordPrompt = a; return }
        if item.type == .series && item.directURL == nil { openSeries = item; return }
        guard let url = streamURL(item) else { syncMessage = IPTVError.badConfig.localizedDescription; return }
        startPlayback(PlayRequest(title: item.name, url: url, isLive: item.type == .live, item: item,
                                  start: item.type == .live ? 0 : progress(accountId: item.accountId, type: item.type, streamId: item.streamId)))
    }

    /// Continue watching: a series resumes the episode that was left, at its position (and its next episodes follow); a movie plays as usual.
    /// Without the episode list in the cache the series opens instead.
    public func resume(_ entry: ContinueEntry) {
        guard entry.item.type == .series, entry.item.directURL == nil, let epId = entry.episodeId else { play(entry.item); return }
        if let a = playlist(id: entry.item.accountId), !hasPassword(a) { passwordPrompt = a; return }
        let eps = (try? db.dbQueue.read { try WatchProgress.cachedEpisodes($0, accountId: entry.item.accountId, seriesId: entry.item.streamId) }) ?? []
        guard let ep = eps.first(where: { $0.streamId == epId }) else { play(entry.item); return }
        playEpisode(ep, of: entry.item, in: eps)
    }

    /// Starts an episode of `series`; `all` is the list its next episodes come from, when the caller has it. Platforms keep that list.
    open func playEpisode(_ e: Episode, of series: Item, in all: [Episode]? = nil) {
        if let r = episodeRequest(e, of: series) { startPlayback(r) }
    }

    /// The skip buttons for what is about to play: only for an episode, with the marks its series has (an empty set at first).
    public func skipControls(for r: PlayRequest) -> SkipControls? {
        guard !r.isLive, r.episodeKey != nil, let series = r.item, series.type == .series else { return nil }
        let aid = series.accountId, sid = series.streamId
        let marks = (try? db.dbQueue.read { try UserData.skipMarks($0, accountId: aid, seriesId: sid) }) ?? SkipMarks()
        return SkipControls(marks: marks) { [db] m in
            db.dbQueue.asyncWrite({ try UserData.saveSkipMarks($0, accountId: aid, seriesId: sid, marks: m) }, completion: { _, _ in })
        }
    }

    /// The speed and subtitle language kept for the series of an episode that is about to play (nil for anything else).
    public func seriesPrefsKeeper(for r: PlayRequest) -> SeriesPrefsKeeper? {
        guard !r.isLive, r.episodeKey != nil, let series = r.item, series.type == .series else { return nil }
        let aid = series.accountId, sid = series.streamId
        let prefs = (try? db.dbQueue.read { try UserData.seriesPrefs($0, accountId: aid, seriesId: sid) }) ?? SeriesPrefs()
        return SeriesPrefsKeeper(prefs: prefs) { [db] p in
            db.dbQueue.asyncWrite({ try UserData.saveSeriesPrefs($0, accountId: aid, seriesId: sid, prefs: p) }, completion: { _, _ in })
        }
    }

    public func episodeRequest(_ e: Episode, of series: Item) -> PlayRequest? {
        guard let url = xtreamURLs(for: series.accountId)?.series(id: e.streamId, ext: e.containerExt) else { return nil }
        return PlayRequest(title: "\(series.name) — \(e.title)", url: url, isLive: false, item: series,
                           episodeKey: "ep:\(e.streamId)", start: progress(accountId: series.accountId, type: .series, streamId: "ep:\(e.streamId)"))
    }

    /// `background`: periodic saves go through asyncWrite so the main thread never waits behind a catalog sync holding the writer;
    /// saves on stop/close/quit stay synchronous so they are on disk before the app exits.
    public func saveProgress(_ r: PlayRequest, position: Double, duration: Double, background: Bool = false) {
        guard !r.isLive, let item = r.item else { return }
        let aid = item.accountId
        let sid = r.episodeKey ?? item.streamId
        let write: @Sendable (Database) throws -> Void = { try UserData.saveProgress($0, accountId: aid, type: item.type, streamId: sid, position: position, duration: duration) }
        if background { db.dbQueue.asyncWrite(write, completion: { _, _ in }) } else { _ = try? db.dbQueue.write(write) }
    }

    // MARK: Favorites and EPG

    public func isFavorite(_ i: Item) -> Bool { favoriteKeys.contains(UserData.favoriteKey(accountId: i.accountId, type: i.type, streamId: i.streamId)) }

    public func toggleFavorite(_ i: Item) {
        let aid = i.accountId
        Task {   // async: the writer may be busy with a catalog sync
            _ = try? await db.dbQueue.write { try UserData.toggleFavorite($0, accountId: aid, type: i.type, streamId: i.streamId) }
            loadFavorites()
            if selectedCategory == "__fav" { scheduleSearch() }
        }
    }

    /// Keeps `schedule` fresh for the live channel being watched; ends when the calling task is cancelled.
    public func watchSchedule(of item: Item) async {
        schedule = []
        guard item.type == .live, let urls = xtreamURLs(for: item.accountId) else { return }
        while !Task.isCancelled {
            if let l = try? await XtreamClient(urls: urls).epgShort(streamId: item.streamId, limit: 3) { schedule = l }
            try? await Task.sleep(for: .seconds(60))
        }
    }

    public func epgTitle(_ i: Item) -> String? { epgNow["\(i.accountId):\(i.streamId)"] }
    /// The program on now and the one after it (nil when the provider has no guide for the channel).
    public func epgPrograms(_ i: Item) -> (now: EPGEntry?, next: EPGEntry?) {
        let l = epgEntries["\(i.accountId):\(i.streamId)"] ?? []
        return (l.first, l.count > 1 ? l[1] : nil)
    }

    /// "Now" per channel (keyed by playlist and stream id): refreshed after 5 minutes, fetched once at a time per channel.
    public func loadEPGNow(_ item: Item) async {
        let key = "\(item.accountId):\(item.streamId)"
        guard item.type == .live, !epgInFlight.contains(key), let urls = xtreamURLs(for: item.accountId) else { return }
        if let t = epgStamp[key], Date().timeIntervalSince(t) < 300 { return }
        epgInFlight.insert(key); defer { epgInFlight.remove(key) }
        let entries = try? await XtreamClient(urls: urls).epgShort(streamId: item.streamId, limit: 2)
        guard !Task.isCancelled else { return }
        epgStamp[key] = Date()
        epgNow[key] = entries?.first?.title
        epgEntries[key] = entries ?? []
    }

    // MARK: Preferences, info, backup

    public var refreshHours: Int { UserDefaults.standard.integer(forKey: "refreshHours") }                     // 0 = only when the app opens
    public var categoryFilter: CategoryFilter { CategoryFilter(UserDefaults.standard.string(forKey: "hiddenCategoryWords") ?? "") }

    /// Syncs what is shown (the playlist, or all of them) once `refreshHours` have passed since the last sync; ends when cancelled.
    public func refreshLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled else { return }
            if !syncing, !accounts.isEmpty, RefreshSchedule.isDue(hours: refreshHours, lastSync: lastSync, now: Date()) { await sync() }
        }
    }

    /// The hidden words changed: the sidebar and the lists are filtered again (a selected category that is now hidden is left).
    public func hiddenCategoriesChanged() {
        loadCategories()
        if !selectedCategory.hasPrefix("__"), !categories.contains(where: { categoryTag($0) == selectedCategory }) { selectedCategory = "__all" }
        scheduleSearch()
    }

    /// Details exist only for movies and series of an Xtream playlist (an M3U file has none).
    public func hasInfo(_ item: Item) -> Bool { item.type != .live && playlist(id: item.accountId)?.kind == .xtream }

    /// The provider's details for a title: cached for 14 days, else fetched (never for a whole list, only when a sheet asks).
    public func loadInfo(_ item: Item, refresh: Bool = false) async throws -> ItemInfo {
        guard let a = playlist(id: item.accountId), let id = a.id else { return ItemInfo() }
        guard hasPassword(a) else { throw IPTVError.badCredentials }
        return try await SyncService(db: db).info(account: a, password: secrets.password(for: id), type: item.type, streamId: item.streamId, refresh: refresh)
    }

    /// Whatever is cached, however old: for showing something at once while a fresh copy is on its way.
    public func cachedInfo(_ item: Item) async -> ItemInfo? {
        try? await db.dbQueue.read { try ItemInfoStore.cached($0, accountId: item.accountId, type: item.type, streamId: item.streamId, maxAge: nil) }
    }

    public func exportBackup(to url: URL) async throws {
        try await db.dbQueue.read { try Backup.make($0) }.write(to: url)
    }

    /// Merges a backup file. New playlists are synced; an Xtream one has no password yet, so sync() asks for it.
    open func importBackup(from url: URL) async throws {
        let backup = try Backup.read(from: url)
        let added = try await db.dbQueue.write { try backup.merge(into: $0) }.compactMap(\.id)
        loadAccounts(); loadFavorites(); scheduleSearch()
        await sync(accounts.filter { added.contains($0.id ?? 0) })
    }

    /// Checks a new source before it is saved (the same check on every platform): Xtream must log in, an M3U link must answer with a playlist.
    /// Throws an error whose localizedDescription is fit to show.
    nonisolated public static func testConnection(kind: AccountKind, server: String, username: String, password: String, url: String) async throws {
        if kind == .xtream {
            guard let u = XtreamURLs(server: server, username: username, password: password) else { throw IPTVError.badConfig }
            try await XtreamClient(urls: u).authenticate()
        } else {
            guard let u = URL(string: url.trimmingCharacters(in: .whitespaces)), u.scheme != nil, u.host != nil else { throw IPTVError.badConfig }
            var r = URLRequest(url: u); r.setValue("bytes=0-1023", forHTTPHeaderField: "Range")
            let (d, _) = try await apiSession.data(for: r)
            guard String(decoding: d, as: UTF8.self).drop(while: { $0.isWhitespace || $0 == "\u{FEFF}" }).hasPrefix("#EXTM3U")
            else { throw IPTVError.badResponse }
        }
    }

    /// The add-source form is complete (name, and server + user for Xtream or a link for M3U).
    nonisolated public static func isValidSource(kind: AccountKind, name: String, server: String, username: String, url: String) -> Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (kind == .xtream ? !server.isEmpty && !username.isEmpty : !url.isEmpty)
    }

    public func clear(_ kind: ClearKind) {
        switch kind {
        case .history: _ = try? db.dbQueue.write { try UserData.clearHistory($0) }
        case .favorites: _ = try? db.dbQueue.write { try UserData.clearFavorites($0) }
        case .images: URLCache.shared.removeAllCachedResponses()
        }
        loadFavorites(); scheduleSearch()
    }
}
