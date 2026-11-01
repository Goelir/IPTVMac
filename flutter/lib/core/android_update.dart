import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_session.dart';

/// GitHub's own feed of the releases: plain github.com, so none of the 60-requests-an-hour limit of the API that made the Mac updater
/// switch to release.txt. The Android releases are published as "not the latest", so `releases/latest` cannot be used for them.
const androidReleasesFeed = 'https://github.com/Goelir/IPTVMac/releases.atom';

RegExp _tag(String channel) => RegExp('/releases/tag/$channel-v(\\d{1,4})\\.(\\d{1,4})\\.(\\d{1,4})(?=["\\s<])');

/// "android" or "windows": the tag prefix of the app that asks. Anything else would put arbitrary text into the pattern.
String _checked(String channel) {
  if (channel != 'android' && channel != 'windows') throw ArgumentError.value(channel, 'channel');
  return channel;
}

/// The newest stable Android version the feed names, e.g. "1.0.2", or null. The Mac releases and the pre-releases
/// ("android-v0.1.0-beta.1") do not match. Only three numbers are taken from the feed, never a link.
String? newestAndroidVersion(String feed, {String channel = 'android'}) {
  List<int>? best;
  for (final m in _tag(_checked(channel)).allMatches(feed)) {
    final v = [for (var i = 1; i <= 3; i++) int.parse(m[i]!)];
    if (best == null || _compare(v, best) > 0) best = v;
  }
  return best?.join('.');
}

List<int>? _parse(String v) {
  final m = RegExp(r'^(\d{1,4})\.(\d{1,4})\.(\d{1,4})').firstMatch(v);
  return m == null ? null : [for (var i = 1; i <= 3; i++) int.parse(m[i]!)];
}

int _compare(List<int> a, List<int> b) {
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i].compareTo(b[i]);
  }
  return 0;
}

/// [candidate] is a higher version than [current] ("1.0.3" vs "1.0.2"; a build suffix like "+5" is ignored). False when either is not a version.
bool isNewerVersion(String candidate, String current) {
  final a = _parse(candidate), b = _parse(current);
  return a != null && b != null && _compare(a, b) > 0;
}

/// The page of a release, built from a version that passed [newestAndroidVersion]: the app never opens an address taken from the feed.
Uri androidReleasePage(String version, {String channel = 'android'}) {
  if (_parse(version) == null || _parse(version)!.join('.') != version) throw ArgumentError.value(version, 'version');
  return Uri.https('github.com', '/Goelir/IPTVMac/releases/tag/${_checked(channel)}-v$version');
}

/// Asks the feed. Throws on a network failure.
Future<String?> fetchNewestAndroidVersion(http.Client client, {String channel = 'android'}) async {
  final bytes = await apiGet(client, Uri.parse(androidReleasesFeed), timeout: const Duration(seconds: 30), idleTimeout: const Duration(seconds: 20), maxBytes: 2000000);
  return newestAndroidVersion(utf8.decode(bytes, allowMalformed: true), channel: channel);
}

/// The APK file name part of the release for this phone: the first of its processor types (best first) that the release has a file for.
/// The TV files ("tv-32bit", "tv-64bit") are not offered here: the in-app update is for phones and tablets.
String? apkAbi(List<String> supportedAbis) {
  for (final a in supportedAbis) {
    if (const {'arm64-v8a', 'armeabi-v7a', 'x86_64'}.contains(a)) return a;
  }
  return null;
}

/// The file of [version] for [abi], built from values that passed [newestAndroidVersion] and [apkAbi]: never an address taken from the feed.
/// The release's key is checked by Android itself: it refuses an update that is not signed with the key of the installed app.
Uri androidApkUrl(String version, String abi) {
  if (_parse(version)?.join('.') != version || apkAbi([abi]) != abi) throw ArgumentError.value('$version $abi');
  return Uri.https('github.com', '/Goelir/IPTVMac/releases/download/android-v$version/IPTVMac-Android-$version-$abi.apk');
}

/// Saves [url] as `update.apk` in [dir] (replacing an older one) and returns it. [onProgress] gets 0..1 when the size is known.
/// Throws when the answer is not a complete download over https (the address redirects to GitHub's file server).
Future<File> downloadApk(http.Client client, Uri url, Directory dir, {void Function(double)? onProgress, int maxBytes = 150000000}) async {
  final res = await client.send(http.Request('GET', url)).timeout(const Duration(seconds: 30));
  if (res.statusCode != 200 || (res.request?.url.scheme ?? 'https') != 'https') throw HttpException('update download: ${res.statusCode}', uri: url);
  final total = res.contentLength;
  if (total != null && total > maxBytes) throw const HttpException('the update is larger than expected');
  await dir.create(recursive: true);
  final file = File('${dir.path}/update.apk');
  final sink = file.openWrite();
  var got = 0;
  try {
    await for (final chunk in res.stream.timeout(const Duration(seconds: 30))) {
      got += chunk.length;
      if (got > maxBytes) throw const HttpException('the update is larger than expected');
      sink.add(chunk);
      if (total != null && total > 0) onProgress?.call(got / total);
    }
    await sink.close();
    if (total != null && got != total) throw const HttpException('the update download was cut short');
    return file;
  } catch (_) {
    await sink.close().catchError((_) {});
    if (file.existsSync()) file.deleteSync();
    rethrow;
  }
}
