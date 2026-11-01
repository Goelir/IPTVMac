import 'package:iptvmac/core/series_prefs.dart';
import 'package:iptvmac/core/skip_marks.dart';
import 'package:sqlite3/sqlite3.dart';

import 'models.dart';

/// Favorites and watch history. `accountId: null` = every playlist (here and in the queries below).
abstract final class UserData {
  /// Returns whether the item is a favorite now.
  static bool toggleFavorite(Database db, {required int accountId, required ItemType type, required String streamId}) {
    final args = [accountId, type.name, streamId];
    final exists = db.select('SELECT EXISTS(SELECT 1 FROM favorite WHERE accountId=? AND type=? AND streamId=?) e', args).first['e'] == 1;
    db.execute(
        exists
            ? 'DELETE FROM favorite WHERE accountId=? AND type=? AND streamId=?'
            : 'INSERT INTO favorite (accountId,type,streamId) VALUES (?,?,?)',
        args);
    return !exists;
  }

  /// Playlists may reuse the same stream id, so a favorite is identified by its playlist too.
  static String favoriteKey({required int accountId, required ItemType type, required String streamId}) =>
      '$accountId:${type.name}:$streamId';

  static Set<String> favoriteKeys(Database db, {int? accountId}) => {
        for (final r in db.select('SELECT accountId, type, streamId FROM favorite WHERE (? IS NULL OR accountId=?)', [accountId, accountId]))
          favoriteKey(accountId: r['accountId'] as int, type: ItemType.parse(r['type']) ?? ItemType.live, streamId: r['streamId'] as String)
      };

  static List<Item> favorites(Database db, {int? accountId, required ItemType type}) => Item.fromRows(db.select('''
      SELECT item.* FROM item JOIN favorite f ON f.accountId=item.accountId AND f.type=item.type AND f.streamId=item.streamId
      WHERE (? IS NULL OR item.accountId=?) AND item.type=? ORDER BY item.id
      ''', [accountId, accountId, type.name]));

  static void saveProgress(Database db,
      {required int accountId, required ItemType type, required String streamId, required double position, required double duration}) {
    // 0 / 0 means "nothing played yet" (still loading, load failed): saving it would erase the real resume point.
    if (!(duration > 0 && position.isFinite && duration.isFinite && position >= 0)) return;
    db.execute('''
      INSERT INTO history (accountId,type,streamId,position,duration,updated) VALUES (?,?,?,?,?,datetime('now'))
      ON CONFLICT(accountId,type,streamId) DO UPDATE SET position=excluded.position, duration=excluded.duration, updated=excluded.updated
      ''', [accountId, type.name, streamId, position, duration]);
  }

  /// The position to resume at, or null when there is none worth resuming (under 5 s in, or finished: over 95 %).
  static double? progress(Database db, {required int accountId, required ItemType type, required String streamId}) {
    final rows = db.select('SELECT position, duration FROM history WHERE accountId=? AND type=? AND streamId=?',
        [accountId, type.name, streamId]);
    if (rows.isEmpty) return null;
    final p = (rows.first['position'] as num).toDouble(), d = (rows.first['duration'] as num).toDouble();
    return (d > 0 && p / d > 0.95) || p < 5 ? null : p;
  }

  /// Settings > Clear data: every playlist's resume points / favorites.
  static void clearHistory(Database db) => db.execute('DELETE FROM history');
  static void clearFavorites(Database db) => db.execute('DELETE FROM favorite');

  static List<Item> continueWatching(Database db, {int? accountId, required ItemType type}) {
    var items = Item.fromRows(db.select('''
      SELECT item.* FROM item JOIN history h ON h.accountId=item.accountId AND h.type=item.type AND h.streamId=item.streamId
      WHERE (? IS NULL OR item.accountId=?) AND item.type=? AND (h.duration <= 0 OR h.position / h.duration <= 0.95)
      ORDER BY h.updated DESC
      ''', [accountId, accountId, type.name]));
    if (type == ItemType.series) {
      // Xtream episodes are saved as "ep:<episodeId>": map them to their series through the cached episode list.
      final viaEpisodes = Item.fromRows(db.select('''
        SELECT item.* FROM item JOIN (
            SELECT e.accountId AS aid, e.seriesId AS sid, MAX(h.updated) AS u FROM history h
            JOIN episode e ON e.accountId = h.accountId AND h.streamId = 'ep:' || e.streamId
            WHERE (? IS NULL OR h.accountId = ?) AND h.type = 'series' AND (h.duration <= 0 OR h.position / h.duration <= 0.95)
            GROUP BY e.accountId, e.seriesId) x ON x.aid = item.accountId AND x.sid = item.streamId
        WHERE item.type = 'series' ORDER BY x.u DESC
        ''', [accountId, accountId]));
      final have = {for (final i in items) i.id};
      items = [...viaEpisodes.where((i) => !have.contains(i.id)), ...items];
    }
    return items;
  }

  /// The marks of a series' intro and credits (empty when the user never marked any).
  static SkipMarks skipMarks(Database db, {required int accountId, required String seriesId}) {
    final r = db.select('SELECT introStart, introEnd, creditsLen FROM series_marks WHERE accountId=? AND seriesId=?', [accountId, seriesId]);
    if (r.isEmpty) return const SkipMarks();
    double? d(Object? v) => (v as num?)?.toDouble();
    return SkipMarks(introStart: d(r.first['introStart']), introEnd: d(r.first['introEnd']), creditsLen: d(r.first['creditsLen']));
  }

  /// Empty marks remove the row.
  static void saveSkipMarks(Database db, {required int accountId, required String seriesId, required SkipMarks marks}) {
    if (marks.isEmpty) {
      db.execute('DELETE FROM series_marks WHERE accountId=? AND seriesId=?', [accountId, seriesId]);
      return;
    }
    db.execute('''
      INSERT INTO series_marks (accountId, seriesId, introStart, introEnd, creditsLen) VALUES (?,?,?,?,?)
      ON CONFLICT(accountId, seriesId) DO UPDATE SET introStart=excluded.introStart, introEnd=excluded.introEnd, creditsLen=excluded.creditsLen
      ''', [accountId, seriesId, marks.introStart, marks.introEnd, marks.creditsLen]);
  }

  static SeriesPrefs seriesPrefs(Database db, {required int accountId, required String seriesId}) {
    final r = db.select('SELECT speed, subtitle FROM series_prefs WHERE accountId=? AND seriesId=?', [accountId, seriesId]);
    if (r.isEmpty) return const SeriesPrefs();
    return SeriesPrefs(speed: (r.first['speed'] as num?)?.toDouble(), subtitle: SubtitleChoice.fromStored(r.first['subtitle'] as String?));
  }

  /// Empty preferences remove the row.
  static void saveSeriesPrefs(Database db, {required int accountId, required String seriesId, required SeriesPrefs prefs}) {
    if (prefs.isEmpty) {
      db.execute('DELETE FROM series_prefs WHERE accountId=? AND seriesId=?', [accountId, seriesId]);
      return;
    }
    db.execute('''
      INSERT INTO series_prefs (accountId, seriesId, speed, subtitle) VALUES (?,?,?,?)
      ON CONFLICT(accountId, seriesId) DO UPDATE SET speed=excluded.speed, subtitle=excluded.subtitle
      ''', [accountId, seriesId, prefs.speed, prefs.subtitle?.stored]);
  }
}
