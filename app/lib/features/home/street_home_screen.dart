import 'dart:async';

import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart' show Message;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/nexconn/chat_session.dart';
import '../../core/nexconn/js_messages.dart';
import '../../core/nexconn/nexconn_service.dart';
import '../../core/session/session_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import '../bucket/list_logic.dart';
import '../community/join_community_screen.dart';
import 'card_group.dart';
import 'list_feed.dart';
import 'list_home_sections.dart';

/// Street home, people first: who on your street is buying together right now,
/// the few buckets closest to filling ("Join your neighbours"), what just
/// happened, and how to start your own. The catalogue lives on the Buckets tab.
/// Cards and the feed update live from the Street chat (card metadata and
/// `js:event` messages).
class StreetHomeScreen extends StatefulWidget {
  const StreetHomeScreen({super.key});

  @override
  State<StreetHomeScreen> createState() => _StreetHomeScreenState();
}

class _StreetHomeScreenState extends State<StreetHomeScreen> {
  StreamSubscription<MetadataUpdate>? _metaSub;
  StreamSubscription<Message>? _msgSub;

  Community? _community;
  List<Bucket>? _buckets;
  Map<String, Json> _raw = const {};
  final List<FeedItem> _liveFeed = [];
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _community = context.read<SessionStore>().community;
    _load();
    try {
      final nx = context.read<NexconnService>();
      _metaSub = nx.metadataUpdates.listen(_onMetadata);
      _msgSub = nx.messages.listen(_onMessage);
    } catch (_) {
      // No chat engine (tests, or the plugin failed to load): the page still works, just not live.
    }
  }

  @override
  void dispose() {
    _metaSub?.cancel();
    _msgSub?.cancel();
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
      final results = await Future.wait([
        api.community(id),
        api.get('/api/communities/$id/buckets', query: {'status': 'live'}),
      ]);
      if (!mounted) return;
      final rawList = (results[1] is List ? results[1] as List : const []).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
      setState(() {
        _community = results[0] as Community;
        _raw = {for (final j in rawList) asString(j['id']): j};
        _buckets = rawList.map(Bucket.fromJson).toList();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
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

  void _onMessage(Message m) {
    if (!mounted || jsTypeOf(m) != JsType.event) return;
    final sent = m.sentTime;
    final item = feedFromEvent(jsFields(m), sent == null || sent == 0 ? StreetClock.now() : DateTime.fromMillisecondsSinceEpoch(sent), _buckets ?? const []);
    if (item == null) return;
    setState(() {
      _liveFeed.insert(0, item);
      if (_liveFeed.length > 3) _liveFeed.removeLast();
    });
  }

  String _streetTitle(String name) {
    final base = name.replaceAll(RegExp(r'\s+(Towers?|Apartments?|Residency|Society|Enclave|Heights)$', caseSensitive: false), '');
    return '$base Street';
  }

  void _openStreetChat() {
    final id = context.read<SessionStore>().streetChannelId;
    if (id == null) return;
    context.push('/chat/group/$id?title=${Uri.encodeComponent(_streetTitle(_community?.name ?? 'Your'))}');
  }

  void _seeAll() {
    BucketsFilter.category.value = null;
    BucketsFilter.type.value = null;
    context.go('/buckets');
  }

  /// Up to three buckets to feature: one per type, closest cutoff first,
  /// preferring ones the viewer hasn't joined yet.
  List<Bucket> _featured(List<Bucket> live) {
    final sorted = sortBuckets(live, BucketSort.closingSoon);
    final pool = [...sorted.where((b) => b.myShare == null), ...sorted.where((b) => b.myShare != null)];
    final out = <Bucket>[];
    for (final b in pool) {
      if (out.length == 3) break;
      if (out.any((x) => x.type == b.type)) continue;
      out.add(b);
    }
    for (final b in pool) {
      if (out.length == 3) break;
      if (!out.contains(b)) out.add(b);
    }
    return out;
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
    // Heroes out of the way so tags never clash across tabs.
    return HeroMode(
      enabled: TickerMode.valuesOf(context).enabled,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: RefreshIndicator(
          color: AppColors.brand,
          edgeOffset: MediaQuery.paddingOf(context).top + 64,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [_header(s), ..._body(s)],
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
      toolbarHeight: 64,
      backgroundColor: AppColors.canvas,
      surfaceTintColor: Colors.transparent,
      titleSpacing: AppSpace.gutter,
      title: Row(children: [
        const BrandMark(size: 36),
        const SizedBox(width: AppSpace.sm),
        Flexible(
          child: Semantics(
            button: true,
            label: 'Community ${c?.name ?? ''}, tap to switch',
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.photo),
              onTap: () => _switchCommunity(s),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: AppSpace.xs),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(
                      child: Text(c?.name ?? 'Your street',
                          style: AppText.heading.copyWith(fontSize: 17, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.ink),
                  ]),
                  if (place.isNotEmpty) Text(place, style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ),
          ),
        ),
      ]),
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
                decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.line)),
                child: Text(s.user?.initial ?? '?', style: AppText.heading.copyWith(color: AppColors.brand)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _body(SessionStore s) {
    final buckets = _buckets;
    if (buckets == null) {
      return [
        const SliverPadding(padding: EdgeInsets.only(top: AppSpace.sm), sliver: SliverToBoxAdapter(child: HomeSkeleton())),
        if (_error != null) SliverToBoxAdapter(child: ErrorPanel(message: _error!, onRetry: _load)),
      ];
    }
    final c = _community;
    final live = buckets.where((b) => b.isLive).toList();
    final seen = <String>{};
    final people = [
      for (final b in sortBuckets(live, BucketSort.closingSoon))
        for (final u in b.people)
          if (seen.add(u.id)) u,
    ];
    final featured = _featured(live);
    final feed = [..._liveFeed, ...feedFromBuckets(live, _raw)].take(6).toList();
    final meId = s.user?.id;

    Widget pad(Widget w) => Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter), child: w);

    return [
      SliverToBoxAdapter(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: AppSpace.xs),
          pad(TogetherHero(
            streetName: _streetTitle(c?.name ?? 'Your'),
            people: people,
            // One community snapshot (same numbers as the admin screen); only
            // fall back to local counts if the server sent no stats.
            members: c?.stats?.members ?? c?.memberCount ?? people.length,
            liveBuckets: c?.stats?.liveBuckets ?? live.length,
            saved: c?.stats?.savedThisMonth ?? 0,
            month: DateFormat('MMMM').format(StreetClock.now().toLocal()),
            onStart: () => context.push('/create'),
            onChat: s.streetChannelId == null ? null : _openStreetChat,
          )),
          const SizedBox(height: AppSpace.md),
          pad(const BucketExplainer()),
          HomeSectionHeader('Join your neighbours',
              subtitle: live.isEmpty ? 'Nothing open right now' : 'Closest to filling up. Every person helps.'),
        ]),
      ),
      if (featured.isEmpty)
        SliverToBoxAdapter(child: pad(_EmptyLive(onStart: () => context.push('/create'))))
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          sliver: SliverList.separated(
            itemCount: featured.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.lg),
            itemBuilder: (_, i) => GroupBucketCard(bucket: featured[i], meId: meId),
          ),
        ),
      SliverToBoxAdapter(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (live.length > featured.length)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.md, AppSpace.gutter, 0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _seeAll,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brandDeep,
                    side: const BorderSide(color: Color(0xFFF1CDBF)),
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.photo)),
                  ),
                  child: Text('See all ${live.length} buckets', style: AppText.heading.copyWith(color: AppColors.brandDeep, fontSize: 14.5)),
                ),
              ),
            ),
          if (feed.isNotEmpty) ...[
            const HomeSectionHeader('Happening on your street', subtitle: 'Live from the Street chat'),
            pad(ActivityFeed(items: feed)),
          ],
          const HomeSectionHeader('Start your own bucket', subtitle: 'Anyone can start one. Your street fills it.'),
          pad(StartTypeTiles(onTap: (_) => context.push('/create'))),
          const SizedBox(height: AppSpace.xxxl),
        ]),
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
              if (s.user?.role == 'vendor')
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
