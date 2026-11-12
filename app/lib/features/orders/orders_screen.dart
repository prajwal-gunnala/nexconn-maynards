import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/session/session_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import 'money_ui.dart';
import 'order_view.dart';

/// My orders: buckets that filled. Active (on the way) and Past (delivered).
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<OrderView>? _orders;
  String? _error;
  int? _tab;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiClient>();
    final me = context.read<SessionStore>().user?.id;
    try {
      final data = await api.get('/api/me/orders');
      final list = data is List
          ? data.whereType<Map>().map((m) => OrderView.fromJson(m.cast<String, dynamic>(), meId: me)).toList()
          : <OrderView>[];
      if (!mounted) return;
      setState(() {
        _orders = list;
        _error = null;
        _tab ??= list.any((o) => !o.isPast) || list.isEmpty ? 0 : 1;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = _orders;
    final active = orders?.where((o) => !o.isPast).toList() ?? const [];
    final past = orders?.where((o) => o.isPast).toList() ?? const [];
    final tab = _tab ?? 0;
    final shown = tab == 0 ? active : past;
    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: Column(children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.xs, AppSpace.gutter, AppSpace.md),
          child: Segmented(
            labels: [
              orders == null ? 'Active' : 'Active · ${active.length}',
              orders == null ? 'Past' : 'Past · ${past.length}',
            ],
            index: tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
        ),
        const Divider(),
        Expanded(
          child: _error != null && orders == null
              ? LoadFailed(message: _error!, onRetry: () {
                  setState(() => _error = null);
                  _load();
                })
              : orders == null
                  ? Pulse(
                      child: ListView(
                        padding: const EdgeInsets.all(AppSpace.gutter),
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (var i = 0; i < 3; i++)
                            Container(
                              margin: const EdgeInsets.only(bottom: AppSpace.md),
                              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: AppRadius.cardBorder,
                                border: Border.all(color: AppColors.line),
                              ),
                              child: const SkeletonRow(thumb: 72),
                            ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.brand,
                      onRefresh: _load,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: shown.isEmpty
                            ? ListView(key: ValueKey('empty$tab'), children: [
                                EmptyNote(
                                  icon: tab == 0 ? Icons.local_shipping_outlined : Icons.receipt_long_outlined,
                                  title: tab == 0 ? 'Nothing on the way' : 'No past orders yet',
                                  body: tab == 0
                                      ? 'When a bucket you joined fills, its order shows up here with your pickup OTP.'
                                      : 'Delivered orders and what you saved will be kept here.',
                                  action: 'Browse live buckets',
                                  onAction: () => context.go('/buckets'),
                                ),
                              ])
                            : ListView.separated(
                                key: ValueKey('list$tab'),
                                padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.lg, AppSpace.gutter, AppSpace.xxl),
                                itemCount: shown.length,
                                separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
                                itemBuilder: (_, i) => OrderCard(order: shown[i]),
                              ),
                      ),
                    ),
        ),
      ]),
    );
  }
}

/// Order row: photo, title, status, my amount + savings, pickup window.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order});
  final OrderView order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final me = o.myLine;
    final amountLabel = switch (me?.paymentStatus) {
      'due' => 'Pay at the market',
      'paid' => 'Paid at the market',
      'held' => 'Held',
      _ => o.isPast ? 'You paid' : 'Your share',
    };
    final members = o.lines.length;
    return Semantics(
      button: true,
      label: '${o.title}, order ${o.id}',
      child: InkWell(
        onTap: () => context.push('/orders/${o.id}'),
        borderRadius: AppRadius.cardBorder,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: AppColors.line),
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                PhotoThumb(imageKey: o.image ?? o.title, size: 76),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(o.title, style: AppText.heading, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      [
                        'Order ${o.id}',
                        if (members > 0) '$members ${members == 1 ? 'neighbour' : 'neighbours'}',
                        if (me != null) me.qtyLabel,
                      ].join(' · '),
                      style: AppText.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      o.statusPill(),
                      if (me?.collected == true) const _MiniTag(icon: Icons.verified_outlined, text: 'Collected'),
                    ]),
                  ]),
                ),
              ]),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.sm, AppSpace.md),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(amountLabel, style: AppText.caption),
                    const SizedBox(height: 2),
                    Text.rich(TextSpan(children: [
                      TextSpan(text: Fmt.rupees(me?.amount ?? o.total), style: AppText.price.copyWith(fontSize: 17, fontFeatures: tabular)),
                      if ((me?.savings ?? 0) > 0)
                        TextSpan(
                          text: '   Saved ${Fmt.rupees(me!.savings)}',
                          style: AppText.label.copyWith(color: AppColors.save, fontFeatures: tabular),
                        ),
                    ])),
                  ]),
                ),
                if (!o.isPast && me?.otp != null && me?.collected != true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(10)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('Pickup OTP', style: AppText.tiny.copyWith(color: AppColors.brandDeep)),
                      Text(
                        me!.otp!,
                        style: AppText.heading.copyWith(color: AppColors.brandDeep, letterSpacing: 3, fontFeatures: tabular),
                      ),
                    ]),
                  ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
              ]),
            ),
            if (o.pickupPoint != null || o.window != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 10),
                decoration: const BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.card)),
                ),
                child: Row(children: [
                  Icon(o.atMarket ? Icons.storefront_outlined : Icons.place_outlined, size: 16, color: AppColors.inkMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [
                        if (o.pickupPoint != null && o.pickupPoint!.isNotEmpty) (o.atMarket ? 'Meet at ${o.pickupPoint}' : 'Pickup at ${o.pickupPoint}'),
                        if (o.window != null && o.window!.isNotEmpty) o.window!,
                      ].join(' · '),
                      style: AppText.caption.copyWith(color: AppColors.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.chip)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: AppColors.save),
          const SizedBox(width: 4),
          Text(text, style: AppText.tiny.copyWith(color: AppColors.ink)),
        ]),
      );
}
