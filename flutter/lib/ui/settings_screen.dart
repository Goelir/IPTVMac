import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:iptvmac/app/device.dart';
import 'package:intl/intl.dart';
import 'package:iptvmac/app/library_model.dart';
import 'package:iptvmac/core/backup.dart';
import 'package:iptvmac/core/models.dart';
import 'package:iptvmac/core/subscription_info.dart';
import 'package:iptvmac/downloads/downloads_model.dart';
import 'package:iptvmac/l10n/app_localizations.dart';
import 'package:iptvmac/ui/about_screens.dart';
import 'package:iptvmac/ui/downloads_screen.dart';
import 'package:iptvmac/ui/missing_strings.dart';
import 'package:iptvmac/ui/source_form.dart';
import 'package:iptvmac/ui/tv.dart';
import 'package:iptvmac/ui/widgets.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(padding: const EdgeInsets.only(bottom: 24), scrollCacheExtent: tvCache(3000), children: const [
            _SourcesSection(),
            _PreferencesSection(),
            _UpdatesSection(),
            _DownloadsTile(),
            _HiddenCategoriesSection(),
            _BackupSection(),
            _ClearSection(),
            _AboutTile(),
          ]),
        ),
      ),
    );
  }
}

/// A titled group of rows on a card, with an optional note under it.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.note});
  final String? title;
  final List<Widget> children;
  final Widget? note;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Semantics(header: true, child: Text(title!, style: t.titleSmall?.copyWith(color: cs.primary)))),
        Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), clipBehavior: Clip.antiAlias, child: Column(children: children)),
        if (note != null) Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 0), child: DefaultTextStyle.merge(style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant), child: note!)),
      ]),
    );
  }
}

Future<bool> confirm(BuildContext context, {required String title, required String message, required String action}) async {
  final l = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(autofocus: isTelevision, onPressed: () => Navigator.pop(c, false), child: Text(l.commonCancel)),
        TextButton(onPressed: () => Navigator.pop(c, true), child: Text(action, style: TextStyle(color: Theme.of(c).colorScheme.error))),
      ],
    ),
  );
  return ok == true;
}

class _SourcesSection extends StatefulWidget {
  const _SourcesSection();

  @override
  State<_SourcesSection> createState() => _SourcesSectionState();
}

class _SourcesSectionState extends State<_SourcesSection> {
  @override
  void initState() {
    super.initState();
    final m = context.read<LibraryModel>();
    for (final a in m.accounts) {
      m.refreshSubscription(a); // the expiry date of each Xtream subscription, when the panel gives one
    }
  }

  /// One source. On a TV the buttons sit beside the tile, not inside it: the remote moves between neighbours, never into a child.
  Widget _sourceRow(BuildContext context, LibraryModel m, AppLocalizations l, ColorScheme cs, int i, Account a) {
    final refresh = IconButton(icon: const Icon(Icons.refresh), tooltip: l.syncNow, onPressed: m.syncing ? null : () => m.sync([a]));
    final delete = IconButton(
      icon: const Icon(Icons.delete_outline),
      tooltip: l.settingsDelete,
      onPressed: () async {
        if (await confirm(context, title: a.name, message: l.sourceDeleteWarn, action: l.settingsDelete)) await m.deleteAccount(a);
      },
    );
    final tile = ListTile(
      key: Key('source-${a.id}'),
      autofocus: isTelevision && i == 0,
      leading: Icon(a.kind == AccountKind.xtream ? Icons.dns_outlined : Icons.list_alt, color: cs.primary),
      title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text([a.kind == AccountKind.xtream ? l.kindXtream : l.kindM3u, if (a.kind == AccountKind.xtream) a.username].whereType<String>().join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
        if (m.subscriptions[a.id] case final s? when s.expires != null) SubscriptionLine(s),
      ]),
      trailing: isTelevision ? null : Row(mainAxisSize: MainAxisSize.min, children: [refresh, delete]),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SourceFormScreen(edit: a))),
    );
    if (!isTelevision) return tile;
    final row = Row(children: [Expanded(child: tile), refresh, delete, const SizedBox(width: 8)]);
    return i == 0 ? TvEntry(child: row) : row;
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<LibraryModel>();
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return _Section(
      title: l.settingsAccounts,
      note: m.syncing
          ? Row(children: [SizedBox(width: 14, height: 14, child: CircularProgressIndicator(value: m.syncProgress, strokeWidth: 2)), const SizedBox(width: 8), Text(syncStatusText(context, m.syncProgress))])
          : m.syncMessage != null
              ? Text('${l.syncFailed}: ${m.syncMessage}', style: TextStyle(color: cs.error))
              : null,
      children: [
        for (final (i, a) in m.accounts.indexed) _sourceRow(context, m, l, cs, i, a),
        ListTile(
          key: const Key('add-source-tile'),
          leading: Icon(Icons.add_circle, color: cs.primary),
          title: Text(l.accountAdd),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SourceFormScreen())),
        ),
      ],
    );
  }
}

