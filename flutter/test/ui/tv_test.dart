import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptvmac/app/device.dart';
import 'package:iptvmac/downloads/downloads_model.dart';
import 'package:iptvmac/downloads/library_downloads.dart';
import 'package:iptvmac/player/play_request.dart';
import 'package:iptvmac/ui/item_views.dart';
import 'package:iptvmac/ui/play.dart' as play;

import '../app/harness.dart';
import '../downloads/fake_download_engine.dart';

const tvSize = Size(1280, 720);

/// Lets focus change, scrolling, the grow animation and the model's futures (fake HTTP) run. Not pumpAndSettle: a sheet that is still
/// loading shows a spinner, which never settles.
Future<void> frames(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 8)));
    await t.pump(const Duration(milliseconds: 120));
  }
}

/// A D-pad key, then [frames].
Future<void> press(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyEvent(k);
  await frames(t);
}

Future<void> back(WidgetTester t) async {
  await t.binding.handlePopRoute(); // what the remote's Back button does on Android
  await frames(t);
  await frames(t); // the route's leave animation
}

const up = LogicalKeyboardKey.arrowUp, down = LogicalKeyboardKey.arrowDown, left = LogicalKeyboardKey.arrowLeft, right = LogicalKeyboardKey.arrowRight;
const select = LogicalKeyboardKey.select;

/// The first text inside the widget that has focus: what a person sees lit up.
String? focusedText() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return null;
  String? found;
  void visit(Element e) {
    if (found != null) return;
    final w = e.widget;
    if (w is Text && (w.data ?? '').isNotEmpty) {
      found = w.data;
      return;
    }
    e.visitChildren(visit);
  }

  (ctx as Element).visitChildren(visit);
  return found;
}

/// Whether the focused widget is inside a widget of type [T].
bool focusInside<T extends Widget>() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return false;
  return ctx.findAncestorWidgetOfExactType<T>() != null;
}

/// Presses Down (then Up) until the focused text starts with [text]; fails instead of looping forever.
Future<void> moveTo(WidgetTester t, String text) async {
  bool at() => (focusedText() ?? '').startsWith(text);
  for (final k in [down, up]) {
    for (var i = 0; i < 45 && !at(); i++) {
      await press(t, k);
    }
  }
  expect(focusedText(), startsWith(text));
}

Rect? focusRect() => FocusManager.instance.primaryFocus?.rect;

