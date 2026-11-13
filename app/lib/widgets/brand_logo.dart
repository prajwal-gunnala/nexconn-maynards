import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme/tokens.dart';

/// The Jugaad Street mark (a market basket holding three shares) on a brand tile.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40, this.radius});

  final double size;

  /// Corner radius of the tile; defaults to a soft app-icon squircle.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Jugaad Street',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius ?? size * 0.26),
        child: SvgPicture.asset('assets/brand/app_icon.svg', width: size, height: size),
      ),
    );
  }
}

/// White basket only (for brand-coloured backgrounds such as the splash).
class BrandGlyph extends StatelessWidget {
  const BrandGlyph({super.key, this.size = 96});
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset('assets/brand/mark.svg', width: size, height: size);
}

/// Mark + "Jugaad Street" wordmark ("Street" in brand colour).
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.size = 32, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final ink = onDark ? Colors.white : AppColors.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: size),
        SizedBox(width: size * 0.32),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: 'Jugaad ', style: TextStyle(color: ink)),
            TextSpan(text: 'Street', style: TextStyle(color: onDark ? Colors.white : AppColors.brand)),
          ]),
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontFamilyFallback: const ['Roboto'],
            fontWeight: FontWeight.w800,
            fontSize: size * 0.62,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}
