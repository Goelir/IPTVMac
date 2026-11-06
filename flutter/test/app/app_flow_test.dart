import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptvmac/core/models.dart';
import 'package:iptvmac/ui/category_index.dart';
import 'package:iptvmac/core/user_data.dart';
import 'package:iptvmac/player/play_request.dart';
import 'package:iptvmac/ui/play.dart' as play;

import 'harness.dart';

void main() {
  testWidgets('onboarding to library: welcome, test connection, save and sync, channels appear', (tester) async {
    final h = await Harness.create(tester);
    await h.pumpApp(tester);

    expect(find.text('Welcome to IPTVMac'), findsOneWidget);
    expect(find.textContaining('includes no channels'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-source')));
    await go(tester);
    expect(find.text('Test connection'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull); // nothing typed yet

    await tester.enterText(find.byKey(const Key('field-name')), 'Home');
    await tester.enterText(find.byKey(const Key('field-server')), 'http://panel.test');
    await tester.enterText(find.byKey(const Key('field-username')), 'u');
    await tester.enterText(find.byKey(const Key('field-password')), 'p');
    await tester.pump();
    await tester.tap(find.text('Test connection'));
    await settle(tester);
    expect(find.text('Connected successfully'), findsOneWidget);

    await tester.tap(find.text('Save and sync'));
    await go(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('News 24'), findsOneWidget);
    expect(h.model.accounts.single.name, 'Home');
    expect(await h.secrets.password(h.model.accounts.single.id!), 'p'); // kept in the secret store, not in the database
    expect(h.model.syncMessage, isNull);
  });

  testWidgets('a wrong password says so and does not save', (tester) async {
    final h = await Harness.create(tester);
    await h.pumpApp(tester);
    await tester.tap(find.byKey(const Key('add-source')));
    await go(tester);
    await tester.enterText(find.byKey(const Key('field-name')), 'Home');
    await tester.enterText(find.byKey(const Key('field-server')), 'http://panel.test');
    await tester.enterText(find.byKey(const Key('field-username')), 'u');
    await tester.enterText(find.byKey(const Key('field-password')), 'nope');
    await tester.pump();
    await tester.tap(find.text('Test connection'));
    await settle(tester);
    expect(find.textContaining('Connection failed'), findsOneWidget);
    expect(find.textContaining('Wrong username or password'), findsOneWidget);
    expect(h.model.accounts, isEmpty);
  });

  testWidgets('a pasted provider link fills the form', (tester) async {
    final h = await Harness.create(tester);
    await h.pumpApp(tester);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': 'http://panel.test:8080/get.php?username=u&password=p&type=m3u_plus'};
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.text('Paste'));
    await go(tester);
    expect(find.widgetWithText(TextField, 'http://panel.test:8080'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'panel.test'), findsOneWidget); // the name defaults to the host
  });

  testWidgets('live list shows channels with now and next from the guide', (tester) async {
    final h = await Harness.create(tester, withAccount: true, sync: true);
    await h.pumpApp(tester);
    await go(tester);
    expect(find.text('News 24'), findsOneWidget);
    expect(find.text('Evening Report'), findsOneWidget);
    expect(find.textContaining('Late Session'), findsOneWidget);
    // only Xtream channels of the guide are asked for, never more than once per channel
    expect(h.provider.calls.where((u) => u.queryParameters['action'] == 'get_short_epg' && u.queryParameters['stream_id'] == '1').length, 1);
  });

  testWidgets('search finds items, scopes widen it, clearing brings the list back', (tester) async {
    final h = await Harness.create(tester, withAccount: true, sync: true);
    await h.pumpApp(tester);
    await go(tester);

    await tester.enterText(find.byType(TextField), 'spo');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(find.text('Sport One'), findsOneWidget);
    expect(find.text('News 24'), findsNothing);

    await tester.enterText(find.byType(TextField), 'big');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(find.text('Nothing found'), findsOneWidget); // a movie is not in the Live section
    await tester.tap(find.text('Everywhere'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Big Movie'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear text'));
    await go(tester);
    expect(find.text('News 24'), findsOneWidget);
    expect(h.model.searchText, '');
  });

  testWidgets('a section opens on its categories: All channels first, every category with a count, a row leads into the list', (tester) async {
    final h = await Harness.create(tester, withAccount: true, sync: true);
    await h.pumpApp(tester);
    await go(tester, index: true);
    expect(find.byType(CategoryIndex), findsOneWidget);
    expect(find.text('All channels'), findsOneWidget);
    expect(find.text('News'), findsOneWidget);
    expect(find.text('Night Show'), findsNothing); // channels only show once a row is chosen
    await tester.tap(find.text('News'));
    await go(tester, index: true);
    expect(find.byType(CategoryIndex), findsNothing);
    expect(find.text('Sport One'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.filter_list)); // the filter button leads back to the categories
    await go(tester, index: true);
    expect(find.byType(CategoryIndex), findsOneWidget);
  });

  testWidgets('the list keeps its place when the phone rotates and comes back (the player does that)', (tester) async {
    final h = await Harness.create(tester, withAccount: true, sync: true);
    h.db.write((d) {
      for (var i = 100; i < 200; i++) {
        d.execute("INSERT INTO item (accountId,type,name,categoryId,streamId,stale) VALUES (1,'live',?, '5', ?, 0)", ['Channel $i', '$i']);
      }
    });
    await h.pumpApp(tester);
    h.model.scheduleSearch(immediate: true);
    await go(tester);
    double offset() => tester.state<ScrollableState>(find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first).position.pixels;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await go(tester);
    final before = offset();
    expect(before, greaterThan(500));
    tester.view.physicalSize = const Size(800, 400); // landscape: the shell swaps the bottom bar for the rail
    await go(tester);
    tester.view.physicalSize = const Size(400, 800);
    await go(tester);
    expect(offset(), closeTo(before, 1));
    await tester.pumpWidget(const SizedBox());
    await settle(tester, 20);
  });

  testWidgets('category chips filter, favorites chip, hidden words remove categories', (tester) async {
    final h = await Harness.create(tester, withAccount: true, sync: true);
    await h.pumpApp(tester);
    await go(tester);
    expect(find.text('Night Show'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'News'));
    await go(tester);
    expect(find.text('Night Show'), findsNothing);
    expect(find.text('Sport One'), findsOneWidget);
    h.model.setHiddenWords('adult');
    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await go(tester);
    expect(find.text('Night Show'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'Adult Zone'), findsNothing);
  });

  testWidgets('favorites toggle: star in the list, the Favorites chip and the Library tab', (tester) async {
    final h = await Harness.create(tester, withAccount: true, sync: true);
    await h.pumpApp(tester);
    await go(tester);

    await tester.tap(find.byTooltip('Add to favorites').first);
    await go(tester);
    final news = h.model.results.firstWhere((i) => i.name == 'News 24');
    expect(h.model.isFavorite(news), isTrue);
    expect(h.db.read((d) => UserData.favorites(d, type: ItemType.live)).single.name, 'News 24');
    expect(find.byTooltip('Remove from favorites'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Favorites'));
    await go(tester);
    expect(find.text('News 24'), findsOneWidget);
    expect(find.text('Sport One'), findsNothing);

    await tester.tap(find.text('Library'));
    await go(tester);
    expect(find.text('News 24'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove from favorites'));
    await go(tester);
    expect(find.text('Your library is empty'), findsOneWidget);
  });

  testWidgets('Movies: poster grid, details sheet, Play hands the right request to the player', (tester) async {
    final h = await Harness.create(tester, withAccount: true, sync: true);
    PlayRequest? request;
    PlayerHost? host;
    final saved = play.playerBuilder;
    play.playerBuilder = (r, hh) {
      request = r;
      host = hh;
      return Scaffold(body: Text('player:${r.title}'));
    };
    addTearDown(() => play.playerBuilder = saved);

    await h.pumpApp(tester);
    await go(tester);
    await tester.tap(find.text('Movies').last);
    await go(tester);
    expect(find.text('Big Movie'), findsOneWidget);

    await tester.tap(find.text('Big Movie'));
    await go(tester);
    expect(find.text('A heist that goes wrong.'), findsOneWidget);
    expect(find.text('Ada Quill'), findsOneWidget);
    expect(find.text('2019'), findsOneWidget);
    expect(find.text('7.5'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);

    await tester.tap(find.byTooltip('Add to favorites'));
    await go(tester);
    expect(h.model.favoriteKeys, hasLength(1));

    await tester.tap(find.text('Play'));
    await go(tester);
    expect(find.text('player:Big Movie'), findsOneWidget);
    final r = request!;
    expect(r.url.toString(), 'http://panel.test/movie/u/p/10.mkv');
    expect(r.isLive, isFalse);
    expect(r.start, 0);
    expect(r.item!.name, 'Big Movie');

    // the host: progress is saved for the movie, favorites are shared with the app, close pops the screen
    expect(host!.isFavorite(r.item!), isTrue);
    host!.saveProgress(r, 30, 6000);
    expect(h.model.progress(r.item!), 30);
    host!.saveProgress(r, 0, 0); // nothing played yet: must not erase the resume point
    expect(h.model.progress(r.item!), 30);
    host!.closePlayer();
    await go(tester);
    expect(find.text('player:Big Movie'), findsNothing);
    expect(find.text('Continue watching'), findsWidgets); // the shelf now has the movie

    // reopening resumes where it stopped
    await tester.tap(find.text('Big Movie').first);
    await go(tester);
  });

  testWidgets('series screen: seasons, up next, episode request and next episode through the host', (tester) async {
    final h = await Harness.create(tester, withAccount: true, sync: true);
    PlayRequest? request;
    PlayerHost? host;
    final saved = play.playerBuilder;
    play.playerBuilder = (r, hh) {
      request = r;
      host = hh;
      return const Scaffold(body: Text('player'));
    };
    addTearDown(() => play.playerBuilder = saved);

    await h.pumpApp(tester);
    await go(tester);
    await tester.tap(find.text('Series').last);
    await go(tester);
    await tester.tap(find.text('The Show'));
    await go(tester);

    expect(find.text('Play S1 E1'), findsOneWidget);
    expect(find.text('Pilot'), findsOneWidget);
    await tester.tap(find.text('Season 2'));
    await go(tester);
    expect(find.text('Return'), findsOneWidget);
    await tester.tap(find.text('Season 1'));
    await go(tester);

    await tester.tap(find.text('Play S1 E1'));
    await go(tester);
    final r = request!;
    expect(r.url.toString(), 'http://panel.test/series/u/p/101.mp4');
    expect(r.item!.name, 'The Show');
    expect(r.subtitle, 'Pilot');

    final next = host!.nextEpisode(r)!;
    expect(next.url.toString(), 'http://panel.test/series/u/p/102.mp4');
    expect(host!.nextEpisode(next)!.url.toString(), 'http://panel.test/series/u/p/201.mp4'); // across seasons
    host!.saveProgress(r, 1500, 2700); // saved as the episode, so the series shows "continue"
    expect(h.db.read((d) => d.select("SELECT streamId FROM history WHERE type='series'")).single['streamId'], 'ep:101');
    host!.closePlayer();
    await go(tester);
    expect(find.text('Continue S1 E1'), findsOneWidget);
    expect(find.text('20 min left'), findsOneWidget); // the episode that was left halfway says how much is left (1500 of 2700 s)
  });

  testWidgets('live channel: zapping stays in the list the channel came from', (tester) async {
    final h = await Harness.create(tester, withAccount: true, sync: true);
    PlayRequest? request;
    PlayerHost? host;
    final saved = play.playerBuilder;
    play.playerBuilder = (r, hh) {
      request = r;
      host = hh;
      return const Scaffold(body: Text('player'));
    };
    addTearDown(() => play.playerBuilder = saved);
    await h.pumpApp(tester);
    await go(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'News'));
    await go(tester);
    await tester.tap(find.text('Sport One'));
    await go(tester);
    final r = request!;
    expect(r.isLive, isTrue);
    expect(r.start, 0);
    expect(r.url.toString(), 'http://panel.test/live/u/p/2.ts');
    // the News category holds two channels: next from the second wraps to the first; Night Show (another category) is not in it
    expect(host!.zap(r, 1)!.item!.name, 'News 24');
    expect(host!.zap(r, -1)!.item!.name, 'News 24');
    expect(host!.zap(r, 1)!.subtitle, 'Evening Report'); // the zapped-to channel carries its guide entry
    host!.saveProgress(r, 10, 100); // never saved for live
    expect(h.db.read((d) => d.select('SELECT * FROM history')), isEmpty);
    expect(host!.liveProgramme(r), isNull);
  });

  testWidgets('settings: delete a source with confirmation, clear history with confirmation', (tester) async {
    final h = await Harness.create(tester, withAccount: true, sync: true);
    await h.pumpApp(tester);
    await go(tester);
    h.db.write((d) => UserData.saveProgress(d, accountId: h.model.accounts.single.id!, type: ItemType.movie, streamId: '10', position: 100, duration: 1000));
    await tester.tap(find.text('Settings').last);
    await go(tester);
    expect(find.text('Home'), findsOneWidget);

    await tester.scrollUntilVisible(find.byKey(const Key('clear-history')), 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.byKey(const Key('clear-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('clear-history')));
    await go(tester);
    expect(find.textContaining('cannot be undone'), findsOneWidget);
    await tester.tap(find.text('Clear').last);
    await go(tester);
    expect(h.db.read((d) => d.select('SELECT * FROM history')), isEmpty);

    await tester.scrollUntilVisible(find.byTooltip('Delete'), -300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byTooltip('Delete'));
    await go(tester);
    await tester.tap(find.text('Delete').last);
    await go(tester);
    expect(h.model.accounts, isEmpty);
    expect(find.text('Welcome to IPTVMac'), findsOneWidget); // back to the first-run screen
    expect(await h.secrets.password(1), isNull);
  });

  testWidgets('right-to-left smoke test: Hebrew onboarding, shell and details lay out without errors', (tester) async {
    final h = await Harness.create(tester);
    await h.pumpApp(tester, locale: const Locale('he'));
    expect(Directionality.of(tester.element(find.byKey(const Key('add-source')))), TextDirection.rtl);
    expect(tester.takeException(), isNull);

    final h2 = await Harness.create(tester, withAccount: true, sync: true);
    await h2.pumpApp(tester, locale: const Locale('ar'), textScale: 1.6);
    await go(tester);
    expect(Directionality.of(tester.element(find.byType(NavigationBar))), TextDirection.rtl);
    for (final label in [1, 2, 3, 4, 0]) {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.byType(NavigationDestination)).at(label));
      await go(tester);
      expect(tester.takeException(), isNull, reason: 'section $label');
    }
  });

  testWidgets('a tablet gets a navigation rail and a wider poster grid; large text does not overflow', (tester) async {
    final h = await Harness.create(tester, withAccount: true, sync: true);
    await h.pumpApp(tester, size: const Size(1000, 700), textScale: 2);
    await go(tester);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    for (final label in ['Movies', 'Series', 'Library', 'Settings', 'Live']) {
      await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text(label)));
      await go(tester);
      expect(tester.takeException(), isNull, reason: label);
    }
  });
}
