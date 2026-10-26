import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptvmac/app/device.dart';
import 'package:iptvmac/app/library_model.dart';
import 'package:iptvmac/app/source_draft.dart';
import 'package:iptvmac/app/sync_worker.dart';
import 'package:iptvmac/core/models.dart';
import 'package:iptvmac/l10n/app_localizations.dart';
import 'package:iptvmac/ui/missing_strings.dart';
import 'package:iptvmac/ui/tv.dart';
import 'package:provider/provider.dart';

enum _Test { idle, testing, ok, failed }

/// Add a source, or edit one: the type, fields that say what is wrong while you type, a connection test, and one big button
/// (test first, then save and sync; editing may save at once).
class SourceFormScreen extends StatefulWidget {
  const SourceFormScreen({super.key, this.edit, this.initial});

  /// The source being edited; null = add.
  final Account? edit;

  /// A draft to start with (a pasted link).
  final SourceDraft? initial;

  @override
  State<SourceFormScreen> createState() => _SourceFormScreenState();
}

class _SourceFormScreenState extends State<SourceFormScreen> {
  late final SourceDraft _d;
  late final _name = TextEditingController(), _server = TextEditingController(), _user = TextEditingController();
  late final _pass = TextEditingController(), _url = TextEditingController();
  var _state = _Test.idle;
  var _error = '';
  var _busy = false;

  Account? get _editing => widget.edit;

  @override
  void initState() {
    super.initState();
    _d = widget.initial ?? SourceDraft();
    final a = _editing;
    if (a != null) {
      _d
        ..kind = a.kind
        ..name = a.name
        ..server = a.server ?? ''
        ..username = a.username ?? ''
        ..url = a.url ?? '';
    }
    _fill();
  }

  void _fill() {
    _name.text = _d.name;
    _server.text = _d.server;
    _user.text = _d.username;
    _pass.text = _d.password;
    _url.text = _d.url;
  }

  @override
  void dispose() {
    for (final c in [_name, _server, _user, _pass, _url]) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed(VoidCallback f) => setState(() {
        f();
        if (_state != _Test.testing) _state = _Test.idle;
      });

  Future<void> _paste() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (text == null || text.isEmpty) return;
    _changed(() {
      _d.applyPasted(text);
      _fill();
    });
  }

