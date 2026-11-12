import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/images.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import '../bucket/bucket_card.dart';
import '../bucket/card_parts.dart';
import '../bucket/list_logic.dart';

/// Section title + subtitle, Licious spacing (24 above, 12 below).
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader(this.title, {super.key, this.subtitle, this.action, this.onAction});

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.xxl, AppSpace.sm, AppSpace.md),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.heading.copyWith(fontSize: 18)),
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

/// One promo banner: photo (or a branded fallback) with copy on top.
class HomeBanner {
  const HomeBanner({
    required this.kicker,
    required this.title,
    required this.body,
    required this.image,
    required this.fallbackPhoto,
    required this.colors,
    required this.onTap,
  });

  final String kicker;
  final String title;
  final String body;
  final String image;

  /// Product photo used in the fallback art while the banner photo is missing.
  final String? fallbackPhoto;
  final List<Color> colors;
  final VoidCallback onTap;
}

/// Auto-advancing banner carousel with page dots (Licious hero banner).
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key, required this.banners, this.interval = const Duration(seconds: 5)});

  final List<HomeBanner> banners;
  final Duration interval;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final _page = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || !_page.hasClients || widget.banners.length < 2) return;
      final next = (_index + 1) % widget.banners.length;
      _page.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      LayoutBuilder(builder: (context, c) {
        final h = ((c.maxWidth - AppSpace.gutter * 2) / 2.3).clamp(140.0, 200.0);
        return SizedBox(
          height: h,
          child: PageView.builder(
            controller: _page,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
              child: _BannerTile(banner: widget.banners[i]),
            ),
          ),
        );
      }),
      const SizedBox(height: AppSpace.md),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < widget.banners.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _index ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == _index ? AppColors.brand : const Color(0xFFE2D9D3),
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
          ),
      ]),
    ]);
  }
}

class _BannerTile extends StatelessWidget {
  const _BannerTile({required this.banner});

  final HomeBanner banner;

  @override
  Widget build(BuildContext context) {
    final b = banner;
    final fallback = DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(colors: b.colors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: b.fallbackPhoto == null
          ? const SizedBox.expand()
          : Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.52,
                heightFactor: 1,
                child: ShaderMask(
                  shaderCallback: (r) => const LinearGradient(colors: [Colors.transparent, Colors.black], stops: [0, 0.45]).createShader(r),
                  blendMode: BlendMode.dstIn,
                  child: Image.asset(b.fallbackPhoto!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
                ),
              ),
            ),
    );
    return Semantics(
      button: true,
      label: '${b.kicker}. ${b.title}. ${b.body}',
      child: ClipRRect(
        borderRadius: AppRadius.cardBorder,
        child: Material(
          color: b.colors.first,
          child: InkWell(
            onTap: b.onTap,
            child: Stack(fit: StackFit.expand, children: [
              Image.asset(b.image, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
              // Scrim so copy stays legible on any photo.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withValues(alpha: 0.55), Colors.black.withValues(alpha: 0.0)],
                    stops: const [0.0, 0.75],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.md),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(AppRadius.chip)),
                    child: Text(b.kicker.toUpperCase(),
                        style: AppText.tiny.copyWith(color: Colors.white, letterSpacing: 0.8, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  SizedBox(
                    width: 230,
                    child: Text(b.title, maxLines: 2, style: AppText.title.copyWith(color: Colors.white, fontSize: 21, height: 1.15)),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 220,
                    child: Text(b.body, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(color: Colors.white.withValues(alpha: 0.9), fontSize: 12.5)),
                  ),
                  const Spacer(),
                ]),
              ),
              Positioned(
                right: AppSpace.md,
                bottom: AppSpace.md,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_forward_rounded, size: 20, color: AppColors.brand),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Round photo tile for a category, falling back to a tinted icon disc.
class CategoryCircle extends StatelessWidget {
  const CategoryCircle({super.key, required this.id, this.size = 68});

  final String id;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (tint, icon) = categoryArt(id);
    final fallback = ColoredBox(color: tint, child: Center(child: Icon(icon, size: size * 0.44, color: AppColors.ink.withValues(alpha: 0.6))));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: tint),
      child: ClipOval(child: Image.asset(AppImages.category(id), fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback)),
    );
  }
}

/// "Shop by category": 4 × 2 round photo tiles.
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({super.key, required this.onTap, this.counts = const {}});

  final void Function(String id) onTap;

  /// Live buckets per category id, shown as a small badge.
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final cats = AppImages.categories;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
      child: Column(children: [
        for (var row = 0; row < (cats.length / 4).ceil(); row++)
          Padding(
            padding: EdgeInsets.only(top: row == 0 ? 0 : AppSpace.md),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var col = 0; col < 4; col++)
                Expanded(
                  child: row * 4 + col < cats.length
                      ? _CategoryTile(id: cats[row * 4 + col].$1, label: cats[row * 4 + col].$2, count: counts[cats[row * 4 + col].$1] ?? 0, onTap: onTap)
                      : const SizedBox(),
                ),
            ]),
          ),
      ]),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.id, required this.label, required this.count, required this.onTap});

  final String id;
  final String label;
  final int count;
  final void Function(String id) onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count > 0 ? '$label, $count live' : label,
      child: InkWell(
        onTap: () => onTap(id),
        borderRadius: BorderRadius.circular(AppRadius.photo),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            Stack(clipBehavior: Clip.none, children: [
              const SizedBox(width: 68, height: 68),
              CategoryCircle(id: id),
              if (count > 0)
                Positioned(
                  right: -4,
                  top: -2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                      border: Border.all(color: AppColors.canvas, width: 2),
                    ),
                    child: Text('$count', textAlign: TextAlign.center, style: AppText.tiny.copyWith(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ),
            ]),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, maxLines: 2, style: AppText.caption.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600, height: 1.2)),
          ]),
        ),
      ),
    );
  }
}

