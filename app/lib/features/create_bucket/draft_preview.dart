import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import '../bucket/bucket_visuals.dart';
import 'bucket_draft.dart';

/// What the preview needs, derived from the form on every change.
class PreviewData {
  const PreviewData({
    required this.kind,
    required this.title,
    required this.image,
    this.subtitle,
    this.vendor,
    this.price,
    this.retail,
    this.per,
    required this.goal,
    this.tierHint,
    this.cutoffAt,
    this.atMarket = false,
    this.meetLine,
    this.poster,
  });

  final DraftKind kind;
  final String title;
  final String? subtitle;
  final String? vendor;
  final String image;
  final int? price;
  final int? retail;
  final String? per;

  /// "0 of 8 cuts", "0 of 25 kg to go ahead", "0 of 150 kg"
  final String goal;
  final String? tierHint;
  final DateTime? cutoffAt;
  final bool atMarket;
  final String? meetLine;
  final String? poster;
}

/// How the live bucket card will look in the Street chat: the bot's bubble with the card,
/// on the chat background. Mirrors the chat's `js:bucket` card at 0 % filled.
class DraftPreview extends StatelessWidget {
  const DraftPreview({super.key, required this.data, this.now});

  final PreviewData data;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Semantics(
      label: 'Preview of the card in the Street chat',
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.lg, AppSpace.md, AppSpace.lg),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(color: AppColors.line),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle),
            child: Text('JS', style: AppText.tiny.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: 'Jugaad Street', style: AppText.label),
                TextSpan(text: '  ·  just now', style: AppText.caption),
              ])),
              const SizedBox(height: 6),
              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 280), child: _card()),
              if (d.poster != null) ...[
                const SizedBox(height: 6),
                Text('Started by ${d.poster}', style: AppText.caption),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _card() {
    final d = data;
    final hasTitle = d.title.trim().isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: BucketPhoto(
            visual: BucketVisual.of(d.image),
            height: 120,
            badge: d.atMarket ? 'Book & meet' : d.kind.label,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(
                  hasTitle ? d.title : 'Your bucket title',
                  style: AppText.heading.copyWith(color: hasTitle ? AppColors.ink : AppColors.inkMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const StatusPill('Live', tone: PillTone.brand),
            ]),
            if ((d.subtitle ?? '').isNotEmpty || d.vendor != null) ...[
              const SizedBox(height: 2),
              Text(
                [if (d.vendor != null) d.vendor!, if ((d.subtitle ?? '').isNotEmpty) d.subtitle!].join(' · '),
                style: AppText.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (d.price != null && d.price! > 0) ...[
              const SizedBox(height: 8),
              PriceText(price: d.price!, retail: d.retail, per: d.per),
            ],
            const SizedBox(height: 10),
            const AppProgressBar(value: 0),
            const SizedBox(height: 6),
            Text(d.goal, style: AppText.label),
            if (d.tierHint != null) ...[
              const SizedBox(height: 4),
              Text(d.tierHint!, style: AppText.caption.copyWith(color: AppColors.save)),
            ],
            if (d.meetLine != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.place_outlined, size: 14, color: AppColors.inkMuted),
                const SizedBox(width: 4),
                Expanded(child: Text(d.meetLine!, style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ],
            if (d.cutoffAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Cutoff ${Fmt.dayTime(d.cutoffAt!)} · ${Fmt.timeLeft(d.cutoffAt!, now: now)}',
                style: AppText.caption,
              ),
            ],
            const SizedBox(height: 10),
            Container(
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(10)),
              child: Text(
                d.atMarket ? 'Book my share' : 'Join bucket',
                style: AppText.label.copyWith(color: Colors.white),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
