import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/device.dart';
import 'player_model.dart';

/// The player on a TV remote (Android TV, Google TV, Fire TV): keys, focus and the focus ring. Nothing here runs unless
/// [isTelevision] is set, so phones and tablets behave as before.

/// How long the controls stay up after the last key on a TV.
const tvHideAfter = Duration(seconds: 5);

/// A held seek key (Left/Right, fast-forward) seeks one step at first, then faster: x2 after three repeats, up to x4. A repeat that
/// comes sooner than [gap] after the last seek is dropped (a remote repeats 20-30 times a second).
class SeekRepeat {
  static const gap = Duration(milliseconds: 200);
  int _n = 0;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  /// Seconds to seek for this key event; 0 when a repeat came too soon.
  double seconds(KeyEvent e, int step, DateTime now) {
    if (e is KeyRepeatEvent) {
      if (now.difference(_last) < gap) return 0;
      _n++;
    } else {
      _n = 0;
    }
    _last = now;
    return step * (1 + _n ~/ 3).clamp(1, 4).toDouble();
  }
}

/// The three nodes the key layer moves focus to: the screen itself (no control focused: the keys zap and seek), the play button and
/// the subtitles button.
class PlayerTvNodes {
  final root = FocusNode(debugLabel: 'player');
  final play = FocusNode(debugLabel: 'player-play');
  final subtitles = FocusNode(debugLabel: 'player-subtitles');

  void dispose() {
    root.dispose();
    play.dispose();
    subtitles.dispose();
  }
}

/// The key map. It sits on the Focus around the whole player, so it sees the keys the focused control did not take: with a control
/// focused (the controls are up and the user moves around them) the arrows and Select are left to the normal focus traversal; with
/// the screen itself focused they seek, zap and toggle. Left/Right are always time (Right = forward), also in a right-to-left language.
class PlayerTvKeys {
  PlayerTvKeys(this.model, this.nodes);
  final PlayerModel model;
  final PlayerTvNodes nodes;
  final _held = <LogicalKeyboardKey>{}; // keys whose press we took: their repeats and release must not reach anyone else

  static final _select = {LogicalKeyboardKey.select, LogicalKeyboardKey.enter, LogicalKeyboardKey.numpadEnter, LogicalKeyboardKey.gameButtonA};
  static final _back = {LogicalKeyboardKey.goBack, LogicalKeyboardKey.escape};
  static final _info = {LogicalKeyboardKey.contextMenu, LogicalKeyboardKey.info, LogicalKeyboardKey.settings};
  static final _repeating = {LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.mediaFastForward, LogicalKeyboardKey.mediaRewind};

  /// Like a TV remote: Up is channel up (the next one in the list, as CH+), Down the previous one.
  static const _zapUp = 1;

  KeyEventResult onKey(FocusNode _, KeyEvent e) {
    final k = e.logicalKey;
    if (e is KeyUpEvent) return _held.remove(k) ? KeyEventResult.handled : KeyEventResult.ignored;
    if (model.closed) return KeyEventResult.ignored;
    if (e is KeyRepeatEvent && !_repeating.contains(k)) return _held.contains(k) ? KeyEventResult.handled : KeyEventResult.ignored;
    model.keyActivity();
    final r = _handle(k, e);
    if (r == KeyEventResult.handled) _held.add(k);
    return r;
  }

