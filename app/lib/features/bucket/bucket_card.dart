import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import 'bucket_visuals.dart';

/// Licious-style product card for a bucket in lists: photo, title,
/// "Net wt · Pieces · Serves" line, price with strike + save, progress.
class BucketCard extends StatelessWidget {
  const BucketCard({super.key, required this.bucket});

  final Bucket bucket;

  @override
  Widget build(BuildContext context) {
    final b = bucket;
    final p = b.progress;
    final unit = b.unitLabel ?? 'share';
    final facts = [
      if (b.netWeight != null) 'Net wt ${b.netWeight}',
      if (b.units.isNotEmpty) '${b.units.length} pieces',
      if (b.serves != null) 'Serves ${b.serves}',
    ];
    return InkWell(
      borderRadius: AppRadius.cardBorder,
      onTap: () => context.push('/bucket/${b.id}'),
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(color: AppColors.line),
        ),
        padding: const EdgeInsets.all(AppSpace.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BucketPhoto(visual: BucketVisual.of(b.image ?? b.category ?? b.title), url: b.image, height: 150),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.title, style: AppText.heading, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (b.subtitle != null) Text(b.subtitle!, style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (facts.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(facts.join('  ·  '), style: AppText.caption.copyWith(color: AppColors.ink)),
              ],
              const SizedBox(height: 8),
              if (b.unitPrice != null) PriceText(price: b.unitPrice!, retail: b.retailUnitPrice, per: unit),
              const SizedBox(height: 10),
              AppProgressBar(value: p.fraction),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: Text('${p.members} neighbours · ${p.percentRounded}% full', style: AppText.caption)),
                if (b.cutoffAt != null) Text(Fmt.timeLeft(b.cutoffAt!), style: AppText.caption.copyWith(color: AppColors.brandDeep)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
