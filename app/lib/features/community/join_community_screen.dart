import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/session/session_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';

/// Screen 3 · Find your community. Search, pick, enter your flat, join.
class JoinCommunityScreen extends StatefulWidget {
  const JoinCommunityScreen({super.key});

  @override
  State<JoinCommunityScreen> createState() => _JoinCommunityScreenState();
}

class _JoinCommunityScreenState extends State<JoinCommunityScreen> {
  final _q = TextEditingController();
  Timer? _debounce;
  List<Community>? _results;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    try {
      final r = await context.read<ApiClient>().communities(q: _q.text.trim());
      if (mounted) setState(() => (_results = r, _error = null));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _join(Community c) async {
    final unit = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UnitSheet(community: c, initial: context.read<SessionStore>().user?.unit),
    );
    if (unit == null || !mounted) return;
    final session = context.read<SessionStore>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await context.read<ApiClient>().joinCommunity(c.id, unit: unit);
      final role = asJson(r['membership'])?['role']?.toString() ?? 'member';
      await session.setCommunity(c, unit: unit, role: role);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.xxl, AppSpace.xl, AppSpace.md),
            child: Text('Find your community', style: AppText.display),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
            child: TextField(
              controller: _q,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Society, street, office or hostel'),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), _search);
              },
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Expanded(
            child: _error != null
                ? Center(child: Text(_error!, style: AppText.bodyMuted))
                : _results == null
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
                        itemCount: _results!.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (_, i) {
                          final c = _results![i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(c.name, style: AppText.heading),
                            subtitle: Text(c.subtitle, style: AppText.caption),
                            trailing: SizedBox(
                              width: 84,
                              child: AppButton(label: 'Join', expand: false, onPressed: () => _join(c)),
                            ),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}

class _UnitSheet extends StatefulWidget {
  const _UnitSheet({required this.community, this.initial});
  final Community community;
  final String? initial;

  @override
  State<_UnitSheet> createState() => _UnitSheetState();
}

class _UnitSheetState extends State<_UnitSheet> {
  late final _ctrl = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.xl, AppSpace.xl, AppSpace.xl + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Join ${widget.community.name}', style: AppText.title),
        const SizedBox(height: AppSpace.sm),
        Text('Your flat or house number, so the vendor knows where to deliver.', style: AppText.bodyMuted),
        const SizedBox(height: AppSpace.lg),
        TextField(
          controller: _ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'B-1204'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpace.lg),
        AppButton(
          label: 'Join community',
          onPressed: _ctrl.text.trim().isEmpty ? null : () => Navigator.pop(context, _ctrl.text.trim()),
        ),
      ]),
    );
  }
}
