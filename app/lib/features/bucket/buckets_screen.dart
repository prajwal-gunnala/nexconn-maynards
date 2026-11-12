import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/session/session_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import 'bucket_card.dart';

/// "Buckets" tab: every live bucket in the community, filterable by type.
/// TODO(feature): category grid, my buckets, filters per design board.
class BucketsScreen extends StatefulWidget {
  const BucketsScreen({super.key});

  @override
  State<BucketsScreen> createState() => _BucketsScreenState();
}

class _BucketsScreenState extends State<BucketsScreen> {
  BucketType? _type;
  Future<List<Bucket>>? _load;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final s = context.read<SessionStore>();
    _load = (s.isDev || s.community == null)
        ? Future.value(const <Bucket>[])
        : context.read<ApiClient>().buckets(s.community!.id, type: _type?.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buckets')),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter, vertical: AppSpace.sm),
            children: [
              for (final t in [null, BucketType.split, BucketType.bulk, BucketType.service, BucketType.trip])
                Padding(
                  padding: const EdgeInsets.only(right: AppSpace.sm),
                  child: ChoiceChip(
                    label: Text(t == null ? 'All' : t.name[0].toUpperCase() + t.name.substring(1)),
                    selected: _type == t,
                    onSelected: (_) => setState(() {
                      _type = t;
                      _reload();
                    }),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Bucket>>(
            future: _load,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snap.hasError) return Center(child: Text('${snap.error}', style: AppText.bodyMuted));
              final list = snap.data ?? const [];
              if (list.isEmpty) return Center(child: Text('No buckets here yet', style: AppText.bodyMuted));
              return ListView.separated(
                padding: const EdgeInsets.all(AppSpace.gutter),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
                itemBuilder: (_, i) => BucketCard(bucket: list[i]),
              );
            },
          ),
        ),
      ]),
    );
  }
}
