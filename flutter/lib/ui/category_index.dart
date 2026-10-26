import 'package:flutter/material.dart';
import 'package:iptvmac/app/device.dart';
import 'package:iptvmac/app/library_model.dart';
import 'package:iptvmac/core/models.dart';
import 'package:iptvmac/l10n/app_localizations.dart';
import 'package:iptvmac/ui/tv.dart';
import 'package:provider/provider.dart';

/// The front page of a section: "All channels/movies/series", favorites, continue watching, then every category (grouped by
/// playlist in All mode) with its item count and a field to filter them.
class CategoryIndex extends StatefulWidget {
  const CategoryIndex({super.key, required this.type});
  final ItemType type;
  @override
  State<CategoryIndex> createState() => _CategoryIndexState();
}

class _CategoryIndexState extends State<CategoryIndex> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final m = context.watch<LibraryModel>();
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final q = _query.toLowerCase();
    final cats = [for (final c in m.categories) if (q.isEmpty || c.name.toLowerCase().contains(q)) c];
    final allLabel = switch (widget.type) { ItemType.live => l.catAllLive, ItemType.movie => l.catAllMovies, ItemType.series => l.catAllSeries };

    Widget row(String tag, String title, {IconData? icon, int? count, bool first = false}) {
      final tile = ListTile(
          autofocus: isTelevision && first,
          leading: icon == null ? null : Icon(icon, color: scheme.primary),
          title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: count == null ? null : Text('$count', style: Theme.of(context).textTheme.bodySmall),
          onTap: () {
            tvExpectEntry();
            m.selectCategory(tag);
          },
        );
      return isTelevision && first ? TvEntry(child: tile) : tile;
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: TvEditable(
          builder: (_, node, readOnly, done) => TextField(
            focusNode: node,
            readOnly: readOnly,
            decoration: InputDecoration(hintText: l.catFilter, prefixIcon: const Icon(Icons.filter_list)),
            onChanged: (v) => setState(() => _query = v),
            onSubmitted: (_) => done(),
          ),
        ),
      ),
      Expanded(
        child: ListView(children: [
          if (q.isEmpty) ...[
            row('__all', allLabel, icon: Icons.grid_view, first: true),
            row('__fav', l.catFavorites, icon: Icons.star_outline_rounded),
            if (widget.type != ItemType.live) row('__hist', l.catContinue, icon: Icons.schedule),
            const Divider(),
          ],
          if (m.allPlaylists)
            for (final a in m.accounts) ...[
              if (cats.any((c) => c.accountId == a.id))
                Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text(a.name, style: Theme.of(context).textTheme.labelLarge)),
              for (final c in cats.where((c) => c.accountId == a.id)) row(m.categoryTag(c), c.name, count: m.categoryCounts[m.categoryTag(c)]),
            ]
          else
            for (final c in cats) row(m.categoryTag(c), c.name, count: m.categoryCounts[m.categoryTag(c)]),
        ]),
      ),
    ]);
  }
}
