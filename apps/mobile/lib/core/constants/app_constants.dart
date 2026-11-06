import 'package:flutter/material.dart';

/// Application-wide constants for spacing, radiuses, and durations.
class AppConstants {
  AppConstants._();

  // App Identity
  static const String appName = 'Pingo';
  static const String appTagline = 'Say it. Type it. Never forget it.';

  // Spacing
  static const double spacing2 = 2.0;
  static const double spacing4 = 4.0;
  static const double spacing6 = 6.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing40 = 40.0;

  // Border Radiuses
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 24.0;
  static const double radiusFull = 999.0;

  // Touch Target Sizes
  static const double minTouchTarget = 48.0;
  static const double floatingMicButtonSize = 68.0;

  // Animation Durations
  static const Duration fastAnimation = Duration(milliseconds: 150);
  static const Duration normalAnimation = Duration(milliseconds: 250);
  static const Duration smoothAnimation = Duration(milliseconds: 350);

  // Defaults
  static const TimeOfDay defaultMorningTime = TimeOfDay(hour: 9, minute: 0);
  static const TimeOfDay defaultEveningTime = TimeOfDay(hour: 18, minute: 0);
}

