import 'package:flutter/material.dart';

import '../../core/call/call_service.dart';
import '../../core/config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// App version (keep in sync with pubspec.yaml).
const appVersion = '1.0.0 (1)';

void openAbout(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => const AboutScreen()));

/// What Jugaad Street is built on: Nexconn Chat SDK + Nexconn Call SDK.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final callVersion = CallService.instance?.sdkVersion;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: Text('About', style: AppText.title)),
      body: ListView(padding: const EdgeInsets.all(AppSpace.gutter), children: [
        Center(
          child: Column(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.tile),
              child: Image.asset('assets/brand/icon_512.png', width: 72, height: 72, errorBuilder: (_, _, _) {
                return Container(
                  width: 72,
                  height: 72,
                  color: AppColors.brandTint,
                  child: const Icon(Icons.storefront_rounded, color: AppColors.brand, size: 36),
                );
              }),
            ),
            const SizedBox(height: AppSpace.md),
            Text('Jugaad Street', style: AppText.title),
            const SizedBox(height: AppSpace.xs),
            Text('Version $appVersion', style: AppText.caption),
          ]),
        ),
        const SizedBox(height: AppSpace.xxl),
        Text('BUILT ON NEXCONN', style: AppText.tiny.copyWith(letterSpacing: 1.2)),
        const SizedBox(height: AppSpace.sm),
        const _SdkCard(
          icon: Icons.forum_rounded,
          title: 'Nexconn Chat SDK',
          body: 'Chat UI kit, group channels (your Street and every bucket), direct channels '
              '(neighbour and vendor), custom message cards, and live message metadata that moves '
              'bucket cards in real time.',
        ),
        const SizedBox(height: AppSpace.md),
        _SdkCard(
          icon: Icons.call_rounded,
          title: 'Nexconn Call SDK',
          body: '1-to-1 and group voice and video calls, straight from any chat header. '
              'Runs on the same Nexconn connection as chat.',
          footer: callVersion == null ? null : 'Call SDK $callVersion',
        ),
        const SizedBox(height: AppSpace.xxl),
        Text('DETAILS', style: AppText.tiny.copyWith(letterSpacing: 1.2)),
        const SizedBox(height: AppSpace.sm),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(children: [
            const _Row('App Key', AppConfig.nexconnAppKey),
            const Divider(height: 1),
            const _Row('Region', 'Singapore (SG)'),
            const Divider(height: 1),
            const _Row('Chat SDK', 'Flutter 26.2.11'),
            const Divider(height: 1),
            _Row('Call SDK', 'Android ${callVersion ?? '26.2.0'}'),
          ]),
        ),
      ]),
    );
  }
}

class _SdkCard extends StatelessWidget {
  const _SdkCard({required this.icon, required this.title, required this.body, this.footer});

  final IconData icon;
  final String title;
  final String body;
  final String? footer;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.brand, size: 22),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.heading),
              const SizedBox(height: AppSpace.xs),
              Text(body, style: AppText.bodyMuted),
              if (footer != null) ...[
                const SizedBox(height: AppSpace.sm),
                Text(footer!, style: AppText.caption),
              ],
            ]),
          ),
        ]),
      );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
        child: Row(children: [
          Text(label, style: AppText.bodyMuted),
          const Spacer(),
          SelectableText(value, style: AppText.label),
        ]),
      );
}
