import AVFAudio
import UIKit
import Observation
import IPTVCore
import IPTVAppKit
import IPTVPlayer

/// One playing stream on iPhone/iPad: libmpv (PlaybackController) + its OpenGL ES view, the touch interactions, and the system around it
/// (PlayerSystem). The model creates it for a PlayRequest (`PhonePlayer(request:)`), asks it to `replace(with:)` for the next channel or
/// episode, and `close()`s it. The screen (PlayerScreen) only draws what is here; the rules live in IPTVPlayer / IPTVAppKit (tested).
@MainActor @Observable
final class PhonePlayer {
    enum LevelKind { case brightness, volume }

    private(set) var request: PlayRequest
    let view: MPVVideoView            // one view for the player's lifetime
    let core: PlaybackController
    let preview = SeekPreview()
    let levels = SystemLevels()
    @ObservationIgnored let upNext = UpNext()
    /// The skip intro / skip credits buttons of the episode that plays (nil for anything that is not an episode).
    var skipControls: SkipControls?
    @ObservationIgnored private let system = PlayerSystem()

    /// The model hands out the saved position: (position, duration).
    @ObservationIgnored var onSaveProgress: ((_ position: Double, _ duration: Double) -> Void)?
    @ObservationIgnored var onClose: (() -> Void)?
    @ObservationIgnored private weak var model: PhoneModel?

    // MARK: what the screen shows
    var controls: ControlsVisibility
    var scrubbing = false                  // the seek bar or a horizontal drag is active
    var sheetOpen = false                  // a sheet or the file picker is up
    var voiceOver = UIAccessibility.isVoiceOverRunning
    var skipHUD: (side: PlayerGestures.Side, label: String, id: Int)?
    var levelHUD: (kind: LevelKind, value: Double, id: Int)?
    var toast: (symbol: String?, text: String, id: Int)?
    var dragScrub: (time: Double, delta: Double)?
    var boosting = false                   // long press: 2x while held
    private(set) var pipActive = false     // the Picture in Picture window is up
    private(set) var episodes: [Episode] = []
    private(set) var canZapNext = false
    private(set) var canZapPrevious = false
    var videoScale: VideoScale { didSet { UserDefaults.standard.set(videoScale.rawValue, forKey: "videoScale"); core.mpv.apply(videoScale) } }
    var subScale: Double { didSet { UserDefaults.standard.set(subScale, forKey: "subScale"); applySubtitleStyle() } }
    var subDelay: Double { didSet { UserDefaults.standard.set(subDelay, forKey: "subDelay"); applySubtitleStyle() } }

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var skipper = SkipAccumulator()
    @ObservationIgnored private var hudSerial = 0
    @ObservationIgnored private var hudTasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var levelStart = 0.0
    @ObservationIgnored private var scrubStart = 0.0
    @ObservationIgnored private var speedBeforeBoost = 1.0
    @ObservationIgnored private var mpvVolume = 100.0
    @ObservationIgnored private var episodesFor: String?
    @ObservationIgnored private var queueTask: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var closed = false

    // MARK: forwarded state
    var paused: Bool { core.paused }
    var position: Double { core.position }
    var duration: Double { core.duration }
    var quality: String? { core.quality }
    var speed: Double { core.speed }
    var tracks: [Track] { core.tracks }
    var buffering: Bool { core.buffering }
    var atEnd: Bool { core.atEnd }
    var isLive: Bool { request.isLive }
    var sleepMinutesLeft: Int? { core.sleepMinutesLeft }
    var error: String? { core.failed ? [L("player.error"), core.failure].compactMap { $0 }.joined(separator: ": ") : nil }

    // MARK: preferences (the same defaults as the Mac player)
    var seekStep: Int { Self.number("seekStep", 10).map(Int.init) ?? 10 }
    var networkPreviews: Bool { UserDefaults.standard.bool(forKey: "seekPreview") }
    var autoNextEpisode: Bool { UserDefaults.standard.object(forKey: "autoNextEpisode") as? Bool ?? true }
    private var barsHide: Double { Self.number("barsHideSeconds", 3) ?? 3 }

    /// A stored number (the Mac settings store Ints and Doubles; a launch argument arrives as text, which `double(forKey:)` also reads).
    private static func number(_ key: String, _ fallback: Double) -> Double? {
        UserDefaults.standard.object(forKey: key) == nil ? fallback : UserDefaults.standard.double(forKey: key)
    }

