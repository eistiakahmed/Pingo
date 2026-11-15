import 'package:flutter/material.dart';

/// Semantic color palette for Pingo based on the Architectural Minimalist Design System.
/// Monochromatic ink & paper aesthetic with titanium highlights and hairline borders.
class AppColors {
  AppColors._();

  // Architectural Minimalist Core Palette (Monochromatic Ink & Paper)
  static const Color inkBlack = Color(0xFF0A0C0E);            // Deep Matte Obsidian Canvas
  static const Color inkSurface = Color(0xFF121519);          // Structural Surface Elevation
  static const Color inkCard = Color(0xFF16191E);             // Architectural Card Container
  static const Color inkBorder = Color(0xFF232830);           // Hairline Graphite Border (0.5-1px)
  static const Color inkBorderActive = Color(0xFF3A4250);     // Active / Focused Hairline Border
  static const Color paperWhite = Color(0xFFF0F3F6);          // Crisp High-Contrast Text
  static const Color paperMuted = Color(0xFF8A94A0);          // Refined Editorial Slate Text
  static const Color paperSubtle = Color(0xFF525A66);         // Muted Metadata & Timestamp Text
  static const Color titanium = Color(0xFFFFFFFF);            // Pure Titanium White Highlight
  static const Color titaniumSoft = Color(0xFFE2E8F0);        // Soft Titanium Accent

  // Legacy/Semantic Compatibility Tokens (Mapped to Architectural Minimalist Palette)
  static const Color penguinBlack = inkBlack;
  static const Color penguinSurface = inkSurface;
  static const Color penguinCard = inkCard;
  static const Color penguinBorder = inkBorder;
  static const Color penguinBeak = titanium;                  // Replaced orange with crisp titanium white
  static const Color penguinOrange = titanium;                // Replaced vibrant orange with white
  static const Color penguinGlacier = paperWhite;
  static const Color penguinSnow = paperWhite;
  static const Color penguinFrost = paperWhite;
  static const Color penguinMuted = paperMuted;
  static const Color penguinGoldGlow = Color(0x1AFFFFFF);     // Subtle white ambient glow

  // Primary Brand Colors
  static const Color pingoPurple = titanium;
  static const Color pingoPurpleLight = Color(0xFF1E232B);
  static const Color pingoPurpleSubtle = Color(0xFF16191E);
  static const Color pingoBackground = inkBlack;
  static const Color pingoSurface = inkSurface;
  static const Color pingoBorder = inkBorder;
  static const Color pingoDark = paperWhite;
  static const Color pingoMuted = paperMuted;
  static const Color pingoLightMuted = paperSubtle;

  // Semantic Indicators (Muted, Architectural, Non-Cartoony)
  static const Color success = Color(0xFF98C379);             // Muted Sage Green
  static const Color warning = Color(0xFFE5C07B);             // Muted Ochre
  static const Color overdue = Color(0xFFE06C75);             // Subtle Crimson Dot
  static const Color info = Color(0xFF61AFEF);                // Muted Slate Blue

  // Category Colors (Monochrome Tone Palette)
  static const Color categoryMedicine = Color(0xFFE06C75);
  static const Color categoryBill = Color(0xFFE5C07B);
  static const Color categoryWork = Color(0xFF61AFEF);
  static const Color categoryPersonal = Color(0xFFD19A66);
  static const Color categoryBirthday = Color(0xFF98C379);

  // Category Badges in Vault
  static const Color vaultIdentity = paperMuted;
  static const Color vaultFinance = paperMuted;
  static const Color vaultHealth = paperMuted;
  static const Color vaultEducation = paperMuted;

  // Backward-compatible aliases
  static const Color brandPrimary = titanium;
  static const Color brandSecondary = paperWhite;
  static const Color lightBg = inkBlack;
  static const Color lightSurface = inkSurface;
  static const Color lightBorder = inkBorder;
  static const Color lightTextPrimary = paperWhite;
  static const Color lightTextSecondary = paperMuted;
  static const Color lightTextMuted = paperSubtle;
  static const Color navyDark = inkBlack;
  static const Color navySlate = inkSurface;

  // Dark Theme
  static const Color darkBg = inkBlack;
  static const Color darkSurface = inkSurface;
  static const Color darkBorder = inkBorder;
  static const Color darkTextPrimary = paperWhite;
  static const Color darkTextSecondary = paperMuted;
  static const Color darkTextMuted = paperSubtle;
}
