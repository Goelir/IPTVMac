import 'package:flutter/material.dart';
import 'package:iptvmac/app/library_model.dart';
import 'package:iptvmac/core/models.dart';
import 'package:iptvmac/downloads/download_entry.dart';
import 'package:iptvmac/downloads/downloads_model.dart';
import 'package:iptvmac/downloads/library_downloads.dart';
import 'package:iptvmac/l10n/app_localizations.dart';
import 'package:iptvmac/ui/downloads_screen.dart';
import 'package:iptvmac/ui/missing_strings.dart';
import 'package:provider/provider.dart';

/// A long press on a movie: favorite and download. A movie from an M3U playlist plays on a tap and has no details sheet, so this is
/// where its download button lives (Xtream movies also have one in the sheet).
/// The long-press menu of a title. [inContinue]: it was pressed on the Continue watching page or shelf, so it can be removed from there.
Future<void> showItemActions(BuildContext context, Item item, {bool inContinue = false}) {
  final m = context.read<LibraryModel>();
  final d = context.read<DownloadsModel>();
  final messenger = ScaffoldMessenger.of(context);
  final nav = Navigator.of(context);
  final l = AppLocalizations.of(context);
  final fav = m.isFavorite(item);
  final canDownload = d.enabled && m.canDownload(item);
  final existing = canDownload ? d.find(DownloadEntry.keyOf(item.accountId, item.type, item.streamId, null)) : null;
  final running = existing != null && existing.status != DownloadStatus.failed && existing.status != DownloadStatus.canceled && !existing.missing;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(sheet).textTheme.titleMedium)),
        ListTile(
          key: const Key('action-favorite'),
          leading: Icon(fav ? Icons.star : Icons.star_border),
          title: Text(fav ? l.favRemove : l.favAdd),
          onTap: () {
            Navigator.pop(sheet);
            m.toggleFavorite(item);
          },
        ),
        if (inContinue)
          ListTile(
            key: const Key('action-remove-continue'),
            leading: const Icon(Icons.highlight_off),
            title: Text(l.continueRemove),
            onTap: () {
              Navigator.pop(sheet);
              m.removeFromContinue(item);
            },
          ),
        if (canDownload)
          ListTile(
            key: const Key('action-download'),
            leading: Icon(running ? Icons.download_done : Icons.download_outlined),
            title: Text(running ? l.downloadsTitle : l.downloadsAdd),
            onTap: () async {
              Navigator.pop(sheet);
              if (running) {
                nav.push(MaterialPageRoute<void>(builder: (_) => const DownloadsScreen()));
                return;
              }
              final r = await m.downloadMovie(d, item);
              messenger.showSnackBar(SnackBar(
                content: Text(r == AddResult.noUrl || r == AddResult.refused ? Missing.downloadsCannotStart : Missing.downloadsAdded),
              ));
            },
          ),
      ]),
    ),
  );
}
