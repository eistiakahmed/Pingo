import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import '../typography/app_typography.dart';

/// Device-Adaptive Penguin ThemeData specification.
/// - Light Mode: Clean soft off-white/light grey canvas, deep black primary text, warm amber accents.
/// - Dark Mode: Matte charcoal/black canvas, pure white primary text, warm amber accents.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => _buildTheme(PenguinPalette.light);

  static ThemeData get darkTheme => _buildTheme(PenguinPalette.dark);

  static ThemeData _buildTheme(PenguinPalette p) {
    final isDark = p.isDark;
    final textTheme = GoogleFonts.hindSiliguriTextTheme().apply(
      bodyColor: p.textPrimary,
      displayColor: p.textPrimary,
    );

    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: p.accent,
            secondary: p.textSecondary,
            surface: p.card,
            error: p.danger,
            onPrimary: p.onAccent,
            onSurface: p.textPrimary,
          )
        : ColorScheme.light(
            primary: p.accent,
            secondary: p.textSecondary,
            surface: p.card,
            error: p.danger,
            onPrimary: p.onAccent,
            onSurface: p.textPrimary,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      primaryColor: p.accent,
      scaffoldBackgroundColor: p.bg,
      textTheme: textTheme,
      colorScheme: colorScheme,
      dividerColor: p.border,
      appBarTheme: AppBarTheme(
        backgroundColor: p.chrome,
        foregroundColor: p.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: AppTypography.headlineSmall(color: p.textPrimary),
        iconTheme: IconThemeData(color: p.textSecondary, size: 20),
      ),
      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: p.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.accent, width: 1.5),
        ),
        hintStyle: AppTypography.bodyMedium(color: p.textMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.isDark ? p.surface : p.primaryFill,
        contentTextStyle: TextStyle(
          color: p.isDark ? p.textPrimary : p.onPrimaryFill,
          fontSize: 13,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primaryFill,
        foregroundColor: p.onPrimaryFill,
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          side: BorderSide(color: p.border, width: 1),
        ),
      ),
    );
  }
}
