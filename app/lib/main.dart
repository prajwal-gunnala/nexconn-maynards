import 'dart:async';

import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import 'package:flutter/material.dart';

import 'core/config.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/api/local_backend.dart';
import 'core/nexconn/chat_session.dart';
import 'core/nexconn/nexconn_service.dart';
import 'core/session/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final api = await _buildApi();
  final session = await SessionStore.open(api);
  final nexconn = NexconnService(EngineProvider());
  final chat = ChatSession(session, nexconn);

  // Connect in the background if a session (or dev token) already exists.
  unawaited(chat.ensureConnected());

  runApp(JugaadStreetApp(api: api, session: session, nexconn: nexconn, chat: chat));
}


/// Standalone by default: the app answers its own API from the bundled demo snapshot (LocalBackend), so only Nexconn
/// (chat, calls) uses the network. Pass `--dart-define=API_BASE=http://…` to use a real server instead.
Future<ApiClient> _buildApi() async {
  if (const bool.hasEnvironment('API_BASE')) return ApiClient(baseUrl: AppConfig.apiBase);
  return ApiClient(baseUrl: 'http://local.jugaad', httpClient: await LocalBackend.load());
}
