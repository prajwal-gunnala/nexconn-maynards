import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import 'card_parts.dart';
import 'list_logic.dart';

/// Licious-style product card for a bucket.
///
/// Full (lists): photo flush on top with type ribbon + countdown, title,
/// subtitle, `Net wt | Pieces | Serves` facts, price + strike + % off, fill
/// progress, neighbours and a "Join +" pill.
/// Compact (horizontal rails): 216 dp wide, "+" square overlapping the photo.
///
/// The photo carries the Hero tag `bucket-photo-<id>` for the detail page;
/// pass `hero: false` when the same bucket appears twice on one screen.
class BucketCard extends StatelessWidget {
  const BucketCard({super.key, required this.bucket, this.hero = true, this.onTap, this.meId})
      : compact = false;

  const BucketCard.compact({super.key, required this.bucket, this.hero = false, this.onTap, this.meId})
      : compact = true;

  final Bucket bucket;
  final bool compact;
  final bool hero;
  final VoidCallback? onTap;

  /// The viewer, so their own share reads as "You".
  final String? meId;

  static const compactWidth = 216.0;
  static const compactHeight = 262.0;

  void _open(BuildContext context) => onTap != null ? onTap!() : context.push('/bucket/${bucket.id}');

  Widget _photo(double height) {
    final b = bucket;
    final photo = SizedBox(height: height, width: double.infinity, child: CardPhoto(bucket: b, greyed: !b.isLive));
    return hero ? Hero(tag: 'bucket-photo-${b.id}', child: photo) : photo;
  }

  @override
  Widget build(BuildContext context) {
    final b = bucket;
    final semantics = '${b.typeLabel} bucket, ${b.title}. ${b.progressCaption}.';
    return Semantics(
      container: true,
      label: semantics,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder, side: const BorderSide(color: AppColors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context),
          child: compact ? _compact(context) : _full(context),
        ),
      ),
    );
  }

  Widget _full(BuildContext context) {
    final b = bucket;
    final next = b.nextTierCaption;
    final people = b.people;
    final members = b.progress.members;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Stack(children: [
        _photo(196),
        Positioned(left: 10, top: 10, child: TypeRibbon(bucket: b)),
        if (b.isLive && b.cutoffAt != null) Positioned(left: 10, bottom: 10, child: CountdownChip(cutoff: b.cutoffAt!)),
        if (b.myShare != null)
          const Positioned(right: 10, top: 10, child: _OnPhotoTag(label: 'You\'re in', icon: Icons.check_circle_rounded)),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(b.title, style: AppText.heading, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (b.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(b.subtitle!, style: AppText.caption.copyWith(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: AppSpace.sm),
          FactsLine(facts: b.facts),
          const SizedBox(height: AppSpace.md),
          Row(children: [
            if (people.isNotEmpty) ...[AvatarStack(users: people, size: 28), const SizedBox(width: AppSpace.sm)],
            Expanded(
              child: Text(
                members == 0 ? 'Be the first to join' : b.peopleLine(meId: meId, withFlats: false),
                style: AppText.caption.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600, fontSize: 12.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
          const SizedBox(height: AppSpace.sm),
          CardProgress(bucket: b),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: b.progressCaption, style: AppText.caption.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600)),
                  if (b.isLive && b.cutoffAt != null) ...[
                    TextSpan(text: '  ·  ', style: AppText.caption),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: Countdown(cutoff: b.cutoffAt!, style: AppText.caption),
                    ),
                  ],
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (next != null)
              Text(next, style: AppText.caption.copyWith(color: AppColors.save, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: AppSpace.md),
          const Divider(),
          const SizedBox(height: AppSpace.md),
          Row(children: [
            Expanded(child: CardPrice(bucket: b)),
            const SizedBox(width: AppSpace.sm),
            if (b.isLive)
              JoinPill(onPressed: () => _open(context), joined: b.myShare != null)
            else
              BucketStatusPill(bucket: b),
          ]),
        ]),
      ),
    ]);
  }

  Widget _compact(BuildContext context) {
    final b = bucket;
    return SizedBox(
      width: compactWidth,
      height: compactHeight,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(clipBehavior: Clip.none, children: [
          _photo(138),
          Positioned(left: 8, top: 8, child: TypeRibbon(bucket: b, small: true)),
          if (b.isLive && b.cutoffAt != null) Positioned(left: 8, bottom: 8, child: CountdownChip(cutoff: b.cutoffAt!, small: true)),
          if (b.isLive)
            Positioned(
              right: 8,
              bottom: 8,
              child: _PlusSquare(onTap: () => _open(context), joined: b.myShare != null),
            ),
        ]),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.md, 10, AppSpace.md, AppSpace.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.title, style: AppText.heading.copyWith(fontSize: 14.5), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              FactsLine(facts: b.facts.take(2).toList(), small: true),
              const SizedBox(height: 6),
              CardPrice(bucket: b, small: true),
              const Spacer(),
              CardProgress(bucket: b, height: 5),
              const SizedBox(height: 6),
              if (b.isLive)
                Text(b.progressCaption, style: AppText.tiny.copyWith(color: AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis)
              else
                BucketStatusPill(bucket: b),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// White "+" square overlapping the rail card photo (Licious rail pattern).
class _PlusSquare extends StatelessWidget {
  const _PlusSquare({required this.onTap, required this.joined});

  final VoidCallback onTap;
  final bool joined;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: joined ? 'Joined' : 'Join',
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.line)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(joined ? Icons.check_rounded : Icons.add_rounded, color: joined ? AppColors.save : AppColors.brand, size: 22),
          ),
        ),
      ),
    );
  }
}

class _OnPhotoTag extends StatelessWidget {
  const _OnPhotoTag({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
        decoration: BoxDecoration(color: AppColors.save, borderRadius: BorderRadius.circular(AppRadius.chip)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(label, style: AppText.tiny.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
      );
}

/// One-line row for past buckets: thumbnail, title, outcome, status pill.
class PastBucketRow extends StatelessWidget {
  const PastBucketRow({super.key, required this.bucket});

  final Bucket bucket;

  @override
  Widget build(BuildContext context) {
    final b = bucket;
    final done = b.status == BucketStatus.completed;
    final when = b.cutoffAt == null ? null : _shortDay(b.cutoffAt!);
    final line = done
        ? '${b.progress.members} neighbours · ${qtyText(b.progress.filled)} ${plural(b.type == BucketType.trip ? 'kg' : b.unit, b.progress.filled)} bought'
        : 'Didn\'t fill · holds released';
    return Semantics(
      container: true,
      label: '${b.title}, ${b.statusLabel}',
      child: InkWell(
        onTap: () => context.push('/bucket/${b.id}'),
        borderRadius: BorderRadius.circular(AppRadius.photo),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
          child: Row(children: [
            ClipRRect(
              borderRadius: AppRadius.photoBorder,
              child: SizedBox(width: 60, height: 60, child: CardPhoto(bucket: b, greyed: !done)),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.title, style: AppText.label.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text([?when, b.typeLabel].join(' · '), style: AppText.caption, maxLines: 1),
                const SizedBox(height: 2),
                Text(line, style: AppText.caption.copyWith(color: done ? AppColors.save : AppColors.inkMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            const SizedBox(width: AppSpace.sm),
            BucketStatusPill(bucket: b),
          ]),
        ),
      ),
    );
  }

  static String _shortDay(DateTime t) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final l = t.toLocal();
    return '${l.day} ${m[l.month - 1]}';
  }
}
