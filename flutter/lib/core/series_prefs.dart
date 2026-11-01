/// What the user chose while watching one series, kept for its next episodes: the playback speed and the subtitle language
/// (a new episode would otherwise start at normal speed with the provider's default subtitles). Port of IPTVCore/SeriesPrefs.swift.
class SeriesPrefs {
  const SeriesPrefs({this.speed, this.subtitle});

  /// null: normal speed.
  final double? speed;

  /// null: the user never chose; the player's own defaults apply.
  final SubtitleChoice? subtitle;

  bool get isEmpty => speed == null && subtitle == null;

  SeriesPrefs copyWith({double? Function()? speed, SubtitleChoice? Function()? subtitle}) =>
      SeriesPrefs(speed: speed != null ? speed() : this.speed, subtitle: subtitle != null ? subtitle() : this.subtitle);

  @override
  bool operator ==(Object other) => other is SeriesPrefs && other.speed == speed && other.subtitle == subtitle;

  @override
  int get hashCode => Object.hash(speed, subtitle);

  @override
  String toString() => 'SeriesPrefs($speed, $subtitle)';
}

/// The subtitles of a series: turned off, or in a language (the track's language as the engine reports it, or its title when it has none).
sealed class SubtitleChoice {
  const SubtitleChoice();

  static const off = SubtitleOff();

  /// The choice that picking a track stands for; null when the track names neither a language nor a title.
  static SubtitleChoice? of({String? lang, String? title}) {
    final l = lang?.trim().toLowerCase();
    if (l != null && l.isNotEmpty) return SubtitleLanguage(l);
    final t = title?.trim().toLowerCase();
    if (t != null && t.isNotEmpty) return SubtitleLanguage(t);
    return null;
  }

  String get stored => switch (this) { SubtitleOff() => 'off', SubtitleLanguage(:final language) => 'lang:$language' };

  static SubtitleChoice? fromStored(String? s) {
    if (s == null) return null;
    if (s == 'off') return off;
    if (s.startsWith('lang:') && s.length > 5) return SubtitleLanguage(s.substring(5));
    return null;
  }
}

final class SubtitleOff extends SubtitleChoice {
  const SubtitleOff();
  @override
  bool operator ==(Object other) => other is SubtitleOff;
  @override
  int get hashCode => 11;
  @override
  String toString() => 'off';
}

final class SubtitleLanguage extends SubtitleChoice {
  const SubtitleLanguage(this.language);
  final String language;
  @override
  bool operator ==(Object other) => other is SubtitleLanguage && other.language == language;
  @override
  int get hashCode => language.hashCode;
  @override
  String toString() => 'lang:$language';
}

/// What to do with the subtitles of a new episode: [track] the id of the track to show, or null for "off".
class SubtitleAction {
  const SubtitleAction.off() : track = null;
  const SubtitleAction.track(int this.track);
  final int? track;

  @override
  bool operator ==(Object other) => other is SubtitleAction && other.track == track;
  @override
  int get hashCode => track.hashCode;
}

abstract final class SeriesPrefsLogic {
  /// The subtitle track of this episode that matches the saved choice, or "off". Null when the choice is not there (no track in that
  /// language in this episode): the player's default stays. [tracks] are the subtitle tracks only.
  static SubtitleAction? action(SubtitleChoice? choice, List<({int id, String? lang, String? title})> tracks) {
    switch (choice) {
      case null:
        return null;
      case SubtitleOff():
        return const SubtitleAction.off();
      case SubtitleLanguage(:final language):
        final w = language.toLowerCase();
        for (final t in tracks) {
          if (t.lang?.toLowerCase() == w) return SubtitleAction.track(t.id);
        }
        for (final t in tracks) {
          if (t.title?.toLowerCase() == w) return SubtitleAction.track(t.id);
        }
        return null;
    }
  }
}
