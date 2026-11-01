import 'package:iptvmac/core/models.dart';
import 'package:iptvmac/core/series_prefs.dart';
import 'package:iptvmac/core/skip_marks.dart';

/// What to play: the contract between the app shell (lib/app, lib/ui) and the player (lib/player).
/// The shell builds one and pushes `PlayerScreen(request:, host:)`; the player never touches the database or the network
/// layer of the library itself, it only talks to the [PlayerHost] below.
class PlayRequest {
  const PlayRequest({required this.title, required this.url, required this.isLive, this.start = 0, this.item, this.subtitle});

  final String title;
  final Uri url;
  final bool isLive;

  /// Seconds to start at (resume position); 0 for live.
  final double start;

  /// The library item this is (favorites star, guide, zapping); null for ad-hoc streams (the debug launcher, a pasted link).
  final Item? item;

  /// A second line under the title: the episode name, or the programme on now (the host may refine it with [PlayerHost.liveProgramme]).
  final String? subtitle;
}

/// What the player needs from the app. The shell implements it on top of the library model (database, favorites, queues).
abstract class PlayerHost {
  /// Called about every 20 s while a movie or episode plays, and when the player closes (position and duration in seconds).
  /// Never called for live streams or while the position is still 0 (nothing played yet).
  void saveProgress(PlayRequest request, double position, double duration);

  bool isFavorite(Item item);
  Future<void> toggleFavorite(Item item);

  /// Whether the provider has details to show for [item] (a movie or series of an Xtream source; an episode's item is its series).
  bool hasDetails(Item item);

  /// Opens those details over the player; the playback goes on underneath.
  void showDetails(Item item);

  /// Live zapping in the list the user came from: -1 previous, +1 next. Null when there is none.
  PlayRequest? zap(PlayRequest current, int step);

  /// The next episode of the series the current request belongs to, or null.
  PlayRequest? nextEpisode(PlayRequest current);

  /// The programme on now for a live channel (EPG), or null.
  String? liveProgramme(PlayRequest request);

  /// The marks of the series that [request] (an episode) belongs to: where its intro and credits are (empty until the user marks them).
  /// Null for anything that is not an episode: there is nothing to skip and the skip menu is not shown.
  SkipMarks? skipMarks(PlayRequest request) => null;

  /// Keeps the marks of that series (empty marks forget them).
  void saveSkipMarks(PlayRequest request, SkipMarks marks) {}

  /// The speed and subtitle language the user kept for the series that [request] (an episode) belongs to, so its next episodes start the
  /// same way. Null for anything that is not an episode.
  SeriesPrefs? seriesPrefs(PlayRequest request) => null;

  /// Keeps those choices (empty ones forget them).
  void saveSeriesPrefs(PlayRequest request, SeriesPrefs prefs) {}

  /// The user closed the player (back button / close): the shell pops the screen.
  void closePlayer();
}
