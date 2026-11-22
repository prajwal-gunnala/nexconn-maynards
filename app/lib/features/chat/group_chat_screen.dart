import 'dart:async';

import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart' show GroupMembersByRoleQueryParams;
import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/images.dart';
import '../../core/nexconn/chat_session.dart';
import '../../core/nexconn/nexconn_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import '../call/call_screen.dart';
import 'chat_avatar.dart';
import 'chat_directory.dart';
import 'js_bubbles.dart';

/// Installs every Chat UI kit hook we use (idempotent).
void installChatHooks() {
  installJsKitHooks();
  JugaadKitHooks.avatarBuilder = (context, message, profile, size) {
    final id = message.senderUserId ?? message.userInfo?.userId ?? profile?.id;
    if (id == null || id.isEmpty) return null;
    final person = ChatDirectory.of(context).person(id);
    final labelName = profile?.name?.split(' · ').first;
    return ChatAvatar(id: id, name: person?.name ?? labelName, kind: person?.kind ?? profile?.extra, size: size);
  };
}

/// Shared ChatPage config: brand colours, our names/avatars and custom bubbles.
ChatPageConfig jsChatPageConfig(ChatDirectory dir, {String hint = 'Message your neighbours'}) => ChatPageConfig(
      profileProvider: dir.kitProfile,
      messageListConfig: const MessageListConfig(
        showSenderName: true,
        showAvatar: true,
        backgroundColor: AppColors.canvas,
        showNetworkStatusTip: true,
      ),
      bubbleConfig: BubbleConfig(
        sentStyle: MessageStyleConfig(
          backgroundColor: AppColors.brand,
          textColor: Colors.white,
          textStyle: AppText.body.copyWith(color: Colors.white, fontSize: 15),
        ),
        receivedStyle: MessageStyleConfig(
          backgroundColor: AppColors.surface,
          textColor: AppColors.ink,
          textStyle: AppText.body.copyWith(fontSize: 15),
        ),
        borderRadius: AppRadius.card,
        avatarConfig: const ChatAvatarConfig(size: 36),
      ),
      inputConfig: MessageInputConfig(hintText: hint),
      customMessageBubbleBuilders: jsBubbleBuilders,
    );

/// A Nexconn chat (Street group `street_<communityId>`, bucket group
/// `bucket_<bucketId>` or a direct chat) rendered with the UI kit's ChatPage,
/// our header, real names/avatars and the `js:*` custom bubbles.
class GroupChatScreen extends StatelessWidget {
  const GroupChatScreen({super.key, required this.channelId, this.title, this.direct = false});

  final String channelId;
  final String? title;

  /// Open as a direct (1:1) channel instead of a group.
  final bool direct;

  @override
  Widget build(BuildContext context) {
    installChatHooks();
    final nx = context.read<NexconnService>();
    final dir = ChatDirectory.of(context);
    // ChatPage queries NCEngine on first build, so wait until we're connected
    // (the engine throws if it isn't initialized yet).
    return ValueListenableBuilder<NexconnState>(
      valueListenable: nx.state,
      builder: (context, st, _) {
        if (st != NexconnState.connected && !nx.hasConnectedOnce) {
          return _Connecting(failed: st == NexconnState.failed, title: title ?? dir.titleNow(channelId, direct: direct));
        }
        final channel = direct ? DirectChannel(channelId) : GroupChannel(channelId);
        return ChatPage(
          key: ValueKey('chat-$channelId'),
          channel: channel,
          config: jsChatPageConfig(dir, hint: switch (ChatDirectory.kindOfId(channelId, direct: direct)) {
            ChatChannelKind.direct => 'Message',
            ChatChannelKind.bucket => 'Message the group',
            _ => 'Message your neighbours',
          }),
          appBarBuilder: (ctx, _) => ChatHeader(channelId: channelId, direct: direct, title: title),
          onMessageAvatarTap: (m) {
            final id = m.senderUserId;
            if (id != null) showPersonSheet(context, id);
          },
        );
      },
    );
  }
}

// ---- header -------------------------------------------------------------------------------------

/// Chat header: avatar, title, member count and an info action.
class ChatHeader extends StatefulWidget implements PreferredSizeWidget {
  const ChatHeader({super.key, required this.channelId, this.direct = false, this.title});

  final String channelId;
  final bool direct;
  final String? title;

  @override
  Size get preferredSize => const Size.fromHeight(65);

  @override
  State<ChatHeader> createState() => _ChatHeaderState();
}

class _ChatHeaderState extends State<ChatHeader> {
  late final ChatDirectory _dir = ChatDirectory.of(context);
  late final ChatChannelKind _kind = ChatDirectory.kindOfId(widget.channelId, direct: widget.direct);
  String get _ref => ChatDirectory.refOf(widget.channelId);

