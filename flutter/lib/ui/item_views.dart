import 'dart:math';

import 'package:flutter/material.dart';
import 'package:iptvmac/ui/item_actions.dart';
import 'package:iptvmac/ui/bidi.dart';
import 'package:flutter/semantics.dart';
import 'package:iptvmac/app/device.dart';
import 'package:iptvmac/app/library_model.dart';
import 'package:iptvmac/app/watch_progress.dart';
import 'package:iptvmac/core/models.dart';
import 'package:iptvmac/l10n/app_localizations.dart';
import 'package:iptvmac/ui/artwork.dart';
import 'package:iptvmac/ui/play.dart';
import 'package:iptvmac/ui/tv.dart';
import 'package:iptvmac/ui/widgets.dart';
import 'package:provider/provider.dart';

/// Height of [lines] lines of body text at the user's font size (cells have a fixed height, so they must grow with the text).
double textHeight(BuildContext context, int lines, {double size = 14}) => MediaQuery.textScalerOf(context).scale(size) * 1.5 * lines;

double _scale(BuildContext context) => min(MediaQuery.textScalerOf(context).scale(1), 1.6);

/// Which playlist an item comes from; only shown while All playlists is on.
class PlaylistBadge extends StatelessWidget {
  const PlaylistBadge({super.key, required this.item, this.onArtwork = false});

  final Item item;

  /// On a poster the badge sits on arbitrary artwork, so it gets its own dark ground.
  final bool onArtwork;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<LibraryModel>();
    final name = m.allPlaylists ? m.accountById(item.accountId)?.name : null;
    if (name == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: onArtwork ? Colors.black.withValues(alpha: 0.62) : cs.onSurface.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
      child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: onArtwork ? Colors.white : cs.onSurfaceVariant)),
    );
  }
}

// ---- channels ----

class ChannelLogo extends StatelessWidget {
  const ChannelLogo({super.key, required this.item, required this.size});
  final Item item;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ArtworkImage(url: artUri(item.icon), maxPixel: 160, fit: BoxFit.contain, placeholder: Monogram(name: item.name)),
        ),
      );
}

/// What is on now (with how far along it is) and what comes next, when the provider has a guide for the channel.
class ProgramLine extends StatelessWidget {
  const ProgramLine({super.key, required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LibraryModel>().epgPrograms(item);
    final now = p.now;
    if (now == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final big = MediaQuery.textScalerOf(context).scale(1) > 1.5; // big text: the titles get the room, the bar goes
    final span = now.end.difference(now.start).inSeconds;
    final done = span > 0 ? DateTime.now().toUtc().difference(now.start).inSeconds / span : 0.0;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(now.title, textDirection: titleDirection(now.title), maxLines: big ? 2 : 1, overflow: TextOverflow.ellipsis, style: t),
        if (big && p.next != null)
          Text('${l.epgNext}: ${p.next!.title}', maxLines: 2, overflow: TextOverflow.ellipsis, style: t)
        else if (!big)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              SizedBox(width: 56, child: ProgressBar(value: done, height: 3)),
              if (p.next != null) ...[
                const SizedBox(width: 8),
                Expanded(child: Text('${l.epgNext}: ${p.next!.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t)),
              ],
            ]),
          ),
      ]),
    );
  }
}

class ChannelRow extends StatefulWidget {
  const ChannelRow({super.key, required this.item, this.zapList = const [], this.autofocus = false});

  final Item item;

  /// The remote's first stop on this screen (TV only).
  final bool autofocus;

  /// The list the channel is in (what the player zaps through).
  final List<Item> zapList;

  @override
  State<ChannelRow> createState() => _ChannelRowState();
}

class _ChannelRowState extends State<ChannelRow> {
  @override
  void initState() {
    super.initState();
    context.read<LibraryModel>().loadEpgNow(widget.item); // only rows that get built (the visible ones) ask for the guide
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<LibraryModel>();
    final item = widget.item;
    final fav = m.isFavorite(item);
    final cs = Theme.of(context).colorScheme;
    final current = m.lastPlayedId == item.id;
    final main = <Widget>[
      ChannelLogo(item: item, size: min(52 * _scale(context), 76)),
      const SizedBox(width: 12),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, textDirection: titleDirection(item.name), maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500, color: current ? cs.primary : null)),
            ProgramLine(item: item),
          ]),
        ),
      ),
    ];
    final tail = <Widget>[
      PlaylistBadge(item: item),
      if (item.tvArchive) Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.history, size: 18, color: cs.onSurfaceVariant)),
      FavoriteButton(favorite: fav, onPressed: () => m.toggleFavorite(item)),
    ];
    InkWell tappable(Widget child) => InkWell(
          autofocus: isTelevision && widget.autofocus,
          onTap: () => openItem(context, item, zapList: widget.zapList),
          onLongPress: () => m.toggleFavorite(item),
          child: child,
        );
    final row = Material(
      color: current ? cs.primary.withValues(alpha: 0.12) : Colors.transparent,
      // On a TV the star is next to the row, not inside it: the remote moves from one focusable to a neighbour, never into a child.
      child: isTelevision
          ? Row(children: [
              Expanded(child: tappable(Padding(padding: const EdgeInsetsDirectional.only(start: 16, end: 4, top: 4, bottom: 4), child: Row(children: main)))),
              Padding(padding: const EdgeInsetsDirectional.only(end: 4), child: Row(children: tail)),
            ])
          : tappable(Padding(padding: const EdgeInsetsDirectional.only(start: 16, end: 4, top: 4, bottom: 4), child: Row(children: [...main, ...tail]))),
    );
    return isTelevision && widget.autofocus ? TvEntry(child: row) : row;
  }
}

