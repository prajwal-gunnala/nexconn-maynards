import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';

/// `Live buckets            See all >`
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.action, this.onAction});

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.xl, AppSpace.gutter, AppSpace.md),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppText.heading.copyWith(fontSize: 18)),
            if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: AppText.caption)],
          ]),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Row(children: [
              Text(action!, style: AppText.label.copyWith(color: AppColors.brand)),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.brand),
            ]),
          ),
      ]),
    );
  }
}
