import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/session/session_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';

/// Find your community: search, pick one, enter your flat, join. Also takes an
/// invite code. After joining, the router moves on to Street home (or, when
/// opened from the community switcher with [popOnJoin], this screen closes).
class JoinCommunityScreen extends StatefulWidget {
  const JoinCommunityScreen({super.key, this.popOnJoin = false});

  final bool popOnJoin;

  @override
  State<JoinCommunityScreen> createState() => _JoinCommunityScreenState();
}

class _JoinCommunityScreenState extends State<JoinCommunityScreen> {
  final _q = TextEditingController();
  late final TextEditingController _unit;
  final _unitFocus = FocusNode();
  Timer? _debounce;
  List<Community>? _results;
  String? _error;
  Community? _picked;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<SessionStore>();
    _unit = TextEditingController(text: s.unit ?? s.user?.unit ?? '');
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    _unit.dispose();
    _unitFocus.dispose();
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

  void _pick(Community c) {
    setState(() => _picked = _picked?.id == c.id ? null : c);
    if (_picked != null && _unit.text.trim().isEmpty) _unitFocus.requestFocus();
  }

  Future<void> _join() async {
    final c = _picked;
    final unit = _unit.text.trim().toUpperCase();
    if (c == null || unit.isEmpty) return;
    final session = context.read<SessionStore>();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final router = GoRouter.of(context);
    setState(() => _busy = true);
    try {
      final r = await context.read<ApiClient>().joinCommunity(c.id, unit: unit);
      final role = asJson(r['membership'])?['role']?.toString() ?? 'member';
      await session.setCommunity(c, unit: unit, role: role);
      if (widget.popOnJoin && nav.canPop()) {
        nav.pop();
      } else {
        router.go('/street');
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _inviteCode() async {
    final api = context.read<ApiClient>();
    final found = await showModalBottomSheet<Community>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _InviteSheet(api: api),
    );
    if (found != null && mounted) {
      setState(() {
        _results = [found, ...?_results?.where((c) => c.id != found.id)];
        _picked = found;
      });
      _unitFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    final canJoin = picked != null && _unit.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: widget.popOnJoin ? AppBar() : null,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.xl, AppSpace.xl, AppSpace.lg),
              children: [
                Semantics(header: true, child: Text('Find your community', style: AppText.display)),
                const SizedBox(height: AppSpace.sm),
                Text('Everyone in your society buys together in one Street chat.', style: AppText.bodyMuted),
                const SizedBox(height: AppSpace.xl),
                TextField(
                  controller: _q,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.inkMuted),
                    hintText: 'Search by name or area',
                  ),
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 300), _search);
                  },
                ),
                const SizedBox(height: AppSpace.lg),
                if (_error != null)
                  Padding(padding: const EdgeInsets.all(AppSpace.lg), child: Text(_error!, style: AppText.bodyMuted, textAlign: TextAlign.center))
                else if (_results == null)
                  const Padding(padding: EdgeInsets.all(AppSpace.xxl), child: Center(child: CircularProgressIndicator()))
                else if (_results!.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
                    child: Text('No community by that name yet. Try your area, or use an invite code.',
                        style: AppText.bodyMuted, textAlign: TextAlign.center),
                  )
                else
                  for (final c in _results!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.md),
                      child: _CommunityCard(community: c, selected: picked?.id == c.id, onTap: () => _pick(c)),
                    ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: picked == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: AppSpace.sm),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Your flat or house number', style: AppText.label.copyWith(color: AppColors.inkMuted)),
                            const SizedBox(height: AppSpace.sm),
                            TextField(
                              controller: _unit,
                              focusNode: _unitFocus,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(hintText: 'e.g. B-1204', prefixIcon: Icon(Icons.door_front_door_outlined)),
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) => _join(),
                            ),
                            const SizedBox(height: AppSpace.xs),
                            Text('So the vendor knows where to drop your share.', style: AppText.caption),
                          ]),
                        ),
                ),
                const SizedBox(height: AppSpace.lg),
                _LinkRow(icon: Icons.confirmation_number_outlined, label: 'Have an invite code?', onTap: _inviteCode),
              ],
            ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.md, AppSpace.xl, AppSpace.md),
              child: AppButton(
                label: picked == null ? 'Pick your community' : 'Join ${picked.name}',
                loading: _busy,
                onPressed: canJoin ? _join : null,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  const _CommunityCard({required this.community, required this.selected, required this.onTap});

  final Community community;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = community;
    final members = c.stats?.members ?? c.memberCount;
    final kind = c.kind == null ? null : c.kind![0].toUpperCase() + c.kind!.substring(1);
    final place = c.area ?? c.city ?? '';
    final line = [?kind, if (place.isNotEmpty) place].join(' · ');
    return Semantics(
      selected: selected,
      button: true,
      label: '${c.name}, $line',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandTint : AppColors.surface,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(color: selected ? AppColors.brand : AppColors.line, width: selected ? 1.5 : 1),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: AppRadius.cardBorder,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.surface : AppColors.brandTint,
                    borderRadius: BorderRadius.circular(AppRadius.photo),
                  ),
                  child: Icon(
                    c.kind == 'office' ? Icons.business_rounded : (c.kind == 'hostel' ? Icons.bed_rounded : Icons.apartment_rounded),
                    color: AppColors.brand,
                    size: 26,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.name, style: AppText.heading, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text([line, if (c.flats != null) '${c.flats} flats'].where((s) => s.isNotEmpty).join(' · '),
                        style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: members == null || members == 0 ? AppColors.inkMuted : AppColors.save, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        members == null || members == 0 ? 'Be the first on Jugaad Street' : '$members on Jugaad Street',
                        style: AppText.tiny.copyWith(color: members == null || members == 0 ? AppColors.inkMuted : AppColors.save, fontWeight: FontWeight.w700),
                      ),
                    ]),
                  ]),
                ),
                const SizedBox(width: AppSpace.sm),
                Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: selected ? AppColors.brand : const Color(0xFFD6CDC7), size: 24),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.photo),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.photo), border: Border.all(color: AppColors.line)),
        child: Row(children: [
          Icon(icon, color: AppColors.brand, size: 20),
          const SizedBox(width: AppSpace.md),
          Expanded(child: Text(label, style: AppText.label.copyWith(fontSize: 14))),
          const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
        ]),
      ),
    );
  }
}

class _InviteSheet extends StatefulWidget {
  const _InviteSheet({required this.api});

  final ApiClient api;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => (_busy = true, _error = null));
    try {
      final all = await widget.api.communities();
      final match = all.where((c) => c.inviteCode?.toUpperCase() == code || c.id.toUpperCase() == code).firstOrNull;
      if (!mounted) return;
      if (match != null) {
        Navigator.pop(context, match);
      } else {
        setState(() => _error = "That code doesn't match a community. Check it with whoever sent it.");
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.xl + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Enter invite code', style: AppText.title),
        const SizedBox(height: AppSpace.sm),
        Text('A neighbour or your society admin can share it from the Street chat.', style: AppText.bodyMuted),
        const SizedBox(height: AppSpace.lg),
        TextField(
          controller: _ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: AppText.heading.copyWith(letterSpacing: 2),
          decoration: InputDecoration(hintText: 'SEABREEZE', errorText: _error, errorMaxLines: 2),
          onSubmitted: (_) => _find(),
        ),
        const SizedBox(height: AppSpace.lg),
        AppButton(label: 'Find community', loading: _busy, onPressed: _find),
      ]),
    );
  }
}
