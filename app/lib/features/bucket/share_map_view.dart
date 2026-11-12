import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import 'detail_widgets.dart';

/// True for a whole fish split head → steaks → tail (draw it as a fish).
bool isFishSplit(Bucket b) {
  if (b.type != BucketType.split || b.units.length < 3) return false;
  final first = b.units.first.label.toLowerCase();
  final last = b.units.last.label.toLowerCase();
  return first.startsWith('head') && last.startsWith('tail');
}

enum _PartState { open, taken, mine, selected }

/// Interactive map of a split bucket's parts: a drawn fish for head/steaks/tail
/// splits, else a grid of share tiles. Tap an open part to select it.
class ShareMap extends StatelessWidget {
  const ShareMap({
    super.key,
    required this.bucket,
    required this.selected,
    required this.mine,
    required this.onTap,
    this.enabled = true,
  });

  final Bucket bucket;
  final Set<String> selected;
  final Set<String> mine;
  final ValueChanged<BucketUnit> onTap;
  final bool enabled;

  _PartState _state(BucketUnit u) {
    if (mine.contains(u.id)) return _PartState.mine;
    if (selected.contains(u.id)) return _PartState.selected;
    if (u.owner != null) return _PartState.taken;
    return _PartState.open;
  }

  @override
  Widget build(BuildContext context) {
    if (isFishSplit(bucket)) {
      return _FishMap(units: bucket.units, stateOf: _state, onTap: enabled ? onTap : null, retailPerKg: bucket.retailUnitPrice);
    }
    return _TileGrid(units: bucket.units, stateOf: _state, onTap: enabled ? onTap : null, unitLabel: bucket.unitLabel ?? 'share');
  }
}

/// "● Open  ● Taken  ● Yours" key under the map.
class ShareMapLegend extends StatelessWidget {
  const ShareMapLegend({super.key, required this.open, required this.taken});

  final int open;
  final int taken;

  @override
  Widget build(BuildContext context) {
    Widget dot(Color fill, {Color? border, bool dashed = false}) => Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: border ?? fill, width: dashed ? 1.5 : 1),
          ),
        );
    Widget item(Widget d, String t) => Row(mainAxisSize: MainAxisSize.min, children: [d, const SizedBox(width: 6), Text(t, style: AppText.caption)]);
    return Wrap(spacing: AppSpace.lg, runSpacing: AppSpace.xs, children: [
      item(dot(AppColors.surface, border: AppColors.brand, dashed: true), '$open open'),
      item(dot(const Color(0xFFDCE4EA)), '$taken taken'),
      item(dot(AppColors.brand), 'Your pick'),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Fish

class _FishMap extends StatelessWidget {
  const _FishMap({required this.units, required this.stateOf, required this.onTap, this.retailPerKg});

  final List<BucketUnit> units;
  final _PartState Function(BucketUnit) stateOf;
  final ValueChanged<BucketUnit>? onTap;
  final int? retailPerKg;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final h = w * 0.44;
      final geo = _FishGeometry(units.length);
      final states = [for (final u in units) stateOf(u)];
      return SizedBox(
        width: w,
        height: h + 26,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            bottom: 26,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => CustomPaint(painter: _FishPainter(geo: geo, units: units, states: states, reveal: t)),
            ),
          ),
          for (var i = 0; i < units.length; i++) ...[
            // Marker (owner initial / + / check) at the segment's anchor.
            Positioned(
              left: geo.anchor(i).dx * w - 13,
              top: geo.anchor(i).dy * h - 13,
              child: IgnorePointer(child: _Marker(unit: units[i], state: states[i])),
            ),
            // Label under the fish.
            Positioned(
              left: geo.center(i) * w - 24,
              width: 48,
              top: h + 6,
              child: Text(
                geo.shortLabel(i, units[i].label),
                textAlign: TextAlign.center,
                style: AppText.tiny.copyWith(
                  color: states[i] == _PartState.selected || states[i] == _PartState.mine ? AppColors.brandDeep : AppColors.inkMuted,
                  fontWeight: states[i] == _PartState.selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            // Tap region (full height of the fish + label row).
            Positioned(
              left: geo.slab(i).$1 * w,
              width: (geo.slab(i).$2 - geo.slab(i).$1) * w,
              top: 0,
              height: h + 26,
              child: Semantics(
                button: states[i] == _PartState.open || states[i] == _PartState.selected,
                selected: states[i] == _PartState.selected,
                label: _semantic(units[i], states[i]),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap == null || states[i] == _PartState.taken || states[i] == _PartState.mine ? null : () => onTap!(units[i]),
                ),
              ),
            ),
          ],
        ]),
      );
    });
  }

  String _semantic(BucketUnit u, _PartState s) {
    final grams = u.grams == null ? '' : ', about ${u.grams} grams';
    return switch (s) {
      _PartState.open => '${u.label}$grams, ${Fmt.rupees(u.price)}, open. Tap to pick',
      _PartState.selected => '${u.label}$grams, ${Fmt.rupees(u.price)}, picked. Tap to remove',
      _PartState.taken => '${u.label}, taken by ${u.owner?.name ?? 'a neighbour'}',
      _PartState.mine => '${u.label}, yours',
    };
  }
}

