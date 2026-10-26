import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptvmac/app/device.dart';
import 'package:iptvmac/l10n/app_localizations.dart';
import 'package:iptvmac/player/play_request.dart';
import 'package:iptvmac/player/player_prefs.dart';
import 'package:iptvmac/player/player_screen.dart';

import 'package:iptvmac/player/track_label.dart';

import 'fake_engine.dart';
import 'player_screen_test.dart' show FakeHost, FakeSystem, live, movie, playing;

/// The player on a TV remote: every key, the focus, the auto-hide and the menus. Host tests only; no remote was used.

/// Zaps to "Next" for +1 and to "Prev" for -1 (the engine's last load tells which way the player went).
class StepHost extends FakeHost {
  @override
  PlayRequest? zap(PlayRequest c, int step) => zapTo == null ? null : live(step > 0 ? 'Next' : 'Prev');
}

String zapped(FakeEngine e) => e.loads.last.$1.split('/').last.split('.').first;

typedef Rig = (FakeEngine, StepHost, FakeSystem);

Future<Rig> openTv(WidgetTester t, PlayRequest r, {StepHost? host, Locale? locale, bool tv = true, PlayerPrefs? prefs}) async {
  isTelevision = tv;
  t.view.physicalSize = const Size(1280, 720);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final e = FakeEngine();
  final h = host ?? StepHost();
  final s = FakeSystem();
  await t.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PlayerScreen(request: r, host: h, engineFactory: (_) => e, system: s, prefs: prefs ?? PlayerPrefs(), clock: t.binding.clock.now),
  ));
  await t.pump(); // prefs, system.enter
  await t.pump();
  playing(e);
  await t.pump(const Duration(milliseconds: 300));
  e.commands.clear(); // the start-up commands (buffer, subtitle style, speed)
  return (e, h, s);
}

/// Waits until the controls have hidden (5 s on a TV).
Future<void> hideControls(WidgetTester t) => t.pump(const Duration(seconds: 6));

String? focusLabel() => FocusManager.instance.primaryFocus?.debugLabel;

bool hasFocus(WidgetTester t, Finder f) => Focus.of(t.element(f)).hasPrimaryFocus;

Future<void> focus(WidgetTester t, Finder f) async {
  Focus.of(t.element(f)).requestFocus();
  await t.pump(const Duration(milliseconds: 50));
}

Future<void> press(WidgetTester t, LogicalKeyboardKey k, {int ms = 50}) async {
  await t.sendKeyEvent(k, physicalKey: k == LogicalKeyboardKey.goBack ? PhysicalKeyboardKey.escape : null); // the test key table has no Android back scan code: any physical key with the logical Go Back
  await t.pump(Duration(milliseconds: ms));
}

Finder get controlsUp => find.byIcon(Icons.close).hitTestable();

Future<void> end(WidgetTester t) => t.pumpWidget(const SizedBox());

