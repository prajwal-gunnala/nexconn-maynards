import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/models/models.dart';
import '../../core/nexconn/nexconn_service.dart';
import '../../core/session/session_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import '../hold/hold_draft.dart';
import 'bucket_visuals.dart';
import 'detail_meet.dart';
import 'detail_model.dart';
import 'detail_modules.dart';
import 'detail_sections.dart';
import 'detail_widgets.dart';

/// Bucket detail (`/bucket/:id`), laid out like a Licious product page:
/// hero photo → title, vendor, spec strip, price → the type module (share
/// map, tiers, step chart or shared list) → members → how the money works
/// (or the market meet card) → sticky CTA with the amount.
class BucketDetailScreen extends StatefulWidget {
  const BucketDetailScreen({super.key, required this.bucketId});

  final String bucketId;

  @override
  State<BucketDetailScreen> createState() => _BucketDetailScreenState();
}

class _BucketDetailScreenState extends State<BucketDetailScreen> {
  BucketView? _view;
  Object? _error;
  JoinDraft _draft = const JoinDraft();
  bool _draftReady = false;
  bool _busy = false;
  bool _checkingIn = false;
  StreamSubscription<MetadataUpdate>? _metaSub;
  String? _watching;
  Timer? _refetchDebounce;
  final _scroll = ScrollController();
  final _collapsed = ValueNotifier(false);

