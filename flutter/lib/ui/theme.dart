import 'package:flutter/material.dart';
import 'package:iptvmac/app/device.dart';

/// The look: one violet on quiet surfaces (colours from ios/Sources/UI/Theme.swift and the asset catalog), Material 3 parts.
abstract final class Brand {
  /// iOS `AccentColor`: fills (buttons, selected chips).
  static const accentFill = Color(0xFF6F59E6);

  static ThemeData theme(Brightness b) {
    final dark = b == Brightness.dark;
    // iOS `AccentText`: the violet for text and glyphs (the fill violet is too dark for text on a dark ground).
    final primary = dark ? const Color(0xFFA496FF) : const Color(0xFF5B3DE0);
    final canvas = dark ? const Color(0xFF0A0912) : const Color(0xFFF6F5FB);
    final surface = dark ? const Color(0xFF15132A) : Colors.white;
    final raised = dark ? const Color(0xFF1F1C3A) : const Color(0xFFECEBF6);
    final scheme = ColorScheme.fromSeed(seedColor: accentFill, brightness: b).copyWith(
      primary: primary,
      onPrimary: dark ? const Color(0xFF1A1040) : Colors.white,
      surface: canvas,
      surfaceContainerLowest: canvas,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: raised,
      surfaceContainerHighest: raised,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      appBarTheme: AppBarTheme(backgroundColor: canvas, scrolledUnderElevation: 0, surfaceTintColor: Colors.transparent),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: surface, indicatorColor: scheme.primaryContainer),
      chipTheme: ChipThemeData(
        backgroundColor: raised,
        selectedColor: accentFill,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: TextStyle(color: scheme.onSurface),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        checkmarkColor: Colors.white,
        showCheckmark: false,
      ),
      cardTheme: CardThemeData(color: surface, elevation: 0, margin: EdgeInsets.zero),
      dividerTheme: DividerThemeData(color: scheme.onSurface.withValues(alpha: 0.08), space: 1),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: canvas, showDragHandle: true),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raised,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        // A text field is not drawn over by the TV focus ring, so its own border shows where the cursor is.
        focusedBorder: isTelevision
            ? OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: dark ? Colors.white : const Color(0xFF1A1040), width: 3))
            : null,
      ),
      navigationRailTheme: isTelevision ? const NavigationRailThemeData(minWidth: 104, minExtendedWidth: 220) : null,
    );
  }
}

/// Text colour on the violet fill.
const onAccent = Colors.white;
