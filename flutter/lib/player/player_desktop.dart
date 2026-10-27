import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'player_model.dart';

/// The player with a mouse and a keyboard (Windows). Nothing here runs unless `isDesktop` is set.

/// What a key does. Kept apart from the widget so the map is tested without a screen.
enum DesktopAction { pause, back, forward, bigBack, bigForward, volumeUp, volumeDown, mute, fullscreen, escape, next, previous, slower, faster, none }

DesktopAction desktopAction(LogicalKeyboardKey k, {bool shift = false}) {
  if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.keyK || k == LogicalKeyboardKey.mediaPlayPause) return DesktopAction.pause;
  if (k == LogicalKeyboardKey.arrowLeft) return shift ? DesktopAction.bigBack : DesktopAction.back;
  if (k == LogicalKeyboardKey.arrowRight) return shift ? DesktopAction.bigForward : DesktopAction.forward;
  if (k == LogicalKeyboardKey.arrowUp) return DesktopAction.volumeUp;
  if (k == LogicalKeyboardKey.arrowDown) return DesktopAction.volumeDown;
  if (k == LogicalKeyboardKey.keyM) return DesktopAction.mute;
  if (k == LogicalKeyboardKey.keyF || k == LogicalKeyboardKey.f11) return DesktopAction.fullscreen;
  if (k == LogicalKeyboardKey.escape) return DesktopAction.escape;
  if (k == LogicalKeyboardKey.pageUp || k == LogicalKeyboardKey.mediaTrackNext) return DesktopAction.next;
  if (k == LogicalKeyboardKey.pageDown || k == LogicalKeyboardKey.mediaTrackPrevious) return DesktopAction.previous;
  if (k == LogicalKeyboardKey.bracketLeft) return DesktopAction.slower;
  if (k == LogicalKeyboardKey.bracketRight) return DesktopAction.faster;
  return DesktopAction.none;
}

/// Space or K pause, Left/Right seek (Shift: six steps), Up/Down and M the volume, F or F11 full screen, Esc leaves full screen then
/// the player, Page Up/Down the next and previous channel or episode, [ and ] the speed. Left/Right are always time, also in a
/// right-to-left language.
class PlayerDesktopKeys {
  PlayerDesktopKeys(this.model);
  final PlayerModel model;

  static const volumeStep = 0.05;
  static const speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0];

  KeyEventResult onKey(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent || model.closed) return KeyEventResult.ignored;
    final a = desktopAction(e.logicalKey, shift: HardwareKeyboard.instance.isShiftPressed);
    if (a == DesktopAction.none) return KeyEventResult.ignored;
    final repeat = e is KeyRepeatEvent;
    if (repeat && a != DesktopAction.back && a != DesktopAction.forward && a != DesktopAction.bigBack && a != DesktopAction.bigForward && a != DesktopAction.volumeUp && a != DesktopAction.volumeDown) {
      return KeyEventResult.handled; // a held key does not toggle or flip again and again
    }
    final step = model.prefs.seekStep.toDouble();
    switch (a) {
      case DesktopAction.pause:
        model.togglePause();
      case DesktopAction.back:
        model.remoteSeek(-step);
      case DesktopAction.forward:
        model.remoteSeek(step);
      case DesktopAction.bigBack:
        model.remoteSeek(-step * 6);
      case DesktopAction.bigForward:
        model.remoteSeek(step * 6);
      case DesktopAction.volumeUp:
        model.volumeBy(volumeStep);
      case DesktopAction.volumeDown:
        model.volumeBy(-volumeStep);
      case DesktopAction.mute:
        model.toggleMute();
      case DesktopAction.fullscreen:
        model.toggleFullscreen();
      case DesktopAction.escape:
        model.escape();
      case DesktopAction.next:
        model.isLive ? model.zap(1) : model.goNext();
      case DesktopAction.previous:
        model.isLive ? model.zap(-1) : model.previous();
      case DesktopAction.slower || DesktopAction.faster:
        if (!model.isLive) model.setSpeed(_nextSpeed(model.core.speed, a == DesktopAction.faster));
      case DesktopAction.none:
        break;
    }
    return KeyEventResult.handled;
  }

  /// The next stop of [speeds] above or below [current].
  static double _nextSpeed(double current, bool up) {
    if (up) return speeds.firstWhere((s) => s > current + 1e-6, orElse: () => speeds.last);
    return speeds.lastWhere((s) => s < current - 1e-6, orElse: () => speeds.first);
  }
}

/// The layer over the picture: a click pauses, a double click fills the screen, the wheel changes the volume, moving the mouse shows
/// the controls, and the pointer hides with them while a picture plays.
class PlayerDesktopSurface extends StatelessWidget {
  const PlayerDesktopSurface({super.key, required this.model});
  final PlayerModel model;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: model.controlsVisible || model.core.paused ? SystemMouseCursors.basic : SystemMouseCursors.none,
        onHover: (_) => model.controls.shown ? model.keyActivity() : model.touchControls(),
        child: Listener(
          onPointerSignal: (s) {
            if (s is PointerScrollEvent && s.scrollDelta.dy != 0) model.volumeBy(s.scrollDelta.dy < 0 ? PlayerDesktopKeys.volumeStep : -PlayerDesktopKeys.volumeStep);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: model.togglePause,
            onDoubleTap: model.toggleFullscreen,
          ),
        ),
      );
}
