import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import 'detail_model.dart';
import 'detail_widgets.dart';
import 'share_map_view.dart';

/// The type-specific middle of the detail page.
class TypeModule extends StatelessWidget {
  const TypeModule({
    super.key,
    required this.view,
    required this.draft,
    required this.onChanged,
    required this.interactive,
    this.myUnit,
    this.onLimit,
  });

  final BucketView view;
  final JoinDraft draft;
  final ValueChanged<JoinDraft> onChanged;

  /// False once the member has a share or the bucket is closed.
  final bool interactive;
  final String? myUnit;
  final ValueChanged<String>? onLimit;

  @override
  Widget build(BuildContext context) => switch (view.bucket.type) {
        BucketType.split => SplitModule(view: view, draft: draft, onChanged: onChanged, interactive: interactive, onLimit: onLimit),
        BucketType.bulk => BulkModule(view: view, draft: draft, onChanged: onChanged, interactive: interactive),
        BucketType.service => ServiceModule(view: view, draft: draft, onChanged: onChanged, interactive: interactive, myUnit: myUnit),
        BucketType.trip => TripModule(view: view, draft: draft, onChanged: onChanged, interactive: interactive),
        BucketType.unknown => const SizedBox.shrink(),
      };
}

/// Option groups (cut style, flat size, slot). ≤3 choices → segmented control.
class OptionGroupsBlock extends StatelessWidget {
  const OptionGroupsBlock({super.key, required this.groups, required this.draft, required this.onChanged, required this.enabled});

  final List<OptionGroup> groups;
  final JoinDraft draft;
  final ValueChanged<JoinDraft> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final g in groups) ...[
        if (g != groups.first) const SizedBox(height: AppSpace.md),
        if (g.choices.length <= 3 && g.choices.every((c) => c.length <= 10))
          _Segmented(
            label: g.label,
            choices: g.choices,
            value: draft.options[g.key],
            onChanged: enabled ? (c) => onChanged(draft.copyWith(options: {...draft.options, g.key: c})) : null,
          )
        else
          OptionPills(
            label: g.label,
            choices: g.choices,
            value: draft.options[g.key],
            onChanged: (c) {
              if (enabled) onChanged(draft.copyWith(options: {...draft.options, g.key: c}));
            },
          ),
      ],
    ]);
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.label, required this.choices, required this.value, required this.onChanged});

  final String label;
  final List<String> choices;
  final String? value;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppText.label),
      const SizedBox(height: AppSpace.sm),
      Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
        child: Row(children: [
          for (final c in choices)
            Expanded(
              child: Semantics(
                selected: c == value,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onChanged == null ? null : () => onChanged!(c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c == value ? AppColors.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: c == value ? [BoxShadow(color: AppColors.ink.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 1))] : null,
                    ),
                    child: Text(c, style: AppText.label.copyWith(color: c == value ? AppColors.brandDeep : AppColors.inkMuted)),
                  ),
                ),
              ),
            ),
        ]),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Split

class SplitModule extends StatelessWidget {
  const SplitModule({super.key, required this.view, required this.draft, required this.onChanged, required this.interactive, this.onLimit});

  final BucketView view;
  final JoinDraft draft;
  final ValueChanged<JoinDraft> onChanged;
  final bool interactive;
  final ValueChanged<String>? onLimit;

  void _tap(BucketUnit u) {
    final sel = [...draft.unitIds];
    if (sel.contains(u.id)) {
      sel.remove(u.id);
    } else {
      final max = view.x.maxUnitsPerMember;
      if (max == 1) {
        sel
          ..clear()
          ..add(u.id);
      } else if (max != null && sel.length >= max) {
        onLimit?.call('You can take at most $max ${plural(max, view.bucket.unitLabel ?? 'part').split(' ').last} in this bucket.');
        return;
      } else {
        sel.add(u.id);
      }
    }
    onChanged(draft.copyWith(unitIds: sel));
  }

