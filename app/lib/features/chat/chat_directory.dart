import 'dart:async';

import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/session/session_store.dart';

/// Display profile from `GET /api/users?ids=` (docs/CONTRACT.md).
class ChatPerson {
  const ChatPerson({required this.id, required this.name, required this.kind, required this.label, this.unit});

  final String id;
  final String name;
  final String? unit;

  /// `member` | `admin` | `vendor` | `bot`
  final String kind;

  /// `Ravi · C-801`, `Murugan Fish Stall · vendor`, `Jugaad Street`.
  final String label;

  bool get isBot => kind == 'bot' || id == ChatDirectory.botId;
  bool get isVendor => kind == 'vendor';

  factory ChatPerson.fromJson(Json j) {
    final name = asString(j['name']);
    return ChatPerson(
      id: asString(j['id']),
      name: name,
      unit: asStringOrNull(j['unit']),
      kind: asString(j['kind'], 'member'),
      label: asString(j['label'], name),
    );
  }
}

/// What a chat channel is about: Street group, bucket group or a direct chat.
enum ChatChannelKind { street, bucket, direct, other }

/// Names, portraits and titles for chat: people (batched `/api/users`),
/// buckets behind `bucket_<id>` groups and communities behind `street_<id>`.
///
/// One cache per [ApiClient]; get it with [ChatDirectory.of]. Listeners are
/// notified when new profiles arrive so rows can redraw with real names.
class ChatDirectory extends ChangeNotifier {
  ChatDirectory(this.api, {this.session});

  static const botId = 'jugaad_bot';

  static final _byApi = Expando<ChatDirectory>('chatDirectory');

  /// The shared directory for this app's [ApiClient].
  static ChatDirectory of(BuildContext context) {
    final api = context.read<ApiClient>();
    SessionStore? session;
    try {
      session = context.read<SessionStore>();
    } on ProviderNotFoundException {
      session = null;
    }
    final d = _byApi[api] ??= ChatDirectory(api, session: session);
    d.session ??= session;
    return d;
  }

  final ApiClient api;
  SessionStore? session;

  // ---- people ---------------------------------------------------------------------------------

  final Map<String, ChatPerson> _people = {};
  final Set<String> _missing = {};
  final Set<String> _queued = {};
  Completer<void>? _batch;

  ChatPerson? person(String? id) => id == null ? null : _people[id];

  /// Resolves one person; requests made within a few ms go out as one call.
  Future<ChatPerson?> resolve(String? id) async {
    if (id == null || id.isEmpty) return null;
    final hit = _people[id];
    if (hit != null || _missing.contains(id)) return hit;
    _queued.add(id);
    final batch = _batch ??= Completer<void>();
    if (_queued.length == 1) Timer(const Duration(milliseconds: 25), _flush);
    await batch.future;
    return _people[id];
  }

  /// Loads several people at once (e.g. everyone in a packing list).
  Future<void> prefetch(Iterable<String?> ids) => Future.wait(ids.whereType<String>().toSet().map(resolve));

  Future<void> _flush() async {
    final ids = _queued.toList();
    _queued.clear();
    final done = _batch;
    _batch = null;
    if (ids.isEmpty) {
      done?.complete();
      return;
    }
    try {
      final res = await api.get('/api/users', query: {'ids': ids.join(',')});
      if (res is List) {
        for (final e in res.whereType<Map>()) {
          final p = ChatPerson.fromJson(e.cast<String, dynamic>());
          if (p.id.isNotEmpty) _people[p.id] = p;
        }
      }
      _missing.addAll(ids.where((id) => !_people.containsKey(id)));
      notifyListeners();
    } catch (e) {
      debugPrint('[chat] /api/users failed: $e');
    } finally {
      done?.complete();
    }
  }

  // ---- buckets & communities ------------------------------------------------------------------

  final Map<String, Bucket> _buckets = {};
  final Map<String, Future<Bucket?>> _bucketLoads = {};
  final Map<String, Community> _communities = {};
  final Map<String, Future<Community?>> _communityLoads = {};

  Bucket? bucketNow(String id) => _buckets[id];

  /// Cached bucket (fetched once); pass [refresh] for live counts.
  Future<Bucket?> bucket(String id, {bool refresh = false}) {
    if (refresh) _bucketLoads.remove(id);
    return _bucketLoads.putIfAbsent(id, () async {
      try {
        final b = await api.bucket(id);
        _buckets[id] = b;
        notifyListeners();
        return b;
      } catch (e) {
        _bucketLoads.remove(id);
        return _buckets[id];
      }
    });
  }