    init(request: PlayRequest) {
        self.request = request
        let d = UserDefaults.standard
        core = PlaybackController(subLang: d.string(forKey: "prefSubLang"), audioLang: d.string(forKey: "prefAudioLang"))
        view = MPVVideoView(player: core.mpv)
        videoScale = VideoScale(rawValue: d.string(forKey: "videoScale") ?? "") ?? .fit
        subScale = Self.number("subScale", 1) ?? 1
        subDelay = Self.number("subDelay", 0) ?? 0
        controls = ControlsVisibility(hideAfter: Self.number("barsHideSeconds", 3) ?? 3)
        core.mpv.apply(videoScale)
        core.mpv.apply(BufferSize(rawValue: d.string(forKey: "bufferSize") ?? "") ?? .normal)
        applySubtitleStyle()
        core.onSaveProgress = { [weak self] position, duration, _ in self?.onSaveProgress?(position, duration) }
        core.onEndChanged = { [weak self] ended in self?.endChanged(ended) }
        core.onSleep = { [weak self] in self?.onClose?() }
        system.activate(commands, seekStep: seekStep) { [weak self] in
            guard let self, !self.closed else { return }
            self.core.play(self.request.url, isLive: self.request.isLive, start: self.request.start)
        }
        pushRemoteCommands()
        view.pipCommands = (setPlaying: { [weak self] on in self?.setPlaying(on) }, skip: { [weak self] s in self?.skip(by: s) },
                            restore: { [weak self] in self?.pipActive = false })
        view.onPiPChange = { [weak self] on in self?.pipActive = on }
        observers = [
            NotificationCenter.default.addObserver(forName: UIAccessibility.voiceOverStatusDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.voiceOver = UIAccessibility.isVoiceOverRunning }
            },
            NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.core.saveNow() }     // the app may be killed in the background without notice
            },
        ]
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in Task { @MainActor in self?.pulse() } }
    }

    /// The screen gives the player its model once (favorites, the channel list and the series episodes live there).
    func configure(model: PhoneModel) {
        guard self.model !== model else { return }
        self.model = model
        skipControls = model.skipControls(for: request)
        onClose = { [weak model] in model?.stopPlayback() }
        refreshQueues()
    }

    private var commands: PlayerSystem.Commands {
        PlayerSystem.Commands(
            play: { [weak self] in self?.setPlaying(true) },
            pause: { [weak self] in self?.setPlaying(false) },
            toggle: { [weak self] in self?.togglePause() },
            skip: { [weak self] s in self?.skip(by: s) },
            seek: { [weak self] t in self?.seek(to: t) },
            next: { [weak self] in self?.goNext() },
            previous: { [weak self] in self?.zap(-1) },
            isPlaying: { [weak self] in !(self?.core.paused ?? true) })
    }

    private func pushRemoteCommands() {
        system.configureRemoteCommands(seekStep: seekStep, live: request.isLive, canGoNext: request.isLive ? canZapNext : nextEpisode != nil,
                                       canGoPrevious: request.isLive && canZapPrevious)
    }

    // MARK: Transport

    func togglePause() { system.userChose(); core.togglePause(); touchControls() }
    func setPlaying(_ on: Bool) { core.setPlaying(on) }
    func seek(to t: Double) { core.seek(to: t) }
    func skip(by s: Double) { core.seek(by: s) }
    func retry() { core.retry() }
    func close(restoringBrightness: Bool = true) {
        guard !closed else { return }
        closed = true
        view.stopPiP()
        core.close()            // saves the position
        timer?.invalidate(); timer = nil
        queueTask?.cancel(); hudTasks.values.forEach { $0.cancel() }
        upNext.cancel()
        preview.shutdown()
        observers.forEach(NotificationCenter.default.removeObserver); observers = []
        if restoringBrightness { levels.restoreBrightness() }
        system.deactivate()
    }

    /// The next channel or episode on the same player: the old position is saved first (PlaybackController.play).
    func replace(with r: PlayRequest) {
        guard !closed else { return }
        upNext.cancel()
        request = r
        skipControls = model?.skipControls(for: r)
        preview.reset()
        core.play(r.url, isLive: r.isLive, start: r.start)
        touchControls()
        refreshQueues()
        pushRemoteCommands()
    }

    // MARK: Channels and episodes

    func zap(_ step: Int) {
        guard let model, let item = request.item, let next = ChannelZap.neighbor(of: item, in: model.results, step: step) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        model.play(next)
    }

    var nextEpisode: Episode? {
        guard let key = request.episodeKey, key.hasPrefix("ep:") else { return nil }
        return EpisodeQueue.next(after: String(key.dropFirst(3)), in: episodes)
    }

    private func goNext() { if request.isLive { zap(1) } else { playUpNextNow() } }

    /// The skip button was pressed: the intro is jumped over; after the credits the next episode starts, or the picture goes to the end.
    func doSkip(_ offer: SkipOffer) {
        switch offer {
        case .intro(let to): seek(to: to); touchControls()
        case .credits:
            if nextEpisode != nil { playUpNextNow() } else { seek(to: max(duration - 1, 0)) }
        }
    }

    private func refreshQueues() {
        guard let model else { return }
        if request.isLive, let item = request.item {
            canZapNext = ChannelZap.neighbor(of: item, in: model.results, step: 1) != nil
            canZapPrevious = ChannelZap.neighbor(of: item, in: model.results, step: -1) != nil
        } else { canZapNext = false; canZapPrevious = false }
        if request.episodeKey != nil, let item = request.item, let a = model.playlist(id: item.accountId), episodesFor != "\(a.id ?? 0):\(item.streamId)" {
            episodesFor = "\(a.id ?? 0):\(item.streamId)"
            queueTask?.cancel()
            queueTask = Task { [weak self, weak model] in
                guard let model else { return }
                let password = a.id.flatMap { model.secrets.password(for: $0) }
                let list = (try? await SyncService(db: model.db).episodes(account: a, password: password, seriesId: item.streamId)) ?? []
                guard !Task.isCancelled, let self else { return }
                self.episodes = list
                self.pushRemoteCommands()
            }
        }
        pushRemoteCommands()
    }

    private func endChanged(_ ended: Bool) {
        guard ended else { upNext.cancel(); return }
        guard autoNextEpisode, let next = nextEpisode, let series = request.item else { return }
        controls.touch(now: Date())
        upNext.begin(next) { [weak self] ep in self?.model?.playEpisode(ep, of: series) }
    }

    func playUpNextNow() {
        guard let next = upNext.episode ?? nextEpisode, let series = request.item else { return }
        upNext.cancel()
        model?.playEpisode(next, of: series)
    }

    // MARK: Subtitles, audio, speed, scale

    func applySubtitleStyle() {
        core.mpv.setProperty("sub-scale", String(subScale))
        core.mpv.setProperty("sub-delay", String(subDelay))
    }

    var subtitleSelection: Int { tracks.first { $0.type == "sub" && $0.selected }?.id ?? 0 }
    var audioSelection: Int { tracks.first { $0.type == "audio" && $0.selected }?.id ?? 0 }
    func selectSubtitle(_ id: Int) { core.mpv.setProperty("sid", id == 0 ? "no" : String(id)); interact() }
    func selectAudio(_ id: Int) { core.mpv.setProperty("aid", String(id)); interact() }
    func addSubtitle(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        core.mpv.addSubtitle(url)
        if access { url.stopAccessingSecurityScopedResource() }
    }

    func setSpeed(_ s: Double) { core.setSpeed(s) }
    func setSleep(minutes: Int) { core.setSleep(minutes: minutes); interact() }

    // MARK: Controls visibility

    /// A touch on the picture or a control shows the controls and restarts the countdown.
    func touchControls() { controls.touch(now: Date()) }

    /// A touch on a control that opens a menu: the controls stay long enough to choose (the menu has no callback to tell when it closes).
    func interact() { controls.touch(now: Date().addingTimeInterval(6)) }

    /// Shown by a touch, or held on screen because something needs it (paused, scrubbing, a sheet, an error, VoiceOver, the up-next card).
    var controlsVisible: Bool { controls.shown || holdControls }

    private var holdControls: Bool {
        paused || atEnd || scrubbing || sheetOpen || core.failed || voiceOver || upNext.isCounting
    }

    /// 4 times a second: the controls' countdown, the lock screen, the screen's idle timer.
    private func pulse() {
        guard !closed else { return }
        controls.hideAfter = barsHide
        controls.tick(now: Date(), holding: holdControls)
        skipControls?.update(position: position, duration: duration)
        system.setScreenAwake(!paused)
        system.updateNowPlaying(nowPlayingState)
        if view.pipMode == "pip" { view.syncPiP(position: position, duration: duration, paused: paused, speed: speed, live: isLive) }
    }

    /// The video moves into the system's floating window (the app can go away; the sound and the window go on).
    func startPiP() { if view.startPiP() { touchControls() } }
    var canPiP: Bool { MPVVideoView.pipSupported }

    private var nowPlayingState: NowPlayingState {
        NowPlayingState(title: request.title, subtitle: liveProgramme, isLive: request.isLive, position: position, duration: duration,
                        speed: speed, paused: paused)
    }

    /// The programme on now, for the lock screen and the title area (live channels with a guide).
    var liveProgramme: String? {
        guard request.isLive, let model else { return nil }
        return model.schedule.first { $0.end > Date() }?.title
    }

    // MARK: Gestures (all called by the gesture surface on the main thread)

    /// A single tap on the picture: another skip while a double-tap chain is running, else show/hide the controls.
    func singleTap(side: PlayerGestures.Side) {
        if !isLive, skipper.isChaining(now: Date()) { skipTapped(side) } else { controls.toggle(now: Date()) }
    }

    func doubleTap(side: PlayerGestures.Side) { if !isLive { skipTapped(side) } }

    private func skipTapped(_ side: PlayerGestures.Side) {
        let total = skipper.skip(side, step: seekStep, now: Date())
        core.seek(by: Double(side == .left ? -seekStep : seekStep))
        show(id: "skip") { [self] id in skipHUD = (side, SkipAccumulator.label(total), id) } clear: { [self] in skipHUD = nil }
    }

    func scrubBegan() {
        guard !isLive, duration > 0 else { return }
        scrubbing = true
        scrubStart = position
        dragScrub = (position, 0)
        controls.touch(now: Date())
    }

    func scrubChanged(translation: CGFloat, width: CGFloat) {
        guard scrubbing else { return }
        let t = PlayerGestures.scrubTarget(start: scrubStart, translation: translation, width: width, duration: duration)
        dragScrub = (t, t - scrubStart)
        previewAt(t)
    }

    func scrubEnded(commit: Bool) {
        guard scrubbing else { return }
        if commit, let t = dragScrub?.time { core.seek(to: t) }
        dragScrub = nil
        scrubbing = false
    }

    func levelBegan(side: PlayerGestures.Side) {
        let kind: LevelKind = side == .left ? .brightness : .volume
        levelStart = kind == .brightness ? levels.brightness : (levels.canSetVolume ? levels.volume : mpvVolume / 100)
        levelHUD = (kind, levelStart, levelHUD?.id ?? 0)
    }

    func levelChanged(side: PlayerGestures.Side, translationY: CGFloat, height: CGFloat) {
        let v = PlayerGestures.level(start: levelStart, translationY: translationY, height: height)
        let kind: LevelKind = side == .left ? .brightness : .volume
        applyLevel(kind, v)
        hudSerial += 1
        levelHUD = (kind, v, hudSerial)
    }

    /// A long fast flick down closes the player (and the level the drag moved is put back); anything else keeps the new level.
    func levelEnded(side: PlayerGestures.Side, translationY: CGFloat, velocityY: CGFloat) {
        let kind: LevelKind = side == .left ? .brightness : .volume
        if PlayerGestures.verticalEnd(translationY: translationY, velocityY: velocityY) == .dismiss {
            applyLevel(kind, levelStart)
            levelHUD = nil
            onClose?()
            return
        }
        let id = hudSerial
        hudTasks["level"]?.cancel()
        hudTasks["level"] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            if !Task.isCancelled, self?.levelHUD?.id == id { self?.levelHUD = nil }
        }
    }

    private func applyLevel(_ kind: LevelKind, _ v: Double) {
        switch kind {
        case .brightness: levels.setBrightness(v)
        case .volume:
            if levels.canSetVolume { levels.setVolume(v) }
            else { mpvVolume = v * 100; core.mpv.setProperty("volume", String(Int(mpvVolume))) }   // no system slider (Simulator): mpv's own gain
        }
    }

    /// The pinch is over: fit -> fill -> stretch by how far it went.
    func pinchEnded(scale: CGFloat) {
        let next = PlayerGestures.scale(after: scale, from: videoScale)
        guard next != videoScale else { return }
        videoScale = next
        UISelectionFeedbackGenerator().selectionChanged()
        showToast(symbol: "arrow.up.left.and.arrow.down.right", text: scaleName(next))
    }

    func scaleName(_ s: VideoScale) -> String { L("player.scale.\(s.rawValue)") }

    /// Long press: 2x while the finger stays down (movies and episodes only).
    func hold(_ down: Bool) {
        guard !isLive else { return }
        if down, !boosting {
            boosting = true
            speedBeforeBoost = speed
            core.setSpeed(2)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else if !down, boosting {
            boosting = false
            core.setSpeed(speedBeforeBoost)
        }
    }

    func showToast(symbol: String?, text: String) {
        show(id: "toast") { [self] id in toast = (symbol, text, id) } clear: { [self] in toast = nil }
    }

    /// The seek bar / drag asks for the frame under the finger (local files, or when the "seek preview" setting is on).
    func previewAt(_ time: Double) {
        preview.hover(time, duration: duration) { [request, networkPreviews] in
            PreviewSource.path(for: request.url, isLive: request.isLive, networkAllowed: networkPreviews)
        }
    }

    private func show(id key: String, delay: Duration = .milliseconds(800), set: (Int) -> Void, clear: @escaping () -> Void) {
        hudSerial += 1
        let id = hudSerial
        set(id)
        hudTasks[key]?.cancel()
        hudTasks[key] = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            let current: Int? = key == "skip" ? self.skipHUD?.id : self.toast?.id
            if current == id { clear() }
        }
    }
}
