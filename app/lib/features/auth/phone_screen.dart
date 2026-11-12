import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';

/// Screen 2a · Phone login. `POST /api/auth/otp` then go to the OTP screen.
class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _ctrl = TextEditingController(text: '9000000001');
  bool _busy = false;

  bool get _valid => _ctrl.text.replaceAll(RegExp(r'\D'), '').length == 10;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final phone = _ctrl.text.replaceAll(RegExp(r'\D'), '');
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("What's your number?", style: AppText.display),
            const SizedBox(height: AppSpace.sm),
            Text("We'll text you a code. Your neighbours see your name and flat, never your number.",
                style: AppText.bodyMuted),
            const SizedBox(height: AppSpace.xxl),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.phone,
              autofocus: true,
              style: AppText.heading.copyWith(fontSize: 18, letterSpacing: 1),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: Text('+91', style: AppText.heading.copyWith(fontSize: 18)),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                hintText: '98410 22417',
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _valid ? _send() : null,
            ),
            const Spacer(),
            Text('Demo: seeded numbers 9000000001–07 log in as the Sea Breeze neighbours.', style: AppText.caption),
            const SizedBox(height: AppSpace.md),
            AppButton(label: 'Send code', loading: _busy, onPressed: _valid ? _send : null),
          ]),
        ),
      ),
    );
  }
}
