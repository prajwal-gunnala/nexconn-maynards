import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/models/models.dart';
import '../../core/session/session_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import 'money_ui.dart';
import 'order_view.dart';

/// Order detail: pickup OTP, status tracker, my money, every member's line, chat link.
class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  OrderView? _order;
  Bucket? _bucket;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiClient>();
    final me = context.read<SessionStore>().user?.id;
    try {
      final data = await api.get('/api/orders/${widget.orderId}');
      final o = OrderView.fromJson((data as Map).cast<String, dynamic>(), meId: me);
      Bucket? b;
      try {
        b = await api.bucket(o.bucketId);
      } on ApiException {
        b = null; // the order alone is enough to render
      }
      if (!mounted) return;
      setState(() {
        _order = o;
        _bucket = b;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    return Scaffold(
      appBar: AppBar(title: Text(o == null ? 'Order' : 'Order ${o.id}')),
      body: o == null
          ? (_error != null
              ? LoadFailed(message: _error!, onRetry: () {
                  setState(() => _error = null);
                  _load();
                })
              : const _OrderSkeleton())
          : RefreshIndicator(color: AppColors.brand, onRefresh: _load, child: _body(o)),
      bottomNavigationBar: o == null
          ? null
          : StickyCta(
              child: AppButton(
                label: 'Chat with buyers and vendor',
                icon: Icons.forum_outlined,
                onPressed: () => context.push('/chat/group/bucket_${o.bucketId}?title=${Uri.encodeComponent(o.title)}'),
              ),
            ),
    );
  }

  Widget _body(OrderView o) {
    final b = _bucket;
    final me = o.myLine;
    const gap = SizedBox(height: AppSpace.lg);
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpace.xxl),
      children: [
        _header(o),
        gap,
        if (me?.otp != null) ...[_OtpCard(order: o, line: me!, vendor: b?.vendor?.name), gap],
        if (o.atMarket) ...[_MeetCard(order: o, bucket: b), gap],
        _Tracker(order: o, vendor: b?.vendor?.name),
        gap,
        if (me != null) ...[_MyMoney(order: o, line: me, bucket: b), gap],
        _Members(order: o, meId: me?.userId),
      ],
    );
  }

  Widget _header(OrderView o) {
    final members = o.lines.length;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.sm, AppSpace.gutter, AppSpace.xl),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const StatusPill('Bucket full · order created', tone: PillTone.captured, icon: Icons.check_circle_outline),
            const SizedBox(height: AppSpace.md),
            Text(o.title, style: AppText.title.copyWith(fontSize: 22)),
            const SizedBox(height: AppSpace.xs),
            Text(
              [
                'Order ${o.id}',
                if (members > 0) '$members ${members == 1 ? 'neighbour' : 'neighbours'}',
                if (o.createdAt != null) Fmt.day(o.createdAt!).replaceAll(' ', '\u00A0'),
              ].join(' · '),
              style: AppText.bodyMuted,
            ),
          ]),
        ),
        const SizedBox(width: AppSpace.md),
        PhotoThumb(imageKey: o.image ?? o.title, size: 84),
      ]),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(AppSpace.lg), this.color = AppColors.surface, this.border = AppColors.line});
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color border;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
        padding: padding,
        decoration: BoxDecoration(color: color, borderRadius: AppRadius.cardBorder, border: Border.all(color: border)),
        child: child,
      );
}

class _OtpCard extends StatelessWidget {
  const _OtpCard({required this.order, required this.line, this.vendor});
  final OrderView order;
  final MemberLine line;
  final String? vendor;

