import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';

/// Temporary body for screens that aren't built yet. Replace per feature.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, this.note, this.actions = const [], this.showAppBar = true});

  final String title;
  final String? note;
  final List<Widget> actions;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showAppBar ? AppBar(title: Text(title)) : null,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.construction_rounded, size: 40, color: AppColors.inkMuted),
            const SizedBox(height: AppSpace.md),
            Text(title, style: AppText.title, textAlign: TextAlign.center),
            if (note != null) ...[
              const SizedBox(height: AppSpace.sm),
              Text(note!, style: AppText.bodyMuted, textAlign: TextAlign.center),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AppSpace.xxl),
              ...actions.expand((a) => [a, const SizedBox(height: AppSpace.sm)]),
            ],
          ]),
        ),
      ),
    );
  }
}
