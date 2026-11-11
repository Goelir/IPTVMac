import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iptvmac/ui/theme.dart';
import 'package:iptvmac/app/library_model.dart';
import 'package:iptvmac/downloads/download_entry.dart';
import 'package:iptvmac/downloads/downloads_model.dart';
import 'package:iptvmac/downloads/library_downloads.dart';
import 'package:iptvmac/l10n/app_localizations.dart';
import 'package:iptvmac/ui/bidi.dart';
import 'package:iptvmac/ui/missing_strings.dart';
import 'package:iptvmac/ui/play.dart';
import 'package:iptvmac/ui/settings_screen.dart' show confirm;
import 'package:iptvmac/ui/widgets.dart';
import 'package:provider/provider.dart';

/// "1.4 GB", "230 MB": decimal units like the Mac app's byte formatter.
/// "45 seconds", "12 min", "1 h 5 min": the time left of a download, in the units the player already uses.
String etaText(AppLocalizations l, Duration d) {
  final s = d.inSeconds;
  if (s < 60) return l.unitSeconds(s < 1 ? 1 : s);
  final m = (s / 60).round();
  if (m < 60) return l.unitMinutesShort(m);
  return m % 60 == 0 ? l.unitHoursShort(m ~/ 60) : '${l.unitHoursShort(m ~/ 60)} ${l.unitMinutesShort(m % 60)}';
}

String formatBytes(int bytes, [String? locale]) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = bytes.toDouble(), i = 0;
  while (v >= 1000 && i < units.length - 1) {
    v /= 1000;
    i++;
  }
  return '${NumberFormat(i == 0 ? '0' : '0.0', locale).format(v)} ${units[i]}';
}

/// The saved and saving movies and episodes: progress, pause, resume, cancel, play offline, delete.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});
  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  @override
  void initState() {
    super.initState();
    final d = context.read<DownloadsModel>();
    WidgetsBinding.instance.addPostFrameCallback((_) => d.refreshFiles()); // a file may have been deleted with a file manager
  }

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DownloadsModel>();
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final entries = d.entries.reversed.toList(); // newest first
    return Scaffold(
      appBar: AppBar(title: Text(l.downloadsTitle), actions: [
        if (d.hasDone)
          IconButton(
            key: const Key('delete-all'),
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: Missing.downloadsDeleteAll,
            onPressed: () async {
              if (await confirm(context, title: Missing.downloadsDeleteAll, message: Missing.downloadsDeleteAllWarn, action: l.downloadsDelete)) await d.removeAllDone();
            },
          ),
      ]),
      body: entries.isEmpty
          ? EmptyState(icon: Icons.arrow_circle_down_outlined, title: l.downloadsEmpty, hint: Missing.downloadsNote)
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
                  if (d.hasDone) Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text(Missing.downloadsTotal(formatBytes(d.doneBytes, locale)), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
                  for (final e in entries) _Row(entry: e, locale: locale),
                  Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 0), child: Text(Missing.downloadsNote, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
                ]),
              ),
            ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.locale});
  final DownloadEntry entry;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final d = context.read<DownloadsModel>();
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final e = entry;
    final small = t.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    final Widget status = switch (e.status) {
      DownloadStatus.done when e.missing => Text(Missing.downloadsFileMissing, style: small?.copyWith(color: cs.error)),
      DownloadStatus.done => Text('${l.downloadsDone} · ${formatBytes(e.bytes, locale)}', style: small),
      DownloadStatus.failed => Text(_failure(l, e), style: small?.copyWith(color: cs.error), maxLines: 2, overflow: TextOverflow.ellipsis),
      DownloadStatus.canceled => Text(Missing.downloadsCanceled, style: small),
      DownloadStatus.queued => Text(l.downloadsQueued, style: small),
      DownloadStatus.running || DownloadStatus.paused => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ProgressBar(value: e.fraction, track: e.status == DownloadStatus.paused ? cs.onSurface.withValues(alpha: 0.2) : null),
          const SizedBox(height: 4),
          Text(
            [
              e.total > 0 ? '${formatBytes(e.bytes, locale)} / ${formatBytes(e.total, locale)}' : formatBytes(e.bytes, locale),
              if (e.eta != null) l.downloadsEta(etaText(l, e.eta!)),
            ].join(' · '),
            style: small?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ]),
    };
    final actions = <Widget>[
      if (e.status == DownloadStatus.done && !e.missing)
        IconButton(key: Key('play-${e.id}'), icon: const Icon(Icons.play_arrow_rounded), tooltip: l.downloadsPlay, onPressed: () => _play(context)),
      if (e.status == DownloadStatus.running) IconButton(key: Key('pause-${e.id}'), icon: const Icon(Icons.pause), tooltip: l.downloadsPause, onPressed: () => d.pause(e.id)),
      if (e.status == DownloadStatus.paused || e.status == DownloadStatus.failed || e.status == DownloadStatus.canceled)
        IconButton(key: Key('resume-${e.id}'), icon: const Icon(Icons.refresh), tooltip: l.downloadsResume, onPressed: () => d.resume(e.id)),
      if (e.status == DownloadStatus.done)
        IconButton(
          key: Key('delete-${e.id}'),
          icon: const Icon(Icons.delete_outline),
          tooltip: e.missing ? Missing.downloadsRemove : l.downloadsDelete,
          onPressed: () async {
            if (e.missing || await confirm(context, title: e.title, message: Missing.downloadsDeleteWarn, action: l.downloadsDelete)) await d.remove(e.id);
          },
        )
      else
        IconButton(key: Key('cancel-${e.id}'), icon: const Icon(Icons.close), tooltip: l.downloadsCancel, onPressed: () => d.remove(e.id)),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Brand.radiusCard), side: BorderSide(color: cs.onSurface.withValues(alpha: 0.06))),
      child: InkWell(
        onTap: e.status == DownloadStatus.done && !e.missing ? () => _play(context) : null,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 8),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.title, textDirection: titleDirection(e.title), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall),
                const SizedBox(height: 4),
                status,
              ]),
            ),
            ...actions,
          ]),
        ),
      ),
    );
  }

  static String _failure(AppLocalizations l, DownloadEntry e) => switch (e.error) {
        'noSpace' => l.downloadsNoSpace,
        'notFound' => Missing.downloadsNotFound,
        'lost' => Missing.downloadsLost,
        _ => Missing.downloadsFailed,
      };

  void _play(BuildContext context) => openPlayer(context, context.read<LibraryModel>().offlineRequest(entry));
}
