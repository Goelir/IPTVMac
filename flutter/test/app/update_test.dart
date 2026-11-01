import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http;

import 'package:iptvmac/app/apk_installer.dart';
import 'package:iptvmac/app/library_model.dart';
import 'package:iptvmac/core/android_update.dart';
import 'package:iptvmac/ui/widgets.dart';

import 'harness.dart';

String feed(List<String> tags) =>
    '<feed>${[for (final t in tags) '<entry><link rel="alternate" href="https://github.com/Goelir/IPTVMac/releases/tag/$t"/></entry>'].join()}</feed>';

void main() {
  test('a newer version in the feed becomes the banner; dismissing hides it until an even newer one comes', () async {
    final h = await Harness.createPlain(appVersion: '1.0.2');
    h.provider.feed = feed(['android-v1.0.3', 'android-v1.0.2', 'v0.9.3']);
    expect(h.model.updateAvailable, isNull, reason: 'nothing known yet');
    await h.model.checkForUpdate();
    expect(h.model.updateAvailable, '1.0.3');
    h.model.dismissUpdate();
    expect(h.model.updateAvailable, isNull);
    expect(h.model.newerVersion, '1.0.3', reason: 'Settings still says so');
    h.provider.feed = feed(['android-v1.0.4', 'android-v1.0.3']);
    await h.model.checkForUpdate(manual: true);
    expect(h.model.updateAvailable, '1.0.4');
  });

  test('no banner when the installed version is the newest or newer', () async {
    final h = await Harness.createPlain(appVersion: '1.0.3');
    h.provider.feed = feed(['android-v1.0.3', 'android-v1.0.2']);
    await h.model.checkForUpdate();
    expect(h.model.updateAvailable, isNull);
    expect(h.model.newerVersion, isNull);
    expect(h.model.updateCheck, UpdateCheck.done);
  });

  test('automatic checks run at most every 6 hours and obey the switch; a manual check always runs', () async {
    final h = await Harness.createPlain(appVersion: '1.0.2');
    h.provider.feed = feed(['android-v1.0.2']);
    await h.model.checkForUpdate();
    await h.model.checkForUpdate();
    expect(h.provider.feedCalls, 1, reason: 'the second automatic check is too soon');
    await h.model.checkForUpdate(manual: true);
    expect(h.provider.feedCalls, 2);
    final off = await Harness.createPlain(appVersion: '1.0.2', prefs: {'autoCheckUpdates': false});
    await off.model.checkForUpdate();
    expect(off.provider.feedCalls, 0, reason: 'switched off');
    await off.model.checkForUpdate(manual: true);
    expect(off.provider.feedCalls, 1);
  });

  test('a failing check says so and keeps what was known; without a version there is no check at all', () async {
    final h = await Harness.createPlain(appVersion: '1.0.2');
    h.provider.feed = feed(['android-v1.0.3']);
    await h.model.checkForUpdate();
    h.provider.fail = true;
    await h.model.checkForUpdate(manual: true);
    expect(h.model.updateCheck, UpdateCheck.failed);
    expect(h.model.updateAvailable, '1.0.3');
    final dev = await Harness.createPlain();
    await dev.model.checkForUpdate(manual: true);
    expect(dev.provider.feedCalls, 0);
  });

  testWidgets('the banner offers the release page and can be closed', (t) async {
    final h = await Harness.create(t, withAccount: true, sync: true, appVersion: '1.0.2');
    h.provider.feed = feed(['android-v1.0.3']);
    await t.runAsync(h.model.checkForUpdate);
    final opened = <String>[];
    final old = openUpdatePage;
    openUpdatePage = (v) async => opened.add(v);
    addTearDown(() => openUpdatePage = old);
    await h.pumpApp(t);
    await go(t);
    expect(find.text('Version 1.0.3 is available'), findsOneWidget);
    await t.tap(find.text('Update now'));
    expect(opened, ['1.0.3']);
    await t.tap(find.byTooltip('Later'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('update-banner')), findsNothing);
  });

  testWidgets('Settings: the check button asks the feed and answers; the switch turns the automatic check off', (t) async {
    final h = await Harness.create(t, withAccount: true, sync: true, appVersion: '1.0.2');
    h.provider.feed = feed(['android-v1.0.2']);
    await h.pumpApp(t);
    await go(t);
    await t.tap(find.text('Settings').last);
    await go(t);
    await t.scrollUntilVisible(find.byKey(const Key('check-update-tile')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Current version: 1.0.2'), findsOneWidget);
    await t.ensureVisible(find.byKey(const Key('check-update-tile')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('check-update-tile')));
    await go(t);
    expect(h.provider.feedCalls, 1);
    expect(find.text('You have the latest version'), findsOneWidget);
    await t.ensureVisible(find.byKey(const Key('auto-update-switch')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('auto-update-switch')));
    await t.pumpAndSettle();
    expect(h.model.prefs.autoCheckUpdates, false);
  });

  test('the APK of a phone: its processor type picks the file, and only a version and a type that passed the checks make an address', () {
    expect(apkAbi(['arm64-v8a', 'armeabi-v7a']), 'arm64-v8a');
    expect(apkAbi(['x86', 'x86_64']), 'x86_64');
    expect(apkAbi(['mips']), isNull);
    expect(androidApkUrl('1.0.6', 'armeabi-v7a').toString(),
        'https://github.com/Goelir/IPTVMac/releases/download/android-v1.0.6/IPTVMac-Android-1.0.6-armeabi-v7a.apk');
    expect(() => androidApkUrl('1.0.6/../x', 'arm64-v8a'), throwsArgumentError);
    expect(() => androidApkUrl('1.0.6', 'tv-64bit'), throwsArgumentError);
  });

  group('the in-app update', () {
    late Directory dir;
    late FakeInstaller fake;
    final oldInstaller = apkInstaller, oldPoll = apkPermissionPoll;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('apk_update');
      fake = FakeInstaller(Directory('${dir.path}/updates'));
      apkInstaller = fake;
      apkPermissionPoll = const Duration(milliseconds: 1);
    });
    tearDown(() {
      apkInstaller = oldInstaller;
      apkPermissionPoll = oldPoll;
      dir.deleteSync(recursive: true);
    });

    test('downloads the file of this phone and hands it to the installer', () async {
      final h = await Harness.createPlain(appVersion: '1.0.2');
      h.provider.apk = List.filled(5000, 7);
      final seen = <ApkInstall>[];
      h.model.addListener(() => seen.add(h.model.apkInstall));
      await h.model.installUpdate('1.0.3');
      expect(fake.installed.single, '${dir.path}/updates/update.apk');
      expect(File(fake.installed.single).lengthSync(), 5000);
      expect(h.provider.calls.last.path, endsWith('/android-v1.0.3/IPTVMac-Android-1.0.3-arm64-v8a.apk'));
      expect(h.model.apkInstall, ApkInstall.idle);
      expect(seen, contains(ApkInstall.downloading));
    });

    test('when installing is not allowed the system screen opens, and the update goes on once the user allows it', () async {
      final h = await Harness.createPlain(appVersion: '1.0.2');
      h.provider.apk = [1, 2, 3];
      fake.allowed = false;
      fake.onOpenSettings = () => fake.allowed = true;
      await h.model.installUpdate('1.0.3');
      expect(fake.settingsOpened, 1);
      expect(fake.installed, hasLength(1));
    });

    test('a failed download, a refusal to allow and an installer that does not start all end as "failed"; nothing is left behind', () async {
      final h = await Harness.createPlain(appVersion: '1.0.2');
      await h.model.installUpdate('1.0.3'); // the file is not there (404)
      expect(h.model.apkInstall, ApkInstall.failed);
      expect(fake.installed, isEmpty);
      h.provider.apk = [1, 2, 3];
      fake.startOk = false;
      await h.model.installUpdate('1.0.3');
      expect(h.model.apkInstall, ApkInstall.failed);
      fake.startOk = true;
      fake.allowed = false; // the user never switches it on: gives up after the wait
      await h.model.installUpdate('1.0.3');
      expect(h.model.apkInstall, ApkInstall.failed);
    });

    test('a download that is cut short or too large is refused and deleted', () async {
      final client = http.MockClient.streaming((r, _) async => http.StreamedResponse(Stream.value([1, 2, 3]), 200, contentLength: 10, request: r));
      final folder = Directory('${dir.path}/x');
      await expectLater(downloadApk(client, Uri.https('github.com', '/a.apk'), folder), throwsA(isA<HttpException>()));
      expect(File('${folder.path}/update.apk').existsSync(), isFalse);
      final big = http.MockClient.streaming((r, _) async => http.StreamedResponse(Stream.value([1, 2, 3]), 200, contentLength: 3, request: r));
      await expectLater(downloadApk(big, Uri.https('github.com', '/a.apk'), folder, maxBytes: 2), throwsA(isA<HttpException>()));
    });

    testWidgets('the banner: Update now installs from the app; after a failure it offers the release page', (t) async {
      final h = await Harness.create(t, withAccount: true, sync: true, appVersion: '1.0.2');
      h.provider.feed = feed(['android-v1.0.3']);
      await t.runAsync(h.model.checkForUpdate);
      final opened = <String>[];
      final old = openUpdatePage;
      openUpdatePage = (v) async => opened.add(v);
      addTearDown(() => openUpdatePage = old);
      await h.pumpApp(t);
      await go(t);
      await t.runAsync(() async {
        await t.tap(find.byKey(const Key('update-now')));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await go(t);
      expect(opened, isEmpty, reason: 'the page is only the fallback');
      expect(h.model.apkInstall, ApkInstall.failed, reason: 'the fake server has no file');
      expect(find.text('Update failed'), findsOneWidget);
      await t.tap(find.text('Download manually'));
      expect(opened, ['1.0.3']);
    });
  });
}

class FakeInstaller extends ApkInstaller {
  FakeInstaller(this._folder);
  final Directory _folder;
  bool allowed = true, startOk = true;
  int settingsOpened = 0;
  void Function()? onOpenSettings;
  final installed = <String>[];

  @override
  bool get supported => true;
  @override
  Future<Directory> folder() async => _folder;
  @override
  Future<List<String>> abis() async => ['arm64-v8a', 'armeabi-v7a'];
  @override
  Future<bool> canInstall() async => allowed;
  @override
  Future<void> openSettings() async {
    settingsOpened++;
    onOpenSettings?.call();
  }

  @override
  Future<bool> install(String path) async {
    if (startOk) installed.add(path);
    return startOk;
  }
}
