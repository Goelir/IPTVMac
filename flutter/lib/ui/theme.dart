import 'package:flutter/material.dart';
import 'package:iptvmac/app/device.dart';

/// The look: deep broadcast blue (the website's "On air" family), one blue for actions and selection, small corners.
/// Same values as ios/Sources/UI/Theme.swift and the iOS asset catalog. Material 3 parts, reshaped: no capsules for controls.
abstract final class Brand {
  /// iOS `AccentColor` (light): fills (buttons, selected chips).
  static const accentFill = Color(0xFF1F4FBF);
  static const _accentFillDark = Color(0xFF2F62D8);

  /// Corner radii: small parts (chips, buttons, fields, badges) and content (posters, cards, sheets).
  static const radiusSmall = 7.0;
  static const radiusCard = 10.0;
  static final small = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall));
  static final card = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusCard));

  /// `high`: the system's high-contrast setting (MaterialApp.highContrastTheme / highContrastDarkTheme), same values as the
  /// iOS Increase Contrast variants.
  static ThemeData theme(Brightness b, {bool high = false}) {
    final dark = b == Brightness.dark;
    final fill = high ? (dark ? const Color(0xFF2350B8) : const Color(0xFF163A8F)) : (dark ? _accentFillDark : accentFill);
    // iOS `AccentText`: the blue for text and glyphs (the fill blue is too dark for text on a dark ground).
    final primary = high ? (dark ? const Color(0xFFC3D5FB) : const Color(0xFF163A8F)) : (dark ? const Color(0xFF9DB9F7) : const Color(0xFF1F4FBF));
    final canvas = dark ? const Color(0xFF0B1426) : const Color(0xFFF4F6FA);
    final surface = dark ? (high ? const Color(0xFF18284A) : const Color(0xFF121E35)) : Colors.white;
    final raised = high ? (dark ? const Color(0xFF2A3E64) : const Color(0xFFD5DCE8)) : (dark ? const Color(0xFF1A2944) : const Color(0xFFE8ECF3));
    final ink = dark ? const Color(0xFFEEF2FF) : const Color(0xFF0B1B3A);
    // 7.5:1 / 5.7:1 on the canvas; high contrast 10:1 / 8.6:1
    final muted = high ? (dark ? const Color(0xFFB9C7E2) : const Color(0xFF3E4A60)) : (dark ? const Color(0xFF93A6C9) : const Color(0xFF55627A));
    final hairline = ink.withValues(alpha: high ? 0.35 : 0.12);
    final scheme = ColorScheme.fromSeed(seedColor: accentFill, brightness: b).copyWith(
      primary: primary,
      onPrimary: dark ? const Color(0xFF0B1426) : Colors.white,
      primaryContainer: fill,
      onPrimaryContainer: Colors.white,
      secondaryContainer: raised,
      onSecondaryContainer: ink,
      surface: canvas,
      onSurface: ink,
      onSurfaceVariant: muted,
      surfaceContainerLowest: canvas,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: raised,
      surfaceContainerHighest: raised,
      outline: muted,
      outlineVariant: hairline,
    );
    final buttonShape = WidgetStatePropertyAll<OutlinedBorder>(small);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      appBarTheme: AppBarTheme(backgroundColor: canvas, scrolledUnderElevation: 0, surfaceTintColor: Colors.transparent),
      // The selected tab: a soft rounded square behind the icon, not a pill.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: raised,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        // The selected tab's icon carries the brand blue (Apple: "save it for primary actions and ... the selected tab's icon").
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? primary : muted)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: canvas,
        indicatorColor: raised,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selectedIconTheme: IconThemeData(color: primary),
        unselectedIconTheme: IconThemeData(color: muted),
        minWidth: isTelevision ? 104 : null,
        minExtendedWidth: isTelevision ? 220 : null,
      ),
      filledButtonTheme: FilledButtonThemeData(style: ButtonStyle(shape: buttonShape, backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? null : fill), foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? null : Colors.white))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: ButtonStyle(shape: buttonShape)),
      textButtonTheme: TextButtonThemeData(style: ButtonStyle(shape: buttonShape)),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ButtonStyle(shape: buttonShape)),
      iconButtonTheme: IconButtonThemeData(style: ButtonStyle(shape: buttonShape)),
      segmentedButtonTheme: SegmentedButtonThemeData(style: ButtonStyle(shape: buttonShape)),
      chipTheme: ChipThemeData(
        backgroundColor: raised,
        selectedColor: fill,
        side: BorderSide(color: hairline),   // light chips are only 1.1:1 against the canvas without it
        shape: small,
        labelStyle: TextStyle(color: scheme.onSurface),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        checkmarkColor: Colors.white,
        showCheckmark: false,
      ),
      cardTheme: CardThemeData(color: surface, elevation: 0, margin: EdgeInsets.zero, shape: card),
      dialogTheme: DialogThemeData(backgroundColor: surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      popupMenuTheme: PopupMenuThemeData(color: surface, shape: small),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: small),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: fill, linearTrackColor: raised, borderRadius: BorderRadius.circular(1.5)),
      dividerTheme: DividerThemeData(color: scheme.onSurface.withValues(alpha: 0.08), space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: canvas,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raised,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusSmall), borderSide: BorderSide.none),
        // A text field is not drawn over by the TV focus ring, so its own border shows where the cursor is.
        focusedBorder: isTelevision
            ? OutlineInputBorder(borderRadius: BorderRadius.circular(radiusSmall), borderSide: BorderSide(color: dark ? Colors.white : const Color(0xFF0B1426), width: 3))
            : OutlineInputBorder(borderRadius: BorderRadius.circular(radiusSmall), borderSide: BorderSide(color: primary, width: 1.5)),
      ),
    );
  }
}

/// Text colour on the blue fill.
const onAccent = Colors.white;
