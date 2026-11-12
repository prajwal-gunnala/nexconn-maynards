import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';

/// Phone login. `POST /api/auth/otp`, then the OTP screen.
class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _ctrl = TextEditingController(text: '9000000001');
  final _focus = FocusNode();
  bool _busy = false;
  bool _tried = false;

  String get _digits => _ctrl.text.replaceAll(RegExp(r'\D'), '');
  bool get _valid => RegExp(r'^[6-9]\d{9}$').hasMatch(_digits);

  String? get _error {
    final d = _digits;
    if (d.isNotEmpty && !RegExp('^[6-9]').hasMatch(d)) return 'Indian mobile numbers start with 6, 7, 8 or 9';
    if (_tried && d.length != 10) return 'Enter all 10 digits of your mobile number';
    return null;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _tried = true);
    if (!_valid) return;
    final phone = _digits;
    setState(() => _busy = true);
    try {
      await context.read<ApiClient>().requestOtp(phone);
      if (mounted) context.push('/login/otp?phone=$phone');
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: context.canPop() ? BackButton(onPressed: () => context.pop()) : null,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.sm, AppSpace.xl, AppSpace.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(AppRadius.card)),
              child: const Icon(Icons.phone_iphone_rounded, color: AppColors.brand, size: 28),
            ),
            const SizedBox(height: AppSpace.xl),
            Semantics(header: true, child: Text("What's your number?", style: AppText.display)),
            const SizedBox(height: AppSpace.sm),
            Text("We'll text you a 4-digit code. Neighbours see your name and flat, never your number.", style: AppText.bodyMuted),
            const SizedBox(height: AppSpace.xxl),
            Text('Mobile number', style: AppText.label.copyWith(color: AppColors.inkMuted)),
            const SizedBox(height: AppSpace.sm),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.photo),
                border: Border.all(
                  color: error != null ? AppColors.danger : (_focus.hasFocus ? AppColors.brand : AppColors.line),
                  width: _focus.hasFocus || error != null ? 1.5 : 1,
                ),
              ),
              child: Row(children: [
                const SizedBox(width: AppSpace.lg),
                Text('+91', style: AppText.heading.copyWith(fontSize: 17)),
                const SizedBox(width: AppSpace.md),
                Container(width: 1, height: 28, color: AppColors.line),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Focus(
                    onFocusChange: (_) => setState(() {}),
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.telephoneNumberNational],
                      style: AppText.heading.copyWith(fontSize: 18, letterSpacing: 1.5),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                      decoration: InputDecoration(
                        hintText: '98410 22417',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        hintStyle: AppText.heading.copyWith(fontSize: 18, color: AppColors.line, letterSpacing: 1.5),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                if (_valid)
                  const Padding(
                    padding: EdgeInsets.only(right: AppSpace.lg),
                    child: Icon(Icons.check_circle_rounded, color: AppColors.save, size: 22),
                  ),
              ]),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 160),
              child: error == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: AppSpace.sm),
                      child: Text(error, style: AppText.caption.copyWith(color: AppColors.danger)),
                    ),
            ),
            const Spacer(),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.inkMuted),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text('Your number is only used to sign you in and to send UPI hold requests.', style: AppText.caption),
              ),
            ]),
            const SizedBox(height: AppSpace.lg),
            AppButton(label: 'Get code', loading: _busy, onPressed: _digits.length == 10 ? _send : null),
          ]),
        ),
      ),
    );
  }
}
