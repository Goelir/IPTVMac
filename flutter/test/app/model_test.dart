import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptvmac/app/library_model.dart';
import 'package:iptvmac/app/watch_progress.dart';
import 'package:iptvmac/core/errors.dart';
import 'package:iptvmac/core/models.dart';
import 'package:iptvmac/core/skip_marks.dart';
import 'package:iptvmac/core/user_data.dart';

import 'harness.dart';

Episode ep(String id, int season, int number) => Episode(accountId: 1, seriesId: 's', season: season, number: number, title: 'E$id', streamId: id);

void main() {
  group('LibraryModel', () {
    test('sync, categories, search with scopes, hidden words', () async {
      final h = await Harness.createPlain(withAccount: true, sync: true);
      final m = h.model;
      expect(m.accounts.single.name, 'Home');
      expect(m.results.map((i) => i.name), ['News 24', 'Sport One', 'Night Show']);
      expect(m.categories.map((c) => c.name), ['News', 'Adult Zone']);

      m.selectCategory('5');
      expect(m.results.map((i) => i.name), ['News 24', 'Sport One']);
      m.setSearchText('night'); // category scope: Night Show is in another category
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(m.results, isEmpty);
      m.setScope(SearchScope.type);
      expect(m.results.single.name, 'Night Show');
      m.setSearchText('film');
      m.setScope(SearchScope.everywhere);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(m.results.single.name, 'Other Film');

      m.setSearchText('');
      m.setHiddenWords('adult');
      expect(m.categories.map((c) => c.name), ['News']);
      expect(m.results.map((i) => i.name), isNot(contains('Night Show')));
    });

    test('a failing sync keeps the old data and says why; a later one clears the message', () async {
      final h = await Harness.createPlain(withAccount: true, sync: true);
      h.provider.fail = true;
      await h.model.sync();
      expect(h.model.syncMessage, isNotNull);
      expect(h.model.syncMessage, isNot(contains('password')));
      expect(h.model.results, isNotEmpty);
      h.provider.fail = false;
      await h.model.sync();
      expect(h.model.syncMessage, isNull);
      expect(h.model.syncing, isFalse);
    });

    test('an Xtream source without a stored password asks for it, and syncs once it is given', () async {
      final h = await Harness.createPlain();
      final a = Account(name: 'Imported', kind: AccountKind.xtream, server: 'http://panel.test', username: 'u');
      h.db.write((d) => a.insert(d));
      await h.model.loadAccounts();
      expect(h.model.hasPassword(h.model.accounts.single), isFalse);
      await h.model.sync();
      expect(h.model.passwordPrompt?.name, 'Imported');
      expect(h.model.syncing, isFalse);
      await h.model.savePassword('p', h.model.accounts.single);
      expect(h.model.passwordPrompt, isNull);
      expect(h.model.results, isNotEmpty);
      expect(await h.secrets.password(a.id!), 'p');
    });

    test('two playlists: All mode merges categories with tags, switching resets the category, deleting removes data', () async {
      final h = await Harness.createPlain(withAccount: true, sync: true);
      final m = h.model;
      await m.addAccount(Account(name: 'Second', kind: AccountKind.xtream, server: 'http://panel.test', username: 'u'), password: 'p');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(m.accounts.length, 2);
      expect(m.account!.name, 'Second'); // the new source is shown
      m.selectPlaylist(null);
      expect(m.allPlaylists, isTrue);
      expect(m.categories.map(m.categoryTag), ['1|5', '1|6', '2|5', '2|6']);
      m.selectCategory('2|5');
      expect(m.results.map((i) => i.accountId).toSet(), {2});
      await m.toggleFavorite(m.results.first);
      expect(m.favoriteKeys, hasLength(1));
      await m.deleteAccount(m.accounts.last);
      expect(m.accounts.length, 1);
      expect(m.allPlaylists, isFalse);
      expect(m.selectedCategory, '__all');
      expect(m.favoriteKeys, isEmpty);
      expect(h.db.read((d) => d.select('SELECT * FROM item WHERE accountId = 2')), isEmpty);
    });

    test('the chosen playlist is remembered', () async {
      final h = await Harness.createPlain(withAccount: true, sync: true);
      await h.model.addAccount(Account(name: 'Second', kind: AccountKind.m3u, url: 'http://panel.test/x.m3u'), password: null);
      h.model.selectPlaylist(null);
      expect(h.model.prefs.playlist, 'all');
      h.model.selectPlaylist(h.model.accounts.first);
      expect(h.model.prefs.playlist, '1');
    });

    test('testConnection: M3U answers with a playlist or not; Xtream wrong login', () async {
      final h = await Harness.createPlain();
      h.provider.m3u = '#EXTM3U\n#EXTINF:-1,A\nhttp://x.test/a.ts';
      await h.model.testConnection(kind: AccountKind.m3u, url: 'http://panel.test/list.m3u');
      h.provider.m3u = '<html>login</html>';
      expect(() => h.model.testConnection(kind: AccountKind.m3u, url: 'http://panel.test/list.m3u'), throwsA(IPTVError.badResponse));
      expect(() => h.model.testConnection(kind: AccountKind.m3u, url: 'not a link'), throwsA(IPTVError.badConfig));
      expect(() => h.model.testConnection(kind: AccountKind.xtream, server: 'http://panel.test', username: 'u', password: 'x'), throwsA(IPTVError.badCredentials));
    });

    test('only network schemes can be played', () {
      expect(LibraryModel.safeStreamUrl('http://a.test/x.ts'), isNotNull);
      expect(LibraryModel.safeStreamUrl(' rtmp://a.test/x '), isNotNull);
      for (final bad in ['file:///etc/passwd', 'fd://3', 'edl://x', 'memory://x', 'javascript:alert(1)', 'http://', 'nonsense']) {
        expect(LibraryModel.safeStreamUrl(bad), isNull, reason: bad);
      }
    });

    test('backup export and import round trip adds the playlist and its favorites', () async {
      final h = await Harness.createPlain(withAccount: true, sync: true);
      await h.model.toggleFavorite(h.model.results.first);
      final json = h.model.backupJson();
      expect(json, isNot(contains('"p"'))); // no password in the file
      final other = await Harness.createPlain();
      await other.model.importBackup(Uint8List.fromList(utf8.encode(json)));
      expect(other.model.accounts.single.name, 'Home');
      expect(other.model.passwordPrompt?.name, 'Home'); // an imported Xtream source needs its password
      expect(other.db.read((d) => d.select('SELECT * FROM favorite')), hasLength(1));
    });
  });

  group('WatchProgress', () {
    final eps = [ep('1', 1, 1), ep('2', 1, 2), ep('3', 2, 1)];

    test('nothing watched: the first episode', () {
      expect(WatchProgress.upNext(eps, {})!.episode.streamId, '1');
      expect(WatchProgress.upNext(eps, {})!.resume, isFalse);
    });

    test('halfway: resume it; finished: the next one, across seasons; all done: nothing', () {
      expect(WatchProgress.upNext(eps, {'1': const EpisodeProgress(100, 2700, 0)})!, (episode: eps[0], resume: true));
      expect(WatchProgress.upNext(eps, {'1': const EpisodeProgress(2650, 2700, 0)})!, (episode: eps[1], resume: false));
      expect(WatchProgress.upNext(eps, {'2': const EpisodeProgress(2650, 2700, 1)})!.episode.streamId, '3');
      expect(WatchProgress.upNext(eps, {'3': const EpisodeProgress(2650, 2700, 5)}), isNull);
      expect(WatchProgress.upNext(const [], {}), isNull);
    });

    test('under 5 seconds in is not a resume point', () {
      expect(WatchProgress.upNext(eps, {'1': const EpisodeProgress(3, 2700, 0)})!.resume, isFalse);
    });

    test('zapping wraps around and stays among channels', () {
      Item c(String n, [ItemType t = ItemType.live]) => Item(id: n.hashCode, accountId: 1, type: t, name: n, streamId: n);
      final list = [c('a'), c('m', ItemType.movie), c('b'), c('d')];
      expect(WatchProgress.zapNeighbor(list[0], list, 1)!.name, 'b');
      expect(WatchProgress.zapNeighbor(list[0], list, -1)!.name, 'd');
      expect(WatchProgress.zapNeighbor(list[3], list, 1)!.name, 'a');
      expect(WatchProgress.zapNeighbor(list[0], [list[0]], 1), isNull);
    });

    test('continue entries carry the fraction and the last episode of a series', () async {
      final h = await Harness.createPlain(withAccount: true, sync: true);
      final m = h.model;
      final episodes = await m.loadEpisodes(Item(id: 0, accountId: 1, type: ItemType.series, name: 'The Show', streamId: '20'));
      expect(episodes.length, 3);
      final aid = m.accounts.single.id!;
      h.db.write((d) {
        UserData.saveProgress(d, accountId: aid, type: ItemType.series, streamId: 'ep:102', position: 900, duration: 1800);
        UserData.saveProgress(d, accountId: aid, type: ItemType.movie, streamId: '10', position: 600, duration: 6000);
      });
      m.reloadContinue();
      expect(m.continueSeries.single.fraction, 0.5);
      expect((m.continueSeries.single.season, m.continueSeries.single.episode), (1, 2));
      expect(m.continueMovies.single.fraction, closeTo(0.1, 1e-9));
    });

    test('the Continue watching page knows the episode and the minute; resume builds that episode and its marks are kept per series', () async {
      final h = await Harness.createPlain(withAccount: true, sync: true);
      final m = h.model;
      final series = Item(id: 0, accountId: 1, type: ItemType.series, name: 'The Show', streamId: '20');
      final episodes = await m.loadEpisodes(series);
      final aid = m.accounts.single.id!;
      h.db.write((d) => UserData.saveProgress(d, accountId: aid, type: ItemType.series, streamId: 'ep:102', position: 900, duration: 1800));
      m.setTab(ItemType.series);
      m.selectCategory('__hist');
      final entry = m.continueInfo.values.single;
      expect((entry.episodeId, entry.position, entry.duration, entry.secondsLeft), ('102', 900.0, 1800.0, 900.0));
      final r = m.resumeRequest(entry)!;
      expect(r.start, 900);
      expect(r.subtitle, episodes.firstWhere((e) => e.streamId == '102').title);
      expect(m.episodeOf(r)!.streamId, '102');
      // the series' marks: an episode has an (empty) set, a movie has none, and they are saved for the series
      expect(m.skipMarksOf(r)!.isEmpty, isTrue);
      m.saveSkipMarks(r, const SkipMarks(introEnd: 75));
      expect(m.skipMarksOf(m.resumeRequest(entry)!), const SkipMarks(introEnd: 75)); // another episode of the series sees them
      expect(m.skipMarksOf(m.requestFor(Item(id: 1, accountId: 1, type: ItemType.live, name: 'News 24', streamId: '1', directURL: 'http://h/1.ts'))!), isNull);
    });

    test('the Continue watching caption says the episode and the minutes left', () {
      final item = Item(id: 1, accountId: 1, type: ItemType.series, name: 'S', streamId: '1');
      String? cap(ContinueEntry e) => WatchProgress.caption(e, episode: (s, n) => 'S$s E$n', left: (t) => '$t left', minutes: (n) => '$n min');
      expect(cap(ContinueEntry(item, season: 2, episode: 5, position: 600, duration: 2400)), 'S2 E5 · 30 min left');
      expect(cap(ContinueEntry(item, position: 100, duration: 160)), '1 min left'); // under a minute counts as one, never 0
      expect(cap(ContinueEntry(item, season: 1, episode: 1)), 'S1 E1'); // no length known: only the episode
      expect(cap(ContinueEntry(item)), isNull);
    });
  });
}