  @override
  Widget build(BuildContext context) {
    final b = view.bucket;
    final my = b.myShare;
    final mine = my != null && !const {ShareStatus.left, ShareStatus.released}.contains(my.status) ? my.unitIds.toSet() : const <String>{};
    final live = b.status == BucketStatus.live;
    final open = b.units.where((u) => u.isOpen && !mine.contains(u.id)).toList();
    final taken = b.units.length - open.length;
    final picked = b.units.where((u) => draft.unitIds.contains(u.id)).toList();
    final fish = isFishSplit(b);
    final unit = b.unitLabel ?? 'part';
    final perMember = view.x.maxUnitsPerMember;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      DetailSectionTitle(
        interactive
            ? (fish ? 'Pick your cut' : 'Pick your $unit')
            : live
                ? (fish ? 'Who has which cut' : 'Who has which $unit')
                : 'How it was split',
        subtitle: interactive
            ? '${open.length} of ${b.units.length} open · tap ${fish ? 'the fish' : 'a tile'} to pick${perMember != null ? ' (up to $perMember)' : ''}'
            : '${b.units.length - open.length} of ${plural(b.units.length, unit)} taken',
      ),
      DetailCard(
        padding: EdgeInsets.fromLTRB(AppSpace.lg, fish ? AppSpace.xl : AppSpace.lg, AppSpace.lg, AppSpace.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ShareMap(bucket: b, selected: draft.unitIds.toSet(), mine: mine, onTap: _tap, enabled: interactive),
          if (fish) ...[
            const SizedBox(height: AppSpace.md),
            ShareMapLegend(
              open: open.length,
              taken: taken,
              example: b.units.where((u) => u.owner != null && !mine.contains(u.id)).firstOrNull,
            ),
          ],
        ]),
      ),
      if (interactive && open.isNotEmpty && fish) ...[
        const SizedBox(height: AppSpace.sm),
        // Accessible list of open parts (the fish slices are narrow).
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final u in open) ...[
              ChoicePill(
                label: '${u.label} · ${Fmt.rupees(u.price)}',
                selected: draft.unitIds.contains(u.id),
                onTap: () => _tap(u),
              ),
              const SizedBox(width: AppSpace.sm),
            ],
          ]),
        ),
      ],
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: picked.isEmpty || !interactive
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: AppSpace.md),
                child: DetailCard(
                  borderColor: AppColors.brand.withValues(alpha: 0.4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final u in picked) _PickedRow(unit: u, retailPerKg: b.retailUnitPrice),
                    if (view.x.optionGroups.isNotEmpty) ...[
                      const Divider(height: AppSpace.xxl),
                      OptionGroupsBlock(groups: view.x.optionGroups, draft: draft, onChanged: onChanged, enabled: interactive),
                    ],
                  ]),
                ),
              ),
      ),
    ]);
  }
}

class _PickedRow extends StatelessWidget {
  const _PickedRow({required this.unit, this.retailPerKg});

  final BucketUnit unit;
  final int? retailPerKg;

  @override
  Widget build(BuildContext context) {
    final retail = unit.grams == null || retailPerKg == null ? null : (unit.grams! / 1000 * retailPerKg!).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xs),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(unit.label, style: AppText.heading),
            if (unit.grams != null) Text('about ${fmtKg(unit.grams!)} kg', style: AppText.caption),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(Fmt.rupees(unit.price), style: AppText.price.tab),
          if (retail != null && retail > unit.price)
            Text(
              Fmt.rupees(retail),
              style: AppText.caption.copyWith(decoration: TextDecoration.lineThrough, decorationColor: AppColors.inkMuted).tab,
            ),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Bulk

class BulkModule extends StatelessWidget {
  const BulkModule({super.key, required this.view, required this.draft, required this.onChanged, required this.interactive});