  KeyEventResult _handle(LogicalKeyboardKey k, KeyEvent e) {
    const handled = KeyEventResult.handled;
    final step = model.prefs.seekStep;
    if (_back.contains(k)) {
      model.back();
      return handled;
    }
    switch (k) {
      case LogicalKeyboardKey.mediaPlayPause:
        model.togglePause();
        return handled;
      case LogicalKeyboardKey.mediaPlay:
        model.remotePlay(true);
        return handled;
      case LogicalKeyboardKey.mediaPause:
        model.remotePlay(false);
        return handled;
      case LogicalKeyboardKey.mediaStop:
        model.close();
        return handled;
      case LogicalKeyboardKey.mediaFastForward || LogicalKeyboardKey.mediaRewind:
        final secs = model.seekRepeat.seconds(e, step, model.now);
        model.remoteSeek(k == LogicalKeyboardKey.mediaRewind ? -secs : secs);
        return handled;
      case LogicalKeyboardKey.mediaTrackNext:
        model.goNext();
        return handled;
      case LogicalKeyboardKey.mediaTrackPrevious:
        model.previous();
        return handled;
      case LogicalKeyboardKey.channelUp:
        model.zap(1);
        return handled;
      case LogicalKeyboardKey.channelDown:
        model.zap(-1);
        return handled;
    }
    if (_info.contains(k)) {
      _menu();
      return handled;
    }
    if (model.core.failed || model.upNext.isCounting || !nodes.root.hasPrimaryFocus) return KeyEventResult.ignored; // a card or a control has the focus
    if (_select.contains(k)) {
      model.togglePause();
      _focus(nodes.play);
      return handled;
    }
    switch (k) {
      case LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.arrowRight:
        if (model.isLive) return model.controlsVisible ? KeyEventResult.ignored : handled;
        final secs = model.seekRepeat.seconds(e, step, model.now);
        model.remoteSeek(k == LogicalKeyboardKey.arrowLeft ? -secs : secs);
        return handled;
      case LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.arrowDown:
        if (model.isLive) {
          model.zap(k == LogicalKeyboardKey.arrowUp ? _zapUp : -_zapUp);
        } else {
          _focus(nodes.play);
        }
        return handled;
    }
    return KeyEventResult.ignored;
  }

  /// Menu / Info: the details of the item when the provider has any, else the controls with the subtitles button focused.
  void _menu() {
    final item = model.request.item;
    if (item != null && model.host.hasDetails(item)) {
      model.host.showDetails(item);
      model.touchControls();
    } else {
      _focus(nodes.subtitles);
    }
  }

  /// Shows the controls and, once they are built, moves the focus to [node].
  void _focus(FocusNode node) {
    model.touchControls();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!model.closed && node.context != null && node.canRequestFocus) node.requestFocus();
    });
  }
}

/// Wraps [child] in the focus ring on a TV; as is everywhere else.
Widget tvRing(Widget child, {double radius = 24}) => isTelevision ? PlayerFocusRing(radius: radius, child: child) : child;

/// A control that is not focusable by itself (a GestureDetector) made focusable on a TV: Select calls [onActivate].
Widget tvFocusable({required Widget child, required VoidCallback onActivate, FocusNode? focusNode, double radius = 24}) => !isTelevision
    ? child
    : PlayerFocusRing(
        radius: radius,
        child: FocusableActionDetector(
          focusNode: focusNode,
          actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => onActivate())},
          child: child,
        ),
      );

/// Menus and sheets of the player live under the Navigator, not under the player: their sliders must hand Up/Down to the focus
/// traversal (the directional navigation mode) instead of taking them.
Widget tvDirectional(BuildContext context, Widget child) =>
    isTelevision ? MediaQuery(data: MediaQuery.of(context).copyWith(navigationMode: NavigationMode.directional), child: child) : child;

/// A white ring around the control that has the focus (or one of its parts): big enough to see from the couch.
class PlayerFocusRing extends StatefulWidget {
  const PlayerFocusRing({super.key, required this.child, this.radius = 24});
  final Widget child;
  final double radius;

  @override
  State<PlayerFocusRing> createState() => _PlayerFocusRingState();
}

class _PlayerFocusRingState extends State<PlayerFocusRing> {
  bool _on = false;

  @override
  Widget build(BuildContext context) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (f) => setState(() => _on = f),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: _on ? Colors.white : Colors.transparent, width: 3),
          ),
          child: widget.child,
        ),
      );
}
