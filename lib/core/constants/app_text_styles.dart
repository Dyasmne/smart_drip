import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Application text style constants (default system font — no custom fonts).
class AppTextStyles {
  AppTextStyles._();

  // =====================
  // HEADINGS
  // =====================

  static const TextStyle h1 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.4,
    inherit: true,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
    inherit: true,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    inherit: true,
  );

  static const TextStyle h4 = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    inherit: true,
  );

  // =====================
  // BODY TEXT
  // =====================

  static const TextStyle body1 = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.4,
    inherit: true,
  );

  static const TextStyle body2 = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.4,
    inherit: true,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    inherit: true,
  );

  // =====================
  // LABELS
  // =====================

  static const TextStyle labelLarge = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.2,
    inherit: true,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.2,
    inherit: true,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 9.5,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.3,
    inherit: true,
  );

  // =====================
  // BUTTON TEXT
  // =====================

  static const TextStyle button = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    inherit: true,
  );

  // =====================
  // DISPLAY
  // =====================

  static const TextStyle displayLarge = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
    letterSpacing: -0.8,
    inherit: true,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
    inherit: true,
  );

  // =====================
  // APP NAME
  // =====================

  static const TextStyle appName = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
    letterSpacing: 0.2,
    inherit: true,
  );

  static const TextStyle appSubtitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    letterSpacing: 0.2,
    inherit: true,
  );

  // =====================
  // ON PRIMARY
  // =====================

  static const TextStyle onPrimary = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    color: Colors.white,
    inherit: true,
  );

  static const TextStyle onPrimaryBold = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    inherit: true,
  );

  // =====================
  // DATA / SENSOR READOUTS
  // =====================
  // Used for moisture %, temperature, humidity, timestamps.
  // Same default font as everything else now — just bold + slightly
  // tighter letter spacing so readings still stand out a bit.

  static const TextStyle dataLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.4,
    inherit: true,
  );

  static const TextStyle dataMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    inherit: true,
  );

  static const TextStyle dataSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    inherit: true,
  );
}