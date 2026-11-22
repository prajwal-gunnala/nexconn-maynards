import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../bucket/card_parts.dart';
import '../bucket/list_logic.dart';

enum FeedKind { joined, started, priceDrop, live }

/// One row of "Happening on your street".
class FeedItem {
  const FeedItem({required this.kind, required this.action, this.actor, this.unit, this.bucket, this.detail, this.at});

  final FeedKind kind;

  /// Who did it (null for system rows such as price drops).
  final String? actor;
  final String? unit;

  /// What happened, after the actor: `took Steak 3`.
  final String action;
  final Bucket? bucket;

  /// Second line, e.g. `Whole Seer · 6 of 8 cuts`.
  final String? detail;
  final DateTime? at;
}

/// Builds feed rows from bucket data: the latest neighbour in a few buckets, a
/// price that dropped because enough people joined, and a newly started bucket.
/// [raw] is the bucket JSON by id (for `qtyLabel` and `createdAt`, which the
/// typed models don't carry).
List<FeedItem> feedFromBuckets(List<Bucket> live, Map<String, Json> raw, {int max = 6}) {
  final byCutoff = sortBuckets(live, BucketSort.closingSoon);
  final out = <FeedItem>[];
  final used = <String>{};

  // Latest neighbour in up to four buckets.
  for (final b in byCutoff) {
    if (out.length >= 4) break;
    if (b.shares.isEmpty) continue;
    final s = b.shares.last;
    final rawShare = asList(raw[b.id]?['shares'], (j) => j).where((j) => j['id'] == s.id).firstOrNull;
    var label = asStringOrNull(rawShare?['qtyLabel']) ?? '${qtyText(s.qty)} ${plural(b.type == BucketType.trip ? 'kg' : b.unit, s.qty)}';
    if (b.type == BucketType.trip) label = label.split(' · ').first;
    final action = switch (b.type) {
      BucketType.split => 'took $label',
      BucketType.service => 'booked ${label == '1 ${b.unit}' ? 'their ${b.unit}' : label}',
      BucketType.trip => 'added $label',
      _ => 'joined with $label',
    };
    out.add(
      FeedItem(
        kind: FeedKind.joined,
        actor: s.user.name,
        unit: s.user.unit,
        action: action,
        bucket: b,
        detail: shortTitle(b.title),
        at: asTime(rawShare?['createdAt']),
      ),
    );
    used.add(b.id);
  }

  // A price that dropped because the group grew.
  for (final b in byCutoff) {
    final price = b.progress.unitPrice;
    if (b.tiers.length < 2 || price == null || price >= b.tiers.first.unitPrice) continue;
    final n = b.progress.nextTier;
    out.insert(
      out.length >= 2 ? 2 : out.length,
      FeedItem(
        kind: FeedKind.priceDrop,
        action: '${shortTitle(b.title)} dropped to ${Fmt.rupees(price)}/${b.unit}',
        bucket: b,
        detail: n == null
            ? '${b.progressCaption} · best price reached'
            : '${qtyText(b.progress.filled)} ${plural(b.unit, b.progress.filled)} in · ${Fmt.rupees(n.unitPrice)} at ${n.minQty}',
      ),
    );
    break;
  }

  // The newest bucket someone started.
  final started = [
    for (final b in live)
      if (b.createdBy != null && asTime(raw[b.id]?['createdAt']) != null) (b, asTime(raw[b.id]?['createdAt'])!),
  ]..sort((a, b) => b.$2.compareTo(a.$2));
  final fresh = started.where((e) => !used.contains(e.$1.id)).firstOrNull ?? started.firstOrNull;
  if (fresh != null) {
    final b = fresh.$1;
    out.add(
      FeedItem(
        kind: FeedKind.started,
        actor: b.createdBy!.name,
        unit: b.createdBy!.unit,
        action: 'started a bucket',
        bucket: b,
        detail: shortTitle(b.title),
        at: fresh.$2,
      ),
    );
  }
  return out.take(max).toList();
}

