import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../bucket/bucket_visuals.dart';
import 'bucket_draft.dart';

/// Step 1: "What are we buying?" Four type tiles, then photo templates that jump to step 2 prefilled.
class StepOne extends StatelessWidget {
  const StepOne({super.key, required this.kind, required this.onKind, required this.onTemplate});

  final DraftKind? kind;
  final ValueChanged<DraftKind> onKind;
  final ValueChanged<BucketTemplate> onTemplate;

  @override
  Widget build(BuildContext context) {
    final t = BucketTemplate.all;
    final grid = t.where((x) => x.id != 'meetup').toList();
    final featured = t.firstWhere((x) => x.id == 'meetup');
    return ListView(
      key: const Key('create-step1'),
      padding: const EdgeInsets.only(bottom: AppSpace.xxl),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.xl, AppSpace.gutter, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(header: true, child: Text('What are we buying?', style: AppText.display.copyWith(fontSize: 26))),
            const SizedBox(height: AppSpace.xs),
            Text('Pick how neighbours share it. You can change everything on the next step.', style: AppText.bodyMuted),
          ]),
        ),
        const SizedBox(height: AppSpace.xl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: Column(children: [
            for (var r = 0; r < 2; r++) ...[
              if (r > 0) const SizedBox(height: AppSpace.md),
              Row(children: [
                for (var c = 0; c < 2; c++) ...[
                  if (c > 0) const SizedBox(width: AppSpace.md),
                  Expanded(child: _TypeTile(kind: DraftKind.values[r * 2 + c], selected: kind == DraftKind.values[r * 2 + c], onTap: onKind)),
                ],
              ]),
            ],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.xxl + AppSpace.sm, AppSpace.gutter, AppSpace.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(header: true, child: Text('Or start from a template', style: AppText.heading.copyWith(fontSize: 18))),
            const SizedBox(height: 2),
            Text("Prefilled with this week's prices. Post in two taps.", style: AppText.caption),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: Column(children: [
            for (var i = 0; i < grid.length; i += 2) ...[
              if (i > 0) const SizedBox(height: AppSpace.md),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _TemplateCard(t: grid[i], onTap: onTemplate)),
                const SizedBox(width: AppSpace.md),
                Expanded(child: i + 1 < grid.length ? _TemplateCard(t: grid[i + 1], onTap: onTemplate) : const SizedBox()),
              ]),
            ],
            const SizedBox(height: AppSpace.md),
            _FeaturedTemplate(t: featured, onTap: onTemplate),
          ]),
        ),
      ],
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({required this.kind, required this.selected, required this.onTap});
  final DraftKind kind;
  final bool selected;
  final ValueChanged<DraftKind> onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${kind.label}. ${kind.blurb}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onTap(kind),
        borderRadius: AppRadius.cardBorder,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 132,
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandTint : AppColors.surface,
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: selected ? AppColors.brand : AppColors.line, width: selected ? 2 : 1),
          ),
          child: Stack(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? AppColors.surface : BucketVisual.of(_visualKey).tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(kind.icon, size: 24, color: selected ? AppColors.brand : AppColors.ink.withValues(alpha: 0.7)),
              ),
              const Spacer(),
              Text(kind.label, style: AppText.heading),
              const SizedBox(height: 2),
              Text(kind.blurb, style: AppText.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
            Positioned(
              right: 0,
              top: 0,
              child: AnimatedScale(
                scale: selected ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: const CircleAvatar(
                  radius: 11,
                  backgroundColor: AppColors.brand,
                  child: Icon(Icons.check_rounded, size: 15, color: Colors.white),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  String get _visualKey => switch (kind) {
        DraftKind.split => 'fish',
        DraftKind.bulk => 'rice',
        DraftKind.service => 'pest',
        DraftKind.trip => 'koyambedu',
      };
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.t, required this.onTap});
  final BucketTemplate t;
  final ValueChanged<BucketTemplate> onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Template: ${t.name}, ${t.meta}, ${t.priceLine}',
      excludeSemantics: true,
      child: InkWell(
        key: Key('template-${t.id}'),
        onTap: () => onTap(t),
        borderRadius: AppRadius.cardBorder,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: AppColors.line),
          ),
          padding: const EdgeInsets.all(6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(aspectRatio: 3 / 2, child: BucketPhoto(visual: BucketVisual.of(t.image), height: double.infinity)),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.name, style: AppText.heading.copyWith(fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(t.meta, style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text(t.priceLine, style: AppText.label.copyWith(fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _FeaturedTemplate extends StatelessWidget {
  const _FeaturedTemplate({required this.t, required this.onTap});
  final BucketTemplate t;
  final ValueChanged<BucketTemplate> onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Template: ${t.name}, ${t.meta}',
      excludeSemantics: true,
      child: InkWell(
        key: Key('template-${t.id}'),
        onTap: () => onTap(t),
        borderRadius: AppRadius.cardBorder,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: AppColors.line),
          ),
          padding: const EdgeInsets.all(6),
          child: Row(children: [
            SizedBox(width: 128, height: 104, child: BucketPhoto(visual: BucketVisual.of(t.image), height: 104, badge: 'Book & meet')),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.name, style: AppText.heading.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text('No prepayment. Book a half, ride to Kasimedu together, pay at the stall.', style: AppText.caption, maxLines: 3),
                const SizedBox(height: 6),
                Text(t.priceLine, style: AppText.label.copyWith(fontWeight: FontWeight.w800)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
          ]),
        ),
      ),
    );
  }
}
