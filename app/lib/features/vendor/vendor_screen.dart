import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/images.dart';
import '../../core/models/models.dart';
import '../../core/nexconn/chat_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import '../chat/chat_avatar.dart';
import '../chat/chat_directory.dart';
import 'handover_screen.dart';
import 'vendor_models.dart';

/// "Sea Breeze Towers" → "Sea Breeze".
String shortCommunityName(String name) {
  final street = ChatDirectory.streetTitle(name);
  return street.endsWith(' Street') ? street.substring(0, street.length - 7) : name;
}

/// Vendor: today — demand held, today's buckets, packing list, handover.
class VendorScreen extends StatefulWidget {
  const VendorScreen({super.key});

  @override
  State<VendorScreen> createState() => _VendorScreenState();
}

class _VendorScreenState extends State<VendorScreen> {
  late Future<VendorDashboard> _future = _load();

  Future<VendorDashboard> _load() async {
    final api = context.read<ApiClient>();
    final d = VendorDashboard.fromJson(await api.vendorDashboard());
    if (mounted) {
      final dir = ChatDirectory.of(context);
      for (final id in {for (final b in d.buckets) b.communityId}) {
        dir.community(id);
      }
    }
    return d;
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() {
      _future = f;
    });
    await f;
  }

  Future<void> _openHandover(String orderId, String communityName) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => HandoverScreen(orderId: orderId, communityName: communityName),
    ));
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      // Zero-height bar: keeps a white strip under the status bar while the page scrolls.
      appBar: AppBar(toolbarHeight: 0, backgroundColor: AppColors.surface, scrolledUnderElevation: 0),
      body: FutureBuilder<VendorDashboard>(
        future: _future,
        builder: (context, s) {
          if (s.hasError) {
            final msg = s.error is ApiException ? (s.error as ApiException).message : 'Something went wrong.';
            return _ErrorState(message: msg, onRetry: _refresh);
          }
          final d = s.data;
          if (d == null) return const Center(child: CircularProgressIndicator());
          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(slivers: [
              SliverToBoxAdapter(child: _Header(d: d)),
              SliverToBoxAdapter(child: _HeldHero(d: d)),
              if (d.packing.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: SectionHeader('Hand over at the gate', subtitle: 'Enter each buyer’s OTP to release payment'),
                ),
                SliverList.list(children: [
                  for (final g in d.packing)
                    for (final e in g.byOrder.entries)
                      _HandoverTile(
                        title: e.value.first.title ?? 'Order ${e.key}',
                        orderId: e.key,
                        community: shortCommunityName(g.communityName),
                        lines: e.value,
                        onTap: () => _openHandover(e.key, g.communityName),
                      ),
                ]),
              ],
              SliverToBoxAdapter(
                child: SectionHeader(
                  'Today’s buckets',
                  subtitle: d.live.isEmpty ? 'Nothing live right now' : '${d.live.length} live · demand updates as neighbours join',
                ),
              ),
              SliverList.list(children: [for (final b in d.buckets) _BucketRow(bucket: b)]),
              const SliverToBoxAdapter(
                child: SectionHeader('Packing list', subtitle: 'Grouped by community, one bag per flat'),
              ),
              if (d.packing.isEmpty)
                const SliverToBoxAdapter(child: _EmptyPacking())
              else
                SliverList.list(children: [for (final g in d.packing) _PackingCard(group: g)]),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpace.xxxl)),
            ]),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.d});
  final VendorDashboard d;

  @override
  Widget build(BuildContext context) {
    final v = d.vendor;
    final canPop = Navigator.of(context).canPop();
    return Container(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.sm, AppSpace.gutter, AppSpace.lg),
          child: Row(children: [
            if (canPop)
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            else
              const SizedBox(width: AppSpace.md),
            ChatAvatar(id: v.id, name: v.name, kind: 'vendor', size: 48),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(v.name, style: AppText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  if (v.rating != null) ...[
                    const Icon(Icons.star_rounded, size: 16, color: AppColors.held),
                    const SizedBox(width: 2),
                    Text(v.rating!.toStringAsFixed(1), style: AppText.label),
                    Text('  ·  ', style: AppText.caption),
                  ],
                  Flexible(
                    child: Text(v.place ?? 'Vendor', style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ]),
            ),
            if (!canPop)
              IconButton(
                tooltip: 'Sign out',
                icon: const Icon(Icons.logout_rounded),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Sign out?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sign out')),
                      ],
                    ),
                  );
                  if (ok == true && context.mounted) await context.read<ChatSession>().signOut();
                },
              ),
          ]),
        ),
      ),
    );
  }
}

