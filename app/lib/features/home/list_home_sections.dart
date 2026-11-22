import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/images.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import '../bucket/card_parts.dart';

/// Section title + subtitle: tight 20 px heading, muted subtitle, 32 above and
/// 16 below. [live] puts a pulsing dot before the subtitle.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader(this.title, {super.key, this.subtitle, this.action, this.onAction, this.live = false});

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter + 4, AppSpace.xxxl, AppSpace.sm, AppSpace.lg),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.heading.copyWith(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4, height: 1.2)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  if (live) ...[
                    const PulseDot(color: AppColors.save, size: 6),
                    const SizedBox(width: 2),
                  ],
                  Flexible(child: Text(subtitle!, style: AppText.caption.copyWith(fontSize: 13, height: 1.3))),
                ]),
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
  const PulseDot({super.key, this.color = AppColors.live, this.size = 8});

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

/// Full-bleed brand hero: tomato gradient over a duotone Kasimedu photo with
/// soft glows, and frosted glass on top. Community switcher, "Buying together
/// on Sea Breeze Street", the people, three live numbers and the two actions
/// (start a bucket, open the Street chat). [topInset] leaves room for the
/// floating top bar. Null numbers render as a dash while the street loads.
class TogetherHero extends StatelessWidget {
  const TogetherHero({
    super.key,
    required this.streetName,
    required this.communityName,
    required this.people,
    required this.month,
    required this.onStart,
    this.place,
    this.members,
    this.liveBuckets,
    this.saved,
    this.onChat,
    this.onSwitchCommunity,
    this.topInset = 0,
    this.bottomInset = AppSpace.xxxl,
  });

  final String streetName;
  final String communityName;

  /// `B-1204` (the viewer's flat), shown next to the community.
  final String? place;

  /// Everyone in a live bucket right now (from the bucket list).
  final List<User> people;

  /// Community snapshot from `GET /api/communities/:id` → `stats`, so these
  /// numbers match the admin screen.
  final int? members;
  final int? liveBuckets;
  final int? saved;

  /// Month name for "saved in November".
  final String month;
  final VoidCallback onStart;
  final VoidCallback? onChat;
  final VoidCallback? onSwitchCommunity;
  final double topInset;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    final muted = Colors.white.withValues(alpha: 0.86);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.hero)),
      child: Stack(children: [
        const Positioned.fill(child: HeroBackdrop()),
        Padding(
          padding: EdgeInsets.fromLTRB(AppSpace.xl, topInset + AppSpace.sm, AppSpace.xl, bottomInset),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: _CommunityPill(name: communityName, place: place, onTap: onSwitchCommunity)),
              const SizedBox(width: AppSpace.md),
              const PulseDot(size: 7),
              Text('LIVE', style: AppText.tiny.copyWith(color: white, letterSpacing: 1.4, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: AppSpace.xl),
            Semantics(
              header: true,
              child: Text(
                'Buying together on\n$streetName',
                style: AppText.display.copyWith(color: white, fontSize: 30, height: 1.12, letterSpacing: -0.9),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            if (people.isNotEmpty)
              Row(children: [
                AvatarStack(users: people, size: 28, max: 4),
                const SizedBox(width: AppSpace.sm + 2),
                Expanded(
                  child: Text(
                    '${people.length} ${people.length == 1 ? 'neighbour' : 'neighbours'} in a bucket now',
                    style: AppText.label.copyWith(color: muted, fontSize: 13.5, height: 1.3),
                    maxLines: 2,
                  ),
                ),
              ])
            else
              Text('Big orders, split between neighbours.', style: AppText.label.copyWith(color: muted, fontSize: 13.5)),
            const SizedBox(height: AppSpace.xl),
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _StatChip(icon: Icons.shopping_basket_rounded, value: liveBuckets == null ? '–' : '$liveBuckets', label: 'live\nbuckets'),
                const SizedBox(width: AppSpace.sm),
                _StatChip(icon: Icons.groups_rounded, value: members == null ? '–' : Fmt.number(members!), label: 'neighbours\non the app'),
                const SizedBox(width: AppSpace.sm),
                _StatChip(icon: Icons.savings_rounded, value: saved == null ? '–' : Fmt.rupees(saved!), label: 'saved in\n$month'),
              ]),
            ),
            const SizedBox(height: AppSpace.xl),
            Row(children: [
              Expanded(child: _StartButton(onPressed: onStart)),
              const SizedBox(width: AppSpace.sm + 2),
              _GlassChatButton(onPressed: onChat),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// The hero's painted background, shared with the floating top bar's look.
class HeroBackdrop extends StatelessWidget {
  const HeroBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    Widget glow(Color c, double size, double alpha) => IgnorePointer(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [c.withValues(alpha: alpha), c.withValues(alpha: 0)]),
            ),
          ),
        );
    return Stack(fit: StackFit.expand, children: [
      const DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.hero)),
      // The harbour at dawn, tinted into the brand (duotone) so text stays readable.
      Image.asset(
        AppImages.banners.first,
        fit: BoxFit.cover,
        alignment: const Alignment(0.4, 0.3),
        color: AppColors.brandDeep,
        colorBlendMode: BlendMode.multiply,
        opacity: const AlwaysStoppedAnimation(0.3),
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
      Positioned(top: -140, right: -110, child: glow(AppColors.glowAmber, 320, 0.4)),
      Positioned(top: 220, left: -140, child: glow(AppColors.glowRose, 300, 0.35)),
      Positioned(bottom: -140, right: -60, child: glow(AppColors.brandNight, 360, 0.55)),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00000000), Color(0x338F2A0F)],
          ),
        ),
      ),
    ]);
  }
}

