import 'dart:math' show max;

import 'package:iptvmac/core/episode_queue.dart';
import 'package:iptvmac/core/models.dart';
import 'package:iptvmac/core/user_data.dart';
import 'package:sqlite3/sqlite3.dart';

/// A title that can be resumed, with how far along it is (and, for a series, the episode that was last watched).
class ContinueEntry {
  const ContinueEntry(this.item, {this.fraction, this.season, this.episode, this.episodeId, this.episodeTitle, this.position, this.duration});
  final Item item;
  final double? fraction; // 0...1, null when unknown
  final int? season, episode;

  /// For a series: the episode that was left (stream id and title), so the entry resumes it, and where in it.
  final String? episodeId, episodeTitle;
  final double? position, duration;

  /// Seconds still to watch, when the length is known.
  double? get secondsLeft => position == null || duration == null || duration! <= 0 ? null : (duration! - position!).clamp(0.0, double.infinity);
}

class EpisodeProgress {
  const EpisodeProgress(this.position, this.duration, this.rank);
  final double position, duration;
  final int rank; // 0 = watched longest ago; the highest rank is the latest
  double get fraction => duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0;
  bool get isWatched => fraction > 0.95;
}

/// Port of WatchProgress.swift (continue-watching shelves, per-episode progress, "what to watch next").
abstract final class WatchProgress {
  static double? _fraction(num p, num d) => d > 0 ? (p / d).clamp(0.0, 1.0).toDouble() : null;

  /// The continue-watching list of one type with progress, newest first.
  static List<ContinueEntry> continueEntries(Database db, {int? accountId, required ItemType type, int limit = 20}) {
    return [
      for (final item in UserData.continueWatching(db, accountId: accountId, type: type).take(limit))
        _entry(db, item, type),
    ];
  }

  static ContinueEntry _entry(Database db, Item item, ItemType type) {
    if (type == ItemType.series) {
      final r = db.select('''
        SELECT h.position, h.duration, e.season, e.number, e.streamId AS epId, e.title AS epTitle FROM history h
        JOIN episode e ON e.accountId = h.accountId AND h.streamId = 'ep:' || e.streamId
        WHERE e.accountId = ? AND e.seriesId = ? AND h.type = 'series' ORDER BY h.updated DESC, h.rowid DESC LIMIT 1
        ''', [item.accountId, item.streamId]);
      if (r.isNotEmpty) {
        final row = r.first;
        return ContinueEntry(item,
            fraction: _fraction(row['position'] as num, row['duration'] as num),
            season: row['season'] as int,
            episode: row['number'] as int,
            episodeId: row['epId'] as String,
            episodeTitle: row['epTitle'] as String?,
            position: (row['position'] as num).toDouble(),
            duration: (row['duration'] as num).toDouble());
      }
    }
    final r = db.select('SELECT position, duration FROM history WHERE accountId = ? AND type = ? AND streamId = ?',
        [item.accountId, item.type.name, item.streamId]);
    return ContinueEntry(item,
        fraction: r.isEmpty ? null : _fraction(r.first['position'] as num, r.first['duration'] as num),
        position: r.isEmpty ? null : (r.first['position'] as num).toDouble(),
        duration: r.isEmpty ? null : (r.first['duration'] as num).toDouble());
  }

  /// "S2 E5 · 23 min left": where the title was left. The three formats are the platform's localized strings ("S%d E%d" and so on,
  /// as functions). Null when nothing is known.
  static String? caption(ContinueEntry e, {required String Function(int season, int episode) episode, required String Function(String time) left, required String Function(int minutes) minutes}) {
    final ep = e.season != null && e.episode != null ? episode(e.season!, e.episode!) : null;
    final s = e.secondsLeft;
    final time = s == null ? null : left(minutes(max(1, (s / 60).ceil())));
    final line = [?ep, ?time].join(' · ');
    return line.isEmpty ? null : line;
  }

  /// Resume points of a series' episodes, keyed by the episode's stream id.
  static Map<String, EpisodeProgress> episodeProgress(Database db, {required int accountId}) {
    final rows = db.select(
        "SELECT streamId, position, duration FROM history WHERE accountId = ? AND type = 'series' AND streamId LIKE 'ep:%' ORDER BY updated, rowid",
        [accountId]);
    final out = <String, EpisodeProgress>{};
    var i = 0;
    for (final r in rows) {
      out[(r['streamId'] as String).substring(3)] = EpisodeProgress((r['position'] as num).toDouble(), (r['duration'] as num).toDouble(), i++);
    }
    return out;
  }

  /// What the series screen offers first: the episode left halfway (resume), else the one after the last finished, else the
  /// first. Null once every episode up to the last one is watched.
  static ({Episode episode, bool resume})? upNext(List<Episode> episodes, Map<String, EpisodeProgress> progress) {
    final ordered = [...episodes]..sort((a, b) => a.season != b.season ? a.season.compareTo(b.season) : a.number.compareTo(b.number));
    if (ordered.isEmpty) return null;
    final seen = [for (final e in ordered) if (progress[e.streamId] != null) (e, progress[e.streamId]!)];
    if (seen.isEmpty) return (episode: ordered.first, resume: false);
    final (last, p) = seen.reduce((a, b) => b.$2.rank > a.$2.rank ? b : a);
    if (!p.isWatched && p.position >= 5) return (episode: last, resume: true);
    final next = EpisodeQueue.next(last.streamId, ordered);
    return next == null ? null : (episode: next, resume: false);
  }

  /// Channel zapping: the channel before or after [current] in the list the user picked it from (wraps around).
  static Item? zapNeighbor(Item current, List<Item> list, int step) {
    final channels = [for (final i in list) if (i.type == ItemType.live) i];
    final i = channels.indexWhere((c) => c.accountId == current.accountId && c.streamId == current.streamId);
    if (channels.length < 2 || i < 0) return null;
    return channels[((i + step) % channels.length + channels.length) % channels.length];
  }
}
