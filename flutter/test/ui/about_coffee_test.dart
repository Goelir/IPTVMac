import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptvmac/l10n/app_localizations.dart';
import 'package:iptvmac/ui/about_screens.dart';

void main() {
  testWidgets('About has the support link, with its address for a TV without a browser', (t) async {
    await t.pumpWidget(MaterialApp(
      locale: const Locale('he'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AboutScreen(),
    ));
    await t.pump();
    final tile = find.byKey(const Key('coffee-link'));
    expect(tile, findsOneWidget);
    expect(find.descendant(of: tile, matching: find.text('קנו לי קפה')), findsOneWidget);
    expect(find.descendant(of: tile, matching: find.text('buymeacoffee.com/elijr')), findsOneWidget);
    expect(coffeeUrl, 'https://buymeacoffee.com/elijr');
  });
}
