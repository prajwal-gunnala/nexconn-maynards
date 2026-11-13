import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import 'detail_model.dart';
import 'detail_widgets.dart';

/// Frosted chip on the hero photo (type badge, countdown).
class HeroChip extends StatelessWidget {
  const HeroChip({super.key, required this.icon, required this.label, this.urgent = false});

  final IconData icon;
  final String label;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final fg = urgent ? Colors.white : AppColors.ink;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: urgent ? AppColors.brand : AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: urgent ? Colors.white : AppColors.brandDeep),
        const SizedBox(width: 6),
        Flexible(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              label,
              key: ValueKey(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label.copyWith(color: fg, fontWeight: FontWeight.w700).tab,
            ),
          ),
        ),
      ]),
    );
  }
}

/// Status pill for a closed bucket (hero + closed card).
class ClosedPill extends StatelessWidget {
  const ClosedPill({super.key, required this.status});

  final BucketStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = closedLook(status);
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label, style: AppText.label.copyWith(color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

(String, IconData, Color) closedLook(BucketStatus s) => switch (s) {
      BucketStatus.ordered => ('Ordered', Icons.receipt_long_rounded, AppColors.save),
      BucketStatus.marketDay => ('Market day', Icons.storefront_rounded, AppColors.brandDeep),
      BucketStatus.delivering => ('On the way', Icons.local_shipping_rounded, AppColors.save),
      BucketStatus.completed => ('Completed', Icons.check_circle_rounded, AppColors.save),
      BucketStatus.expired => ('Expired', Icons.history_rounded, AppColors.released),
      BucketStatus.cancelled => ('Cancelled', Icons.block_rounded, AppColors.released),
      _ => ('Closed', Icons.lock_outline_rounded, AppColors.released),
    };

class TitleBlock extends StatelessWidget {
  const TitleBlock({super.key, required this.view});

  final BucketView view;

  @override
  Widget build(BuildContext context) {
    final b = view.bucket;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(b.title, style: AppText.title.copyWith(fontSize: 22)),
      if (b.subtitle != null) ...[
        const SizedBox(height: AppSpace.xs),
        Text(b.subtitle!, style: AppText.bodyMuted),
      ],
    ]);
  }
}

class VendorRow extends StatelessWidget {
  const VendorRow({super.key, required this.bucket});

  final Bucket bucket;

  @override
  Widget build(BuildContext context) {
    final v = bucket.vendor;
    final by = bucket.createdBy;
    return Row(children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: AppColors.canvas, shape: BoxShape.circle, border: Border.all(color: AppColors.line)),
        child: const Icon(Icons.storefront_outlined, color: AppColors.brandDeep, size: 22),
      ),
      const SizedBox(width: AppSpace.md),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v?.name ?? 'Neighbour-run', style: AppText.label.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(
            [v?.place, if (by != null) 'started by ${by.name}${by.unit == null ? '' : ', ${by.unit}'}'].whereType<String>().join(' · '),
            style: AppText.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ]),
      ),
      if (v?.rating != null)
        Semantics(
          label: 'Rated ${v!.rating} out of 5',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppColors.saveTint, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star_rounded, size: 15, color: AppColors.save),
              const SizedBox(width: 2),
              Text(v.rating!.toStringAsFixed(1), style: AppText.label.copyWith(color: AppColors.save, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
    ]);
  }
}

/// Licious-style "500 g | 12-18 Pieces | Serves 4" strip.
class SpecStrip extends StatelessWidget {
  const SpecStrip({super.key, required this.view});

  final BucketView view;

