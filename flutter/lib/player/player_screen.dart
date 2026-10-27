import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_localized_locales/flutter_localized_locales.dart';

import '../app/device.dart';
import 'android_player_system.dart';
import 'desktop_player_system.dart';
import 'engine.dart';
import 'media_kit_engine.dart';
import 'play_request.dart';
import 'player_controls.dart';
import 'player_desktop.dart';
import 'player_gesture_surface.dart';
import 'player_model.dart';
import 'player_options.dart';
import 'player_prefs.dart';
import 'player_system.dart';
import 'player_tv.dart';
import 'player_widgets.dart';

/// The full-screen player. The shell pushes it with a [PlayRequest] and a [PlayerHost]; it never touches the library itself.
/// [engineFactory], [system], [prefs] and [clock] are for tests and the lab: the defaults are libmpv, the Android system glue and the
/// stored settings. The app needs `MediaKit.ensureInitialized()` in main and the generated localizations in its MaterialApp.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.request, required this.host, this.engineFactory, this.system, this.prefs, this.clock});

  final PlayRequest request;
  final PlayerHost host;
  final PlaybackEngine Function(PlayerPrefs prefs)? engineFactory;
  final PlayerSystem? system;
  final PlayerPrefs? prefs;
  final DateTime Function()? clock;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  PlayerModel? _model;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_starting) return;
    _starting = true;
    _start(!isTelevision && MediaQuery.sizeOf(context).shortestSide < 600);
  }

  Future<void> _start(bool phone) async {
    final prefs = widget.prefs ?? await PlayerPrefs.load();
    if (!mounted) return;
    final engine = widget.engineFactory?.call(prefs) ?? MediaKitEngine(subLang: prefs.subLang, audioLang: prefs.audioLang);
    final system = widget.system ?? (Platform.isAndroid ? AndroidPlayerSystem() : isDesktop ? DesktopPlayerSystem() : PlayerSystem());
    await system.enter(lockLandscape: phone);
    if (!mounted) {
      engine.dispose();
      await system.exit();
      return;
    }
    setState(() => _model = PlayerModel(host: widget.host, request: widget.request, engine: engine, system: system, prefs: prefs, clock: widget.clock ?? DateTime.now, canRotate: phone));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) _model?.appPaused(); // saves the position; playback goes on (a desktop window can sit behind another)
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _model?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = _model;
    return Theme(
      data: ThemeData(brightness: Brightness.dark, useMaterial3: true, focusColor: isTelevision ? Colors.white30 : null),
      child: tvDirectional(context, Localizations.override(
        context: context,
        delegates: const [LocaleNamesLocalizationsDelegate()],
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) model == null ? widget.host.closePlayer() : model.back();
          },
          child: Material(
            color: Colors.black,
            child: model == null ? const SizedBox.expand() : ListenableBuilder(listenable: model, builder: (_, _) => _PlayerView(model: model)),
          ),
        ),
      )),
    );
  }
}

class _PlayerView extends StatefulWidget {
  const _PlayerView({required this.model});
  final PlayerModel model;

  @override
  State<_PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<_PlayerView> {
  final _nodes = PlayerTvNodes();
  late final _keys = PlayerTvKeys(widget.model, _nodes);
  late final _desktopKeys = PlayerDesktopKeys(widget.model);

  PlayerModel get model => widget.model;

  @override
  void dispose() {
    _nodes.dispose();
    super.dispose();
  }

  static const _scrim = BoxDecoration(
    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x99000000), Color(0x40000000), Color(0x99000000)]),
  );

  @override
  Widget build(BuildContext context) {
    final failed = model.core.failed;
    final visible = model.controlsVisible;
    final transport = visible && !failed;
    final pip = model.pipActive;
    final fit = switch (model.videoScale) {
      VideoScale.fit => BoxFit.contain,
      VideoScale.fill => BoxFit.cover,
      VideoScale.stretch => BoxFit.fill,
    };
    final view = Stack(fit: StackFit.expand, children: [
      model.core.engine.buildVideo(fit),
      isDesktop ? PlayerDesktopSurface(model: model) : PlayerGestureSurface(model: model),
      IgnorePointer(child: AnimatedOpacity(opacity: visible ? 1 : 0, duration: const Duration(milliseconds: 200), child: const DecoratedBox(decoration: _scrim))),
      if (!pip)
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: ExcludeFocus(
              excluding: isTelevision && !visible, // hidden controls take no D-pad focus
              child: IgnorePointer(
                ignoring: !visible,
                child: AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Column(children: [
                    PlayerTopBar(model: model),
                    Expanded(child: transport && !model.upNext.isCounting ? Center(child: PlayerTransport(model: model, playFocus: _nodes.play)) : const SizedBox.shrink()),
                    if (transport && !model.upNext.isCounting) PlayerBottomPanel(model: model, subtitlesFocus: _nodes.subtitles),
                  ]),
                ),
              ),
            ),
          ),
        ),
      if (!pip) PlayerHud(model: model),
      if (!visible && model.core.buffering && !model.core.paused) const Center(child: CircularProgressIndicator(color: Colors.white)),
      if (!pip && failed) PlayerErrorCard(model: model),
      if (!pip && model.upNext.isCounting) UpNextCard(model: model),
    ]);
    if (isDesktop) return Focus(autofocus: true, skipTraversal: true, onKeyEvent: _desktopKeys.onKey, child: view);
    if (!isTelevision) return view;
    // The focus left the player (the controls hid, a card went away): take it back, unless a menu or another screen is on top.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !model.closed && !_nodes.root.hasFocus && (ModalRoute.of(context)?.isCurrent ?? true)) _nodes.root.requestFocus();
    });
    return Focus(focusNode: _nodes.root, autofocus: true, skipTraversal: true, onKeyEvent: _keys.onKey, child: view);
  }
}
