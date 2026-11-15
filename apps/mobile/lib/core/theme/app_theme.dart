import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import '../typography/app_typography.dart';

/// Architectural Minimalist ThemeData specifications.
/// Monochromatic ink & paper aesthetic with titanium highlights and hairline borders.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.hindSiliguriTextTheme().apply(
      bodyColor: AppColors.paperWhite,
      displayColor: AppColors.paperWhite,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark, // Default to architectural dark ink
      primaryColor: AppColors.titanium,
      scaffoldBackgroundColor: AppColors.inkBlack,
      textTheme: textTheme,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.titanium,
        secondary: AppColors.paperWhite,
        surface: AppColors.inkSurface,
        error: AppColors.overdue,
        onPrimary: AppColors.inkBlack,
        onSurface: AppColors.paperWhite,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.inkBlack,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.headlineSmall(color: AppColors.paperWhite),
        iconTheme: const IconThemeData(color: AppColors.paperWhite),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inkBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inkBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.titanium, width: 1.2),
        ),
        hintStyle: AppTypography.bodyMedium(color: AppColors.paperSubtle),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.titanium,
        foregroundColor: AppColors.inkBlack,
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.inkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: AppColors.inkBorder, width: 1),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return lightTheme; // In Architectural Minimalist, both modes honor the dark ink aesthetic
  }
}