  final BucketView view;
  final JoinDraft draft;
  final ValueChanged<JoinDraft> onChanged;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final b = view.bucket;
    final x = view.x;
    final pr = Pricing(view);
    final unit = b.unitLabel ?? 'kg';
    final p = b.progress;
    final mine = interactive ? (draft.qty ?? 0) : 0;
    final after = p.filled + mine;
    final target = p.target > 0 ? p.target : (pr.tiers.isNotEmpty ? pr.tiers.last.minQty : 1);
    final scale = math.max(target, after).toDouble();
    final next = pr.nextTierAfter(after);
    final people = p.members + (mine > 0 ? 1 : 0);
    final step = bulkStep(view);
    final min = x.minQty ?? 1;
    final lotLeft = x.lotQty == null ? null : x.lotQty! - p.filled;
    final max = [x.maxQty, lotLeft].whereType<num>().fold<num>(9999, math.min).toInt();
    final q = draft.qty ?? 0;

    final String headline;
    if (next != null) {
      headline = '${plural(next.minQty - after, unit)} more unlocks ${Fmt.rupees(next.unitPrice)}/$unit for all $people of you';
    } else if (pr.tiers.isNotEmpty) {
      headline = 'Best price unlocked: ${Fmt.rupees(pr.unitPriceAt(after))}/$unit for everyone';
    } else {
      headline = '${plural(target - after, unit)} to go';
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const DetailSectionTitle('Price drops as the group grows', subtitle: 'Everyone pays the tier reached at the cutoff'),
      DetailCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Group total', style: AppText.label.copyWith(color: AppColors.inkMuted)),
            const Spacer(),
            LiveText('${fmtQty(p.filled)} of ${plural(target, unit)}', style: AppText.heading),
          ]),
          const SizedBox(height: AppSpace.md),
          _GhostedBar(
            filled: p.filled / scale,
            withMine: after / scale,
            markers: [
              for (final t in pr.tiers)
                TierMarker(at: t.minQty / scale, label: '${t.minQty} $unit', reached: after >= t.minQty),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          _TierLadder(tiers: pr.tiers, reachedAt: after, unit: unit, retail: b.retailUnitPrice),
          const SizedBox(height: AppSpace.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 10),
            decoration: BoxDecoration(color: AppColors.saveTint, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.trending_down_rounded, size: 18, color: AppColors.save),
              const SizedBox(width: AppSpace.sm),
              Expanded(child: LiveText(headline, style: AppText.label.copyWith(color: const Color(0xFF0B7A3B)))),
            ]),
          ),
        ]),
      ),
      if (interactive) ...[
        const SizedBox(height: AppSpace.md),
        DetailCard(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.sm, AppSpace.md),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Your quantity', style: AppText.heading),
                const SizedBox(height: 2),
                Text(
                  [
                    if (step > 1) 'in ${plural(step, unit)} ${b.netWeight?.contains('bag') == true ? 'bags' : 'steps'}',
                    if (x.maxQty != null) 'max ${plural(x.maxQty!, unit)}',
                  ].join(' · ').ifEmpty('min ${plural(min, unit)}'),
                  style: AppText.caption,
                ),
              ]),
            ),
            QtyStepper(
              label: plural(q, unit),
              semanticsLabel: 'Your quantity ${plural(q, unit)}',
              onMinus: q - step >= min ? () => onChanged(draft.copyWith(qty: q - step)) : null,
              onPlus: q + step <= max ? () => onChanged(draft.copyWith(qty: q + step)) : null,
            ),
          ]),
        ),
      ],
    ]);
  }
}

/// Stepper increment: whole bags when the minimum is a bag size (5 kg), else 1.
int bulkStep(BucketView v) {
  final min = v.x.minQty ?? 1;
  return min >= 5 ? min : 1;
}

/// Default quantity for a fresh bulk/service join.
int bulkDefaultQty(BucketView v) {
  final x = v.x;
  final step = bulkStep(v);
  final min = x.minQty ?? 1;
  final want = step > 1 ? step * 2 : min;
  final max = x.maxQty ?? want;
  return math.max(min, math.min(want, max));
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

class _GhostedBar extends StatelessWidget {
  const _GhostedBar({required this.filled, required this.withMine, required this.markers});

  final double filled;
  final double withMine;
  final List<TierMarker> markers;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Padding(
        padding: const EdgeInsets.only(top: 3),
        child: AppProgressBar(value: withMine, height: 10, color: AppColors.brand.withValues(alpha: 0.35)),
      ),
      AppProgressBar(value: filled, height: 10, markers: markers, track: Colors.transparent),
    ]);
  }
}

