import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/images.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// Illustrations for the onboarding slides, built from product photos and UI
/// pieces. Used until (or whenever) the generated onboarding photos are missing.

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.colors, required this.child});

  final List<Color> colors;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Stack(children: [
          Positioned(right: -40, top: -40, child: _Blob(size: 180, color: Colors.white.withValues(alpha: 0.35))),
          Positioned(left: -30, bottom: -50, child: _Blob(size: 150, color: Colors.white.withValues(alpha: 0.25))),
          Positioned.fill(child: child),
        ]),
      );
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

BoxDecoration _card() => BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: const Color(0x14000000)),
      boxShadow: const [BoxShadow(color: Color(0x0F3A1A0E), blurRadius: 12, offset: Offset(0, 2))],
    );

/// Slide 1: four product tiles with their street price drop.
class StreetArt extends StatelessWidget {
  const StreetArt({super.key});

  @override
  Widget build(BuildContext context) {
    const tiles = [
      ('seer', 'Whole seer', '-32%', -4.0),
      ('basmati', 'Basmati 1121', '-29%', 3.0),
      ('alphonso', 'Alphonso peti', '-21%', 2.5),
      ('pest', 'Pest control', '-38%', -3.0),
    ];
    return _Backdrop(
      colors: const [Color(0xFFFFE6DC), Color(0xFFFFF4EE)],
      child: LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth - 56) / 2;
        final h = math.min(w * 1.02, (c.maxHeight - 56) / 2);
        return Center(
          child: Wrap(spacing: 16, runSpacing: 16, children: [
            for (final (key, label, off, deg) in tiles)
              Transform.rotate(
                angle: deg * math.pi / 180,
                child: Container(
                  width: w,
                  height: h,
                  padding: const EdgeInsets.all(8),
                  decoration: _card(),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: AppRadius.photoBorder,
                        child: Image.asset(AppImages.bucket(key)!, fit: BoxFit.cover, width: double.infinity,
                            errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.brandTint)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.tiny.copyWith(color: AppColors.ink))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.saveTint, borderRadius: BorderRadius.circular(6)),
                        child: Text(off, style: AppText.tiny.copyWith(color: AppColors.save, fontWeight: FontWeight.w800)),
                      ),
                    ]),
                  ]),
                ),
              ),
          ]),
        );
      }),
    );
  }
}

/// Slide 2: a UPI hold card that resolves to paid or released.
class HeldArt extends StatelessWidget {
  const HeldArt({super.key});

  @override
  Widget build(BuildContext context) {
    return _Backdrop(
      colors: const [Color(0xFFFFF0CF), Color(0xFFFFF9EC)],
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(AppSpace.lg),
              decoration: _card(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(color: AppColors.heldTint, shape: BoxShape.circle),
                    child: const Icon(Icons.lock_clock_rounded, color: AppColors.held, size: 22),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Basmati 1121 · 10 kg', style: AppText.label),
                      Text('Held with UPI', style: AppText.caption),
                    ]),
                  ),
                  Text('₹960', style: AppText.price.copyWith(color: AppColors.held)),
                ]),
                const SizedBox(height: AppSpace.lg),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: const LinearProgressIndicator(value: 0.87, minHeight: 8, color: AppColors.brand, backgroundColor: AppColors.brandTint),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Text('87 of 100 kg', style: AppText.caption.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('13 kg to ₹88', style: AppText.caption.copyWith(color: AppColors.save, fontWeight: FontWeight.w700)),
                ]),
              ]),
            ),
            const SizedBox(height: AppSpace.lg),
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _Outcome(icon: Icons.check_circle_rounded, label: 'Fills: paid', fg: AppColors.save, bg: AppColors.saveTint),
              SizedBox(width: AppSpace.md),
              _Outcome(icon: Icons.undo_rounded, label: "Doesn't: released", fg: AppColors.released, bg: AppColors.releasedTint),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({required this.icon, required this.label, required this.fg, required this.bg});
  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.chip), border: Border.all(color: bg, width: 2)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(label, style: AppText.label.copyWith(color: fg, fontSize: 12.5)),
        ]),
      );
}

/// Slide 3: one order for the whole tower, dropped at the gate.
class GateArt extends StatelessWidget {
  const GateArt({super.key});

  @override
  Widget build(BuildContext context) {
    const flats = [('Ananya', 'B-1204', '10 kg'), ('Meera', 'A-303', '15 kg'), ('Kiran', 'B-402', '20 kg')];
    return _Backdrop(
      colors: const [Color(0xFFD9F2E4), Color(0xFFF1FAF5)],
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Container(
            padding: const EdgeInsets.all(AppSpace.lg),
            decoration: _card(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: AppColors.saveTint, shape: BoxShape.circle),
                  child: const Icon(Icons.local_shipping_rounded, color: AppColors.save, size: 22),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Order JS-2041 · 11 flats', style: AppText.label),
                    Text('Arriving at Gate 2, 7:30 am', style: AppText.caption),
                  ]),
                ),
              ]),
              const SizedBox(height: AppSpace.md),
              const Divider(),
              for (final (name, flat, qty) in flats)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.save),
                    const SizedBox(width: AppSpace.sm),
                    Text(name, style: AppText.label),
                    Text('  $flat', style: AppText.caption),
                    const Spacer(),
                    Text(qty, style: AppText.label),
                  ]),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('+ 8 more flats', style: AppText.caption),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
