import Foundation
import IPTVCore

/// The speed and the subtitle language of the series that is playing: applied to each new episode, saved when the user changes them.
/// The player asks `speed` when an episode starts, calls `speedChanged` / `subtitleChosen` from the user's actions only (never for what
/// the keeper itself asked for), and offers every refreshed track list to `subtitleToApply`.
@MainActor
public final class SeriesPrefsKeeper {
    public private(set) var prefs: SeriesPrefs
    private let save: (SeriesPrefs) -> Void
    private var subtitleChecked = false

    public init(prefs: SeriesPrefs, save: @escaping (SeriesPrefs) -> Void) { self.prefs = prefs; self.save = save }

    /// The speed an episode of this series starts at.
    public var speed: Double { prefs.speed ?? 1 }

    public func speedChanged(_ v: Double) {
        let n = abs(v - 1) < 0.001 ? nil : v
        guard n != prefs.speed else { return }
        prefs.speed = n; save(prefs)
    }

    /// `lang` and `title` of the chosen subtitle track; both nil with `off` = subtitles turned off.
    public func subtitleChosen(lang: String?, title: String?, off: Bool = false) {
        subtitleChecked = true      // the user decided for this episode: nothing is applied over it
        let c: SubtitleChoice? = off ? SubtitleChoice.off : SubtitleChoice.of(lang: lang, title: title)
        guard let c, c != prefs.subtitle else { return }
        prefs.subtitle = c; save(prefs)
    }

    /// Called with every refreshed subtitle track list of the episode: once the list is there, the saved choice is applied (once).
    public func subtitleToApply(tracks: [(id: Int, lang: String?, title: String?)]) -> SubtitleAction? {
        guard !subtitleChecked, !tracks.isEmpty else { return nil }
        subtitleChecked = true
        return SeriesPrefsLogic.action(for: prefs.subtitle, tracks: tracks)
    }
}
