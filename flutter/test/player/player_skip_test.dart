import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptvmac/core/series_prefs.dart';
import 'package:iptvmac/core/skip_marks.dart';
import 'package:iptvmac/l10n/app_localizations_en.dart';
import 'package:iptvmac/player/play_request.dart';
import 'package:iptvmac/player/track_label.dart';

import 'fake_engine.dart';
import 'player_screen_test.dart' show FakeHost, item, movie, open, playing;

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
  seriesPrefsTests();
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

// ---- the speed and the subtitle language kept for a series ----

Future<(FakeEngine, FakeHost)> seriesEpisode(WidgetTester t, SeriesPrefs prefs, {PlayRequest? next}) async {
  final h = FakeHost()
    ..prefs = prefs
    ..next = next;
  final (e, _, _) = await open(t, movie('Show'), host: h);
  return (e, h);
}

void seriesPrefsTests() {
  testWidgets('an episode starts at the speed kept for its series', (t) async {
    final (e, _) = await seriesEpisode(t, const SeriesPrefs(speed: 1.5));
    expect(e.commands, contains('speed 1.5'));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a speed the user picks is kept for the next episodes, and 1x forgets it', (t) async {
    final (e, h) = await seriesEpisode(t, const SeriesPrefs());
    playing(e);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('1×'));
    await t.pumpAndSettle();
    await t.tap(find.text('2×').last);
    await t.pump();
    expect(h.savedPrefs.last.speed, 2);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the next episode keeps the speed', (t) async {
    final nextEp = PlayRequest(title: 'Show', url: Uri.parse('http://x/next.mp4'), isLive: false, subtitle: 'Episode 2', item: item('Show'));
    final h = FakeHost()
      ..prefs = const SeriesPrefs(speed: 1.25)
      ..marks = const SkipMarks(creditsLen: 50)
      ..next = nextEp;
    final (e, _, _) = await open(t, movie('Show'), host: h);
    playing(e, position: 560, duration: 600);
    await t.pump(const Duration(milliseconds: 300));
    e.commands.clear();
    await t.tap(find.text(_l.playerSkipCredits)); // the next episode starts; it asks the host for the series' choices again
    await t.pump(const Duration(milliseconds: 200));
    expect(e.loads.last.$1, 'http://x/next.mp4');
    expect(e.commands, contains('speed 1.25'));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the saved subtitle language is chosen when the tracks arrive, once', (t) async {
    final (e, _) = await seriesEpisode(t, const SeriesPrefs(subtitle: SubtitleLanguage('heb')));
    e.tracks = const [Track(id: 1, type: 'sub', lang: 'eng'), Track(id: 2, type: 'sub', lang: 'heb')];
    playing(e);
    await t.pump(const Duration(seconds: 5));
    expect(e.commands.where((c) => c.startsWith('sub ')), ['sub 2']);
    await t.pump(const Duration(seconds: 5));
    expect(e.commands.where((c) => c.startsWith('sub ')), ['sub 2']); // not again
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a subtitle the user picks is kept for the series', (t) async {
    final (e, h) = await seriesEpisode(t, const SeriesPrefs());
    e.tracks = const [Track(id: 1, type: 'sub', lang: 'eng'), Track(id: 2, type: 'sub', lang: 'heb')];
    playing(e);
    await t.pump(const Duration(seconds: 5));
    await t.tapAt(const Offset(450, 210)); // the controls hid meanwhile: a tap brings them back
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byIcon(Icons.closed_caption_outlined));
    await t.pumpAndSettle();
    await t.tap(find.textContaining(RegExp('Hebrew|heb')).first);
    await t.pump();
    expect(h.savedPrefs.last.subtitle, const SubtitleLanguage('heb'));
    await t.pumpWidget(const SizedBox());
  });
}
