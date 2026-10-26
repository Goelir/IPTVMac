import 'dart:async';

import 'package:flutter/services.dart';

/// Whether the app runs on a TV (Android TV, Google TV, Fire TV): a remote control with a D-pad and no touch screen. Set once at start
/// by [detectTelevision]; widgets read it to lay out for the couch (big focus rings, rows to move along) and tests set it.
bool isTelevision = false;

/// A build for an app store (`--dart-define=STORE_BUILD=true`): the store updates the app, so the app does not look for APK updates on
/// GitHub (no banner, no setting): Google Play does not allow an app to update itself outside the store, and the GitHub APK is signed
/// with a different key anyway.
const bool storeBuild = bool.fromEnvironment('STORE_BUILD');

/// Asks Android (UiModeManager / the leanback feature). `--dart-define=FORCE_TV=true` forces TV mode on any device, for testing with an
/// emulator.
Future<bool> detectTelevision() async {
  if (const bool.fromEnvironment('FORCE_TV')) return true;
  try {
    return await const MethodChannel('io.github.goelir.iptvmac/pip').invokeMethod<bool>('isTelevision') ?? false;
  } catch (_) {
    return false; // not Android, or a test
  }
}

/// What has to stop before the app leaves on a TV (the player closes and saves its position). Hooks add and remove themselves.
final tvExitHooks = <void Function()>[];

/// Leaves the app: stops the hooks first, so no sound goes on in the background, then finishes the activity. Tests replace [tvExit].
Future<void> exitApp() async {
  for (final h in List.of(tvExitHooks)) {
    h();
  }
  await SystemNavigator.pop();
}

Future<void> Function() tvExit = exitApp;

/// A long press of Back on a TV remote closes the app, wherever it is (a short press only goes up one level). Fed with every key event;
/// returns true when the event is used up (the repeats of the long press, and its key-up).
class LongBackExit {
  LongBackExit({this.hold = const Duration(milliseconds: 700), DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
  final Duration hold;
  final DateTime Function() _clock;
  DateTime? _downAt;
  var _fired = false;

  static final _keys = {LogicalKeyboardKey.goBack, LogicalKeyboardKey.escape};

  bool handle(KeyEvent e) {
    if (!_keys.contains(e.logicalKey)) return false;
    if (e is KeyDownEvent) {
      _downAt = _clock();
      _fired = false;
      return false; // a short press goes on as a normal Back
    }
    if (e is KeyRepeatEvent) {
      if (_fired) return true;
      final at = _downAt;
      if (at == null || _clock().difference(at) < hold) return false;
      _fired = true;
      unawaited(tvExit());
      return true;
    }
    if (e is KeyUpEvent) {
      final was = _fired;
      _fired = false;
      _downAt = null;
      return was; // the key-up of a long press must not also go Back
    }
    return false;
  }
}