class _PreferencesSection extends StatelessWidget {
  const _PreferencesSection();

  @override
  Widget build(BuildContext context) {
    final m = context.watch<LibraryModel>();
    final l = AppLocalizations.of(context);
    final labels = {0: l.settingsRefresh0, 6: l.settingsRefresh6, 12: l.settingsRefresh12, 24: l.settingsRefresh24};
    return Column(children: [
      _Section(title: null, children: [
        ListTile(
          title: Text(l.settingsRefresh),
          subtitle: Text(labels[m.refreshHours] ?? labels[0]!),
          onTap: () async {
            final h = await showDialog<int>(
              context: context,
              builder: (c) => SimpleDialog(title: Text(l.settingsRefresh), children: [
                for (final e in labels.entries)
                  ListTile(
                    autofocus: isTelevision && e.key == (labels.containsKey(m.refreshHours) ? m.refreshHours : 0),
                    title: Text(e.value),
                    trailing: e.key == m.refreshHours ? Icon(Icons.check, color: Theme.of(c).colorScheme.primary) : null,
                    onTap: () => Navigator.pop(c, e.key),
                  ),
              ]),
            );
            if (h != null) m.setRefreshHours(h);
          },
        ),
        ListTile(
          title: Text(l.settingsAppearance),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'system', label: Text(l.settingsSystem, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ButtonSegment(value: 'light', label: Text(l.appearanceLight, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ButtonSegment(value: 'dark', label: Text(l.appearanceDark, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
              selected: {m.prefs.appearance},
              onSelectionChanged: (s) => m.setAppearance(s.first),
            ),
          ),
        ),
      ]),
      _Section(title: null, note: Text(Missing.languageNote), children: [
        ListTile(title: Text(l.settingsInterfaceLanguage), trailing: Text(languageName(Localizations.localeOf(context)))),
      ]),
    ]);
  }
}

/// Whether to ask github.com now and then if a newer APK is out, a button to ask right now, and the answer.
class _UpdatesSection extends StatelessWidget {
  const _UpdatesSection();

  @override
  Widget build(BuildContext context) {
    final m = context.watch<LibraryModel>();
    final l = AppLocalizations.of(context);
    if (m.appVersion == null || isTelevision) return const SizedBox.shrink(); // the release page needs a browser, which a TV rarely has
    final newer = m.newerVersion;
    final subtitle = switch (m.updateCheck) {
      UpdateCheck.checking => l.syncRunning,
      UpdateCheck.failed => l.updateFailed,
      _ when newer != null => l.updateAvailable(newer),
      UpdateCheck.done => l.updateUpToDate,
      _ => l.updateCurrent(m.appVersion!),
    };
    return _Section(title: null, children: [
      SwitchListTile(
        key: const Key('auto-update-switch'),
        title: Text(l.updateAuto),
        value: m.prefs.autoCheckUpdates,
        onChanged: m.setAutoCheckUpdates,
      ),
      ListTile(
        key: const Key('check-update-tile'),
        title: Text(l.updateCheckNow),
        subtitle: Text(subtitle),
        trailing: newer != null
            ? TextButton(onPressed: () => openUpdatePage(newer), child: Text(l.updateNow))
            : m.updateCheck == UpdateCheck.checking
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : null,
        onTap: m.updateCheck == UpdateCheck.checking ? null : () => m.checkForUpdate(manual: true),
      ),
    ]);
  }
}

class _HiddenCategoriesSection extends StatefulWidget {
  const _HiddenCategoriesSection();
  @override
  State<_HiddenCategoriesSection> createState() => _HiddenCategoriesSectionState();
}

class _HiddenCategoriesSectionState extends State<_HiddenCategoriesSection> {
  late final _c = TextEditingController(text: context.read<LibraryModel>().prefs.hiddenWords);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final m = context.read<LibraryModel>();
    return _Section(
      title: l.settingsHideCategories,
      note: Text(l.settingsHideCategoriesNote),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TvEditable(
            builder: (_, node, readOnly, done) => TextField(
              key: const Key('hidden-words'),
              controller: _c,
              focusNode: node,
              readOnly: readOnly,
              autocorrect: false,
              decoration: InputDecoration(labelText: l.settingsHideCategoriesWords, hintText: 'xxx, adult'),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 600), () => m.setHiddenWords(v)); // applied once typing pauses
              },
              onSubmitted: (_) => done(),
            ),
          ),
        ),
      ],
    );
  }
}

class _BackupSection extends StatelessWidget {
  const _BackupSection();

