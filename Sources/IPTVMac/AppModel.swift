import Foundation
import AppKit
import Observation
import IPTVCore
@_exported import IPTVAppKit   // the views and tests of this module keep seeing PlayRequest, SearchScopeChoice, ClearKind, LibraryModel

#if !APPSTORE
enum UpdateStatus: Equatable { case none, available, downloading, ready, failed(String), upToDate, devBuild }
#endif

@MainActor @Observable
final class AppModel: LibraryModel {
    /// The last item played, and (set only when the player closes onto the list) the row the list scrolls back to.
    var lastPlayedID: Int64?
    var scrollTarget: Int64?
    var player: PlayerModel?
    var pip = false
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
        window = w; reopening = false; videoChrome = false
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
    /// The window is also dressed for video then, once per change and not on every call (this runs every 300 ms and on window events):
    /// dark, black and without the title bar line. In Light Mode a thin white line showed at the top of the screen; in Dark Mode it never did.
    func updateToolbar() {
        guard let w = window else { return }
        let hide = playerFullscreen && w.styleMask.contains(.fullScreen)
        if videoChrome != hide { videoChrome = hide; dress(w, forVideo: hide) }
        if let tb = w.toolbar, tb.isVisible == hide { tb.isVisible = !hide }
    }

    @ObservationIgnored private var videoChrome = false    // the window is dressed for full-screen video

    private func dress(_ w: NSWindow, forVideo on: Bool) {
        w.appearance = on ? NSAppearance(named: .darkAqua) : nil       // nil = follow the app (Settings > Appearance)
        w.backgroundColor = on ? .black : .windowBackgroundColor
        w.titlebarSeparatorStyle = on ? .none : .automatic
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

    #if !APPSTORE
    // MARK: Updates
    var update: AppUpdate?
    var updateStatus: UpdateStatus = .none
    var updateBannerDismissed = false
    private var stagedApp: URL?
    private var swapScheduled = false
    #endif

    static let keychainKey = "passwordsInKeychain"
    /// Where passwords live (Settings > Playlists > Keychain); `secrets` is this same store.
    let passwordStore: SwitchableSecretStore

    /// Moves every saved password to (or out of) the login keychain. false: the keychain refused, nothing changed.
    func storePasswordsInKeychain(_ on: Bool) -> Bool {
        do { try passwordStore.use(keychain: on, ids: accounts.compactMap(\.id)) } catch { return false }
        UserDefaults.standard.set(on, forKey: Self.keychainKey)
        return true
    }

    init() {
        let opened: (db: AppDatabase, movedAside: String?)
        do {
            opened = try AppDatabase.openRecovering(path: try AppDatabase.defaultPath())
        } catch {
            let a = NSAlert()
            a.messageText = L("db.error.title"); a.informativeText = "\(error.localizedDescription)\n\n\(L("db.error.body"))"
            a.runModal(); exit(1)
        }
        passwordStore = SwitchableSecretStore(database: DatabaseSecretStore(db: opened.db), keychain: KeychainSecretStore(),
                                              usesKeychain: UserDefaults.standard.bool(forKey: Self.keychainKey))
        super.init(db: opened.db, secrets: passwordStore, dbMovedAside: opened.movedAside)
        for n in [NSWindow.willEnterFullScreenNotification, NSWindow.willExitFullScreenNotification, NSWindow.didEnterFullScreenNotification,
                  NSWindow.didExitFullScreenNotification, NSWindow.didEndSheetNotification, NSWindow.didDeminiaturizeNotification,
                  NSWindow.didBecomeKeyNotification, NSWindow.willCloseNotification, NSApplication.didUnhideNotification] {
            NotificationCenter.default.addObserver(forName: n, object: nil, queue: .main) { [weak self] n in
                MainActor.assumeIsolated { self?.windowEvent(n) }
            }
        }
    }

    private var macStarted = false

    override func start() async {
        guard !macStarted else { return }                       // every new window runs .task again: sync/update loop/staged update must not
        macStarted = true
        if let aside = dbMovedAside {
            let a = NSAlert(); a.messageText = L("db.recovered.title"); a.informativeText = String(format: L("db.recovered.body"), aside); a.runModal()
        }
        #if !APPSTORE
        clearStaleUpdate()
        Task { await updateLoop() }
        #endif
        await super.start()
    }

    /// Merges a backup file; a playlist that still needs its password asks for it in the main window (a sheet of it, not of Settings).
    override func importBackup(from url: URL) async throws {
        try await super.importBackup(from: url)
        if passwordPrompt != nil { showMainWindow() }
    }

    // MARK: Playback

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

    override func playEpisode(_ e: Episode, of series: Item, in all: [Episode]? = nil) {
        guard let r = episodeRequest(e, of: series) else { return }
        cancelUpNext()
        if let all { episodeQueue = all }
        startPlayback(r)
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

    /// "Skip credits": the next episode starts at once; after the last one the picture goes to the end of the file.
    func skipCredits() {
        guard let r = playing, let key = r.episodeKey, let series = r.item else { return }
        if let next = EpisodeQueue.next(after: String(key.dropFirst(3)), in: episodeQueue) { playEpisode(next, of: series, in: episodeQueue) }
        else if let p = player { p.mpv.seek(to: max(p.duration - 1, 0)) }
    }

    override func startPlayback(_ r: PlayRequest) {
        defer { updateToolbar() }
        cancelUpNext()                                           // a pending "up next" must not replace what the user picked now
        if let id = r.item?.id { lastPlayedID = id }
        if pip { exitPiP() }
        if openFullscreen { setFullscreen(true) }
        // replace() saves the old position through onSaveProgress, which reads `playing`: switch only afterwards.
        if let p = player { p.replace(with: r, keeper: seriesPrefsKeeper(for: r)); p.skip = skipControls(for: r); playing = r; return }
        playing = r
        let p = PlayerModel(request: r, keeper: seriesPrefsKeeper(for: r))
        p.skip = skipControls(for: r)
        p.onSaveProgress = { [weak self] pos, dur, background in
            guard let self, let cur = self.playing else { return }
            self.saveProgress(cur, position: pos, duration: dur, background: background)
        }
        p.onEndChanged = { [weak self] ended in self?.episodeEndChanged(ended) }
        p.onSleep = { [weak self] in self?.stopPlayback() }
        player = p
    }

    override func stopPlayback() {
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
    override func leavePlayerForBrowsing() { if playing != nil && !pip { enterPiP() } }

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
}

extension AppModel {
    var currentVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0" }
}

#if !APPSTORE
// MARK: - Updates
extension AppModel {
    private static func flag(_ key: String) -> Bool { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
    var autoCheckUpdates: Bool { Self.flag("autoCheckUpdates") }
    var autoInstallUpdates: Bool { Self.flag("autoInstallUpdates") }
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
#endif
