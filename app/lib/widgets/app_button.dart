import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';

enum AppButtonKind { primary, secondary, ghost }

/// Full-width pill button. Shows a spinner when [loading].
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.kind = AppButtonKind.primary,
    this.loading = false,
    this.icon,
    this.expand = true,
    this.trailing,
  });

  const AppButton.secondary({super.key, required this.label, this.onPressed, this.loading = false, this.icon, this.expand = true, this.trailing})
      : kind = AppButtonKind.secondary;

  const AppButton.ghost({super.key, required this.label, this.onPressed, this.loading = false, this.icon, this.expand = true, this.trailing})
      : kind = AppButtonKind.ghost;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final bool loading;
  final IconData? icon;
  final bool expand;

  /// Right-side text inside the button (e.g. a price on a sticky CTA).
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final (bg, fg, border) = switch (kind) {
      AppButtonKind.primary => (AppColors.brand, Colors.white, AppColors.brand),
      AppButtonKind.secondary => (AppColors.brandTint, AppColors.brandDeep, AppColors.brandTint),
      AppButtonKind.ghost => (Colors.transparent, AppColors.ink, AppColors.line),
    };
    final child = loading
        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: trailing == null ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
                Text(label, style: AppText.heading.copyWith(color: fg, fontSize: 15)),
              ]),
              if (trailing != null) Text(trailing!, style: AppText.heading.copyWith(color: fg, fontSize: 15)),
            ],
          );
    return SizedBox(
      width: expand ? double.infinity : null,
      height: 52,
      child: TextButton(
        onPressed: enabled ? onPressed : null,
        style: TextButton.styleFrom(
          backgroundColor: enabled ? bg : bg.withValues(alpha: kind == AppButtonKind.ghost ? 0 : 0.45),
          foregroundColor: fg,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: border),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Sticky bottom CTA bar (white, top divider), as on Licious product pages.
class StickyCta extends StatelessWidget {
  const StickyCta({super.key, required this.child, this.leading});

  final Widget child;

  /// Optional left block (e.g. price + "per kg").
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.md, AppSpace.gutter, AppSpace.md),
          child: leading == null
              ? child
              : Row(children: [leading!, const SizedBox(width: AppSpace.lg), Expanded(child: child)]),
        ),
      ),
    );
  }
}
