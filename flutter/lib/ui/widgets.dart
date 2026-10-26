import 'package:flutter/material.dart';
import 'package:iptvmac/app/device.dart';
import 'package:intl/intl.dart';
import 'package:iptvmac/core/android_update.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iptvmac/app/library_model.dart';
import 'package:iptvmac/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

/// A slim progress bar; fills from the start edge (so from the right in right-to-left languages).
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.height = 4, this.track});

  final double value;
  final double height;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      value: '${(value.clamp(0, 1) * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          minHeight: height,
          backgroundColor: track ?? cs.onSurface.withValues(alpha: 0.12),
          color: cs.primary,
        ),
      ),
    );
  }
}

/// Under the app bar: "Syncing…" and "Sync failed" with a retry.
class StatusStrip extends StatelessWidget {
  const StatusStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<LibraryModel>();
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final Widget? child;
    if (m.syncing) {
      child = Row(children: [
        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(value: m.syncProgress, strokeWidth: 2)),
        const SizedBox(width: 12),
        Expanded(child: Text(syncStatusText(context, m.syncProgress), key: const Key('sync-status'))),
      ]);
    } else if (m.syncMessage != null) {
      child = Row(children: [
        Icon(Icons.warning_amber_rounded, color: cs.error, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text('${l.syncFailed}: ${m.syncMessage}. ${l.syncNotUpdated}', maxLines: 4, overflow: TextOverflow.ellipsis)),
        TextButton(onPressed: m.sync, child: Text(l.playerRetry)),
      ]);
    } else {
      child = null;
    }
    if (child == null) return const SizedBox.shrink();
    return Material(
      color: cs.surfaceContainerLow,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 8, 6),
        constraints: const BoxConstraints(minHeight: 44),
        alignment: AlignmentDirectional.centerStart,
        child: DefaultTextStyle.merge(style: Theme.of(context).textTheme.bodySmall, child: child),
      ),
    );
  }
}

/// An empty state: an icon, a title, a hint and optionally a button. Scrolls, so a big font or a short screen never overflows.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.hint, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String? hint;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(), // lets pull-to-refresh work on an empty list
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 56, color: cs.onSurfaceVariant),
                const SizedBox(height: 16),
                Text(title, style: t.titleMedium, textAlign: TextAlign.center),
                if (hint != null) ...[
                  const SizedBox(height: 8),
                  Text(hint!, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
                ],
                if (actionLabel != null) ...[const SizedBox(height: 20), FilledButton.tonal(autofocus: isTelevision, onPressed: onAction, child: Text(actionLabel!))],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// A star button (48 dp) that toggles a favorite.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.favorite, required this.onPressed, this.tonal = false, this.autofocus = false});

  final bool favorite;
  final VoidCallback onPressed;
  final bool tonal;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final icon = Icon(favorite ? Icons.star_rounded : Icons.star_outline_rounded, color: favorite ? Colors.amber : null);
    final tip = favorite ? l.favRemove : l.favAdd;
    return tonal
        ? IconButton.filledTonal(autofocus: autofocus, onPressed: onPressed, icon: icon, tooltip: tip)
        : IconButton(autofocus: autofocus, onPressed: onPressed, icon: icon, tooltip: tip);
  }
}

/// "Syncing… 42%": the sync status line, with the percentage once the sync reports one.
String syncStatusText(BuildContext context, double? progress) {
  final text = AppLocalizations.of(context).syncRunning;
  if (progress == null) return text;
  String pct;
  try {
    pct = NumberFormat.percentPattern(Localizations.localeOf(context).toString()).format(progress);
  } catch (_) {
    pct = '${(progress * 100).floor()}%'; // a locale intl has no number data for
  }
  return '$text $pct';
}

/// "Version 1.0.3 is available": a new APK is out. The install stays manual: the button opens the release page, where the file is.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final v = context.select<LibraryModel, String?>((m) => m.updateAvailable);
    if (v == null || isTelevision) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primaryContainer,
      child: Container(
        key: const Key('update-banner'),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 4, 4),
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(children: [
          Icon(Icons.system_update, size: 20, color: cs.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(child: Text(l.updateAvailable(v), style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w600))),
          TextButton(onPressed: () => openUpdatePage(v), child: Text(l.updateNow)),
          IconButton(
            icon: Icon(Icons.close, color: cs.onPrimaryContainer),
            tooltip: l.updateLater,
            onPressed: context.read<LibraryModel>().dismissUpdate,
          ),
        ]),
      ),
    );
  }
}

/// Opens the release page of [version] in the browser (tests replace this).
Future<void> Function(String version) openUpdatePage = (v) => launchUrl(androidReleasePage(v), mode: LaunchMode.externalApplication);
