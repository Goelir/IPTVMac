import 'package:flutter_test/flutter_test.dart';
import 'package:iptvmac/core/android_update.dart';

import 'support.dart';

String feed(List<String> tags) => '<feed>${[for (final t in tags) '<entry><link rel="alternate" type="text/html" href="https://github.com/Goelir/IPTVMac/releases/tag/$t"/><title>x</title></entry>'].join()}</feed>';

void main() {
  test('the newest stable Android version of the feed, ignoring Mac releases and pre-releases', () {
    expect(newestAndroidVersion(feed(['android-v1.0.2', 'v0.9.3', 'android-v1.0.1', 'android-v1.0.0', 'android-v0.1.0-beta.2'])), '1.0.2');
    expect(newestAndroidVersion(feed(['android-v1.0.9', 'android-v1.0.10', 'android-v1.0.2'])), '1.0.10', reason: 'numbers, not text');
    expect(newestAndroidVersion(feed(['android-v1.2.0', 'android-v1.10.0', 'android-v2.0.0'])), '2.0.0');
    expect(newestAndroidVersion(feed(['v0.9.3', 'android-v0.1.0-beta.2'])), isNull);
    expect(newestAndroidVersion(''), isNull);
    expect(newestAndroidVersion('<html>blocked</html>'), isNull);
  });

  test('the Windows app follows its own tags, not the Android ones', () {
    final f = feed(['android-v1.0.9', 'windows-v1.0.2', 'windows-v1.0.10', 'v0.9.3', 'windows-v2.0.0-beta.1']);
    expect(newestAndroidVersion(f, channel: 'windows'), '1.0.10');
    expect(newestAndroidVersion(f), '1.0.9');
    expect(newestAndroidVersion(feed(['android-v1.0.9']), channel: 'windows'), isNull);
    expect(androidReleasePage('1.0.3', channel: 'windows').toString(), 'https://github.com/Goelir/IPTVMac/releases/tag/windows-v1.0.3');
    expect(() => newestAndroidVersion(f, channel: '.*'), throwsArgumentError, reason: 'the channel is never put into the pattern as given');
  });

  for (final (candidate, current, newer) in [
    ('1.0.3', '1.0.2', true), ('1.0.2', '1.0.2', false), ('1.0.1', '1.0.2', false), ('1.1.0', '1.0.9', true), ('2.0.0', '1.9.9', true),
    ('1.0.10', '1.0.9', true), ('1.0.3', '1.0.2+5', true), ('1.0.2', '1.0.2+9', false), ('x', '1.0.2', false), ('1.0.3', 'dev', false),
  ]) {
    test('$candidate is ${newer ? '' : 'not '}newer than $current', () => expect(isNewerVersion(candidate, current), newer));
  }

  test('the release page is built from a clean version only', () {
    expect(androidReleasePage('1.0.3').toString(), 'https://github.com/Goelir/IPTVMac/releases/tag/android-v1.0.3');
    for (final bad in ['1.0', '1.0.3/../../x', 'javascript:1', '1.0.3?x=1', '', '1.0.3-beta']) {
      expect(() => androidReleasePage(bad), throwsArgumentError, reason: bad);
    }
  });

  test('fetch reads the feed and gives the newest version; a failing feed throws', () async {
    final server = FakeServer((r) => res(200, feed(['android-v1.0.2', 'android-v1.0.3'])));
    expect(await fetchNewestAndroidVersion(server.client), '1.0.3');
    expect(server.calls, 1);
    server.reply(503, 'down');
    await expectLater(fetchNewestAndroidVersion(server.client), throwsA(anything));
  });
}
