import '../core/series_prefs.dart';

/// The speed and the subtitle language of the series that is playing: applied to each new episode, saved when the user changes them.
/// The player asks [speed] when an episode starts, calls [speedChanged] / [subtitleChosen] from the user's actions only (never for what
/// the keeper itself asked for), and offers every refreshed track list to [subtitleToApply]. Port of IPTVAppKit/SeriesPrefsKeeper.swift.
class SeriesPrefsKeeper {
  SeriesPrefsKeeper({required this.prefs, required this.save});

  SeriesPrefs prefs;
  final void Function(SeriesPrefs) save;
  bool _subtitleChecked = false;

  /// The speed an episode of this series starts at.
  double get speed => prefs.speed ?? 1;

  void speedChanged(double v) {
    final n = (v - 1).abs() < 0.001 ? null : v;
    if (n == prefs.speed) return;
    prefs = SeriesPrefs(speed: n, subtitle: prefs.subtitle);
    save(prefs);
  }

  /// [lang] and [title] of the chosen subtitle track; [off] = subtitles turned off.
  void subtitleChosen({String? lang, String? title, bool off = false}) {
    _subtitleChecked = true; // the user decided for this episode: nothing is applied over it
    final c = off ? SubtitleChoice.off : SubtitleChoice.of(lang: lang, title: title);
    if (c == null || c == prefs.subtitle) return;
    prefs = SeriesPrefs(speed: prefs.speed, subtitle: c);
    save(prefs);
  }

  /// Called with every refreshed subtitle track list of the episode: once the list is there, the saved choice is applied (once).
  SubtitleAction? subtitleToApply(List<({int id, String? lang, String? title})> tracks) {
    if (_subtitleChecked || tracks.isEmpty) return null;
    _subtitleChecked = true;
    return SeriesPrefsLogic.action(prefs.subtitle, tracks);
  }
}
