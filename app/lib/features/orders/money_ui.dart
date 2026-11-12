import 'package:flutter/material.dart';

import '../../core/images.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import '../bucket/bucket_visuals.dart';

/// Shared bits for the orders and wallet screens: photo thumbs, skeletons, error and empty states.

const tabular = [FontFeature.tabularFigures()];

/// Square product photo (radius 12) from a bucket image key.
class PhotoThumb extends StatelessWidget {
  const PhotoThumb({super.key, required this.imageKey, this.size = 56});
  final String imageKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final v = BucketVisual.of(imageKey);
    // No bundled photo for this key: draw the tinted icon straight away rather than
    // waiting for an asset lookup to fail.
    if (AppImages.bucket(imageKey) == null && !imageKey.startsWith('http')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: v.tint, borderRadius: AppRadius.photoBorder),
        child: Icon(v.icon, size: size * 0.45, color: AppColors.ink.withValues(alpha: 0.55)),
      );
    }
    return SizedBox(width: size, height: size, child: BucketPhoto(visual: v, url: imageKey, height: size));
  }
}

/// Grey placeholder block that gently pulses while data loads.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 8});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(radius)),
      );
}

class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.child});
  final Widget child;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Loading',
        child: FadeTransition(opacity: Tween(begin: 0.55, end: 1.0).animate(_c), child: widget.child),
      );
}

/// A card-shaped skeleton row: thumb + two lines + amount.
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({super.key, this.thumb = 56});
  final double thumb;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
        child: Row(children: [
          SkeletonBox(width: thumb, height: thumb, radius: 12),
          const SizedBox(width: AppSpace.md),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SkeletonBox(width: 160, height: 14),
              SizedBox(height: 8),
              SkeletonBox(width: 100, height: 12),
            ]),
          ),
          const SkeletonBox(width: 56, height: 16),
        ]),
      );
}

/// Centered "couldn't load" with a retry button.
class LoadFailed extends StatelessWidget {
  const LoadFailed({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: AppColors.brandTint, shape: BoxShape.circle),
              child: const Icon(Icons.cloud_off_rounded, color: AppColors.brand, size: 30),
            ),
            const SizedBox(height: AppSpace.lg),
            Text("Couldn't load this", style: AppText.title),
            const SizedBox(height: AppSpace.sm),
            Text(message, style: AppText.bodyMuted, textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.xl),
            AppButton.secondary(label: 'Try again', icon: Icons.refresh_rounded, expand: false, onPressed: onRetry),
          ]),
        ),
      );
}

/// Friendly empty state with an optional action.
class EmptyNote extends StatelessWidget {
  const EmptyNote({super.key, required this.icon, required this.title, required this.body, this.action, this.onAction});
  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xxl, vertical: AppSpace.xxxl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: AppColors.brandTint, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.brand, size: 32),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(title, style: AppText.heading.copyWith(fontSize: 18), textAlign: TextAlign.center),
          const SizedBox(height: AppSpace.xs),
          Text(body, style: AppText.bodyMuted, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: AppSpace.xl),
            AppButton.secondary(label: action!, expand: false, onPressed: onAction),
          ],
        ]),
      );
}

/// Two-option segmented control (Active / Past), 44 px tall inside a 48 px target.
class Segmented extends StatelessWidget {
  const Segmented({super.key, required this.labels, required this.index, required this.onChanged});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth / labels.length;
        return Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            left: w * index,
            top: 0,
            bottom: 0,
            width: w,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 1))],
              ),
            ),
          ),
          Row(children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onChanged(i),
                    child: Center(
                      child: Text(
                        labels[i],
                        style: AppText.label.copyWith(color: i == index ? AppColors.ink : AppColors.inkMuted, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}