class _TierLadder extends StatelessWidget {
  const _TierLadder({required this.tiers, required this.reachedAt, required this.unit, this.retail});

  final List<Tier> tiers;
  final num reachedAt;
  final String unit;
  final int? retail;

  @override
  Widget build(BuildContext context) {
    Tier? current;
    for (final t in tiers) {
      if (reachedAt >= t.minQty) current = t;
    }
    return Row(children: [
      if (retail != null)
        Expanded(child: _rung('Shop price', Fmt.rupees(retail!), state: 0)),
      for (final t in tiers) ...[
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: _rung(
            'from ${t.minQty} $unit',
            Fmt.rupees(t.unitPrice),
            state: t == current ? 2 : reachedAt >= t.minQty ? 1 : 3,
          ),
        ),
      ],
    ]);
  }

  /// state: 0 shop, 1 passed, 2 current, 3 locked
  Widget _rung(String caption, String price, {required int state}) {
    final cur = state == 2;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cur ? AppColors.saveTint : AppColors.canvas,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cur ? AppColors.save : AppColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(
            price,
            style: AppText.heading.copyWith(
              color: state == 0 ? AppColors.inkMuted : cur ? const Color(0xFF0B7A3B) : AppColors.ink,
              decoration: state == 0 ? TextDecoration.lineThrough : null,
              decorationColor: AppColors.inkMuted,
            ).tab,
          ),
          const Spacer(),
          if (cur) const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.save),
          if (state == 3) const Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.inkMuted),
        ]),
        Text(caption, style: AppText.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Service

class ServiceModule extends StatelessWidget {
  const ServiceModule({super.key, required this.view, required this.draft, required this.onChanged, required this.interactive, this.myUnit});

  final BucketView view;
  final JoinDraft draft;
  final ValueChanged<JoinDraft> onChanged;
  final bool interactive;
  final String? myUnit;

  @override
  Widget build(BuildContext context) {
    final b = view.bucket;
    final pr = Pricing(view);
    final unit = b.unitLabel ?? 'flat';
    final mine = interactive ? (draft.qty ?? 0) : 0;
    final after = b.progress.filled + mine;
    final next = pr.nextTierAfter(after);
    final max = view.x.maxQty;
    final min = view.x.minQty ?? 1;
    final q = draft.qty ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      DetailSectionTitle('Price per $unit', subtitle: 'Drops for everyone as more ${pluralWord(unit)} join'),
      DetailCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            LiveText('${Fmt.rupees(pr.unitPriceAt(after))}/$unit now', style: AppText.heading),
            const Spacer(),
            LiveText('${plural(b.progress.filled, unit)} in', style: AppText.label.copyWith(color: AppColors.inkMuted)),
          ]),
          const SizedBox(height: AppSpace.md),
          SizedBox(
            height: 150,
            child: Semantics(
              label: 'Price steps: ${pr.tiers.map((t) => '${Fmt.rupees(t.unitPrice)} from ${t.minQty} ${unit}s').join(', ')}. '
                  'Now ${fmtQty(after)} ${unit}s at ${Fmt.rupees(pr.unitPriceAt(after))}.',
              excludeSemantics: true,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: after.toDouble()),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => CustomPaint(
                  size: Size.infinite,
                  painter: PriceStepPainter(tiers: pr.tiers, current: v, unit: unit, withYou: mine > 0),
                ),
              ),
            ),
          ),
          if (next != null) ...[
            const SizedBox(height: AppSpace.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 10),
              decoration: BoxDecoration(color: AppColors.saveTint, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.trending_down_rounded, size: 18, color: AppColors.save),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: LiveText(
                    'Drops to ${Fmt.rupees(next.unitPrice)} if ${fmtQty(next.minQty - after)} more ${pluralWord(unit)} join',
                    style: AppText.label.copyWith(color: const Color(0xFF0B7A3B)),
                  ),
                ),
              ]),
            ),
          ],
        ]),
      ),
      if (interactive) ...[
        const SizedBox(height: AppSpace.md),
        DetailCard(
          padding: EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, max == 1 ? AppSpace.lg : AppSpace.sm, AppSpace.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.home_outlined, color: AppColors.brandDeep, size: 22),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(max == 1 ? 'Your $unit${myUnit == null ? '' : ', $myUnit'}' : 'How many ${unit}s', style: AppText.heading),
                  Text(max == 1 ? 'One booking per $unit' : 'min $min${max == null ? '' : ' · max $max'}', style: AppText.caption),
                ]),
              ),
              if (max != 1)
                QtyStepper(
                  label: plural(q, unit),
                  onMinus: q - 1 >= min ? () => onChanged(draft.copyWith(qty: q - 1)) : null,
                  onPlus: max == null || q + 1 <= max ? () => onChanged(draft.copyWith(qty: q + 1)) : null,
                ),
            ]),
            if (view.x.optionGroups.isNotEmpty) ...[
              const Divider(height: AppSpace.xxl),
              OptionGroupsBlock(groups: view.x.optionGroups, draft: draft, onChanged: onChanged, enabled: interactive),
            ],
          ]),
        ),
      ],
    ]);
  }
}

