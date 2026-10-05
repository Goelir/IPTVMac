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
    var tracks: [Track] = []
    var error: String?
    private(set) var request: PlayRequest
    private var retries = 0
    private var timer: Timer?
    private var ticks = 0
    var onSaveProgress: ((Double, Double) -> Void)?

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

    func applySubtitleStyle() {
        let d = UserDefaults.standard
        mpv.setProperty("sub-scale", String(d.object(forKey: "subScale") as? Double ?? 1.0))
        mpv.setProperty("sub-delay", String(d.object(forKey: "subDelay") as? Double ?? 0))
    }

    func replace(with new: PlayRequest) {
        if !request.isLive { onSaveProgress?(position, duration) }
        request = new; retries = 0; error = nil; position = 0; duration = 0
        mpv.load(new.url, start: new.start)
    }

    private func handleFailure() {
        if request.isLive && retries < 3 {
            retries += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self else { return }
                self.mpv.load(self.request.url, start: 0)
            }
        } else { error = L("player.error") }
    }

    func retry() { retries = 0; error = nil; mpv.load(request.url, start: request.isLive ? 0 : position) }

    private func tick() {
        position = mpv.double("time-pos") ?? position
        duration = mpv.double("duration") ?? 0
        paused = mpv.flag("pause")
        ticks += 1
        if ticks % 4 == 0 { tracks = mpv.tracks() }
        if ticks % 20 == 0, !request.isLive { onSaveProgress?(position, duration) }
    }

    func close() {
        if !request.isLive { onSaveProgress?(position, duration) }
        timer?.invalidate(); timer = nil
        mpv.shutdown()
    }
}
