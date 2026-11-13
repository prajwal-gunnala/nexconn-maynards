import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/images.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import 'bucket_visuals.dart';
import 'list_logic.dart';

/// Bucket photo that fills its box, falling back to a tinted icon tile when
/// the asset is missing. [greyed] desaturates it (past buckets).
class CardPhoto extends StatelessWidget {
  const CardPhoto({super.key, required this.bucket, this.greyed = false});

  final Bucket bucket;
  final bool greyed;

  @override
  Widget build(BuildContext context) {
    final b = bucket;
    final visual = BucketVisual.of(b.image ?? b.category ?? b.title);
    final fallback = ColoredBox(
      color: visual.tint,
      child: LayoutBuilder(
        builder: (_, c) => Center(
          child: Icon(visual.icon, size: (c.maxHeight.isFinite ? c.maxHeight : 120) * 0.4, color: AppColors.ink.withValues(alpha: 0.45)),
        ),
      ),
    );
    final path = AppImages.bucket(b.image);
    Widget img = path == null
        ? fallback
        : Image.asset(path, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, _, _) => fallback);
    if (greyed) {
      img = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.33, 0.59, 0.11, 0, 0, //
          0.33, 0.59, 0.11, 0, 0,
          0.33, 0.59, 0.11, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: img,
      );
    }
    return img;
  }
}

/// Flush top-left ribbon on the photo: `Split`, `Bulk`, `Service`, `Market trip`,
/// or `Book & meet` for pay-at-market buckets.
class TypeRibbon extends StatelessWidget {
  const TypeRibbon({super.key, required this.bucket, this.small = false});

  final Bucket bucket;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final atMarket = bucket.settleMode == PayMode.atMarket;
    final label = atMarket ? 'Book & meet' : bucket.typeLabel;
    final live = bucket.isLive;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 3 : 5),
      decoration: BoxDecoration(
        color: !live ? AppColors.released : (atMarket ? AppColors.held : AppColors.brand),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(label, style: AppText.tiny.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: small ? 10.5 : 11)),
    );
  }
}

/// Ticking "1h 55m left" text. Rebuilds every 30 s.
class Countdown extends StatefulWidget {
  const Countdown({super.key, required this.cutoff, this.style, this.prefix = ''});

  final DateTime cutoff;
  final TextStyle? style;
  final String prefix;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text('${widget.prefix}${Fmt.timeLeft(widget.cutoff, now: StreetClock.now())}', style: widget.style, maxLines: 1);
}

/// White pill on the photo: clock + countdown. Turns brand-red in the last 3 hours.
class CountdownChip extends StatelessWidget {
  const CountdownChip({super.key, required this.cutoff, this.small = false});

  final DateTime cutoff;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final left = cutoff.difference(StreetClock.now());
    final urgent = left.inHours < 3;
    final fg = urgent ? AppColors.brandDeep : AppColors.held;
    return Container(
      padding: EdgeInsets.fromLTRB(6, small ? 3 : 4, 8, small ? 3 : 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 1))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(urgent ? Icons.timer_outlined : Icons.schedule_rounded, size: small ? 12 : 14, color: fg),
        const SizedBox(width: 4),
        Countdown(cutoff: cutoff, style: AppText.tiny.copyWith(color: fg, fontWeight: FontWeight.w700, fontSize: small ? 10.5 : 11)),
      ]),
    );
  }
}

/// `5.2 kg | 8 cuts | Serves 8 families` — first fact in ink, the rest muted.
class FactsLine extends StatelessWidget {
  const FactsLine({super.key, required this.facts, this.small = false});

  final List<String> facts;
  final bool small;

  @override
  Widget build(BuildContext context) {
    if (facts.isEmpty) return const SizedBox.shrink();
    final first = AppText.label.copyWith(fontSize: small ? 12 : 13, color: AppColors.ink);
    final rest = AppText.caption.copyWith(fontSize: small ? 11.5 : 12.5);
    final bar = TextSpan(text: '  |  ', style: rest.copyWith(color: const Color(0xFFCFC7C1), fontWeight: FontWeight.w400));
    TextSpan span(int n) => TextSpan(children: [
          for (var i = 0; i < n; i++) ...[
            if (i > 0) bar,
            TextSpan(text: facts[i], style: i == 0 ? first : rest),
          ],
        ]);
    // Show only the facts that fit whole; never cut one in half.
    return LayoutBuilder(builder: (context, c) {
      var n = facts.length;
      final scaler = MediaQuery.textScalerOf(context);
      while (n > 1) {
        final tp = TextPainter(text: span(n), textDirection: TextDirection.ltr, maxLines: 1, textScaler: scaler)..layout();
        final fits = tp.width <= c.maxWidth;
        tp.dispose();
        if (fits) break;
        n--;
      }
      return Text.rich(span(n), maxLines: 1, overflow: TextOverflow.ellipsis);
    });
  }
}

/// `₹96 /kg  ₹135  29% off` (Licious price row, discount as green text).
class CardPrice extends StatelessWidget {
  const CardPrice({super.key, required this.bucket, this.small = false});

