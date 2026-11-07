import Foundation
import Observation

/// One libmpv playback and the state a player UI shows (position, pause, speed, tracks, buffering, failure), polled twice a second.
/// It also carries the rules the Mac player model has: a dropped live stream is reloaded a few times, a paused live stream that went
/// stale is reloaded on resume, "the movie ended" is reported once, the sleep timer, and progress saving that never writes a 0 position.
/// The iOS player is built on it; the Mac `PlayerModel` keeps its own copy of the same rules.
/// No UI and no localization in here: `failure` is mpv's reason, the app words the message.
@MainActor @Observable
public final class PlaybackController {
    public let mpv: MPVPlayer
    /// What mpv was asked to open (a URL, or any mpv source string).
    public private(set) var source: String?
    public private(set) var isLive = false
    public private(set) var position = 0.0
    public private(set) var duration = 0.0
    public private(set) var paused = false
    public private(set) var speed = 1.0
    public private(set) var tracks: [Track] = []
    /// "4K", "FHD", "HD", "SD" for the picture being decoded; nil until the size is known (or for audio only).
    public private(set) var quality: String?
    /// Waiting for data: loading the first frame, a seek, or an empty cache.
    public private(set) var buffering = false
    public private(set) var atEnd = false
    /// True once the stream failed for good (a live stream only after its retries); `failure` is mpv's reason.
    public private(set) var failed = false
    public private(set) var failure: String?
    public private(set) var sleepMinutesLeft: Int?

    /// (position, duration, background): periodic saves are `background` so they never wait behind a running catalog sync write.
    @ObservationIgnored public var onSaveProgress: ((Double, Double, Bool) -> Void)?
    /// A movie/episode reached its end (true) or left it again (false).
    @ObservationIgnored public var onEndChanged: ((Bool) -> Void)?
    /// The sleep timer ran out.
    @ObservationIgnored public var onSleep: (() -> Void)?

    @ObservationIgnored private var recovery = LiveRecovery()
    @ObservationIgnored private var end = EndOfMedia()
    @ObservationIgnored private var pauseClock = PauseClock()
    @ObservationIgnored private var sleepTimer = SleepTimer()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var ticks = 0
    @ObservationIgnored private var closed = false
    @ObservationIgnored private var retryPending = false
    @ObservationIgnored private var generation = 0      // bumped on every explicit load: a stale retry timer cannot reload an old item
    @ObservationIgnored private let retryDelay: TimeInterval

    /// `tickInterval` nil = no timer (tests call `tick(now:)`); `retryDelay` is the pause before a live reload.
    public init(subLang: String?, audioLang: String?, tickInterval: TimeInterval? = 0.5, retryDelay: TimeInterval = LiveRecovery.delay) {
        mpv = MPVPlayer(subLang: subLang, audioLang: audioLang)
        self.retryDelay = retryDelay
        mpv.onEndFile = { [weak self] isError in
            guard isError else { return }
            Task { @MainActor in self?.handleFailure() }
        }
        if let tickInterval {
            timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
        }
    }

    // MARK: Loading

    /// Starts `url` (the first one, or the next channel/episode: the old position is saved first).
    public func play(_ url: URL, isLive: Bool, start: Double, speed: Double = 1) { play(url.absoluteString, isLive: isLive, start: start, speed: speed) }

    /// `speed` is the one the new item starts at: 1, or what the user kept for this series.
    public func play(_ source: String, isLive: Bool, start: Double, speed: Double = 1) {
        guard !closed else { return }
        saveIfLoaded(background: false)
        generation += 1
        self.source = source; self.isLive = isLive
        recovery.reset(); end.newFile(); pauseClock.reset()
        position = 0; duration = 0; atEnd = false; failed = false; failure = nil; retryPending = false; paused = false; buffering = true; tracks = []
        setSpeed(speed)
        mpv.load(source, start: start)
    }

    /// The failure screen's Retry: a live stream starts again at the live edge, a movie at the position it had.
    public func retry() {
        guard !closed, let source else { return }
        generation += 1
        recovery.reset(); retryPending = false; failed = false; failure = nil; buffering = true
        let start = isLive ? 0 : position
        position = 0
        mpv.load(source, start: start)
    }

