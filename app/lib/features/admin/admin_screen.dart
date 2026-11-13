import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/models/models.dart';
import '../../core/session/session_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import '../chat/chat_avatar.dart';
import '../chat/chat_directory.dart';

/// `GET /api/admin/communities/:id`.
class AdminData {
  const AdminData({
    required this.community,
    required this.savedThisMonth,
    required this.members,
    required this.pendingVendors,
    required this.nudges,
  });

  final Community? community;
  final int savedThisMonth;
  final int members;
  final List<PendingVendor> pendingVendors;
  final List<Nudge> nudges;

  /// Uses [c]'s stats as the single source for the headline numbers.
  AdminData withCommunity(Community? c) {
    final stats = c?.stats;
    if (c == null || stats == null) return this;
    return AdminData(
      community: c,
      savedThisMonth: stats.savedThisMonth,
      members: stats.members,
      pendingVendors: pendingVendors,
      nudges: nudges,
    );
  }

  factory AdminData.fromJson(Json j) => AdminData(
    community: asJson(j['community']) == null ? null : Community.fromJson(asJson(j['community'])!),
    savedThisMonth: asInt(j['savedThisMonth']),
    members: asInt(j['members']),
    pendingVendors: asList(j['pendingVendors'], PendingVendor.fromJson),
    nudges: asList(j['nudges'], Nudge.fromJson),
  );
}

class PendingVendor {
  const PendingVendor({required this.id, required this.name, this.category, this.place, this.note});

  final String id;
  final String name;
  final String? category;
  final String? place;
  final String? note;

  factory PendingVendor.fromJson(Json j) => PendingVendor(
    id: asString(j['id']),
    name: asString(j['name'], 'Vendor'),
    category: asStringOrNull(j['category']),
    place: asStringOrNull(j['place']),
    note: asStringOrNull(j['note']),
  );
}

class Nudge {
  const Nudge({required this.bucketId, required this.text, this.title, this.cutoffAt});

  final String bucketId;
  final String? title;
  final String text;
  final DateTime? cutoffAt;

  /// The text without the leading "Title: " (the title is shown above it).
  String get body {
    final t = title;
    if (t != null && text.startsWith('$t: ')) return text.substring(t.length + 2);
    return text;
  }

  factory Nudge.fromJson(Json j) => Nudge(
    bucketId: asString(j['bucketId']),
    title: asStringOrNull(j['title']),
    text: asString(j['text']),
    cutoffAt: asTime(j['cutoffAt']),
  );
}

enum _Decision { approved, declined }

