import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Text styles (Plus Jakarta Sans). 800 for big numbers/titles, 700 headings,
/// 500/600 UI. Prefer these over `Theme.of(context).textTheme` in feature code
/// so sizes stay consistent with the design board.
class AppText {
  const AppText._();

  static TextStyle _f(double size, FontWeight w, {Color color = AppColors.ink, double? height}) =>
      TextStyle(fontFamily: 'PlusJakartaSans', fontFamilyFallback: const ['Roboto'], fontSize: size, fontWeight: w, color: color, height: height);

  /// Hero numbers and onboarding titles.
  static TextStyle get display => _f(28, FontWeight.w800, height: 1.15);

  /// Screen titles.
  static TextStyle get title => _f(20, FontWeight.w800, height: 1.2);

  /// Section and card headings.
  static TextStyle get heading => _f(16, FontWeight.w700, height: 1.25);

  static TextStyle get body => _f(14, FontWeight.w500, height: 1.4);
  static TextStyle get bodyMuted => _f(14, FontWeight.w500, color: AppColors.inkMuted, height: 1.4);
  static TextStyle get label => _f(13, FontWeight.w600);
  static TextStyle get caption => _f(12, FontWeight.w500, color: AppColors.inkMuted);
  static TextStyle get tiny => _f(11, FontWeight.w600, color: AppColors.inkMuted);

  /// Prices and big amounts.
  static TextStyle get price => _f(18, FontWeight.w800);
  static TextStyle get priceLarge => _f(24, FontWeight.w800);
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        primary: AppColors.brand,
        onPrimary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.canvas,
      dividerColor: AppColors.line,
      splashFactory: InkSparkle.splashFactory,
      // google_fonts 9 builds on the decoupled `material_ui` package, so its
      // *TextTheme helpers return a different TextTheme type. Use the family.
      fontFamily: 'PlusJakartaSans',
      fontFamilyFallback: const ['Roboto'],
    );
    final text = base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleTextStyle: AppText.heading.copyWith(fontSize: 18),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardBorder,
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: AppText.bodyMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.brandTint,
        side: const BorderSide(color: AppColors.line),
        shape: const StadiumBorder(),
        labelStyle: AppText.label,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.brandTint,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => AppText.tiny.copyWith(
            color: s.contains(WidgetState.selected) ? AppColors.brand : AppColors.inkMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? AppColors.brand : AppColors.inkMuted,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: AppText.body.copyWith(color: Colors.white),
      ),
    );
  }

  /// Tokens for the Nexconn Chat UI kit so ChatPage/ChannelPage match the brand.
  static const chatTokens = NexconnThemeTokens(
    brightness: Brightness.light,
    pageBackgroundColor: AppColors.canvas,
    surfaceColor: AppColors.canvas,
    surfaceMutedColor: AppColors.canvas,
    panelColor: AppColors.surface,
    primaryTextColor: AppColors.ink,
    secondaryTextColor: AppColors.inkMuted,
    dividerColor: AppColors.line,
    primaryColor: AppColors.brand,
    destructiveColor: AppColors.danger,
    successColor: AppColors.save,
    overlayColor: Color(0x14000000),
  );
}
