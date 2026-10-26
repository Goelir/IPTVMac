import 'package:flutter/material.dart';
import 'package:iptvmac/ui/tv.dart';
import 'package:iptvmac/app/library_model.dart';
import 'package:iptvmac/core/models.dart';
import 'package:iptvmac/downloads/downloads_model.dart';
import 'package:iptvmac/l10n/app_localizations.dart';
import 'package:iptvmac/ui/browse_screen.dart';
import 'package:iptvmac/ui/downloads_screen.dart';
import 'package:iptvmac/ui/item_views.dart';
import 'package:iptvmac/ui/widgets.dart';
import 'package:provider/provider.dart';

/// What belongs to you: what you started watching, and your favorites by type.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<LibraryModel>();
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final shelf = [...m.continueMovies, ...m.continueSeries];
    final groups = [for (final type in ItemType.values) (type, m.favoriteItems[type] ?? const <Item>[])].where((g) => g.$2.isNotEmpty).toList();
    final heading = t.titleMedium?.copyWith(fontWeight: FontWeight.w600);
    return Scaffold(
      appBar: AppBar(title: Text(l.tabLibrary), actions: [if (context.watch<DownloadsModel>().enabled) const _DownloadsAction(), const PlaylistMenu()]),
      body: RefreshIndicator(
        onRefresh: m.sync,
        child: shelf.isEmpty && groups.isEmpty
            ? EmptyState(icon: Icons.video_library_outlined, title: l.libraryEmpty, hint: l.libraryEmptyHint)
            : CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), scrollCacheExtent: tvCache(1500), slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                if (shelf.isNotEmpty) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(bottom: 20), child: ContinueShelf(entries: shelf, autofocus: true))),
                if (groups.isNotEmpty) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 4), child: Text(l.catFavorites, style: heading))),
                for (final (g, (type, items)) in groups.indexed) ...[
                  SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: Text(sectionTitle(l, type), style: t.titleSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)))),
                  if (type == ItemType.live) ChannelListSliver(items: items, autofocus: g == 0 && shelf.isEmpty) else PosterGridSliver(items: items, autofocus: g == 0 && shelf.isEmpty),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ]),
      ),
    );
  }
}

/// The way to the Downloads screen, with a count of what is running.
class _DownloadsAction extends StatelessWidget {
  const _DownloadsAction();

  @override
  Widget build(BuildContext context) {
    final running = context.select<DownloadsModel, int>((d) => d.activeCount);
    return IconButton(
      key: const Key('downloads-action'),
      tooltip: AppLocalizations.of(context).downloadsTitle,
      icon: Badge(isLabelVisible: running > 0, label: Text('$running'), child: const Icon(Icons.arrow_circle_down_outlined)),
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DownloadsScreen())),
    );
  }
}
