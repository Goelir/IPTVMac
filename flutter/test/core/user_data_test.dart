import 'package:flutter_test/flutter_test.dart';
import 'package:iptvmac/core/models.dart';
import 'package:iptvmac/core/secret_store.dart';
import 'package:iptvmac/core/user_data.dart';

import 'support.dart';

void main() {
  test('favorites toggle and list', () {
    final (db, a) = makeDB();
    addItem(db, a, 'One', sid: '1');
    addItem(db, a, 'Two', sid: '2');
    expect(db.write((d) => UserData.toggleFavorite(d, accountId: a, type: ItemType.live, streamId: '2')), isTrue);
    expect(db.read((d) => UserData.favorites(d, accountId: a, type: ItemType.live).map((i) => i.name)), ['Two']);
    expect(db.read((d) => UserData.favoriteKeys(d, accountId: a)), {'$a:live:2'});
    expect(db.write((d) => UserData.toggleFavorite(d, accountId: a, type: ItemType.live, streamId: '2')), isFalse);
    expect(db.read((d) => UserData.favorites(d, accountId: a, type: ItemType.live)), isEmpty);
  });

  test('favorite keys are account scoped so playlists reusing a stream id do not collide', () {
    final (db, a) = makeDB();
    final b = addAccount(db, 'second');
    addItem(db, a, 'In A', sid: '7');
    addItem(db, b, 'In B', sid: '7');
    db.write((d) => UserData.toggleFavorite(d, accountId: b, type: ItemType.live, streamId: '7'));
    final keys = db.read((d) => UserData.favoriteKeys(d));
    expect(keys, {UserData.favoriteKey(accountId: b, type: ItemType.live, streamId: '7')});
    expect(keys.contains(UserData.favoriteKey(accountId: a, type: ItemType.live, streamId: '7')), isFalse);
    expect(db.read((d) => UserData.favoriteKeys(d, accountId: a)), isEmpty);
  });

  test('favorites across all playlists', () {
    final (db, a) = makeDB();
    final b = addAccount(db, 'second');
    addItem(db, a, 'In A', sid: '7');
    addItem(db, b, 'In B', sid: '7');
    addItem(db, b, 'Not fav', sid: '8');
    db.write((d) {
      UserData.toggleFavorite(d, accountId: a, type: ItemType.live, streamId: '7');
      UserData.toggleFavorite(d, accountId: b, type: ItemType.live, streamId: '7');
    });
    expect(db.read((d) => UserData.favorites(d, type: ItemType.live).map((i) => i.name)), ['In A', 'In B']);
    expect(db.read((d) => UserData.favorites(d, accountId: b, type: ItemType.live).map((i) => i.name)), ['In B']);
  });

  test('continue watching across all playlists keeps progress per playlist', () {
    final (db, a) = makeDB();
    final b = addAccount(db, 'second');
    addItem(db, a, 'Film A', type: ItemType.movie, sid: '1');
    addItem(db, b, 'Film B', type: ItemType.movie, sid: '1');
    db.write((d) {
      UserData.saveProgress(d, accountId: a, type: ItemType.movie, streamId: '1', position: 10, duration: 100);
      UserData.saveProgress(d, accountId: b, type: ItemType.movie, streamId: '1', position: 50, duration: 100);
      d.execute("UPDATE history SET updated = datetime('now','-1 day') WHERE accountId = ?", [a]);
    });
    List<String> names(int? acc) => db.read((d) => UserData.continueWatching(d, accountId: acc, type: ItemType.movie).map((i) => i.name).toList());
    expect(names(null), ['Film B', 'Film A']);
    expect(names(a), ['Film A']);
    expect(db.read((d) => UserData.progress(d, accountId: b, type: ItemType.movie, streamId: '1')), 50);
  });

  test('continue watching series via episodes does not leak into a playlist with the same series id', () {
    final (db, a) = makeDB();
    final b = addAccount(db, 'second');
    addItem(db, a, 'Show A', type: ItemType.series, sid: '5');
    addItem(db, b, 'Show B', type: ItemType.series, sid: '5');
    db.write((d) {
      for (final aid in [a, b]) {
        Episode(accountId: aid, seriesId: '5', season: 1, number: 1, title: 'E1', streamId: '100').insert(d);
      }
      UserData.saveProgress(d, accountId: a, type: ItemType.series, streamId: 'ep:100', position: 10, duration: 100);
    });
    expect(db.read((d) => UserData.continueWatching(d, type: ItemType.series).map((i) => i.name)), ['Show A']);
  });

  test('progress resumes unless finished', () {
    final (db, a) = makeDB();
    db.write((d) => UserData.saveProgress(d, accountId: a, type: ItemType.movie, streamId: '9', position: 600, duration: 6000));
    expect(db.read((d) => UserData.progress(d, accountId: a, type: ItemType.movie, streamId: '9')), 600);
    db.write((d) => UserData.saveProgress(d, accountId: a, type: ItemType.movie, streamId: '9', position: 5900, duration: 6000));
    expect(db.read((d) => UserData.progress(d, accountId: a, type: ItemType.movie, streamId: '9')), isNull);
  });

  test('progress without a duration never overwrites the resume point', () {
    final (db, a) = makeDB();
    db.write((d) {
      UserData.saveProgress(d, accountId: a, type: ItemType.movie, streamId: '9', position: 600, duration: 6000);
      UserData.saveProgress(d, accountId: a, type: ItemType.movie, streamId: '9', position: 0, duration: 0); // still loading
      UserData.saveProgress(d, accountId: a, type: ItemType.movie, streamId: '9', position: double.nan, duration: 6000);
    });
    expect(db.read((d) => UserData.progress(d, accountId: a, type: ItemType.movie, streamId: '9')), 600);
  });

  test('continue watching is newest first and skips finished', () {
    final (db, a) = makeDB();
    for (final (n, s) in [('Old', '1'), ('New', '2'), ('Done', '3')]) {
      addItem(db, a, n, type: ItemType.movie, sid: s);
    }
    db.write((d) {
      UserData.saveProgress(d, accountId: a, type: ItemType.movie, streamId: '1', position: 10, duration: 100);
      UserData.saveProgress(d, accountId: a, type: ItemType.movie, streamId: '3', position: 99, duration: 100);
      UserData.saveProgress(d, accountId: a, type: ItemType.movie, streamId: '2', position: 10, duration: 100);
      d.execute("UPDATE history SET updated = datetime('now','-1 day') WHERE streamId = '1'");
    });
    expect(db.read((d) => UserData.continueWatching(d, accountId: a, type: ItemType.movie).map((i) => i.name)), ['New', 'Old']);
  });

  test('favorites can be sorted by name: case does not matter, numbers count by value, other scripts follow in letter order', () {
    final (db, a) = makeDB();
    final names = ['sport 10', 'Zeta', 'Sport 2', 'alpha', 'בבב', 'אאא'];
    for (var i = 0; i < names.length; i++) {
      addItem(db, a, names[i], sid: '$i');
      db.write((d) => UserData.toggleFavorite(d, accountId: a, type: ItemType.live, streamId: '$i'));
    }
    List<String> favs({required bool sorted}) =>
        db.read((d) => UserData.favorites(d, accountId: a, type: ItemType.live, sortedByName: sorted).map((i) => i.name).toList());
    expect(favs(sorted: false), names, reason: 'the provider order is the default');
    expect(favs(sorted: true), ['alpha', 'Sport 2', 'sport 10', 'Zeta', 'אאא', 'בבב']);
  });

  test('a title removed from Continue watching stays out until it is watched again', () {
    final (db, a) = makeDB();
    addItem(db, a, 'Movie', type: ItemType.movie, sid: '1');
    addItem(db, a, 'Other', type: ItemType.movie, sid: '2');
    addItem(db, a, 'Show', type: ItemType.series, sid: '20');
    db.write((d) => Episode(accountId: a, seriesId: '20', season: 1, number: 1, title: 'Pilot', streamId: '201').insert(d));
    List<String> names(ItemType t) => db.read((d) => UserData.continueWatching(d, accountId: a, type: t).map((i) => i.name).toList());
    db.write((d) {
      UserData.saveProgress(d, accountId: a, type: ItemType.movie, streamId: '1', position: 10, duration: 100);
      UserData.saveProgress(d, accountId: a, type: ItemType.movie, streamId: '2', position: 10, duration: 100);
      UserData.saveProgress(d, accountId: a, type: ItemType.series, streamId: 'ep:201', position: 10, duration: 100);
      d.execute("UPDATE history SET updated = datetime('now','-1 hour')");
    });
    expect(names(ItemType.series), ['Show']);
    db.write((d) {
      UserData.hideFromContinue(d, accountId: a, type: ItemType.movie, streamId: '1');
      UserData.hideFromContinue(d, accountId: a, type: ItemType.series, streamId: '20');
    });
    expect(names(ItemType.movie), ['Other']);
    expect(names(ItemType.series), isEmpty);
    expect(count(db, 'SELECT COUNT(*) FROM history'), 3); // nothing is deleted: only hidden
    // watching it again saves a newer resume point, so it comes back
    db.write((d) {
      UserData.saveProgress(d, accountId: a, type: ItemType.movie, streamId: '1', position: 20, duration: 100);
      d.execute("UPDATE history SET updated = datetime('now','+1 hour') WHERE streamId = '1'");
    });
    expect(names(ItemType.movie), ['Movie', 'Other']);
  });

  test('saved playlist choice is restored and falls back safely', () {
    final a = Account(id: 1, name: 'A', kind: AccountKind.m3u), b = Account(id: 2, name: 'B', kind: AccountKind.m3u);
    expect(Account.restore('all', [a, b]), (all: true, account: a));
    expect(Account.restore('2', [a, b]), (all: false, account: b));
    expect(Account.restore('9', [a, b]), (all: false, account: a)); // that playlist was deleted
    expect(Account.restore(null, [a, b]), (all: false, account: a));
    expect(Account.restore('all', [a]), (all: false, account: a)); // All needs more than one playlist
    expect(Account.restore('all', []), (all: false, account: null));
  });

  test('memory secret store round trip', () async {
    final s = MemorySecretStore();
    await s.setPassword(1, 'pw');
    expect(await s.password(1), 'pw');
    await s.deletePassword(1);
    expect(await s.password(1), isNull);
  });

  test('clearing history removes every playlists progress but keeps favorites', () {
    final (db, a) = makeDB();
    final b = addAccount(db, 'second');
    addItem(db, a, 'Film', type: ItemType.movie, sid: '1');
    db.write((d) {
      for (final aid in [a, b]) {
        UserData.saveProgress(d, accountId: aid, type: ItemType.movie, streamId: '1', position: 10, duration: 100);
      }
      UserData.saveProgress(d, accountId: a, type: ItemType.series, streamId: 'ep:5', position: 10, duration: 100);
      UserData.toggleFavorite(d, accountId: a, type: ItemType.movie, streamId: '1');
      UserData.clearHistory(d);
    });
    expect(count(db, 'SELECT COUNT(*) FROM history'), 0);
    expect(db.read((d) => UserData.continueWatching(d, type: ItemType.movie)), isEmpty);
    expect(db.read((d) => UserData.favoriteKeys(d)), {'$a:movie:1'});
  });

  test('clearing favorites removes every playlists favorites but keeps history', () {
    final (db, a) = makeDB();
    final b = addAccount(db, 'second');
    db.write((d) {
      for (final aid in [a, b]) {
        UserData.toggleFavorite(d, accountId: aid, type: ItemType.live, streamId: '1');
      }
      UserData.saveProgress(d, accountId: a, type: ItemType.movie, streamId: '1', position: 10, duration: 100);
      UserData.clearFavorites(d);
    });
    expect(db.read((d) => UserData.favoriteKeys(d)), isEmpty);
    expect(count(db, 'SELECT COUNT(*) FROM history'), 1);
  });
}
