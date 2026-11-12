import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import 'bucket_visuals.dart';

/// Bucket detail. One body per type (split: share map, bulk: quantity + tiers,
/// service: flats + slot, trip: shared list).
/// TODO(feature): build each [_TypeBody] per the design board.
class BucketDetailScreen extends StatefulWidget {
  const BucketDetailScreen({super.key, required this.bucketId});

  final String bucketId;

  @override
  State<BucketDetailScreen> createState() => _BucketDetailScreenState();
}

class _BucketDetailScreenState extends State<BucketDetailScreen> {
  late Future<Bucket> _load = context.read<ApiClient>().bucket(widget.bucketId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Bucket>(
      future: _load,
      builder: (context, snap) {
        if (snap.hasError) {
          return PlaceholderScreen(
            title: 'Bucket ${widget.bucketId}',
            note: snap.error is ApiException ? (snap.error as ApiException).message : '${snap.error}',
            actions: [AppButton.ghost(label: 'Retry', onPressed: () => setState(() => _load = context.read<ApiClient>().bucket(widget.bucketId)))],
          );
        }
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final b = snap.data!;
        final unit = b.unitLabel ?? 'share';
        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(title: Text(b.title)),
          body: ListView(padding: const EdgeInsets.all(AppSpace.gutter), children: [
            BucketPhoto(visual: BucketVisual.of(b.image ?? b.title), url: b.image, height: 200),
            const SizedBox(height: AppSpace.lg),
            Text(b.title, style: AppText.title),
            if (b.subtitle != null) Text(b.subtitle!, style: AppText.bodyMuted),
            const SizedBox(height: AppSpace.sm),
            if (b.unitPrice != null) PriceText(price: b.unitPrice!, retail: b.retailUnitPrice, per: unit, large: true),
            const SizedBox(height: AppSpace.lg),
            AppProgressBar(
              value: b.progress.fraction,
              markers: [
                if (b.progress.target > 0)
                  for (final t in b.tiers)
                    TierMarker(at: t.minQty / b.progress.target, label: Fmt.rupees(t.unitPrice), reached: b.progress.filled >= t.minQty),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Text('${b.progress.filled} of ${b.progress.target} $unit · ${b.progress.members} neighbours', style: AppText.label),
            if (b.cutoffAt != null) Text('Cutoff ${Fmt.dayTime(b.cutoffAt!)}', style: AppText.caption),
            const SizedBox(height: AppSpace.xl),
            Text('Type: ${b.type.name} — detail UI to be built', style: AppText.bodyMuted),
          ]),
          bottomNavigationBar: StickyCta(
            child: b.myShare != null
                ? AppButton.secondary(label: 'You\'re in · ${b.myShare!.status.wire}', onPressed: null)
                : AppButton(label: 'Join bucket', onPressed: () => context.push('/bucket/${b.id}/hold')),
          ),
        );
      },
    );
  }
}
