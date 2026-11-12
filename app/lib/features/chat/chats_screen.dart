import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

/// "Chats" tab: the UI kit's channel list. Tapping a group opens our
/// [GroupChatScreen] (so js:* bubbles render); direct chats open the same way.
class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChannelPage(
      config: const ChannelConfig(
        appBarConfig: ChannelAppBarConfig(title: 'Chats'),
      ),
      chatPageOpener: (ctx, channel) async {
        final type = channel.channelType == ChannelType.group ? 'group' : 'direct';
        await ctx.push('/chat/$type/${Uri.encodeComponent(channel.channelId)}');
      },
      emptyBuilder: (_) => Center(child: Text('No chats yet', style: AppText.bodyMuted)),
    );
  }
}