class _CommunityPill extends StatelessWidget {
  const _CommunityPill({required this.name, this.place, this.onTap});

  final String name;
  final String? place;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Community $name, tap to switch',
      excludeSemantics: true,
      child: GlassPanel(
        radius: AppRadius.chip,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.location_on_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Flexible(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: name, style: AppText.label.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                      if (place != null && place!.isNotEmpty)
                        TextSpan(text: '  ·  $place', style: AppText.label.copyWith(color: Colors.white.withValues(alpha: 0.78), fontWeight: FontWeight.w500)),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.white),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$value ${label.replaceAll('\n', ' ')}',
        excludeSemantics: true,
        child: GlassPanel(
          radius: AppRadius.card,
          padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.sm, AppSpace.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: Icon(icon, size: 15, color: Colors.white),
            ),
            const SizedBox(height: AppSpace.sm + 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, maxLines: 1, style: AppText.title.copyWith(color: Colors.white, fontSize: 21, letterSpacing: -0.5, height: 1.1)),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 2,
              style: AppText.tiny.copyWith(color: Colors.white.withValues(alpha: 0.82), fontWeight: FontWeight.w600, fontSize: 11.5, height: 1.25),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Start a bucket',
      excludeSemantics: true,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: const [BoxShadow(color: Color(0x408F2A0F), blurRadius: 20, offset: Offset(0, 8))],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppGradients.button),
                    child: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: AppSpace.sm + 2),
                  Text('Start a bucket', style: AppText.heading.copyWith(color: AppColors.brandDeep, fontSize: 15, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassChatButton extends StatelessWidget {
  const _GlassChatButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final on = onPressed != null;
    return Semantics(
      button: true,
      enabled: on,
      label: 'Open Street chat',
      excludeSemantics: true,
      child: SizedBox(
        height: 52,
        child: GlassPanel(
          radius: AppRadius.card,
          strong: true,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg + 2),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.forum_rounded, size: 19, color: Colors.white.withValues(alpha: on ? 1 : 0.5)),
                  const SizedBox(width: AppSpace.sm),
                  Text('Chat', style: AppText.heading.copyWith(color: Colors.white.withValues(alpha: on ? 1 : 0.5), fontSize: 15)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What a bucket is, in one line and three steps (the five-second test).
class BucketExplainer extends StatelessWidget {
  const BucketExplainer({super.key});

  static const _steps = [
    (Icons.group_add_rounded, 'Join at\nwholesale'),
    (Icons.trending_up_rounded, 'Neighbours\nfill it'),
    (Icons.storefront_rounded, 'Collect at\nthe gate'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        boxShadow: AppShadows.floating,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const BrandMark(size: 36),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: 'A bucket ', style: AppText.body.copyWith(fontWeight: FontWeight.w800, color: AppColors.brandDeep)),
                TextSpan(text: 'is one big order your neighbours split.', style: AppText.body.copyWith(height: 1.35, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: AppSpace.md + 2),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < _steps.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.only(top: 7),
                child: Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.line),
              ),
            Expanded(
              child: Column(children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(color: AppColors.brandTint, shape: BoxShape.circle),
                  child: Icon(_steps[i].$1, size: 16, color: AppColors.brand),
                ),
                const SizedBox(height: 6),
                Text(
                  _steps[i].$2,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: AppText.tiny.copyWith(color: AppColors.ink, fontSize: 11.5, height: 1.3),
                ),
              ]),
            ),
          ],
        ]),
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
      final r = BorderRadius.circular(AppRadius.tile);
      return Expanded(
        child: Semantics(
          button: true,
          label: 'Start a $name bucket. $line',
          excludeSemantics: true,
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: r, boxShadow: AppShadows.card),
            child: Material(
              color: AppColors.surface,
              borderRadius: r,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onTap(type),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
                        child: Icon(icon, color: fg, size: 22),
                      ),
                      const Spacer(),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(color: AppColors.canvas, shape: BoxShape.circle),
                        child: const Icon(Icons.add_rounded, color: AppColors.brand, size: 18),
                      ),
                    ]),
                    const SizedBox(height: AppSpace.md + 2),
                    Text(name, style: AppText.heading.copyWith(fontSize: 15.5, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                    const SizedBox(height: 3),
                    Text(line, style: AppText.caption.copyWith(height: 1.35), maxLines: 3, overflow: TextOverflow.ellipsis),
                  ]),
                ),
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
        Skeleton(height: 120, radius: AppRadius.tile),
        SizedBox(height: AppSpace.xxxl),
        Skeleton(width: 180, height: 20),
        SizedBox(height: AppSpace.lg),
        Skeleton(height: 360, radius: AppRadius.feature),
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
