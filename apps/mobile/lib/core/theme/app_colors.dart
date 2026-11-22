import 'package:flutter/material.dart';

/// Semantic color palette for Pingo — Unslop Ink & Horological Ledger System.
/// Built from a single low-saturation Ink neutral ramp with three text roles,
/// quiet hairline borders, and one warm signal-amber accent.
class AppColors {
  AppColors._();

  // ── 1. Ink Neutral Ramp (Dark) ──
  static const Color inkDeep = Color(0xFF07080D);         // Deepest surface (header / chrome bar)
  static const Color inkBlack = Color(0xFF0B0D14);        // Page background
  static const Color inkCard = Color(0xFF11141C);         // Card & assistant message surface
  static const Color inkSurface = Color(0xFF1A1E28);      // Raised surface (input bar, user bubble, active row)
  static const Color inkBorder = Color(0xFF222734);       // Hairline border (~8% primary text on ink)
  static const Color inkBorderActive = Color(0xFF32394A); // Focused / active hairline

  // ── 2. Three Text Roles ──
  static const Color paperWhite = Color(0xFFEEF0F5);      // Primary text
  static const Color paperMuted = Color(0xFFA3A9B8);      // Secondary text
  static const Color paperSubtle = Color(0xFF7A8296);     // Muted metadata, timestamps & icons

  // ── 3. Accent & Semantic Roles (Toned to sit inside the Ink ramp) ──
  static const Color signalAmber = Color(0xFFE5A93C);     // Single accent: pending alarm & key actions
  static const Color titanium = Color(0xFFEEF0F5);        // High-contrast off-white fill for primary buttons
  static const Color titaniumSoft = Color(0xFFD8DCE6);

  static const Color success = Color(0xFF4CC38A);         // Confirmed alarm / completed status dot
  static const Color warning = Color(0xFFE5A93C);         // Pending confirmation status dot
  static const Color overdue = Color(0xFFE5484D);         // Overdue / recording dot
  static const Color info = Color(0xFFA3A9B8);

  // ── 4. Category Status Dot Colors ──
  static const Color categoryMedicine = Color(0xFFE5484D);
  static const Color categoryBill = Color(0xFFE5A93C);
  static const Color categoryWork = Color(0xFFA3A9B8);
  static const Color categoryPersonal = Color(0xFFEEF0F5);
  static const Color categoryBirthday = Color(0xFF4CC38A);

  // ── 5. Legacy Compatibility Aliases (All mapped strictly to the Ink ramp) ──
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
  static const Color lightBg = inkBlack;
  static const Color lightSurface = inkCard;
  static const Color lightBorder = inkBorder;
  static const Color lightTextPrimary = paperWhite;
  static const Color lightTextSecondary = paperMuted;
  static const Color lightTextMuted = paperSubtle;
  static const Color navyDark = inkBlack;
  static const Color navySlate = inkCard;

  static const Color darkBg = inkBlack;
  static const Color darkSurface = inkCard;
  static const Color darkBorder = inkBorder;
  static const Color darkTextPrimary = paperWhite;
  static const Color darkTextSecondary = paperMuted;
  static const Color darkTextMuted = paperSubtle;
}
