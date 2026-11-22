import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';

/// Frosted-glass panel for content over the brand hero: backdrop blur, white
/// tint and a 1 px white hairline. Set [blur] false where several panels sit
/// side by side and one blur behind them is enough.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = AppRadius.card,
    this.padding = EdgeInsets.zero,
    this.blur = true,
    this.strong = false,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool blur;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        color: strong ? AppGlass.fillStrong : AppGlass.fill,
        border: Border.all(color: AppGlass.border),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (!blur) return panel;
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: AppGlass.blur, sigmaY: AppGlass.blur), child: panel),
    );
  }
}