  Future<void> _test() async {
    if (!isTelevision) FocusScope.of(context).unfocus(); // on a TV the button keeps focus (the remote has nowhere else to be)
    setState(() => _state = _Test.testing);
    try {
      await context.read<LibraryModel>().testConnection(kind: _d.kind, server: _d.server, username: _d.username, password: _d.password, url: _d.url);
      if (mounted) setState(() => _state = _Test.ok);
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _Test.failed;
          _error = describeError(e);
        });
      }
    }
  }

  Future<void> _save() async {
    final m = context.read<LibraryModel>();
    final nav = Navigator.of(context);
    final a = _editing;
    setState(() => _busy = true);
    if (a != null) {
      final d = _d.makeAccount().account;
      final updated = Account(id: a.id, name: d.name, kind: a.kind, server: d.server, username: d.username, url: d.url);
      nav.pop();
      await m.updateAccount(updated, password: _d.password.isEmpty ? null : _d.password);
    } else {
      final (:account, :password) = _d.makeAccount();
      final saved = await m.addAccount(account, password: password);
      if (saved) {
        nav.popUntil((r) => r.isFirst); // first run: the root swaps to the library by itself
      } else if (mounted) {
        setState(() => _busy = false); // the form stays and shows why
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final editing = _editing != null;
    final failure = context.select<LibraryModel, String?>((m) => m.accounts.isEmpty ? m.syncMessage : null);
    final ready = _state == _Test.ok || editing;
    Widget problem(String s) => Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.error_outline, size: 16, color: cs.error),
            const SizedBox(width: 6),
            Expanded(child: Text(s, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.error))),
          ]),
        );
    final xtream = _d.kind == AccountKind.xtream;
    return TvFrame(
      child: Scaffold(
      appBar: AppBar(title: Text(editing ? l.settingsEditSource : l.accountAdd)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            // While testing a phone shows the button disabled; on a TV it stays enabled (and does nothing) so the remote keeps its place.
            onPressed: !_d.canTest || _busy ? null : _state == _Test.testing ? (isTelevision ? () {} : null) : (ready ? _save : _test),
            child: _state == _Test.testing
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 10),
                    Text(l.onbTestRunning),
                  ])
                : Text(ready ? l.onbSave : l.onbTest),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, children: [
            if (!editing) ...[
              SegmentedButton<AccountKind>(
                segments: [ButtonSegment(value: AccountKind.xtream, label: Text(l.kindXtream)), ButtonSegment(value: AccountKind.m3u, label: Text(l.kindM3u))],
                selected: {_d.kind},
                showSelectedIcon: false,
                onSelectionChanged: (s) => _changed(() => _d.kind = s.first),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 16), child: Text(xtream ? l.onbWhereXtream : l.onbWhereM3u, style: Theme.of(context).textTheme.bodySmall)),
            ],
            TvEditable(builder: (_, node, readOnly, done) => TextField(
              focusNode: node,
              readOnly: readOnly,
              onSubmitted: (_) => done(),
              autofocus: isTelevision,
              key: const Key('field-name'),
              controller: _name,
              decoration: InputDecoration(labelText: l.fieldName),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onChanged: (v) => _changed(() => _d.name = v),
            )),
            const SizedBox(height: 12),
            if (xtream) ...[
              TvEditable(builder: (_, node, readOnly, done) => TextField(
                focusNode: node,
                readOnly: readOnly,
                onSubmitted: (_) => done(),
                key: const Key('field-server'),
                controller: _server,
                decoration: InputDecoration(labelText: l.fieldServer, hintText: 'http://host:8080'),
                keyboardType: TextInputType.url,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                onChanged: (v) => _changed(() => _d.server = v),
              )),
              if (_d.serverLooksWrong) problem(l.fieldServerInvalid),
              const SizedBox(height: 12),
              TvEditable(builder: (_, node, readOnly, done) => TextField(
                focusNode: node,
                readOnly: readOnly,
                onSubmitted: (_) => done(),
                key: const Key('field-username'),
                controller: _user,
                decoration: InputDecoration(labelText: l.fieldUsername),
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
                onChanged: (v) => _changed(() => _d.username = v),
              )),
              const SizedBox(height: 12),
              TvEditable(builder: (_, node, readOnly, done) => TextField(
                focusNode: node,
                readOnly: readOnly,
                onSubmitted: (_) => done(),
                key: const Key('field-password'),
                controller: _pass,
                decoration: InputDecoration(labelText: editing ? l.settingsNewPassword : l.fieldPassword),
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (v) => _changed(() => _d.password = v),
              )),
              if (editing) Padding(padding: const EdgeInsets.fromLTRB(4, 6, 4, 0), child: Text(Missing.passwordNote, style: Theme.of(context).textTheme.bodySmall)),
            ] else ...[
              TvEditable(builder: (_, node, readOnly, done) => TextField(
                focusNode: node,
                readOnly: readOnly,
                onSubmitted: (_) => done(),
                key: const Key('field-url'),
                controller: _url,
                decoration: InputDecoration(labelText: l.fieldUrl, hintText: 'https://example.com/list.m3u'),
                keyboardType: TextInputType.url,
                autocorrect: false,
                minLines: 1,
                maxLines: isTelevision ? 1 : 4,
                onChanged: (v) => _changed(() => _d.url = v),
              )),
              if (_d.urlLooksWrong) problem(l.fieldUrlInvalid),
            ],
            if (!editing && !isTelevision) // a TV has no clipboard to paste a link from
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(children: [
                  Expanded(child: Text(l.onbPasteHint, style: TextStyle(color: cs.onSurfaceVariant))),
                  OutlinedButton.icon(onPressed: _paste, icon: const Icon(Icons.content_paste, size: 18), label: Text(Missing.paste)),
                ]),
              ),
            if (failure != null) Padding(padding: const EdgeInsets.only(top: 16), child: problem(failure)),
            if (_state == _Test.failed) Padding(padding: const EdgeInsets.only(top: 16), child: problem('${l.onbTestFail}: $_error')),
            if (_state == _Test.ok)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(children: [const Icon(Icons.check_circle, color: Colors.green), const SizedBox(width: 8), Expanded(child: Text(l.onbTestOk))]),
              ),
            if (editing) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: !_d.canTest ? null : _state == _Test.testing ? (isTelevision ? () {} : null) : _test, child: Text(l.onbTest)),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: cs.error),
                onPressed: () => _confirmDelete(context),
                child: Text(l.settingsDelete),
              ),
            ],
          ]),
        ),
      ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final a = _editing!;
    final m = context.read<LibraryModel>();
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(a.name),
        content: Text(l.sourceDeleteWarn),
        actions: [
          TextButton(autofocus: isTelevision, onPressed: () => Navigator.pop(c, false), child: Text(l.commonCancel)),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(l.settingsDelete, style: TextStyle(color: Theme.of(c).colorScheme.error))),
        ],
      ),
    );
    if (ok == true) {
      nav.pop();
      await m.deleteAccount(a);
    }
  }
}
