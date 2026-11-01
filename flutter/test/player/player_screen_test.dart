import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptvmac/core/models.dart';
import 'package:iptvmac/core/series_prefs.dart';
import 'package:iptvmac/core/skip_marks.dart';
import 'package:iptvmac/l10n/app_localizations.dart';
import 'package:iptvmac/player/play_request.dart';
import 'package:iptvmac/player/player_prefs.dart';
import 'package:iptvmac/player/player_screen.dart';
import 'package:iptvmac/player/player_system.dart';
import 'package:iptvmac/player/track_label.dart';

import 'fake_engine.dart';

class FakeHost implements PlayerHost {
  final saves = <(String, double, double)>[];
  final favorites = <String>{};
  var closed = 0;
  PlayRequest? zapTo;
  PlayRequest? next;
  String? programme;
  var details = false;
  final shownDetails = <String>[];

  @override
  void saveProgress(PlayRequest r, double p, double d) => saves.add((r.title, p, d));
  @override
  bool isFavorite(Item i) => favorites.contains(i.name);
  @override
  Future<void> toggleFavorite(Item i) async => favorites.contains(i.name) ? favorites.remove(i.name) : favorites.add(i.name);
  @override
  bool hasDetails(Item i) => details;
  @override
  void showDetails(Item i) => shownDetails.add(i.name);
  @override
  PlayRequest? zap(PlayRequest c, int step) => zapTo;
  @override
  PlayRequest? nextEpisode(PlayRequest c) => next;
  @override
  String? liveProgramme(PlayRequest r) => programme;
  SeriesPrefs? prefs; // null: not an episode; set it to make every request an episode of a series with these choices
  final savedPrefs = <SeriesPrefs>[];
  @override
  SeriesPrefs? seriesPrefs(PlayRequest r) => prefs;
  @override
  void saveSeriesPrefs(PlayRequest r, SeriesPrefs p) {
    prefs = p;
    savedPrefs.add(p);
  }
  SkipMarks? marks; // null: not an episode (no skip menu); set it to make every request an episode of a series with these marks
  final savedMarks = <SkipMarks>[];
  @override
  SkipMarks? skipMarks(PlayRequest r) => marks;
  @override
  void saveSkipMarks(PlayRequest r, SkipMarks m) {
    marks = m;
    savedMarks.add(m);
  }
  @override
  void closePlayer() => closed++;
}

class FakeSystem extends PlayerSystem {
  final awake = <bool>[];
  @override
  Future<bool> isPipSupported() async => true;
  @override
  void setAwake(bool a) => awake.add(a);
  @override
  Future<double?> volume() async => 0.5;
  final levels = <double>[];
  @override
  void setVolume(double v) => levels.add(v);
  final portraits = <bool>[];
  @override
  Future<void> setPortrait(bool portrait) async => portraits.add(portrait);
}

Item item(String name, {ItemType type = ItemType.movie}) => Item(accountId: 1, type: type, name: name, streamId: name);

PlayRequest movie([String name = 'Sintel']) => PlayRequest(title: name, url: Uri.parse('http://x/$name.mp4'), isLive: false, item: item(name), subtitle: 'Season 1');
PlayRequest live([String name = 'Channel A']) => PlayRequest(title: name, url: Uri.parse('http://x/$name.m3u8'), isLive: true, item: item(name, type: ItemType.live));

Future<(FakeEngine, FakeHost, FakeSystem)> open(WidgetTester t, PlayRequest r, {FakeHost? host, FakeEngine? engine, Size size = const Size(900, 420)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final e = engine ?? FakeEngine();
  final h = host ?? FakeHost();
  final s = FakeSystem();
  await t.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PlayerScreen(request: r, host: h, engineFactory: (_) => e, system: s, prefs: PlayerPrefs(), clock: t.binding.clock.now),
  ));
  await t.pump(); // prefs, system.enter
  await t.pump();
  return (e, h, s);
}

