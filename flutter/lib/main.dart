import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:iptvmac/app/app.dart';
import 'package:iptvmac/app/demo_seed.dart';
import 'package:iptvmac/app/device.dart';
import 'package:iptvmac/app/library_model.dart';
import 'package:iptvmac/app/secure_secret_store.dart';
import 'package:iptvmac/app/sync_worker.dart';
import 'package:iptvmac/core/app_database.dart';
import 'package:iptvmac/downloads/open_downloads.dart';
import 'package:media_kit/media_kit.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final dir = await getApplicationSupportDirectory();
  final path = '${dir.path}/iptv.sqlite';
  AppDatabase db;
  String? movedAside, failure;
  try {
    final opened = AppDatabase.openRecovering(path);
    db = opened.db;
    movedAside = opened.movedAside;
  } catch (e) {
    // No disk or no access: an in-memory database keeps the app usable, nothing is saved this session.
    db = AppDatabase.memory();
    failure = e.toString();
  }
  isDesktop = Platform.isWindows;
  isTelevision = await detectTelevision();
  if (isTelevision) await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky); // a TV has no bars; an emulator or box that draws them gets none
  final model = LibraryModel(
    db: db,
    secrets: SecureSecretStore(),
    prefs: await SharedPreferences.getInstance(),
    dbPath: path,
    syncRunner: failure == null ? null : inlineSyncRunner(db),
    dbMovedAside: movedAside,
    appVersion: storeBuild ? null : (await PackageInfo.fromPlatform()).version, // null: no GitHub update check in store builds
    onClearImages: () async {
      PaintingBinding.instance.imageCache.clear();
      await DefaultCacheManager().emptyCache();
    },
  );
  if (failure != null) model.syncMessage = failure;
  await model.loadAccounts(); // before the first frame: a returning user must not see the welcome screen for an instant
  final downloads = await openDownloads(model, dir);
  runApp(IptvApp(model: model, downloads: downloads));
  await model.start();
  if (kDebugMode && const bool.fromEnvironment('DEMO_SEED')) await seedDemo(model);
}