void main() {
  setUp(() => isTelevision = true);
  tearDown(() => isTelevision = false);

  Future<Harness> shell(WidgetTester tester, {int movies = 0, Locale? locale}) async {
    final h = await Harness.create(tester, withAccount: true);
    h.provider.extraMovies = movies;
    await tester.runAsync(() => h.model.sync());
    await h.pumpApp(tester, size: tvSize, locale: locale);
    await go(tester, index: true);
    return h;
  }

  testWidgets('shell: rail, first stop is the first category, the arrows move along the rail, Select opens a section, Back goes to the first tab', (tester) async {
    await shell(tester);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(focusedText(), 'All channels'); // no touch needed to start: focus is already on the first row
    expect(find.byKey(const Key('tv-focus-ring')), findsOneWidget);

    await press(tester, left);
    expect(focusInside<NavigationRail>(), isTrue);
    expect(focusedText(), 'Live');
    await press(tester, down);
    expect(focusedText(), 'Movies');
    await press(tester, select);
    expect(find.text('All movies'), findsOneWidget); // the Movies front page

    await press(tester, down); // Series
    await press(tester, down); // Library
    await press(tester, down); // Settings
    expect(focusedText(), 'Settings');
    await press(tester, down); // the end: nothing past Settings, focus stays
    expect(focusedText(), 'Settings');
    await press(tester, select);
    expect(find.text('Sources'), findsWidgets);

    await back(tester); // Back from another tab: the first tab
    expect(find.text('All channels'), findsOneWidget);
    expect(focusInside<NavigationRail>(), isTrue, reason: 'focus is not lost when the section behind it changes');
  });

  testWidgets('shell: a text size and margin for the couch, and the ring sits on the focused row', (tester) async {
    await shell(tester);
    final ring = tester.getRect(find.byKey(const Key('tv-focus-ring')));
    final row = focusRect()!;
    expect(ring.contains(row.center), isTrue);
    expect(ring.width, greaterThan(row.width)); // drawn around it, not inside
    // overscan: nothing is closer than 48 px to the left/right edge or 27 px to the top
    final rail = tester.getRect(find.byType(NavigationRail));
    expect(rail.left, greaterThanOrEqualTo(48));
    expect(tester.getTopLeft(find.byType(AppBar)).dy, greaterThanOrEqualTo(27));
    expect(MediaQuery.textScalerOf(tester.element(find.byType(NavigationRail))).scale(10), closeTo(12, 0.01));
  });

  testWidgets('channel list: arrows move row to row, Right reaches the star, Select toggles it and plays', (tester) async {
    final h = await shell(tester);
    PlayRequest? request;
    final saved = play.playerBuilder;
    play.playerBuilder = (r, hh) {
      request = r;
      return const Scaffold(body: Text('player'));
    };
    addTearDown(() => play.playerBuilder = saved);

    await press(tester, select); // All channels
    expect(find.byType(ChannelRow), findsNWidgets(3));
    expect(focusInside<ChannelRow>(), isTrue, reason: 'the list opens with its first row focused, the row the category row was replaced by');
    final first = focusedText();
    await press(tester, down);
    final second = focusedText();
    expect(second, isNot(first));
    expect(focusRect()!.top, greaterThan(0));
    await press(tester, up);
    expect(focusedText(), first);

    await press(tester, right); // the star of the row
    expect(FocusManager.instance.primaryFocus!.context!.findAncestorWidgetOfExactType<IconButton>(), isNotNull);
    await press(tester, select);
    expect(h.model.favoriteKeys, hasLength(1));
    await press(tester, left);
    await press(tester, select);
    expect(find.text('player'), findsOneWidget);
    expect(request!.isLive, isTrue);
    await back(tester); // Back out of the player
    expect(find.text('player'), findsNothing);
    expect(focusInside<ChannelRow>(), isTrue, reason: 'focus comes back to the list');
    expect(focusedText(), first);

    await press(tester, up); // up from the first row: the category chips / search above the list
    expect(focusInside<ChannelRow>(), isFalse);
    expect(focusInside<ListView>() || focusInside<TextField>() || focusInside<ChoiceChip>(), isTrue);
  });

  testWidgets('poster grid: arrows move cell to cell and the grid scrolls along, Up from the first row leaves the grid, Select opens details, Back returns', (tester) async {
    final h = await shell(tester, movies: 20);
    expect(h.model.accounts, isNotEmpty);
    await press(tester, left);
    await press(tester, down); // Movies
    await press(tester, select);
    await press(tester, right); // into the section
    await moveTo(tester, 'All movies');
    await press(tester, select);
    expect(find.byType(PosterCell), findsWidgets);
    expect(focusInside<PosterCell>(), isTrue, reason: 'the grid opens with its first cell focused');
    final firstText = focusedText();
    final firstRect = focusRect()!;
    await press(tester, right);
    final r2 = focusRect()!;
    expect(r2.left, greaterThan(firstRect.left));
    expect(r2.top, firstRect.top);
    await press(tester, left);
    expect(focusedText(), firstText);

    // down several rows: the grid scrolls and the focused cell stays on screen
    for (var i = 0; i < 4; i++) {
      await press(tester, down);
      expect(focusInside<PosterCell>(), isTrue);
      final r = focusRect()!;
      expect(r.top, greaterThanOrEqualTo(0));
      expect(r.bottom, lessThanOrEqualTo(tvSize.height + 1), reason: 'row ${i + 1} is scrolled into view');
    }
    expect(focusRect()!.top, greaterThan(firstRect.top - 1000));

    // Select opens the details sheet (Play has focus), Back closes it and the same cell is focused again
    final cell = focusedText();
    await press(tester, select);
    expect(find.text('Play'), findsOneWidget);
    expect(focusedText(), 'Play');
    await back(tester);
    expect(find.text('Play'), findsNothing);
    expect(focusedText(), cell);

    // up to the top: leaves the grid for the search field / chips
    for (var i = 0; i < 10 && focusInside<PosterCell>(); i++) {
      await press(tester, up);
    }
    expect(focusInside<PosterCell>(), isFalse);
  });

  testWidgets('Hebrew: the arrows follow the mirrored layout (the rail is on the right, Right reaches it)', (tester) async {
    await shell(tester, locale: const Locale('he'));
    expect(Directionality.of(tester.element(find.byType(NavigationRail))), TextDirection.rtl);
    final railLeft = tester.getRect(find.byType(NavigationRail)).left;
    expect(railLeft, greaterThan(tvSize.width / 2));
    expect(focusInside<NavigationRail>(), isFalse); // content is focused first
    await press(tester, right);
    expect(focusInside<NavigationRail>(), isTrue);
    await press(tester, left);
    expect(focusInside<NavigationRail>(), isFalse);
  });

  testWidgets('add-source form: the cursor passes over fields without a keyboard, Select types, Down leaves, Test and Save by remote', (tester) async {
    final h = await Harness.create(tester);
    await h.pumpApp(tester, size: tvSize);
    expect(find.text('Welcome to IPTVMac'), findsOneWidget);
    expect(focusedText(), 'Add source…'); // first run: the one button is focused
    expect(find.text('Paste'), findsNothing); // no clipboard on a TV
    await press(tester, select);

    TextField field(String k) => tester.widget<TextField>(find.byKey(Key(k)));
    expect(find.byKey(const Key('field-name')), findsOneWidget);
    expect(field('field-name').readOnly, isTrue);
    expect(tester.testTextInput.isVisible, isFalse, reason: 'resting on a field must not pop up the keyboard');
    expect(FocusManager.instance.primaryFocus, field('field-name').focusNode);

    Future<void> type(String k, String text) async {
      await press(tester, select);
      expect(field(k).readOnly, isFalse);
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.enterText(find.byKey(Key(k)), text);
      await press(tester, down);
      expect(field(k).readOnly, isTrue);
    }

    await type('field-name', 'Home');
    expect(field('field-server').focusNode!.hasPrimaryFocus, isTrue);
    await type('field-server', 'http://panel.test');
    await type('field-username', 'u');
    await type('field-password', 'p');
    expect(tester.testTextInput.isVisible, isFalse);
    expect(focusedText(), 'Test connection');
    await press(tester, select);
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Connected successfully'), findsOneWidget);
    expect(focusedText(), 'Save and sync', reason: 'the button keeps focus while testing and becomes Save');
    await press(tester, select);
    await go(tester);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(h.model.accounts.single.name, 'Home');
    expect(focusInside<NavigationRail>(), isFalse);
    expect(FocusManager.instance.primaryFocus, isNotNull);
    expect(find.byKey(const Key('tv-focus-ring')), findsOneWidget, reason: 'focus is not lost when the first-run screen is replaced');
  });

  testWidgets('settings: Select opens the interval dialog with the chosen option focused, Back closes it and focus returns; choices by remote', (tester) async {
    final h = await shell(tester);
    await press(tester, left);
    for (var i = 0; i < 4; i++) {
      await press(tester, down);
    }
    await press(tester, select);
    await press(tester, right); // into the page
    expect(focusInside<NavigationRail>(), isFalse);
    await moveTo(tester, 'Home');
    await press(tester, right); // the buttons beside the source: refresh, then delete
    expect(FocusManager.instance.primaryFocus!.context!.findAncestorWidgetOfExactType<IconButton>()?.tooltip, 'Refresh');
    await press(tester, right);
    expect(FocusManager.instance.primaryFocus!.context!.findAncestorWidgetOfExactType<IconButton>()?.tooltip, 'Delete');
    await press(tester, left);
    await press(tester, left);

    // no file-picker backup, no downloads, no update rows on a TV
    expect(find.text('Export backup'), findsNothing);
    expect(find.text('Import backup'), findsNothing);
    expect(find.byKey(const Key('downloads-tile')), findsNothing);
    expect(find.byKey(const Key('auto-update-switch')), findsNothing);

    await moveTo(tester, 'Update playlists');
    final tile = focusRect()!;
    await press(tester, select);
    expect(find.byType(SimpleDialog), findsOneWidget);
    expect(focusInside<SimpleDialog>(), isTrue);
    await press(tester, down);
    await press(tester, select);
    expect(find.byType(SimpleDialog), findsNothing);
    expect(h.model.refreshHours, isNot(0));
    expect(focusedText(), 'Update playlists');
    expect(focusRect()!.top, tile.top);

    // the appearance buttons: Right then Select
    await press(tester, down);
    expect(focusInside<SegmentedButton<String>>(), isTrue);
    await press(tester, right);
    await press(tester, right);
    await press(tester, select);
    expect(h.model.prefs.appearance, 'dark');

    // all the way down: every row can be reached and the page scrolled along
    await moveTo(tester, 'About');
    expect(focusRect()!.bottom, lessThanOrEqualTo(tvSize.height));
    await press(tester, select);
    expect(find.text('Privacy'), findsOneWidget);
    expect(focusedText(), 'Privacy'); // the About screen starts on its first row
    await back(tester);
    expect(focusedText(), 'About');
  });

  testWidgets('dialog: Cancel has focus, Right reaches the destructive button, Back closes without doing it and focus returns', (tester) async {
    final h = await shell(tester);
    h.db.write((d) => d.execute('SELECT 1'));
    await press(tester, left);
    for (var i = 0; i < 4; i++) {
      await press(tester, down);
    }
    await press(tester, select);
    await press(tester, right);
    await moveTo(tester, 'Clear watch history');
    final tile = focusRect()!;
    await press(tester, select);
    expect(find.textContaining('cannot be undone'), findsOneWidget);
    expect(focusedText(), 'Cancel');
    await press(tester, select); // Cancel
    expect(find.textContaining('cannot be undone'), findsNothing);
    expect(focusRect()!.top, tile.top);
    expect((focusedText() ?? '').startsWith('Clear watch history'), isTrue);

    await press(tester, select);
    await press(tester, right);
    expect(focusedText(), 'Clear');
    await back(tester);
    expect(find.textContaining('cannot be undone'), findsNothing);
    expect((focusedText() ?? '').startsWith('Clear watch history'), isTrue);

    await press(tester, select);
    await press(tester, right);
    await press(tester, select);
    expect(find.textContaining('cannot be undone'), findsNothing);
  });

  testWidgets('a TV has no downloads: no entry in Library or Settings even when the platform offers them', (tester) async {
    final h = await Harness.create(tester, withAccount: true, sync: true);
    final dir = Directory.systemTemp.createTempSync('tv_dl');
    addTearDown(() => dir.deleteSync(recursive: true));
    final d = DownloadsModel(engine: FakeDownloadEngine(), store: File('${dir.path}/downloads.json'), dir: '${dir.path}/Downloads', resolveUrl: h.model.downloadUrl);
    expect(d.enabled, isTrue);
    await h.pumpApp(tester, size: tvSize, downloads: d);
    await go(tester);
    await press(tester, left);
    for (var i = 0; i < 3; i++) {
      await press(tester, down);
    }
    await press(tester, select); // Library
    expect(find.byKey(const Key('downloads-action')), findsNothing);
    await press(tester, down);
    await press(tester, select); // Settings
    expect(find.byKey(const Key('downloads-tile')), findsNothing);
    await settle(tester);
  });

  testWidgets('refresh without pulling: a focusable Sync button in every section', (tester) async {
    final h = await shell(tester);
    await press(tester, select);
    final before = h.provider.calls.length;
    final sync = find.byTooltip('Refresh');
    expect(sync, findsOneWidget);
    while (!focusInside<IconButton>() || (FocusManager.instance.primaryFocus!.context!.findAncestorWidgetOfExactType<IconButton>()?.tooltip != 'Refresh')) {
      await press(tester, up);
      if (focusInside<NavigationRail>()) break;
    }
    expect(FocusManager.instance.primaryFocus!.context!.findAncestorWidgetOfExactType<IconButton>()?.tooltip, 'Refresh');
    await press(tester, select);
    await settle(tester);
    expect(h.provider.calls.length, greaterThan(before));
  });

  testWidgets('phones are untouched: no ring, no rail on a phone, no text scaling', (tester) async {
    isTelevision = false;
    await Harness.create(tester, withAccount: true, sync: true).then((h) => h.pumpApp(tester));
    await go(tester);
    expect(find.byKey(const Key('tv-focus-ring')), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(MediaQuery.textScalerOf(tester.element(find.byType(NavigationBar))).scale(10), 10);
  });
}