void main() {
  tearDown(() => isTelevision = false);

  group('hidden controls', () {
    testWidgets('Select toggles pause, shows the controls and puts the focus on the play button', (t) async {
      final (e, _, _) = await openTv(t, movie());
      await hideControls(t);
      expect(controlsUp, findsNothing);
      expect(focusLabel(), 'player', reason: 'the screen itself holds the focus while the controls are hidden');
      await press(t, LogicalKeyboardKey.select);
      expect(e.commands, ['pause']);
      expect(e.paused, true);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(controlsUp, findsOneWidget);
      expect(focusLabel(), 'player-play');
      await press(t, LogicalKeyboardKey.select); // on the button now: the same toggle through the normal activation
      expect(e.commands, ['pause', 'play']);
      await end(t);
    });

    testWidgets('Enter does the same, a held Select toggles only once', (t) async {
      final (e, _, _) = await openTv(t, movie());
      await hideControls(t);
      await t.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await t.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await t.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await t.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await t.pump(const Duration(milliseconds: 50));
      expect(e.commands, ['pause']);
      await end(t);
    });

    testWidgets('Left and Right seek back and forward by the seek step and show the amount', (t) async {
      final (e, _, _) = await openTv(t, movie());
      await hideControls(t);
      playing(e, position: 100);
      await press(t, LogicalKeyboardKey.arrowRight);
      expect(e.commands, ['seekBy 10.0']);
      expect(find.text('+10'), findsOneWidget);
      await press(t, LogicalKeyboardKey.arrowRight);
      expect(find.text('+20'), findsOneWidget, reason: 'quick presses add up');
      await press(t, LogicalKeyboardKey.arrowLeft);
      expect(e.commands.last, 'seekBy -10.0');
      expect(find.text('−10'), findsOneWidget, reason: 'the other direction starts a new total');
      expect(controlsUp, findsNothing, reason: 'seeking does not bring up the whole controls');
      await t.pump(const Duration(seconds: 2));
      expect(find.text('−10'), findsNothing);
      await end(t);
    });

    testWidgets('a held key repeats at most five times a second and seeks faster, up to four steps', (t) async {
      final (e, _, _) = await openTv(t, movie());
      await hideControls(t);
      await t.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await t.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight); // too soon after the press: dropped
      expect(e.commands, ['seekBy 10.0']);
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 210));
        await t.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
      }
      await t.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      final steps = [for (final c in e.commands) double.parse(c.split(' ').last)];
      expect(steps.first, 10);
      expect(steps.last, 40, reason: 'capped');
      expect(steps.reduce((a, b) => a > b ? a : b), 40);
      expect(steps.every((s) => s >= 10 && s <= 40), true);
      expect(steps, orderedEquals([...steps]..sort()), reason: 'only ever faster while held');
      await t.pump(const Duration(seconds: 2));
      await end(t);
    });

    testWidgets('the seek step setting is used', (t) async {
      final (e, _, _) = await openTv(t, movie(), prefs: PlayerPrefs(seekStep: 30));
      await hideControls(t);
      await press(t, LogicalKeyboardKey.arrowLeft);
      expect(e.commands, ['seekBy -30.0']);
      await end(t);
    });

    testWidgets('Right is forward in Hebrew too', (t) async {
      final (e, _, _) = await openTv(t, movie(), locale: const Locale('he'));
      await hideControls(t);
      await press(t, LogicalKeyboardKey.arrowRight);
      expect(e.commands, ['seekBy 10.0']);
      await press(t, LogicalKeyboardKey.arrowLeft, ms: 1200);
      expect(e.commands.last, 'seekBy -10.0');
      await end(t);
    });

    testWidgets('Up and Down zap on a live channel: Up the next one (channel up), Down the previous one', (t) async {
      final host = StepHost()..zapTo = live('x');
      final (e, _, _) = await openTv(t, live(), host: host);
      await hideControls(t);
      await press(t, LogicalKeyboardKey.arrowDown);
      expect(zapped(e), 'Prev');
      await press(t, LogicalKeyboardKey.arrowUp);
      expect(zapped(e), 'Next');
      expect(e.loads.length, 3);
      await end(t);
    });

    testWidgets('after a zap the next Up or Down zaps again: the keys do not wander into the controls that showed', (t) async {
      final host = StepHost()..zapTo = live('x');
      final (e, _, _) = await openTv(t, live(), host: host);
      await hideControls(t);
      await press(t, LogicalKeyboardKey.arrowDown);
      expect(controlsUp, findsOneWidget, reason: 'the channel name shows');
      await press(t, LogicalKeyboardKey.arrowDown);
      await press(t, LogicalKeyboardKey.arrowUp);
      expect(e.loads.length, 4);
      expect(zapped(e), 'Next');
      expect(focusLabel(), 'player');
      await end(t);
    });

    testWidgets('Left and Right do nothing on a live channel', (t) async {
      final (e, _, _) = await openTv(t, live());
      await hideControls(t);
      await press(t, LogicalKeyboardKey.arrowLeft);
      await press(t, LogicalKeyboardKey.arrowRight);
      expect(e.commands, isEmpty);
      expect(controlsUp, findsNothing);
      await end(t);
    });

    testWidgets('Up and Down on a movie show the controls with the play button focused', (t) async {
      final (e, _, _) = await openTv(t, movie());
      for (final k in [LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.arrowDown]) {
        await hideControls(t);
        expect(controlsUp, findsNothing);
        await press(t, k);
        expect(controlsUp, findsOneWidget);
        expect(focusLabel(), 'player-play');
      }
      expect(e.commands, isEmpty);
      await end(t);
    });

    testWidgets('Menu, Info and the context key open the details when there are some', (t) async {
      final host = StepHost()..details = true;
      await openTv(t, movie(), host: host);
      for (final k in [LogicalKeyboardKey.contextMenu, LogicalKeyboardKey.info]) {
        await press(t, k);
      }
      expect(host.shownDetails, ['Sintel', 'Sintel']);
      await end(t);
    });

    testWidgets('without details they bring up the controls on the subtitles button', (t) async {
      final (_, _, _) = await openTv(t, movie());
      await hideControls(t);
      await press(t, LogicalKeyboardKey.contextMenu);
      expect(controlsUp, findsOneWidget);
      expect(focusLabel(), 'player-subtitles');
      await end(t);
    });

    testWidgets('Back hides the controls first and closes the player when they are hidden', (t) async {
      final host = StepHost();
      final (e, _, _) = await openTv(t, movie(), host: host);
      playing(e, position: 42);
      expect(controlsUp, findsOneWidget);
      await press(t, LogicalKeyboardKey.goBack, ms: 400);
      expect(controlsUp, findsNothing);
      expect(host.closed, 0);
      expect(focusLabel(), 'player');
      await press(t, LogicalKeyboardKey.goBack);
      expect(host.closed, 1);
      expect(host.saves.last.$2, 42.0);
      await end(t);
      expect(host.closed, 1);
    });

    testWidgets('system back does the same as the Back key', (t) async {
      final host = StepHost();
      await openTv(t, movie(), host: host);
      await t.binding.handlePopRoute();
      await t.pump(const Duration(milliseconds: 400));
      expect(controlsUp, findsNothing);
      expect(host.closed, 0);
      await t.binding.handlePopRoute();
      await t.pump();
      expect(host.closed, 1);
      await end(t);
    });

    testWidgets('Back with the controls held up (paused) closes the player', (t) async {
      final host = StepHost();
      final (e, _, _) = await openTv(t, movie(), host: host);
      await hideControls(t);
      await press(t, LogicalKeyboardKey.select);
      expect(e.paused, true);
      await press(t, LogicalKeyboardKey.goBack);
      expect(host.closed, 1);
      await end(t);
    });

    testWidgets('on a phone none of this is there: the keys do nothing and Back closes', (t) async {
      final host = StepHost();
      final (e, _, _) = await openTv(t, movie(), host: host, tv: false);
      await t.pump(const Duration(seconds: 4));
      await press(t, LogicalKeyboardKey.select);
      await press(t, LogicalKeyboardKey.arrowRight);
      await press(t, LogicalKeyboardKey.mediaPlayPause);
      expect(e.commands, isEmpty);
      await t.binding.handlePopRoute();
      await t.pump();
      expect(host.closed, 1);
      await end(t);
    });
  });

  group('media keys', () {
    testWidgets('play/pause, play and pause', (t) async {
      final (e, _, _) = await openTv(t, movie());
      await press(t, LogicalKeyboardKey.mediaPlayPause);
      expect(e.paused, true);
      await press(t, LogicalKeyboardKey.mediaPlayPause);
      expect(e.paused, false);
      await press(t, LogicalKeyboardKey.mediaPause);
      expect(e.paused, true);
      await press(t, LogicalKeyboardKey.mediaPause);
      expect(e.paused, true, reason: 'pause is not a toggle');
      await press(t, LogicalKeyboardKey.mediaPlay);
      await press(t, LogicalKeyboardKey.mediaPlay);
      expect(e.paused, false);
      await end(t);
    });

    testWidgets('they work with a control focused and with the controls hidden', (t) async {
      final (e, _, _) = await openTv(t, movie());
      await press(t, LogicalKeyboardKey.arrowUp); // the play button has the focus
      await press(t, LogicalKeyboardKey.mediaPause);
      expect(e.paused, true);
      await press(t, LogicalKeyboardKey.mediaPlay);
      await hideControls(t);
      await press(t, LogicalKeyboardKey.mediaPause);
      expect(e.paused, true);
      await end(t);
    });

    testWidgets('stop closes the player', (t) async {
      final host = StepHost();
      await openTv(t, movie(), host: host);
      await press(t, LogicalKeyboardKey.mediaStop);
      expect(host.closed, 1);
      await end(t);
    });

    testWidgets('fast-forward and rewind seek by the step', (t) async {
      final (e, _, _) = await openTv(t, movie());
      await hideControls(t);
      playing(e, position: 100);
      await press(t, LogicalKeyboardKey.mediaFastForward);
      await press(t, LogicalKeyboardKey.mediaRewind, ms: 1200);
      expect(e.commands, ['seekBy 10.0', 'seekBy -10.0']);
      expect(controlsUp, findsNothing);
      await end(t);
    });

    testWidgets('next and previous: the next episode, and the start of the movie', (t) async {
      final host = StepHost()..next = movie('Episode 2');
      final (e, _, _) = await openTv(t, movie('Episode 1'), host: host);
      playing(e, position: 300);
      await press(t, LogicalKeyboardKey.mediaTrackPrevious);
      expect(e.commands, ['seekTo 0.0']);
      await press(t, LogicalKeyboardKey.mediaTrackNext);
      expect(e.loads.last.$1, Uri.parse('http://x/Episode 2.mp4').toString());
      await end(t);
    });

    testWidgets('next and previous and CH+ / CH- zap on a live channel', (t) async {
      final host = StepHost()..zapTo = live('x');
      final (e, _, _) = await openTv(t, live(), host: host);
      final seen = <String>[];
      for (final k in [LogicalKeyboardKey.mediaTrackNext, LogicalKeyboardKey.mediaTrackPrevious, LogicalKeyboardKey.channelUp, LogicalKeyboardKey.channelDown]) {
        await press(t, k);
        seen.add(zapped(e));
      }
      expect(seen, ['Next', 'Prev', 'Next', 'Prev']);
      expect(e.loads.length, 5);
      await end(t);
    });
  });

  group('controls up', () {
    testWidgets('the arrows move the focus over the top bar, the transport, the seek bar and the menus', (t) async {
      await openTv(t, movie());
      await press(t, LogicalKeyboardKey.select); // toggles pause, controls up, focus on play
      expect(focusLabel(), 'player-play');
      expect(hasFocus(t, find.byIcon(Icons.play_arrow)), true);
      await press(t, LogicalKeyboardKey.arrowRight);
      expect(hasFocus(t, find.byIcon(Icons.forward_10)), true);
      await press(t, LogicalKeyboardKey.arrowLeft);
      await press(t, LogicalKeyboardKey.arrowLeft);
      expect(hasFocus(t, find.byIcon(Icons.replay_10)), true);
      await press(t, LogicalKeyboardKey.arrowRight);
      await press(t, LogicalKeyboardKey.arrowUp);
      expect(focusLabel(), isNot('player-play'));
      expect(t.getCenter(find.byIcon(Icons.close)).dy, lessThan(100), reason: 'the top bar is above');
      await press(t, LogicalKeyboardKey.arrowDown);
      expect(focusLabel(), 'player-play');
      await press(t, LogicalKeyboardKey.arrowDown);
      expect(FocusManager.instance.primaryFocus!.rect.center.dy, closeTo(635, 5), reason: 'the seek bar');
      await press(t, LogicalKeyboardKey.arrowDown);
      expect(FocusManager.instance.primaryFocus!.rect.center.dy, greaterThan(650), reason: 'the menu buttons');
      await press(t, LogicalKeyboardKey.arrowLeft);
      await press(t, LogicalKeyboardKey.arrowLeft);
      expect(hasFocus(t, find.text('1×')), true, reason: 'speed is the first button; the disabled audio button is skipped');
      await end(t);
    });

    testWidgets('the seek bar takes Left/Right, Select commits', (t) async {
      final (e, _, _) = await openTv(t, movie());
      playing(e, position: 100, duration: 3600);
      await t.pump(const Duration(milliseconds: 300));
      await press(t, LogicalKeyboardKey.arrowUp); // play
      await press(t, LogicalKeyboardKey.arrowDown); // the seek bar
      await press(t, LogicalKeyboardKey.arrowRight);
      await press(t, LogicalKeyboardKey.arrowRight);
      await press(t, LogicalKeyboardKey.arrowLeft, ms: 1200);
      expect(e.commands.where((c) => c.startsWith('seek')), isEmpty, reason: 'nothing happens before the commit');
      expect(find.textContaining('1:50'), findsWidgets, reason: 'the target shows (100 + 10 + 10 - 10)');
      await press(t, LogicalKeyboardKey.select);
      expect(e.commands.where((c) => c.startsWith('seek')).toList(), ['seekTo 110.0']);
      await end(t);
    });

    testWidgets('a pause in the keys commits the seek bar, Back cancels it, leaving it commits', (t) async {
      final (e, _, _) = await openTv(t, movie());
      playing(e, position: 100, duration: 3600);
      await t.pump(const Duration(milliseconds: 300));
      await press(t, LogicalKeyboardKey.arrowUp);
      await press(t, LogicalKeyboardKey.arrowDown);
      await press(t, LogicalKeyboardKey.arrowRight);
      await t.pump(const Duration(seconds: 2));
      expect(e.commands, ['seekTo 110.0']);

      e.commands.clear();
      await press(t, LogicalKeyboardKey.arrowRight);
      await press(t, LogicalKeyboardKey.goBack, ms: 400);
      await t.pump(const Duration(seconds: 2));
      expect(e.commands, isEmpty, reason: 'Back cancels the scrub');
      expect(controlsUp, findsOneWidget, reason: 'and leaves the controls up');

      await press(t, LogicalKeyboardKey.arrowRight);
      await press(t, LogicalKeyboardKey.arrowUp); // leaves the bar
      expect(e.commands, ['seekTo 120.0']);
      await end(t);
    });

    testWidgets('the seek bar goes the same way in Hebrew: Right is later', (t) async {
      final (e, _, _) = await openTv(t, movie(), locale: const Locale('he'));
      playing(e, position: 100, duration: 3600);
      await t.pump(const Duration(milliseconds: 300));
      await press(t, LogicalKeyboardKey.arrowUp);
      await press(t, LogicalKeyboardKey.arrowDown);
      await press(t, LogicalKeyboardKey.arrowRight);
      await press(t, LogicalKeyboardKey.select);
      expect(e.commands, ['seekTo 110.0']);
      await end(t);
    });

    testWidgets('the controls stay while keys are pressed and hide five seconds after the last one', (t) async {
      final (_, _, _) = await openTv(t, movie());
      await press(t, LogicalKeyboardKey.arrowUp);
      for (var i = 0; i < 3; i++) {
        await t.pump(const Duration(seconds: 4)); // three seconds would be the phone's limit
        expect(controlsUp, findsOneWidget);
        await press(t, LogicalKeyboardKey.arrowRight);
      }
      await t.pump(const Duration(seconds: 4));
      expect(controlsUp, findsOneWidget);
      await t.pump(const Duration(seconds: 2));
      expect(controlsUp, findsNothing);
      expect(focusLabel(), 'player', reason: 'the focus came back to the screen');
      await end(t);
    });

    testWidgets('after they hid the keys seek again and Select works', (t) async {
      final (e, _, _) = await openTv(t, movie());
      await press(t, LogicalKeyboardKey.arrowUp);
      await hideControls(t);
      await press(t, LogicalKeyboardKey.arrowRight);
      expect(e.commands, ['seekBy 10.0']);
      await end(t);
    });

    testWidgets('a speed sheet keeps the controls, takes the D-pad and closes with Back', (t) async {
      final (e, _, _) = await openTv(t, movie());
      await press(t, LogicalKeyboardKey.arrowUp);
      await focus(t, find.text('1×'));
      await press(t, LogicalKeyboardKey.select);
      await t.pumpAndSettle();
      expect(find.text('Playback speed'), findsOneWidget);
      await t.pump(const Duration(seconds: 12));
      expect(find.text('Playback speed'), findsOneWidget, reason: 'a sheet is not closed by a timer');
      await press(t, LogicalKeyboardKey.arrowRight);
      await press(t, LogicalKeyboardKey.select);
      expect(e.commands, ['speed 1.25']);
      await press(t, LogicalKeyboardKey.arrowDown); // the slider hands the arrows over
      await press(t, LogicalKeyboardKey.arrowDown);
      expect(FocusManager.instance.primaryFocus?.debugLabel, isNot('player'));
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('Playback speed'), findsNothing);
      expect(controlsUp, findsOneWidget, reason: 'the controls are still up, with a fresh five seconds');
      await end(t);
    });

    testWidgets('the subtitles menu is driven with the D-pad', (t) async {
      final (e, _, _) = await openTv(t, movie());
      e.tracks = [const Track(id: 1, type: 'sub', lang: 'eng', title: 'Commentary'), const Track(id: 2, type: 'sub', lang: 'zzz')];
      await t.pump(const Duration(milliseconds: 300));
      await press(t, LogicalKeyboardKey.contextMenu);
      expect(focusLabel(), 'player-subtitles');
      await press(t, LogicalKeyboardKey.select);
      await t.pumpAndSettle();
      expect(find.text('Off'), findsOneWidget);
      await press(t, LogicalKeyboardKey.arrowDown);
      await press(t, LogicalKeyboardKey.arrowDown);
      await press(t, LogicalKeyboardKey.select);
      await t.pumpAndSettle();
      expect(e.commands.where((c) => c.startsWith('sub')), hasLength(1));
      await end(t);
    });

    testWidgets('a menu closes with Back and keeps the controls', (t) async {
      final (e, _, _) = await openTv(t, movie());
      e.tracks = [const Track(id: 1, type: 'sub', lang: 'eng')];
      await t.pump(const Duration(milliseconds: 300));
      await press(t, LogicalKeyboardKey.contextMenu);
      await press(t, LogicalKeyboardKey.select);
      await t.pumpAndSettle();
      expect(find.text('Off'), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('Off'), findsNothing);
      expect(controlsUp, findsOneWidget);
      expect(e.commands, isEmpty);
      await end(t);
    });

    testWidgets('the subtitle adjust sheet works with the D-pad', (t) async {
      final (e, _, _) = await openTv(t, movie());
      e.tracks = [const Track(id: 1, type: 'sub', lang: 'eng')];
      await t.pump(const Duration(milliseconds: 300));
      await press(t, LogicalKeyboardKey.contextMenu);
      await press(t, LogicalKeyboardKey.select);
      await t.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await press(t, LogicalKeyboardKey.arrowDown); // Off, Eng, (divider), Add, Adjust
      }
      await press(t, LogicalKeyboardKey.select);
      await t.pumpAndSettle();
      expect(find.text('Subtitle size'), findsOneWidget);
      await press(t, LogicalKeyboardKey.select); // the focus starts on the first "+"
      expect(e.commands.last, startsWith('substyle 1.1'));
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('Subtitle size'), findsNothing);
      await end(t);
    });
  });

  group('cards', () {
    testWidgets('the sleep menu is driven with the D-pad and closes with Back', (t) async {
      await openTv(t, movie());
      await press(t, LogicalKeyboardKey.arrowUp);
      await focus(t, find.byIcon(Icons.bedtime_outlined));
      await press(t, LogicalKeyboardKey.select);
      await t.pumpAndSettle();
      expect(find.text('30 minutes'), findsOneWidget);
      await press(t, LogicalKeyboardKey.arrowDown);
      await press(t, LogicalKeyboardKey.arrowDown);
      await press(t, LogicalKeyboardKey.select);
      await t.pumpAndSettle();
      expect(find.text('15 min'), findsOneWidget);
      await focus(t, find.byIcon(Icons.bedtime));
      await press(t, LogicalKeyboardKey.select);
      await t.pumpAndSettle();
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('30 minutes'), findsNothing);
      await end(t);
    });

    testWidgets('the error card takes the focus on Retry; Select retries, Back closes', (t) async {
      final host = StepHost();
      final (e, _, _) = await openTv(t, movie(), host: host);
      playing(e, position: 40);
      e.fail('Connection reset');
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Playback failed'), findsOneWidget);
      await press(t, LogicalKeyboardKey.select);
      expect(e.loads.last, ('http://x/Sintel.mp4', 40.0));
      expect(find.text('Playback failed'), findsNothing);
      await t.pump(const Duration(milliseconds: 300));
      expect(focusLabel(), 'player', reason: 'the screen has the focus back');
      e.fail('again');
      await t.pump(const Duration(milliseconds: 300));
      await press(t, LogicalKeyboardKey.goBack);
      expect(host.closed, 1);
      await end(t);
    });

    testWidgets('the up-next card: Select plays the next episode, Back cancels the countdown', (t) async {
      final host = StepHost()..next = movie('Episode 2');
      final (e, _, _) = await openTv(t, movie('Episode 1'), host: host);
      playing(e, position: 10, duration: 60);
      await t.pump(const Duration(milliseconds: 300));
      e
        ..position = 59
        ..atEof = true;
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Playing in 5 s'), findsOneWidget);
      await press(t, LogicalKeyboardKey.goBack);
      expect(find.textContaining('Playing in'), findsNothing);
      expect(host.closed, 0);
      await t.pump(const Duration(seconds: 8));
      expect(e.loads.length, 1);

      e.atEof = false;
      e.position = 10;
      await t.pump(const Duration(milliseconds: 300));
      e
        ..position = 59
        ..atEof = true;
      await t.pump(const Duration(milliseconds: 300));
      await press(t, LogicalKeyboardKey.select);
      expect(e.loads.last.$1, Uri.parse('http://x/Episode 2.mp4').toString());
      await end(t);
    });
  });

  group('what a TV does not have', () {
    testWidgets('no rotate and no Picture in Picture button, however small the screen', (t) async {
      final (e, _, _) = await openTv(t, movie());
      t.view.physicalSize = const Size(900, 420);
      playing(e);
      await t.pump(const Duration(milliseconds: 300));
      await press(t, LogicalKeyboardKey.arrowUp);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.stay_current_portrait), findsNothing);
      expect(find.byIcon(Icons.picture_in_picture_alt), findsNothing);
      await end(t);
    });

    testWidgets('a swipe changes no volume or brightness and shows no level', (t) async {
      final (e, _, s) = await openTv(t, movie());
      playing(e);
      final g = await t.startGesture(const Offset(1100, 500));
      await t.pump();
      await g.moveBy(const Offset(0, -30));
      await t.pump(const Duration(milliseconds: 50));
      await g.moveBy(const Offset(0, -150));
      await t.pump(const Duration(milliseconds: 50));
      await g.up();
      await t.pump(const Duration(seconds: 2));
      expect(s.levels, isEmpty);
      expect(find.text('Volume'), findsNothing);
      await end(t);
    });
  });

  group('right to left', () {
    testWidgets('the arrows follow the screen: the top bar is mirrored, Left goes on to the left', (t) async {
      await openTv(t, movie(), locale: const Locale('he'));
      final close = find.byIcon(Icons.close);
      final star = find.byIcon(Icons.star_border);
      await focus(t, close);
      expect(t.getCenter(close).dx > t.getCenter(star).dx, true, reason: 'close is at the start, which is the right in Hebrew');
      expect(hasFocus(t, close), true);
      await press(t, LogicalKeyboardKey.arrowLeft);
      expect(hasFocus(t, star), true);
      await press(t, LogicalKeyboardKey.arrowRight);
      expect(hasFocus(t, close), true);
      await end(t);
    });

    testWidgets('the same in English the other way round', (t) async {
      await openTv(t, movie());
      final close = find.byIcon(Icons.close);
      final star = find.byIcon(Icons.star_border);
      await focus(t, close);
      expect(t.getCenter(close).dx < t.getCenter(star).dx, true);
      expect(hasFocus(t, close), true);
      await press(t, LogicalKeyboardKey.arrowRight);
      expect(hasFocus(t, star), true);
      await end(t);
    });

    testWidgets('the transport stays left-to-right in Hebrew and Left from play goes to skip back', (t) async {
      await openTv(t, movie(), locale: const Locale('he'));
      await press(t, LogicalKeyboardKey.arrowUp);
      expect(focusLabel(), 'player-play');
      await press(t, LogicalKeyboardKey.arrowLeft);
      expect(hasFocus(t, find.byIcon(Icons.replay_10)), true);
      await end(t);
    });
  });
}

Object? e0() => FocusManager.instance.primaryFocus;
