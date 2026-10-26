import 'package:flutter/material.dart';
import 'package:iptvmac/app/device.dart';
import 'package:iptvmac/ui/bidi.dart';
import 'package:iptvmac/app/library_model.dart';
import 'package:iptvmac/app/sync_worker.dart';
import 'package:iptvmac/app/watch_progress.dart';
import 'package:iptvmac/core/item_info.dart';
import 'package:iptvmac/core/models.dart';
import 'package:iptvmac/downloads/download_entry.dart';
import 'package:iptvmac/downloads/downloads_model.dart';
import 'package:iptvmac/downloads/library_downloads.dart';
import 'package:iptvmac/l10n/app_localizations.dart';
import 'package:iptvmac/ui/artwork.dart';
import 'package:iptvmac/ui/browse_screen.dart';
import 'package:iptvmac/ui/download_button.dart';
import 'package:iptvmac/ui/missing_strings.dart';
import 'package:iptvmac/ui/details_sheet.dart';
import 'package:iptvmac/ui/info_parts.dart';
import 'package:iptvmac/ui/item_views.dart';
import 'package:iptvmac/ui/play.dart';
import 'package:iptvmac/ui/tv.dart';
import 'package:iptvmac/ui/widgets.dart';
import 'package:provider/provider.dart';

/// A series: cover, facts, what to watch next, and the episodes by season with how far each one is.
class SeriesScreen extends StatefulWidget {
  const SeriesScreen({super.key, required this.series});
  final Item series;
  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  List<Episode> _episodes = [];
  Map<String, EpisodeProgress> _progress = {};
  ItemInfo? _info;
  var _loading = true;
  String? _error;
  var _season = 1;

  Item get series => widget.series;
  List<int> get _seasons => ({for (final e in _episodes) e.season}.toList()..sort());
  ({Episode episode, bool resume})? get _upNext => WatchProgress.upNext(_episodes, _progress);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = context.read<LibraryModel>();
    setState(() {
      _loading = true;
      _error = null;
      _info = m.cachedInfo(series); // from an earlier visit; the episodes request below refreshes it for free
    });
    try {
      final eps = await m.loadEpisodes(series);
      if (!mounted) return;
      _episodes = eps;
      _progress = m.episodeProgress(series);
      _season = _upNext?.episode.season ?? _seasons.firstOrNull ?? 1;
    } catch (e) {
      if (mounted) _error = describeError(e);
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _info = m.cachedInfo(series) ?? _info;
    });
  }

  Future<void> _play(Episode e) async {
    final m = context.read<LibraryModel>();
    final r = m.episodeRequest(e, series);
    if (r == null) return;
    await openPlayer(context, r);
    if (mounted) setState(() => _progress = m.episodeProgress(series)); // the resume points moved while watching
  }

  Future<void> _downloadSeason(List<Episode> episodes) async {
    final m = context.read<LibraryModel>(), d = context.read<DownloadsModel>();
    final messenger = ScaffoldMessenger.of(context);
    for (final e in episodes) {
      if (await m.downloadEpisode(d, series, e) == AddResult.noUrl) return; // no password: the dialog is up, asking once is enough
    }
    messenger.showSnackBar(SnackBar(content: Text(Missing.downloadsAdded)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final body = <Widget>[_header(context)];
    if (_loading) {
      body.add(const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())));
    } else if (_error != null) {
      body.add(SizedBox(
        height: 260,
        child: EmptyState(icon: Icons.warning_amber_rounded, title: l.infoError, hint: _error, actionLabel: l.playerRetry, onAction: _load),
      ));
    } else if (_episodes.isEmpty) {
      body.add(SizedBox(height: 220, child: EmptyState(icon: Icons.video_library_outlined, title: l.seriesNoEpisodes)));
    } else {
      if (_seasons.length > 1) {
        body.add(SizedBox(
          height: 52,
          child: ListView(scrollCacheExtent: tvCache(1200), scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            for (final s in _seasons)
              Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: Center(child: AppChip(label: '${l.seriesSeason} $s', selected: _season == s, onTap: () => setState(() => _season = s)))),
          ]),
        ));
      }
      final eps = [for (final e in _episodes) if (e.season == _season) e]..sort((a, b) => a.number.compareTo(b.number));
      final saveable = [for (final e in eps) if (context.read<LibraryModel>().canDownloadEpisode(e)) e];
      if (saveable.isNotEmpty && context.watch<DownloadsModel>().enabled) {
        body.add(Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 8),
            child: TextButton.icon(key: const Key('download-season'), icon: const Icon(Icons.download_outlined), label: Text(l.downloadsSeason), onPressed: () => _downloadSeason(saveable)),
          ),
        ));
      }
      body.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.onSurface.withValues(alpha: 0.06))),
          child: Column(children: [for (final e in eps) _episodeRow(context, e)]),
        ),
      ));
    }
    return TvFrame(
      child: Scaffold(
        appBar: AppBar(title: Text(series.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
        body: ListView(scrollCacheExtent: tvCache(1500), children: body),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final m = context.watch<LibraryModel>();
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final info = _info, next = _upNext, fav = m.isFavorite(series);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        HeaderStack(
          poster: SizedBox(width: 100, child: PosterImage(name: series.name, url: artUri(series.icon) ?? info?.posterURL)),
          text: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(header: true, child: Text(series.name, style: t.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            if (info != null && InfoMetaLine.hasAny(info)) InfoMetaLine(info: info),
            PlaylistBadge(item: series),
          ]),
        ),
        if (info?.plot != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(info!.plot!, maxLines: 5, overflow: TextOverflow.ellipsis, style: t.bodyMedium)),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (next != null)
            FilledButton.icon(
              autofocus: isTelevision,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(next.resume ? l.seriesContinueEp(next.episode.season, next.episode.number) : l.seriesPlayEp(next.episode.season, next.episode.number)),
              style: FilledButton.styleFrom(minimumSize: const Size(140, 48)),
              onPressed: () => _play(next.episode),
            ),
          if (info?.trailerURL != null) IconButton.filledTonal(icon: const Icon(Icons.smart_display_outlined), tooltip: l.infoTrailer, onPressed: () => openTrailer(info!.trailerURL!)),
          FavoriteButton(favorite: fav, tonal: true, onPressed: () => m.toggleFavorite(series)),
        ]),
      ]),
    );
  }

  Widget _episodeRow(BuildContext context, Episode e) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final m = context.read<LibraryModel>();
    final p = _progress[e.streamId];
    final isNext = _upNext?.episode.streamId == e.streamId;
    return InkWell(
      onTap: () => _play(e),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
          child: Row(children: [
            SizedBox(width: 34, child: Text('${e.number}', textAlign: TextAlign.end, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant, fontFeatures: const [FontFeature.tabularFigures()]))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.title, textDirection: titleDirection(e.title), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (isNext) Text(l.nextTitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
                if (p != null && !p.isWatched && p.fraction > 0.01) Padding(padding: const EdgeInsets.only(top: 4), child: SizedBox(width: 140, child: ProgressBar(value: p.fraction, height: 3))),
              ]),
            ),
            if (m.canDownloadEpisode(e))
              DownloadButton(
                  entryKey: DownloadEntry.keyOf(series.accountId, series.type, series.streamId, e.streamId), start: (d) => m.downloadEpisode(d, series, e)),
            const SizedBox(width: 8),
            if (p?.isWatched == true) Icon(Icons.check_circle, color: cs.onSurfaceVariant, semanticLabel: l.seriesWatched) else Icon(Icons.play_arrow_rounded, size: 20, color: isNext ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.6)),
          ]),
        ),
      ),
    );
  }
}