class _HeldHero extends StatelessWidget {
  const _HeldHero({required this.d});
  final VendorDashboard d;

  @override
  Widget build(BuildContext context) {
    final households = d.liveHouseholds;
    final communities = d.communities;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.lg, AppSpace.gutter, 0),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.xl),
        decoration: BoxDecoration(
          borderRadius: AppRadius.cardBorder,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.brand, AppColors.brandDeep],
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.lock_clock_rounded, size: 18, color: Colors.white),
            const SizedBox(width: AppSpace.sm),
            Expanded(child: Text('Demand held for you', style: AppText.label.copyWith(color: Colors.white))),
            Text(Fmt.day(DateTime.now()), style: AppText.tiny.copyWith(color: Colors.white.withValues(alpha: 0.85))),
          ]),
          const SizedBox(height: AppSpace.sm),
          Semantics(
            label: 'Demand held ${Fmt.rupees(d.heldDemand)}',
            excludeSemantics: true,
            child: Text(Fmt.rupees(d.heldDemand), style: AppText.display.copyWith(color: Colors.white, fontSize: 36)),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            households == 0
                ? 'No live buckets right now'
                : 'from $households households in $communities ${communities == 1 ? 'community' : 'communities'}',
            style: AppText.body.copyWith(color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: AppSpace.lg),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.verified_user_outlined, size: 16, color: Colors.white),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  'Paid to you at handover, after each buyer\u2019s OTP.',
                  style: AppText.caption.copyWith(color: Colors.white),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _HandoverTile extends StatelessWidget {
  const _HandoverTile({
    required this.title,
    required this.orderId,
    required this.community,
    required this.lines,
    required this.onTap,
  });

  final String title;
  final String orderId;
  final String community;
  final List<PackLine> lines;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = lines.where((l) => l.collected).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, AppSpace.md),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder, side: const BorderSide(color: AppColors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.qr_code_2_rounded, color: AppColors.brand),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: AppText.heading, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('$orderId · $community', style: AppText.caption),
                  const SizedBox(height: AppSpace.sm),
                  AppProgressBar(value: lines.isEmpty ? 0 : done / lines.length, color: AppColors.save, height: 6),
                  const SizedBox(height: AppSpace.xs),
                  Text('$done of ${lines.length} collected', style: AppText.tiny),
                ]),
              ),
              const SizedBox(width: AppSpace.sm),
              const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
            ]),
          ),
        ),
      ),
    );
  }
}

class _BucketRow extends StatelessWidget {
  const _BucketRow({required this.bucket});
  final Bucket bucket;

  static StatusPill pill(BucketStatus s) => switch (s) {
        BucketStatus.live => const StatusPill('Live', tone: PillTone.brand),
        BucketStatus.ordered => const StatusPill('Locked · pack it', tone: PillTone.captured),
        BucketStatus.marketDay => const StatusPill('Market day', tone: PillTone.brand),
        BucketStatus.delivering => const StatusPill('Handing over', tone: PillTone.held),
        BucketStatus.completed => const StatusPill('Delivered', tone: PillTone.captured),
        BucketStatus.expired => const StatusPill('Expired', tone: PillTone.released),
        BucketStatus.cancelled => const StatusPill('Cancelled', tone: PillTone.released),
        BucketStatus.unknown => const StatusPill('—'),
      };

