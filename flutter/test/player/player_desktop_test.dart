import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptvmac/app/device.dart';
import 'package:iptvmac/l10n/app_localizations.dart';
import 'package:iptvmac/player/play_request.dart';
import 'package:iptvmac/player/player_desktop.dart';
import 'package:iptvmac/player/player_prefs.dart';
import 'package:iptvmac/player/player_screen.dart';
import 'package:iptvmac/player/player_system.dart';

import 'fake_engine.dart';
import 'player_screen_test.dart' show FakeHost, live, movie, playing;

/// The Windows player: keys, mouse wheel, clicks and full screen. Host tests only (the window itself is not opened).

class DesktopSystem extends PlayerSystem {
  final fullscreens = <bool>[];
  @override
  Future<void> setFullscreen(bool on) async => fullscreens.add(on);
}

Future<(FakeEngine, FakeHost, DesktopSystem)> openDesktop(WidgetTester t, PlayRequest r) async {
  isDesktop = true;
  addTearDown(() => isDesktop = false);
  t.view.physicalSize = const Size(1280, 720);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final e = FakeEngine();
  final h = FakeHost();
  final s = DesktopSystem();
  await t.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PlayerScreen(request: r, host: h, engineFactory: (_) => e, system: s, prefs: PlayerPrefs(), clock: t.binding.clock.now),
  ));
  await t.pump();
  await t.pump();
  playing(e);
  await t.pump(const Duration(milliseconds: 300));
  e.commands.clear();
  return (e, h, s);
}

Future<void> press(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyEvent(k);
  await t.pump(const Duration(milliseconds: 50));
}

void main() {
  test('the key map', () {
    expect(desktopAction(LogicalKeyboardKey.space), DesktopAction.pause);
    expect(desktopAction(LogicalKeyboardKey.keyK), DesktopAction.pause);
    expect(desktopAction(LogicalKeyboardKey.arrowLeft), DesktopAction.back);
    expect(desktopAction(LogicalKeyboardKey.arrowRight, shift: true), DesktopAction.bigForward);
    expect(desktopAction(LogicalKeyboardKey.arrowUp), DesktopAction.volumeUp);
    expect(desktopAction(LogicalKeyboardKey.arrowDown), DesktopAction.volumeDown);
    expect(desktopAction(LogicalKeyboardKey.keyF), DesktopAction.fullscreen);
    expect(desktopAction(LogicalKeyboardKey.f11), DesktopAction.fullscreen);
    expect(desktopAction(LogicalKeyboardKey.escape), DesktopAction.escape);
    expect(desktopAction(LogicalKeyboardKey.keyQ), DesktopAction.none);
  });

  testWidgets('space pauses and plays, arrows seek by the step', (t) async {
    final (e, _, _) = await openDesktop(t, movie());
    await press(t, LogicalKeyboardKey.space);
    expect(e.commands, contains('pause'));
    await press(t, LogicalKeyboardKey.arrowRight);
    expect(e.commands.any((c) => c.startsWith('seekBy 10')), isTrue, reason: e.commands.toString());
    await press(t, LogicalKeyboardKey.arrowLeft);
    expect(e.commands.any((c) => c.startsWith('seekBy -10')), isTrue);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('up and down change the engine volume, M mutes and restores it', (t) async {
    final (e, _, _) = await openDesktop(t, movie());
    await press(t, LogicalKeyboardKey.arrowDown);
    expect(e.commands, contains('volume 0.95'));
    await press(t, LogicalKeyboardKey.keyM);
    expect(e.commands.last, 'volume 0.0');
    await press(t, LogicalKeyboardKey.keyM);
    expect(e.commands.last, 'volume 0.95');
    await t.pump(const Duration(seconds: 1));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the mouse wheel changes the volume', (t) async {
    final (e, _, _) = await openDesktop(t, movie());
    final wheel = TestPointer(1, PointerDeviceKind.mouse);
    await t.sendEventToBinding(wheel.hover(const Offset(300, 250)));
    await t.sendEventToBinding(wheel.scroll(const Offset(0, 120)));
    await t.pump();
    expect(e.commands.last, 'volume 0.95', reason: 'wheel down lowers it');
    await t.sendEventToBinding(wheel.scroll(const Offset(0, -240)));
    await t.pump();
    expect(e.commands.last, 'volume 1.0', reason: 'wheel up raises it, capped at 1');
    await t.pump(const Duration(seconds: 1));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('F toggles full screen, Esc leaves it first and then closes the player', (t) async {
    final (_, h, s) = await openDesktop(t, movie());
    await press(t, LogicalKeyboardKey.keyF);
    expect(s.fullscreens, [true]);
    await press(t, LogicalKeyboardKey.escape);
    expect(s.fullscreens, [true, false]);
    expect(h.closed, 0, reason: 'the first Esc only left full screen');
    await press(t, LogicalKeyboardKey.escape);
    expect(h.closed, 1);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a click pauses and a double click fills the screen', (t) async {
    final (e, _, s) = await openDesktop(t, movie());
    await t.tapAt(const Offset(300, 250));
    await t.pump(const Duration(milliseconds: 400));
    expect(e.commands, contains('pause'));
    await t.tapAt(const Offset(300, 250));
    await t.pump(const Duration(milliseconds: 50));
    await t.tapAt(const Offset(300, 250));
    await t.pump(const Duration(milliseconds: 400));
    expect(s.fullscreens, [true]);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('on a live channel Left and Right do nothing and Page Up zaps', (t) async {
    final (e, h, _) = await openDesktop(t, live());
    await press(t, LogicalKeyboardKey.arrowRight);
    expect(e.commands.any((c) => c.startsWith('seek')), isFalse);
    h.zapTo = live('Next');
    await press(t, LogicalKeyboardKey.pageUp);
    expect(e.loads.last.$1, contains('Next'));
    await t.pumpWidget(const SizedBox());
  });
}