/// Step chart of price per unit vs number of members, with the current point.
class PriceStepPainter extends CustomPainter {
  PriceStepPainter({required this.tiers, required this.current, required this.unit, this.withYou = false});

  final List<Tier> tiers;
  final double current;
  final String unit;

  /// The current point includes the member's own pick.
  final bool withYou;

  TextPainter _tp(String s, TextStyle st) => TextPainter(text: TextSpan(text: s, style: st), textDirection: TextDirection.ltr)..layout();

  @override
  void paint(Canvas canvas, Size size) {
    if (tiers.isEmpty) return;
    const left = 4.0, right = 8.0, top = 18.0, bottom = 22.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    final maxX = tiers.last.minQty * 1.25;
    final hi = tiers.first.unitPrice.toDouble();
    final lo = tiers.last.unitPrice.toDouble();
    double xOf(num q) => left + (q / maxX).clamp(0.0, 1.0) * w;
    double yOf(num p) => hi == lo ? top + h / 2 : top + (hi - p) / (hi - lo) * h;

    // baseline grid
    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    canvas.drawLine(Offset(left, top + h + 6), Offset(left + w, top + h + 6), grid);

    // full step path
    final pts = <Offset>[Offset(xOf(0), yOf(tiers.first.unitPrice))];
    for (var i = 0; i < tiers.length; i++) {
      final t = tiers[i];
      final endX = i + 1 < tiers.length ? tiers[i + 1].minQty : maxX;
      pts.add(Offset(xOf(t.minQty), yOf(t.unitPrice)));
      pts.add(Offset(xOf(endX), yOf(t.unitPrice)));
      if (i + 1 < tiers.length) pts.add(Offset(xOf(endX), yOf(tiers[i + 1].unitPrice)));
    }
    // insert the vertical drop before each tier start (path is H then V)
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }

    // future part: dashed muted
    _dashed(canvas, path, Paint()
      ..color = AppColors.inkMuted.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke);

