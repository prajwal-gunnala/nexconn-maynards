import 'package:flutter/material.dart';

import '../core/models/share.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';

enum PillTone { held, captured, released, brand, neutral, danger }

/// Small rounded status label. Money states: held (amber), captured (green),
/// released (slate).
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.tone = PillTone.neutral, this.icon});

  /// Pill for a hold status.
  factory StatusPill.hold(HoldStatus s, {Key? key}) => switch (s) {
        HoldStatus.held || HoldStatus.created => StatusPill('Held', key: key, tone: PillTone.held, icon: Icons.lock_clock_outlined),
        HoldStatus.captured => StatusPill('Paid', key: key, tone: PillTone.captured, icon: Icons.check_circle_outline),
        HoldStatus.released => StatusPill('Released', key: key, tone: PillTone.released, icon: Icons.undo),
        HoldStatus.unknown => StatusPill('—', key: key),
      };

  /// Pill for a share status.
  factory StatusPill.share(ShareStatus s, {Key? key}) => switch (s) {
        ShareStatus.pendingPayment => StatusPill('Awaiting UPI', key: key, tone: PillTone.brand),
        ShareStatus.held => StatusPill('Held', key: key, tone: PillTone.held, icon: Icons.lock_clock_outlined),
        ShareStatus.booked => StatusPill('Booked', key: key, tone: PillTone.brand),
        ShareStatus.captured => StatusPill('Paid', key: key, tone: PillTone.captured, icon: Icons.check_circle_outline),
        ShareStatus.released => StatusPill('Released', key: key, tone: PillTone.released, icon: Icons.undo),
        ShareStatus.checkedIn => StatusPill("I'm here", key: key, tone: PillTone.brand),
        ShareStatus.collected => StatusPill('Collected', key: key, tone: PillTone.captured),
        ShareStatus.left => StatusPill('Left', key: key, tone: PillTone.released),
        ShareStatus.unknown => StatusPill('—', key: key),
      };

  final String label;
  final PillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PillTone.held => (AppColors.heldTint, AppColors.held),
      PillTone.captured => (AppColors.saveTint, AppColors.save),
      PillTone.released => (AppColors.releasedTint, AppColors.released),
      PillTone.brand => (AppColors.brandTint, AppColors.brandDeep),
      PillTone.danger => (const Color(0xFFFDECEA), AppColors.danger),
      PillTone.neutral => (AppColors.canvas, AppColors.inkMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.chip)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
        Text(label, style: AppText.tiny.copyWith(color: fg, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