  @override
  Widget build(BuildContext context) {
    final place = order.pickupPoint ?? 'the gate';
    if (line.collected) {
      return _Card(
        color: AppColors.saveTint,
        border: AppColors.saveTint,
        child: Row(children: [
          const CircleAvatar(radius: 20, backgroundColor: AppColors.save, child: Icon(Icons.check_rounded, color: Colors.white)),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Collected', style: AppText.heading.copyWith(color: AppColors.save)),
              Text('You picked this up at $place with OTP ${line.otp}.', style: AppText.caption.copyWith(color: AppColors.ink)),
            ]),
          ),
        ]),
      );
    }
    final digits = line.otp!.split('');
    return Semantics(
      label: 'Your pickup OTP is ${digits.join(' ')}. Show this at $place.',
      excludeSemantics: true,
      child: _Card(
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xl, AppSpace.lg, AppSpace.lg),
        border: AppColors.brand.withValues(alpha: 0.35),
        child: Column(children: [
          Text('YOUR PICKUP OTP', style: AppText.tiny.copyWith(letterSpacing: 1.2, color: AppColors.brandDeep)),
          const SizedBox(height: AppSpace.md),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < digits.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpace.sm),
              Container(
                width: 60,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(14)),
                child: Text(digits[i], style: AppText.display.copyWith(fontSize: 36, color: AppColors.brandDeep, fontFeatures: tabular)),
              ),
            ],
          ]),
          const SizedBox(height: AppSpace.lg),
          Text(
            order.atMarket ? 'Show this to ${vendor ?? 'the seller'} at $place' : 'Show this at $place',
            style: AppText.heading,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.xs),
          if (order.window != null && order.window!.isNotEmpty)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.schedule_rounded, size: 16, color: AppColors.inkMuted),
              const SizedBox(width: 4),
              Text(order.window!, style: AppText.bodyMuted),
            ]),
          const SizedBox(height: AppSpace.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
            decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(10)),
            child: Text(
              'The vendor enters it to hand over your ${line.qtyLabel}. Never share it in the chat.',
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
          ),
        ]),
      ),
    );
  }
}

class _MeetCard extends StatelessWidget {
  const _MeetCard({required this.order, this.bucket});
  final OrderView order;
  final Bucket? bucket;

  @override
  Widget build(BuildContext context) {
    final meet = bucket?.meet;
    final place = asStringOrNull(meet?['place']) ?? order.pickupPoint ?? 'the market';
    final at = asTime(meet?['at']);
    final note = asStringOrNull(meet?['note']);
    final vendor = bucket?.vendor;
    final due = order.myLine?.paymentStatus == 'due';
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 88,
          decoration: const BoxDecoration(
            color: Color(0xFFE3F0FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card - 1)),
          ),
          child: CustomPaint(painter: _MapPainter(), child: const Center(child: Icon(Icons.location_on, color: AppColors.brand, size: 36))),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Meet at the market', style: AppText.caption.copyWith(color: AppColors.brandDeep, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              [if (vendor?.place != null && !place.contains(vendor!.place!)) vendor.place!, place].join(', '),
              style: AppText.heading.copyWith(fontSize: 17),
            ),
            if (at != null) ...[
              const SizedBox(height: 2),
              Text(Fmt.dayTime(at), style: AppText.body),
            ],
            if (note != null) ...[
              const SizedBox(height: AppSpace.sm),
              Text(note, style: AppText.bodyMuted),
            ],
            if (order.myLine != null) ...[
              const SizedBox(height: AppSpace.md),
              Container(
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(color: due ? AppColors.brandTint : AppColors.saveTint, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(due ? Icons.payments_outlined : Icons.check_circle_outline, size: 20, color: due ? AppColors.brandDeep : AppColors.save),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      due
                          ? 'Pay ${Fmt.rupees(order.myLine!.amount)} to ${vendor?.name ?? 'the seller'} at the stall'
                          : 'Paid ${Fmt.rupees(order.myLine!.amount)} at the market',
                      style: AppText.label.copyWith(color: due ? AppColors.brandDeep : AppColors.save),
                    ),
                  ),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// A few soft "streets" behind the pin, so the meet card reads as a place.
class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, s.height * 0.62), Offset(s.width, s.height * 0.62), road);
    canvas.drawLine(Offset(s.width * 0.3, 0), Offset(s.width * 0.3, s.height), road);
    canvas.drawLine(Offset(s.width * 0.72, 0), Offset(s.width * 0.6, s.height), road..strokeWidth = 7);
    final block = Paint()..color = const Color(0xFFCFE3F2);
    canvas.drawRRect(RRect.fromLTRBR(s.width * 0.78, 10, s.width - 14, s.height * 0.5, const Radius.circular(8)), block);
    canvas.drawRRect(RRect.fromLTRBR(14, 10, s.width * 0.24, s.height * 0.5, const Radius.circular(8)), block);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Tracker extends StatelessWidget {
  const _Tracker({required this.order, this.vendor});
  final OrderView order;
  final String? vendor;

  @override
  Widget build(BuildContext context) {
    final labels = order.atMarket
        ? const ['Order created', 'Seller told', 'Bought', 'Collected']
        : const ['Order created', 'Sent to vendor', 'Packed', 'Delivered'];
    final at = switch (order.status) {
      OrderStatus.created || OrderStatus.unknown => 0,
      OrderStatus.sent => 1,
      OrderStatus.packed => 2,
      OrderStatus.delivered => 3,
    };
    final v = vendor ?? 'the vendor';
    final now = switch (at) {
      0 => order.atMarket ? 'Everyone has booked. See you at the market.' : 'Every member is in. $v gets the list next.',
      1 => order.atMarket ? '$v knows how much to keep aside.' : '$v has the packing list.',
      2 => order.atMarket ? 'Bought together. Collect your share.' : 'Packed by $v. On the way to ${order.pickupPoint ?? 'the gate'}.',
      _ => '${order.collectedCount} of ${order.lines.length} neighbours have collected.',
    };
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Order status', style: AppText.heading)),
          order.statusPill(),
        ]),
        const SizedBox(height: 2),
        Text(now, style: AppText.caption),
        const SizedBox(height: AppSpace.lg),
        Semantics(
          label: 'Step ${at + 1} of 4: ${labels[at]}',
          excludeSemantics: true,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Column(children: [
                  Row(children: [
                    Expanded(child: Container(height: 3, color: i == 0 ? Colors.transparent : (i <= at ? AppColors.save : AppColors.line))),
                    _dot(i, at),
                    Expanded(
                      child: Container(height: 3, color: i == labels.length - 1 ? Colors.transparent : (i < at ? AppColors.save : AppColors.line)),
                    ),
                  ]),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: AppText.tiny.copyWith(
                      color: i <= at ? AppColors.ink : AppColors.inkMuted,
                      fontWeight: i == at ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _dot(int i, int at) {
    if (i < at || (i == at && order.status == OrderStatus.delivered)) {
      return const CircleAvatar(radius: 12, backgroundColor: AppColors.save, child: Icon(Icons.check_rounded, size: 15, color: Colors.white));
    }
    if (i == at) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
          border: Border.all(color: AppColors.save, width: 3),
        ),
        child: const Center(child: CircleAvatar(radius: 4, backgroundColor: AppColors.save)),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface, border: Border.all(color: AppColors.line, width: 2)),
    );
  }
}

