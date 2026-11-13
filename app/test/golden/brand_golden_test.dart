@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jugaad_street/core/theme/app_theme.dart';
import 'package:jugaad_street/core/theme/tokens.dart';
import 'package:jugaad_street/features/splash/splash_screen.dart';
import 'package:jugaad_street/widgets/brand_logo.dart';

import 'harness.dart';

// Run: flutter test test/golden/brand_golden_test.dart -t golden --run-skipped --update-goldens
// PNGs: test/golden/shots/brand_*.png (1080×2400).

Future<void> _phone(WidgetTester t) async {
  await t.runAsync(loadFonts);
  t.view.physicalSize = phoneSize * phoneDpr;
  t.view.devicePixelRatio = phoneDpr;
  addTearDown(t.view.reset);
}

Widget _app(Widget home) => MaterialApp(debugShowCheckedModeBanner: false, theme: AppTheme.light(), home: home);

void main() {
  group('splash', () {
    for (final (name, ms) in [('0ms', 0), ('600ms', 600), ('end', 1450)]) {
      testWidgets('splash at $name', (t) async {
        await _phone(t);
        await t.pumpWidget(_app(const SplashScreen()));
        await t.pump(Duration(milliseconds: ms));
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/brand_splash_$name.png'));
        // let the fade finish so no timers/tickers are left running
        await t.pump(const Duration(seconds: 2));
      });
    }

    testWidgets('overlay removes itself and calls through to the app', (t) async {
      await _phone(t);
      await t.pumpWidget(_app(const SplashOverlay(child: Scaffold(body: Center(child: Text('first screen'))))));
      expect(find.byType(SplashScreen), findsOneWidget);
      await t.pump(const Duration(milliseconds: 1450)); // composed end frame
      expect(find.byType(SplashScreen), findsOneWidget);
      final frames = await t.pumpAndSettle(); // fade (~260 ms), then the overlay drops the splash
      expect(frames, lessThan(8));
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.text('first screen'), findsOneWidget);
    });

    testWidgets('reduced motion jumps to the composed frame and finishes quickly', (t) async {
      await _phone(t);
      await t.pumpWidget(_app(const MediaQuery(
        data: MediaQueryData(disableAnimations: true, size: phoneSize),
        child: SplashOverlay(child: SizedBox()),
      )));
      await t.pump();
      final title = t.widget<Opacity>(
        find.ancestor(of: find.text('Jugaad Street'), matching: find.byType(Opacity)).first,
      );
      expect(title.opacity, 1);
      await t.pump(const Duration(milliseconds: 350));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.byType(SplashScreen), findsNothing);
    });
  });

  testWidgets('brand widgets gallery', (t) async {
    await _phone(t);
    final gallery = _app(Scaffold(
      backgroundColor: AppColors.canvas,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('BrandMark 24 / 48 / 96', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13)),
            const SizedBox(height: 12),
            const Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              BrandMark(size: 24),
              SizedBox(width: 24),
              BrandMark(size: 48),
              SizedBox(width: 24),
              BrandMark(size: 96),
            ]),
            const SizedBox(height: 36),
            const Text('BrandWordmark 32 / 24', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13)),
            const SizedBox(height: 12),
            const BrandWordmark(),
            const SizedBox(height: 16),
            const BrandWordmark(size: 24),
            const SizedBox(height: 36),
            const Text('On brand: BrandWordmark(onDark) + BrandGlyph 96',
                style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.brand, borderRadius: AppRadius.cardBorder),
              child: const Row(children: [
                BrandWordmark(onDark: true),
                Spacer(),
                BrandGlyph(size: 96),
              ]),
            ),
          ],
        ),
      ),
    ));
    await t.runAsync(() async {
      await t.pumpWidget(gallery);
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await t.pump(const Duration(milliseconds: 100));
      }
    });
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/brand_widgets.png'));
  });
}