/// A live `js:event` from the Street chat (`joined`, `left`, `locked`, ...).
FeedItem? feedFromEvent(Map<String, String> fields, DateTime? at, List<Bucket> buckets) {
  final text = fields['text'];
  if (text == null || text.isEmpty) return null;
  final b = buckets.where((x) => x.id == fields['bucketId']).firstOrNull;
  return FeedItem(
    kind: FeedKind.live,
    actor: (fields['actor'] ?? '').isEmpty ? null : fields['actor'],
    action: text,
    bucket: b,
    detail: b == null ? null : shortTitle(b.title),
    at: at,
  );
}

/// The feed card: a timeline, one rail joining every row's avatar.
class ActivityFeed extends StatelessWidget {
  const ActivityFeed({super.key, required this.items});

  final List<FeedItem> items;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(AppRadius.feature);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: r, boxShadow: AppShadows.card),
      child: Material(
        color: AppColors.surface,
        borderRadius: r,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
          child: Column(
            children: [for (var i = 0; i < items.length; i++) _FeedRow(item: items[i], first: i == 0, last: i == items.length - 1)],
          ),
        ),
      ),
    );
  }
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.item, this.first = false, this.last = false});

  final FeedItem item;
  final bool first;
  final bool last;

  /// Centre of the avatar column (row padding + half the 36 px avatar).
  static const double _rail = AppSpace.lg + 18;

  @override
  Widget build(BuildContext context) {
    final it = item;
    final when = it.at == null ? null : Fmt.ago(it.at!, now: StreetClock.now());
    final detail = [?it.detail, ?when].join(' · ');
    final b = it.bucket;
    final Widget lead = switch (it.kind) {
      FeedKind.priceDrop => const _IconDot(icon: Icons.trending_down_rounded, fg: AppColors.save, bg: AppColors.saveTint),
      _ when it.actor == null => const _IconDot(icon: Icons.bolt_rounded, fg: AppColors.brand, bg: AppColors.brandTint),
      _ => Stack(
        clipBehavior: Clip.none,
        children: [
          AvatarStack(
            users: [User(id: it.actor!, name: it.actor!)],
            size: 36,
            max: 1,
          ),
          if (it.kind == FeedKind.started || it.kind == FeedKind.live)
            Positioned(
              right: -3,
              bottom: -3,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: it.kind == FeedKind.live ? AppColors.save : AppColors.brand,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: Icon(it.kind == FeedKind.live ? Icons.bolt_rounded : Icons.add_rounded, size: 9, color: Colors.white),
              ),
            ),
        ],
      ),
    };
    final who = it.actor == null || it.kind == FeedKind.live ? null : (it.unit == null ? it.actor! : '${it.actor} · ${it.unit}');
    return Semantics(
      button: b != null,
      child: InkWell(
        onTap: b == null ? null : () => openBucket(context, b.id),
        child: Stack(
          children: [
            if (!(first && last))
              Positioned(
                left: _rail - 1,
                width: 2,
                top: first ? AppSpace.md + 18 : 0,
                bottom: last ? null : 0,
                height: last ? AppSpace.md + 18 : null,
                child: const ColoredBox(color: AppColors.line),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface,
                        boxShadow: [BoxShadow(color: AppColors.surface, spreadRadius: 3)],
                      ),
                      child: lead,
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              if (who != null)
                                TextSpan(
                                  text: '$who ',
                                  style: AppText.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700),
                                ),
                              TextSpan(
                                text: it.action,
                                style: AppText.body.copyWith(
                                  fontSize: 13.5,
                                  height: 1.3,
                                  fontWeight: it.kind == FeedKind.priceDrop ? FontWeight.w700 : FontWeight.w500,
                                  color: it.kind == FeedKind.priceDrop ? AppColors.save : AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (detail.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(detail, style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                  if (b != null) ...[
                    const SizedBox(width: AppSpace.md),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.photo),
                      child: SizedBox(width: 48, height: 48, child: CardPhoto(bucket: b)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconDot extends StatelessWidget {
  const _IconDot({required this.icon, required this.fg, required this.bg});

  final IconData icon;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
    child: Icon(icon, color: fg, size: 20),
  );
}
