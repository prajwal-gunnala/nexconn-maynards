import 'package:flutter/material.dart';

/// Brand colours from docs/CONTRACT.md. Use these instead of raw hex values.
class AppColors {
  const AppColors._();

  static const brand = Color(0xFFE4572E);
  static const brandDeep = Color(0xFFB93A17);
  static const brandTint = Color(0xFFFFF1EC);
  static const ink = Color(0xFF1F1A17);
  static const inkMuted = Color(0xFF6E6660);
  static const line = Color(0xFFEFE9E5);
  static const surface = Color(0xFFFFFFFF);
  static const canvas = Color(0xFFFAF7F5);
  static const save = Color(0xFF12A150);
  static const saveTint = Color(0xFFE7F6EE);
  static const held = Color(0xFFB7791F);
  static const heldTint = Color(0xFFFFF6E0);
  static const released = Color(0xFF5B6472);
  static const releasedTint = Color(0xFFEEF0F3);
  static const danger = Color(0xFFD93025);

  /// Hero gradient stops: warm tomato into a deep, almost-brick red.
  static const brandBright = Color(0xFFF2784B);
  static const brandNight = Color(0xFF8F2A0F);

  /// Soft glows behind the hero glass.
  static const glowAmber = Color(0xFFFFB27A);
  static const glowRose = Color(0xFFFF7A6B);
  static const live = Color(0xFF7CF0A9);
}

/// Gradients shared by the hero, primary buttons and progress fills.
class AppGradients {
  const AppGradients._();

  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.brandBright, AppColors.brand, AppColors.brandDeep, AppColors.brandNight],
    stops: [0, 0.35, 0.75, 1],
  );

  static const button = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.brandBright, AppColors.brand, AppColors.brandDeep],
  );

  static const progress = LinearGradient(colors: [AppColors.brandBright, AppColors.brand]);
}

/// Frosted glass over the hero: white at low alpha, a hairline white border
/// and a backdrop blur. Keep blurred regions few (cost on mid phones).
class AppGlass {
  const AppGlass._();

  static final fill = Colors.white.withValues(alpha: 0.14);
  static final fillStrong = Colors.white.withValues(alpha: 0.2);
  static final border = Colors.white.withValues(alpha: 0.3);
  static const double blur = 18;
}

/// Soft, layered shadows (no hard drop shadows).
class AppShadows {
  const AppShadows._();

  static const card = [
    BoxShadow(color: Color(0x0F1F1A17), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0A1F1A17), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const floating = [
    BoxShadow(color: Color(0x1A1F1A17), blurRadius: 32, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x0D1F1A17), blurRadius: 6, offset: Offset(0, 2)),
  ];

  static const brand = [
    BoxShadow(color: Color(0x4DE4572E), blurRadius: 18, offset: Offset(0, 8)),
  ];
}

/// Spacing scale 4 / 8 / 12 / 16 / 20 / 24 / 32.
class AppSpace {
  const AppSpace._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Horizontal page gutter.
  static const double gutter = 16;
}

class AppRadius {
  const AppRadius._();

  static const double card = 16;
  static const double photo = 12;
  static const double sheet = 24;
  static const double chip = 999;

  /// Larger, softer radii for the home's photo-led cards and the hero.
  static const double tile = 20;
  static const double feature = 24;
  static const double hero = 32;

  static final cardBorder = BorderRadius.circular(card);
  static final photoBorder = BorderRadius.circular(photo);
}