  void _say(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _export(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final m = context.read<LibraryModel>();
    try {
      final saved = await FilePicker.saveFile(
          fileName: 'IPTVMac backup.json', bytes: utf8.encode(m.backupJson()), mimeType: 'application/json', type: FileType.custom, allowedExtensions: ['json']);
      if (saved != null && context.mounted) _say(context, l.backupExported);
    } catch (e) {
      if (context.mounted) _say(context, '${l.backupFailed}: $e');
    }
  }

  Future<void> _import(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final m = context.read<LibraryModel>();
    try {
      final f = await FilePicker.pickFile(type: FileType.any);
      if (f == null) return;
      if ((await f.length() ?? 0) > Backup.maxBytes) throw BackupError.tooLarge;
      await m.importBackup(await f.readAsBytes());
      if (context.mounted) _say(context, l.backupImported);
    } on BackupError catch (e) {
      if (context.mounted) {
        _say(context, switch (e) { BackupError.tooLarge => l.backupErrorTooLarge, BackupError.unsupportedVersion => l.backupErrorVersion, BackupError.invalid => l.backupErrorInvalid });
      }
    } catch (e) {
      if (context.mounted) _say(context, '${l.backupFailed}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isTelevision) return const SizedBox.shrink(); // the file picker needs a file manager, which a TV does not have
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return _Section(title: l.settingsBackup, note: Text(l.backupWarn), children: [
      ListTile(leading: Icon(Icons.upload_file, color: cs.primary), title: Text(l.backupExport), onTap: () => _export(context)),
      ListTile(leading: Icon(Icons.download, color: cs.primary), title: Text(l.backupImport), onTap: () => _import(context)),
    ]);
  }
}

class _ClearSection extends StatelessWidget {
  const _ClearSection();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final m = context.read<LibraryModel>();
    final cs = Theme.of(context).colorScheme;
    final kinds = {
      ClearKind.history: (l.clearHistory, l.clearHistoryWarn),
      ClearKind.favorites: (l.clearFavorites, l.clearFavoritesWarn),
      ClearKind.images: (l.clearImages, l.clearImagesWarn),
    };
    return _Section(title: l.settingsClearData, children: [
      for (final e in kinds.entries)
        ListTile(
          key: Key('clear-${e.key.name}'),
          title: Text(e.value.$1, style: TextStyle(color: cs.error)),
          onTap: () async {
            if (await confirm(context, title: e.value.$1, message: e.value.$2, action: l.clearConfirm)) await m.clear(e.key);
          },
        ),
    ]);
  }
}

class _DownloadsTile extends StatelessWidget {
  const _DownloadsTile();

  @override
  Widget build(BuildContext context) {
    if (!context.watch<DownloadsModel>().enabled) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return _Section(title: null, children: [
      ListTile(
        key: const Key('downloads-tile'),
        leading: Icon(Icons.arrow_circle_down_outlined, color: Theme.of(context).colorScheme.primary),
        title: Text(l.downloadsTitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DownloadsScreen())),
      ),
    ]);
  }
}

class _AboutTile extends StatelessWidget {
  const _AboutTile();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _Section(title: null, children: [
      ListTile(
        key: const Key('about-tile'),
        leading: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
        title: Text(l.settingsAbout),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AboutScreen())),
      ),
    ]);
  }
}

/// The language's own name (the 31 languages of the app).
String languageName(Locale l) {
  const names = {
    'ar': 'العربية', 'bg': 'Български', 'bn': 'বাংলা', 'cs': 'Čeština', 'de': 'Deutsch', 'el': 'Ελληνικά', 'en': 'English', 'es': 'Español',
    'fa': 'فارسی', 'fr': 'Français', 'he': 'עברית', 'hi': 'हिन्दी', 'hu': 'Magyar', 'id': 'Indonesia', 'it': 'Italiano', 'ja': '日本語',
    'ko': '한국어', 'nl': 'Nederlands', 'pl': 'Polski', 'pt': 'Português', 'ro': 'Română', 'ru': 'Русский', 'sq': 'Shqip', 'sv': 'Svenska',
    'th': 'ไทย', 'tr': 'Türkçe', 'uk': 'Українська', 'ur': 'اردو', 'vi': 'Tiếng Việt',
  };
  if (l.languageCode == 'zh') return l.scriptCode == 'Hant' ? '繁體中文' : '简体中文';
  return names[l.languageCode] ?? l.toLanguageTag();
}

/// "Expires 12 Mar 2027 · Days left: 140": orange within a week, red once it ended. Nothing when the panel gave no date.
class SubscriptionLine extends StatelessWidget {
  const SubscriptionLine(this.info, {super.key, this.now});
  final SubscriptionInfo info;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final end = info.expires;
    if (end == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final at = now ?? DateTime.now();
    final state = info.state(at);
    String date;
    try {
      date = DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(end);
    } catch (_) {
      date = end.toIso8601String().substring(0, 10); // a locale intl has no date data for
    }
    final text = state == SubscriptionState.expired ? l.subExpired(date) : '${l.subExpires(date)} · ${l.subDaysLeft(info.daysLeft(at) ?? 0)}';
    final color = switch (state) {
      SubscriptionState.expired => cs.error,
      SubscriptionState.soon => Colors.orange,
      _ => cs.onSurfaceVariant,
    };
    return Text(text, key: const Key('subscription-line'), style: TextStyle(color: color, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}
