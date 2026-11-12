import 'package:flutter/material.dart';

import '../../widgets/widgets.dart';

/// Order — Every member, final price and pickup OTP
/// TODO(feature): build per docs/design/app-flow.html.
class OrderScreen extends StatelessWidget {
  const OrderScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) => const PlaceholderScreen(title: 'Order', note: 'Every member, final price and pickup OTP');
}