    // reached part: solid brand, clipped at the current x
    final cx = xOf(current);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, cx, size.height));
    // area under the reached curve
    final area = Path.from(path)
      ..lineTo(xOf(maxX), top + h + 6)
      ..lineTo(left, top + h + 6)
      ..close();
    canvas.drawPath(area, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.brand.withValues(alpha: 0.10), AppColors.brand.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, top, size.width, h)));
    canvas.drawPath(path, Paint()
      ..color = AppColors.brand
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke);
    canvas.restore();

    // tier labels
    Tier? cur;
    for (final t in tiers) {
      if (current >= t.minQty) cur = t;
    }
    for (var i = 0; i < tiers.length; i++) {
      final t = tiers[i];
      final reached = current >= t.minQty;
      final isCur = t == cur;
      final price = _tp(
        Fmt.rupees(t.unitPrice),
        AppText.tiny.copyWith(
          color: isCur ? AppColors.brandDeep : reached ? AppColors.ink : AppColors.inkMuted,
          fontWeight: isCur ? FontWeight.w800 : FontWeight.w600,
          fontSize: isCur ? 12 : 11,
          fontFeatures: tabular,
        ),
      );
      final px = (xOf(t.minQty) + 4).clamp(0.0, size.width - price.width);
      price.paint(canvas, Offset(px, yOf(t.unitPrice) - price.height - 3));
      final xl = _tp(i == 0 ? '${t.minQty} ${unit}s' : '${t.minQty}', AppText.tiny.copyWith(fontFeatures: tabular));
      final lx = (xOf(t.minQty) - xl.width / 2).clamp(0.0, size.width - xl.width);
      xl.paint(canvas, Offset(lx, top + h + 9));
      // tick
      canvas.drawLine(Offset(xOf(t.minQty), top + h + 3), Offset(xOf(t.minQty), top + h + 9), grid..color = AppColors.inkMuted.withValues(alpha: 0.4));
    }

    // current point
    final curPrice = cur?.unitPrice ?? tiers.first.unitPrice;
    final cp = Offset(cx, yOf(curPrice));
    canvas.drawCircle(cp, 10, Paint()..color = AppColors.brand.withValues(alpha: 0.18));
    canvas.drawCircle(cp, 6, Paint()..color = AppColors.brand);
    canvas.drawCircle(cp, 2.5, Paint()..color = Colors.white);
    final now = _tp(withYou ? 'You · #${current.round()}' : '${current.round()} now', AppText.tiny.copyWith(color: AppColors.brandDeep, fontWeight: FontWeight.w800, fontFeatures: tabular));
    final nx = (cx - now.width / 2).clamp(0.0, size.width - now.width);
    final ny = cp.dy + 12;
    final pill = RRect.fromRectAndRadius(Rect.fromLTWH(nx - 6, ny, now.width + 12, now.height + 4), const Radius.circular(999));
    canvas.drawRRect(pill, Paint()..color = AppColors.brandTint);
    now.paint(canvas, Offset(nx, ny + 2));
  }

  void _dashed(Canvas canvas, Path path, Paint paint) {
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 6, m.length)), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(PriceStepPainter old) => old.current != current || old.tiers != tiers || old.withYou != withYou;
}

// ---------------------------------------------------------------------------
// Trip

class TripModule extends StatelessWidget {
  const TripModule({super.key, required this.view, required this.draft, required this.onChanged, required this.interactive});

  final BucketView view;
  final JoinDraft draft;
  final ValueChanged<JoinDraft> onChanged;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final b = view.bucket;
    final pr = Pricing(view);
    final cap = b.capacity ?? b.progress.target.toInt();
    final myItems = interactive ? draft.items : <String, num>{for (final i in b.myShare?.items ?? const <ShareItem>[]) i.id: i.qty};
    final myKg = interactive ? pr.kgOf(draft.items) : 0.0;
    final booked = b.progress.filled;
    final left = math.max(0, cap - booked - myKg);
    final minLoad = view.x.minLoadKg;
    final transport = pr.transportFor(myKg);

