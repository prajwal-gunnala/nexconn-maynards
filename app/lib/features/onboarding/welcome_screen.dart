import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import '../bucket/bucket_visuals.dart';

/// Screen 1 · Welcome — what the app does, in one line.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const tiles = [('seer', '-34%'), ('basmati', '-20%'), ('mango', '-25%'), ('pest', '-29%')];
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: AppSpace.lg),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpace.md,
                crossAxisSpacing: AppSpace.md,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final (k, off) in tiles)
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.cardBorder,
                        border: Border.all(color: AppColors.line),
                      ),
                      padding: const EdgeInsets.all(AppSpace.sm),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: BucketPhoto(visual: BucketVisual.of(k), height: double.infinity)),
                        const SizedBox(height: 6),
                        Text(off, style: AppText.heading.copyWith(color: AppColors.save)),
                      ]),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.xxl),
            Text('Wholesale prices for your whole street', style: AppText.display),
            const SizedBox(height: AppSpace.sm),
            Text(
              'Fill a bucket with your neighbours inside your society chat. Money is held, not paid, until the bucket fills.',
              style: AppText.bodyMuted,
            ),
            const SizedBox(height: AppSpace.xxl),
            AppButton(label: 'Get started', onPressed: () => context.go('/login')),
          ]),
        ),
      ),
    );
  }
}
