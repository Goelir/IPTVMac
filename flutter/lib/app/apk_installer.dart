import 'dart:io';

import 'package:flutter/services.dart';
import 'package:iptvmac/app/device.dart';
import 'package:path_provider/path_provider.dart';

/// What the in-app update asks of the phone (the native side is MainActivity.kt). Tests replace [apkInstaller].
class ApkInstaller {
  static const _channel = MethodChannel('io.github.goelir.iptvmac/pip');

  /// Phones and tablets with the Android app (not a store build, the TV or Windows): the update is downloaded and installed from the app.
  bool get supported => Platform.isAndroid && !isDesktop && !isTelevision && !storeBuild;

  /// Where the APK is saved: the folder the app's FileProvider shares with the system installer (cache/updates).
  Future<Directory> folder() async => Directory('${(await getTemporaryDirectory()).path}/updates');

  /// The processor types of the phone, best first ("arm64-v8a", "armeabi-v7a", ...).
  Future<List<String>> abis() async => (await _channel.invokeListMethod<String>('abis')) ?? const [];

  /// Whether the user has allowed this app to install apps ("Install unknown apps").
  Future<bool> canInstall() async => await _channel.invokeMethod<bool>('canInstall') ?? false;

  /// Opens the system screen where that is allowed for this app.
  Future<void> openSettings() => _channel.invokeMethod('openInstallSettings');

  /// Hands the file to the system installer, which asks the user to confirm. False when it could not be started.
  Future<bool> install(String path) async => await _channel.invokeMethod<bool>('installApk', {'path': path}) ?? false;
}

ApkInstaller apkInstaller = ApkInstaller();

/// How often the app looks, after opening the system screen, whether the user has allowed the install (tests make it short).
Duration apkPermissionPoll = const Duration(seconds: 1);
