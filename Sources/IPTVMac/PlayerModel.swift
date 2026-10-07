import Foundation
import Observation
import IPTVPlayer

@MainActor @Observable
final class PlayerModel {
    let mpv: MPVPlayer
    let videoView: MPVVideoView          // one view for the player's lifetime; reparented between hosts
    var position = 0.0
    var duration = 0.0
    var paused = false
    var speed = 1.0
    var tracks: [Track] = []
    var error: String?
    private(set) var request: PlayRequest
    private var retries = 0
    private var timer: Timer?
    private var ticks = 0
    private var closed = false
    private var retryPending = false
    private var lastPos = 0.0
    var onSaveProgress: ((Double, Double) -> Void)?
    /// Called when a movie/episode reaches its end (true) and when it leaves the end again, e.g. after a seek back (false).
    var onEndChanged: ((Bool) -> Void)?
    /// Called once when the sleep timer runs out.
    var onSleep: (() -> Void)?
    private var sleepTimer = SleepTimer()        // lives and dies with the player, so it carries over channel/episode changes
    private(set) var sleepMinutesLeft: Int?      // for the moon button; nil = off
    private var wasAtEnd = false
    private var loadGen = 0                      // bumped on every explicit load, so a stale retry timer cannot reload an old item
    private var activity: NSObjectProtocol?       // keeps the display awake while a video plays (vo=libmpv has no window of its own)

    init(request: PlayRequest) {
        let d = UserDefaults.standard
        let mpv = MPVPlayer(subLang: d.string(forKey: "prefSubLang"), audioLang: d.string(forKey: "prefAudioLang"))
        self.mpv = mpv
        self.videoView = MPVVideoView(player: mpv)
        self.request = request
        applySubtitleStyle()
        applyVideoScale()
        applyBuffer()
        mpv.onEndFile = { [weak self] isError in
            guard isError else { return }
            Task { @MainActor in self?.handleFailure() }
        }
        mpv.load(request.url, start: request.start)
        activity = ProcessInfo.processInfo.beginActivity(options: [.idleDisplaySleepDisabled, .idleSystemSleepDisabled], reason: "Playing video")
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    /// Clamped to 0.25...4 and rounded to 0.05. `speed` is set at once (the 0.5 s tick would make a dragged slider jump back).
    func setSpeed(_ s: Double) {
        let v = PlaybackSpeed.normalized(s)
        speed = v
        mpv.setProperty("speed", String(v))
    }
    func stepSpeed(up: Bool) { setSpeed(PlaybackSpeed.step(from: speed, up: up)) }
    func toggleDoubleSpeed() { setSpeed(speed == 2 ? 1 : 2) }

    func applySubtitleStyle() {
        let d = UserDefaults.standard
        mpv.setProperty("sub-scale", String(d.object(forKey: "subScale") as? Double ?? 1.0))
        mpv.setProperty("sub-delay", String(d.object(forKey: "subDelay") as? Double ?? 0))
    }

    func applyVideoScale() { mpv.apply(VideoScale(rawValue: UserDefaults.standard.string(forKey: "videoScale") ?? "") ?? .fit) }
    func applyBuffer() { mpv.apply(BufferSize(rawValue: UserDefaults.standard.string(forKey: "bufferSize") ?? "") ?? .normal) }

    /// 0 turns the timer off.
    func setSleep(minutes: Int, now: Date = Date()) {
        sleepTimer.set(minutes: minutes, now: now)
        sleepMinutesLeft = sleepTimer.remainingMinutes(now: now)
    }

    /// A position of 0 means "nothing played yet" (file still loading or load failed): saving it would erase the resume point.
    private func saveIfLoaded() { if !request.isLive, position > 0 { onSaveProgress?(position, duration) } }

    func replace(with new: PlayRequest) {
        saveIfLoaded()
        loadGen += 1
        wasAtEnd = true   // the old file may still report its end for a tick; only a real false -> true change counts
        request = new; retries = 0; error = nil; position = 0; duration = 0; lastPos = 0; retryPending = false
        setSpeed(1)
        mpv.load(new.url, start: new.start)
    }

    private func handleFailure() {
        guard !closed, !retryPending else { return }
        if request.isLive && retries < 3 {
            retries += 1
            retryPending = true
            let gen = loadGen
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self, !self.closed, self.loadGen == gen else { return }
                self.retryPending = false
                self.position = 0; self.lastPos = 0          // time-pos restarts at 0 after a reload: the retry budget must refresh again
                self.mpv.load(self.request.url, start: 0)
            }
        } else { error = [L("player.error"), mpv.lastError].compactMap { $0 }.joined(separator: ": ") }
    }

    func retry() {
        guard !closed else { return }
        loadGen += 1; retries = 0; retryPending = false; error = nil
        let start = request.isLive ? 0 : (position > 0 ? position : request.start)
        position = 0; lastPos = 0
        mpv.load(request.url, start: start)
    }

    func tick(now: Date = Date()) {
        guard !closed else { return }
        if sleepTimer.expired(now: now) {
            sleepTimer.cancel(); sleepMinutesLeft = nil
            onSleep?()
            return
        }
        let left = sleepTimer.remainingMinutes(now: now)
        if left != sleepMinutesLeft { sleepMinutesLeft = left }
        position = mpv.double("time-pos") ?? position
        if request.isLive {
            if position > lastPos + 0.5 { retries = 0; lastPos = position }   // playing again: the next drop gets fresh retries
            // With keep-open a dropped live stream just stops at EOF (no end-file event): treat it as a failure.
            if mpv.isAtEnd && error == nil { handleFailure() }
        }
        duration = mpv.double("duration") ?? 0
        if !request.isLive {
            // A connection cut early also sets eof-reached: only the real end of the file starts the next episode.
            let atEnd = mpv.isAtEnd && duration > 0 && position >= duration - 15
            if atEnd != wasAtEnd { wasAtEnd = atEnd; onEndChanged?(atEnd) }
        }
        paused = mpv.flag("pause")
        speed = mpv.double("speed") ?? 1
        ticks += 1
        if ticks % 4 == 0 { tracks = mpv.tracks() }
        if ticks % 20 == 0 { saveIfLoaded() }
    }

    func close() {
        guard !closed else { return }
        closed = true
        saveIfLoaded()
        if let a = activity { ProcessInfo.processInfo.endActivity(a); activity = nil }
        timer?.invalidate(); timer = nil
        mpv.shutdown()
    }
}