  final Bucket bucket;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final b = bucket;
    final price = b.displayPrice;
    if (price == null) return const SizedBox.shrink();
    final retail = b.displayRetail;
    final pct = b.savePercent;
    return Text.rich(
      TextSpan(children: [
        if (b.type == BucketType.trip) TextSpan(text: 'From ', style: AppText.caption.copyWith(fontSize: small ? 11.5 : 12.5)),
        TextSpan(text: Fmt.rupees(price), style: AppText.price.copyWith(fontSize: small ? 16 : 18)),
        TextSpan(text: ' /${b.priceUnit}', style: AppText.caption.copyWith(fontSize: small ? 11.5 : 12.5)),
        if (retail != null && pct != null) ...[
          const TextSpan(text: '  '),
          TextSpan(
            text: Fmt.rupees(retail),
            style: AppText.caption.copyWith(
              fontSize: small ? 11.5 : 13,
              decoration: TextDecoration.lineThrough,
              decorationColor: AppColors.inkMuted,
            ),
          ),
          const TextSpan(text: '  '),
          TextSpan(text: '$pct% off', style: AppText.label.copyWith(color: AppColors.save, fontSize: small ? 12 : 13.5, fontWeight: FontWeight.w700)),
        ],
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

Color avatarColor(String seed) {
  const palette = [Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFF0EA5A4), Color(0xFFF59E0B), Color(0xFFEC4899), Color(0xFF10B981), Color(0xFF6366F1)];
  return palette[seed.codeUnits.fold<int>(0, (a, c) => a + c) % palette.length];
}

/// Overlapping initials, like a chat group's faces.
class AvatarStack extends StatelessWidget {
  const AvatarStack({super.key, required this.users, this.size = 24, this.max = 4});

  final List<User> users;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final shown = users.where((u) => seen.add(u.id)).take(max).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    final step = size * 0.68;
    return SizedBox(
      width: step * (shown.length - 1) + size,
      height: size,
      child: Stack(children: [
        for (var i = 0; i < shown.length; i++)
          Positioned(
            left: step * i,
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: avatarColor(shown[i].name),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
              child: Text(shown[i].initial, style: AppText.tiny.copyWith(color: Colors.white, fontSize: size * 0.42, fontWeight: FontWeight.w800)),
            ),
          ),
      ]),
    );
  }
}

/// Licious "Add +" pill → "Join +". Shows "Joined" once the viewer has a share.
class JoinPill extends StatelessWidget {
  const JoinPill({super.key, required this.onPressed, this.joined = false});

  final VoidCallback onPressed;
  final bool joined;

  @override
  Widget build(BuildContext context) {
    final fg = joined ? AppColors.save : Colors.white;
    return Semantics(
      button: true,
      label: joined ? 'Joined, view your share' : 'Join this bucket',
      child: SizedBox(
        height: 40,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            backgroundColor: joined ? AppColors.saveTint : AppColors.brand,
            foregroundColor: fg,
            minimumSize: const Size(96, 40),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            tapTargetSize: MaterialTapTargetSize.padded,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(joined ? 'Joined' : 'Join', style: AppText.heading.copyWith(color: fg, fontSize: 15)),
            const SizedBox(width: 10),
            Icon(joined ? Icons.check_rounded : Icons.add_rounded, size: 18, color: fg),
          ]),
        ),
      ),
    );
  }
}

/// Status pill for closed buckets.
class BucketStatusPill extends StatelessWidget {
  const BucketStatusPill({super.key, required this.bucket});

  final Bucket bucket;

  @override
  Widget build(BuildContext context) {
    final tone = switch (bucket.status) {
      BucketStatus.completed => PillTone.captured,
      BucketStatus.ordered || BucketStatus.marketDay || BucketStatus.delivering => PillTone.brand,
      BucketStatus.expired || BucketStatus.cancelled => PillTone.released,
      _ => PillTone.neutral,
    };
    final icon = switch (bucket.status) {
      BucketStatus.completed => Icons.check_circle_outline,
      BucketStatus.expired || BucketStatus.cancelled => Icons.undo_rounded,
      BucketStatus.delivering => Icons.local_shipping_outlined,
      _ => null,
    };
    return StatusPill(bucket.statusLabel, tone: tone, icon: icon);
  }
}

/// Rounded progress bar, brand on tint (6 dp).
class CardProgress extends StatelessWidget {
  const CardProgress({super.key, required this.bucket, this.height = 6});

  final Bucket bucket;
  final double height;

  @override
  Widget build(BuildContext context) => AppProgressBar(
        value: bucket.progress.fraction,
        height: height,
        color: bucket.isLive ? AppColors.brand : AppColors.save,
        track: AppColors.brandTint,
      );
}

/// Opens a bucket, dropping keyboard focus first so a search field doesn't grab
/// it again (and reopen the keyboard over the tabs) when the user comes back.
void openBucket(BuildContext context, String id) {
  FocusManager.instance.primaryFocus?.unfocus();
  context.push('/bucket/$id');
}

/// Tinted box that pulses gently while content loads.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = 8, this.circle = false});

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: widget.circle ? null : BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(-1.6 + 3.2 * _c.value, 0),
            end: Alignment(-0.6 + 3.2 * _c.value, 0),
            colors: const [Color(0xFFF1ECE8), Color(0xFFFAF6F3), Color(0xFFF1ECE8)],
          ),
        ),
      ),
    );
  }
}
