import 'package:flutter/material.dart';

/// Semantic color palette for Pingo based on the Penguin Design System.
/// Combines deep tuxedo midnight navy, antarctic glacier snow, and signature golden amber beak accents.
class AppColors {
  AppColors._();

  // 🐧 Pingo Penguin Signature Tokens
  static const Color penguinBlack = Color(0xFF0B0F19);        // Deep Tuxedo Midnight Navy
  static const Color penguinSurface = Color(0xFF141C2B);      // Elevated Smooth Slate
  static const Color penguinCard = Color(0xFF1D283C);         // Floating Frost Container
  static const Color penguinBorder = Color(0xFF283852);       // Crisp Icy Border
  static const Color penguinBeak = Color(0xFFFF9F1C);         // Signature Golden Amber Beak
  static const Color penguinOrange = Color(0xFFFF7A00);       // Warm Tangerine Accent
  static const Color penguinGlacier = Color(0xFF0EA5E9);      // Arctic Glacier Ocean Blue
  static const Color penguinSnow = Color(0xFFFFFFFF);         // Pure Antarctic Snow White
  static const Color penguinFrost = Color(0xFFF1F5F9);        // Frost White Text
  static const Color penguinMuted = Color(0xFF94A3B8);        // Accessible Muted Text (4.5:1+)
  static const Color penguinGoldGlow = Color(0x33FF9F1C);     // Warm Welcoming Halo Glow

  // Primary Brand Colors (Vibrant Penguin Theme)
  static const Color pingoPurple = Color(0xFFFF9F1C);         // Primary Brand: Golden Amber Beak
  static const Color pingoPurpleLight = Color(0xFFFFF3E0);    // Warm Amber Tint
  static const Color pingoPurpleSubtle = Color(0xFFFFF8E1);   // Subtle Amber Frost
  static const Color pingoBackground = Color(0xFFF8FAFC);     // Clean Light Porcelain
  static const Color pingoSurface = Color(0xFFFFFFFF);        // Crisp White Card
  static const Color pingoBorder = Color(0xFFE2E8F0);         // Crisp Border
  static const Color pingoDark = Color(0xFF0F172A);           // Deep Tuxedo Heading
  static const Color pingoMuted = Color(0xFF6B7280);          // Subtitle Muted Gray
  static const Color pingoLightMuted = Color(0xFF64748B);     // Muted Gray

  // Semantic Accents
  static const Color success = Color(0xFF10B981);             // Emerald Ice
  static const Color warning = Color(0xFFF59E0B);             // Amber
  static const Color overdue = Color(0xFFEF4444);             // Coral Urgent
  static const Color info = Color(0xFF0EA5E9);                // Glacier Ocean Blue

  // Category Colors with High Vibrancy
  static const Color categoryMedicine = Color(0xFFF43F5E);    // Rose / Medicine
  static const Color categoryBill = Color(0xFFFF9F1C);        // Beak Amber / Bill
  static const Color categoryWork = Color(0xFF0EA5E9);        // Glacier Blue / Work
  static const Color categoryPersonal = Color(0xFFA855F7);    // Violet / Personal
  static const Color categoryBirthday = Color(0xFFFF7A00);    // Orange / Birthday

  // Category Badges in Vault
  static const Color vaultIdentity = Color(0xFFA855F7);
  static const Color vaultFinance = Color(0xFFFF9F1C);
  static const Color vaultHealth = Color(0xFFF43F5E);
  static const Color vaultEducation = Color(0xFF10B981);

  // Backward-compatible aliases
  static const Color brandPrimary = penguinBeak;
  static const Color brandSecondary = penguinGlacier;
  static const Color lightBg = pingoBackground;
  static const Color lightSurface = pingoSurface;
  static const Color lightBorder = pingoBorder;
  static const Color lightTextPrimary = pingoDark;
  static const Color lightTextSecondary = pingoMuted;
  static const Color lightTextMuted = pingoLightMuted;
  static const Color navyDark = penguinBlack;
  static const Color navySlate = penguinSurface;

  // Dark Theme (Penguin Tuxedo & Glacier Frost)
  static const Color darkBg = penguinBlack;
  static const Color darkSurface = penguinSurface;
  static const Color darkBorder = penguinBorder;
  static const Color darkTextPrimary = penguinSnow;
  static const Color darkTextSecondary = penguinFrost;
  static const Color darkTextMuted = penguinMuted;
}
