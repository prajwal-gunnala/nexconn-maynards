import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/images.dart';
import '../../core/models/models.dart';
import '../../core/nexconn/chat_session.dart';
import '../../core/nexconn/nexconn_service.dart';
import '../../core/session/session_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/format.dart';
import '../bucket/bucket_card.dart';
import '../bucket/list_logic.dart';
import '../community/join_community_screen.dart';
import 'list_home_sections.dart';

/// Street home (Licious home pattern): sticky tinted header with the community
/// and search, banner carousel, "Shop by category", a "Closing soon" rail,
/// savings, the Street chat entry, every live bucket, and "Start a bucket".
/// Cards update live from the `js:bucket` chat card metadata.
class StreetHomeScreen extends StatefulWidget {
  const StreetHomeScreen({super.key});

  @override
  State<StreetHomeScreen> createState() => _StreetHomeScreenState();
}

class _StreetHomeScreenState extends State<StreetHomeScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  StreamSubscription<MetadataUpdate>? _metaSub;

  Community? _community;
  List<Bucket>? _buckets;
  String? _error;
  bool _loading = false;

  String get _query => _search.text.trim();

  @override
  void initState() {
    super.initState();
    _community = context.read<SessionStore>().community;
    _load();
    try {
      _metaSub = context.read<NexconnService>().metadataUpdates.listen(_onMetadata);
    } catch (_) {
      // No chat engine (tests, or the plugin failed to load): cards just won't tick live.
    }
  }

  @override
  void dispose() {
    _metaSub?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = context.read<SessionStore>();
    final api = context.read<ApiClient>();
    final id = s.community?.id;
    if (s.isDev || id == null) {
      setState(() => (_buckets = const [], _community = s.community));
      return;
    }
    setState(() => (_loading = true, _error = null));
    try {
      final results = await Future.wait([api.community(id), api.buckets(id)]);
      if (!mounted) return;
      setState(() {
        _community = results[0] as Community;
        _buckets = results[1] as List<Bucket>;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong. Pull down to try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onMetadata(MetadataUpdate u) {
    final list = _buckets;
    if (list == null || !mounted) return;
    final next = applyCardMetadata(list, u.messageId, u.metadata);
    if (next != null) setState(() => _buckets = next);
  }

  void _openCategory(String? id) {
    BucketsFilter.category.value = id;
    BucketsFilter.type.value = null;
    context.go('/buckets');
  }

  String _streetTitle(String name) {
    final base = name.replaceAll(RegExp(r'\s+(Towers?|Apartments?|Residency|Society|Enclave|Heights)$', caseSensitive: false), '');
    return '$base Street';
  }

  void _openStreetChat() {
    final s = context.read<SessionStore>();
    final id = s.streetChannelId;
    if (id == null) return;
    final title = _streetTitle(_community?.name ?? 'Your');
    context.push('/chat/group/$id?title=${Uri.encodeComponent(title)}');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SessionStore>();
    if (s.community?.id != _community?.id && !_loading) {
      // Community switched elsewhere: reload on the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
      _community = s.community;
    }
    // Inactive tabs stay mounted (IndexedStack) with tickers off; keep their
    // card Heroes out of the way so tags never clash across tabs.
    return HeroMode(
      enabled: TickerMode.valuesOf(context).enabled,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: RefreshIndicator(
          color: AppColors.brand,
          edgeOffset: MediaQuery.paddingOf(context).top + 128,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [_header(s), ...(_query.isNotEmpty ? _searchSlivers() : _homeSlivers(s))],
          ),
        ),
      ),
    );
  }

  Widget _header(SessionStore s) {
    final c = _community ?? s.community;
    final place = [s.unit, c?.area].whereType<String>().join(' · ');
    return SliverAppBar(
      pinned: true,
      toolbarHeight: 68,
      backgroundColor: AppColors.brandTint,
      surfaceTintColor: Colors.transparent,
      titleSpacing: AppSpace.sm,
      title: Semantics(
        button: true,
        label: 'Community ${c?.name ?? ''}, tap to switch',
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.photo),
          onTap: () => _switchCommunity(s),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, color: AppColors.brand, size: 26),
                const SizedBox(width: 6),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              c?.name ?? 'Your street',
                              style: AppText.heading.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: AppColors.ink),
                        ],
                      ),
                      if (place.isNotEmpty)
                        Text(place, style: AppText.caption.copyWith(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpace.md),
          child: Semantics(
            button: true,
            label: 'Profile and settings',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _profileMenu(s),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFF6D9CE)),
                ),
                child: Text(s.user?.initial ?? '?', style: AppText.heading.copyWith(color: AppColors.brand)),
              ),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, AppSpace.md),
          child: _SearchField(controller: _search, focusNode: _searchFocus, onChanged: () => setState(() {})),
        ),
      ),
    );
  }

  List<Widget> _homeSlivers(SessionStore s) {
    final buckets = _buckets;
    if (buckets == null) {
      return [
        const SliverPadding(
          padding: EdgeInsets.only(top: AppSpace.lg),
          sliver: SliverToBoxAdapter(child: HomeSkeleton()),
        ),
        if (_error != null)
          SliverToBoxAdapter(
            child: ErrorPanel(message: _error!, onRetry: _load),
          ),
      ];
    }
    final c = _community;
    final live = sortBuckets(buckets.where((b) => b.isLive), BucketSort.closingSoon);
    final closing = live.where((b) => b.cutoffAt != null).take(5).toList();
    final counts = <String, int>{for (final (id, _) in AppImages.categories) id: live.where((b) => inCategory(b, id)).length};
    final members = c?.stats?.members ?? c?.memberCount ?? 0;
    final saved = c?.stats?.savedThisMonth ?? 0;
    final latest = live.map((b) => b.latestActivity).whereType<String>().firstOrNull;

    final banners = [
      HomeBanner(
        kicker: 'Kasimedu harbour',
        title: 'Sunday fish run',
        body: 'Whole seer split eight ways, landed at dawn',
        image: AppImages.banners[0],
        fallbackPhoto: AppImages.bucket('seer'),
        colors: const [Color(0xFF0F4C5C), Color(0xFF1C7C8C)],
        onTap: () => _openCategory('fish'),
      ),
      HomeBanner(
        kicker: 'Devgad peti',
        title: 'Mango season',
        body: 'GI-tagged Alphonso, farm-direct by the dozen',
        image: AppImages.banners[1],
        fallbackPhoto: AppImages.bucket('alphonso'),
        colors: const [Color(0xFFB8590B), Color(0xFFE8961E)],
        onTap: () => _openCategory('fruits'),
      ),
      HomeBanner(
        kicker: 'This month',
        title: 'Your tower saved ${Fmt.rupees(saved)}',
        body: '$members neighbours buying together',
        image: AppImages.banners[2],
        fallbackPhoto: AppImages.bucket('koyambedu'),
        colors: const [Color(0xFF0B7A43), Color(0xFF12A150)],
        onTap: () => context.go('/wallet'),
      ),
    ];

    Widget pad(Widget w, {double top = 0}) => Padding(padding: EdgeInsets.fromLTRB(AppSpace.gutter, top, AppSpace.gutter, 0), child: w);

    return [
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpace.lg),
            BannerCarousel(banners: banners),
            const HomeSectionHeader('Shop by category', subtitle: 'Everything your street buys together'),
            CategoryGrid(counts: counts, onTap: _openCategory),
            if (closing.isNotEmpty) ...[
              HomeSectionHeader(
                'Closing soon',
                subtitle: 'Last call before the cutoff',
                action: 'See all',
                onAction: () => _openCategory(null),
              ),
              SizedBox(
                height: BucketCard.compactHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
                  itemCount: closing.length,
                  separatorBuilder: (_, _) => const SizedBox(width: AppSpace.md),
                  itemBuilder: (_, i) => BucketCard.compact(bucket: closing[i]),
                ),
              ),
            ],
            pad(
              SavingsCard(saved: saved, members: members, live: live.length, onTap: () => context.go('/wallet')),
              top: AppSpace.xxl,
            ),
            if (s.streetChannelId != null)
              pad(
                StreetChatCard(title: _streetTitle(c?.name ?? 'Your'), members: members, latest: latest, onTap: _openStreetChat),
                top: AppSpace.md,
              ),
            HomeSectionHeader(
              'Live on your street',
              subtitle: live.isEmpty ? 'Nothing open right now' : '${live.length} buckets your neighbours are filling',
            ),
          ],
        ),
      ),
      if (live.isEmpty)
        SliverToBoxAdapter(child: pad(_EmptyLive(onStart: () => context.push('/create'))))
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          sliver: SliverList.separated(
            itemCount: live.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.lg),
            itemBuilder: (_, i) => BucketCard(bucket: live[i]),
          ),
        ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.xxl, AppSpace.gutter, AppSpace.xxxl),
          child: StartBucketCard(onTap: () => context.push('/create')),
        ),
      ),
    ];
  }

  List<Widget> _searchSlivers() {
    final live = (_buckets ?? const <Bucket>[]).where((b) => b.isLive);
    final results = sortBuckets(searchBuckets(live, _query), BucketSort.closingSoon);
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.lg, AppSpace.gutter, AppSpace.md),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${results.length} ${results.length == 1 ? 'bucket' : 'buckets'}',
                  style: AppText.label.copyWith(fontSize: 14),
                ),
                TextSpan(text: ' for "$_query"', style: AppText.bodyMuted),
              ],
            ),
          ),
        ),
      ),
      if (results.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xxl),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(color: AppColors.brandTint, shape: BoxShape.circle),
                  child: const Icon(Icons.search_off_rounded, color: AppColors.brand, size: 32),
                ),
                const SizedBox(height: AppSpace.lg),
                Text('Nobody has started that yet', style: AppText.heading),
                const SizedBox(height: AppSpace.xs),
                Text('Start a bucket and your neighbours can join in.', style: AppText.bodyMuted, textAlign: TextAlign.center),
                const SizedBox(height: AppSpace.lg),
                TextButton.icon(
                  onPressed: () => context.push('/create'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Start a bucket'),
                ),
              ],
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, AppSpace.xxxl),
          sliver: SliverList.separated(
            itemCount: results.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.lg),
            itemBuilder: (_, i) => BucketCard(bucket: results[i]),
          ),
        ),
    ];
  }

  // ---- sheets ---------------------------------------------------------------

  Future<void> _switchCommunity(SessionStore s) async {
    final api = context.read<ApiClient>();
    final picked = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (_) => _CommunitySheet(
        load: s.isDev ? Future.value(const <Membership>[]) : api.me().then((m) => m.memberships),
        currentId: s.community?.id,
      ),
    );
    if (!mounted) return;
    if (picked is Membership) {
      if (picked.community.id == s.community?.id) return;
      setState(() => _buckets = null);
      // build() notices the new community and reloads.
      await s.setCommunity(picked.community, unit: picked.unit, role: picked.role);
    } else if (picked == _CommunitySheet.joinAnother) {
      await Navigator.of(
        context,
        rootNavigator: true,
      ).push(MaterialPageRoute<void>(builder: (_) => const JoinCommunityScreen(popOnJoin: true)));
      if (mounted) await _load();
    }
  }

  Future<void> _profileMenu(SessionStore s) async {
    final route = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, AppSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.brand,
                    child: Text(s.user?.initial ?? '?', style: AppText.title.copyWith(color: Colors.white)),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.user?.name ?? 'You', style: AppText.title.copyWith(fontSize: 18)),
                        Text([s.unit, s.community?.name].whereType<String>().join(' · '), style: AppText.caption),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              const Divider(),
              _MenuTile(icon: Icons.receipt_long_outlined, label: 'My orders', onTap: () => Navigator.pop(ctx, '/orders')),
              _MenuTile(icon: Icons.storefront_outlined, label: 'Vendor dashboard', onTap: () => Navigator.pop(ctx, '/vendor')),
              if (s.isAdmin)
                _MenuTile(icon: Icons.admin_panel_settings_outlined, label: 'Community admin', onTap: () => Navigator.pop(ctx, '/admin')),
              const Divider(),
              _MenuTile(icon: Icons.logout_rounded, label: 'Sign out', danger: true, onTap: () => Navigator.pop(ctx, 'signout')),
            ],
          ),
        ),
      ),
    );
    if (!mounted || route == null) return;
    if (route != 'signout') {
      context.push(route);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your holds stay safe. Sign back in with your number any time.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true && mounted) await context.read<ChatSession>().signOut();
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.focusNode, required this.onChanged});

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        onChanged: (_) => onChanged(),
        style: AppText.body,
        decoration: InputDecoration(
          hintText: 'Search seer, basmati, pest control…',
          contentPadding: EdgeInsets.zero,
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.inkMuted),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () {
                    controller.clear();
                    focusNode.unfocus();
                    onChanged();
                  },
                ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFF3DED5)),
          ),
        ),
      ),
    );
  }
}