    void setQty(TripItem it, num q) {
      final m = {...draft.items};
      if (q <= 0) {
        m.remove(it.id);
      } else {
        m[it.id] = q;
      }
      onChanged(draft.copyWith(items: m));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      DetailSectionTitle('Space in the tempo', subtitle: minLoad == null ? null : 'The trip goes once ${fmtQty(minLoad)} kg is booked'),
      DetailCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            LiveText('${fmtQty(booked + myKg)} kg booked', style: AppText.heading),
            const Spacer(),
            LiveText('${fmtQty(left)} kg space left', style: AppText.label.copyWith(color: AppColors.inkMuted)),
          ]),
          const SizedBox(height: AppSpace.md),
          _GhostedBar(
            filled: cap == 0 ? 0 : booked / cap,
            withMine: cap == 0 ? 0 : (booked + myKg) / cap,
            markers: [
              if (minLoad != null) TierMarker(at: minLoad / cap, label: '${fmtQty(minLoad)} kg', reached: booked + myKg >= minLoad),
              TierMarker(at: 1, label: '$cap kg', reached: booked + myKg >= cap),
            ],
          ),
        ]),
      ),
      const SizedBox(height: AppSpace.xxl),
      DetailSectionTitle(
        interactive ? 'Add from the list' : 'The shared list',
        subtitle: 'Wholesale prices at ${b.vendor?.place ?? 'the market'}',
      ),
      DetailCard(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.xs),
        child: Column(children: [
          for (final it in b.items) ...[
            if (it != b.items.first) const Divider(),
            _TripRow(
              item: it,
              retail: view.x.itemRetail[it.id],
              mine: myItems[it.id] ?? 0,
              interactive: interactive,
              onChanged: (q) => setQty(it, q),
              maxQty: view.x.itemMax[it.id],
            ),
          ],
        ]),
      ),
      if (interactive) ...[
        const SizedBox(height: AppSpace.md),
        DetailCard(
          color: AppColors.canvas,
          child: Column(children: [
            _kv('Your list', myKg == 0 ? 'Nothing yet' : '${fmtQty(myKg)} kg · ${Fmt.rupees(pr.goodsOf(draft.items))}'),
            const SizedBox(height: AppSpace.sm),
            _kv(
              'Your transport share',
              myKg == 0 ? '${Fmt.rupees((view.x.transportPerKg ?? 0).round())}/kg now' : Fmt.rupees(transport),
              strong: true,
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              'Tempo ${Fmt.rupees(view.x.transportFee ?? 0)}, split by weight. Your share drops as neighbours load more.',
              style: AppText.caption,
            ),
          ]),
        ),
      ],
    ]);
  }

  Widget _kv(String k, String v, {bool strong = false}) => Row(children: [
        Expanded(child: Text(k, style: AppText.label.copyWith(color: AppColors.inkMuted))),
        LiveText(v, style: strong ? AppText.heading : AppText.label),
      ]);
}

class _TripRow extends StatelessWidget {
  const _TripRow({required this.item, required this.mine, required this.interactive, required this.onChanged, this.retail, this.maxQty});

  final TripItem item;
  final num mine;
  final bool interactive;
  final ValueChanged<num> onChanged;
  final int? retail;
  final num? maxQty;

  @override
  Widget build(BuildContext context) {
    final perUnit = item.unit == 'pc' ? 'each' : '/${item.unit}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: AppText.label.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '${Fmt.rupees(item.price)}${item.unit == 'pc' ? ' ' : ''}$perUnit', style: AppText.caption.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700)),
                if (retail != null && retail! > item.price)
                  TextSpan(text: '  ${Fmt.rupees(retail!)}', style: AppText.caption.copyWith(decoration: TextDecoration.lineThrough, decorationColor: AppColors.inkMuted)),
                TextSpan(text: '  ·  ${item.members} ${item.members == 1 ? 'neighbour' : 'neighbours'}', style: AppText.caption),
              ]),
              style: const TextStyle(fontFeatures: tabular),
            ),
          ]),
        ),
        if (interactive)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: mine <= 0
                ? Semantics(
                    key: const ValueKey('add'),
                    button: true,
                    label: 'Add ${item.name}',
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () => onChanged(1),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 40,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.brand),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('Add', style: AppText.label.copyWith(color: AppColors.brand, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 4),
                          const Icon(Icons.add_rounded, size: 18, color: AppColors.brand),
                        ]),
                      ),
                    ),
                  )
                : QtyStepper(
                    key: const ValueKey('stepper'),
                    compact: true,
                    label: plural(mine, item.unit),
                    semanticsLabel: '${item.name}: ${plural(mine, item.unit)}',
                    onMinus: () => onChanged(mine - 1),
                    onPlus: maxQty != null && mine + 1 > maxQty! ? null : () => onChanged(mine + 1),
                  ),
          )
        else if (mine > 0)
          StatusPill('You · ${plural(mine, item.unit)}', tone: PillTone.brand)
        else
          Text('${fmtQty(item.qty)} ${item.unit}', style: AppText.caption.tab),
      ]),
    );
  }
}
