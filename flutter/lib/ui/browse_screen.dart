import 'package:flutter/material.dart';
import 'package:iptvmac/app/device.dart';
import 'package:iptvmac/app/library_model.dart';
import 'package:iptvmac/app/watch_progress.dart';
import 'package:iptvmac/core/models.dart';
import 'package:iptvmac/l10n/app_localizations.dart';
import 'package:iptvmac/ui/category_index.dart';
import 'package:iptvmac/ui/item_views.dart';
import 'package:iptvmac/ui/tv.dart';
import 'package:iptvmac/ui/widgets.dart';
import 'package:provider/provider.dart';

String sectionTitle(AppLocalizations l, ItemType t) => switch (t) { ItemType.live => l.tabLive, ItemType.movie => l.tabMovies, ItemType.series => l.tabSeries };

IconData sectionIcon(ItemType t) => switch (t) { ItemType.live => Icons.live_tv_outlined, ItemType.movie => Icons.movie_outlined, ItemType.series => Icons.video_library_outlined };

/// One of Live / Movies / Series: search with scopes, category chips, then the list or the poster grid.
class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key, required this.type});
  final ItemType type;

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final _pulling = ValueNotifier(false); // a pull to refresh is running: its spinner is the progress, so the strip stays away

  @override
  void dispose() {
    _pulling.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final searching = context.select<LibraryModel, bool>((m) => m.searchText.isNotEmpty);
    final index = context.select<LibraryModel, bool>((m) => m.showCategoryIndex) && !searching;
    return Scaffold(
      appBar: AppBar(title: Text(sectionTitle(l, widget.type)), actions: const [PlaylistMenu()]),
      body: Column(children: [
        const UpdateBanner(),
        ValueListenableBuilder<bool>(valueListenable: _pulling, builder: (_, p, _) => p ? const SizedBox.shrink() : const StatusStrip()),
        const SearchField(),
        if (searching) const ScopeChips() else if (!index) CategoryChips(type: widget.type),
        Expanded(child: index ? CategoryIndex(type: widget.type) : ResultsView(type: widget.type, pulling: _pulling)),
      ]),
    );
  }
}

/// Playlist switcher (only with more than one source) and a refresh.
class PlaylistMenu extends StatelessWidget {
  const PlaylistMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<LibraryModel>();
    final l = AppLocalizations.of(context);
    if (m.accounts.length > 1) {
      return PopupMenuButton<Object>(
        tooltip: l.playlistLabel,
        icon: Icon(m.allPlaylists ? Icons.layers : Icons.layers_outlined),
        onSelected: (v) => v is Account ? m.selectPlaylist(v) : v == 'refresh' ? m.sync() : m.selectPlaylist(null),
        itemBuilder: (_) => [
          CheckedPopupMenuItem<Object>(value: 'all', checked: m.allPlaylists, child: Text(l.playlistAll)),
          for (final a in m.accounts) CheckedPopupMenuItem<Object>(value: a, checked: !m.allPlaylists && m.account?.id == a.id, child: Text(a.name)),
          const PopupMenuDivider(),
          PopupMenuItem<Object>(value: 'refresh', enabled: !m.syncing, child: Text(l.syncNow)),
        ],
      );
    }
    if (isTelevision || MediaQuery.sizeOf(context).width >= 600) {
      return IconButton(onPressed: m.syncing ? null : m.sync, icon: const Icon(Icons.refresh), tooltip: l.syncNow);
    }
    return const SizedBox.shrink();
  }
}

class SearchField extends StatefulWidget {
  const SearchField({super.key});
  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late final LibraryModel _model = context.read<LibraryModel>();

  @override
  void initState() {
    super.initState();
    _controller.text = _model.searchText;
    _model.addListener(_fromModel);
    _focus.addListener(() => setState(() {}));
  }

  void _fromModel() {
    if (_controller.text != _model.searchText) _controller.text = _model.searchText; // a tab or playlist change clears it
  }

  @override
  void dispose() {
    _model.removeListener(_fromModel);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TvEditable(
        focusNode: _focus,
        builder: (_, node, readOnly, done) => TextField(
            controller: _controller,
            focusNode: node,
            readOnly: readOnly,
            textInputAction: TextInputAction.search,
            onChanged: _model.setSearchText,
            onSubmitted: (t) {
              done();
              _model.prefs.addRecent(t);
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: l.searchPrompt,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: MaterialLocalizations.of(context).clearButtonTooltip,
                      onPressed: () {
                        _controller.clear();
                        _model.setSearchText('');
                      }),
              isDense: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              fillColor: cs.surfaceContainerHigh,
            ),
        ),
      ),
    );
  }
}

class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, required this.selected, required this.onTap, this.icon});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Theme.of(context).colorScheme.onSurface;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: icon == null ? null : Icon(icon, size: 16, color: color),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w500),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

class ScopeChips extends StatelessWidget {
  const ScopeChips({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<LibraryModel>();
    final l = AppLocalizations.of(context);
    final names = {SearchScope.category: l.scopeCategory, SearchScope.type: l.scopeType, SearchScope.everywhere: l.scopeEverywhere};
    return SizedBox(
      width: double.infinity, // a Column would centre the wrapped chips
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(spacing: 8, children: [for (final s in SearchScope.values) AppChip(label: names[s]!, selected: m.scope == s, onTap: () => m.setScope(s))]),
      ),
    );
  }
}

class CategoryChips extends StatefulWidget {
  const CategoryChips({super.key, required this.type});
  final ItemType type;
  @override
  State<CategoryChips> createState() => _CategoryChipsState();
}

