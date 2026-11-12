import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/images.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// Fallback art for a bucket's `image` key until real photos land in
/// `assets/images/<key>.jpg`. Keys/categories map to a tint + icon.
class BucketVisual {
  const BucketVisual(this.key, this.tint, this.icon);

  final String key;
  final Color tint;
  final IconData icon;

  static BucketVisual of(String keyOrTitle) {
    final k = keyOrTitle.toLowerCase();
    bool has(List<String> words) => words.any(k.contains);
    if (has(['seer', 'fish', 'tuna', 'rohu', 'hilsa', 'prawn', 'kasimedu', 'pomfret', 'crab', 'paarai'])) {
      return BucketVisual(keyOrTitle, const Color(0xFFE3F0FA), Icons.set_meal_rounded);
    }
    if (has(['basmati', 'rice', 'atta', 'dal', 'oil', 'sack'])) {
      return BucketVisual(keyOrTitle, const Color(0xFFF7EEDD), Icons.rice_bowl_rounded);
    }
    if (has(['mango', 'alphonso', 'fruit'])) {
      return BucketVisual(keyOrTitle, const Color(0xFFFFF1D6), Icons.spa_rounded);
    }
    if (has(['pest', 'clean', 'service', 'tank'])) {
      return BucketVisual(keyOrTitle, const Color(0xFFE6F5EE), Icons.cleaning_services_rounded);
    }
    if (has(['goat', 'mutton', 'meat', 'chicken', 'bakrid'])) {
      return BucketVisual(keyOrTitle, const Color(0xFFFBE7E3), Icons.kebab_dining_rounded);
    }
    if (has(['koyambedu', 'veg', 'onion', 'trip', 'market'])) {
      return BucketVisual(keyOrTitle, const Color(0xFFEAF5DF), Icons.local_shipping_rounded);
    }
    return BucketVisual(keyOrTitle, AppColors.brandTint, Icons.shopping_basket_rounded);
  }
}

/// Photo block at the top of product cards (radius 12). Uses a network image
/// when [url] is given, else an asset `assets/images/<key>.jpg`, else the
/// tinted icon fallback.
class BucketPhoto extends StatelessWidget {
  const BucketPhoto({super.key, required this.visual, this.url, this.height = 140, this.badge, this.borderRadius});

  final BucketVisual visual;
  final String? url;
  final double height;

  /// Small label in the top-left corner (e.g. `Split`).
  final String? badge;

  /// Defaults to the photo radius (12). Pass [BorderRadius.zero] for full-bleed heroes.
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: visual.tint,
      alignment: Alignment.center,
      child: LayoutBuilder(
        builder: (_, c) => Icon(
          visual.icon,
          size: (c.maxHeight.isFinite ? c.maxHeight : 120) * 0.42,
          color: AppColors.ink.withValues(alpha: 0.55),
        ),
      ),
    );
    final Widget img;
    if (url != null && url!.startsWith('http')) {
      img = CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover, errorWidget: (_, _, _) => fallback, placeholder: (_, _) => fallback);
    } else {
      img = Image.asset(
        AppImages.bucket(visual.key) ?? 'assets/images/${visual.key}.jpg',
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return ClipRRect(
      borderRadius: borderRadius ?? AppRadius.photoBorder,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(fit: StackFit.expand, children: [
          img,
          if (badge != null)
            Positioned(
              left: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.chip)),
                child: Text(badge!, style: AppText.tiny.copyWith(color: AppColors.ink)),
              ),
            ),
        ]),
      ),
    );
  }
}
