import 'package:flutter/material.dart';

/// Semantic color palette for Pingo based on the redesign.
class AppColors {
  AppColors._();

  // Redesign Brand Tokens
  static const Color pingoPurple = Color(0xFF544DE8);       // Electric Iris Purple
  static const Color pingoPurpleLight = Color(0xFFECEBFC);  // Soft Lavender Tint
  static const Color pingoPurpleSubtle = Color(0xFFF5F4FE); // Subtle Background Tint
  static const Color pingoBackground = Color(0xFFF9FAFC);   // Porcelain Canvas
  static const Color pingoSurface = Color(0xFFFFFFFF);      // Pure White Card
  static const Color pingoBorder = Color(0xFFECEFF4);       // Crisp Card Border
  static const Color pingoDark = Color(0xFF111827);         // Deep Slate Headings
  static const Color pingoMuted = Color(0xFF6B7280);        // Subtitle Muted Gray
  static const Color pingoLightMuted = Color(0xFF9CA3AF);   // Placeholder Gray

  // Semantic Accents
  static const Color success = Color(0xFF10B981);           // Emerald Green (Done / Active)
  static const Color warning = Color(0xFFF59E0B);           // Amber (Expiry / Alert)
  static const Color overdue = Color(0xFFEF4444);           // Coral Red (Stop / Urgent)
  static const Color info = Color(0xFF3B82F6);              // Blue Info

  // Category Colors
  static const Color categoryMedicine = Color(0xFF8B5CF6);  // Purple
  static const Color categoryBill = Color(0xFF06B6D4);      // Cyan
  static const Color categoryWork = Color(0xFF3B82F6);      // Blue
  static const Color categoryPersonal = Color(0xFFEC4899);  // Pink
  static const Color categoryBirthday = Color(0xFFF97316);  // Orange

  // Category Badges in Vault
  static const Color vaultIdentity = Color(0xFF8B5CF6);
  static const Color vaultFinance = Color(0xFFF59E0B);
  static const Color vaultHealth = Color(0xFFEF4444);
  static const Color vaultEducation = Color(0xFF10B981);

  // Backward-compatible alias
  static const Color brandPrimary = pingoPurple;
  static const Color brandSecondary = Color(0xFF3B82F6);
  static const Color lightBg = pingoBackground;
  static const Color lightSurface = pingoSurface;
  static const Color lightBorder = pingoBorder;
  static const Color lightTextPrimary = pingoDark;
  static const Color lightTextSecondary = pingoMuted;
  static const Color lightTextMuted = pingoLightMuted;
  static const Color navyDark = Color(0xFF0F172A);
  static const Color navySlate = Color(0xFF1E293B);

  // Dark Theme
  static const Color darkBg = Color(0xFF0F141C);
  static const Color darkSurface = Color(0xFF1A222E);
  static const Color darkBorder = Color(0xFF2B3747);
  static const Color darkTextPrimary = Color(0xFFF9FAFB);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkTextMuted = Color(0xFF6B7280);
}
