import 'package:flutter/material.dart';

import '../../widgets/widgets.dart';

/// UPI hold — Money blocked in the bank, not paid
/// TODO(feature): build per docs/design/app-flow.html.
class HoldScreen extends StatelessWidget {
  const HoldScreen({super.key, required this.bucketId});

  final String bucketId;

  @override
  Widget build(BuildContext context) => const PlaceholderScreen(title: 'UPI hold', note: 'Money blocked in the bank, not paid');
}
