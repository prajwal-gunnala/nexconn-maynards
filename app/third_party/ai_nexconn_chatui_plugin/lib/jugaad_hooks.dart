// JUGAAD PATCH: host hooks for things the kit has no public config for.
// Added by Jugaad Street (see app/docs/NEXCONN_NOTES.md, "Kit patches").
// Every hook is optional; when null the kit behaves exactly as upstream.
import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:flutter/widgets.dart';

import 'models/chat_profile_info.dart';

/// Builds a sender avatar from the resolved [profile] (the kit only draws
/// `http` portrait URLs, else a stock icon).
typedef JugaadAvatarBuilder =
    Widget? Function(
      BuildContext context,
      Message message,
      ChatProfileInfo? profile,
      double size,
    );

class JugaadKitHooks {
  const JugaadKitHooks._();

  /// Messages that render as a centred system row (no avatar, sender name or
  /// status line) through their custom bubble builder, e.g. `js:event`.
  static bool Function(Message message)? isSystemRow;

  /// Sender avatar override (return null to fall back to the kit's avatar).
  static JugaadAvatarBuilder? avatarBuilder;

  /// Summary text for messages the kit can't describe (custom messages show
  /// `[customMessage]` upstream). Used by [messageSummary], so reply previews,
  /// the default channel list and search results pick it up.
  static String? Function(Message message)? summary;
}
