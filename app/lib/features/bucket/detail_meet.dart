import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import 'detail_widgets.dart';

/// One person on the "Who's coming" list.
class MeetPerson {
  const MeetPerson({required this.name, required this.note, required this.status, this.me = false, this.here = false});

  final String name;
  final String note;
  final String status;
  final bool me;
  final bool here;
}

/// "Meet at the market" card: stylised map, place + time, who's coming and an
/// optional "I'm here" check-in button.
class MeetCard extends StatelessWidget {
  const MeetCard({
    super.key,
    required this.place,
    required this.market,
    this.at,
    this.note,
    this.people = const [],
    this.checkInLabel,
    this.onCheckIn,
    this.checkInHint,
    this.checkingIn = false,
    this.checkedIn = false,
  });

  final String place;
  final String market;
  final DateTime? at;
  final String? note;
  final List<MeetPerson> people;

  /// Null hides the button row.
  final String? checkInLabel;
  final VoidCallback? onCheckIn;
  final String? checkInHint;
  final bool checkingIn;
  final bool checkedIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(
          label: 'Map: meet at $place, $market',
          image: true,
          excludeSemantics: true,
          child: SizedBox(
            height: 150,
            width: double.infinity,
            child: CustomPaint(painter: MeetMapPainter(pinLabel: place, landmark: 'Auction hall')),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.place_outlined, color: AppColors.brandDeep, size: 22),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$market, $place', style: AppText.heading),
                  if (at != null) ...[
                    const SizedBox(height: 2),
                    Text(Fmt.dayTime(at!), style: AppText.label.copyWith(color: AppColors.brandDeep)),
                  ],
                ]),
              ),
            ]),
            if (note != null) ...[
              const SizedBox(height: AppSpace.md),
              Text(note!, style: AppText.bodyMuted),
            ],
            if (people.isNotEmpty) ...[
              const SizedBox(height: AppSpace.lg),
              Text("Who's coming", style: AppText.label.copyWith(color: AppColors.inkMuted)),
              const SizedBox(height: AppSpace.xs),
              for (final p in people)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    PersonAvatar(name: p.name, size: 32, ring: false, color: p.me ? AppColors.brand : null),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: p.me ? 'You' : p.name, style: AppText.label.copyWith(fontWeight: FontWeight.w700)),
                        TextSpan(text: '  ${p.note}', style: AppText.caption),
                      ])),
                    ),
                    StatusPill(p.status, tone: p.here ? PillTone.captured : PillTone.brand, icon: p.here ? Icons.check_rounded : null),
                  ]),
                ),
            ],
            if (checkInLabel != null) ...[
              const SizedBox(height: AppSpace.md),
              AppButton(
                label: checkedIn ? "You're checked in" : checkInLabel!,
                icon: checkedIn ? Icons.check_circle_rounded : Icons.near_me_outlined,
                kind: checkedIn ? AppButtonKind.secondary : AppButtonKind.primary,
                loading: checkingIn,
                onPressed: checkedIn ? null : onCheckIn,
              ),
              if (checkInHint != null) ...[
                const SizedBox(height: AppSpace.sm),
                Center(child: Text(checkInHint!, style: AppText.caption, textAlign: TextAlign.center)),
              ],
            ],
          ]),
        ),
      ]),
    );
  }
}

/// A calm, hand-drawn style map: sea on the right, a few roads, the auction
/// hall block and a brand pin at the gate.
class MeetMapPainter extends CustomPainter {
  MeetMapPainter({required this.pinLabel, required this.landmark});