/// Admin: community — what the street saved, vendor approvals, nudges.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, this.communityId});

  /// Defaults to the signed-in member's community.
  final String? communityId;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late Future<AdminData> _future = _load();
  final Map<String, _Decision> _decisions = {};
  final Set<String> _reminded = {};
  final Set<String> _reminding = {};

  String? get _communityId => widget.communityId ?? context.read<SessionStore>().community?.id;

  Future<AdminData> _load() async {
    final id = _communityId;
    if (id == null) throw const ApiException('NO_COMMUNITY', 'Join a community first.');
    final api = context.read<ApiClient>();
    // Admin-only lists from the admin endpoint; the numbers (saved, members, live buckets)
    // from the same `GET /api/communities/:id` stats the home screen shows.
    final results = await Future.wait<Object?>([
      api.adminCommunity(id),
      api.community(id).then<Community?>((c) => c, onError: (_) => null),
    ]);
    final admin = AdminData.fromJson(results[0] as Json);
    final community = results[1] as Community?;
    return admin.withCommunity(community);
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() {
      _future = f;
    });
    await f;
  }

  Future<void> _remind(Nudge n) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _reminding.add(n.bucketId));
    try {
      await context.read<ApiClient>().nudge(n.bucketId);
      if (!mounted) return;
      setState(() => _reminded.add(n.bucketId));
      messenger.showSnackBar(const SnackBar(content: Text('Reminder posted in Street chat')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _reminding.remove(n.bucketId));
    }
  }

  void _decide(PendingVendor v, _Decision d) {
    setState(() => _decisions[v.id] = d);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(d == _Decision.approved ? '${v.name} can now start buckets' : '${v.name} declined'),
        action: SnackBarAction(label: 'Undo', onPressed: () => setState(() => _decisions.remove(v.id))),
      ),
    );
  }

  Future<void> _invite(Community? c) async {
    final name = c?.name ?? 'our building';
    final code = c?.inviteCode;
    final text =
        'Join $name on Jugaad Street. We buy fish, rice, mangoes and services together and save on every '
        'order. Money is only held until a bucket fills.${code == null ? '' : ' Invite code: $code'}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite copied. Paste it in your building group.')));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Community admin')),
      body: FutureBuilder<AdminData>(
        future: _future,
        builder: (context, s) {
          if (s.hasError) {
            final msg = s.error is ApiException ? (s.error as ApiException).message : 'Something went wrong.';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.admin_panel_settings_outlined, size: 40, color: AppColors.inkMuted),
                    const SizedBox(height: AppSpace.md),
                    Text(msg, style: AppText.body, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpace.lg),
                    AppButton.ghost(label: 'Try again', expand: false, onPressed: _refresh),
                  ],
                ),
              ),
            );
          }
          final d = s.data;
          if (d == null) return const Center(child: CircularProgressIndicator());
          final c = d.community ?? session.community;
          final user = session.user;
          final pending = d.pendingVendors;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpace.xxxl),
              children: [
                _CommunityHeader(
                  community: c,
                  members: d.members,
                  adminLine: user == null ? null : 'Admin · ${user.name}${session.unit == null ? '' : ', ${session.unit}'}',
                ),
                _SavedHero(saved: d.savedThisMonth, liveBuckets: c?.stats?.liveBuckets),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.lg, AppSpace.gutter, 0),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _QuickAction(
                          icon: Icons.add_shopping_cart_rounded,
                          label: 'Start a bucket',
                          onTap: () => context.push('/create'),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        _QuickAction(icon: Icons.person_add_alt_1_rounded, label: 'Invite neighbours', onTap: () => _invite(c)),
                        const SizedBox(width: AppSpace.sm),
                        _QuickAction(
                          icon: Icons.forum_rounded,
                          label: 'Street chat',
                          onTap: c == null ? null : () => context.push('/chat/group/${Uri.encodeComponent(c.streetChannelId)}'),
                        ),
                      ],
                    ),
                  ),
                ),
                SectionHeader(
                  'Vendors asking to join',
                  subtitle: pending.isEmpty ? 'No requests right now' : 'Approved vendors can start buckets here',
                ),
                for (final v in pending)
                  _VendorRequest(
                    vendor: v,
                    decision: _decisions[v.id],
                    onApprove: () => _decide(v, _Decision.approved),
                    onDecline: () => _decide(v, _Decision.declined),
                  ),
                SectionHeader(
                  'Needs a nudge',
                  subtitle: d.nudges.isEmpty ? 'Every live bucket is on track' : 'Remind the street before these close',
                ),
                for (final n in d.nudges)
                  _NudgeCard(
                    nudge: n,
                    reminded: _reminded.contains(n.bucketId),
                    busy: _reminding.contains(n.bucketId),
                    onRemind: () => _remind(n),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CommunityHeader extends StatelessWidget {
  const _CommunityHeader({required this.community, required this.members, this.adminLine});

  final Community? community;
  final int members;
  final String? adminLine;

  @override
  Widget build(BuildContext context) {
    final c = community;
    final flats = c?.flats;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.sm, AppSpace.gutter, AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (adminLine != null) StatusPill(adminLine!, tone: PillTone.brand, icon: Icons.verified_user_outlined),
          const SizedBox(height: AppSpace.md),
          Text(c?.name ?? 'Your community', style: AppText.display.copyWith(fontSize: 26)),
          if (c != null && [c.area, c.city].whereType<String>().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text([c.area, c.city].whereType<String>().join(', '), style: AppText.bodyMuted),
          ],
          const SizedBox(height: AppSpace.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Fmt.number(members), style: AppText.priceLarge),
              const SizedBox(width: AppSpace.xs),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(flats == null ? 'members' : 'of ${Fmt.number(flats)} flats on Jugaad Street', style: AppText.caption),
              ),
            ],
          ),
          if (flats != null && flats > 0) ...[
            const SizedBox(height: AppSpace.sm),
            AppProgressBar(value: members / flats, height: 6),
          ],
        ],
      ),
    );
  }
}

