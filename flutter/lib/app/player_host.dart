import 'package:iptvmac/app/library_model.dart';
import 'package:iptvmac/app/watch_progress.dart';
import 'package:iptvmac/core/episode_queue.dart';
import 'package:iptvmac/core/models.dart';
import 'package:iptvmac/core/series_prefs.dart';
import 'package:iptvmac/core/skip_marks.dart';
import 'package:iptvmac/player/play_request.dart';

/// What the player may ask of the app (the contract in lib/player/play_request.dart) on top of [LibraryModel].
/// One host per player screen: [zapList] is the channel list the user picked the channel from (a category, favorites, a search).
class ShellPlayerHost implements PlayerHost {
  ShellPlayerHost(this.model, {this.zapList = const [], required this.onClose, this.onShowDetails});

  final LibraryModel model;
  final List<Item> zapList;

  /// Pops the player screen.
  final void Function() onClose;

  /// Shows an item's details sheet over the player (the UI layer owns the navigator); null where there is none.
  final void Function(Item item)? onShowDetails;

  @override
  void saveProgress(PlayRequest request, double position, double duration) => model.saveProgress(request, position, duration);

  @override
  bool isFavorite(Item item) => model.isFavorite(item);

  @override
  Future<void> toggleFavorite(Item item) => model.toggleFavorite(item);

  @override
  bool hasDetails(Item item) => onShowDetails != null && model.hasInfo(item);

  @override
  void showDetails(Item item) => onShowDetails?.call(item);

  @override
  PlayRequest? zap(PlayRequest current, int step) {
    final item = current.item;
    if (item == null || current.isLive == false) return null;
    final next = WatchProgress.zapNeighbor(item, zapList, step);
    return next == null ? null : model.requestFor(next);
  }

  @override
  PlayRequest? nextEpisode(PlayRequest current) {
    final series = current.item, episode = model.episodeOf(current);
    if (series == null || episode == null) return null;
    final next = EpisodeQueue.next(episode.streamId, model.cachedEpisodes(series));
    return next == null ? null : model.episodeRequest(next, series);
  }

  @override
  SkipMarks? skipMarks(PlayRequest request) => model.skipMarksOf(request);

  @override
  void saveSkipMarks(PlayRequest request, SkipMarks marks) => model.saveSkipMarks(request, marks);

  @override
  SeriesPrefs? seriesPrefs(PlayRequest request) => model.seriesPrefsOf(request);

  @override
  void saveSeriesPrefs(PlayRequest request, SeriesPrefs prefs) => model.saveSeriesPrefs(request, prefs);

  @override
  String? liveProgramme(PlayRequest request) {
    final item = request.item;
    if (item == null || !request.isLive) return null;
    model.loadEpgNow(item); // refreshes in the background (5 min); the next call sees it
    return model.epgTitle(item);
  }

  @override
  void closePlayer() {
    onClose();
    model.reloadContinue();
  }
}
