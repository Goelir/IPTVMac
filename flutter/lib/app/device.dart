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
