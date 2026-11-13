import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import '../bucket/bucket_visuals.dart';
import '../orders/time_fmt.dart';

/// "Posted to your Street chat": a drawn check, the new card in brief, then [onDone]
/// fires on its own after a short beat (or straight away from the button).
class PostSuccess extends StatefulWidget {
  const PostSuccess({super.key, required this.bucket, required this.streetName, required this.onDone, required this.onOpenChat});

  final Bucket bucket;
  final String streetName;
  final VoidCallback onDone;
  final VoidCallback onOpenChat;

  @override
  State<PostSuccess> createState() => _PostSuccessState();
}

class _PostSuccessState extends State<PostSuccess> with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 2600);
  late final AnimationController _c = AnimationController(vsync: this, duration: _total);
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish();
    });
    _c.forward();
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Phases of the single controller: circle pops (0–0.18), tick draws (0.12–0.35),
  // text and card fade up (0.25–0.45), the bar fills to the hand-off (0.3–1).
  Animation<double> _phase(double a, double b, [Curve c = Curves.easeOutCubic]) => CurvedAnimation(
    parent: _c,
    curve: Interval(a, b, curve: c),
  );

  @override
  Widget build(BuildContext context) {
    final b = widget.bucket;
    final pop = _phase(0, 0.18, Curves.easeOutBack);
    final tick = _phase(0.12, 0.35);
    final rise = _phase(0.25, 0.45);
    final unit = b.unitLabel ?? 'share';
    final goal = switch (b.type) {
      BucketType.split => '${b.units.length} ${unit}s open',
      BucketType.trip => '${b.capacity ?? 0} kg of space',
      _ => b.tiers.isEmpty ? 'Open' : 'Goes ahead at ${b.tiers.first.minQty} $unit',
    };
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xxl),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    Semantics(
                      label: 'Posted',
                      child: ScaleTransition(
                        scale: pop,
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: AppColors.save,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: AppColors.save.withValues(alpha: 0.25), blurRadius: 24, spreadRadius: 4)],
                          ),
                          child: AnimatedBuilder(
                            animation: tick,
                            builder: (_, _) => CustomPaint(painter: _TickPainter(tick.value)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.xxl),
                    FadeTransition(
                      opacity: rise,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(rise),
                        child: Column(
                          children: [
                            Text('Posted to your Street chat', style: AppText.title.copyWith(fontSize: 22), textAlign: TextAlign.center),
                            const SizedBox(height: AppSpace.sm),
                            Text(
                              'Neighbours in ${widget.streetName} can take their share now. We\'ll ping you as it fills.',
                              style: AppText.bodyMuted,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpace.xxl),
                            Container(
                              padding: const EdgeInsets.all(AppSpace.md),
                              decoration: BoxDecoration(
                                color: AppColors.canvas,
                                borderRadius: AppRadius.cardBorder,
                                border: Border.all(color: AppColors.line),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(width: 64, child: BucketPhoto(visual: BucketVisual.of(b.image ?? b.title), height: 64)),
                                  const SizedBox(width: AppSpace.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(b.title, style: AppText.heading, maxLines: 2, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Text(
                                          [goal, if (b.cutoffAt != null) 'closes ${shortDayTimeR(b.cutoffAt!)}'].join(' · '),
                                          style: AppText.caption,
                                        ),
                                        const SizedBox(height: 6),
                                        const StatusPill('Live in the chat', tone: PillTone.brand),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpace.xl),
                            _next(Icons.group_add_outlined, 'Neighbours take their share', 'Each claim shows up live on the card.'),
                            _next(
                              b.settleMode == PayMode.atMarket ? Icons.storefront_outlined : Icons.lock_clock_outlined,
                              b.settleMode == PayMode.atMarket ? 'They book, pay at the market' : 'Money is held with UPI',
                              b.settleMode == PayMode.atMarket ? 'Nobody pays until you meet.' : 'Taken only if the bucket fills.',
                            ),
                            _next(Icons.receipt_long_outlined, 'Full bucket becomes an order', 'Everyone gets a pickup OTP.'),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(flex: 3),
                    FadeTransition(
                      opacity: rise,
                      child: Column(
                        children: [
                          Text('Opening your bucket in a moment', style: AppText.caption),
                          const SizedBox(height: AppSpace.lg),
                          AppButton(label: 'View bucket', onPressed: _finish),
                          const SizedBox(height: AppSpace.sm),
                          AppButton.ghost(
                            label: 'Open Street chat',
                            icon: Icons.forum_outlined,
                            onPressed: () {
                              _done = true;
                              _c.stop();
                              widget.onOpenChat();
                            },
                          ),
                          const SizedBox(height: AppSpace.lg),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _next(IconData icon, String title, String body) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Row(
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: AppColors.brandDeep),
      ),
      const SizedBox(width: AppSpace.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.label),
            Text(body, style: AppText.caption),
          ],
        ),
      ),
    ],
  ),
);

class _TickPainter extends CustomPainter {
  _TickPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final w = size.width;
    final path = Path()
      ..moveTo(w * 0.28, w * 0.52)
      ..lineTo(w * 0.44, w * 0.67)
      ..lineTo(w * 0.73, w * 0.37);
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * math.min(1, t));
    canvas.drawPath(
      drawn,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.085
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.t != t;
}
