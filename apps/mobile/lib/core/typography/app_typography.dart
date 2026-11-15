import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Architectural Minimalist Typography configuration tailored for bilingual (Bangla + English) text.
/// Uses [Hind Siliguri] for clean, legible Bengali typography with deliberate line heights (1.45x-1.55x),
/// and [Space Grotesk] / [JetBrains Mono] for sharp, editorial metadata.
class AppTypography {
  AppTypography._();

  static const String fontFamilyName = 'Hind Siliguri';
  static const double banglaLineHeight = 1.45;

  // Base text style with Hind Siliguri
  static TextStyle get _baseBanglaStyle => GoogleFonts.hindSiliguri(
        height: banglaLineHeight,
        letterSpacing: 0.1,
      );

  static String get displayFont => GoogleFonts.spaceGrotesk().fontFamily ?? 'Space Grotesk';
  static String get monoFont => GoogleFonts.jetBrainsMono().fontFamily ?? 'JetBrains Mono';

  // Editorial Masthead & Monospace Labels
  static TextStyle masthead({
    Color? color,
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w800,
    double letterSpacing = 2.0,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        color: color,
      );

  static TextStyle monoLabel({
    Color? color,
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w600,
    double letterSpacing = 0.8,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        color: color,
      );

  static TextStyle get mastheadStyle => masthead();
  static TextStyle get monoLabelStyle => monoLabel();

  // Headlines
  static TextStyle headlineLarge({Color? color}) => _baseBanglaStyle.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle headlineMedium({Color? color}) => _baseBanglaStyle.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle headlineSmall({Color? color}) => _baseBanglaStyle.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
      );

  // Titles
  static TextStyle titleLarge({Color? color}) => _baseBanglaStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle titleMedium({Color? color}) => _baseBanglaStyle.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: color,
      );

  // Body
  static TextStyle bodyLarge({Color? color}) => _baseBanglaStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle bodyMedium({Color? color}) => _baseBanglaStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle bodySmall({Color? color}) => _baseBanglaStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
      );

  // Labels & Chips
  static TextStyle labelLarge({Color? color}) => _baseBanglaStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle labelMedium({Color? color}) => _baseBanglaStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle labelSmall({Color? color}) => _baseBanglaStyle.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: color,
      );
}