/// Normalised fish layout: head slab, equal steak slabs, tail slab.
class _FishGeometry {
  _FishGeometry(this.n);

  final int n;
  static const headEnd = 0.24;
  static const tailStart = 0.80;

  (double, double) slab(int i) {
    if (i == 0) return (0, headEnd);
    if (i == n - 1) return (tailStart, 1);
    final w = (tailStart - headEnd) / (n - 2);
    return (headEnd + (i - 1) * w, headEnd + i * w);
  }

  double center(int i) {
    if (i == 0) return 0.13;
    if (i == n - 1) return 0.88;
    final s = slab(i);
    return (s.$1 + s.$2) / 2;
  }

  Offset anchor(int i) {
    if (i == 0) return const Offset(0.165, 0.54);
    if (i == n - 1) return const Offset(0.86, 0.50);
    return Offset(center(i), 0.50);
  }

  String shortLabel(int i, String label) {
    if (i == 0) return 'Head';
    if (i == n - 1) return 'Tail';
    final digits = RegExp(r'\d+').firstMatch(label)?.group(0);
    return digits ?? label;
  }

  /// Body + tail outline in a w×h box.
  Path outline(Size s) {
    final w = s.width, h = s.height;
    Offset p(double x, double y) => Offset(x * w, y * h);
    final path = Path()..moveTo(p(0.015, 0.54).dx, p(0.015, 0.54).dy);
    void cubic(Offset a, Offset b, Offset c) => path.cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
    // upper contour: snout → back → peduncle
    cubic(p(0.04, 0.34), p(0.14, 0.16), p(0.32, 0.12));
    cubic(p(0.50, 0.08), p(0.68, 0.14), p(0.79, 0.30));
    cubic(p(0.82, 0.35), p(0.845, 0.40), p(0.865, 0.42));
    // tail fin
    cubic(p(0.90, 0.30), p(0.95, 0.14), p(0.995, 0.04));
    cubic(p(0.975, 0.24), p(0.955, 0.40), p(0.945, 0.50));
    cubic(p(0.955, 0.60), p(0.975, 0.76), p(0.995, 0.96));
    cubic(p(0.95, 0.86), p(0.90, 0.70), p(0.865, 0.58));
    // lower contour: peduncle → belly → snout
    cubic(p(0.845, 0.60), p(0.82, 0.65), p(0.78, 0.70));
    cubic(p(0.66, 0.86), p(0.46, 0.92), p(0.30, 0.88));
    cubic(p(0.15, 0.84), p(0.05, 0.74), p(0.015, 0.54));
    return path..close();
  }
}

class _FishPainter extends CustomPainter {
  _FishPainter({required this.geo, required this.units, required this.states, required this.reveal});

  final _FishGeometry geo;
  final List<BucketUnit> units;
  final List<_PartState> states;
  final double reveal;

  static const _taken = Color(0xFFDCE4EA);
  static const _body = Color(0xFFF4F7F9);

