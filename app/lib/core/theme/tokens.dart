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

  static final cardBorder = BorderRadius.circular(card);
  static final photoBorder = BorderRadius.circular(photo);
}
