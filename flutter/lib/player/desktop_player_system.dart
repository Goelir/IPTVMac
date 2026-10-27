import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'player_system.dart';

/// The player's seat in Windows: full screen through media_kit_video's own window channel, and the display kept awake while a
/// picture plays. Volume is the engine's (the player model), there is no brightness and no Picture in Picture.
class DesktopPlayerSystem extends PlayerSystem {
  static const _window = MethodChannel('com.alexmercerind/media_kit_video');
  bool _full = false;

  @override
  Future<void> setFullscreen(bool on) async {
    _full = on;
    try {
      await _window.invokeMethod<void>(on ? 'Utils.EnterNativeFullscreen' : 'Utils.ExitNativeFullscreen');
    } catch (_) {} // no plugin (a test): nothing to do
  }

  @override
  void setAwake(bool awake) {
    try {
      WakelockPlus.toggle(enable: awake).catchError((Object _) {});
    } catch (_) {}
  }

  @override
  Future<void> exit() async {
    if (_full) await setFullscreen(false);
    setAwake(false);
  }
}