class ChannelListSliver extends StatelessWidget {
  const ChannelListSliver({super.key, required this.items, this.autofocus = false});
  final List<Item> items;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => SliverList.separated(
        itemCount: items.length,
        itemBuilder: (_, i) => ChannelRow(key: ValueKey(items[i].id), item: items[i], zapList: items, autofocus: autofocus && i == 0),
        separatorBuilder: (_, _) => const Divider(indent: 80, height: 1),
      );
}

// ---- posters ----

class PosterImage extends StatelessWidget {
  const PosterImage({super.key, required this.name, required this.url, this.maxPixel = 420});
  final String name;
  final Uri? url;
  final int maxPixel;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 2 / 3,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10)),
          ),
          clipBehavior: Clip.antiAlias,
          child: ArtworkImage(url: url, maxPixel: maxPixel, placeholder: Monogram(name: name, fontSize: 28)),
        ),
      );
}

class PosterCell extends StatelessWidget {
  const PosterCell({super.key, required this.item, this.autofocus = false});
  final Item item;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<LibraryModel>();
    final fav = m.isFavorite(item);
    final current = m.lastPlayedId == item.id;
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final cell = Semantics(
      customSemanticsActions: {CustomSemanticsAction(label: fav ? l.favRemove : l.favAdd): () => m.toggleFavorite(item)},
      child: TvScale(
        child: InkWell(
        autofocus: isTelevision && autofocus,
        borderRadius: BorderRadius.circular(10),
        onTap: () => openItem(context, item),
        onLongPress: () => item.type == ItemType.movie ? showItemActions(context, item) : m.toggleFavorite(item),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            PosterImage(name: item.name, url: artUri(item.icon)),
            PositionedDirectional(top: 5, start: 5, child: PlaylistBadge(item: item, onArtwork: true)),
            if (fav)
              PositionedDirectional(
                top: 5,
                end: 5,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.62), shape: BoxShape.circle),
                  child: const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                ),
              ),
            if (current)
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: cs.primary, width: 3)))),
          ]),
          const SizedBox(height: 6),
          Text(item.name, textDirection: titleDirection(item.name), maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
        ]),
        ),
      ),
    );
    return isTelevision && autofocus ? TvEntry(child: cell) : cell;
  }
}

/// Posters in a grid whose columns adapt to the width (phone, tablet, landscape) and whose cells grow with the font size.
class PosterGridSliver extends StatelessWidget {
  const PosterGridSliver({super.key, required this.items, this.autofocus = false});
  final List<Item> items;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final minCell = (isTelevision ? 120.0 : MediaQuery.sizeOf(context).width >= 600 ? 140.0 : 104.0) * _scale(context); // a TV: about six across at 1080p
    final text = textHeight(context, 2) + 6;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverLayoutBuilder(builder: (context, c) {
        const gap = 12.0;
        final cols = max(2, ((c.crossAxisExtent + gap) / (minCell + gap)).floor());
        final cell = (c.crossAxisExtent - gap * (cols - 1)) / cols;
        return SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 18, crossAxisSpacing: gap, mainAxisExtent: cell * 1.5 + text),
          itemCount: items.length,
          itemBuilder: (_, i) => PosterCell(key: ValueKey(items[i].id), item: items[i], autofocus: autofocus && i == 0),
        );
      }),
    );
  }
}

// ---- continue watching ----

/// Titles that were started and not finished, with how far along they are.
class ContinueShelf extends StatelessWidget {
  const ContinueShelf({super.key, required this.entries, this.autofocus = false});
  final List<ContinueEntry> entries;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final w = min(128 * _scale(context), 200.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Text(l.catContinue, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      ),
      SizedBox(
        height: w * 1.5 + textHeight(context, 2) + 10,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) => SizedBox(width: w, child: ContinueCard(entry: entries[i], autofocus: autofocus && i == 0)),
        ),
      ),
    ]);
  }
}

class ContinueCard extends StatelessWidget {
  const ContinueCard({super.key, required this.entry, this.autofocus = false});
  final ContinueEntry entry;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final l = AppLocalizations.of(context);
    final label = entry.season != null && entry.episode != null ? l.seriesEpShort(entry.season!, entry.episode!) : null;
    final t = Theme.of(context).textTheme;
    final card = TvScale(
      child: InkWell(
      autofocus: isTelevision && autofocus,
      borderRadius: BorderRadius.circular(10),
      onTap: () => item.type == ItemType.movie ? playItem(context, item) : openItem(context, item),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          PosterImage(name: item.name, url: artUri(item.icon)),
          if (entry.fraction != null)
            Positioned.directional(
              textDirection: Directionality.of(context),
              start: 8,
              end: 8,
              bottom: 8,
              child: ProgressBar(value: entry.fraction!, track: Colors.white.withValues(alpha: 0.35)),
            ),
        ]),
        const SizedBox(height: 6),
        Text(item.name, textDirection: titleDirection(item.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyMedium),
        if (label != null) Text(label, maxLines: 1, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
      ),
    );
    return isTelevision && autofocus ? TvEntry(child: card) : card;
  }
}
