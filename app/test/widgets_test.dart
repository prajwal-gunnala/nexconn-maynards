import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jugaad_street/widgets/widgets.dart';

void main() {
  testWidgets('PriceText shows price, struck retail and save badge', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PriceText(price: 88, retail: 120, per: 'kg'))));
    expect(find.text('₹120'), findsOneWidget);
    expect(find.text('27% off'), findsOneWidget);
    expect(find.textContaining('₹88', findRichText: true), findsOneWidget);
  });

  testWidgets('AppProgressBar renders with markers', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 300, child: AppProgressBar(value: 0.5, markers: [TierMarker(at: 0.25, label: '₹96', reached: true)])),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('₹96'), findsOneWidget);
  });
}
