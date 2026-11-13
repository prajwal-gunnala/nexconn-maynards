import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import '../bucket/card_parts.dart';

/// Section title + subtitle, Licious spacing (32 above, 12 below).
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader(this.title, {super.key, this.subtitle, this.action, this.onAction});

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.xxxl, AppSpace.sm, AppSpace.md),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.heading.copyWith(fontSize: 19, fontWeight: FontWeight.w800)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: AppText.caption.copyWith(fontSize: 13)),
              ],
            ]),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: AppColors.brand, minimumSize: const Size(48, 40), padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(action!, style: AppText.label.copyWith(color: AppColors.brand)),
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.brand),
            ]),
          ),
      ]),
    );
  }
}

/// Softly pulsing "live" dot.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, this.color = const Color(0xFF7CF0A9), this.size = 8});

  final Color color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 2.4,
      height: s * 2.4,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Stack(alignment: Alignment.center, children: [
          Container(
            width: s * (1 + 1.4 * _c.value),
            height: s * (1 + 1.4 * _c.value),
            decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withValues(alpha: 0.45 * (1 - _c.value))),
          ),
          Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)),
        ]),
      ),
    );
  }
}

/// Hero: "Buying together on Sea Breeze Street" with the people, three numbers and the
/// two things you can do (start a bucket, open the Street chat).
class TogetherHero extends StatelessWidget {
  const TogetherHero({
    super.key,
    required this.streetName,
    required this.people,
    required this.members,
    required this.liveBuckets,
    required this.saved,
    required this.month,
    required this.onStart,
    this.onChat,
  });

  final String streetName;

  /// Everyone in a live bucket right now (from the bucket list).
  final List<User> people;

  /// Community snapshot from `GET /api/communities/:id` → `stats`, so these
  /// numbers match the admin screen.
  final int members;
  final int liveBuckets;
  final int saved;

  /// Month name for "saved together in November".
  final String month;
  final VoidCallback onStart;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    final muted = Colors.white.withValues(alpha: 0.82);
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.lg, AppSpace.xl, AppSpace.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sheet),
        gradient: const LinearGradient(
          colors: [Color(0xFFEB6A40), Color(0xFFD9481F), Color(0xFFB93A17)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const PulseDot(),
          const SizedBox(width: 4),
          Text('LIVE NOW', style: AppText.tiny.copyWith(color: muted, letterSpacing: 1.2, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: AppSpace.xs),
        Semantics(
          header: true,
          child: Text('Buying together on\n$streetName', style: AppText.display.copyWith(color: white, fontSize: 25, height: 1.15)),
        ),
        const SizedBox(height: AppSpace.lg),
        if (people.isNotEmpty)
          Row(children: [
            AvatarStack(users: people, size: 40, max: 5),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Text(
                '${people.length} ${people.length == 1 ? 'neighbour' : 'neighbours'} in a bucket now',
                style: AppText.label.copyWith(color: white, height: 1.3),
                maxLines: 2,
              ),
            ),
          ]),
        const SizedBox(height: AppSpace.lg),
        Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.card)),
          child: IntrinsicHeight(
            child: Row(children: [
              _Stat(value: '$liveBuckets', label: 'live buckets'),
              VerticalDivider(color: Colors.white.withValues(alpha: 0.25), width: 1, indent: 4, endIndent: 4),
              _Stat(value: Fmt.number(members), label: 'neighbours on\nJugaad Street'),
              VerticalDivider(color: Colors.white.withValues(alpha: 0.25), width: 1, indent: 4, endIndent: 4),
              _Stat(value: Fmt.rupees(saved), label: 'saved together\nin $month'),
            ]),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Row(children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                  backgroundColor: white,
                  foregroundColor: AppColors.brandDeep,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.photo)),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Start a bucket', maxLines: 1, style: AppText.heading.copyWith(color: AppColors.brandDeep, fontSize: 14.5)),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          // Compact so "Start a bucket" always fits, even at 360 dp.
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onChat,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                foregroundColor: white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.photo)),
              ),
              icon: const Icon(Icons.forum_outlined, size: 19),
              label: Text('Chat', semanticsLabel: 'Open Street chat', style: AppText.heading.copyWith(color: white, fontSize: 14.5)),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: AppText.title.copyWith(color: Colors.white, fontSize: 22)),
        ),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600, height: 1.25)),
      ]),
    );
  }
}

