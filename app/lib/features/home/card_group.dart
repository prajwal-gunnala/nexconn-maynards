import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import '../bucket/card_parts.dart';
import '../bucket/list_logic.dart';

/// "Join your neighbours" card: leads with the people and the shared goal;
/// the product is a small thumbnail. One CTA: "Join them".
class GroupBucketCard extends StatelessWidget {
  const GroupBucketCard({super.key, required this.bucket, this.meId});

  final Bucket bucket;
  final String? meId;

  @override
  Widget build(BuildContext context) {
    final b = bucket;
    final pct = b.savePercent;
    final price = b.displayPrice;
    void open() => openBucket(context, b.id);
    return Semantics(
      container: true,
      label: '${b.peopleLine(meId: meId)}. ${b.goalHeadline}.',
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder, side: const BorderSide(color: AppColors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                AvatarStack(users: b.people, size: 34, max: 5),
                const Spacer(),
                if (b.cutoffAt != null) _Closes(cutoff: b.cutoffAt!),
              ]),
              const SizedBox(height: AppSpace.sm),
              Text(b.peopleLine(meId: meId), style: AppText.label.copyWith(color: AppColors.inkMuted, height: 1.35), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpace.md),
              Text(b.goalHeadline, style: AppText.title.copyWith(fontSize: 19, height: 1.25)),
              const SizedBox(height: AppSpace.md),
              AppProgressBar(value: b.progress.fraction, markers: b.tierMarkers, height: 8, track: AppColors.brandTint),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: Text(b.progressCaption, style: AppText.caption.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600)),
                ),
                Text('${b.progress.percentRounded}% there', style: AppText.caption),
              ]),
              const SizedBox(height: AppSpace.lg),
              const Divider(),
              const SizedBox(height: AppSpace.md),
              Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(width: 48, height: 48, child: CardPhoto(bucket: b)),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(shortTitle(b.title), style: AppText.label.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(children: [
                        if (price != null)
                          TextSpan(
                            text: '${b.type == BucketType.trip ? 'from ' : ''}${Fmt.rupees(price)}/${b.priceUnit}',
                            style: AppText.caption.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700),
                          ),
                        if (pct != null) TextSpan(text: '  $pct% below shop', style: AppText.caption.copyWith(color: AppColors.save, fontWeight: FontWeight.w700)),
                        if (pct == null && b.vendor != null) TextSpan(text: '  ${b.vendor!.name}', style: AppText.caption),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]),
                ),
              ]),
              const SizedBox(height: AppSpace.md),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: open,
                  style: FilledButton.styleFrom(
                    backgroundColor: b.myShare != null ? AppColors.saveTint : AppColors.brand,
                    foregroundColor: b.myShare != null ? AppColors.save : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(b.myShare != null ? "You're in · view your share" : 'Join them',
                      style: AppText.heading.copyWith(fontSize: 15, color: b.myShare != null ? AppColors.save : Colors.white)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Closes extends StatelessWidget {
  const _Closes({required this.cutoff});

  final DateTime cutoff;

  @override
  Widget build(BuildContext context) {
    final urgent = cutoff.difference(StreetClock.now()).inHours < 3;
    final fg = urgent ? AppColors.brandDeep : AppColors.held;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(color: urgent ? AppColors.brandTint : AppColors.heldTint, borderRadius: BorderRadius.circular(AppRadius.chip)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.schedule_rounded, size: 14, color: fg),
        const SizedBox(width: 4),
        Countdown(cutoff: cutoff, style: AppText.tiny.copyWith(color: fg, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