  Community? communityNow(String id) {
    final c = _communities[id];
    if (c != null) return c;
    final mine = session?.community;
    return mine != null && mine.id == id ? mine : null;
  }

  Future<Community?> community(String id, {bool refresh = false}) {
    if (refresh) _communityLoads.remove(id);
    return _communityLoads.putIfAbsent(id, () async {
      try {
        final c = await api.community(id);
        _communities[id] = c;
        notifyListeners();
        return c;
      } catch (e) {
        _communityLoads.remove(id);
        return communityNow(id);
      }
    });
  }

  // ---- channels -------------------------------------------------------------------------------

  static ChatChannelKind kindOf(BaseChannel c) => kindOfId(c.channelId, direct: c.channelType == ChannelType.direct);

  static ChatChannelKind kindOfId(String id, {bool direct = false}) {
    if (direct) return ChatChannelKind.direct;
    if (id.startsWith('street_')) return ChatChannelKind.street;
    if (id.startsWith('bucket_')) return ChatChannelKind.bucket;
    return ChatChannelKind.other;
  }

  /// `street_c_seabreeze` → `c_seabreeze`; `bucket_b_seer` → `b_seer`.
  /// Bucket groups may carry a seed tag (`bucket_b_seer__k3x9`); the tag is dropped.
  static String refOf(String channelId) {
    final i = channelId.indexOf('_');
    final ref = i < 0 ? channelId : channelId.substring(i + 1);
    final t = ref.indexOf('__');
    return t < 0 ? ref : ref.substring(0, t);
  }

  /// "Sea Breeze Towers" → "Sea Breeze Street".
  static String streetTitle(String communityName) {
    const suffixes = ['Towers', 'Tower', 'Apartments', 'Apartment', 'Residency', 'Society', 'Enclave', 'Heights', 'Homes'];
    var name = communityName.trim();
    for (final s in suffixes) {
      if (name.endsWith(' $s')) {
        name = name.substring(0, name.length - s.length - 1);
        break;
      }
    }
    return name.isEmpty ? 'Street chat' : '$name Street';
  }

  /// "Kasimedu Book & Meet: Whole Paarai" → "Whole Paarai";
  /// "Aged Basmati Rice (1121)" → "Aged Basmati Rice". For tight list rows.
  static String shortBucketTitle(String title) {
    var t = title.trim();
    final colon = t.indexOf(': ');
    if (colon > 0 && colon < t.length - 3) t = t.substring(colon + 2);
    t = t.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '');
    final comma = t.indexOf(', ');
    if (t.length > 18 && comma > 3) t = t.substring(0, comma);
    return t.isEmpty ? title : t;
  }

  /// Best title available right now (no network). [short] trims bucket titles for list rows.
  String titleNow(String channelId, {bool direct = false, bool short = false}) {
    final ref = refOf(channelId);
    return switch (kindOfId(channelId, direct: direct)) {
      ChatChannelKind.street => communityNow(ref) == null ? 'Street chat' : streetTitle(communityNow(ref)!.name),
      ChatChannelKind.bucket => _buckets[ref] == null
          ? 'Bucket chat'
          : short
              ? shortBucketTitle(_buckets[ref]!.title)
              : _buckets[ref]!.title,
      ChatChannelKind.direct => _people[channelId]?.name ?? (channelId == botId ? 'Jugaad Street' : 'Chat'),
      ChatChannelKind.other => channelId,
    };
  }

  /// Title once names have loaded.
  Future<String> title(String channelId, {bool direct = false}) async {
    final ref = refOf(channelId);
    switch (kindOfId(channelId, direct: direct)) {
      case ChatChannelKind.street:
        if (communityNow(ref) == null) await community(ref);
      case ChatChannelKind.bucket:
        await bucket(ref);
      case ChatChannelKind.direct:
        await resolve(channelId);
      case ChatChannelKind.other:
        break;
    }
    return titleNow(channelId, direct: direct);
  }

  /// For the kit's `profileProvider`: the sender's label for messages and the
  /// channel title otherwise.
  Future<ChatProfileInfo?> kitProfile(BaseChannel channel, {Message? message}) async {
    if (message != null) {
      final id = message.senderUserId ?? message.userInfo?.userId;
      final p = await resolve(id);
      if (p == null) return id == null ? null : ChatProfileInfo(id: id, name: _fallbackName(id));
      return ChatProfileInfo(id: p.id, name: p.label, extra: p.kind);
    }
    final direct = channel.channelType == ChannelType.direct;
    return ChatProfileInfo(id: channel.channelId, name: await title(channel.channelId, direct: direct));
  }

  static String _fallbackName(String id) => id == botId ? 'Jugaad Street' : 'Neighbour';
}
