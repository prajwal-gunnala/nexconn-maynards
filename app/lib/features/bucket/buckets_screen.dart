import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/images.dart';
import '../../core/models/models.dart';
import '../../core/nexconn/nexconn_service.dart';
import '../../core/session/session_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import 'bucket_card.dart';
import 'bucket_visuals.dart';
import 'card_parts.dart';
import 'list_logic.dart';

/// "Buckets" tab (Licious category listing): tinted header with a type
/// segmented filter and category chips, a count + sort bar, live bucket cards,
/// then past buckets. Home's category grid preselects a category through
/// [BucketsFilter].
class BucketsScreen extends StatefulWidget {
  const BucketsScreen({super.key});

  @override
  State<BucketsScreen> createState() => _BucketsScreenState();
}

class _BucketsScreenState extends State<BucketsScreen> {
  List<Bucket>? _all;
  String? _error;
  BucketSort _sort = BucketSort.closingSoon;
  StreamSubscription<MetadataUpdate>? _metaSub;

  @override
  void initState() {
    super.initState();
    BucketsFilter.category.addListener(_onFilter);
    BucketsFilter.type.addListener(_onFilter);
    _load();
    try {
      _metaSub = context.read<NexconnService>().metadataUpdates.listen((u) {
        final next = _all == null ? null : applyCardMetadata(_all!, u.messageId, u.metadata);
        if (next != null && mounted) setState(() => _all = next);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    BucketsFilter.category.removeListener(_onFilter);
    BucketsFilter.type.removeListener(_onFilter);
    _metaSub?.cancel();
    super.dispose();
  }

  void _onFilter() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final s = context.read<SessionStore>();
    if (s.isDev || s.community == null) {
      setState(() => _all = const []);
      return;
    }
    try {
      final list = await context.read<ApiClient>().buckets(s.community!.id, status: 'all');
      if (mounted) setState(() => (_all = list, _error = null));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SessionStore>();
    final type = BucketsFilter.type.value;
    final cat = BucketsFilter.category.value;
    final all = _all;
    final liveAll = all?.where((b) => b.isLive).toList() ?? const <Bucket>[];
    final live = sortBuckets(liveAll.where((b) => (type == null || b.type == type) && (cat == null || inCategory(b, cat))), _sort);
    final past = (all ?? const <Bucket>[]).where((b) => !b.isLive).toList()
      ..sort((a, b) => (b.cutoffAt ?? DateTime(0)).compareTo(a.cutoffAt ?? DateTime(0)));

    // Inactive tabs stay mounted with tickers off; disable their Heroes so the
    // `bucket-photo-<id>` tags never clash with the Street tab.
    return HeroMode(
      enabled: TickerMode.valuesOf(context).enabled,
      child: Scaffold(
        backgroundColor: AppColors.brandTint,
        body: Column(
          children: [
            _Header(
              subtitle: all == null ? (s.community?.name ?? '') : '${liveAll.length} live at ${s.community?.name ?? 'your street'}',
              type: type,
              category: cat,
            ),
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
                ),
                child: RefreshIndicator(color: AppColors.brand, onRefresh: _load, child: _body(all, live, past, type, cat)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(List<Bucket>? all, List<Bucket> live, List<Bucket> past, BucketType? type, String? cat) {
    if (all == null && _error != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          _Empty(icon: Icons.wifi_off_rounded, title: "Couldn't load buckets", body: _error!, action: 'Try again', onAction: _load),
        ],
      );
    }
    if (all == null) {
      return ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpace.gutter),
        children: const [
          Skeleton(width: 140, height: 16),
          SizedBox(height: AppSpace.lg),
          Skeleton(height: 320, radius: AppRadius.card),
          SizedBox(height: AppSpace.lg),
          Skeleton(height: 320, radius: AppRadius.card),
        ],
      );
    }
    final filtered = type != null || cat != null;
    final what = [if (cat != null) categoryShortLabel(cat), if (type != null) _typeName(type)].join(' · ');
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpace.xxxl),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.md, AppSpace.gutter, AppSpace.xs),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${live.length} live ${live.length == 1 ? 'bucket' : 'buckets'}',
                        style: AppText.label.copyWith(fontSize: 14),
                      ),
                      if (filtered) TextSpan(text: '  in $what', style: AppText.bodyMuted.copyWith(fontSize: 13)),
                    ],
                  ),
                ),
              ),
              _SortButton(value: _sort, onChanged: (v) => setState(() => _sort = v)),
            ],
          ),
        ),
        if (live.isEmpty)
          _Empty(
            icon: Icons.shopping_basket_outlined,
            title: filtered ? 'Nothing live in $what' : 'No live buckets yet',
            body: 'Start one and your neighbours will see it in the Street chat.',
            action: 'Start a bucket',
            onAction: () => context.push('/create'),
            secondary: filtered ? 'Show everything' : null,
            onSecondary: () {
              BucketsFilter.category.value = null;
              BucketsFilter.type.value = null;
            },
          )
        else
          for (final b in live)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.md, AppSpace.gutter, AppSpace.xs),
              child: BucketCard(bucket: b),
            ),
        if (past.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.xxl, AppSpace.gutter, AppSpace.md),
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Past buckets', style: AppText.heading.copyWith(fontSize: 18)),
                  const SizedBox(height: 2),
                  Text('What your street bought together', style: AppText.caption.copyWith(fontSize: 13)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.cardBorder,
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < past.length; i++) ...[if (i > 0) const Divider(), PastBucketRow(bucket: past[i])],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