/// One line that explains what a bucket is (the five-second test).
class BucketExplainer extends StatelessWidget {
  const BucketExplainer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(AppRadius.photo)),
      child: Row(children: [
        const BrandMark(size: 32),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: 'A bucket ', style: AppText.body.copyWith(fontWeight: FontWeight.w800, color: AppColors.brandDeep)),
              TextSpan(
                text: 'is one big order your neighbours split. Join one at wholesale price, or start your own.',
                style: AppText.body.copyWith(color: AppColors.ink, height: 1.35),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// "Start your own bucket": the four kinds, one line each.
class StartTypeTiles extends StatelessWidget {
  const StartTypeTiles({super.key, required this.onTap});

  final void Function(BucketType type) onTap;

  static const _types = [
    (BucketType.split, 'Split', 'A whole fish or goat, cut into shares', Icons.call_split_rounded, Color(0xFFE3F0FA), Color(0xFF1F6FB2)),
    (BucketType.bulk, 'Bulk', 'Rice, oil, mangoes: cheaper as more join', Icons.inventory_2_outlined, Color(0xFFF7EEDD), Color(0xFF9A6A12)),
    (BucketType.service, 'Service', 'One pro for the whole tower', Icons.handyman_outlined, Color(0xFFE6F5EE), Color(0xFF12804A)),
    (BucketType.trip, 'Market trip', "One tempo, everyone's mandi list", Icons.local_shipping_outlined, Color(0xFFFFF1EC), AppColors.brandDeep),
  ];

  @override
  Widget build(BuildContext context) {
    Widget tile(int i) {
      final (type, name, line, icon, bg, fg) = _types[i];
      return Expanded(
        child: Semantics(
          button: true,
          label: 'Start a $name bucket. $line',
          excludeSemantics: true,
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder, side: const BorderSide(color: AppColors.line)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onTap(type),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.md),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.photo)),
                      child: Icon(icon, color: fg, size: 22),
                    ),
                    const Spacer(),
                    const Icon(Icons.add_circle_outline_rounded, color: AppColors.brand, size: 22),
                  ]),
                  const SizedBox(height: AppSpace.md),
                  Text(name, style: AppText.heading.copyWith(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(line, style: AppText.caption.copyWith(height: 1.35), maxLines: 3, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    return Column(children: [
      IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [tile(0), const SizedBox(width: AppSpace.md), tile(1)])),
      const SizedBox(height: AppSpace.md),
      IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [tile(2), const SizedBox(width: AppSpace.md), tile(3)])),
    ]);
  }
}

/// Loading placeholders shaped like the home sections.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Skeleton(height: 300, radius: AppRadius.sheet),
        SizedBox(height: AppSpace.md),
        Skeleton(height: 56, radius: AppRadius.photo),
        SizedBox(height: AppSpace.xxxl),
        Skeleton(width: 180, height: 18),
        SizedBox(height: AppSpace.md),
        Skeleton(height: 240, radius: AppRadius.card),
      ]),
    );
  }
}

/// Friendly error with a retry button.
class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.xxl),
      child: Column(children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(color: AppColors.brandTint, shape: BoxShape.circle),
          child: const Icon(Icons.wifi_off_rounded, color: AppColors.brand, size: 32),
        ),
        const SizedBox(height: AppSpace.lg),
        Text("Couldn't load your street", style: AppText.heading, textAlign: TextAlign.center),
        const SizedBox(height: AppSpace.xs),
        Text(message, style: AppText.bodyMuted, textAlign: TextAlign.center),
        const SizedBox(height: AppSpace.lg),
        AppButton.secondary(label: 'Try again', icon: Icons.refresh_rounded, expand: false, onPressed: onRetry),
      ]),
    );
  }
}
