import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptvmac/app/app.dart';
import 'package:iptvmac/app/library_model.dart';
import 'package:iptvmac/app/sync_worker.dart';
import 'package:iptvmac/core/app_database.dart';
import 'package:iptvmac/core/models.dart';
import 'package:iptvmac/ui/category_index.dart';
import 'package:iptvmac/core/secret_store.dart';
import 'package:iptvmac/downloads/downloads_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An invented Xtream provider at http://panel.test (user "u", password "p"): two channels, two movies, one series with
/// three episodes in two seasons, a guide for the first channel and details for the first movie.
class FakeProvider {
  /// More movies ("Film 01", "Film 02", ...) in the Action category, for a poster grid that has several rows.
  int extraMovies = 0;

  /// The releases feed github.com would answer (null = a feed with no releases), and how often it was asked.
  String? feed;
  int feedCalls = 0;

  FakeProvider() {
    client = MockClient((r) async {
      calls.add(r.url);
      if (fail) throw http.ClientException('connection refused ${r.url}'); // like the real client: the message holds the URL
      if (r.url.host == 'github.com' && r.url.path.endsWith('releases.atom')) {
        feedCalls++;
        return res(feed ?? '<feed></feed>');
      }
      if (r.url.path.endsWith('.m3u')) return res(m3u);
      final q = r.url.queryParameters;
      if (q['username'] != 'u' || q['password'] != 'p') return res('{"user_info":{"auth":0}}');
      return res(switch (q['action']) {
        'get_live_categories' => '[{"category_id":"5","category_name":"News"},{"category_id":"6","category_name":"Adult Zone"}]',
        'get_vod_categories' => '[{"category_id":"7","category_name":"Action"}]',
        'get_series_categories' => '[{"category_id":"8","category_name":"Drama"}]',
        'get_live_streams' =>
          '[{"stream_id":1,"name":"News 24","category_id":"5","epg_channel_id":"n24"},{"stream_id":2,"name":"Sport One","category_id":"5"},{"stream_id":3,"name":"Night Show","category_id":"6"}]',
        'get_vod_streams' =>
          '[{"stream_id":10,"name":"Big Movie","category_id":"7","container_extension":"mkv"},{"stream_id":11,"name":"Other Film","category_id":"7"}'
              '${[for (var i = 1; i <= extraMovies; i++) ',{"stream_id":${100 + i},"name":"Film ${i.toString().padLeft(2, '0')}","category_id":"7"}'].join()}]',
        'get_series' => '[{"series_id":20,"name":"The Show","category_id":"8"}]',
        'get_short_epg' => q['stream_id'] == '1' ? _epg() : '{"epg_listings":[]}',
        'get_vod_info' =>
          '{"info":{"name":"Big Movie","plot":"A heist that goes wrong.","releasedate":"2019-05-01","rating":"7.5","duration_secs":6300,"genre":"Action","director":"Ada Quill"}}',
        'get_series_info' =>
          '{"info":{"name":"The Show","plot":"A quiet town."},"episodes":{"1":[{"id":"101","episode_num":1,"title":"Pilot","season":1,"container_extension":"mp4"},{"id":"102","episode_num":2,"title":"Second","season":1,"container_extension":"mp4"}],"2":[{"id":"201","episode_num":1,"title":"Return","season":2,"container_extension":"mp4"}]}}',
        _ => '{"user_info":{"auth":1,"status":"Active"},"server_info":{}}',
      });
    });
  }

  late final http.Client client;
  final calls = <Uri>[];

  /// Makes every request fail (the provider is down).
  bool fail = false;

  /// What a playlist link answers (for the M3U test connection).
  String m3u = '#EXTM3U';

  static http.Response res(String body) => http.Response.bytes(utf8.encode(body), 200);

  static String _epg() {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    String b(String s) => base64.encode(utf8.encode(s));
    return '{"epg_listings":[{"title":"${b('Evening Report')}","start_timestamp":${now - 600},"stop_timestamp":${now + 1200}},'
        '{"title":"${b('Late Session')}","start_timestamp":${now + 1200},"stop_timestamp":${now + 3000}}]}';
  }
}

class Harness {
  Harness._(this.db, this.secrets, this.provider, this.model);

  final AppDatabase db;
  final MemorySecretStore secrets;
  final FakeProvider provider;
  final LibraryModel model;

  /// Without a tester: for plain `test()`s, which have real async.
  static Future<Harness> createPlain({bool withAccount = false, bool sync = false, String? appVersion, Map<String, Object> prefs = const {}}) =>
      _create(withAccount: withAccount, sync: sync, prefs: prefs, appVersion: appVersion);

  static Future<Harness> create(WidgetTester tester, {bool withAccount = false, bool sync = false, Map<String, Object> prefs = const {}, String? appVersion}) async =>
      (await tester.runAsync(() => _create(withAccount: withAccount, sync: sync, prefs: prefs, appVersion: appVersion)))!;

  static Future<Harness> _create({required bool withAccount, required bool sync, required Map<String, Object> prefs, String? appVersion}) async {
    SharedPreferences.setMockInitialValues(prefs);
    final db = AppDatabase.memory();
    final secrets = MemorySecretStore();
    final provider = FakeProvider();
    final model = LibraryModel(
      db: db,
      secrets: secrets,
      prefs: await SharedPreferences.getInstance(),
      dbPath: ':memory:',
      syncRunner: inlineSyncRunner(db, client: provider.client),
      client: provider.client,
      autoRefresh: false,
      appVersion: appVersion,
      searchDebounce: const Duration(milliseconds: 20),
    );
    final h = Harness._(db, secrets, provider, model);
    if (withAccount) {
      final a = db.write((d) => Account(name: 'Home', kind: AccountKind.xtream, server: 'http://panel.test', username: 'u').insert(d));
      await secrets.setPassword(a.id!, 'p');
      await model.loadAccounts();
      if (sync) await model.sync();
    }
    return h;
  }

  Future<void> pumpApp(WidgetTester tester, {Locale? locale, double textScale = 1, Size size = const Size(400, 800), DownloadsModel? downloads}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(IptvApp(model: model, locale: locale, downloads: downloads));
    await settle(tester, 2);
  }
}

/// Lets the model's futures (fake HTTP, secret store) finish: the fake clock of `testWidgets` alone does not move them,
/// real event-loop turns (`runAsync`) do.
Future<void> settle(WidgetTester tester, [int turns = 6]) async {
  for (var i = 0; i < turns; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// [settle] then let every animation and frame finish. A section opens on the category screen; unless [index] is true this
/// steps into its first row ("All channels/movies/series") so the tests see the list.
Future<void> go(WidgetTester tester, {bool index = false}) async {
  await settle(tester, 3);
  await tester.pumpAndSettle();
  if (!index && find.byType(CategoryIndex).evaluate().isNotEmpty) {
    await tester.tap(find.descendant(of: find.byType(CategoryIndex), matching: find.byType(ListTile)).first);
    await settle(tester, 3);
    await tester.pumpAndSettle();
  }
}
