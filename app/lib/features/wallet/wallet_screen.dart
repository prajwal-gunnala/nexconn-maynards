import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import '../../core/session/session_store.dart';
import '../about/about_screen.dart';
import '../orders/money_ui.dart';
import '../orders/order_view.dart';

/// Wallet tab: savings hero, held / paid / released tiles, filterable money history.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, this.clock});

  /// Fixed "now" for screenshots; defaults to the wall clock.
  final DateTime Function()? clock;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

enum _Filter {
  all('All', null),
  held('Held', 'held'),
  paid('Paid', 'paid'),
  released('Released', 'released'),
  market('Market', 'at_market');

  const _Filter(this.label, this.kind);
  final String label;
  final String? kind;
}

class _WalletScreenState extends State<WalletScreen> {
  Wallet? _wallet;
  String? _error;

  /// My line per order id, to explain price drops ("Price dropped to ₹88/kg").
  Map<String, MemberLine> _myLines = const {};

  /// Live buckets behind held entries, to show when the price has since dropped.
  Map<String, Bucket> _heldBuckets = const {};
  _Filter _filter = _Filter.all;

  DateTime get _now => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiClient>();
    final me = context.read<SessionStore>().user?.id;
    try {
      final orders = _myOrderLines(api, me);
      final w = await api.wallet();
      final lines = await orders;
      final held = await _bucketsFor(api, w.entries.where((e) => e.kind == 'held').map((e) => e.bucketId).nonNulls.toSet());
      if (!mounted) return;
      setState(() {
        _wallet = w;
        _myLines = lines;
        _heldBuckets = held;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  /// Orders are optional here: without them the wallet still renders, just with less detail.
  static Future<Map<String, MemberLine>> _myOrderLines(ApiClient api, String? me) async {
    try {
      final data = await api.get('/api/me/orders');
      if (data is! List) return const {};
      return {
        for (final m in data.whereType<Map>())
          if (OrderView.fromJson(m.cast<String, dynamic>(), meId: me) case final o when o.myLine != null) o.id: o.myLine!,
      };
    } on ApiException {
      return const {};
    }
  }

  static Future<Map<String, Bucket>> _bucketsFor(ApiClient api, Set<String> ids) async {
    final out = <String, Bucket>{};
    await Future.wait(ids.map((id) async {
      try {
        out[id] = await api.bucket(id);
      } on ApiException {
        // optional detail
      }
    }));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final w = _wallet;
    return Scaffold(
      appBar: AppBar(
        title: Text('Wallet', style: AppText.title),
        actions: [
          IconButton(
            tooltip: 'About Jugaad Street',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => openAbout(context),
          ),
        ],
      ),
      body: w == null
          ? (_error != null
              ? LoadFailed(message: _error!, onRetry: () {
                  setState(() => _error = null);
                  _load();
                })
              : const _WalletSkeleton())
          : RefreshIndicator(color: AppColors.brand, onRefresh: _load, child: _body(w)),
    );
  }

  Widget _body(Wallet w) {
    final now = _now;
    final entries = [...w.entries]..sort((a, b) => (b.at ?? DateTime(0)).compareTo(a.at ?? DateTime(0)));
    final shown = _filter.kind == null ? entries : entries.where((e) => e.kind == _filter.kind).toList();
    bool thisMonth(WalletEntry e) => e.at != null && e.at!.toLocal().year == now.year && e.at!.toLocal().month == now.month;
    int count(String kind, {bool month = false}) => entries.where((e) => e.kind == kind && (!month || thisMonth(e))).length;
    // Tiles add up the same history the list shows (this year), so the numbers always agree.
    // "Released" includes the part of a hold given back when the price dropped.
    final year = entries.where((e) => e.at == null || e.at!.toLocal().year == now.year).toList();
    final paidTotal = year.where((e) => e.kind == 'paid').fold<int>(0, (a, e) => a + e.amount);
    final paidCount = year.where((e) => e.kind == 'paid').length;
    final refunds = year.where((e) => e.kind == 'released' || _backToBank(e) > 0).toList();
    final releasedTotal = refunds.fold<int>(0, (a, e) => a + (e.kind == 'released' ? e.amount : _backToBank(e)));
    final savedBuckets = entries.where((e) => asInt(e.raw['savings']) > 0).map((e) => e.bucketId ?? e.id).toSet().length;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpace.xxxl),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.sm, AppSpace.gutter, 0),
          child: _Hero(
            year: now.year,
            saved: w.savedTotal,
            savedThisMonth: w.savedThisMonth,
            buckets: savedBuckets,
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: Row(children: [
            Expanded(child: _Tile(label: 'Held', amount: w.heldNow, note: _buckets(count('held')), tone: PillTone.held, icon: Icons.lock_clock_outlined)),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: _Tile(
                label: 'Paid',
                amount: paidTotal,
                note: _buckets(paidCount),
                tone: PillTone.captured,
                icon: Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: _Tile(
                label: 'Released',
                amount: releasedTotal,
                note: refunds.isEmpty ? 'none' : '${refunds.length} back to bank',
                tone: PillTone.released,
                icon: Icons.undo_rounded,
              ),
            ),
          ]),
        ),
        const SizedBox(height: AppSpace.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: _OrdersLink(onTap: () => context.push('/orders')),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.xxl, AppSpace.gutter, AppSpace.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(header: true, child: Text('Money history', style: AppText.heading.copyWith(fontSize: 18))),
            const SizedBox(height: 2),
            Text('Held money is still yours until a bucket fills.', style: AppText.caption),
          ]),
        ),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter + AppSpace.lg, 0),
            itemCount: _Filter.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.sm),
            itemBuilder: (_, i) {
              final f = _Filter.values[i];
              final on = f == _filter;
              final n = f.kind == null ? entries.length : count(f.kind!);
              return Center(
                child: Semantics(
                  button: true,
                  selected: on,
                  child: InkWell(
                    key: Key('wallet-filter-${f.name}'),
                    onTap: () => setState(() => _filter = f),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: on ? AppColors.brand : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                        border: Border.all(color: on ? AppColors.brand : AppColors.line),
                      ),
                      child: Text(
                        n > 0 ? '${f.label}  $n' : f.label,
                        style: AppText.label.copyWith(color: on ? Colors.white : AppColors.ink),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: shown.isEmpty
              ? EmptyNote(
                  key: ValueKey('empty-${_filter.name}'),
                  icon: Icons.account_balance_wallet_outlined,
                  title: switch (_filter) {
                    _Filter.all => 'Nothing here yet',
                    _Filter.held => 'No money held right now',
                    _Filter.paid => 'No payments yet',
                    _Filter.released => 'Nothing released',
                    _Filter.market => 'No market bookings',
                  },
                  body: _filter == _Filter.all
                      ? 'Take a share in a bucket and the money held, paid and released shows up here.'
                      : 'Entries show up here as your buckets fill or close.',
                  action: _filter == _Filter.all ? 'Browse live buckets' : null,
                  onAction: () => context.go('/buckets'),
                )
              : Container(
                  key: ValueKey('list-${_filter.name}'),
                  margin: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.cardBorder,
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(children: [
                    for (var i = 0; i < shown.length; i++) ...[
                      if (i > 0) const Divider(),
                      _EntryRow(
                        entry: shown[i],
                        myLine: _myLines[asStringOrNull(shown[i].raw['orderId'])],
                        bucket: shown[i].kind == 'held' ? _heldBuckets[shown[i].bucketId] : null,
                      ),
                    ],
                  ]),
                ),
        ),
      ],
    );
  }

  /// Part of a hold given back after the bucket filled at a lower price.
  static int _backToBank(WalletEntry e) {
    final held = asIntOrNull(e.raw['heldAmount']);
    return e.kind == 'paid' && held != null && held > e.amount ? held - e.amount : 0;
  }

  static String _buckets(int n) => n == 0 ? 'none' : '$n ${n == 1 ? 'bucket' : 'buckets'}';
}