  @override
  Widget build(BuildContext context) {
    final b = bucket;
    final p = b.progress;
    final unit = b.unitLabel ?? 'kg';
    final dir = ChatDirectory.of(context);
    String n(num v) => v == v.roundToDouble() ? Fmt.number(v.round()) : v.toStringAsFixed(1);
    final photo = AppImages.bucket(b.image);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, AppSpace.md),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder, side: const BorderSide(color: AppColors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/bucket/${b.id}'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: AppRadius.photoBorder,
                child: SizedBox.square(
                  dimension: 64,
                  child: photo == null
                      ? Container(color: AppColors.brandTint, child: const Icon(Icons.inventory_2_outlined, color: AppColors.brandDeep))
                      : Image.asset(photo, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Text(b.title, style: AppText.heading.copyWith(fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: AppSpace.sm),
                    pill(b.status),
                  ]),
                  const SizedBox(height: 2),
                  ListenableBuilder(
                    listenable: dir,
                    builder: (context, _) {
                      final c = dir.communityNow(b.communityId);
                      return Text(
                        [
                          if (c != null) shortCommunityName(c.name),
                          if (b.status.isOpen && b.cutoffAt != null) 'closes ${Fmt.time(b.cutoffAt!)}',
                          if (!b.status.isOpen && b.orderId != null) b.orderId!,
                        ].join(' · '),
                        style: AppText.caption,
                      );
                    },
                  ),
                  const SizedBox(height: AppSpace.sm),
                  AppProgressBar(value: p.fraction, height: 6, color: b.status.isOpen ? AppColors.brand : AppColors.save),
                  const SizedBox(height: AppSpace.xs),
                  Row(children: [
                    Expanded(
                      child: Text('${n(p.filled)} of ${n(p.target)} $unit · ${p.members} households', style: AppText.tiny),
                    ),
                    if (b.status.isOpen && p.held > 0)
                      Text('${Fmt.rupees(p.held)} held', style: AppText.tiny.copyWith(color: AppColors.held, fontWeight: FontWeight.w700)),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PackingCard extends StatelessWidget {
  const _PackingCard({required this.group});
  final PackingGroup group;

  @override
  Widget build(BuildContext context) {
    final orders = group.byOrder;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, AppSpace.md),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(color: AppColors.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.sm),
            child: Row(children: [
              const Icon(Icons.apartment_rounded, size: 18, color: AppColors.brand),
              const SizedBox(width: AppSpace.sm),
              Expanded(child: Text(group.communityName, style: AppText.heading)),
              Text('${group.lines.length} bags', style: AppText.caption),
            ]),
          ),
          for (final e in orders.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xs),
              child: Text(
                '${e.value.first.title ?? 'Order'} · ${e.key}'.toUpperCase(),
                style: AppText.tiny.copyWith(letterSpacing: 0.4),
              ),
            ),
            for (final l in e.value) PackLineRow(line: l),
          ],
          const SizedBox(height: AppSpace.sm),
        ]),
      ),
    );
  }
}

/// `B-1204  Ananya          10 kg` with options under the name.
class PackLineRow extends StatelessWidget {
  const PackLineRow({super.key, required this.line, this.selected = false, this.onTap});

  final PackLine line;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = line;
    return Semantics(
      selected: selected,
      button: onTap != null,
      label: '${l.unit ?? ''} ${l.name}, ${l.qtyLabel}${l.collected ? ', collected' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
          color: selected ? AppColors.brandTint : null,
          child: Row(children: [
            Container(
              width: 64,
              padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: l.collected ? AppColors.saveTint : AppColors.canvas,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l.unit ?? '—',
                style: AppText.label.copyWith(fontWeight: FontWeight.w800, color: l.collected ? AppColors.save : AppColors.ink),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  l.name,
                  style: AppText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: l.collected ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.inkMuted,
                    color: l.collected ? AppColors.inkMuted : AppColors.ink,
                  ),
                ),
                if (l.options.isNotEmpty || l.payMode == PayMode.atMarket)
                  Text(
                    [
                      if (l.options.isNotEmpty) l.optionsText,
                      if (l.payMode == PayMode.atMarket) 'Collect ${Fmt.rupees(l.amount)} at pickup',
                    ].join(' · '),
                    style: AppText.caption,
                  ),
              ]),
            ),
            const SizedBox(width: AppSpace.sm),
            Text(l.qtyLabel, style: AppText.heading.copyWith(fontSize: 15)),
            const SizedBox(width: AppSpace.sm),
            SizedBox(
              width: 24,
              child: l.collected
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.save, size: 22)
                  : selected
                      ? const Icon(Icons.radio_button_checked_rounded, color: AppColors.brand, size: 22)
                      : onTap == null
                          ? null
                          : const Icon(Icons.radio_button_unchecked_rounded, color: AppColors.inkMuted, size: 22),
            ),
          ]),
        ),
      ),
    );
  }
}

class _EmptyPacking extends StatelessWidget {
  const _EmptyPacking();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.xl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: AppColors.line),
          ),
          child: Row(children: [
            const Icon(Icons.inventory_2_outlined, color: AppColors.inkMuted),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Text(
                'Nothing to pack yet. When a bucket fills, every flat’s share shows up here.',
                style: AppText.bodyMuted,
              ),
            ),
          ]),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xxl),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.storefront_outlined, size: 40, color: AppColors.inkMuted),
              const SizedBox(height: AppSpace.md),
              Text(message, style: AppText.body, textAlign: TextAlign.center),
              const SizedBox(height: AppSpace.lg),
              AppButton.ghost(label: 'Try again', expand: false, onPressed: onRetry),
            ]),
          ),
        ),
      );
}