  @override
  Widget build(BuildContext context) {
    final b = view.bucket;
    final unit = b.unitLabel ?? 'share';
    final goAt = view.x.goAt;
    final List<(IconData, String)> facts = switch (b.type) {
      BucketType.split => [
          (Icons.scale_outlined, b.netWeight ?? plural(b.units.length, unit)),
          (Icons.pie_chart_outline_rounded, '${b.units.length} ${b.units.length == 1 ? 'piece' : 'pieces'}'),
          (Icons.people_outline_rounded, b.serves == null ? '${b.progress.members} in' : 'Serves ${b.serves!.replaceAll(' families', '')}'),
        ],
      BucketType.bulk => [
          (Icons.inventory_2_outlined, b.netWeight ?? 'Per $unit'),
          (Icons.flag_outlined, 'Goes at ${plural(goAt ?? (b.tiers.isEmpty ? 1 : b.tiers.first.minQty), unit)}'),
          (Icons.people_outline_rounded, '${b.progress.members} in'),
        ],
      BucketType.service => [
          (Icons.home_outlined, 'Per $unit'),
          (Icons.flag_outlined, 'Goes at ${plural(goAt ?? 1, unit)}'),
          (Icons.event_outlined, b.deliverAt == null ? '${b.progress.members} in' : Fmt.day(b.deliverAt!)),
        ],
      BucketType.trip => [
          (Icons.local_shipping_outlined, '${b.capacity ?? b.progress.target} kg tempo'),
          (Icons.flag_outlined, 'Goes at ${fmtQty(view.x.minLoadKg ?? goAt ?? 1)} kg'),
          (Icons.schedule_rounded, b.deliverAt == null ? '${b.progress.members} in' : 'Back ${Fmt.time(tidyTime(b.deliverAt!))}'),
        ],
      BucketType.unknown => const [],
    };
    if (facts.isEmpty) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(12)),
      child: IntrinsicHeight(
        child: Row(children: [
          for (var i = 0; i < facts.length; i++) ...[
            if (i > 0) Center(child: Container(width: 1, height: 20, color: AppColors.line)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(facts[i].$1, size: 18, color: AppColors.inkMuted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      facts[i].$2,
                      style: AppText.label.copyWith(fontWeight: FontWeight.w600, height: 1.25),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Unit price, struck shop price, % off and "you save ₹x vs shop price".
class PriceBlock extends StatelessWidget {
  const PriceBlock({super.key, required this.view, this.draft});

  final BucketView view;

  /// The member's current pick (null when they already have a share).
  final JoinDraft? draft;

  @override
  Widget build(BuildContext context) {
    final b = view.bucket;
    final pr = Pricing(view);
    final d = draft;
    final unit = b.unitLabel ?? 'share';

    int? price;
    String per = unit;
    int? retail = b.retailUnitPrice;
    String? note;
    switch (b.type) {
      case BucketType.split:
        price = b.unitPrice;
        if (b.units.any((u) => u.grams != null)) per = 'kg';
        final from = b.units.isEmpty ? null : b.units.map((u) => u.price).reduce(math.min);
        final word = pluralWord(unit);
        note = from == null ? null : '${word[0].toUpperCase()}${word.substring(1)} from ${Fmt.rupees(from)}, priced by weight';
      case BucketType.bulk:
      case BucketType.service:
        final after = b.progress.filled + (d?.qty ?? 0);
        price = pr.unitPriceAt(after);
        note = b.status == BucketStatus.live
            ? 'Price now, at ${plural(after, unit)}${d?.qty != null && d!.qty! > 0 ? ' with yours' : ''}'
            : 'Final price, at ${plural(after, unit)}';
      case BucketType.trip:
        price = null;
      case BucketType.unknown:
        price = b.unitPrice;
    }

    final saving = d == null || d.isEmpty ? 0 : pr.savingOf(d);
    final String? saveLine;
    if (saving > 0) {
      final what = switch (b.type) {
        BucketType.split => b.units.where((u) => d!.unitIds.contains(u.id)).map((u) => u.label).join(' + '),
        BucketType.trip => 'your list',
        _ => plural(d!.qty ?? 0, unit),
      };
      saveLine = 'You save ${Fmt.rupees(saving)} vs shop price on $what';
    } else if (b.type == BucketType.trip) {
      final best = b.items
          .map((i) => Fmt.savePercent(price: i.price, retail: view.x.itemRetail[i.id] ?? i.price) ?? 0)
          .fold<int>(0, math.max);
      saveLine = best > 0 ? 'Wholesale prices, up to $best% below the shop' : null;
    } else if (price != null && retail != null && retail > price) {
      saveLine = '${Fmt.savePercent(price: price, retail: retail)}% below the shop price';
    } else {
      saveLine = null;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (price != null)
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          LiveText(Fmt.rupees(price), style: AppText.priceLarge.copyWith(fontSize: 26)),
          Text(' /$per', style: AppText.label.copyWith(color: AppColors.inkMuted)),
          if (retail != null && retail > price) ...[
            const SizedBox(width: AppSpace.sm),
            Text(
              Fmt.rupees(retail),
              style: AppText.body.copyWith(color: AppColors.inkMuted, decoration: TextDecoration.lineThrough, decorationColor: AppColors.inkMuted).tab,
            ),
            const SizedBox(width: AppSpace.sm),
            SaveBadge(percent: Fmt.savePercent(price: price, retail: retail)),
          ],
        ])
      else if (b.type == BucketType.trip)
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          LiveText(Fmt.rupees((view.x.transportPerKg ?? 0).round()), style: AppText.priceLarge.copyWith(fontSize: 26)),
          Text(' /kg transport now', style: AppText.label.copyWith(color: AppColors.inkMuted)),
        ]),
      if (note != null) ...[
        const SizedBox(height: 2),
        Text(note, style: AppText.caption),
      ],
      if (saveLine != null) ...[
        const SizedBox(height: AppSpace.sm),
        Row(children: [
          const Icon(Icons.savings_outlined, size: 16, color: AppColors.save),
          const SizedBox(width: 6),
          Expanded(child: LiveText(saveLine, style: AppText.label.copyWith(color: AppColors.save))),
        ]),
      ],
    ]);
  }
}

/// Banner for ordered / completed / expired buckets.
class ClosedCard extends StatelessWidget {
  const ClosedCard({super.key, required this.view, this.onOrder});

  final BucketView view;
  final VoidCallback? onOrder;

  @override
  Widget build(BuildContext context) {
    final b = view.bucket;
    final my = b.myShare;
    final (_, icon, color) = closedLook(b.status);
    final when = view.x.closedAt ?? b.cutoffAt;
    final unit = b.unitLabel ?? 'share';
    final expired = b.status == BucketStatus.expired || b.status == BucketStatus.cancelled;

    final String title;
    final String body;
    if (expired) {
      title = "This bucket didn't fill";
      final held = my?.hold;
      body = held != null && held.status == HoldStatus.released
          ? 'Your ${Fmt.rupees(held.amount)} hold was released${when == null ? '' : ' on ${Fmt.day(when)}'}. Nothing was paid.'
          : 'It closed${when == null ? '' : ' on ${Fmt.day(when)}'} with ${fmtQty(b.progress.filled)} of ${plural(b.progress.target, unit)}. Every hold was released.';
    } else if (b.status == BucketStatus.completed) {
      title = 'Delivered';
      final paid = my?.finalAmount ?? my?.amount;
      body = my == null
          ? '${fmtQty(b.progress.filled)} ${b.unitLabel ?? ''} went to ${b.progress.members} neighbours at ${Fmt.rupees(b.unitPrice ?? 0)}/${b.type == BucketType.split ? 'kg' : unit}.'
          : 'You paid ${Fmt.rupees(paid ?? 0)}'
              '${my.hold != null && my.hold!.amount > (paid ?? 0) ? ' of the ${Fmt.rupees(my.hold!.amount)} held; ${Fmt.rupees(my.hold!.amount - (paid ?? 0))} went back to you' : ''}.';
    } else {
      title = b.status == BucketStatus.marketDay ? 'Booked in full, see you at the market' : 'Bucket full, order sent';
      body = 'Order ${b.orderId ?? ''} has every member\'s share. ${b.vendor?.name ?? 'The vendor'} packs it per flat.';
    }
    final saved = view.x.mySavings;

    return DetailCard(
      color: expired ? AppColors.releasedTint : AppColors.saveTint,
      borderColor: Colors.transparent,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text(title, style: AppText.heading)),
        ]),
        const SizedBox(height: AppSpace.sm),
        Text(body, style: AppText.body.copyWith(color: AppColors.ink.withValues(alpha: 0.8))),
        if (saved != null && saved > 0) ...[
          const SizedBox(height: AppSpace.md),
          Row(children: [
            const Icon(Icons.savings_outlined, size: 18, color: AppColors.save),
            const SizedBox(width: 6),
            Text.rich(TextSpan(children: [
              TextSpan(text: 'You saved ', style: AppText.label),
              TextSpan(text: Fmt.rupees(saved), style: AppText.label.copyWith(color: AppColors.save, fontWeight: FontWeight.w800).tab),
              TextSpan(text: ' vs shop price', style: AppText.label),
            ])),
          ]),
        ],
        if (onOrder != null) ...[
          const SizedBox(height: AppSpace.md),
          InkWell(
            onTap: onOrder,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 44,
              child: Row(children: [
                const Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.brandDeep),
                const SizedBox(width: AppSpace.sm),
                Text('View order ${b.orderId}', style: AppText.label.copyWith(color: AppColors.brandDeep, fontWeight: FontWeight.w700)),
                const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.brandDeep),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

/// "Your share" summary with the hold status.
class MyShareCard extends StatelessWidget {
  const MyShareCard({super.key, required this.view, required this.share, this.onLeave, this.onFinish});

  final BucketView view;
  final Share share;
  final VoidCallback? onLeave;
  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context) {
    final b = view.bucket;
    final s = share;
    final what = view.x.myShareLabel ?? plural(s.qty, b.unitLabel ?? 'share');
    final hold = s.hold;
    final atMarket = s.payMode == PayMode.atMarket;
    final pr = Pricing(view);
    final unit = b.unitLabel ?? 'share';

    String? fine;
    if (!atMarket && hold != null && b.status == BucketStatus.live) {
      if ((b.type == BucketType.bulk || b.type == BucketType.service) && b.progress.nextTier != null) {
        final nt = b.progress.nextTier!;
        final lower = (s.qty * nt.unitPrice).round();
        final now = (s.qty * (b.unitPrice ?? 0)).round();
        final nowPart = now > 0 && now < hold.amount ? ': ${Fmt.rupees(now)} at today\'s ${plural(b.progress.filled, unit)},' : '.';
        fine = 'You pay at most ${Fmt.rupees(hold.amount)}$nowPart ${Fmt.rupees(lower)} if ${fmtQty(nt.remaining)} more '
            '${pluralWord(unit)} join. Anything above the final price is released.';
      } else if (b.type == BucketType.trip) {
        fine = 'You pay at most ${Fmt.rupees(hold.amount)}. Your transport share drops as the tempo fills.';
      } else {
        fine = 'You pay at most ${Fmt.rupees(hold.amount)}, only once the bucket fills.';
      }
    } else if (atMarket) {
      fine = 'Nothing is paid now. Pay ${b.vendor?.name.split(' ').first ?? 'the vendor'} at the stall.';
    }
    final pending = s.status == ShareStatus.pendingPayment;

    return DetailCard(
      borderColor: AppColors.brand.withValues(alpha: 0.35),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: AppColors.brandTint, shape: BoxShape.circle),
            child: const Icon(Icons.verified_rounded, color: AppColors.brand, size: 22),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.status == BucketStatus.live ? "You're in" : 'Your share', style: AppText.heading),
              Text(what, style: AppText.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
          StatusPill.share(s.status),
        ]),
        const Divider(height: AppSpace.xxl),
        _kv(atMarket ? 'Pay at the market' : (hold?.status == HoldStatus.captured ? 'Paid' : 'Held with UPI'),
            atMarket ? '≈ ${Fmt.rupees(s.estAmount)}' : Fmt.rupees(s.finalAmount ?? hold?.amount ?? s.estAmount),
            strong: true),
        if (hold?.vpa != null) ...[const SizedBox(height: AppSpace.sm), _kv('From', hold!.vpa!)],
        if (s.options.isNotEmpty) ...[
          const SizedBox(height: AppSpace.sm),
          _kv(view.x.optionGroups.where((g) => s.options.containsKey(g.key)).map((g) => g.label).firstOrNull?.replaceAll('?', '') ?? 'Options',
              s.options.values.join(', ')),
        ],
        if (b.type == BucketType.trip && s.items != null && s.items!.isNotEmpty) ...[
          const SizedBox(height: AppSpace.sm),
          _kv('Load', '${fmtQty(pr.kgOf({for (final i in s.items!) i.id: i.qty}))} kg'),
        ],
        if (fine != null) ...[
          const SizedBox(height: AppSpace.md),
          Text(fine, style: AppText.caption.copyWith(height: 1.4)),
        ],
        if (pending && onFinish != null) ...[
          const SizedBox(height: AppSpace.md),
          AppButton(label: 'Finish UPI hold', icon: Icons.lock_outline_rounded, onPressed: onFinish),
        ],
        if (onLeave != null) ...[
          const SizedBox(height: AppSpace.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onLeave,
              style: TextButton.styleFrom(foregroundColor: AppColors.danger, minimumSize: const Size(48, 48), padding: EdgeInsets.zero),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(
                hold != null && hold.status == HoldStatus.held ? 'Leave and release ${Fmt.rupees(hold.amount)}' : 'Leave this bucket',
                style: AppText.label.copyWith(color: AppColors.danger),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _kv(String k, String v, {bool strong = false}) => Row(children: [
        Expanded(child: Text(k, style: AppText.label.copyWith(color: AppColors.inkMuted))),
        Text(v, style: (strong ? AppText.price.copyWith(fontSize: 18) : AppText.label).tab),
      ]);
}

/// Avatar stack card: "Meera, Ravi and 5 others".
class MembersCard extends StatelessWidget {
  const MembersCard({super.key, required this.view, this.meId});

  final BucketView view;
  final String? meId;

  @override
  Widget build(BuildContext context) {
    final b = view.bucket;
    final people = <String>[];
    final seen = <String>{};
    final shares = [...b.shares.where((s) => !const {ShareStatus.left, ShareStatus.released}.contains(s.status))];
    // neighbours first, you last
    shares.sort((a, c) => (a.user.id == meId ? 1 : 0).compareTo(c.user.id == meId ? 1 : 0));
    for (final s in shares) {
      if (seen.add(s.user.id)) people.add(s.user.id == meId ? 'you' : s.user.name);
    }
    final total = math.max(b.progress.members, people.length);
    final unit = b.unitLabel ?? 'share';
    final p = b.progress;
    final String progressText = switch (b.type) {
      BucketType.split => '${fmtQty(p.filled)} of ${plural(p.target, unit)} taken',
      BucketType.trip => '${fmtQty(p.filled)} of ${fmtQty(p.target)} kg',
      _ => '${fmtQty(p.filled)} of ${plural(p.target, unit)}',
    };
    return DetailCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Neighbours in', style: AppText.heading),
          const Spacer(),
          LiveText('${p.percentRounded}% full', style: AppText.label.copyWith(color: AppColors.brandDeep)),
        ]),
        const SizedBox(height: AppSpace.md),
        MembersStrip(names: people, total: total, meName: shares.where((s) => s.user.id == meId).firstOrNull?.user.name),
        const SizedBox(height: AppSpace.md),
        AppProgressBar(value: p.fraction, height: 6),
        const SizedBox(height: AppSpace.sm),
        Row(children: [
          LiveText(progressText, style: AppText.caption),
          const Spacer(),
          if (p.held > 0) LiveText('${Fmt.rupees(p.held)} held so far', style: AppText.caption.copyWith(color: AppColors.held, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

/// Held now → Paid when full → Released if not.
class MoneySteps extends StatelessWidget {
  const MoneySteps({super.key, required this.view});

  final BucketView view;

  @override
  Widget build(BuildContext context) {
    final b = view.bucket;
    final close = b.cutoffAt == null ? 'at the cutoff' : shortWhen(b.cutoffAt!);
    final steps = [
      (Icons.lock_clock_outlined, 'Held now', 'Blocked in your bank. Still your money.', AppColors.held, AppColors.heldTint),
      (Icons.check_circle_outline_rounded, 'Paid when full', 'At the final price, never more than held.', AppColors.save, AppColors.saveTint),
      (Icons.undo_rounded, 'Released if not', 'Back to you automatically $close.', AppColors.released, AppColors.releasedTint),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const DetailSectionTitle('How your money works', subtitle: 'UPI Reserve: nothing leaves your account until the bucket fills'),
      DetailCard(
        padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.lg, AppSpace.md, AppSpace.lg),
        child: Stack(children: [
          // connector line behind the icons
          Positioned(
            top: 19,
            left: 40,
            right: 40,
            child: Row(children: [
              for (var i = 0; i < 2; i++) ...[
                Expanded(child: Container(height: 2, color: AppColors.line)),
                if (i == 0) const SizedBox(width: 40),
              ],
            ]),
          ),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final s in steps)
              Expanded(
                child: Column(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: s.$5, shape: BoxShape.circle, border: Border.all(color: AppColors.surface, width: 3)),
                    child: Icon(s.$1, size: 20, color: s.$4),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(s.$2, style: AppText.label.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(s.$3, style: AppText.tiny.copyWith(fontWeight: FontWeight.w500, height: 1.35), textAlign: TextAlign.center),
                  ),
                ]),
              ),
          ]),
        ]),
      ),
    ]);
  }
}

/// "Cleaned and cut free · one delivery to Gate 2".
class VendorPromise extends StatelessWidget {
  const VendorPromise({super.key, required this.view});

  final BucketView view;

  @override
  Widget build(BuildContext context) {
    final b = view.bucket;
    final at = b.pickupPoint ?? 'the gate';
    final when = b.deliverAt == null ? null : (b.type == BucketType.service ? whenText(b.deliverAt!) : pickupWindow(b.deliverAt!));
    final cat = (b.category ?? '').toLowerCase();
    final atMarket = b.settleMode == PayMode.atMarket;
    final (IconData icon, String head) = switch (b.type) {
      _ when atMarket => (Icons.handshake_outlined, 'Pay at the stall · cash or UPI'),
      BucketType.split when cat == 'fish' || cat == 'meat' => (Icons.content_cut_rounded, 'Cleaned and cut free · one delivery to $at'),
      BucketType.split => (Icons.inventory_2_outlined, 'Packed per flat · one delivery to $at'),
      BucketType.bulk => (Icons.inventory_2_outlined, 'Packed per flat · one delivery to $at'),
      BucketType.service => (Icons.verified_user_outlined, 'Verified team · one visit day for the tower'),
      BucketType.trip => (Icons.shopping_bag_outlined, 'Sorted by flat · collect at $at'),
      BucketType.unknown => (Icons.local_shipping_outlined, 'One delivery to $at'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
      decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icon, size: 20, color: AppColors.brandDeep),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(head, style: AppText.label.copyWith(color: AppColors.brandDeep, fontWeight: FontWeight.w700)),
            if (when != null) ...[
              const SizedBox(height: 2),
              Text(atMarket ? 'Meet ${whenText(view.x.meetAt ?? b.deliverAt!)}' : '${b.type == BucketType.service ? 'Visit' : 'Pickup'} $when',
                  style: AppText.caption.copyWith(color: AppColors.brandDeep.withValues(alpha: 0.8))),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Sticky bottom panel: info strip + amount + CTA.
class DetailCta extends StatelessWidget {
  const DetailCta({
    super.key,
    required this.view,
    required this.draft,
    required this.active,
    required this.busy,
    required this.onJoin,
    this.onLeave,
    this.onFinish,
    this.onOrder,
    this.onBrowse,
  });

  final BucketView view;
  final JoinDraft draft;
  final bool active;
  final bool busy;
  final VoidCallback onJoin;
  final VoidCallback? onLeave;
  final VoidCallback? onFinish;
  final VoidCallback? onOrder;
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    final b = view.bucket;
    final live = b.status == BucketStatus.live;
    final atMarket = b.settleMode == PayMode.atMarket;
    final pr = Pricing(view);
    final unit = b.unitLabel ?? 'share';
    final my = b.myShare;

    final String strip;
    Color stripFg = AppColors.held, stripBg = AppColors.heldTint;
    IconData stripIcon = Icons.lock_clock_outlined;
    Widget? leading;
    Widget button;

    if (!live) {
      stripFg = AppColors.released;
      stripBg = AppColors.releasedTint;
      stripIcon = Icons.lock_outline_rounded;
      strip = switch (b.status) {
        BucketStatus.expired || BucketStatus.cancelled => 'This bucket closed without filling',
        BucketStatus.marketDay when view.x.meetAt != null =>
          'Market day · meet at ${view.x.meetPlace ?? b.pickupPoint ?? 'the gate'}, ${whenText(view.x.meetAt!)}',
        BucketStatus.completed => 'Completed · thanks for buying together',
        _ => 'This bucket is closed to new shares',
      };
      if (b.status == BucketStatus.marketDay) {
        stripFg = AppColors.brandDeep;
        stripBg = AppColors.brandTint;
        stripIcon = Icons.storefront_outlined;
      }
      button = onOrder != null
          ? AppButton(label: 'View order ${b.orderId}', icon: Icons.receipt_long_outlined, onPressed: onOrder)
          : AppButton.ghost(label: 'See live buckets', onPressed: onBrowse);
    } else if (active && my != null) {
      final amt = my.payMode == PayMode.atMarket ? '≈ ${Fmt.rupees(my.estAmount)} at the stall' : '${Fmt.rupees(my.hold?.amount ?? my.estAmount)} ${my.status == ShareStatus.pendingPayment ? 'to hold' : 'held'}';
      leading = _Amount(top: "You're in", bottom: amt, bottomColor: my.payMode == PayMode.atMarket ? AppColors.brandDeep : AppColors.held);
      if (my.status == ShareStatus.pendingPayment && onFinish != null) {
        button = AppButton(label: 'Finish hold', onPressed: onFinish, loading: busy);
      } else {
        button = AppButton.ghost(label: 'Leave', icon: Icons.logout_rounded, onPressed: onLeave, loading: busy);
      }
      strip = my.payMode == PayMode.atMarket
          ? 'Booked · leave any time before the cutoff'
          : 'Held, not paid · released if it doesn\'t fill';
    } else {
      final amount = pr.quote(draft);
      final saving = draft.isEmpty ? 0 : pr.savingOf(draft);
      final empty = draft.isEmpty || amount <= 0;
      final pickHint = switch (b.type) {
        BucketType.split => isPart(b) ? 'Pick a cut first' : 'Pick a $unit first',
        BucketType.trip => 'Add items first',
        _ => 'Choose a quantity',
      };
      final fromPrice = b.units.isEmpty ? null : b.units.map((u) => u.price).reduce(math.min);
      leading = _Amount(
        top: empty
            ? (fromPrice != null ? 'from ${Fmt.rupees(fromPrice)}' : b.type == BucketType.trip ? 'No items yet' : Fmt.rupees(0))
            : Fmt.rupees(amount),
        bottom: empty
            ? (atMarket ? 'pay at the market' : 'nothing charged now')
            : saving > 0
                ? 'you save ${Fmt.rupees(saving)}'
                : (atMarket ? 'pay at the market' : 'held, not paid'),
        bottomColor: !empty && saving > 0 ? AppColors.save : AppColors.inkMuted,
        big: !empty,
      );
      final label = atMarket
          ? (draft.unitIds.length > 1 ? 'Book my ${pluralWord(unit)}' : 'Book my $unit')
          : 'Hold ${Fmt.rupees(amount)}';
      button = empty
          ? _DisabledCta(label: pickHint)
          : AppButton(label: label, icon: atMarket ? Icons.event_available_rounded : Icons.lock_outline_rounded, onPressed: onJoin);
      strip = atMarket
          ? 'No prepayment · pay ${b.vendor?.name.split(' ').first ?? 'the vendor'} when you meet'
          : _finalPriceLine(view, draft) ?? 'Held, not paid · released if it doesn\'t fill';
      if (atMarket) {
        stripFg = AppColors.brandDeep;
        stripBg = AppColors.brandTint;
        stripIcon = Icons.storefront_outlined;
      }
    }

    return Material(
      color: AppColors.surface,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: double.infinity,
            color: stripBg,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter, vertical: 7),
            child: Row(children: [
              Icon(stripIcon, size: 15, color: stripFg),
              const SizedBox(width: 6),
              Expanded(child: LiveText(strip, style: AppText.caption.copyWith(color: stripFg, fontWeight: FontWeight.w600))),
            ]),
          ),
        StickyCta(
          leading: leading,
          child: button,
        ),
      ]),
    );
  }

  static bool isPart(Bucket b) => b.units.isNotEmpty && b.units.first.label.toLowerCase().startsWith('head') && b.units.length > 2;

  /// "You pay ₹880 if 100 kg is reached" (bulk/service only).
  static String? _finalPriceLine(BucketView v, JoinDraft d) {
    final b = v.bucket;
    if (b.type != BucketType.bulk && b.type != BucketType.service) return null;
    final q = d.qty ?? 0;
    if (q <= 0) return null;
    final pr = Pricing(v);
    final next = pr.nextTierAfter(b.progress.filled + q);
    if (next == null) return 'Best tier reached · you pay at most ${Fmt.rupees(pr.quote(d))}';
    final unit = b.unitLabel ?? 'unit';
    return b.type == BucketType.service
        ? 'You pay ${Fmt.rupees(q * next.unitPrice)} if ${plural(next.minQty, unit)} sign up'
        : 'You pay ${Fmt.rupees(q * next.unitPrice)} if ${plural(next.minQty, unit)} is reached';
  }
}

/// Readable disabled CTA that says what to do first ("Pick a cut to hold").
class _DisabledCta extends StatelessWidget {
  const _DisabledCta({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: false,
      label: label,
      excludeSemantics: true,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
        decoration: BoxDecoration(color: const Color(0xFFEDEAE7), borderRadius: BorderRadius.circular(14)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.touch_app_outlined, size: 18, color: Color(0xFF6E6660)),
          const SizedBox(width: AppSpace.sm),
          Flexible(
            child: Text(label, style: AppText.heading.copyWith(fontSize: 15, color: const Color(0xFF5E5751)), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.top, required this.bottom, this.bottomColor = AppColors.inkMuted, this.big = true});

  final String top;
  final String bottom;
  final Color bottomColor;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 96, maxWidth: 150),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        LiveText(top, style: big ? AppText.price.copyWith(fontSize: 20) : AppText.heading),
        const SizedBox(height: 2),
        LiveText(bottom, style: AppText.caption.copyWith(color: bottomColor, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Confirm sheet before leaving (releases the hold).
Future<bool?> showLeaveSheet(BuildContext context, {required BucketView view, required Share share}) {
  final b = view.bucket;
  final hold = share.hold;
  final what = view.x.myShareLabel ?? plural(share.qty, b.unitLabel ?? 'share');
  final releases = hold != null && (hold.status == HoldStatus.held || hold.status == HoldStatus.created);
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.xxl, 0, AppSpace.xxl, AppSpace.lg),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Leave this bucket?', style: AppText.title),
          const SizedBox(height: AppSpace.sm),
          Text(
            releases
                ? 'Your ${Fmt.rupees(hold.amount)} hold is released right away. $what opens up for neighbours.'
                : 'Your booking is cancelled and $what opens up for neighbours.',
            style: AppText.bodyMuted,
          ),
          const SizedBox(height: AppSpace.xxl),
          AppButton(label: 'Keep my share', onPressed: () => Navigator.pop(context, false)),
          const SizedBox(height: AppSpace.sm),
          AppButton.ghost(
            label: releases ? 'Leave and release ${Fmt.rupees(hold.amount)}' : 'Leave',
            onPressed: () => Navigator.pop(context, true),
          ),
        ]),
      ),
    ),
  );
}
