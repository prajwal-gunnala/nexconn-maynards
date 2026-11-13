import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/nexconn/nexconn_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import 'chat_directory.dart';
import 'group_chat_screen.dart';
import 'js_bubbles.dart';

/// "Chats" tab: the UI kit's ChannelPage with our rows. The Street chat is
/// pinned on top, then bucket groups and direct chats (vendors, the bot) by
/// latest message. Names, titles and previews come from [ChatDirectory].
class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  /// Street chat first; everything else keeps the SDK's latest-first order.
  static List<BaseChannel> pinStreet(List<BaseChannel> channels) {
    final street = channels.where((c) => ChatDirectory.kindOf(c) == ChatChannelKind.street).toList();
    return [...street, ...channels.where((c) => !street.contains(c))];
  }

  @override
  Widget build(BuildContext context) {
    installChatHooks();
    final dir = ChatDirectory.of(context);
    return ChannelPage(
      config: ChannelConfig(
        appBarConfig: ChannelAppBarConfig(
          title: 'Chats',
          backgroundColor: AppColors.surface,
          titleTextStyle: AppText.title,
          titleSpacing: AppSpace.gutter,
        ),
        listConfig: const ChannelListConfig(backgroundColor: AppColors.surface),
        profileProvider: dir.kitProfile,
        itemConfig: ChannelItemConfig(
          backgroundColor: AppColors.surface,
          pinnedBackgroundColor: AppColors.surface,
          dividerColor: AppColors.line,
          dividerIndent: 80,
          avatarBuilder: (ctx, channel, _, _) => ChannelAvatar(
            channelId: channel.channelId,
            direct: channel.channelType == ChannelType.direct,
            size: 48,
          ),
          titleBuilder: (ctx, channel, _, _) => _ChannelTitle(channel: channel, dir: dir),
          lastMessageBuilder: (ctx, channel, _) => _ChannelPreview(channel: channel, dir: dir),
          timeStyle: AppText.tiny.copyWith(fontWeight: FontWeight.w500),
          unreadBadgeBuilder: (ctx, channel, count, _) => _UnreadBadge(count: count),
          showNotificationLevelIndicator: false,
        ),
      ),
      channelListDataProcessor: pinStreet,
      chatPageOpener: (ctx, channel) async {
        final type = channel.channelType == ChannelType.direct ? 'direct' : 'group';
        await ctx.push('/chat/$type/${Uri.encodeComponent(channel.channelId)}');
      },
      emptyBuilder: (_) => const _EmptyChats(),
    );
  }
}

class _ChannelTitle extends StatelessWidget {
  const _ChannelTitle({required this.channel, required this.dir});

  final BaseChannel channel;
  final ChatDirectory dir;

  @override
  Widget build(BuildContext context) {
    final direct = channel.channelType == ChannelType.direct;
    final kind = ChatDirectory.kindOf(channel);
    // Kick off the lookup; the ListenableBuilder redraws when it lands.
    dir.title(channel.channelId, direct: direct);
    return ListenableBuilder(
      listenable: dir,
      builder: (context, _) {
        final person = direct ? dir.person(channel.channelId) : null;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
            child: Text(
              dir.titleNow(channel.channelId, direct: direct, short: true),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.heading.copyWith(fontSize: 15),
            ),
          ),
          if (kind == ChatChannelKind.street) ...[
            const SizedBox(width: 6),
            const Icon(Icons.push_pin_rounded, size: 14, color: AppColors.brand, semanticLabel: 'Pinned'),
          ],
          if (kind == ChatChannelKind.bucket) ...[const SizedBox(width: 6), const _Tag('Bucket')],
          if (person != null && person.isVendor) ...[const SizedBox(width: 6), const _Tag('Vendor')],
        ]);
      },
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(AppRadius.chip)),
        child: Text(text, style: AppText.tiny.copyWith(fontSize: 10)),
      );
}

class _ChannelPreview extends StatelessWidget {
  const _ChannelPreview({required this.channel, required this.dir});

  final BaseChannel channel;
  final ChatDirectory dir;

  @override
  Widget build(BuildContext context) {
    final m = channel.latestMessage;
    final draft = channel.draft?.trim();
    final style = AppText.caption.copyWith(fontSize: 13);
    if (draft != null && draft.isNotEmpty) {
      return Text.rich(
        TextSpan(children: [
          TextSpan(text: 'Draft: ', style: style.copyWith(color: AppColors.brand)),
          TextSpan(text: draft, style: style),
        ]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    if (m == null) return Text('No messages yet', style: style);
    final js = jsPreviewText(m);
    final senderId = m.senderUserId;
    final me = context.read<NexconnService>().userId;
    final mine = m.direction == MessageDirection.send || (senderId != null && senderId == me);
    final showSender = js == null && channel.channelType == ChannelType.group && senderId != null;
    if (showSender && !mine) dir.resolve(senderId);
    final unread = (channel.unreadCount ?? 0) > 0;
    final body = (js ?? messageSummary(m)).replaceAll(RegExp(r'\s+'), ' ').trim();
    return ListenableBuilder(
      listenable: dir,
      builder: (context, _) {
        final who = !showSender ? null : mine ? 'You' : dir.person(senderId)?.name;
        return Text.rich(
          TextSpan(children: [
            if (who != null) TextSpan(text: '$who: ', style: style.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600)),
            TextSpan(text: body, style: unread ? style.copyWith(color: AppColors.ink) : style),
          ]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$count unread',
        excludeSemantics: true,
        child: Container(
          constraints: const BoxConstraints(minWidth: 22),
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(AppRadius.chip)),
          child: Text(
            count > 99 ? '99+' : '$count',
            style: AppText.tiny.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
      );
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.forum_outlined, size: 40, color: AppColors.inkMuted),
            const SizedBox(height: AppSpace.md),
            Text('No chats yet', style: AppText.heading),
            const SizedBox(height: AppSpace.xs),
            Text(
              'Your Street chat shows up here once you join your building.',
              style: AppText.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      );
}
