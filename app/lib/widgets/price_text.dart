import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';

/// `₹88 /kg  ₹120  27% off` — price, struck retail price and a save badge.
class PriceText extends StatelessWidget {
  const PriceText({
    super.key,
    required this.price,
    this.retail,
    this.per,
    this.large = false,
    this.showBadge = true,
  });

  final int price;
  final int? retail;

  /// Unit suffix, e.g. `kg`, `cut`, `flat`.
  final String? per;
  final bool large;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final pct = retail == null ? null : Fmt.savePercent(price: price, retail: retail!);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: Fmt.rupees(price), style: large ? AppText.priceLarge : AppText.price),
          if (per != null) TextSpan(text: ' /$per', style: AppText.caption),
        ])),
        if (pct != null)
          Text(
            Fmt.rupees(retail!),
            style: AppText.caption.copyWith(decoration: TextDecoration.lineThrough, decorationColor: AppColors.inkMuted),
          ),
        if (pct != null && showBadge) SaveBadge(percent: pct),
      ],
    );
  }
}

/// Green `27% off` / `Save ₹420` chip.
class SaveBadge extends StatelessWidget {
  const SaveBadge({super.key, this.percent, this.amount});

  final int? percent;
  final int? amount;

  @override
  Widget build(BuildContext context) {
    final text = percent != null ? '$percent% off' : 'Save ${Fmt.rupees(amount ?? 0)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: AppColors.saveTint, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: AppText.tiny.copyWith(color: AppColors.save, fontWeight: FontWeight.w700)),
    );
  }
}