class _CategoryChipsState extends State<CategoryChips> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<LibraryModel>();
    final l = AppLocalizations.of(context);
    final selected = m.categories.where((c) => m.categoryTag(c) == m.selectedCategory).firstOrNull;
    final chips = <Widget>[
      AppChip(label: l.catAll, selected: m.selectedCategory == '__all', onTap: () => m.selectCategory('__all')),
      AppChip(label: l.catFavorites, icon: Icons.star_rounded, selected: m.selectedCategory == '__fav', onTap: () => m.selectCategory('__fav')),
      if (widget.type != ItemType.live) AppChip(label: l.catContinue, icon: Icons.schedule, selected: m.selectedCategory == '__hist', onTap: () => m.selectCategory('__hist')),
      if (selected != null) AppChip(label: selected.name, selected: true, onTap: () {}), // the choice stays in sight
      for (final c in m.categories.take(24)) if (c.id != selected?.id) AppChip(label: c.name, selected: false, onTap: () => m.selectCategory(m.categoryTag(c))),
    ];
    return SizedBox(
      height: 52,
      child: Row(children: [
        IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: l.catTitle,
            onPressed: () {
              tvExpectEntry(); // the front page that replaces the chips takes focus
              m.openCategoryIndex();
            }),
        Expanded(
          child: ListView(
            controller: _scroll,
            scrollCacheExtent: tvCache(1200), // the remote can only move to chips that are built
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(end: 16),
            children: [for (final c in chips) Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: Center(child: c))],
          ),
        ),
      ]),
    );
  }
}

class ResultsView extends StatelessWidget {
  const ResultsView({super.key, required this.type, required this.pulling});
  final ItemType type;
  final ValueNotifier<bool> pulling;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<LibraryModel>();
    final l = AppLocalizations.of(context);
    final results = m.results;
    final everywhere = m.scope == SearchScope.everywhere && m.searchText.isNotEmpty;
    final Widget body;
    if (results.isEmpty) {
      body = m.syncing ? Skeleton(posters: type != ItemType.live) : _empty(context, m, l);
    } else {
      final shelf = m.selectedCategory == '__all' && m.searchText.isEmpty ? m.continueEntries(type) : const <ContinueEntry>[];
      body = CustomScrollView(
        scrollCacheExtent: tvCache(1500), // the remote can only move to rows and cells that are built
        // The offset is kept per section and category: coming back from the player (which rotates the phone, so the shell
        // switches between the bottom bar and the rail and rebuilds this screen) or from another tab lands on the same row.
        key: PageStorageKey<String>('results-${type.name}-${m.selectedCategory}-${m.searchText.isEmpty}'),
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          if (everywhere)
            for (final t in ItemType.values) ..._group(context, l, t, [for (final i in results) if (i.type == t) i])
          else if (type == ItemType.live)
            ChannelListSliver(items: results, autofocus: true)
          else ...[
            if (shelf.isNotEmpty) SliverPadding(padding: const EdgeInsets.only(top: 12, bottom: 20), sliver: SliverToBoxAdapter(child: ContinueShelf(entries: shelf, autofocus: true))),
            if (shelf.isEmpty) const SliverToBoxAdapter(child: SizedBox(height: 12)),
            PosterGridSliver(items: results, autofocus: shelf.isEmpty),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        pulling.value = true;
        await m.sync();
        pulling.value = false;
      },
      child: body,
    );
  }

  Widget _empty(BuildContext context, LibraryModel m, AppLocalizations l) {
    if (m.searchText.isNotEmpty) return EmptyState(icon: Icons.search_off, title: l.emptyResults);
    if (m.selectedCategory == '__fav') {
      return EmptyState(
          icon: Icons.star_outline_rounded,
          title: l.emptyFavorites,
          hint: type == ItemType.live ? l.emptyFavoritesLive : l.emptyFavoritesHint,
          actionLabel: l.catAll,
          onAction: () => m.selectCategory('__all'));
    }
    if (m.selectedCategory == '__hist') {
      return EmptyState(icon: Icons.schedule, title: l.emptyContinue, hint: l.emptyContinueHint, actionLabel: l.catAll, onAction: () => m.selectCategory('__all'));
    }
    return EmptyState(icon: sectionIcon(type), title: l.emptyNone, hint: l.emptyNoneHint, actionLabel: l.syncNow, onAction: m.sync);
  }

  List<Widget> _group(BuildContext context, AppLocalizations l, ItemType t, List<Item> items) {
    if (items.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(sectionTitle(l, t), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        ),
      ),
      if (t == ItemType.live) ChannelListSliver(items: items) else PosterGridSliver(items: items),
    ];
  }
}

/// Grey shapes where the first sync has not delivered anything yet.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, required this.posters});
  final bool posters;

  @override
  Widget build(BuildContext context) {
    final fill = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07);
    Widget box(double? w, double h, [double r = 4]) => Container(width: w, height: h, decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(r)));
    return ExcludeSemantics(
      child: posters
          ? GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              padding: const EdgeInsets.all(16),
              mainAxisSpacing: 18,
              crossAxisSpacing: 12,
              childAspectRatio: 0.55,
              children: [for (var i = 0; i < 12; i++) Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: box(null, 0, 10)), const SizedBox(height: 8), box(null, 10), const SizedBox(height: 6), box(60, 10)])],
            )
          : Column(children: [
              for (var i = 0; i < 9; i++)
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(children: [box(52, 52, 12), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [box(170, 12), const SizedBox(height: 8), box(110, 10)])])),
            ]),
    );
  }
}
