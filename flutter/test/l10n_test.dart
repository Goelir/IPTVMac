import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptvmac/l10n/app_localizations.dart';

// Run from flutter/ (flutter test does). The .arb files are produced by tool/strings_to_arb.py.
Map<String, dynamic> arb(String locale) => json.decode(File('lib/l10n/app_$locale.arb').readAsStringSync()) as Map<String, dynamic>;

final placeholder = RegExp(r'\{(p\d+)\}');

void main() {
  // The 31 Apple folders (Sources/IPTVMac/Resources/<code>.lproj) as arb locale codes, read-only.
  final apple = Directory('../Sources/IPTVMac/Resources')
      .listSync()
      .whereType<Directory>()
      .map((d) => d.path.split(RegExp(r'[\\/]')).last)
      .where((n) => n.endsWith('.lproj'))
      .map((n) => n.replaceAll('.lproj', '').replaceAll('-', '_'))
      .toList()
    ..sort();
  final keys = (arb('en').keys.where((k) => !k.startsWith('@')).toList()..sort());

  test('31 Apple languages, all generated and supported', () {
    expect(apple.length, 31);
    final supported = AppLocalizations.supportedLocales.map((l) => l.toString()).toSet();
    for (final code in apple) {
      expect(supported, contains(code), reason: 'app_$code.arb is not a supported locale');
    }
    // zh is the extra fallback gen-l10n requires for zh_Hans / zh_Hant
    expect(supported.difference(apple.toSet()), {'zh'});
  });

  test('key count matches the Apple English file', () {
    final lines = File('../Sources/IPTVMac/Resources/en.lproj/Localizable.strings').readAsLinesSync().where((l) => l.startsWith('"'));
    expect(keys.length, lines.length);
    expect(json.decode(File('lib/l10n/key_map.json').readAsStringSync()), hasLength(keys.length));
  });

  test('every locale loads and has every key, with the same placeholders as English', () async {
    final en = arb('en');
    for (final locale in AppLocalizations.supportedLocales) {
      final code = locale.toString();
      final l10n = await AppLocalizations.delegate.load(locale);
      expect(l10n.localeName, code);
      final a = arb(code);
      expect(a['@@locale'], code);
      for (final k in keys) {
        expect(a[k], isA<String>(), reason: '$code is missing $k');
        final want = en['@$k'] == null ? <String>{} : (en['@$k']['placeholders'] as Map).keys.toSet();
        final got = placeholder.allMatches(a[k] as String).map((m) => m.group(1)!).toSet();
        expect(got, want, reason: '$code $k placeholders');
      }
    }
  });

  testWidgets('text direction: he ar fa ur are right-to-left, the rest left-to-right', (tester) async {
    const rtl = {'he', 'ar', 'fa', 'ur'};
    for (final locale in AppLocalizations.supportedLocales) {
      late TextDirection dir;
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(builder: (context) {
          dir = Directionality.of(context);
          return const SizedBox();
        }),
      ));
      await tester.pumpAndSettle();
      expect(dir, rtl.contains(locale.languageCode) ? TextDirection.rtl : TextDirection.ltr, reason: locale.toString());
    }
  });

  test('spot checks with the real strings', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final he = await AppLocalizations.delegate.load(const Locale('he'));
    final hant = await AppLocalizations.delegate.load(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'));
    expect(en.updateAvailable('1.2.3'), 'Version 1.2.3 is available');
    expect(en.seriesEpShort(3, 4), 'S3 E4');
    expect(en.playerSeekValue('1:00', '2:00'), '1:00 of 2:00');
    expect(en.onbWelcomeBody, contains("Let's add your first source")); // apostrophe survives ICU escaping
    expect(en.aboutPrivacyBody, contains('\n\n')); // \n in the Apple file is a real newline
    expect(he.seriesEpShort(3, 4), 'ע׳3 פ׳4');
    expect(hant.localeName, 'zh_Hant');
    expect(hant.tabLive, isNot(en.tabLive));
  });
}