class _SavedHero extends StatelessWidget {
  const _SavedHero({required this.saved, this.liveBuckets});

  final int saved;
  final int? liveBuckets;

  @override
  Widget build(BuildContext context) {
    final month = DateTime.now();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.lg, AppSpace.gutter, 0),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.xl),
        decoration: BoxDecoration(
          color: AppColors.saveTint,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(color: AppColors.save.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Saved together in ${months[month.month - 1]}', style: AppText.label.copyWith(color: AppColors.save)),
                  const SizedBox(height: AppSpace.xs),
                  Text(Fmt.rupees(saved), style: AppText.display.copyWith(fontSize: 34, color: AppColors.ink)),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    liveBuckets == null ? 'versus shop prices' : 'versus shop prices · $liveBuckets buckets live now',
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
              child: const Icon(Icons.savings_rounded, color: AppColors.save, size: 30),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardBorder,
          side: const BorderSide(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.lg, horizontal: AppSpace.sm),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: AppColors.brandTint, shape: BoxShape.circle),
                  child: Icon(icon, size: 20, color: AppColors.brand),
                ),
                const SizedBox(height: AppSpace.sm),
                Text(label, style: AppText.label, textAlign: TextAlign.center, maxLines: 2),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _VendorRequest extends StatelessWidget {
  const _VendorRequest({required this.vendor, required this.decision, required this.onApprove, required this.onDecline});

  final PendingVendor vendor;
  final _Decision? decision;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final v = vendor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, AppSpace.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChatAvatar(id: v.id, name: v.name, kind: 'vendor', size: 44),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.name, style: AppText.heading),
                      const SizedBox(height: 2),
                      Text(
                        [if (v.category != null) _cap(v.category!), v.place].whereType<String>().join(' · '),
                        style: AppText.caption,
                      ),
                      if (v.note != null) ...[const SizedBox(height: AppSpace.xs), Text(v.note!, style: AppText.body)],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            switch (decision) {
              null => Row(
                children: [
                  Expanded(
                    child: AppButton.ghost(label: 'Decline', onPressed: onDecline),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: AppButton(label: 'Approve', icon: Icons.check_rounded, onPressed: onApprove),
                  ),
                ],
              ),
              _Decision.approved => const StatusPill(
                'Approved · can start buckets',
                tone: PillTone.captured,
                icon: Icons.check_circle_outline,
              ),
              _Decision.declined => const StatusPill('Declined', tone: PillTone.released),
            },
          ],
        ),
      ),
    );
  }

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _NudgeCard extends StatelessWidget {
  const _NudgeCard({required this.nudge, required this.reminded, required this.busy, required this.onRemind});

  final Nudge nudge;
  final bool reminded;
  final bool busy;
  final VoidCallback onRemind;

  @override
  Widget build(BuildContext context) {
    final n = nudge;
    final left = n.cutoffAt == null ? null : Fmt.timeLeft(n.cutoffAt!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, AppSpace.md),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardBorder,
          side: const BorderSide(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/bucket/${n.bucketId}'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        n.title ?? 'Bucket',
                        style: AppText.heading.copyWith(fontSize: 15),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (left != null) StatusPill(left, tone: PillTone.held, icon: Icons.schedule_rounded),
                  ],
                ),
                const SizedBox(height: AppSpace.xs),
                Text(n.body, style: AppText.bodyMuted),
                const SizedBox(height: AppSpace.md),
                Row(
                  children: [
                    const ChatAvatar(id: ChatDirectory.botId, kind: 'bot', size: 24),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(child: Text('Posts as Jugaad Street in your Street chat', style: AppText.tiny)),
                    const SizedBox(width: AppSpace.sm),
                    SizedBox(
                      height: 48,
                      child: reminded
                          ? const Center(
                              child: StatusPill('Reminded', tone: PillTone.captured, icon: Icons.check_rounded),
                            )
                          : AppButton.secondary(
                              label: 'Remind',
                              icon: Icons.campaign_rounded,
                              expand: false,
                              loading: busy,
                              onPressed: busy ? null : onRemind,
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
