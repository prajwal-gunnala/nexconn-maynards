import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../core/nexconn/chat_session.dart';
import '../../core/nexconn/nexconn_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import 'js_bubbles.dart';

/// Shared ChatPage config: brand colours + our custom bubbles.
ChatPageConfig jsChatPageConfig({String? title, List<Widget>? actions}) => ChatPageConfig(
      appBarConfig: ChatAppBarConfig(
        title: title,
        centerTitle: false,
        backgroundColor: AppColors.surface,
        titleTextStyle: AppText.heading.copyWith(fontSize: 17),
        actions: actions,
      ),
      messageListConfig: const MessageListConfig(
        showSenderName: true,
        backgroundColor: AppColors.canvas,
        showNetworkStatusTip: true,
      ),
      customMessageBubbleBuilders: jsBubbleBuilders,
    );

/// A Nexconn group chat (Street group `street_<communityId>` or bucket group
/// `bucket_<bucketId>`) rendered with the UI kit's ChatPage and our
/// `js:*` custom bubbles.
class GroupChatScreen extends StatelessWidget {
  const GroupChatScreen({super.key, required this.channelId, this.title, this.direct = false});

  final String channelId;
  final String? title;

  /// Open as a direct (1:1) channel instead of a group.
  final bool direct;

  @override
  Widget build(BuildContext context) {
    final nx = context.read<NexconnService>();
    // ChatPage queries NCEngine on first build, so wait until we're connected
    // (the engine throws if it isn't initialized yet).
    return ValueListenableBuilder<NexconnState>(
      valueListenable: nx.state,
      builder: (context, st, _) {
        if (st != NexconnState.connected && !nx.hasConnectedOnce) {
          return _Connecting(failed: st == NexconnState.failed, title: title ?? _defaultTitle(channelId));
        }
        return _chat();
      },
    );
  }

  Widget _chat() {
    return ChatPage(
      key: ValueKey('chat-$channelId'),
      channel: direct ? DirectChannel(channelId) : GroupChannel(channelId),
      config: jsChatPageConfig(title: title ?? _defaultTitle(channelId)),
    );
  }

  static String _defaultTitle(String id) {
    if (id.startsWith('street_')) return 'Street chat';
    if (id.startsWith('bucket_')) return 'Bucket chat';
    return id;
  }
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
                const SizedBox(height: 12),
                TextButton(onPressed: () => context.read<ChatSession>().ensureConnected(), child: const Text('Retry')),
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text('Connecting to chat…', style: AppText.bodyMuted),
              ]),
      ),
    );
  }
}
