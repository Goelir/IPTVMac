import 'package:flutter/material.dart';
import 'package:iptvmac/app/device.dart';
import 'package:iptvmac/app/library_model.dart';
import 'package:iptvmac/core/models.dart';
import 'package:iptvmac/downloads/downloads_model.dart';
import 'package:iptvmac/l10n/app_localizations.dart';
import 'package:iptvmac/ui/browse_screen.dart';
import 'package:iptvmac/ui/library_screen.dart';
import 'package:iptvmac/ui/missing_strings.dart';
import 'package:iptvmac/ui/onboarding.dart';
import 'package:iptvmac/ui/settings_screen.dart';
import 'package:iptvmac/ui/tv.dart';
import 'package:provider/provider.dart';

/// First run: the welcome and add-source flow. Afterwards: five sections (a bottom bar on a phone, a rail on a tablet or a
/// phone turned sideways). The player is a route above everything.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});
  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  var _index = 0;
  var _asking = false;
  late final LibraryModel _model = context.read<LibraryModel>();

  @override
  void initState() {
    super.initState();
    _model.addListener(_maybeAskPassword);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeAskPassword();
      _maybeTellRecovered();
    });
  }

  @override
  void dispose() {
    _model.removeListener(_maybeAskPassword);
    super.dispose();
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    if (i < 3) _model.setTab(ItemType.values[i]);
  }

  /// An Xtream source without a stored password (a backup was imported): ask for it.
  void _maybeAskPassword() {
    final a = _model.passwordPrompt;
    if (a == null || _asking || !mounted) return;
    _asking = true;
    showDialog<void>(context: context, builder: (_) => _PasswordDialog(account: a)).whenComplete(() {
      _asking = false;
      if (_model.passwordPrompt != null) _model.dismissPasswordPrompt();
    });
  }

  void _maybeTellRecovered() {
    final path = _model.dbMovedAside;
    if (path == null || !mounted) return;
    final l = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.dbRecoveredTitle),
        content: Text(l.dbRecoveredBody(path)),
        actions: [TextButton(autofocus: isTelevision, onPressed: () => Navigator.pop(c), child: Text(l.playerClose))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _index == 0, // back from another tab goes to the first tab; from the first it leaves the app
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _select(0);
        },
        child: _content(context),
      );

  Widget _content(BuildContext context) {
    final hasAccounts = context.select<LibraryModel, bool>((m) => m.accounts.isNotEmpty);
    if (!hasAccounts) return const OnboardingScreen();
    final l = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final rail = isTelevision || size.width >= 600 || size.height < 480; // a TV: always the rail, the remote moves along it
    final running = context.select<DownloadsModel, int>((d) => d.activeCount); // a count on the Library tab, where Downloads is
    Widget library(IconData i) => Badge(isLabelVisible: running > 0, label: Text('$running'), child: Icon(i));
    final dests = [
      (const Icon(Icons.live_tv_outlined), const Icon(Icons.live_tv), l.tabLive),
      (const Icon(Icons.movie_outlined), const Icon(Icons.movie), l.tabMovies),
      (const Icon(Icons.video_library_outlined), const Icon(Icons.video_library), l.tabSeries),
      (library(Icons.bookmarks_outlined), library(Icons.bookmarks), l.tabLibrary),
      (const Icon(Icons.settings_outlined), const Icon(Icons.settings), l.settingsTitle),
    ];
    final body = switch (_index) {
      0 => const BrowseScreen(key: ValueKey(0), type: ItemType.live),
      1 => const BrowseScreen(key: ValueKey(1), type: ItemType.movie),
      2 => const BrowseScreen(key: ValueKey(2), type: ItemType.series),
      3 => const LibraryScreen(),
      _ => const SettingsScreen(),
    };
    if (rail) {
      return TvFrame(
        child: Scaffold(
          body: Row(children: [
            ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: SafeArea(
                child: NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: _select,
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: Colors.transparent,
                  destinations: [for (final d in dests) NavigationRailDestination(icon: d.$1, selectedIcon: d.$2, label: Text(d.$3))],
                ),
              ),
            ),
            Expanded(child: body),
          ]),
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [for (final d in dests) NavigationDestination(icon: d.$1, selectedIcon: d.$2, label: d.$3)],
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.account});
  final Account account;
  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final m = context.read<LibraryModel>();
    return AlertDialog(
      title: Text(l.passwordTitle),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(Missing.passwordBody(widget.account.name)),
        const SizedBox(height: 12),
        TvEditable(
          builder: (_, node, readOnly, done) => TextField(
              key: const Key('password-field'),
              controller: _c,
              focusNode: node,
              readOnly: readOnly,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(labelText: l.fieldPassword),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => done()),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.playerClose)),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            m.savePassword(_c.text, widget.account);
          },
          child: Text(_c.text.isEmpty ? l.passwordNone : l.onbSave),
        ),
      ],
    );
  }
}