class _EmptyLive extends StatelessWidget {
  const _EmptyLive({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          const Icon(Icons.shopping_basket_outlined, size: 36, color: AppColors.brand),
          const SizedBox(height: AppSpace.sm),
          Text('No live buckets yet', style: AppText.heading),
          const SizedBox(height: AppSpace.xs),
          Text('Be the first: start one and your street fills it.', style: AppText.bodyMuted, textAlign: TextAlign.center),
          const SizedBox(height: AppSpace.md),
          TextButton(onPressed: onStart, child: const Text('Start a bucket')),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, required this.onTap, this.danger = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.ink;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 52,
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: AppText.body.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
      trailing: danger ? null : const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
      onTap: onTap,
    );
  }
}

class _CommunitySheet extends StatelessWidget {
  const _CommunitySheet({required this.load, this.currentId});

  static const joinAnother = 'join';

  final Future<List<Membership>> load;
  final String? currentId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your communities', style: AppText.title.copyWith(fontSize: 18)),
            const SizedBox(height: AppSpace.md),
            FutureBuilder<List<Membership>>(
              future: load,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpace.xl),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final list = snap.data ?? const <Membership>[];
                return Column(
                  children: [
                    for (final m in list)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        minTileHeight: 56,
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.brandTint,
                          child: Icon(Icons.apartment_rounded, color: AppColors.brand),
                        ),
                        title: Text(m.community.name, style: AppText.heading.copyWith(fontSize: 15)),
                        subtitle: Text([m.unit, m.community.area].whereType<String>().join(' · '), style: AppText.caption),
                        trailing: m.community.id == currentId
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.brand)
                            : const Icon(Icons.radio_button_unchecked_rounded, color: AppColors.line),
                        onTap: () => Navigator.pop(context, m),
                      ),
                  ],
                );
              },
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              minTileHeight: 52,
              leading: const Icon(Icons.add_home_outlined, color: AppColors.brand),
              title: Text(
                'Join another community',
                style: AppText.body.copyWith(color: AppColors.brand, fontWeight: FontWeight.w700),
              ),
              onTap: () => Navigator.pop(context, joinAnother),
            ),
          ],
        ),
      ),
    );
  }
}