/// Street savings this month.
class SavingsCard extends StatelessWidget {
  const SavingsCard({super.key, required this.saved, required this.members, required this.live, this.onTap});

  final int saved;
  final int members;
  final int live;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      onTap: onTap,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your street saved this month', style: AppText.caption.copyWith(fontSize: 12.5)),
            const SizedBox(height: 4),
            Text(Fmt.rupees(saved), style: AppText.display.copyWith(color: AppColors.save, fontSize: 30)),
            const SizedBox(height: 4),
            Text('vs. shop prices, across $members neighbours', style: AppText.caption),
          ]),
        ),
        const SizedBox(width: AppSpace.md),
        Container(
          width: 76,
          padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
          decoration: BoxDecoration(color: AppColors.saveTint, borderRadius: BorderRadius.circular(AppRadius.photo)),
          child: Column(children: [
            Text('$live', style: AppText.title.copyWith(color: AppColors.save)),
            Text('live now', style: AppText.tiny.copyWith(color: AppColors.save)),
          ]),
        ),
      ]),
    );
  }
}

/// Entry to the society group chat.
class StreetChatCard extends StatelessWidget {
  const StreetChatCard({super.key, required this.title, required this.members, this.latest, required this.onTap});

  final String title;
  final int members;
  final String? latest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      onTap: onTap,
      semanticsLabel: 'Open $title chat',
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(color: AppColors.brandTint, shape: BoxShape.circle),
            child: const Icon(Icons.forum_rounded, color: AppColors.brand, size: 24),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(color: AppColors.save, shape: BoxShape.circle, border: Border.all(color: AppColors.surface, width: 2)),
            ),
          ),
        ]),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppText.heading.copyWith(fontSize: 15)),
            const SizedBox(height: 2),
            Text('$members neighbours · live buckets post here', style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (latest != null) ...[
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'Latest: ', style: AppText.caption),
                  TextSpan(text: latest, style: AppText.caption.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
      ]),
    );
  }
}

/// "Start a bucket" call to action.
class StartBucketCard extends StatelessWidget {
  const StartBucketCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        gradient: const LinearGradient(colors: [Color(0xFFE4572E), Color(0xFFC9431F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Buying something big?', style: AppText.heading.copyWith(color: Colors.white, fontSize: 17)),
            const SizedBox(height: 4),
            Text('A whole fish, a sack of rice, a plumber for the tower. Start a bucket and your neighbours fill it.',
                style: AppText.caption.copyWith(color: Colors.white.withValues(alpha: 0.9), fontSize: 12.5, height: 1.35)),
            const SizedBox(height: AppSpace.md),
            Semantics(
              button: true,
              child: SizedBox(
                height: 40,
                child: TextButton.icon(
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.brandDeep,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text('Start a bucket', style: AppText.heading.copyWith(color: AppColors.brandDeep, fontSize: 14)),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(width: AppSpace.md),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), shape: BoxShape.circle),
          child: const Icon(Icons.shopping_basket_rounded, color: Colors.white, size: 32),
        ),
      ]),
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({required this.child, this.onTap, this.semanticsLabel});

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder, side: const BorderSide(color: AppColors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(AppSpace.lg), child: child)),
      ),
    );
  }
}

/// Loading placeholders shaped like the home sections.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter),
        child: Skeleton(height: 156, radius: AppRadius.card),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.xxxl, AppSpace.gutter, AppSpace.md),
        child: Skeleton(width: 160, height: 18),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (var i = 0; i < 4; i++)
            const Column(children: [Skeleton(width: 68, height: 68, circle: true), SizedBox(height: 8), Skeleton(width: 52, height: 10)]),
        ]),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.xxxl, AppSpace.gutter, AppSpace.md),
        child: Skeleton(width: 140, height: 18),
      ),
      SizedBox(
        height: 220,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          children: const [
            Skeleton(width: BucketCard.compactWidth, height: 220, radius: AppRadius.card),
            SizedBox(width: AppSpace.md),
            Skeleton(width: BucketCard.compactWidth, height: 220, radius: AppRadius.card),
          ],
        ),
      ),
    ]);
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