  final String pinLabel;
  final String landmark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF3EFEA));

    // blocks
    final block = Paint()..color = const Color(0xFFE9E3DC);
    for (final r in [
      Rect.fromLTWH(w * 0.04, h * 0.08, w * 0.22, h * 0.40),
      Rect.fromLTWH(w * 0.04, h * 0.62, w * 0.22, h * 0.32),
      Rect.fromLTWH(w * 0.54, h * 0.08, w * 0.20, h * 0.30),
    ]) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), block);
    }
    // park
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.34, h * 0.08, w * 0.16, h * 0.36), const Radius.circular(6)),
      Paint()..color = const Color(0xFFDDEBD3),
    );

    // sea
    final sea = Path()
      ..moveTo(w * 0.80, 0)
      ..cubicTo(w * 0.76, h * 0.3, w * 0.86, h * 0.6, w * 0.80, h)
      ..lineTo(w, h)
      ..lineTo(w, 0)
      ..close();
    canvas.drawPath(sea, Paint()..color = const Color(0xFFD6E8F3));
    final wave = Paint()
      ..color = const Color(0xFFB9D6E9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final y in [0.25, 0.5, 0.75]) {
      final p = Path()
        ..moveTo(w * 0.88, h * y)
        ..quadraticBezierTo(w * 0.905, h * y - 4, w * 0.93, h * y)
        ..quadraticBezierTo(w * 0.955, h * y + 4, w * 0.98, h * y);
      canvas.drawPath(p, wave);
    }

    // roads (white with a hairline edge)
    final edge = Paint()
      ..color = const Color(0xFFE2DAD1)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;
    final roads = [
      Path()
        ..moveTo(0, h * 0.55)
        ..lineTo(w * 0.78, h * 0.55),
      Path()
        ..moveTo(w * 0.30, 0)
        ..lineTo(w * 0.30, h),
      Path()
        ..moveTo(w * 0.64, 0)
        ..lineTo(w * 0.58, h),
    ];
    for (final r in roads) {
      canvas.drawPath(r, edge);
    }
    for (final r in roads) {
      canvas.drawPath(r, road);
    }

    // auction hall
    final hall = Rect.fromLTWH(w * 0.34, h * 0.66, w * 0.20, h * 0.28);
    canvas.drawRRect(RRect.fromRectAndRadius(hall.translate(0, 2), const Radius.circular(8)), Paint()..color = AppColors.ink.withValues(alpha: 0.05));
    canvas.drawRRect(RRect.fromRectAndRadius(hall, const Radius.circular(8)), Paint()..color = const Color(0xFFFFE3D6));
    final hl = TextPainter(
      text: TextSpan(text: landmark, style: AppText.tiny.copyWith(color: AppColors.brandDeep, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: hall.width - 8);
    hl.paint(canvas, Offset(hall.center.dx - hl.width / 2, hall.center.dy - hl.height / 2));

    // pin at the gate (intersection of main road and the angled road)
    final pin = Offset(w * 0.612, h * 0.55);
    canvas.drawOval(Rect.fromCenter(center: pin + const Offset(0, 2), width: 18, height: 6), Paint()..color = AppColors.ink.withValues(alpha: 0.18));
    canvas.drawCircle(pin, 16, Paint()..color = AppColors.brand.withValues(alpha: 0.16));
    final drop = Path()
      ..moveTo(pin.dx, pin.dy)
      ..cubicTo(pin.dx - 4, pin.dy - 8, pin.dx - 12, pin.dy - 14, pin.dx - 12, pin.dy - 24)
      ..arcToPoint(Offset(pin.dx + 12, pin.dy - 24), radius: const Radius.circular(12))
      ..cubicTo(pin.dx + 12, pin.dy - 14, pin.dx + 4, pin.dy - 8, pin.dx, pin.dy)
      ..close();
    canvas.drawPath(drop, Paint()..color = AppColors.brand);
    canvas.drawCircle(Offset(pin.dx, pin.dy - 24), 4.5, Paint()..color = Colors.white);

    // label pill
    final tp = TextPainter(
      text: TextSpan(text: pinLabel, style: AppText.tiny.copyWith(color: AppColors.ink, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    final lr = RRect.fromRectAndRadius(
      Rect.fromLTWH(pin.dx - tp.width / 2 - 8, pin.dy + 8, tp.width + 16, tp.height + 6),
      const Radius.circular(999),
    );
    canvas.drawRRect(lr.shift(const Offset(0, 1)), Paint()..color = AppColors.ink.withValues(alpha: 0.08));
    canvas.drawRRect(lr, Paint()..color = Colors.white);
    tp.paint(canvas, Offset(lr.left + 8, lr.top + 3));
  }

  @override
  bool shouldRepaint(MeetMapPainter old) => old.pinLabel != pinLabel || old.landmark != landmark;
}
