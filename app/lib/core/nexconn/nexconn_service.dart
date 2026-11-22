import 'dart:async';

import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart' as nc show AreaCode, GroupChannel, SendMessageParams, TextMessageParams;
import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import 'package:flutter/foundation.dart';

import 'js_messages.dart';

/// A metadata change on one message (e.g. a `js:bucket` card's `p`/`s`/`u`).
class MetadataUpdate {
  const MetadataUpdate(this.messageId, this.metadata, {this.removedKeys = const []});

  /// Nexconn message UID (`Message.messageId`).
  final String messageId;

  /// The full merged metadata after the change.
  final Map<String, String> metadata;
  final List<String> removedKeys;
}

enum NexconnState { idle, initializing, connecting, connected, failed, disconnected }

class NexconnConnectResult {
  const NexconnConnectResult(this.ok, {this.code = 0, this.userId, this.message});

  final bool ok;
  final int code;
  final String? userId;
  final String? message;

  /// 31004: token invalid/expired — log in again.
  bool get badToken => code == 31004;
}

/// Wraps the Nexconn SDK and the Chat UI kit's [EngineProvider].
///
/// - [init] once at startup: initializes the engine (SG region) and registers
///   our custom message types (must happen after init, before connect).
/// - [connect] with the token from `/api/auth/verify`.
/// - [state] / [stateStream] for connection status.
/// - [watchMetadata] to follow live card updates for one messageId.
/// - [messages] for every new incoming message.
///
/// The UI kit keeps its own handlers; ours are registered under separate keys.
class NexconnService {
  NexconnService(this.engine);

  /// The UI kit's engine provider; pass the same instance to NexconnChatUIProviders.
  final EngineProvider engine;

  static const _handlerKey = 'jugaad_street';

  final state = ValueNotifier<NexconnState>(NexconnState.idle);
  final _stateCtrl = StreamController<NexconnState>.broadcast();
  final _metaCtrl = StreamController<MetadataUpdate>.broadcast();
  final _msgCtrl = StreamController<Message>.broadcast();

  /// Latest known metadata per messageId, so recycled list items render the
  /// newest values even if they were built from a stale Message object.
  final Map<String, Map<String, String>> _metaCache = {};

  String? _userId;
  String? get userId => _userId;
  bool get isConnected => state.value == NexconnState.connected;

  /// True after the first successful connect of this login (the SDK then
  /// reconnects on its own, and ChatPage can be shown while it does).
  bool get hasConnectedOnce => _connectedOnce;
  bool _connectedOnce = false;

  Stream<NexconnState> get stateStream => _stateCtrl.stream;
  Stream<MetadataUpdate> get metadataUpdates => _metaCtrl.stream;
  Stream<Message> get messages => _msgCtrl.stream;

  /// Live metadata for one message.
  Stream<MetadataUpdate> watchMetadata(String messageId) =>
      _metaCtrl.stream.where((u) => u.messageId == messageId);

  /// Newest metadata for [m]: message's own metadata overlaid with anything we
  /// received live since it was loaded.
  Map<String, String> metadataFor(Message m) {
    final id = m.messageId;
    final base = jsMetadata(m);
    final cached = id == null ? null : _metaCache[id];
    if (cached == null) return base;
    return {...base, ...cached};
  }

  /// Applies a card change we learned from our own API call (e.g. the response to this user's claim), so the
  /// claimer's card moves even if the push for it is slow. A later push simply overwrites it.
  void applyLocalMetadata(String? messageId, Map<String, String> changed) {
    if (messageId == null || messageId.isEmpty || changed.isEmpty) return;
    final merged = {...?_metaCache[messageId], ...changed};
    _metaCache[messageId] = merged;
    _metaCtrl.add(MetadataUpdate(messageId, merged));
  }

  /// Standalone mode: posts a plain text into a group (e.g. the Street) so chat reflects an in-app action that a
  /// server would otherwise announce. Best effort; never throws.
  Future<void> postText(String groupId, String text) async {
    if (!isConnected) return;
    try {
      await nc.GroupChannel(groupId).sendMessage(nc.SendMessageParams(messageParams: nc.TextMessageParams(text: text)));
    } catch (_) {}
  }

  bool _inited = false;
  Future<void>? _initFuture;

  Future<void> init({required String appKey}) => _initFuture ??= _init(appKey);

  Future<void> _init(String appKey) async {
    _set(NexconnState.initializing);
    await engine.initialize(InitParams(appKey: appKey, areaCode: nc.AreaCode.sg));
    for (final t in JsType.all) {
      final code = await NCEngine.registerCustomMessage(t, CustomMessagePersistentFlag.counted);
      if (code != 0) debugPrint('[nexconn] registerCustomMessage($t) -> $code');
    }
    _bind();
    _inited = true;
    _set(NexconnState.idle);
  }