class _MyMoney extends StatelessWidget {
  const _MyMoney({required this.order, required this.line, this.bucket});
  final OrderView order;
  final MemberLine line;
  final Bucket? bucket;

  @override
  Widget build(BuildContext context) {
    final market = line.payMode == PayMode.atMarket;
    final held = line.heldAmount ?? bucket?.myShare?.hold?.amount ?? line.amount;
    final released = held - line.amount;
    Widget row(String label, int? amount, {TextStyle? style, Widget? trailing, String? text}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Text(label, style: AppText.bodyMuted)),
            ?trailing,
            if (trailing != null) const SizedBox(width: AppSpace.sm),
            Text(text ?? Fmt.rupees(amount ?? 0), style: (style ?? AppText.body).copyWith(fontFeatures: tabular)),
          ]),
        );
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('Your share', style: AppText.heading)),
          Text(line.qtyLabel, style: AppText.label.copyWith(color: AppColors.inkMuted)),
        ]),
        if (line.options.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(line.options.values.join(' · '), style: AppText.caption),
        ],
        const SizedBox(height: AppSpace.sm),
        if (market) ...[
          row('Held with UPI', null, text: 'Nothing, booked only', style: AppText.bodyMuted),
          row(line.paymentStatus == 'paid' ? 'Paid at the market' : 'Pay at the market', line.amount,
              style: AppText.body.copyWith(fontWeight: FontWeight.w800), trailing: line.pill()),
        ] else ...[
          row('Held with UPI', held),
          row('Paid', line.amount, style: AppText.body.copyWith(fontWeight: FontWeight.w800), trailing: line.pill()),
          if (released > 0) row('Released to you', released, style: AppText.body.copyWith(color: AppColors.released)),
        ],
        if (line.savings > 0) ...[
          const Padding(padding: EdgeInsets.symmetric(vertical: AppSpace.sm), child: Divider()),
          Row(children: [
            const Icon(Icons.savings_outlined, size: 20, color: AppColors.save),
            const SizedBox(width: AppSpace.sm),
            Expanded(child: Text('Saved vs shop price', style: AppText.heading.copyWith(fontSize: 15))),
            Text(Fmt.rupees(line.savings), style: AppText.price.copyWith(color: AppColors.save, fontFeatures: tabular)),
          ]),
        ],
      ]),
    );
  }
}

