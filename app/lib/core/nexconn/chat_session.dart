import 'package:flutter/foundation.dart';

import '../config.dart';
import '../session/session_store.dart';
import 'nexconn_service.dart';

/// Glue between the app session and Nexconn: initialises the engine once and
/// connects with the session's Nexconn token. Safe to call repeatedly.
class ChatSession {
  ChatSession(this.session, this.nexconn);

  final SessionStore session;
  final NexconnService nexconn;

  Future<NexconnConnectResult?>? _inFlight;
  String? _connectedToken;

  /// Connects if logged in and not yet connected with the current token.
  Future<NexconnConnectResult?> ensureConnected() {
    final creds = session.nexconn;
    if (!session.isLoggedIn || creds == null || creds.token.isEmpty) return Future.value(null);
    if (_connectedToken == creds.token && nexconn.isConnected) {
      return Future.value(NexconnConnectResult(true, userId: nexconn.userId));
    }
    return _inFlight ??= _connect(creds.appKey.isEmpty ? AppConfig.nexconnAppKey : creds.appKey, creds.token)
        .whenComplete(() => _inFlight = null);
  }

  Future<NexconnConnectResult?> _connect(String appKey, String token) async {
    try {
      await nexconn.init(appKey: appKey);
      final r = await nexconn.connect(token);
      if (r.ok) _connectedToken = token;
      return r;
    } catch (e, st) {
      debugPrint('[chat] connect failed: $e\n$st');
      return NexconnConnectResult(false, code: -1, message: '$e');
    }
  }

  Future<void> signOut() async {
    _connectedToken = null;
    await nexconn.disconnect();
    await session.logout();
  }
}
