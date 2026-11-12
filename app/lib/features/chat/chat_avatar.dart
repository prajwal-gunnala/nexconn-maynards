import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import 'chat_directory.dart';

/// Round avatar for chat: initials on a colour picked from the user id, a
/// storefront corner badge for vendors, and the brand "JS" mark for the bot.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({super.key, required this.id, this.name, this.kind, this.size = 40});

  final String id;
  final String? name;

  /// `member` | `admin` | `vendor` | `bot` (from `/api/users`).
  final String? kind;
  final double size;

  /// Muted, warm-leaning palette that sits well next to the brand orange.
  static const palette = <(Color bg, Color fg)>[
    (Color(0xFFFFE3D6), Color(0xFFB93A17)),
    (Color(0xFFDDEFE4), Color(0xFF16794A)),
    (Color(0xFFE1E8F7), Color(0xFF34558B)),
    (Color(0xFFF6E7C8), Color(0xFF8A5A00)),
    (Color(0xFFEDE1F5), Color(0xFF6B3F8E)),
    (Color(0xFFD9F0F1), Color(0xFF1D6E73)),
    (Color(0xFFF8DDE3), Color(0xFF9B2C48)),
    (Color(0xFFE6E9D2), Color(0xFF5B6420)),
  ];

  static (Color, Color) colorsFor(String id) {
    var h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return palette[h % palette.length];
  }

  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty && RegExp(r'[A-Za-z0-9]').hasMatch(w[0])).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  bool get _isBot => kind == 'bot' || id == ChatDirectory.botId;

  @override
  Widget build(BuildContext context) {
    final label = _isBot ? 'Jugaad Street' : (name ?? 'Neighbour');
    if (_isBot) {
      return Semantics(
        label: label,
        image: true,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.brand, AppColors.brandDeep],
            ),
          ),
          child: Text(
            'JS',
            style: AppText.label.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.36, letterSpacing: -0.5),
          ),
        ),
      );
    }
    final (bg, fg) = colorsFor(id);
    final circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        name == null ? '' : initialsOf(name!),
        style: AppText.label.copyWith(color: fg, fontWeight: FontWeight.w800, fontSize: size * 0.38),
      ),
    );
    return Semantics(
      label: label,
      image: true,
      excludeSemantics: true,
      child: kind != 'vendor'
          ? circle
          : Stack(clipBehavior: Clip.none, children: [
              circle,
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: size * 0.42,
                  height: size * 0.42,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Icon(Icons.storefront_rounded, size: size * 0.26, color: AppColors.brandDeep),
                ),
              ),
            ]),
    );
  }
}

/// [ChatAvatar] that looks the person up in the [ChatDirectory].
class ChatPersonAvatar extends StatelessWidget {
  const ChatPersonAvatar({super.key, required this.id, this.size = 40, this.fallbackName});

  final String id;
  final double size;
  final String? fallbackName;

  @override
  Widget build(BuildContext context) {
    final dir = ChatDirectory.of(context);
    final now = dir.person(id);
    if (now != null) return ChatAvatar(id: id, name: now.name, kind: now.kind, size: size);
    return FutureBuilder<ChatPerson?>(
      future: dir.resolve(id),
      builder: (context, s) =>
          ChatAvatar(id: id, name: s.data?.name ?? fallbackName, kind: s.data?.kind, size: size),
    );
  }
}
