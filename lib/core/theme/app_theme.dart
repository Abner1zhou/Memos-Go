import 'package:flutter/material.dart';

/// Material 3 theme with a flomo-inspired green brand and soft gray canvas.
class AppTheme {
  /// Brand green used for the composer button, highlights and heatmap.
  static const Color brandGreen = Color(0xFF34C77B);

  /// Darker green for pressed states and green-button text/borders.
  static const Color brandGreenDark = Color(0xFF1E9E5A);

  /// Light green fill for the highlighted "All memos" drawer button.
  static const Color brandGreenContainer = Color(0xFFE7F8EF);

  /// Text/icon color on [brandGreenContainer].
  static const Color onBrandGreenContainer = Color(0xFF1B7A4A);

  /// Blue used for `#tag` chips inside memo content (flomo-style).
  static const Color tagBlue = Color(0xFF3E78AD);
  static const Color tagBlueContainer = Color(0xFFE8F1FF);

  /// Muted khaki used for drawer section titles.
  static const Color groupTitleColor = Color(0xFFA8A15C);

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: dark ? const Color(0xFF3ACB82) : brandGreen,
      onPrimary: Colors.white,
      primaryContainer: dark ? const Color(0xFF1D3527) : brandGreenContainer,
      onPrimaryContainer:
          dark ? const Color(0xFF7ED9A6) : onBrandGreenContainer,
      secondary: tagBlue,
      onSecondary: Colors.white,
      surface: dark ? const Color(0xFF232427) : Colors.white,
      onSurface: dark ? const Color(0xFFE8E8EA) : const Color(0xFF26292E),
      surfaceContainerHighest:
          dark ? const Color(0xFF2E2F33) : const Color(0xFFEFEFF2),
      onSurfaceVariant: dark ? const Color(0xFF9AA0A8) : const Color(0xFF8A8F99),
      outlineVariant:
          dark ? const Color(0xFF35363A) : const Color(0xFFE4E6EA),
      error: dark ? const Color(0xFFFF6B6E) : const Color(0xFFE5484D),
      onError: Colors.white,
    );
    final canvas = dark ? const Color(0xFF17181A) : const Color(0xFFF2F3F5);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: canvas,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        filled: true,
        fillColor: dark ? scheme.surfaceContainerHighest : Colors.white,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: dark ? scheme.primary : brandGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      listTileTheme: ListTileThemeData(iconColor: scheme.onSurfaceVariant),
    );
  }
}
