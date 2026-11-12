import 'dart:async';

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

/// OTP (demo code 1234). On success: save the session, connect Nexconn with the
/// server-issued token, pick up an existing membership, and let the router
/// redirect (join community, or home). New numbers are asked for a name when
/// the server answers NAME_REQUIRED.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.phone});

  final String phone;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _len = 4;
  static const _resendAfter = 30;

  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  final _name = TextEditingController();
  bool _busy = false;
  bool _needName = false;
  String? _error;
  int _resendIn = _resendAfter;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _codeFocus.addListener(() => setState(() {}));
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendIn = _resendAfter);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _codeFocus.dispose();
    _name.dispose();
    super.dispose();
  }

  String get _prettyPhone {
    final p = widget.phone;
    return p.length == 10 ? '+91 ${p.substring(0, 5)} ${p.substring(5)}' : '+91 $p';
  }

  Future<void> _resend() async {
    try {
      await context.read<ApiClient>().requestOtp(widget.phone);
      _startTimer();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New code sent')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _verify() async {
    if (_busy) return;
    final api = context.read<ApiClient>();
    final session = context.read<SessionStore>();
    final chat = context.read<ChatSession>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => (_busy = true, _error = null));
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
        messenger.showSnackBar(const SnackBar(content: Text('Chat is reconnecting. Your buckets work meanwhile.')));
      }
      // Router redirect takes it from here.
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'NAME_REQUIRED') {
        setState(() => _needName = true);
      } else {
        setState(() => _error = e.code == 'OTP_INVALID' ? "That code didn't match. Try again." : e.message);
        _code.clear();
        _codeFocus.requestFocus();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _code.text.length == _len && (!_needName || _name.text.trim().isNotEmpty);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/login'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.sm, AppSpace.xl, AppSpace.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(AppRadius.card)),
              child: const Icon(Icons.sms_outlined, color: AppColors.brand, size: 26),
            ),
            const SizedBox(height: AppSpace.xl),
            Semantics(header: true, child: Text('Enter the code we sent', style: AppText.display)),
            const SizedBox(height: AppSpace.sm),
            Row(children: [
              Text(_prettyPhone, style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
              TextButton(
                onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 40), padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text('Change', style: AppText.label.copyWith(color: AppColors.brand, fontSize: 14)),
              ),
            ]),
            const SizedBox(height: AppSpace.xl),
            _CodeBoxes(
              controller: _code,
              focusNode: _codeFocus,
              length: _len,
              error: _error != null,
              onChanged: (v) {
                setState(() => _error = null);
                if (v.length == _len && !_needName) _verify();
              },
            ),
            const SizedBox(height: AppSpace.md),
            if (_error != null)
              Text(_error!, style: AppText.caption.copyWith(color: AppColors.danger))
            else
              Row(children: [
                Text("Didn't get it? ", style: AppText.caption.copyWith(fontSize: 13)),
                if (_resendIn > 0)
                  Text('Resend in 0:${_resendIn.toString().padLeft(2, '0')}',
                      style: AppText.caption.copyWith(fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.w600))
                else
                  TextButton(
                    onPressed: _resend,
                    style: TextButton.styleFrom(minimumSize: const Size(48, 36), padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.padded),
                    child: Text('Resend code', style: AppText.label.copyWith(color: AppColors.brand)),
                  ),
              ]),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: !_needName
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: AppSpace.xxl),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('New here? What should neighbours call you?', style: AppText.heading),
                        const SizedBox(height: AppSpace.xs),
                        Text('Shown with your flat in the Street chat.', style: AppText.caption),
                        const SizedBox(height: AppSpace.md),
                        TextField(
                          controller: _name,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.givenName],
                          decoration: const InputDecoration(hintText: 'Your first name', prefixIcon: Icon(Icons.person_outline_rounded)),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => ready ? _verify() : null,
                        ),
                      ]),
                    ),
            ),
            const Spacer(),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(AppRadius.chip)),
                child: Text('Demo code: 1234', style: AppText.tiny),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            AppButton(label: _needName ? 'Continue' : 'Verify', loading: _busy, onPressed: ready ? _verify : null),
          ]),
        ),
      ),
    );
  }
}

/// Four digit boxes over one hidden field: typing auto-advances, backspace
/// steps back, and pasting a whole code fills every box.
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({required this.controller, required this.focusNode, required this.length, required this.onChanged, this.error = false});

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final ValueChanged<String> onChanged;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final code = controller.text;
    return Semantics(
      label: 'Verification code, $length digits',
      textField: true,
      child: SizedBox(
        height: 64,
        child: Stack(children: [
          Row(children: [
            for (var i = 0; i < length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpace.md),
              Expanded(child: _box(i, code)),
            ],
          ]),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                showCursor: false,
                enableInteractiveSelection: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(length)],
                decoration: const InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false),
                onChanged: onChanged,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _box(int i, String code) {
    final filled = i < code.length;
    final active = focusNode.hasFocus && (i == code.length || (code.length == length && i == length - 1));
    final border = error ? AppColors.danger : (active ? AppColors.brand : (filled ? const Color(0xFFE9C7B9) : AppColors.line));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? AppColors.brandTint : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.photo),
        border: Border.all(color: border, width: active || error ? 2 : 1.2),
      ),
      child: filled
          ? Text(code[i], style: AppText.display.copyWith(fontSize: 26))
          : (active ? Container(width: 2, height: 26, color: AppColors.brand) : const SizedBox()),
    );
  }
}