  ApiClient get _api => context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => _collapsed.value = _scroll.hasClients && _scroll.offset > 220);
    _load();
  }

  @override
  void dispose() {
    _metaSub?.cancel();
    _refetchDebounce?.cancel();
    _scroll.dispose();
    _collapsed.dispose();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet && _error != null) setState(() => _error = null);
    try {
      final raw = await _api.get('/api/buckets/${widget.bucketId}');
      if (!mounted) return;
      final v = BucketView.fromJson(asJson(raw) ?? const {});
      setState(() {
        _view = v;
        _error = null;
        if (!_draftReady) {
          _draft = _initialDraft(v);
          _draftReady = true;
        } else {
          _draft = _pruneDraft(v, _draft);
        }
      });
      _watch(v.bucket.cardMessageId);
    } catch (e) {
      if (!mounted) return;
      if (quiet && _view != null) return; // keep showing what we have
      setState(() => _error = e);
    }
  }

  JoinDraft _initialDraft(BucketView v) {
    final options = {for (final g in v.x.optionGroups) g.key: g.choices.first};
    return switch (v.bucket.type) {
      BucketType.bulk || BucketType.service => JoinDraft(qty: bulkDefaultQty(v), options: options),
      _ => JoinDraft(options: options),
    };
  }

  /// Drops picked parts that a neighbour took meanwhile.
  JoinDraft _pruneDraft(BucketView v, JoinDraft d) {
    if (d.unitIds.isEmpty) return d;
    final open = v.bucket.units.where((u) => u.isOpen).map((u) => u.id).toSet();
    final kept = d.unitIds.where(open.contains).toList();
    if (kept.length != d.unitIds.length && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _snack('A neighbour just took one of your picks.');
      });
    }
    return d.copyWith(unitIds: kept);
  }

  /// Live card metadata from the Street chat: move the bar now, then re-fetch.
  void _watch(String? messageId) {
    if (messageId == null || messageId == _watching) return;
    _watching = messageId;
    _metaSub?.cancel();
    try {
      _metaSub = context.read<NexconnService>().watchMetadata(messageId).listen((u) {
        if (!mounted || _view == null) return;
        setState(() => _view = _view!.withMetadata(u.metadata));
        _refetchDebounce?.cancel();
        _refetchDebounce = Timer(const Duration(milliseconds: 400), () => _load(quiet: true));
      }, onError: (_) {});
    } catch (_) {
      // No chat engine (tests, or chat not connected yet): the page still works.
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // ---- actions ---------------------------------------------------------------------------

  Future<void> _join() async {
    final v = _view!;
    HoldRequest.put(HoldRequest(view: v, draft: _draft));
    await context.push('/bucket/${v.bucket.id}/hold');
    if (mounted) _load(quiet: true);
  }

  Future<void> _finishPending(Share s) async {
    final v = _view!;
    HoldRequest.put(HoldRequest(view: v, draft: _draft, pendingShare: s));
    await context.push('/bucket/${v.bucket.id}/hold');
    if (mounted) _load(quiet: true);
  }

  Future<void> _leave(Share s) async {
    final v = _view!;
    final ok = await showLeaveSheet(context, view: v, share: s);
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _api.delete('/api/shares/${s.id}');
      if (!mounted) return;
      _draftReady = false;
      await _load(quiet: true);
      if (!mounted) return;
      _snack(s.hold != null && s.payMode == PayMode.hold
          ? '${Fmt.rupees(s.hold!.amount)} hold released. It is back in your account.'
          : 'Booking cancelled. Your part is open for neighbours again.');
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkIn(Share s) async {
    setState(() => _checkingIn = true);
    try {
      await _api.checkIn(s.id);
      if (!mounted) return;
      await _load(quiet: true);
      if (mounted) _snack('Checked in. ${_view?.bucket.createdBy?.name ?? 'Your group'} can see you are here.');
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  void _copyInvite() {
    final v = _view;
    if (v == null) return;
    Clipboard.setData(ClipboardData(text: inviteText(v)));
    _snack('Invite copied. Paste it in your block group.');
  }

  // ---- build -----------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final v = _view;
    if (v == null && _error != null) return _ErrorView(error: _error!, onRetry: _load);
    if (v == null) return const DetailSkeleton();
    return _buildLoaded(context, v);
  }

  Widget _buildLoaded(BuildContext context, BucketView v) {
    final b = v.bucket;
    final my = b.myShare;
    final active = my != null && !const {ShareStatus.left, ShareStatus.released, ShareStatus.unknown}.contains(my.status);
    final live = b.status == BucketStatus.live;
    final interactive = live && !active;
    final me = context.read<SessionStore>();
    final atMarket = b.settleMode == PayMode.atMarket;

    final sections = <Widget>[
      TitleBlock(view: v),
      const SizedBox(height: AppSpace.lg),
      VendorRow(bucket: b),
      const SizedBox(height: AppSpace.lg),
      SpecStrip(view: v),
      const SizedBox(height: AppSpace.lg),
      PriceBlock(view: v, draft: interactive ? _draft : null),
      if (!live) ...[
        const SizedBox(height: AppSpace.xxl),
        ClosedCard(view: v, onOrder: b.orderId == null ? null : () => context.push('/orders/${b.orderId}')),
      ],
      if (active) ...[
        const SizedBox(height: AppSpace.xxl),
        MyShareCard(
          view: v,
          share: my,
          onLeave: live && const {ShareStatus.pendingPayment, ShareStatus.held, ShareStatus.booked}.contains(my.status) ? () => _leave(my) : null,
          onFinish: live && my.status == ShareStatus.pendingPayment ? () => _finishPending(my) : null,
        ),
      ],
      const SizedBox(height: AppSpace.xxl),
      TypeModule(
        view: v,
        draft: _draft,
        interactive: interactive,
        myUnit: me.unit,
        onChanged: (d) => setState(() => _draft = d),
        onLimit: _snack,
      ),
      const SizedBox(height: AppSpace.xxl),
      MembersCard(view: v, meId: me.user?.id),
      const SizedBox(height: AppSpace.xxl),
      if (atMarket)
        _meetSection(v, my, active)
      else
        MoneySteps(view: v),
      const SizedBox(height: AppSpace.lg),
      VendorPromise(view: v),
      if (b.description != null && b.description!.trim().isNotEmpty) ...[
        const SizedBox(height: AppSpace.xxl),
        const DetailSectionTitle('About this bucket'),
        Text(b.description!, style: AppText.bodyMuted),
      ],
      const SizedBox(height: AppSpace.xxxl),
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: () => _load(quiet: true),
        edgeOffset: 80,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            HeroAppBar(view: v, collapsed: _collapsed, onShare: live ? _copyInvite : null),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.xl, AppSpace.gutter, 0),
              sliver: SliverList.list(children: sections),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DetailCta(
        view: v,
        draft: _draft,
        active: active,
        busy: _busy,
        onJoin: _join,
        onLeave: active ? () => _leave(my) : null,
        onFinish: active && my.status == ShareStatus.pendingPayment ? () => _finishPending(my) : null,
        onOrder: b.orderId == null ? null : () => context.push('/orders/${b.orderId}'),
        onBrowse: () => context.canPop() ? context.pop() : context.go('/buckets'),
      ),
    );
  }

  Widget _meetSection(BucketView v, Share? my, bool active) {
    final b = v.bucket;
    final place = v.x.meetPlace ?? b.pickupPoint ?? 'the gate';
    final market = (b.vendor?.place ?? 'Market').replaceAll(' Harbour', ' Fish Market');
    final canCheckIn = active &&
        const {BucketStatus.ordered, BucketStatus.marketDay, BucketStatus.delivering}.contains(b.status) &&
        const {ShareStatus.booked, ShareStatus.captured}.contains(my!.status);
    final checkedIn = active && (my!.status == ShareStatus.checkedIn || my.status == ShareStatus.collected);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const DetailSectionTitle('Meet at the market', subtitle: 'No prepayment. Book now, pay at the stall.'),
      MeetCard(
        place: place,
        market: market,
        at: v.x.meetAt ?? b.deliverAt,
        note: v.x.meetNote,
        people: meetPeople(v, context.read<SessionStore>().user?.id),
        checkInLabel: active ? "I'm here" : null,
        checkInHint: active && !canCheckIn && !checkedIn ? 'Check-in opens once both halves are booked.' : null,
        onCheckIn: canCheckIn ? () => _checkIn(my) : null,
        checkingIn: _checkingIn,
        checkedIn: checkedIn,
      ),
    ]);
  }
}