    private func handleFailure() {
        guard !closed, !retryPending, !failed else { return }
        if isLive, recovery.failed() {
            retryPending = true
            let gen = generation
            DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
                guard let self, !self.closed, self.generation == gen, let source = self.source else { return }
                self.retryPending = false
                self.position = 0; self.recovery.reloaded()
                self.mpv.load(source, start: 0)
            }
        } else {
            failed = true
            failure = mpv.lastError
            buffering = false
        }
    }

    // MARK: Transport

    public func togglePause(now: Date = Date()) { setPlaying(mpv.flag("pause"), now: now) }

    /// `true` plays, `false` pauses. A live stream that sat paused long enough is reloaded instead of resumed from its old cache.
    public func setPlaying(_ play: Bool, now: Date = Date()) {
        if play {
            if atEnd, !isLive { replay(); return }
            if pauseClock.resumed(at: now, isLive: isLive), let source {
                generation += 1
                mpv.load(source, start: 0)
            }
            mpv.setProperty("pause", "no")
        } else {
            pauseClock.paused(at: now)
            mpv.setProperty("pause", "yes")
        }
        paused = !play
    }

    /// From the start again after the end (keep-open leaves the player paused on the last frame).
    public func replay() {
        mpv.seek(to: 0)
        mpv.setProperty("pause", "no")
        position = 0; paused = false
    }

    /// The position shown moves at once (the next tick would make a dragged bar jump back).
    public func seek(by s: Double) {
        mpv.seek(by: s)
        position = max(0, duration > 0 ? min(position + s, duration) : position + s)
    }

    public func seek(to s: Double) {
        mpv.seek(to: s)
        position = max(0, duration > 0 ? min(s, duration) : s)
    }

    /// Clamped to 0.25...4 and rounded to 0.05, set at once.
    public func setSpeed(_ s: Double) {
        let v = PlaybackSpeed.normalized(s)
        speed = v
        mpv.setProperty("speed", String(v))
    }

    /// 0 turns the timer off.
    public func setSleep(minutes: Int, now: Date = Date()) {
        sleepTimer.set(minutes: minutes, now: now)
        sleepMinutesLeft = sleepTimer.remainingMinutes(now: now)
    }

    // MARK: Polling

    public func tick(now: Date = Date()) {
        guard !closed else { return }
        if sleepTimer.expired(now: now) {
            sleepTimer.cancel(); sleepMinutesLeft = nil
            onSleep?()
            return
        }
        let left = sleepTimer.remainingMinutes(now: now)
        if left != sleepMinutesLeft { sleepMinutesLeft = left }
        if let p = mpv.double("time-pos") { position = p }
        duration = mpv.double("duration") ?? 0
        let eof = mpv.isAtEnd
        if isLive {
            recovery.observe(position: position)
            // With keep-open a dropped live stream just stops at EOF (no end-file event): treat it as a failure.
            if eof, !failed { handleFailure() }
        } else if let ended = end.observe(atEOF: eof, position: position, duration: duration) {
            atEnd = ended
            onEndChanged?(ended)
        }
        paused = mpv.flag("pause")
        speed = mpv.double("speed") ?? speed
        let q = VideoQuality.label(width: mpv.double("video-params/w") ?? 0, height: mpv.double("video-params/h") ?? 0)
        if q != quality { quality = q }        // an adaptive stream can change size while it plays
        buffering = !failed && !paused && !atEnd && (mpv.flag("paused-for-cache") || mpv.flag("seeking") || (position == 0 && duration == 0))
        ticks += 1
        if tracks.isEmpty || ticks % 4 == 0 { tracks = mpv.tracks() }   // the menus fill as soon as the file opened
        if ticks % 20 == 0 { saveIfLoaded(background: true) }
    }

    /// A position of 0 means "nothing played yet" (still loading or the load failed): saving it would erase the resume point.
    private func saveIfLoaded(background: Bool) { if !isLive, position > 0 { onSaveProgress?(position, duration, background) } }

    /// Saves now (the app goes to the background, where it may be killed without notice).
    public func saveNow() { saveIfLoaded(background: false) }

    public func close() {
        guard !closed else { return }
        closed = true
        saveIfLoaded(background: false)
        timer?.invalidate(); timer = nil
        mpv.shutdown()
    }
}
