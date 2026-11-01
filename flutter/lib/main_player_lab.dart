// A launcher for the player without the app shell: a list of test streams and a FakeHost. Build and run:
//   flutter build apk --debug -t lib/main_player_lab.dart
// Own streams: --dart-define=LAB_URLS="Title|https://host/a.m3u8,Other|https://host/b.mp4" (a title ending in " (live)" plays as live).
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'core/models.dart';
import 'core/skip_marks.dart';
import 'l10n/app_localizations.dart';
import 'player/play_request.dart';
import 'player/player_screen.dart';

const _urls = String.fromEnvironment('LAB_URLS');
const _hls = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';
const _sintel = 'https://download.blender.org/durian/trailer/sintel_trailer-480p.mp4';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const LabApp());
}

class LabApp extends StatelessWidget {
  const LabApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Player lab',
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LabHome(),
      );
}

/// The lab's list: each entry is a [PlayRequest]; live entries zap among themselves, episodes chain to the next one.
List<PlayRequest> labRequests() {
  var n = 0;
  PlayRequest entry(String title, String url, {bool live = false, String? subtitle}) {
    final item = Item(accountId: 1, type: live ? ItemType.live : ItemType.movie, name: title, streamId: '${n++}');
    return PlayRequest(title: title, url: Uri.parse(url), isLive: live, item: item, subtitle: subtitle);
  }

  if (_urls.isNotEmpty) {
    return [
      for (final e in _urls.split(','))
        entry(e.contains('|') ? e.split('|').first.replaceAll(' (live)', '') : e, e.contains('|') ? e.split('|').last : e,
            live: e.contains('|') && e.split('|').first.endsWith(' (live)')),
    ];
  }
  return [
    entry('Sintel trailer (MP4)', _sintel, subtitle: 'Blender Foundation, CC-BY'),
    entry('Mux test stream (HLS)', _hls),
    entry('Channel A (HLS as live)', _hls, live: true),
    entry('Channel B (HLS as live)', _hls, live: true),
    entry('Episode 1 (ends in about a minute)', _sintel, subtitle: 'Season 1'),
    entry('Episode 2', _sintel, subtitle: 'Season 1'),
    entry('Broken link (error card)', 'https://example.invalid/none.m3u8'),
  ];
}

class FakeHost implements PlayerHost {
  FakeHost(this.context, this.list);
  final BuildContext context;
  final List<PlayRequest> list;
  final favorites = <String>{};
  final saved = <String, double>{};

  @override
  void saveProgress(PlayRequest request, double position, double duration) {
    saved[request.title] = position;
    debugPrint('LAB saveProgress ${request.title} ${position.toStringAsFixed(1)}/${duration.toStringAsFixed(1)}');
  }

  @override
  bool isFavorite(Item item) => favorites.contains(item.name);

  @override
  bool hasDetails(Item item) => false;

  @override
  void showDetails(Item item) {}

  @override
  Future<void> toggleFavorite(Item item) async => favorites.contains(item.name) ? favorites.remove(item.name) : favorites.add(item.name);

  @override
  SkipMarks? skipMarks(PlayRequest request) => null;

  @override
  void saveSkipMarks(PlayRequest request, SkipMarks marks) {}

  @override
  PlayRequest? zap(PlayRequest current, int step) {
    if (!current.isLive) return null;
    final live = list.where((r) => r.isLive).toList();
    final i = live.indexWhere((r) => r.title == current.title) + step;
    return i >= 0 && i < live.length ? live[i] : null;
  }

  @override
  PlayRequest? nextEpisode(PlayRequest current) {
    if (!current.title.startsWith('Episode')) return null;
    final i = list.indexWhere((r) => r.title == current.title) + 1;
    return i < list.length && list[i].title.startsWith('Episode') ? list[i] : null;
  }

  @override
  String? liveProgramme(PlayRequest request) => request.isLive ? 'News at ten' : null;

  @override
  void closePlayer() {
    debugPrint('LAB closePlayer');
    if (context.mounted) Navigator.of(context).pop(); // pop, not maybePop: the player route refuses system pops
  }
}

class LabHome extends StatelessWidget {
  const LabHome({super.key});

  @override
  Widget build(BuildContext context) {
    final list = labRequests();
    return Scaffold(
      appBar: AppBar(title: const Text('Player lab')),
      body: ListView(children: [
        for (final r in list)
          ListTile(
            leading: Icon(r.isLive ? Icons.live_tv : Icons.movie),
            title: Text(r.title),
            subtitle: Text(r.url.host),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => PlayerScreen(request: r, host: FakeHost(context, list)),
            )),
          ),
      ]),
    );
  }
}