/// Who's coming to the market: organiser first, then the others, then you.
List<MeetPerson> meetPeople(BucketView v, String? meId) {
  final b = v.bucket;
  final out = <MeetPerson>[];
  final seen = <String>{};
  for (final s in b.shares) {
    if (const {ShareStatus.left, ShareStatus.released}.contains(s.status)) continue;
    if (!seen.add(s.user.id)) continue;
    final isMe = s.user.id == meId;
    final organiser = s.user.id == b.createdBy?.id;
    final here = s.status == ShareStatus.checkedIn || s.status == ShareStatus.collected;
    out.add(MeetPerson(
      name: s.user.name,
      note: [if (organiser) 'organiser', v.x.shareLabels[s.id]?.toLowerCase()].whereType<String>().join(' · '),
      status: here ? 'Here' : 'Booked',
      me: isMe,
      here: here,
    ));
  }
  out.sort((a, c) => (a.me ? 1 : 0).compareTo(c.me ? 1 : 0));
  return out;
}

/// Short name for the collapsed app bar (the full title is in the body):
/// drops "(1121)", ", 7-share Split" and "Kasimedu Book & Meet:" style prefixes.
String shortTitle(String title) {
  var t = title;
  final colon = t.indexOf(':');
  if (colon > 0 && colon < t.length - 1) t = t.substring(colon + 1);
  t = t.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
  final comma = t.indexOf(',');
  if (comma > 0) t = t.substring(0, comma);
  t = t.trim();
  return t.isEmpty ? title : t;
}

/// Text copied by "Invite neighbours".
String inviteText(BucketView v) {
  final b = v.bucket;
  final p = b.progress;
  final unit = b.unitLabel ?? 'share';
  final left = p.target - p.filled;
  final next = p.nextTier;
  final pitch = switch (b.type) {
    BucketType.split => left > 0 ? '${plural(left, unit)} still open' : 'all parts taken',
    BucketType.bulk || BucketType.service => next != null
        ? '${plural(next.remaining, unit)} more and all of us pay ${Fmt.rupees(next.unitPrice)}/$unit'
        : 'we are at the best price, ${Fmt.rupees(b.unitPrice ?? 0)}/$unit',
    BucketType.trip => '${fmtQty(left)} kg of space left in the tempo',
    BucketType.unknown => '',
  };
  final close = b.cutoffAt == null ? '' : ' Closes ${shortWhen(b.cutoffAt!)}.';
  return 'Join our ${b.title} bucket on Jugaad Street: $pitch.$close';
}

// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final msg = error is ApiException ? (error as ApiException).message : 'Something went wrong while loading.';
    final notFound = error is ApiException && (error as ApiException).status == 404;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: AppColors.brandTint, shape: BoxShape.circle),
              child: Icon(notFound ? Icons.search_off_rounded : Icons.wifi_off_rounded, size: 34, color: AppColors.brandDeep),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(notFound ? 'This bucket is gone' : "Couldn't load this bucket", style: AppText.title, textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.sm),
            Text(msg, style: AppText.bodyMuted, textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.xxl),
            AppButton(label: 'Try again', icon: Icons.refresh_rounded, onPressed: onRetry, expand: false),
          ]),
        ),
      ),
    );
  }
}