String _typeName(BucketType t) => switch (t) {
  BucketType.split => 'Split',
  BucketType.bulk => 'Bulk',
  BucketType.service => 'Service',
  BucketType.trip => 'Market trip',
  BucketType.unknown => 'Other',
};

class _Header extends StatelessWidget {
  const _Header({required this.subtitle, required this.type, required this.category});

  final String subtitle;
  final BucketType? type;
  final String? category;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.md, AppSpace.gutter, AppSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text('Buckets', style: AppText.title)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.caption.copyWith(fontSize: 13)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
            child: _TypeSegments(value: type, onChanged: (t) => BucketsFilter.type.value = t),
          ),
          const SizedBox(height: AppSpace.md),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
              children: [
                _CategoryChip(id: null, label: 'All', selected: category == null),
                for (final (id, _) in AppImages.categories) _CategoryChip(id: id, label: categoryShortLabel(id), selected: category == id),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
        ],
      ),
    );
  }
}

class _TypeSegments extends StatelessWidget {
  const _TypeSegments({required this.value, required this.onChanged});

  final BucketType? value;
  final ValueChanged<BucketType?> onChanged;

  @override
  Widget build(BuildContext context) {
    const opts = <(BucketType?, String)>[
      (null, 'All'),
      (BucketType.split, 'Split'),
      (BucketType.bulk, 'Bulk'),
      (BucketType.service, 'Service'),
      (BucketType.trip, 'Market trip'),
    ];
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.photo),
        border: Border.all(color: const Color(0xFFF3DED5)),
      ),
      child: Row(
        children: [
          for (final (t, label) in opts)
            Expanded(
              flex: label.length + 4,
              child: Semantics(
                selected: value == t,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value == t ? AppColors.brand : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      style: AppText.label.copyWith(color: value == t ? Colors.white : AppColors.ink, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.id, required this.label, required this.selected});

  final String? id;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final (tint, icon) = id == null ? (AppColors.brandTint, Icons.apps_rounded) : categoryArt(id!);
    return Padding(
      padding: const EdgeInsets.only(right: AppSpace.sm),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? AppColors.ink : AppColors.surface,
          shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.ink : const Color(0xFFF3DED5))),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => BucketsFilter.category.value = id,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: tint),
                    child: ClipOval(
                      child: id == null
                          ? Icon(icon, size: 18, color: AppColors.brand)
                          : Image.asset(
                              AppImages.category(id!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Icon(icon, size: 18, color: AppColors.ink.withValues(alpha: 0.6)),
                            ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Text(label, style: AppText.label.copyWith(color: selected ? Colors.white : AppColors.ink)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.value, required this.onChanged});

  final BucketSort value;
  final ValueChanged<BucketSort> onChanged;

  static String label(BucketSort s) => switch (s) {
    BucketSort.closingSoon => 'Closing soon',
    BucketSort.biggestSaving => 'Biggest saving',
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<BucketSort>(
      tooltip: 'Sort buckets',
      initialValue: value,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.photo)),
      itemBuilder: (_) => [
        for (final s in BucketSort.values)
          PopupMenuItem(
            value: s,
            child: Text(label(s), style: AppText.body.copyWith(fontWeight: s == value ? FontWeight.w700 : FontWeight.w500)),
          ),
      ],
      child: Container(
        height: 48,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.swap_vert_rounded, size: 16, color: AppColors.ink),
              const SizedBox(width: 6),
              Text(label(value), style: AppText.label),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
    this.secondary,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;
  final String? secondary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final art = BucketVisual.of(title);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.xxl, AppSpace.xxl, AppSpace.xxl, AppSpace.sm),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: art.tint == AppColors.brandTint ? AppColors.surface : art.tint, shape: BoxShape.circle),
            child: Icon(icon, size: 34, color: AppColors.brand),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(title, style: AppText.heading, textAlign: TextAlign.center),
          const SizedBox(height: AppSpace.xs),
          Text(body, style: AppText.bodyMuted, textAlign: TextAlign.center),
          const SizedBox(height: AppSpace.lg),
          FilledButton.icon(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              minimumSize: const Size(160, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.photo)),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(action, style: AppText.heading.copyWith(color: Colors.white, fontSize: 15)),
          ),
          if (secondary != null)
            TextButton(
              onPressed: onSecondary,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(secondary!),
            ),
        ],
      ),
    );
  }
}
