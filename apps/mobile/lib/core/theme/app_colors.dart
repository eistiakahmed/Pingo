import 'package:flutter/material.dart';

/// Adaptive Penguin color tokens for Light and Dark system themes.
/// - Dark Mode: Matte charcoal/black background, pure white primary text, warm amber accent.
/// - Light Mode: Clean soft off-white/light grey background, deep black primary text, warm amber accent.
@immutable
class PenguinPalette {
  final Brightness brightness;
  final Color bg;
  final Color chrome;
  final Color card;
  final Color surface;
  final Color border;
  final Color borderActive;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color primaryFill;
  final Color onPrimaryFill;
  final Color accent;
  final Color onAccent;
  final Color success;
  final Color danger;

  const PenguinPalette({
    required this.brightness,
    required this.bg,
    required this.chrome,
    required this.card,
    required this.surface,
    required this.border,
    required this.borderActive,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primaryFill,
    required this.onPrimaryFill,
    required this.accent,
    required this.onAccent,
    required this.success,
    required this.danger,
  });

  bool get isDark => brightness == Brightness.dark;

  /// Deep matte charcoal/black Penguin dark palette.
  static const PenguinPalette dark = PenguinPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF0E0F12),
    chrome: Color(0xFF121317),
    card: Color(0xFF17191E),
    surface: Color(0xFF21242B),
    border: Color(0xFF282C35),
    borderActive: Color(0xFF393F4D),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB2B7C2),
    textMuted: Color(0xFF7E8594),
    primaryFill: Color(0xFFFFFFFF),
    onPrimaryFill: Color(0xFF0E0F12),
    accent: Color(0xFFF09A2B),
    onAccent: Color(0xFF0E0F12),
    success: Color(0xFF4CC38A),
    danger: Color(0xFFE5484D),
  );

  /// Clean soft off-white/light grey Penguin light palette.
  static const PenguinPalette light = PenguinPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF5F6F8),
    chrome: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    surface: Color(0xFFECEEF2),
    border: Color(0xFFE1E4EA),
    borderActive: Color(0xFFCBD0DA),
    textPrimary: Color(0xFF111216),
    textSecondary: Color(0xFF525763),
    textMuted: Color(0xFF7B818F),
    primaryFill: Color(0xFF111216),
    onPrimaryFill: Color(0xFFFFFFFF),
    accent: Color(0xFFE0861B),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF2B9A66),
    danger: Color(0xFFD9383D),
  );
}

/// Semantic color palette for Pingo — Device-Adaptive Penguin Palette.
/// Use `AppColors.of(context)` in UI widgets to adapt automatically to
/// Light and Dark system themes. Static tokens remain for compatibility.
class AppColors {
  AppColors._();

  /// Resolves the active [PenguinPalette] for the current [BuildContext].
  static PenguinPalette of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? PenguinPalette.dark
        : PenguinPalette.light;
  }

  // ── 1. Matte Charcoal Neutral Ramp (Dark Default Tokens) ──
  static const Color inkDeep = Color(0xFF121317);
  static const Color inkBlack = Color(0xFF0E0F12);
  static const Color inkCard = Color(0xFF17191E);
  static const Color inkSurface = Color(0xFF21242B);
  static const Color inkBorder = Color(0xFF282C35);
  static const Color inkBorderActive = Color(0xFF393F4D);

  // ── 2. Three Text Roles ──
  static const Color paperWhite = Color(0xFFFFFFFF);
  static const Color paperMuted = Color(0xFFB2B7C2);
  static const Color paperSubtle = Color(0xFF7E8594);

  // ── 3. Accent & Semantic Roles ──
  static const Color signalAmber = Color(0xFFF09A2B);
  static const Color titanium = Color(0xFFFFFFFF);
  static const Color titaniumSoft = Color(0xFFD8DCE6);

  static const Color success = Color(0xFF4CC38A);
  static const Color warning = Color(0xFFF09A2B);
  static const Color overdue = Color(0xFFE5484D);
  static const Color info = Color(0xFFB2B7C2);

  // ── 4. Category Status Colors ──
  static const Color categoryMedicine = Color(0xFFE5484D);
  static const Color categoryBill = Color(0xFFF09A2B);
  static const Color categoryWork = Color(0xFF3B82F6);
  static const Color categoryPersonal = Color(0xFF64748B);
  static const Color categoryBirthday = Color(0xFF4CC38A);

  // ── 5. Legacy Compatibility Aliases ──
  static const Color penguinBlack = inkBlack;
  static const Color penguinSurface = inkSurface;
  static const Color penguinCard = inkCard;
  static const Color penguinBorder = inkBorder;
  static const Color penguinBeak = signalAmber;
  static const Color penguinOrange = signalAmber;
  static const Color penguinGlacier = paperWhite;
  static const Color penguinSnow = paperWhite;
  static const Color penguinFrost = paperWhite;
  static const Color penguinMuted = paperMuted;
  static const Color penguinGoldGlow = Color(0x00000000);

  static const Color pingoPurple = signalAmber;
  static const Color pingoPurpleLight = inkSurface;
  static const Color pingoPurpleSubtle = inkCard;
  static const Color pingoBackground = inkBlack;
  static const Color pingoSurface = inkSurface;
  static const Color pingoBorder = inkBorder;
  static const Color pingoDark = paperWhite;
  static const Color pingoMuted = paperMuted;
  static const Color pingoLightMuted = paperSubtle;

  static const Color vaultIdentity = paperMuted;
  static const Color vaultFinance = paperMuted;
  static const Color vaultHealth = paperMuted;
  static const Color vaultEducation = paperMuted;

  static const Color brandPrimary = signalAmber;
  static const Color brandSecondary = paperMuted;
  static const Color lightBg = Color(0xFFF5F6F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE1E4EA);
  static const Color lightTextPrimary = Color(0xFF111216);
  static const Color lightTextSecondary = Color(0xFF525763);
  static const Color lightTextMuted = Color(0xFF7B818F);
  static const Color navyDark = inkBlack;
  static const Color navySlate = inkCard;

  static const Color darkBg = inkBlack;
  static const Color darkSurface = inkCard;
  static const Color darkBorder = inkBorder;
  static const Color darkTextPrimary = paperWhite;
  static const Color darkTextSecondary = paperMuted;
  static const Color darkTextMuted = paperSubtle;
}
