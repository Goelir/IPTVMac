import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptvmac/core/skip_marks.dart';
import 'package:iptvmac/l10n/app_localizations_en.dart';
import 'package:iptvmac/player/play_request.dart';

import 'fake_engine.dart';
import 'player_screen_test.dart' show FakeHost, movie, open, playing;

/// The skip buttons of an episode: they appear where the marks of the series say, jump, and can be marked from the menu.
/// Host tests only: no real player or provider was used.
final _l = AppLocalizationsEn();

Future<(FakeEngine, FakeHost)> episode(WidgetTester t, SkipMarks marks, {double position = 5, double duration = 1500, PlayRequest? next}) async {
  final h = FakeHost()
    ..marks = marks
    ..next = next;
  final (e, _, _) = await open(t, movie('Show'), host: h);
  playing(e, position: position, duration: duration);
  await t.pump(const Duration(milliseconds: 300));
  e.commands.clear();
  return (e, h);
}

void main() {
  testWidgets('"Skip intro" shows inside the intro and a press jumps to its end', (t) async {
    final (e, _) = await episode(t, const SkipMarks(introStart: 0, introEnd: 90), position: 10);
    expect(find.text(_l.playerSkipIntro), findsOneWidget);
    await t.tap(find.text(_l.playerSkipIntro));
    await t.pump(const Duration(milliseconds: 100));
    expect(e.commands, contains('seekTo 90.0'));
    e.position = 100; // past the intro: the button goes away
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text(_l.playerSkipIntro), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a movie or a series without marks has no button and no menu', (t) async {
    final h = FakeHost(); // marks null: not an episode
    final (e, _, _) = await open(t, movie(), host: h);
    playing(e, position: 10);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text(_l.playerSkipIntro), findsNothing);
    expect(find.byIcon(Icons.skip_next_outlined), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('"Skip credits" starts the next episode when there is one', (t) async {
    final nextEp = PlayRequest(title: 'Show', url: Uri.parse('http://x/next.mp4'), isLive: false, subtitle: 'Episode 2');
    final (e, _) = await episode(t, const SkipMarks(creditsLen: 80), position: 1430, next: nextEp);
    expect(find.text(_l.playerSkipCredits), findsOneWidget);
    await t.tap(find.text(_l.playerSkipCredits));
    await t.pump(const Duration(milliseconds: 100));
    expect(e.loads.last.$1, 'http://x/next.mp4');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('"Skip credits" on the last episode goes to the end of the file', (t) async {
    final (e, _) = await episode(t, const SkipMarks(creditsLen: 80), position: 1430);
    await t.tap(find.text(_l.playerSkipCredits));
    await t.pump(const Duration(milliseconds: 100));
    expect(e.commands, contains('seekTo 1499.0'));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('marking from the menu saves the marks of the series and shows the message', (t) async {
    final (_, h) = await episode(t, const SkipMarks(), position: 95);
    await t.tap(find.byIcon(Icons.skip_next_outlined));
    await t.pumpAndSettle();
    await t.tap(find.text(_l.playerMarkIntroEnd));
    await t.pump(const Duration(milliseconds: 100));
    expect(h.savedMarks.last.introEnd, 95);
    expect(find.text(_l.playerSkipSaved), findsOneWidget);
    await t.pump(const Duration(seconds: 4)); // the message goes away by itself
    expect(find.text(_l.playerSkipSaved), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a mark that makes no sense is refused and nothing is saved', (t) async {
    final (_, h) = await episode(t, const SkipMarks(), position: 95); // credits cannot start in the first half
    await t.tap(find.byIcon(Icons.skip_next_outlined));
    await t.pumpAndSettle();
    await t.tap(find.text(_l.playerMarkCredits));
    await t.pump(const Duration(milliseconds: 100));
    expect(h.savedMarks, isEmpty);
    expect(find.text(_l.playerSkipRefused), findsOneWidget);
    await t.pump(const Duration(seconds: 4));
    await t.pumpWidget(const SizedBox());
  });
}
