import 'dart:async';

import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app/device.dart';
import 'media_session.dart';
import 'player_system.dart';

/// The Android side: system bars and orientation, wake lock, brightness and volume, Picture in Picture (MainActivity.kt, over the
/// `io.github.goelir.iptvmac/pip` channel) and the media session.
class AndroidPlayerSystem extends PlayerSystem {
  AndroidPlayerSystem() {
    _channel.setMethodCallHandler(_fromNative);
    VolumeController.instance.showSystemUI = false;
  }

  static const _channel = MethodChannel('io.github.goelir.iptvmac/pip');
  final _session = PlayerMediaSession();
  bool _awake = false;

  Future<dynamic> _fromNative(MethodCall call) async {
    switch (call.method) {
      case 'pipChanged':
        pipChanges.add(call.arguments as bool);
      case 'pipAction':
        pipActions.add(null);
    }
  }

  @override
  Future<void> enter({required bool lockLandscape}) async {
    if (!isTelevision) unawaited(_channel.invokeMethod<void>('requestNotificationPermission').catchError((Object _) {})); // Android 13+: the playback notification needs it
    if (isTelevision) return; // a TV has no system bars to hide and is always landscape: no "Viewing full screen" prompt
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (lockLandscape) await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  }

  @override
  Future<void> setPortrait(bool portrait) => SystemChrome.setPreferredOrientations(
      portrait ? [DeviceOrientation.portraitUp] : [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

  @override
  Future<void> exit() async {
    updatePip(aspect: 0, playing: false, autoEnter: false);
    setAwake(false);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(const []); // the previous orientation rules are the app's own: no restriction
  }

  @override
  void setAwake(bool awake) {
    if (awake == _awake) return;
    _awake = awake;
    unawaited(WakelockPlus.toggle(enable: awake).catchError((Object _) {}));
  }

  @override
  Future<double?> brightness() async {
    try {
      return await ScreenBrightness.instance.application;
    } catch (_) {
      return null;
    }
  }

  @override
  void setBrightness(double v) => unawaited(ScreenBrightness.instance.setApplicationScreenBrightness(v).catchError((Object _) {}));

  @override
  void restoreBrightness() => unawaited(ScreenBrightness.instance.resetApplicationScreenBrightness().catchError((Object _) {}));

  @override
  Future<double?> volume() async {
    try {
      return await VolumeController.instance.getVolume();
    } catch (_) {
      return null;
    }
  }

  @override
  void setVolume(double v) => unawaited(VolumeController.instance.setVolume(v).catchError((Object _) {}));

  @override
  Future<bool> isPipSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> enterPip({required double aspect, required bool playing}) async {
    try {
      return await _channel.invokeMethod<bool>('enter', {'aspect': aspect, 'playing': playing}) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  void updatePip({required double aspect, required bool playing, required bool autoEnter}) {
    unawaited(_channel.invokeMethod<void>('update', {'aspect': aspect, 'playing': playing, 'autoEnter': autoEnter}).catchError((Object _) {}));
  }

  @override
  Future<void> activate(PlayerCommands commands) async {
    // Never let the notification or audio focus code stop playback from starting.
    try {
      await _session.activate(commands);
    } catch (_) {}
  }

  @override
  void updateNowPlaying(NowPlaying n) => _session.update(n);

  @override
  void userChose() => _session.userChose();

  @override
  Future<void> deactivate() async {
    try {
      await _session.deactivate();
    } catch (_) {}
  }
}
