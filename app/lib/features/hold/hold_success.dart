import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/models/models.dart';
import '../../core/session/session_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import '../bucket/bucket_detail_screen.dart' show inviteText, meetPeople;
import '../bucket/detail_meet.dart';
import '../bucket/detail_model.dart';
import '../bucket/detail_widgets.dart';

/// Animated check: the circle pops in, then the tick draws itself.
class AnimatedCheck extends StatelessWidget {
  const AnimatedCheck({super.key, this.size = 88, this.color = AppColors.save});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      builder: (context, t, _) {
        final pop = Curves.elasticOut.transform(math.min(1, t / 0.6));
        final draw = Curves.easeOutCubic.transform(((t - 0.35) / 0.65).clamp(0.0, 1.0));
        return SizedBox(
          width: size + 32,
          height: size + 32,
          child: Stack(alignment: Alignment.center, children: [
            Container(
              width: (size + 32) * pop.clamp(0.0, 1.2),
              height: (size + 32) * pop.clamp(0.0, 1.2),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            ),
            Transform.scale(
              scale: pop,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: CustomPaint(painter: _TickPainter(draw)),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _TickPainter extends CustomPainter {
  _TickPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()
      ..moveTo(s.width * 0.28, s.height * 0.52)
      ..lineTo(s.width * 0.44, s.height * 0.67)
      ..lineTo(s.width * 0.73, s.height * 0.36);
    final m = path.computeMetrics().first;
    canvas.drawPath(
      m.extractPath(0, m.length * t),
      Paint()
        ..color = Colors.white
        ..strokeWidth = s.width * 0.085
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.t != t;
}

/// "₹960 held" confirmation with what happens next and an invite nudge.
class HoldSuccessView extends StatelessWidget {
  const HoldSuccessView({super.key, required this.view, required this.share, required this.vpa});

  final BucketView view;
  final Share share;
  final String vpa;

  @override
  Widget build(BuildContext context) {
    final b = view.bucket;
    final p = b.progress;
    final unit = b.unitLabel ?? 'share';
    final amount = share.hold?.amount ?? share.estAmount;
    final filled = b.status != BucketStatus.live;
    final left = math.max(0, p.target - p.filled);
    final next = p.nextTier;

    final String status = switch (b.type) {
      BucketType.split => '${fmtQty(p.filled)} of ${plural(p.target, unit)} taken',
      BucketType.trip => '${fmtQty(p.filled)} of ${fmtQty(p.target)} kg booked',
      _ => '${fmtQty(p.filled)} of ${plural(p.target, unit)}',
    };
    final String closesSub = [
      if (b.cutoffAt != null) shortWhen(b.cutoffAt!).replaceFirstMapped(RegExp(r'^\w'), (m) => m[0]!.toUpperCase()),
      if (next != null) '${plural(next.remaining, unit)} to ${Fmt.rupees(next.unitPrice)}/$unit',
      if (next == null && b.type == BucketType.split && left > 0) '${plural(left, unit)} still open',
    ].join(' · ');
    final deliverTitle = b.type == BucketType.service ? 'Team visits ${b.pickupPoint?.toLowerCase() ?? 'your flat'}' : 'Delivered to ${b.pickupPoint ?? 'your gate'}';
    final deliverSub = [
      if (b.deliverAt != null) Fmt.dayTime(b.deliverAt!),
      if (b.type != BucketType.service) 'show your OTP',
    ].join(' · ');

    final String goTitle;
    final String goSub;
    if (next != null) {
      goTitle = '${plural(next.remaining, unit)} to go';
      goSub = 'Invite neighbours so everyone pays ${Fmt.rupees(next.unitPrice)}/$unit. Your hold drops with it.';
    } else if (b.type == BucketType.split) {
      goTitle = '${plural(left, unit)} to go';
      goSub = 'The fish is cut once every part is taken. Invite neighbours to fill it faster.';
    } else if (b.type == BucketType.trip) {
      goTitle = '${fmtQty(left)} kg of space left';
      goSub = 'More on the tempo means a smaller transport share for everyone.';
    } else {
      goTitle = '${plural(left, unit)} to go';
      goSub = 'Invite neighbours to fill it faster.';
    }

    void copy() {
      Clipboard.setData(ClipboardData(text: inviteText(view)));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Invite copied. Paste it in your block group.')));
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.xxl, AppSpace.gutter, AppSpace.xxl), children: [
          const Center(child: AnimatedCheck()),
          const SizedBox(height: AppSpace.lg),
          Center(child: Text('${Fmt.rupees(amount)} held', style: AppText.display.copyWith(fontSize: 32).tab)),
          const SizedBox(height: AppSpace.xs),
          Center(child: Text('${b.title} · $status', style: AppText.bodyMuted, textAlign: TextAlign.center)),
          const SizedBox(height: AppSpace.xs),
          Center(
            child: Text('Blocked in your bank, not paid', style: AppText.label.copyWith(color: AppColors.held)),
          ),
          const SizedBox(height: AppSpace.xxl),
          DetailCard(
            child: Column(children: [
              TimelineStep(done: true, title: 'Held in your bank', sub: 'Just now · from $vpa'),
              TimelineStep(
                n: '2',
                title: filled ? 'Bucket full, order sent' : 'Bucket closes',
                sub: filled ? 'Order ${b.orderId ?? ''} · charged at the final price' : closesSub,
                done: filled,
              ),
              TimelineStep(n: '3', title: deliverTitle, sub: deliverSub, last: true),
            ]),
          ),
          const SizedBox(height: AppSpace.md),
          if (!filled)
            DetailCard(
              color: AppColors.brandTint,
              borderColor: Colors.transparent,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.group_add_outlined, color: AppColors.brandDeep),
                  const SizedBox(width: AppSpace.sm),
                  Text(goTitle, style: AppText.heading.copyWith(color: AppColors.brandDeep)),
                ]),
                const SizedBox(height: AppSpace.xs),
                Text(goSub, style: AppText.body.copyWith(color: AppColors.brandDeep.withValues(alpha: 0.85))),
                const SizedBox(height: AppSpace.md),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: copy,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandDeep,
                      backgroundColor: AppColors.surface,
                      side: const BorderSide(color: AppColors.brand),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: Text('Copy invite for neighbours', style: AppText.label.copyWith(color: AppColors.brandDeep, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            )
          else
            DetailCard(
              color: AppColors.saveTint,
              borderColor: Colors.transparent,
              child: Row(children: [
                const Icon(Icons.celebration_outlined, color: AppColors.save),
                const SizedBox(width: AppSpace.md),
                Expanded(child: Text('Your share filled the bucket. Everyone is charged the final price now.', style: AppText.label)),
              ]),
            ),
        ]),
      ),
      bottomNavigationBar: StickyCta(
        child: Row(children: [
          Expanded(child: AppButton.ghost(label: 'View bucket', onPressed: () => context.canPop() ? context.pop() : context.go('/bucket/${b.id}'))),
          const SizedBox(width: AppSpace.md),
          Expanded(child: AppButton(label: 'Back to Street', onPressed: () => context.go('/street'))),
        ]),
      ),
    );
  }
}

/// One row of a vertical timeline (✓ done, or a numbered circle).
class TimelineStep extends StatelessWidget {
  const TimelineStep({super.key, this.n = '', required this.title, required this.sub, this.done = false, this.last = false});

  final String n;
  final String title;
  final String sub;
  final bool done;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done ? AppColors.save : AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: done ? AppColors.save : AppColors.line, width: 1.5),
            ),
            child: done
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : Text(n, style: AppText.label.copyWith(color: AppColors.inkMuted, fontWeight: FontWeight.w800)),
          ),
          if (!last)
            Expanded(
              child: Container(width: 2, color: done ? AppColors.save.withValues(alpha: 0.4) : AppColors.line, margin: const EdgeInsets.symmetric(vertical: 3)),
            ),
        ]),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 3, bottom: last ? 0 : AppSpace.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.heading.copyWith(fontSize: 15)),
              if (sub.isNotEmpty) ...[const SizedBox(height: 2), Text(sub, style: AppText.caption.tab)],
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Book-and-meet confirmation: no PIN, meet card instead.
class BookedView extends StatelessWidget {
  const BookedView({super.key, required this.view, required this.share});