class _Members extends StatelessWidget {
  const _Members({required this.order, this.meId});
  final OrderView order;
  final String? meId;

  static const _avatarColors = [Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFF0EA5A4), Color(0xFFF59E0B), Color(0xFFEC4899), Color(0xFF10B981)];

  @override
  Widget build(BuildContext context) {
    final o = order;
    final lines = o.lines.isNotEmpty ? o.lines : [?o.myLine];
    if (lines.isEmpty) return const SizedBox.shrink();
    return _Card(
      padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(o.lines.length > 1 ? 'Everyone in this order' : 'Your line', style: AppText.heading)),
          if (o.lines.isNotEmpty) Text('${o.collectedCount} of ${o.lines.length} collected', style: AppText.caption),
        ]),
        const SizedBox(height: AppSpace.sm),
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const Divider(),
          _line(lines[i], i),
        ],
        const Divider(),
        const SizedBox(height: AppSpace.xs),
        _total('Order total', o.total, bold: true),
        if (o.heldTotal > 0) _total('Paid with UPI', o.heldTotal),
        if (o.atPickupTotal > 0)
          _total(
            o.lines.where((l) => l.payMode == PayMode.atMarket).every((l) => l.paymentStatus == 'paid')
                ? 'Paid at the market'
                : (o.atMarket ? 'Due at the market' : 'Pay at pickup'),
            o.atPickupTotal,
          ),
        const SizedBox(height: AppSpace.sm),
      ]),
    );
  }

  Widget _total(String label, int amount, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: bold ? AppText.label : AppText.bodyMuted)),
          Text(Fmt.rupees(amount), style: (bold ? AppText.heading : AppText.body).copyWith(fontFeatures: tabular)),
        ]),
      );

  Widget _line(MemberLine l, int i) {
    final mine = l.userId == meId;
    return Semantics(
      label: '${mine ? 'You' : l.name}, ${l.unit ?? ''}, ${l.qtyLabel}, ${Fmt.rupees(l.amount)}${l.collected ? ', collected' : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
        child: Row(children: [
          Stack(clipBehavior: Clip.none, children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: mine ? AppColors.brand : _avatarColors[i % _avatarColors.length].withValues(alpha: 0.15),
              child: Text(
                l.name.isEmpty ? '?' : l.name[0].toUpperCase(),
                style: AppText.label.copyWith(color: mine ? Colors.white : _avatarColors[i % _avatarColors.length], fontWeight: FontWeight.w800),
              ),
            ),
            if (l.collected)
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.surface, width: 1.5)),
                  child: const Icon(Icons.check_circle, size: 15, color: AppColors.save),
                ),
              ),
          ]),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: mine ? 'You' : l.name, style: AppText.label.copyWith(fontWeight: FontWeight.w700)),
                if (l.unit != null) TextSpan(text: '  ${l.unit}', style: AppText.caption),
              ])),
              const SizedBox(height: 2),
              Text(
                [l.qtyLabel, ...l.options.values, if (l.collected) 'collected'].join(' · '),
                style: AppText.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(Fmt.rupees(l.amount), style: AppText.label.copyWith(fontWeight: FontWeight.w800, fontFeatures: tabular)),
            const SizedBox(height: 4),
            l.pill(),
          ]),
        ]),
      ),
    );
  }
}

class _OrderSkeleton extends StatelessWidget {
  const _OrderSkeleton();

  @override
  Widget build(BuildContext context) => Pulse(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpace.gutter),
          children: const [
            SkeletonBox(width: 180, height: 22, radius: 999),
            SizedBox(height: AppSpace.md),
            SkeletonBox(width: 260, height: 26),
            SizedBox(height: AppSpace.sm),
            SkeletonBox(width: 200, height: 14),
            SizedBox(height: AppSpace.xxl),
            SkeletonBox(height: 220, radius: 16),
            SizedBox(height: AppSpace.lg),
            SkeletonBox(height: 120, radius: 16),
            SizedBox(height: AppSpace.lg),
            SkeletonBox(height: 160, radius: 16),
          ],
        ),
      );
}