class _Hero extends StatelessWidget {
  const _Hero({required this.year, required this.saved, required this.savedThisMonth, required this.buckets});
  final int year;
  final int saved;
  final int savedThisMonth;
  final int buckets;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Saved with neighbours in $year: ${Fmt.rupees(saved)} across $buckets buckets',
      excludeSemantics: true,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.brand, AppColors.brandDeep],
          ),
        ),
        child: Stack(children: [
          Positioned(right: -36, top: -40, child: _ring(150)),
          Positioned(right: 40, bottom: -60, child: _ring(110)),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.xl, AppSpace.xl, AppSpace.xl),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Saved with neighbours this year', style: AppText.label.copyWith(color: Colors.white.withValues(alpha: 0.85))),
              const SizedBox(height: AppSpace.xs),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: saved.toDouble()),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => Text(
                  Fmt.rupees(v),
                  style: AppText.display.copyWith(fontSize: 38, color: Colors.white, fontFeatures: tabular),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                saved == 0 ? 'Join a bucket with neighbours to start saving' : 'across $buckets ${buckets == 1 ? 'bucket' : 'buckets'}',
                style: AppText.body.copyWith(color: Colors.white.withValues(alpha: 0.85)),
              ),
              if (savedThisMonth > 0) ...[
                const SizedBox(height: AppSpace.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(AppRadius.chip)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.trending_up_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text('${Fmt.rupees(savedThisMonth)} this month', style: AppText.tiny.copyWith(color: Colors.white, fontFeatures: tabular)),
                  ]),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _ring(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 18)),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.amount, required this.note, required this.tone, required this.icon});
  final String label;
  final int amount;
  final String note;
  final PillTone tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PillTone.held => (AppColors.heldTint, AppColors.held),
      PillTone.captured => (AppColors.saveTint, AppColors.save),
      _ => (AppColors.releasedTint, AppColors.released),
    };
    return Semantics(
      label: '$label ${Fmt.rupees(amount)}, $note',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.cardBorder, border: Border.all(color: AppColors.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: fg),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(label, style: AppText.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(Fmt.rupees(amount), style: AppText.price.copyWith(fontFeatures: tabular)),
          ),
          Text(note, style: AppText.tiny.copyWith(fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _OrdersLink extends StatelessWidget {
  const _OrdersLink({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardBorder,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.md),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.cardBorder, border: Border.all(color: AppColors.line)),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.receipt_long_outlined, color: AppColors.brandDeep, size: 20),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('My orders', style: AppText.heading.copyWith(fontSize: 15)),
                Text('Pickup OTPs, status and everyone in the order', style: AppText.caption),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
          ]),
        ),
      );
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, this.myLine, this.bucket});
  final WalletEntry entry;

  /// The live bucket for a held entry, when known.
  final Bucket? bucket;

  /// "now ₹400/flat" when the bucket's current price is below what was held.
  String? get _priceNow {
    final b = bucket;
    final p = b?.unitPrice;
    if (b == null || p == null || entry.kind != 'held') return null;
    final qty = b.myShare?.qty ?? 1;
    if (qty <= 0 || p * qty >= entry.amount) return null;
    return '${Fmt.rupees(p)}/${b.unitLabel ?? 'unit'}';
  }

  /// My line in the entry's order, when known: gives the final unit price.
  final MemberLine? myLine;

  /// "₹88/kg" from "10 kg" and ₹880; null for parts like "Tail half".
  String? get _unitPrice {
    final l = myLine;
    if (l == null) return null;
    final parts = l.qtyLabel.trim().split(RegExp(r'\s+'));
    final qty = parts.isEmpty ? null : num.tryParse(parts.first);
    if (qty == null || qty <= 0 || parts.length < 2) return null;
    return '${Fmt.rupees((l.amount / qty).round())}/${parts.sublist(1).join(' ')}';
  }

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final orderId = asStringOrNull(e.raw['orderId']);
    final savings = asInt(e.raw['savings']);
    final heldAmount = asIntOrNull(e.raw['heldAmount']);
    final image = asStringOrNull(e.raw['image']) ?? e.title;
    final back = e.kind == 'paid' && heldAmount != null && heldAmount > e.amount ? heldAmount - e.amount : 0;
    final pill = switch (e.kind) {
      'held' => const StatusPill('Held', tone: PillTone.held, icon: Icons.lock_clock_outlined),
      'paid' => const StatusPill('Paid', tone: PillTone.captured, icon: Icons.check_circle_outline),
      'released' => const StatusPill('Released', tone: PillTone.released, icon: Icons.undo),
      'at_market' => const StatusPill('At market', tone: PillTone.brand, icon: Icons.storefront_outlined),
      _ => StatusPill(e.kind),
    };
    final sub = [
      if (e.at != null) Fmt.day(e.at!),
      if (orderId != null) 'Order $orderId',
      if (e.kind == 'held') 'until it fills',
      if (e.kind == 'released') 'back in your bank',
    ].join(' · ');
    return Semantics(
      button: true,
      label: '${e.title}, ${Fmt.rupees(e.amount)}, ${pill.label}${savings > 0 ? ', saved ${Fmt.rupees(savings)}' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () {
          if (orderId != null) {
            context.push('/orders/$orderId');
          } else if (e.bucketId != null) {
            context.push('/bucket/${e.bucketId}');
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
          child: Row(children: [
            PhotoThumb(imageKey: image, size: 52),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.title, style: AppText.label.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(sub, style: AppText.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (_priceNow != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${Fmt.rupees(e.amount)} held · now $_priceNow. You pay the lower price',
                    style: AppText.caption.copyWith(color: AppColors.save, fontWeight: FontWeight.w600, fontFeatures: tabular),
                    maxLines: 2,
                  ),
                ],
                if (back > 0 || savings > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    back > 0
                        ? '${_unitPrice == null ? 'Final price was lower' : 'Price dropped to $_unitPrice'} · ${Fmt.rupees(back)} back to your bank'
                        : 'Saved ${Fmt.rupees(savings)} vs shop price',
                    style: AppText.caption.copyWith(color: AppColors.save, fontWeight: FontWeight.w600, fontFeatures: tabular),
                    maxLines: 2,
                  ),
                ],
              ]),
            ),
            const SizedBox(width: AppSpace.sm),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                Fmt.rupees(e.amount),
                style: AppText.label.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: tabular,
                  color: e.kind == 'released' ? AppColors.released : AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              pill,
            ]),
          ]),
        ),
      ),
    );
  }
}

class _WalletSkeleton extends StatelessWidget {
  const _WalletSkeleton();

  @override
  Widget build(BuildContext context) => Pulse(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpace.gutter),
          children: [
            const SkeletonBox(height: 150, radius: 20),
            const SizedBox(height: AppSpace.md),
            const Row(children: [
              Expanded(child: SkeletonBox(height: 104, radius: 16)),
              SizedBox(width: AppSpace.sm),
              Expanded(child: SkeletonBox(height: 104, radius: 16)),
              SizedBox(width: AppSpace.sm),
              Expanded(child: SkeletonBox(height: 104, radius: 16)),
            ]),
            const SizedBox(height: AppSpace.xxl),
            for (var i = 0; i < 4; i++) const SkeletonRow(),
          ],
        ),
      );
}
