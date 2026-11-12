import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/models/models.dart';
import '../../core/nexconn/chat_session.dart';
import '../../core/nexconn/nexconn_service.dart';
import '../../core/session/session_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import '../bucket/bucket_card.dart';

/// Street home: community header, savings, Street chat entry, live buckets.
/// (Screen "Street home" on the design board; category grid etc. still to do.)
class StreetHomeScreen extends StatefulWidget {
  const StreetHomeScreen({super.key});

  @override
  State<StreetHomeScreen> createState() => _StreetHomeScreenState();
}

class _StreetHomeScreenState extends State<StreetHomeScreen> {
  Future<(Community?, List<Bucket>)>? _load;

  @override
  void initState() {
    super.initState();
    _load = _fetch();
  }

  Future<(Community?, List<Bucket>)> _fetch() async {
    final s = context.read<SessionStore>();
    final api = context.read<ApiClient>();
    if (s.isDev || s.community == null) return (s.community, <Bucket>[]);
    final c = await api.community(s.community!.id);
    final b = await api.buckets(s.community!.id);
    return (c, b);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SessionStore>();
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() => _load = _fetch());
            await _load;
          },
          child: FutureBuilder(
            future: _load,
            builder: (context, snap) {
              final c = snap.data?.$1 ?? s.community;
              final buckets = snap.data?.$2 ?? const <Bucket>[];
              return ListView(padding: const EdgeInsets.only(bottom: AppSpace.xxxl), children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.lg, AppSpace.gutter, 0),
                  child: Row(children: [
                    const Icon(Icons.location_on, color: AppColors.brand, size: 20),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c?.name ?? 'Your street', style: AppText.heading),
                        Text([s.user?.name, s.unit].whereType<String>().join(' · '), style: AppText.caption),
                      ]),
                    ),
                    const _ChatDot(),
                    IconButton(
                      tooltip: 'Sign out',
                      icon: const Icon(Icons.logout, size: 20),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (d) => AlertDialog(
                            title: const Text('Sign out?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Sign out')),
                            ],
                          ),
                        );
                        if (ok == true && context.mounted) await context.read<ChatSession>().signOut();
                      },
                    ),
                  ]),
                ),
                if (c?.stats != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.lg, AppSpace.gutter, 0),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpace.lg),
                      decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: AppRadius.cardBorder),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Your street saved', style: AppText.caption.copyWith(color: AppColors.brandDeep)),
                            Text(Fmt.rupees(c!.stats!.savedThisMonth), style: AppText.display.copyWith(color: AppColors.brandDeep)),
                            Text('this month · ${c.stats!.members} members', style: AppText.caption),
                          ]),
                        ),
                        Text('${c.stats!.liveBuckets}\nlive', textAlign: TextAlign.center, style: AppText.heading),
                      ]),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.lg, AppSpace.gutter, 0),
                  child: AppButton.secondary(
                    label: 'Open Street chat',
                    icon: Icons.forum_outlined,
                    onPressed: s.streetChannelId == null
                        ? null
                        : () => context.push('/chat/group/${s.streetChannelId}?title=${Uri.encodeComponent(c?.name ?? 'Street chat')}'),
                  ),
                ),
                SectionHeader('Live buckets', subtitle: 'Join before the cutoff', action: 'Start one', onAction: () => context.push('/create')),
                if (snap.connectionState == ConnectionState.waiting)
                  const Padding(padding: EdgeInsets.all(AppSpace.xxl), child: Center(child: CircularProgressIndicator()))
                else if (snap.hasError)
                  Padding(
                    padding: const EdgeInsets.all(AppSpace.gutter),
                    child: Text(snap.error is ApiException ? (snap.error as ApiException).message : '${snap.error}', style: AppText.bodyMuted),
                  )
                else if (buckets.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpace.gutter),
                    child: Text(s.isDev ? 'Dev mode: no server session. Open the Street chat above.' : 'No live buckets yet.', style: AppText.bodyMuted),
                  )
                else
                  for (final b in buckets)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, AppSpace.md),
                      child: BucketCard(bucket: b),
                    ),
              ]);
            },
          ),
        ),
      ),
    );
  }
}

/// Green/grey dot for the Nexconn connection.
class _ChatDot extends StatelessWidget {
  const _ChatDot();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: context.read<NexconnService>().state,
      builder: (_, st, _) => Tooltip(
        message: 'Chat: ${st.name}',
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: st == NexconnState.connected ? AppColors.save : (st == NexconnState.failed ? AppColors.danger : AppColors.line),
          ),
        ),
      ),
    );
  }
}