/// Loading skeleton in the shape of the page.
class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Semantics(
        label: 'Loading bucket',
        child: ListView(physics: const NeverScrollableScrollPhysics(), padding: EdgeInsets.zero, children: [
          const ColoredBox(color: AppColors.canvas, child: SizedBox(height: 300)),
          const Padding(
            padding: EdgeInsets.all(AppSpace.gutter),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(height: AppSpace.xs),
              SkeletonBox(width: 260, height: 22),
              SizedBox(height: AppSpace.sm),
              SkeletonBox(width: 180, height: 14),
              SizedBox(height: AppSpace.xl),
              Row(children: [
                SkeletonBox(width: 40, height: 40, radius: 20),
                SizedBox(width: AppSpace.md),
                Expanded(child: SkeletonBox(height: 14)),
                SizedBox(width: 80),
              ]),
              SizedBox(height: AppSpace.xl),
              SkeletonBox(height: 52, radius: 12),
              SizedBox(height: AppSpace.xl),
              SkeletonBox(width: 140, height: 26),
              SizedBox(height: AppSpace.xxl),
              SkeletonBox(height: 180, radius: 16),
              SizedBox(height: AppSpace.xxl),
              SkeletonBox(height: 72, radius: 16),
            ]),
          ),
        ]),
      ),
      bottomNavigationBar: const StickyCta(child: SkeletonBox(height: 52, radius: 14)),
    );
  }
}

/// Collapsing hero: full-bleed photo with type badge + countdown, white
/// circular back button; the title fades into the bar once scrolled.
class HeroAppBar extends StatelessWidget {
  const HeroAppBar({super.key, required this.view, required this.collapsed, this.onShare});

  final BucketView view;
  final ValueListenable<bool> collapsed;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final b = view.bucket;
    Widget circle(IconData icon, String tip, VoidCallback? on) => Padding(
          padding: const EdgeInsets.all(4),
          child: Material(
            color: AppColors.surface.withValues(alpha: 0.94),
            shape: const CircleBorder(),
            elevation: 0,
            child: IconButton(icon: Icon(icon, size: 22, color: AppColors.ink), tooltip: tip, onPressed: on),
          ),
        );
    return ValueListenableBuilder<bool>(
      valueListenable: collapsed,
      builder: (context, isCollapsed, _) => SliverAppBar(
        pinned: true,
        expandedHeight: 300,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpace.sm),
          child: circle(Icons.arrow_back_rounded, 'Back', () => context.canPop() ? context.pop() : context.go('/street')),
        ),
        title: AnimatedOpacity(
          opacity: isCollapsed ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(typeLabel(b), style: AppText.tiny.copyWith(color: AppColors.brandDeep)),
            Text(shortTitle(b.title), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.heading.copyWith(fontSize: 17)),
          ]),
        ),
        actions: [
          if (onShare != null) circle(Icons.ios_share_rounded, 'Invite neighbours', onShare),
          const SizedBox(width: AppSpace.sm),
        ],
        flexibleSpace: FlexibleSpaceBar(
          collapseMode: CollapseMode.parallax,
          background: Stack(fit: StackFit.expand, children: [
            Hero(
              tag: 'bucket-photo-${b.id}',
              child: BucketPhoto(
                visual: BucketVisual.of(b.image ?? b.category ?? b.title),
                url: b.image,
                height: double.infinity,
                borderRadius: BorderRadius.zero,
              ),
            ),
            // legibility scrims
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.25, 0.7, 1],
                  colors: [Color(0x33000000), Color(0x00000000), Color(0x00000000), Color(0x59000000)],
                ),
              ),
            ),
            Positioned(
              left: AppSpace.gutter,
              right: AppSpace.gutter,
              bottom: AppSpace.lg,
              child: Row(children: [
                HeroChip(icon: typeIcon(b.type), label: typeLabel(b)),
                const Spacer(),
                if (b.status == BucketStatus.live && b.cutoffAt != null)
                  CountdownBuilder(
                    cutoff: b.cutoffAt!,
                    builder: (_, left) => HeroChip(
                      icon: Icons.schedule_rounded,
                      label: closesText(b.cutoffAt!, left),
                      urgent: left.inHours < 3,
                    ),
                  )
                else
                  ClosedPill(status: b.status),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
