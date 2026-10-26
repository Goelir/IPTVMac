import 'package:flutter/material.dart';
import 'package:iptvmac/app/device.dart';
import 'package:iptvmac/app/library_model.dart';
import 'package:iptvmac/downloads/downloads_model.dart';
import 'package:iptvmac/l10n/app_localizations.dart';
import 'package:iptvmac/ui/root.dart';
import 'package:iptvmac/ui/theme.dart';
import 'package:iptvmac/ui/tv.dart';
import 'package:provider/provider.dart';

/// The app: Material 3, light/dark/system, the 31 languages (right-to-left ones mirror by themselves).
class IptvApp extends StatelessWidget {
  IptvApp({super.key, required this.model, DownloadsModel? downloads, this.locale})
      : downloads = isTelevision ? DownloadsModel.disabled() : downloads ?? DownloadsModel.disabled(); // a TV has no storage for downloads
  final LibraryModel model;

  /// Off (no buttons, no screens) unless the platform entry point passes a real one.
  final DownloadsModel downloads;

  /// Null = the device language.
  final Locale? locale;

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider<LibraryModel>.value(value: model),
          ChangeNotifierProvider<DownloadsModel>.value(value: downloads),
        ],
        child: Selector<LibraryModel, ThemeMode>(
          selector: (_, m) => m.prefs.themeMode,
          builder: (_, mode, _) => MaterialApp(
            onGenerateTitle: (c) => AppLocalizations.of(c).appName,
            debugShowCheckedModeBanner: false,
            theme: Brand.theme(Brightness.light),
            darkTheme: Brand.theme(Brightness.dark),
            themeMode: mode,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: isTelevision ? (_, child) => TvShell(child: child!) : null,
            home: const RootScreen(),
          ),
        ),
      );
}
