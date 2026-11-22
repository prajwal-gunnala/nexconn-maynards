import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import '../bucket/card_parts.dart';
import '../bucket/list_logic.dart';

/// "Join your neighbours" card, photo-led: the product photo with the type,
/// time left and saving on it; then the shared goal, a progress bar, who is
/// in, and the price against the shop with one CTA ("Join them").
class GroupBucketCard extends StatelessWidget {
  const GroupBucketCard({super.key, required this.bucket, this.meId});

  final Bucket bucket;
  final String? meId;

  @override
  Widget build(BuildContext context) {
    final b = bucket;
    final pct = b.savePercent;
    final price = b.displayPrice;
    final retail = b.displayRetail;
    final joined = b.myShare != null;
    final r = BorderRadius.circular(AppRadius.feature);
    void open() => openBucket(context, b.id);
    return Semantics(
      container: true,
      label: '${b.peopleLine(meId: meId)}. ${b.goalHeadline}.',
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: r, boxShadow: AppShadows.card),
        child: Material(
          color: AppColors.surface,
          borderRadius: r,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: open,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                height: 168,
                child: Stack(fit: StackFit.expand, children: [
                  CardPhoto(bucket: b),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x26000000), Color(0x00000000), Color(0x9E000000)],
                        stops: [0, 0.4, 1],
                      ),
                    ),
                  ),
                  Positioned(top: AppSpace.md, left: AppSpace.md, child: _TypeChip(bucket: b)),
                  if (b.cutoffAt != null) Positioned(top: AppSpace.md, right: AppSpace.md, child: CountdownChip(cutoff: b.cutoffAt!)),
                  Positioned(
                    left: AppSpace.lg,
                    right: AppSpace.lg,
                    bottom: AppSpace.md,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text(shortTitle(b.title),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.heading.copyWith(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                          if (b.vendor != null)
                            Text(b.vendor!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.caption.copyWith(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      if (pct != null) ...[
                        const SizedBox(width: AppSpace.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.save, borderRadius: BorderRadius.circular(AppRadius.chip)),
                          child: Text('$pct% below shop', style: AppText.tiny.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ]),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.lg),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.goalHeadline, style: AppText.title.copyWith(fontSize: 18, height: 1.25, letterSpacing: -0.4)),
                  const SizedBox(height: AppSpace.md + 2),
                  AppProgressBar(
                    value: b.progress.fraction,
                    markers: b.tierMarkers,
                    height: 10,
                    track: AppColors.brandTint,
                    gradient: AppGradients.progress,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Row(children: [
                    Expanded(
                      child: Text(b.progressCaption, style: AppText.caption.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700)),
                    ),
                    Text('${b.progress.percentRounded}%', style: AppText.caption.copyWith(color: AppColors.brandDeep, fontWeight: FontWeight.w800)),
                    Text(' there', style: AppText.caption),
                  ]),
                  const SizedBox(height: AppSpace.md + 2),
                  Container(
                    padding: const EdgeInsets.fromLTRB(AppSpace.sm, AppSpace.sm, AppSpace.md, AppSpace.sm),
                    decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(AppRadius.photo)),
                    child: Row(children: [
                      AvatarStack(users: b.people, size: 28, max: 4),
                      const SizedBox(width: AppSpace.sm + 2),
                      Expanded(
                        child: Text(b.peopleLine(meId: meId),
                            style: AppText.caption.copyWith(color: AppColors.inkMuted, fontWeight: FontWeight.w600, height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        if (price != null)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text.rich(
                              TextSpan(children: [
                                if (b.type == BucketType.trip) TextSpan(text: 'from ', style: AppText.caption.copyWith(fontWeight: FontWeight.w600)),
                                TextSpan(text: Fmt.rupees(price), style: AppText.price.copyWith(fontSize: 21, letterSpacing: -0.5)),
                                TextSpan(text: '/${b.priceUnit}', style: AppText.caption.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600)),
                              ]),
                              maxLines: 1,
                            ),
                          ),
                        if (retail != null && price != null && retail > price)
                          Text.rich(
                            TextSpan(children: [
                              TextSpan(text: 'Shop ', style: AppText.caption),
                              TextSpan(
                                text: Fmt.rupees(retail),
                                style: AppText.caption.copyWith(decoration: TextDecoration.lineThrough, decorationColor: AppColors.inkMuted),
                              ),
                            ]),
                            maxLines: 1,
                          )
                        else if (b.vendor != null && price == null)
                          Text(b.vendor!.name, style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    const SizedBox(width: AppSpace.md),
                    _JoinButton(joined: joined, onPressed: open),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Frosted type chip on the photo: `Split`, `Bulk`, `Book & meet`...
class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.bucket});

  final Bucket bucket;

  @override
  Widget build(BuildContext context) {
    final atMarket = bucket.settleMode == PayMode.atMarket;
    final label = atMarket ? 'Book & meet' : bucket.typeLabel;
    final icon = switch (bucket.type) {
      BucketType.split => Icons.call_split_rounded,
      BucketType.bulk => Icons.inventory_2_rounded,
      BucketType.service => Icons.handyman_rounded,
      BucketType.trip => Icons.local_shipping_rounded,
      BucketType.unknown => Icons.shopping_basket_rounded,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 4, 10, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: Colors.white),
        const SizedBox(width: 5),
        Text(label, style: AppText.tiny.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({required this.joined, required this.onPressed});

  final bool joined;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(AppRadius.card);
    final fg = joined ? AppColors.save : Colors.white;
    return Semantics(
      button: true,
      label: joined ? "You're in, view your share" : 'Join them',
      excludeSemantics: true,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: r,
          color: joined ? AppColors.saveTint : null,
          gradient: joined ? null : AppGradients.button,
          boxShadow: joined ? null : AppShadows.brand,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: r,
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg + 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(joined ? "You're in" : 'Join them', style: AppText.heading.copyWith(fontSize: 15, color: fg, fontWeight: FontWeight.w800)),
                const SizedBox(width: 6),
                Icon(joined ? Icons.check_circle_rounded : Icons.arrow_forward_rounded, size: 18, color: fg),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
