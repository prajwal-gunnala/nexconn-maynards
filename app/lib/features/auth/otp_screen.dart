import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/nexconn/chat_session.dart';
import '../../core/session/session_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';

/// Screen 2b · OTP (demo code 1234). On success: save the session, connect
/// Nexconn with the server-issued token, pick up an existing membership, and
/// let the router redirect (join community, or home).
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.phone});

  final String phone;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;
  bool _needName = false;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final api = context.read<ApiClient>();
    final session = context.read<SessionStore>();
    final chat = context.read<ChatSession>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final r = await api.verifyOtp(widget.phone, _code.text, name: _needName ? _name.text.trim() : null);
      await session.signIn(r);
      // Restore the first membership, if any (seeded people are already members).
      try {
        final me = await api.me();
        if (me.memberships.isNotEmpty) {
          final m = me.memberships.first;
          await session.setCommunity(m.community, unit: m.unit, role: m.role);
        }
      } on ApiException catch (_) {}
      final res = await chat.ensureConnected();
      if (res != null && !res.ok) {
        messenger.showSnackBar(SnackBar(content: Text('Chat not connected (${res.code}). Retrying later.')));
      }
      // Router redirect takes it from here.
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'NAME_REQUIRED' || e.message.toLowerCase().contains('name')) {
        setState(() => _needName = true);
      }
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _code.text.length == 4 && (!_needName || _name.text.trim().isNotEmpty);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Enter the code we sent', style: AppText.display),
            const SizedBox(height: AppSpace.sm),
            Text('+91 ${widget.phone} · Demo code 1234', style: AppText.bodyMuted),
            const SizedBox(height: AppSpace.xxl),
            TextField(
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: AppText.display.copyWith(letterSpacing: 16),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              decoration: const InputDecoration(hintText: '••••'),
              onChanged: (v) {
                setState(() {});
                if (v.length == 4 && !_needName) _verify();
              },
            ),
            if (_needName) ...[
              const SizedBox(height: AppSpace.lg),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Your name'),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const Spacer(),
            AppButton(label: 'Verify', loading: _busy, onPressed: ready ? _verify : null),
          ]),
        ),
      ),
    );
  }
}
