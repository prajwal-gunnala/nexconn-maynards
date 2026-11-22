import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'dart:async';

import 'core/api/api_client.dart';
import 'core/call/call_service.dart';
import 'core/nexconn/chat_session.dart';
import 'core/nexconn/nexconn_service.dart';
import 'core/session/session_store.dart';
import 'core/theme/app_theme.dart';
import 'features/call/call_screen.dart';
import 'features/splash/splash_screen.dart';
import 'router.dart';

/// Root widget. Provides (read with `context.read<T>()`):
/// [ApiClient], [SessionStore], [NexconnService], [ChatSession], plus the UI
/// kit's EngineProvider / NexconnThemeProvider (via NexconnChatUIProviders).
class JugaadStreetApp extends StatefulWidget {
  const JugaadStreetApp({
    super.key,
    required this.api,
    required this.session,
    required this.nexconn,
    required this.chat,
  });

  final ApiClient api;
  final SessionStore session;
  final NexconnService nexconn;
  final ChatSession chat;

  @override
  State<JugaadStreetApp> createState() => _JugaadStreetAppState();
}

class _JugaadStreetAppState extends State<JugaadStreetApp> {
  late final GoRouter _router = buildRouter(widget.session);
  final _chatTheme = NexconnThemeProvider(mode: NexconnThemeMode.custom)..setCustomTheme(AppTheme.chatTokens);

  /// Nexconn Call SDK (native). Initialises itself once chat connects; incoming calls open the call screen.
  late final CallService _calls = CallService.instance ??= CallService(widget.nexconn);
  StreamSubscription<CallInfo>? _incomingSub;

  @override
  void initState() {
    super.initState();
    _incomingSub = _calls.incoming.listen((_) => showCallScreen(_calls));
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: widget.api),
        ChangeNotifierProvider.value(value: widget.session),
        Provider.value(value: widget.nexconn),
        Provider.value(value: widget.chat),
        Provider.value(value: _calls),
      ],
      child: NexconnChatUIProviders(
        engineProvider: widget.nexconn.engine,
        themeProvider: _chatTheme,
        child: MaterialApp.router(
          title: 'Jugaad Street',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          routerConfig: _router,
          // Brand splash: plays once over the first screen on cold start, continuing the native launch
          // screen (SessionStore is already open by now; the router builds underneath). Not routing.
          builder: (context, child) => SplashOverlay(child: child ?? const SizedBox.shrink()),
          locale: nexconnChatUIDefaultLocale,
          localizationsDelegates: NexconnChatUILocalizations.localizationsDelegates,
          supportedLocales: NexconnChatUILocalizations.supportedLocales,
        ),
      ),
    );
  }
}