  final BucketView view;
  final Share share;

  @override
  Widget build(BuildContext context) {
    final b = view.bucket;
    final session = context.read<SessionStore>();
    final unit = b.unitLabel ?? 'share';
    final picked = b.units.where((u) => share.unitIds.contains(u.id)).toList();
    final what = picked.isEmpty ? 'your $unit' : picked.map((u) => u.label.toLowerCase()).join(' + ');
    final grams = picked.fold<int>(0, (s, u) => s + (u.grams ?? 0));
    final organiser = b.createdBy?.name;
    final place = view.x.meetPlace ?? b.pickupPoint ?? 'the gate';
    final market = (b.vendor?.place ?? 'Market').replaceAll(' Harbour', ' Fish Market');
    final full = b.progress.filled >= b.progress.target && b.progress.target > 0;
    final chat = session.streetChannelId;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: () => context.canPop() ? context.pop() : context.go('/bucket/${b.id}'),
        ),
        actions: const [
          Padding(padding: EdgeInsets.only(right: AppSpace.gutter), child: StatusPill('Booked', tone: PillTone.captured, icon: Icons.check_rounded)),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.sm, AppSpace.gutter, AppSpace.xxl), children: [
        Text('You booked the $what', style: AppText.title.copyWith(fontSize: 24)),
        const SizedBox(height: AppSpace.xs),
        Text(
          [
            if (organiser != null) "$organiser's bucket",
            if (grams > 0) 'about ${(grams / 1000).toStringAsFixed(grams % 1000 == 0 ? 0 : 2)} kg',
            'pay at the market',
          ].join(' · '),
          style: AppText.bodyMuted,
        ),
        const SizedBox(height: AppSpace.xl),
        MeetCard(
          place: place,
          market: market,
          at: view.x.meetAt ?? b.deliverAt,
          note: view.x.meetNote,
          people: meetPeople(view, session.user?.id),
        ),
        const SizedBox(height: AppSpace.md),
        DetailCard(
          child: Column(children: [
            Row(children: [
              Expanded(child: Text('Your share', style: AppText.label.copyWith(color: AppColors.inkMuted))),
              Text('≈ ${Fmt.rupees(share.estAmount)}', style: AppText.price.tab),
            ]),
            const SizedBox(height: AppSpace.xs),
            Row(children: [
              Expanded(
                child: Text(
                  'Pay ${b.vendor?.name.split(' ').first ?? 'the vendor'} at the stall, cash or UPI. Nothing was charged now.',
                  style: AppText.caption,
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: AppSpace.md),
        DetailCard(
          color: full ? AppColors.saveTint : AppColors.brandTint,
          borderColor: Colors.transparent,
          child: Row(children: [
            Icon(full ? Icons.check_circle_outline_rounded : Icons.hourglass_top_rounded, color: full ? AppColors.save : AppColors.brandDeep),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Text(
                full
                    ? 'Every ${unit.toLowerCase()} is booked. "I\'m here" check-in opens on the bucket page on market day.'
                    : '${plural(b.progress.target - b.progress.filled, unit)} still open. It goes ahead once all are booked.',
                style: AppText.label,
              ),
            ),
          ]),
        ),
      ]),
      bottomNavigationBar: StickyCta(
        child: Row(children: [
          if (chat != null) ...[
            Expanded(
              child: AppButton.ghost(
                label: 'Message',
                icon: Icons.chat_bubble_outline_rounded,
                onPressed: () => context.push('/chat/group/$chat?title=${Uri.encodeComponent(session.community?.name ?? 'Street')}'),
              ),
            ),
            const SizedBox(width: AppSpace.md),
          ],
          Expanded(child: AppButton(label: 'Back to Street', onPressed: () => context.go('/street'))),
        ]),
      ),
    );
  }
}
