import 'package:flutter/material.dart';

/// Application color constants — "Instrument Panel" theme
///
/// Grounded in the actual subject matter of SmartDrip: soil, clay pots,
/// irrigation water, and the sensor hardware itself. Deliberately avoids
/// the generic bright Material-green + white-card look in favor of a more
/// muted, matured palette that reads like a real measurement device.
class AppColors {
  AppColors._();

  // ================= CORE PALETTE =================
  // Ink   — deep pine-charcoal, primary text
  static const Color ink = Color(0xFF1C2620);
  // Canvas — pale eucalyptus-white background (not cream)
  static const Color canvas = Color(0xFFEEF1EC);
  // Moss  — muted, matured green (primary)
  static const Color moss = Color(0xFF3F6B4F);
  static const Color mossDeep = Color(0xFF24402E);
  // Clay  — burnt ochre, like an unglazed terracotta pot (secondary/warm accent)
  static const Color clay = Color(0xFFB5652D);
  // Water — muted teal-blue, like water in shade (info / moisture accent)
  static const Color water = Color(0xFF2D6E8E);
  // Rust  — deep brick red, for alerts and dry-soil warnings
  static const Color rust = Color(0xFFA13D2B);

  // ================= LEGACY / SEMANTIC ALIASES =================
  // Kept so existing screens referencing AppColors.<name> don't break —
  // only the underlying values changed.
  static const Color primary = moss;
  static const Color secondary = clay;
  static const Color background = canvas;

  static const Color accent = water;
  static const Color accentLight = Color(0xFF7FA88C);
  static const Color accentDark = mossDeep;

  static const Color success = Color(0xFF4C7A5B);
  static const Color warning = clay;
  static const Color error = rust;
  static const Color info = water;

  static const Color textPrimary = ink;
  static const Color textSecondary = Color(0xFF5B6660);
  static const Color textLight = Color(0xFF9CA8A1);
  static const Color textOnPrimary = Colors.white;

  static const Color cardLight = Color(0xFFFBFAF6);
  static const Color cardDark = Color(0xFF20281F);
  static const Color divider = Color(0xFFD8DED8);

  // ================= MOISTURE LEVEL COLORS =================
  static const Color moistureLow = rust;       // dry
  static const Color moistureMedium = clay;    // moderate
  static const Color moistureGood = moss;      // good
  static const Color moistureHigh = water;     // saturated

  // ================= GRADIENTS =================
  // Deep-to-moss, less saturated than a bright Material gradient.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [mossDeep, moss],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFFEEF1EC), Color(0xFFE3E9E1)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [moss, mossDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}