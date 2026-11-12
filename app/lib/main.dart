import 'dart:async';

import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/nexconn/chat_session.dart';
import 'core/nexconn/nexconn_service.dart';
import 'core/session/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final api = ApiClient();
  final session = await SessionStore.open(api);
  final nexconn = NexconnService(EngineProvider());
  final chat = ChatSession(session, nexconn);

  // Connect in the background if a session (or dev token) already exists.
  unawaited(chat.ensureConnected());

  runApp(JugaadStreetApp(api: api, session: session, nexconn: nexconn, chat: chat));
}