  @override
  void paint(Canvas canvas, Size size) {
    final fish = geo.outline(size);

    // soft drop shadow
    canvas.drawPath(fish.shift(const Offset(0, 4)), Paint()
      ..color = AppColors.ink.withValues(alpha: 0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawPath(fish, Paint()..color = _body);

    for (var i = 0; i < units.length; i++) {
      final (a, b) = geo.slab(i);
      final rect = Rect.fromLTRB(a * size.width, -2, b * size.width, size.height + 2);
      final seg = Path.combine(PathOperation.intersect, fish, Path()..addRect(rect));
      final st = states[i];
      final fill = switch (st) {
        _PartState.open => AppColors.surface,
        _PartState.taken => Color.lerp(_taken, personColor(units[i].owner?.name ?? ''), 0.10)!,
        _PartState.mine => AppColors.brand,
        _PartState.selected => AppColors.brand,
      };
      canvas.drawPath(seg, Paint()..color = fill);
      if (st == _PartState.open) {
        canvas.drawPath(seg, Paint()..color = AppColors.brandTint.withValues(alpha: 0.6));
        _dashed(canvas, _inset(seg, rect, size), AppColors.brand.withValues(alpha: 0.85));
      }
      if (st == _PartState.mine) {
        // hatch "yours" so it reads differently from a fresh pick
        canvas.save();
        canvas.clipPath(seg);
        final hp = Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..strokeWidth = 4;
        for (var x = rect.left - size.height; x < rect.right; x += 10) {
          canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), hp);
        }
        canvas.restore();
      }
    }

    // cut lines between segments
    canvas.save();
    canvas.clipPath(fish);
    final cut = Paint()
      ..color = AppColors.surface
      ..strokeWidth = 3;
    for (var i = 0; i < units.length - 1; i++) {
      final x = geo.slab(i).$2 * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), cut);
    }
    // scale shimmer on the back
    final sheen = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.45));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.45), sheen);
    canvas.restore();

    // outline
    canvas.drawPath(fish, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = AppColors.ink.withValues(alpha: 0.28));

    // gill + eye on the head
    final w = size.width, h = size.height;
    final headDark = states.first == _PartState.selected || states.first == _PartState.mine;
    final gill = Path()
      ..moveTo(0.19 * w, 0.24 * h)
      ..quadraticBezierTo(0.235 * w, 0.52 * h, 0.19 * w, 0.80 * h);
    canvas.drawPath(gill, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = (headDark ? Colors.white : AppColors.ink).withValues(alpha: 0.35));
    canvas.drawCircle(Offset(0.075 * w, 0.42 * h), 0.045 * h, Paint()..color = headDark ? Colors.white : AppColors.surface);
    canvas.drawCircle(Offset(0.078 * w, 0.42 * h), 0.026 * h, Paint()..color = AppColors.ink);
    // mouth
    canvas.drawLine(Offset(0.02 * w, 0.56 * h), Offset(0.06 * w, 0.58 * h), Paint()
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = AppColors.ink.withValues(alpha: 0.4));

    // first-paint reveal: a white veil wipes left → right
    if (reveal < 1) {
      canvas.drawRect(
        Rect.fromLTRB(size.width * reveal, -4, size.width + 4, size.height + 4),
        Paint()..color = AppColors.surface.withValues(alpha: 1 - reveal),
      );
    }
  }

  Path _inset(Path seg, Rect rect, Size size) {
    // Shrink the open segment a little so the dashes sit inside the cut lines.
    final m = Matrix4.identity();
    final c = seg.getBounds().center;
    final sx = (seg.getBounds().width - 7) / math.max(1, seg.getBounds().width);
    final sy = (seg.getBounds().height - 7) / math.max(1, seg.getBounds().height);
    m.translateByDouble(c.dx, c.dy, 0, 1);
    m.scaleByDouble(sx, sy, 1, 1);
    m.translateByDouble(-c.dx, -c.dy, 0, 1);
    return seg.transform(m.storage);
  }

  void _dashed(Canvas canvas, Path path, Color color) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final next = math.min(d + 5, metric.length);
        canvas.drawPath(metric.extractPath(d, next), paint);
        d = next + 4;
      }
    }
  }

  @override
  bool shouldRepaint(_FishPainter old) => old.states.toString() != states.toString() || old.reveal != reveal || old.units != units;
}

class _Marker extends StatelessWidget {
  const _Marker({required this.unit, required this.state});

