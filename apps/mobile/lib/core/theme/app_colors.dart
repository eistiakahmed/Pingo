import 'package:flutter/material.dart';

/// Semantic color palette for Pingo (Calm, trustworthy, high contrast).
class AppColors {
  AppColors._();

  // Primary & Brand
  static const Color brandPrimary = Color(0xFF4F46E5);      // Indigo Accent
  static const Color brandSecondary = Color(0xFF3B82F6);    // Sky Blue
  static const Color navyDark = Color(0xFF0F172A);          // Deep Charcoal Navy
  static const Color navySlate = Color(0xFF1E293B);         // Slate Navy

  // Semantic Status Colors
  static const Color success = Color(0xFF10B981);           // Emerald Green (Done)
  static const Color warning = Color(0xFFF59E0B);           // Amber (Due Soon / High Priority)
  static const Color overdue = Color(0xFFEF4444);           // Coral Red (Overdue Alert)
  static const Color info = Color(0xFF0EA5E9);              // Sky Info

  // Category Colors
  static const Color categoryMedicine = Color(0xFF8B5CF6);  // Purple
  static const Color categoryBill = Color(0xFF06B6D4);      // Cyan
  static const Color categoryWork = Color(0xFF3B82F6);      // Blue
  static const Color categoryPersonal = Color(0xFFEC4899);  // Pink
  static const Color categoryBirthday = Color(0xFFF97316);  // Orange

  // Light Theme Neutrals
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Dark Theme Neutrals
  static const Color darkBg = Color(0xFF090D16);
  static const Color darkSurface = Color(0xFF161E2E);
  static const Color darkBorder = Color(0xFF26334D);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);
}
