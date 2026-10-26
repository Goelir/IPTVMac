import 'package:flutter/services.dart';

/// Whether the app runs on a TV (Android TV, Google TV, Fire TV): a remote control with a D-pad and no touch screen. Set once at start
/// by [detectTelevision]; widgets read it to lay out for the couch (big focus rings, rows to move along) and tests set it.
bool isTelevision = false;

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