  void _bind() {
    NCEngine.removeConnectionStatusHandler(_handlerKey);
    NCEngine.addConnectionStatusHandler(_handlerKey, (event) {
      debugPrint('[nexconn] connection status ${event.status}');
      switch (event.status) {
        case ConnectionStatus.connected:
          _set(NexconnState.connected);
        case ConnectionStatus.connecting:
          _set(NexconnState.connecting);
        case ConnectionStatus.tokenIncorrect:
        case ConnectionStatus.connUserBlocked:
        case ConnectionStatus.kickedOfflineByOtherClient:
          _set(NexconnState.failed);
        case ConnectionStatus.signOut:
        case ConnectionStatus.unconnected:
          _set(NexconnState.disconnected);
        default:
          break;
      }
    });

    NCEngine.removeMessageHandler(_handlerKey);
    NCEngine.addMessageHandler(
      _handlerKey,
      MessageHandler(
        onMessageReceived: (e) => _msgCtrl.add(e.message),
        onMessageMetadataUpdated: (e) {
          final m = e.message;
          final id = m?.messageId;
          debugPrint('[nexconn] metadata updated id=$id changed=${e.metadata} full=${m?.metadata}');
          if (id == null) return;
          // The cache is the source of truth: the event's message is a snapshot that can lag behind what we already
          // applied, so it only seeds an empty cache; the changed keys always win.
          final merged = <String, String>{
            ..._metaCache[id] ?? (m != null ? jsMetadata(m) : const <String, String>{}),
            ...?e.metadata?.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')),
          };
          _metaCache[id] = merged;
          _metaCtrl.add(MetadataUpdate(id, merged));
        },
        onMessageMetadataDeleted: (e) {
          final id = e.message?.messageId;
          if (id == null) return;
          final keys = e.keys ?? const [];
          final merged = {...?_metaCache[id], if (e.message != null) ...jsMetadata(e.message!)}
            ..removeWhere((k, _) => keys.contains(k));
          _metaCache[id] = merged;
          _metaCtrl.add(MetadataUpdate(id, merged, removedKeys: keys));
        },
      ),
    );
  }

  /// Connects with a user token. 34001 (already connected) counts as success.
  Future<NexconnConnectResult> connect(String token, {Duration timeout = const Duration(seconds: 20)}) async {
    if (!_inited) throw StateError('NexconnService.init() must be called first');
    _set(NexconnState.connecting);
    final done = Completer<NexconnConnectResult>();
    try {
      await engine.connect(
        ConnectParams(token: token),
        handler: (userId, error) {
          final code = error?.code ?? 0;
          final ok = code == 0 || code == 34001;
          if (!done.isCompleted) {
            done.complete(NexconnConnectResult(ok, code: code, userId: userId, message: error?.message));
          }
        },
      );
    } catch (e) {
      if (!done.isCompleted) done.complete(NexconnConnectResult(false, code: -1, message: '$e'));
    }
    final r = await done.future.timeout(
      timeout,
      onTimeout: () => const NexconnConnectResult(false, code: -2, message: 'Timed out connecting to chat'),
    );
    debugPrint('[nexconn] connect -> ok=${r.ok} code=${r.code} user=${r.userId}');
    if (r.ok) {
      _userId = r.userId ?? _userId;
      _connectedOnce = true;
      _set(NexconnState.connected);
    } else {
      _set(NexconnState.failed);
    }
    return r;
  }

  Future<void> disconnect() async {
    _metaCache.clear();
    _userId = null;
    _connectedOnce = false;
    if (_inited) await engine.disconnect();
    // The UI kit destroys the engine before the next initialize, so the next
    // login must call init() again (which re-registers our custom types).
    _inited = false;
    _initFuture = null;
    _set(NexconnState.disconnected);
  }

  /// Client-side metadata write (only works on messages sent with
  /// `hasMetadata`/canIncludeMetadata). Returns the error code (0 = ok).
  ///
  /// Verified on the emulator: it succeeds (0) on a server-sent `hasMetadata`
  /// card and other clients receive it, but the SDK does NOT fire
  /// `onMessageMetadataUpdated` for the sender's own change — so on success we
  /// emit the update locally. (Product rule: the server owns card metadata;
  /// the app should not normally call this.)
  Future<int> setMetadata(Message m, Map<String, String> metadata) async {
    final c = Completer<int>();
    final code = await m.setMetadata(metadata, (err) {
      if (!c.isCompleted) c.complete(err?.code ?? 0);
    });
    if (code != 0 && !c.isCompleted) c.complete(code);
    final result = await c.future;
    final id = m.messageId;
    if (result == 0 && id != null) {
      final merged = {...metadataFor(m), ...metadata};
      _metaCache[id] = merged;
      _metaCtrl.add(MetadataUpdate(id, merged));
    }
    return result;
  }

  void _set(NexconnState s) {
    if (state.value == s) return;
    state.value = s;
    _stateCtrl.add(s);
  }
}
