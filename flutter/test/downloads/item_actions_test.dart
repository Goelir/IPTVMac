import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptvmac/app/library_model.dart';
import 'package:iptvmac/core/models.dart';
import 'package:iptvmac/core/user_data.dart';
import 'package:iptvmac/downloads/downloads_model.dart';
import 'package:iptvmac/downloads/library_downloads.dart';
import 'package:iptvmac/l10n/app_localizations.dart';
import 'package:iptvmac/ui/item_views.dart';
import 'package:provider/provider.dart';

import '../app/harness.dart';
import 'fake_download_engine.dart';

/// An M3U movie plays on a tap and has no details sheet: its download button is the long-press menu.
void main() {
  testWidgets('a long press on a playlist movie offers favorite and download; live and HLS movies get no download', (tester) async {
    final h = await Harness.create(tester, withAccount: true, sync: true);
    final dir = Directory.systemTemp.createTempSync('dl_actions');
    addTearDown(() => dir.deleteSync(recursive: true));
    final engine = FakeDownloadEngine();
    final d = DownloadsModel(engine: engine, store: File('${dir.path}/downloads.json'), dir: '${dir.path}/Downloads', resolveUrl: h.model.downloadUrl);
    await tester.runAsync(d.load);
    final a = h.model.accounts.single.id!;
    final film = Item(accountId: a, type: ItemType.movie, name: 'Open film', streamId: 'f1', directURL: 'http://panel.test/films/open.mp4');
    final hls = Item(accountId: a, type: ItemType.movie, name: 'Stream film', streamId: 'f2', directURL: 'http://panel.test/films/live.m3u8');

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider<LibraryModel>.value(value: h.model), ChangeNotifierProvider<DownloadsModel>.value(value: d)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Row(children: [Expanded(child: PosterCell(item: film)), Expanded(child: PosterCell(item: hls))])),
      ),
    ));

    await tester.longPress(find.text('Stream film'));
    await go(tester);
    expect(find.byKey(const Key('action-favorite')), findsOneWidget);
    expect(find.byKey(const Key('action-download')), findsNothing, reason: 'an HLS playlist is not one file');
    await tester.tapAt(const Offset(10, 10)); // dismiss the sheet
    await go(tester);

    await tester.longPress(find.text('Open film'));
    await go(tester);
    expect(find.byKey(const Key('action-download')), findsOneWidget);
    await tester.tap(find.byKey(const Key('action-download')));
    await go(tester);
    expect(engine.calls.where((c) => c.startsWith('enqueue')).length, 1);
    expect(find.text('Added to Downloads'), findsOneWidget);
  });

  testWidgets('a long press on a Continue watching entry offers to remove it', (tester) async {
    final h = await Harness.create(tester, withAccount: true, sync: true);
    final a = h.model.accounts.single.id!;
    final film = Item(accountId: a, type: ItemType.movie, name: 'Half film', streamId: 'f1', directURL: 'http://panel.test/films/half.mp4');
    h.db.write((d) {
      film.insert(d);
      UserData.saveProgress(d, accountId: a, type: ItemType.movie, streamId: 'f1', position: 600, duration: 6000);
      d.execute("UPDATE history SET updated = datetime('now','-1 hour')");
    });
    h.model.reloadContinue();
    final entry = h.model.continueMovies.single;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    final dir = Directory.systemTemp.createTempSync('dl_actions2');
    addTearDown(() => dir.deleteSync(recursive: true));
    final d = DownloadsModel(engine: FakeDownloadEngine(), store: File('${dir.path}/downloads.json'), dir: '${dir.path}/Downloads', resolveUrl: h.model.downloadUrl);
    await tester.runAsync(d.load);
    await tester.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider<LibraryModel>.value(value: h.model), ChangeNotifierProvider<DownloadsModel>.value(value: d)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Row(children: [Expanded(child: PosterCell(item: entry.item, entry: entry))])),
      ),
    ));
    await tester.longPress(find.text('Half film'));
    await go(tester);
    expect(find.byKey(const Key('action-remove-continue')), findsOneWidget);
    await tester.tap(find.byKey(const Key('action-remove-continue')));
    await go(tester);
    expect(h.model.continueMovies, isEmpty);
  });
}
