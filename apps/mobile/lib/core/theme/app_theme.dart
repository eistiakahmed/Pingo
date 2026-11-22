import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import '../typography/app_typography.dart';

/// Unslop Ink & Ledger ThemeData specification.
/// Single neutral ramp, weights 400–600, nested radii (8/12/16), zero glows.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.hindSiliguriTextTheme().apply(
      bodyColor: AppColors.paperWhite,
      displayColor: AppColors.paperWhite,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.signalAmber,
      scaffoldBackgroundColor: AppColors.inkBlack,
      textTheme: textTheme,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.signalAmber,
        secondary: AppColors.paperMuted,
        surface: AppColors.inkCard,
        error: AppColors.overdue,
        onPrimary: AppColors.inkBlack,
        onSurface: AppColors.paperWhite,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.inkDeep,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.headlineSmall(color: AppColors.paperWhite),
        iconTheme: const IconThemeData(color: AppColors.paperMuted, size: 18),
      ),
      cardTheme: CardThemeData(
        color: AppColors.inkCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.inkBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.inkBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.inkBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.inkBorderActive, width: 1),
        ),
        hintStyle: AppTypography.bodyMedium(color: AppColors.paperSubtle),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.paperWhite,
        foregroundColor: AppColors.inkBlack,
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.inkCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          side: BorderSide(color: AppColors.inkBorder, width: 1),
        ),
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme;
}