  @override
  void initState() {
    super.initState();
    _dir.addListener(_changed);
    switch (_kind) {
      case ChatChannelKind.street:
        _dir.community(_ref, refresh: true);
      case ChatChannelKind.bucket:
        _dir.bucket(_ref, refresh: true);
      case ChatChannelKind.direct:
        _dir.resolve(widget.channelId);
      case ChatChannelKind.other:
        break;
    }
  }

  @override
  void dispose() {
    _dir.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  String? get _subtitle {
    switch (_kind) {
      case ChatChannelKind.street:
        final c = _dir.communityNow(_ref);
        final members = c?.stats?.members ?? c?.memberCount;
        if (members == null) return 'Your building’s group chat';
        final live = c?.stats?.liveBuckets ?? 0;
        return '${Fmt.number(members)} neighbours${live > 0 ? ' · $live live' : ''}';
      case ChatChannelKind.bucket:
        final b = _dir.bucketNow(_ref);
        if (b == null) return 'Bucket group';
        final n = b.progress.members;
        return '$n ${n == 1 ? 'neighbour' : 'neighbours'}${b.vendor == null ? '' : ' + ${b.vendor!.name}'}';
      case ChatChannelKind.direct:
        final p = _dir.person(widget.channelId);
        if (p == null) return null;
        if (p.isBot) return 'Pickup codes and order updates';
        return p.isVendor ? 'Vendor' : p.unit == null ? null : 'Flat ${p.unit}';
      case ChatChannelKind.other:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final title = widget.title ?? _dir.titleNow(widget.channelId, direct: widget.direct);
    final subtitle = _subtitle;
    return AppBar(
      toolbarHeight: 64,
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      leadingWidth: provider.multiSelectMode ? 88 : 52,
      leading: provider.multiSelectMode
          ? TextButton(onPressed: () => provider.setMultiSelectMode(false), child: const Text('Cancel'))
          : IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
      title: Semantics(
        button: true,
        label: 'Chat info',
        child: InkWell(
          onTap: () => _showInfo(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
            child: Row(children: [
              ChannelAvatar(channelId: widget.channelId, direct: widget.direct, size: 40),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(title, style: AppText.heading, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Row(children: [
                    if (subtitle != null) ...[
                      Flexible(child: Text(subtitle, style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: AppSpace.xs + 2),
                    ],
                    const NexconnChip(),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
      actions: [
        if (_canCall) ...[
          IconButton(
            tooltip: _kind == ChatChannelKind.direct ? 'Voice call' : 'Group voice call',
            icon: const Icon(Icons.call_outlined),
            onPressed: () => _call(context, video: false),
          ),
          IconButton(
            tooltip: _kind == ChatChannelKind.direct ? 'Video call' : 'Group video call',
            icon: const Icon(Icons.videocam_outlined),
            onPressed: () => _call(context, video: true),
          ),
        ] else
          IconButton(
            tooltip: 'Chat info',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showInfo(context),
          ),
        const SizedBox(width: AppSpace.xs),
      ],
      bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
    );
  }

  /// Calls go to people: not to the bot's DM or unknown channel kinds.
  bool get _canCall => switch (_kind) {
        ChatChannelKind.direct => widget.channelId != ChatDirectory.botId && _dir.person(widget.channelId)?.isBot != true,
        ChatChannelKind.street || ChatChannelKind.bucket => true,
        ChatChannelKind.other => false,
      };

  /// 1-to-1 call in a direct chat; group call with the channel's members in a Street / bucket group.
  void _call(BuildContext context, {required bool video}) {
    final title = widget.title ?? _dir.titleNow(widget.channelId, direct: widget.direct);
    if (_kind == ChatChannelKind.direct) {
      startDirectCall(context, widget.channelId, title: title, video: video);
      return;
    }
    startGroupCall(context, widget.channelId, _groupMemberIds(), title: title, video: video);
  }

  /// Group members from Nexconn (group channel member query), plus bucket share holders from our server.
  Future<List<String>> _groupMemberIds({int cap = 16}) async {
    final ids = <String>{};
    if (_kind == ChatChannelKind.bucket) {
      for (final s in _dir.bucketNow(_ref)?.shares ?? const []) {
        ids.add(s.user.id);
      }
    }
    Future<void> page(GroupMemberRole role) async {
      final done = Completer<void>();
      final q = GroupChannel.createGroupMembersByRoleQuery(
        GroupMembersByRoleQueryParams(groupId: widget.channelId, role: role, pageSize: 50),
      );
      await q.loadNextPage((r, err) {
        for (final m in r?.data ?? const <GroupMemberInfo>[]) {
          final id = m.userId;
          if (id != null && id.isNotEmpty) ids.add(id);
        }
        if (!done.isCompleted) done.complete();
      });
      await done.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    }

    try {
      for (final role in [GroupMemberRole.owner, GroupMemberRole.admin, GroupMemberRole.normal]) {
        await page(role);
      }
    } catch (e) {
      debugPrint('[call] group member query failed: $e');
    }
    ids.remove(ChatDirectory.botId);
    final out = ids.where((id) => _dir.person(id)?.isBot != true).take(cap).toList();
    debugPrint('[call] group ${widget.channelId} members for call: $out');
    return out;
  }

  void _showInfo(BuildContext context) {
    if (_kind == ChatChannelKind.direct) {
      showPersonSheet(context, widget.channelId, showMessageButton: false);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ChannelInfoSheet(
        kind: _kind,
        ref: _ref,
        dir: _dir,
        outer: context,
        onSearch: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ChatMessageSearchPage(
            provider: context.read<ChatProvider>(),
            channel: GroupChannel(widget.channelId),
            title: 'Search messages',
          ),
        )),
      ),
    );
  }
}

class _ChannelInfoSheet extends StatelessWidget {
  const _ChannelInfoSheet({required this.kind, required this.ref, required this.dir, required this.outer, required this.onSearch});

  final ChatChannelKind kind;
  final String ref;
  final ChatDirectory dir;
  final BuildContext outer;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if (kind == ChatChannelKind.street) {
      final c = dir.communityNow(ref);
      children.addAll([
        Text(c == null ? 'Street chat' : ChatDirectory.streetTitle(c.name), style: AppText.title),
        if (c != null) ...[
          const SizedBox(height: AppSpace.xs),
          Text([c.name, c.subtitle].where((s) => s.isNotEmpty).join(' · '), style: AppText.bodyMuted),
          const SizedBox(height: AppSpace.lg),
          Row(children: [
            _Stat(label: 'Neighbours', value: Fmt.number(c.stats?.members ?? c.memberCount ?? 0)),
            const SizedBox(width: AppSpace.sm),
            _Stat(label: 'Live buckets', value: '${c.stats?.liveBuckets ?? 0}'),
            const SizedBox(width: AppSpace.sm),
            _Stat(label: 'Saved this month', value: Fmt.rupees(c.stats?.savedThisMonth ?? 0), tone: AppColors.save),
          ]),
        ],
        const SizedBox(height: AppSpace.lg),
        Text(
          'Everyone in your building is here. Bucket cards update live as neighbours join, and money is only held until a bucket fills.',
          style: AppText.body,
        ),
        const SizedBox(height: AppSpace.xl),
        AppButton(
          label: 'See live buckets',
          icon: Icons.shopping_basket_outlined,
          onPressed: () {
            Navigator.of(context).pop();
            outer.go('/buckets');
          },
        ),
        const SizedBox(height: AppSpace.sm),
        AppButton.ghost(
          label: 'Start a bucket',
          icon: Icons.add_rounded,
          onPressed: () {
            Navigator.of(context).pop();
            outer.push('/create');
          },
        ),
      ]);
    } else {
      final b = dir.bucketNow(ref);
      children.addAll([
        if (b != null) ...[
          ClipRRect(
            borderRadius: AppRadius.photoBorder,
            child: SizedBox(height: 120, width: double.infinity, child: _bucketPhoto(b.image)),
          ),
          const SizedBox(height: AppSpace.md),
        ],
        Text(b?.title ?? 'Bucket group', style: AppText.title),
        if (b != null) ...[
          const SizedBox(height: AppSpace.xs),
          Text(
            [b.vendor?.name, if (b.pickupPoint != null) 'Pickup ${b.pickupPoint}'].whereType<String>().join(' · '),
            style: AppText.bodyMuted,
          ),
          const SizedBox(height: AppSpace.lg),
          Row(children: [
            _Stat(label: 'Neighbours', value: '${b.progress.members}'),
            const SizedBox(width: AppSpace.sm),
            _Stat(label: 'Filled', value: '${b.progress.percentRounded}%'),
            if (b.deliverAt != null) ...[
              const SizedBox(width: AppSpace.sm),
              _Stat(label: 'Delivery', value: Fmt.day(b.deliverAt!).split(' ').take(2).join(' ')),
            ],
          ]),
        ],
        const SizedBox(height: AppSpace.lg),
        Text('Buyers and the vendor talk here about pickup time and questions.', style: AppText.body),
        const SizedBox(height: AppSpace.xl),
        AppButton(
          label: 'Open bucket',
          onPressed: () {
            Navigator.of(context).pop();
            outer.push('/bucket/$ref');
          },
        ),
        if (b?.orderId != null) ...[
          const SizedBox(height: AppSpace.sm),
          AppButton.ghost(
            label: 'View order ${b!.orderId}',
            onPressed: () {
              Navigator.of(context).pop();
              outer.push('/orders/${b.orderId}');
            },
          ),
        ],
      ]);
    }
    children.addAll([
      const SizedBox(height: AppSpace.sm),
      AppButton.ghost(
        label: 'Search messages',
        icon: Icons.search_rounded,
        onPressed: () {
          Navigator.of(context).pop();
          onSearch();
        },
      ),
    ]);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, AppSpace.lg),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.tone = AppColors.ink});

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: AppText.heading.copyWith(color: tone), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label, style: AppText.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      );
}

Widget _bucketPhoto(String? image) {
  final asset = AppImages.bucket(image);
  final fallback = Container(
    color: AppColors.brandTint,
    alignment: Alignment.center,
    child: const Icon(Icons.shopping_basket_rounded, color: AppColors.brandDeep),
  );
  return asset == null ? fallback : Image.asset(asset, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback);
}

/// Avatar for a channel: Street mark, bucket photo or the person.
class ChannelAvatar extends StatelessWidget {
  const ChannelAvatar({super.key, required this.channelId, this.direct = false, this.size = 48});

  final String channelId;
  final bool direct;
  final double size;

  @override
  Widget build(BuildContext context) {
    final kind = ChatDirectory.kindOfId(channelId, direct: direct);
    switch (kind) {
      case ChatChannelKind.street:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(size * 0.3)),
          child: Icon(Icons.apartment_rounded, size: size * 0.55, color: AppColors.brand),
        );
      case ChatChannelKind.bucket:
        final dir = ChatDirectory.of(context);
        final ref = ChatDirectory.refOf(channelId);
        final b = dir.bucketNow(ref);
        if (b == null) dir.bucket(ref);
        return ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.3),
          child: SizedBox.square(dimension: size, child: _bucketPhoto(b?.image)),
        );
      case ChatChannelKind.direct:
        return ChatPersonAvatar(id: channelId, size: size);
      case ChatChannelKind.other:
        return ChatAvatar(id: channelId, name: channelId, size: size);
    }
  }
}

/// Bottom sheet for a person: avatar, name, flat or vendor, and "Message".
Future<void> showPersonSheet(BuildContext context, String userId, {bool showMessageButton = true}) {
  final dir = ChatDirectory.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => FutureBuilder<ChatPerson?>(
      future: dir.resolve(userId),
      initialData: dir.person(userId),
      builder: (sheet, s) {
        final p = s.data;
        final me = context.read<NexconnService>().userId;
        final canMessage = showMessageButton && userId != me && !(p?.isBot ?? userId == ChatDirectory.botId);
        final sub = p == null
            ? ''
            : p.isBot
                ? 'Posts bucket cards, updates and your pickup codes'
                : p.isVendor
                    ? 'Vendor on Jugaad Street'
                    : p.unit == null
                        ? 'Neighbour'
                        : 'Flat ${p.unit}${p.kind == 'admin' ? ' · community admin' : ''}';
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, AppSpace.lg),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ChatAvatar(id: userId, name: p?.name, kind: p?.kind, size: 72),
              const SizedBox(height: AppSpace.md),
              Text(p?.name ?? '…', style: AppText.title, textAlign: TextAlign.center),
              const SizedBox(height: AppSpace.xs),
              Text(sub, style: AppText.bodyMuted, textAlign: TextAlign.center),
              if (canMessage) ...[
                const SizedBox(height: AppSpace.xl),
                AppButton(
                  label: 'Message ${p?.name.split(' ').first ?? ''}'.trim(),
                  icon: Icons.chat_bubble_outline_rounded,
                  onPressed: () {
                    Navigator.of(sheet).pop();
                    context.push('/chat/direct/${Uri.encodeComponent(userId)}');
                  },
                ),
              ],
            ]),
          ),
        );
      },
    ),
  );
}

class _Connecting extends StatelessWidget {
  const _Connecting({required this.failed, required this.title});

  final bool failed;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: failed
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                Text("Couldn't connect to chat", style: AppText.heading),
                const SizedBox(height: AppSpace.md),
                TextButton(onPressed: () => context.read<ChatSession>().ensureConnected(), child: const Text('Retry')),
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(),
                const SizedBox(height: AppSpace.md),
                Text('Connecting to chat…', style: AppText.bodyMuted),
              ]),
      ),
    );
  }
}


/// Small "Nexconn Chat · Call" badge under chat titles: what powers this conversation.
class NexconnChip extends StatelessWidget {
  const NexconnChip({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.brandTint,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Text(
          'Nexconn Chat · Call',
          style: AppText.tiny.copyWith(color: AppColors.brandDeep, fontSize: 10),
          maxLines: 1,
        ),
      );
}
