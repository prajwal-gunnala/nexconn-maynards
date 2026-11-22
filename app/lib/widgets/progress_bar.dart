import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';

/// A marker on the progress bar, e.g. a price tier at 25 kg.
class TierMarker {
  const TierMarker({required this.at, required this.label, this.reached = false});

  /// Position 0..1 along the bar.
  final double at;
  final String label;
  final bool reached;
}

/// Rounded progress bar with optional tier markers and labels underneath.
/// Animates when [value] changes (live card updates).
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.markers = const [],
    this.height = 8,
    this.color = AppColors.brand,
    this.track = AppColors.line,
    this.gradient,
  });

  /// 0..1
  final double value;
  final List<TierMarker> markers;
  final double height;
  final Color color;
  final Color track;

  /// Optional fill gradient (overrides [color]).
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final bar = SizedBox(
        height: height + (markers.isEmpty ? 0 : 6),
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.centerLeft, children: [
          Container(
            height: height,
            decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(height)),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(end: v),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => Container(
              width: w * t,
              height: height,
              decoration: BoxDecoration(color: gradient == null ? color : null, gradient: gradient, borderRadius: BorderRadius.circular(height)),
            ),
          ),
          for (final m in markers)
            Positioned(
              left: (w * m.at.clamp(0.0, 1.0)) - 1.5,
              child: Container(
                width: 3,
                height: height + 6,
                decoration: BoxDecoration(
                  color: m.reached ? AppColors.surface : AppColors.inkMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ]),
      );
      if (markers.isEmpty) return bar;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        bar,
        const SizedBox(height: 4),
        SizedBox(
          height: 16,
          child: Stack(clipBehavior: Clip.none, children: [
            for (final m in markers)
              Positioned(
                left: (w * m.at.clamp(0.0, 1.0) - 30).clamp(0.0, w - 60),
                width: 60,
                child: Text(
                  m.label,
                  textAlign: m.at > 0.9 ? TextAlign.right : TextAlign.center,
                  style: AppText.tiny.copyWith(color: m.reached ? AppColors.save : AppColors.inkMuted),
                ),
              ),
          ]),
        ),
      ]);
    });
  }
}
