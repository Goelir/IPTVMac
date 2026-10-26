import 'package:flutter/material.dart';
import 'package:iptvmac/app/device.dart';
import 'package:iptvmac/app/library_model.dart';
import 'package:iptvmac/app/sync_worker.dart';
import 'package:iptvmac/core/item_info.dart';
import 'package:iptvmac/core/models.dart';
import 'package:iptvmac/downloads/download_entry.dart';
import 'package:iptvmac/downloads/library_downloads.dart';
import 'package:iptvmac/l10n/app_localizations.dart';
import 'package:iptvmac/ui/artwork.dart';
import 'package:iptvmac/ui/download_button.dart';
import 'package:iptvmac/ui/info_parts.dart';
import 'package:iptvmac/ui/item_views.dart';
import 'package:iptvmac/ui/play.dart';
import 'package:iptvmac/ui/widgets.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// The details of a movie in a bottom sheet: poster, facts, Play and the favorite star. [playing]: opened from the player, where
/// "Play" would only restart what is already playing, so it is left out.
Future<void> showItemDetails(BuildContext context, Item item, {bool playing = false}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => DetailsSheet(item: item, playing: playing),
    );

Future<void> openTrailer(Uri url) => launchUrl(url, mode: LaunchMode.externalApplication);

class DetailsSheet extends StatefulWidget {
  const DetailsSheet({super.key, required this.item, this.playing = false});
  final Item item;
  final bool playing;
  @override
  State<DetailsSheet> createState() => _DetailsSheetState();
}

enum _Phase { loading, loaded, failed, unavailable }

class _DetailsSheetState extends State<DetailsSheet> {
  var _phase = _Phase.loading;
  ItemInfo? _info;
  String _error = '';
  var _attempt = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = context.read<LibraryModel>();
    final item = widget.item;
    if (!m.hasInfo(item)) {
      setState(() => _phase = _Phase.unavailable);
      return;
    }
    final cached = _attempt == 0 ? m.cachedInfo(item) : null;
    setState(() {
      _info = cached ?? _info;
      _phase = cached != null ? _Phase.loaded : _Phase.loading;
    });
    try {
      final i = await m.loadInfo(item, refresh: _attempt > 0);
      if (!mounted) return;
      setState(() {
        _info = i;
        _phase = _Phase.loaded;
      });
    } catch (e) {
      if (!mounted || _info != null) return;
      setState(() {
        _error = describeError(e);
        _phase = _Phase.failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<LibraryModel>();
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final item = widget.item;
    final info = _info;
    final fav = m.isFavorite(item);
    final resumable = m.progress(item) > 0;
    final nav = Navigator.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        HeaderStack(
          poster: SizedBox(width: 112, child: PosterImage(name: item.name, url: artUri(item.icon) ?? info?.posterURL, maxPixel: 480)),
          text: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(header: true, child: Text(item.name, style: t.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
            if (info?.title != null && info!.title!.toLowerCase() != item.name.toLowerCase())
              Text(info.title!, style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            if (info != null && InfoMetaLine.hasAny(info)) InfoMetaLine(info: info),
            const SizedBox(height: 6),
            PlaylistBadge(item: item),
          ]),
        ),
        const SizedBox(height: 20),
        Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (!widget.playing)
            FilledButton.icon(
              autofocus: isTelevision,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(resumable ? l.infoResume : l.infoPlay),
              style: FilledButton.styleFrom(minimumSize: const Size(140, 48)),
              onPressed: () {
                final navContext = nav.context; // the sheet's own context is gone once it is popped
                nav.pop();
                playItem(navContext, item);
              },
            ),
          if (info?.trailerURL != null) IconButton.filledTonal(icon: const Icon(Icons.smart_display_outlined), tooltip: l.infoTrailer, onPressed: () => openTrailer(info!.trailerURL!)),
          if (m.canDownload(item))
            DownloadButton(tonal: true, entryKey: DownloadEntry.keyOf(item.accountId, item.type, item.streamId, null), start: (d) => m.downloadMovie(d, item)),
          FavoriteButton(favorite: fav, tonal: true, autofocus: isTelevision && widget.playing, onPressed: () => m.toggleFavorite(item)),
        ]),
        const SizedBox(height: 20),
        switch (_phase) {
          _Phase.unavailable => const SizedBox.shrink(),
          _Phase.loading => Semantics(
              label: l.infoLoading,
              child: Row(children: [const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)), const SizedBox(width: 12), Text(l.infoLoading)]),
            ),
          _Phase.failed => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error), const SizedBox(width: 8), Expanded(child: Text(l.infoError))]),
              const SizedBox(height: 4),
              Text(_error, style: t.bodySmall),
              const SizedBox(height: 8),
              OutlinedButton(
                  onPressed: () {
                    _attempt++;
                    _load();
                  },
                  child: Text(l.playerRetry)),
            ]),
          _Phase.loaded => info != null && info.hasContent
              ? InfoFacts(info: info)
              : Row(children: [const Icon(Icons.info_outline), const SizedBox(width: 8), Expanded(child: Text(l.infoEmpty))]),
        },
      ]),
    );
  }
}
