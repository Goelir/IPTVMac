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
    private var wasAtEnd = false

    init(request: PlayRequest) {
        let d = UserDefaults.standard
        let mpv = MPVPlayer(subLang: d.string(forKey: "prefSubLang"), audioLang: d.string(forKey: "prefAudioLang"))
        self.mpv = mpv
        self.videoView = MPVVideoView(player: mpv)
        self.request = request
        applySubtitleStyle()
        mpv.onEndFile = { [weak self] isError in
            guard isError else { return }
            Task { @MainActor in self?.handleFailure() }
        }
        mpv.load(request.url, start: request.start)
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func toggleDoubleSpeed() { mpv.setProperty("speed", speed == 2 ? "1" : "2") }

    func applySubtitleStyle() {
        let d = UserDefaults.standard
        mpv.setProperty("sub-scale", String(d.object(forKey: "subScale") as? Double ?? 1.0))
        mpv.setProperty("sub-delay", String(d.object(forKey: "subDelay") as? Double ?? 0))
    }

    func replace(with new: PlayRequest) {
        if !request.isLive { onSaveProgress?(position, duration) }
        wasAtEnd = true   // the old file may still report its end for a tick; only a real false -> true change counts
        request = new; retries = 0; error = nil; position = 0; duration = 0; lastPos = 0; retryPending = false
        mpv.setProperty("speed", "1")
        mpv.load(new.url, start: new.start)
    }

    private func handleFailure() {
        guard !closed, !retryPending else { return }
        if request.isLive && retries < 3 {
            retries += 1
            retryPending = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self, !self.closed else { return }
                self.retryPending = false
                self.mpv.load(self.request.url, start: 0)
            }
        } else { error = [L("player.error"), mpv.lastError].compactMap { $0 }.joined(separator: ": ") }
    }

    func retry() { guard !closed else { return }; retries = 0; retryPending = false; error = nil; mpv.load(request.url, start: request.isLive ? 0 : position) }

    private func tick() {
        guard !closed else { return }
        position = mpv.double("time-pos") ?? position
        if request.isLive {
            if position > lastPos + 0.5 { retries = 0; lastPos = position }   // playing again: the next drop gets fresh retries
            // With keep-open a dropped live stream just stops at EOF (no end-file event): treat it as a failure.
            if mpv.isAtEnd && error == nil { handleFailure() }
        }
        duration = mpv.double("duration") ?? 0
        if !request.isLive {
            let atEnd = mpv.isAtEnd && duration > 0
            if atEnd != wasAtEnd { wasAtEnd = atEnd; onEndChanged?(atEnd) }
        }
        paused = mpv.flag("pause")
        speed = mpv.double("speed") ?? 1
        ticks += 1
        if ticks % 4 == 0 { tracks = mpv.tracks() }
        if ticks % 20 == 0, !request.isLive { onSaveProgress?(position, duration) }
    }

    func close() {
        guard !closed else { return }
        closed = true
        if !request.isLive { onSaveProgress?(position, duration) }
        timer?.invalidate(); timer = nil
        mpv.shutdown()
    }
}
