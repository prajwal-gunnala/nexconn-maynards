import 'dart:async';

import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/nexconn/chat_session.dart';
import 'core/nexconn/nexconn_service.dart';
import 'core/session/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final api = ApiClient(baseUrl: await _resolveApiBase());
  final session = await SessionStore.open(api);
  final nexconn = NexconnService(EngineProvider());
  final chat = ChatSession(session, nexconn);

  // Connect in the background if a session (or dev token) already exists.
  unawaited(chat.ensureConnected());

  runApp(JugaadStreetApp(api: api, session: session, nexconn: nexconn, chat: chat));
}


/// The demo API's address can move (hosted server for judges), so release builds read it from a tiny JSON file on
/// GitHub Pages ({"apiBase": "https://…"}), cache it, and fall back to the cached value or the build-time default.
Future<String> _resolveApiBase() async {
  const fromDefine = bool.hasEnvironment('API_BASE');
  if (fromDefine || AppConfig.remoteConfigUrl.isEmpty) return AppConfig.apiBase;
  final prefs = await SharedPreferences.getInstance();
  try {
    final res = await http.get(Uri.parse(AppConfig.remoteConfigUrl)).timeout(const Duration(seconds: 4));
    if (res.statusCode == 200) {
      final m = RegExp(r'"apiBase"\s*:\s*"([^"]+)"').firstMatch(res.body);
      if (m != null) {
        await prefs.setString('config.apiBase', m.group(1)!);
        return m.group(1)!;
      }
    }
  } catch (_) {}
  return prefs.getString('config.apiBase') ?? AppConfig.apiBase;
}