  final BucketUnit unit;
  final _PartState state;

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (state) {
      _PartState.open => Container(
          key: const ValueKey('open'),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.brand, width: 1.5),
          ),
          child: const Icon(Icons.add_rounded, size: 18, color: AppColors.brand),
        ),
      _PartState.selected => Container(
          key: const ValueKey('sel'),
          width: 26,
          height: 26,
          decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, size: 18, color: AppColors.brand),
        ),
      _PartState.mine => Container(
          key: const ValueKey('mine'),
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
          child: Text('You', style: AppText.tiny.copyWith(color: AppColors.brandDeep, fontSize: 8.5, fontWeight: FontWeight.w800)),
        ),
      _PartState.taken => SizedBox(
          key: ValueKey('t${unit.owner?.name}'),
          width: 26,
          height: 26,
          child: PersonAvatar(name: unit.owner?.name ?? '?', size: 26),
        ),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Tiles (goat shares, halves, crabs...)

class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.units, required this.stateOf, required this.onTap, required this.unitLabel});

  final List<BucketUnit> units;
  final _PartState Function(BucketUnit) stateOf;
  final ValueChanged<BucketUnit>? onTap;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = AppSpace.sm;
      final w = (c.maxWidth - gap) / 2;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final u in units) SizedBox(width: w, child: _Tile(unit: u, state: stateOf(u), onTap: onTap)),
      ]);
    });
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.unit, required this.state, required this.onTap});

  final BucketUnit unit;
  final _PartState state;
  final ValueChanged<BucketUnit>? onTap;

  @override
  Widget build(BuildContext context) {
    final sel = state == _PartState.selected;
    final mine = state == _PartState.mine;
    final open = state == _PartState.open;
    final taken = state == _PartState.taken;
    final kg = unit.grams == null ? null : '${fmtKg(unit.grams!)} kg';
    final tappable = onTap != null && (open || sel);
    return Semantics(
      button: tappable,
      selected: sel,
      label: '${unit.label}${kg == null ? '' : ', $kg'}, ${Fmt.rupees(unit.price)}, '
          '${open ? 'open' : sel ? 'picked' : mine ? 'yours' : 'taken by ${unit.owner?.name}'}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tappable ? () => onTap!(unit) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: sel || mine ? AppColors.brandTint : taken ? AppColors.canvas : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: sel || mine ? AppColors.brand : AppColors.line,
              width: sel || mine ? 1.6 : 1,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(unit.label,
                    style: AppText.label.copyWith(fontWeight: FontWeight.w700, color: taken ? AppColors.inkMuted : AppColors.ink),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              Text(Fmt.rupees(unit.price), style: AppText.label.copyWith(fontWeight: FontWeight.w800, color: taken ? AppColors.inkMuted : AppColors.ink).tab),
            ]),
            if (kg != null) ...[const SizedBox(height: 2), Text('about $kg', style: AppText.caption)],
            const SizedBox(height: AppSpace.sm),
            if (taken)
              Row(children: [
                PersonAvatar(name: unit.owner?.name ?? '?', size: 22, ring: false),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [unit.owner?.name, unit.owner?.unit].whereType<String>().join(' · '),
                    style: AppText.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ])
            else if (mine)
              Row(children: [
                const Icon(Icons.verified_rounded, size: 18, color: AppColors.brand),
                const SizedBox(width: 6),
                Text('Yours', style: AppText.label.copyWith(color: AppColors.brandDeep)),
              ])
            else
              Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: sel ? AppColors.brand : AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.brand, width: 1.5),
                  ),
                  child: Icon(sel ? Icons.check_rounded : Icons.add_rounded, size: 15, color: sel ? Colors.white : AppColors.brand),
                ),
                const SizedBox(width: 6),
                Text(sel ? 'Picked' : 'Open', style: AppText.label.copyWith(color: AppColors.brandDeep)),
              ]),
          ]),
        ),
      ),
    );
  }
}

/// `2`, `1.45`, `0.6` kg from grams.
String fmtKg(int grams) {
  final kg = grams / 1000;
  if (kg == kg.roundToDouble()) return kg.round().toString();
  return kg.toStringAsFixed(grams % 100 == 0 ? 1 : 2);
}