void playing(FakeEngine e, {double position = 5, double duration = 600}) {
  e
    ..position = position
    ..duration = duration
    ..paused = false;
}

void main() {
  testWidgets('the rotate button turns a phone upright and back, and a tablet has none', (t) async {
    final (e, _, sys) = await open(t, movie());
    playing(e);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byIcon(Icons.stay_current_portrait));
    await t.pump(const Duration(milliseconds: 100));
    expect(sys.portraits, [true]);
    await t.tap(find.byIcon(Icons.stay_current_landscape));
    await t.pump(const Duration(milliseconds: 100));
    expect(sys.portraits, [true, false]);
    await t.pumpWidget(const SizedBox());

    final (e2, _, _) = await open(t, movie(), size: const Size(1200, 800));
    playing(e2);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.stay_current_portrait), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('loads the request and shows the title, the transport and the seek bar', (t) async {
    final (e, _, _) = await open(t, movie());
    expect(e.loads.single, ('http://x/Sintel.mp4', 0.0));
    playing(e);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Sintel'), findsOneWidget);
    expect(find.text('Season 1'), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(find.byIcon(Icons.replay_10), findsOneWidget);
    expect(find.text('0:05'), findsOneWidget);
    expect(find.text('\u22129:55'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the controls hide three seconds after the last touch and a tap brings them back', (t) async {
    final (e, _, _) = await open(t, movie());
    playing(e);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.pause).hitTestable(), findsOneWidget);
    await t.pump(const Duration(seconds: 4));
    expect(find.byIcon(Icons.pause).hitTestable(), findsNothing, reason: 'faded out and not tappable');
    await t.tapAt(const Offset(450, 210));
    await t.pump(const Duration(milliseconds: 400)); // a single tap waits for a possible double tap
    expect(find.byIcon(Icons.pause).hitTestable(), findsOneWidget);
    await t.tapAt(const Offset(450, 210));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byIcon(Icons.pause).hitTestable(), findsNothing, reason: 'a tap hides them again');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('paused keeps the controls on screen', (t) async {
    final (e, _, _) = await open(t, movie());
    playing(e);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byIcon(Icons.pause));
    await t.pump(const Duration(seconds: 6));
    expect(e.paused, true);
    expect(find.byIcon(Icons.play_arrow).hitTestable(), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('double tap on the right skips forward and the total grows', (t) async {
    final (e, _, _) = await open(t, movie());
    playing(e, position: 100);
    await t.pump(const Duration(milliseconds: 300));
    await t.tapAt(const Offset(800, 210));
    await t.pump(const Duration(milliseconds: 50));
    await t.tapAt(const Offset(800, 210));
    await t.pump(const Duration(milliseconds: 100));
    expect(e.commands, contains('seekBy 10.0'));
    expect(find.text('+10'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    expect(find.text('+10'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a failure shows the error card with Retry, which reloads the stream', (t) async {
    final (e, _, _) = await open(t, movie());
    playing(e, position: 40);
    await t.pump(const Duration(milliseconds: 300));
    e.fail('Connection reset');
    await t.pump();
    expect(find.text('Playback failed'), findsOneWidget);
    expect(find.text('Connection reset'), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsNothing, reason: 'no dead transport behind the card');
    await t.tap(find.text('Retry'));
    await t.pump();
    expect(find.text('Playback failed'), findsNothing);
    expect(e.loads.last, ('http://x/Sintel.mp4', 40.0));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the end of an episode shows the up-next card, the countdown plays the next one', (t) async {
    final host = FakeHost()..next = movie('Episode 2');
    final (e, _, _) = await open(t, movie('Episode 1'), host: host);
    playing(e, position: 10, duration: 60);
    await t.pump(const Duration(milliseconds: 300));
    e
      ..position = 59
      ..atEof = true;
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Up next: Episode 2'), findsOneWidget);
    expect(find.text('Playing in 5 s'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    expect(find.text('Playing in 3 s'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    expect(e.loads.last.$1, Uri.parse('http://x/Episode 2.mp4').toString());
    expect(find.textContaining('Up next'), findsNothing);
    expect(host.saves.any((s) => s.$1 == 'Episode 1'), true, reason: 'the old position is saved when the next one starts');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('cancel stops the countdown', (t) async {
    final host = FakeHost()..next = movie('Episode 2');
    final (e, _, _) = await open(t, movie('Episode 1'), host: host);
    playing(e, position: 10, duration: 60);
    await t.pump(const Duration(milliseconds: 300));
    e
      ..position = 59
      ..atEof = true;
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('Cancel'));
    await t.pump(const Duration(seconds: 8));
    expect(e.loads.length, 1);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a live channel has previous/next buttons that zap through the host and no seek bar', (t) async {
    final host = FakeHost()..zapTo = live('Channel B')..programme = 'News at ten';
    final (e, _, _) = await open(t, live(), host: host);
    playing(e, position: 30, duration: 0);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('News at ten'), findsOneWidget);
    expect(find.byIcon(Icons.replay_10), findsNothing);
    await t.tap(find.byIcon(Icons.skip_next));
    await t.pump();
    expect(e.loads.last.$1, Uri.parse('http://x/Channel B.m3u8').toString());
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('zapping is disabled when the host has no neighbour', (t) async {
    final (e, _, _) = await open(t, live());
    playing(e, duration: 0);
    await t.pump(const Duration(milliseconds: 300));
    final next = t.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.skip_next));
    expect(next.onPressed, null);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the details button opens the item\'s details through the host and only shows when the host has details', (t) async {
    final host = FakeHost();
    var (e, _, _) = await open(t, movie(), host: host);
    playing(e);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.info_outline), findsNothing, reason: 'no provider details (M3U, live): no button');
    await t.pumpWidget(const SizedBox());

    host.details = true;
    (e, _, _) = await open(t, movie(), host: host);
    playing(e);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byIcon(Icons.info_outline));
    expect(host.shownDetails, ['Sintel']);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the favourite star goes through the host', (t) async {
    final host = FakeHost();
    final (e, _, _) = await open(t, movie(), host: host);
    playing(e);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byIcon(Icons.star_border));
    await t.pump();
    expect(host.favorites, {'Sintel'});
    expect(find.byIcon(Icons.star), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('close asks the host to close and saves the position; the screen going away saves too but does not close again', (t) async {
    final host = FakeHost();
    final (e, _, _) = await open(t, movie(), host: host);
    playing(e, position: 42, duration: 600);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byIcon(Icons.close));
    await t.pump();
    expect(host.closed, 1);
    expect(host.saves.last, ('Sintel', 42.0, 600.0));
    expect(e.disposed, true);
    await t.pumpWidget(const SizedBox());
    expect(host.closed, 1);
    expect(host.saves.length, 1);
  });

  testWidgets('leaving the screen without close() saves once and never closes through the host', (t) async {
    final host = FakeHost();
    final (e, _, _) = await open(t, movie(), host: host);
    playing(e, position: 77, duration: 600);
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpWidget(const SizedBox());
    expect(host.saves, [('Sintel', 77.0, 600.0)]);
    expect(host.closed, 0);
    expect(e.disposed, true);
  });

  testWidgets('system back closes through the host', (t) async {
    final host = FakeHost();
    final (e, _, _) = await open(t, movie(), host: host);
    playing(e);
    await t.pump(const Duration(milliseconds: 300));
    await t.binding.handlePopRoute();
    await t.pump();
    expect(host.closed, 1);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('in Picture in Picture the controls are gone and they come back after', (t) async {
    final (e, _, s) = await open(t, movie());
    playing(e);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.picture_in_picture_alt), findsOneWidget, reason: 'the button is there when the system supports it');
    s.pipChanges.add(true);
    await t.pump();
    expect(find.byIcon(Icons.pause), findsNothing);
    expect(find.text('Sintel'), findsNothing);
    s.pipChanges.add(false);
    await t.pump();
    expect(find.byIcon(Icons.pause), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('subtitles menu lists the tracks, Off first, and selects one', (t) async {
    final (e, _, _) = await open(t, movie());
    playing(e);
    e.tracks = [
      const Track(id: 1, type: 'sub', lang: 'eng', title: 'Commentary'),
      const Track(id: 2, type: 'sub', lang: 'zzz'),
    ];
    await t.pump(const Duration(milliseconds: 300)); // an empty track list is read again on every tick
    await t.tap(find.byIcon(Icons.closed_caption_outlined));
    await t.pumpAndSettle();
    expect(find.text('Off'), findsOneWidget);
    expect(find.text('ZZZ'), findsOneWidget);
    expect(find.textContaining('Commentary'), findsOneWidget);
    await t.tap(find.text('ZZZ'));
    await t.pumpAndSettle();
    expect(e.commands, contains('sub 2'));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the speed menu is small, marks the current speed and changes it', (t) async {
    final (e, _, _) = await open(t, movie());
    playing(e);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('1×'));
    await t.pumpAndSettle();
    expect(find.byType(Slider), findsNothing, reason: 'a menu over the button, not the full sheet');
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget); // the current speed
    await t.tap(find.text('1.5×'));
    await t.pump();
    expect(e.commands, contains('speed 1.5'));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the sleep timer menu sets minutes', (t) async {
    final (e, _, _) = await open(t, movie());
    playing(e);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byIcon(Icons.bedtime_outlined));
    await t.pumpAndSettle();
    await t.tap(find.text('30 minutes'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('30 min'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the transport stays left-to-right in a right-to-left language', (t) async {
    t.view.physicalSize = const Size(900, 420);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final e = FakeEngine();
    await t.pumpWidget(MaterialApp(
      locale: const Locale('he'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PlayerScreen(request: movie(), host: FakeHost(), engineFactory: (_) => e, system: FakeSystem(), prefs: PlayerPrefs(), clock: t.binding.clock.now),
    ));
    await t.pump();
    await t.pump();
    playing(e);
    await t.pump(const Duration(milliseconds: 300));
    final back = t.getCenter(find.byIcon(Icons.replay_10)).dx;
    final forward = t.getCenter(find.byIcon(Icons.forward_10)).dx;
    expect(back < forward, true);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a vertical drag on the right changes the volume', (t) async {
    final (e, _, s) = await open(t, movie());
    playing(e);
    await t.pump(const Duration(milliseconds: 300));
    final g = await t.startGesture(const Offset(800, 300));
    await t.pump();
    await g.moveBy(const Offset(0, -30));
    await t.pump(const Duration(milliseconds: 50));
    await g.moveBy(const Offset(0, -100));
    await t.pump(const Duration(milliseconds: 50));
    await g.moveBy(const Offset(0, -20)); // the first update only starts the drag (the start level is read asynchronously)
    await t.pump(const Duration(milliseconds: 50));
    await g.up();
    await t.pump(const Duration(seconds: 2));
    expect(s.levels, isNotEmpty);
    expect(s.levels.last, greaterThan(0.5));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a horizontal drag scrubs and seeks on release', (t) async {
    final (e, _, _) = await open(t, movie());
    playing(e, position: 100, duration: 3600);
    await t.pump(const Duration(milliseconds: 300));
    final g = await t.startGesture(const Offset(300, 210));
    await t.pump();
    await g.moveBy(const Offset(30, 0));
    await t.pump(const Duration(milliseconds: 50));
    await g.moveBy(const Offset(150, 0));
    await t.pump(const Duration(milliseconds: 50));
    await g.up();
    await t.pump(const Duration(milliseconds: 100));
    final seeks = e.commands.where((c) => c.startsWith('seekTo')).toList();
    expect(seeks, hasLength(1));
    expect(double.parse(seeks.single.split(' ').last), greaterThan(100));
    await t.pumpWidget(const SizedBox());
  });
}
