@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jugaad_street/core/models/models.dart';
import 'package:jugaad_street/core/theme/tokens.dart';
import 'package:jugaad_street/features/auth/otp_screen.dart';
import 'package:jugaad_street/features/auth/phone_screen.dart';
import 'package:jugaad_street/features/bucket/bucket_card.dart';
import 'package:jugaad_street/features/bucket/buckets_screen.dart';
import 'package:jugaad_street/features/bucket/list_logic.dart';
import 'package:jugaad_street/features/community/join_community_screen.dart';
import 'package:jugaad_street/features/home/home_shell.dart';
import 'package:jugaad_street/features/home/list_home_sections.dart';
import 'package:jugaad_street/features/home/street_home_screen.dart';
import 'package:jugaad_street/features/onboarding/welcome_screen.dart';

import 'harness.dart';

/// Fixture cutoffs were recorded relative to 2026-11-13; pin "now" so countdowns are stable.
final _now = DateTime.utc(2026, 11, 12, 22, 5);

List<Bucket> _buckets() => (fixture('buckets') as List).map((e) => Bucket.fromJson((e as Map).cast<String, dynamic>())).toList();
Bucket _b(String id) => _buckets().firstWhere((b) => b.id == id);

Future<void> _scroll(WidgetTester t, double dy, {Finder? on}) async {
  await t.drag(on ?? find.byType(Scrollable).first, Offset(0, -dy));
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
  // Images that scrolled into view still need decoding outside fake async.
  await t.runAsync(() async {
    for (final el in find.byType(Image).evaluate()) {
      await precacheImage((el.widget as Image).image, el, onError: (_, _) {});
    }
  });
  await t.pump(const Duration(milliseconds: 100));
}

/// Card variants side by side, plus the bottom nav.
class _Gallery extends StatelessWidget {
  const _Gallery({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final all = _buckets();
    Bucket get(String id) => all.firstWhere((b) => b.id == id);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      bottomNavigationBar: StreetNavBar(currentIndex: 0, onTab: (_) {}, onStart: () {}),
      body: SafeArea(
        child: ListView(children: compact
            ? [
                const HomeSectionHeader('Closing soon', subtitle: 'Compact rail cards'),
                SizedBox(
                  height: BucketCard.compactHeight,
                  child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                    BucketCard.compact(bucket: get('b_seer')),
                    const SizedBox(width: 12),
                    BucketCard.compact(bucket: get('b_basmati')),
                  ]),
                ),
                SizedBox(
                  height: BucketCard.compactHeight + 24,
                  child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 24, 16, 0), children: [
                    BucketCard.compact(bucket: get('b_trip')),
                    const SizedBox(width: 12),
                    BucketCard.compact(bucket: get('b_past_prawns')),
                  ]),
                ),
              ]
            : [
                const HomeSectionHeader('Full cards', subtitle: 'Service and book-and-meet'),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: BucketCard(bucket: get('b_pest'))),
                const SizedBox(height: 16),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: BucketCard(bucket: get('b_paarai'))),
              ]),
      ),
    );
  }
}

void main() {
  setUp(() {
    StreetClock.now = () => _now;
    BucketsFilter.category.value = null;
    BucketsFilter.type.value = null;
  });

  group('street home', () {
    testWidgets('top', (t) => shoot(t, 'discovery_home_top', const StreetHomeScreen()));
    testWidgets('rail', (t) => shoot(t, 'discovery_home_rail', const StreetHomeScreen(), act: (t) => _scroll(t, 640)));
    testWidgets('live list', (t) => shoot(t, 'discovery_home_live', const StreetHomeScreen(), act: (t) => _scroll(t, 1180)));
    testWidgets('bottom', (t) => shoot(t, 'discovery_home_bottom', const StreetHomeScreen(), act: (t) => _scroll(t, 6000)));
    for (final i in [1, 2]) {
      testWidgets('banner ${i + 1}', (t) => shoot(t, 'discovery_home_banner${i + 1}', const StreetHomeScreen(), act: (t) async {
            for (var k = 0; k < i; k++) {
              await t.drag(find.byType(PageView), const Offset(-500, 0));
              await t.pump(const Duration(milliseconds: 600));
            }
            await t.runAsync(() async {
              for (final el in find.byType(Image).evaluate()) {
                await precacheImage((el.widget as Image).image, el, onError: (_, _) {});
              }
            });
            await t.pump(const Duration(milliseconds: 100));
          }));
    }
    testWidgets('search', (t) => shoot(t, 'discovery_home_search', const StreetHomeScreen(), act: (t) async {
          await t.enterText(find.byType(TextField).first, 'kasimedu');
          await t.pump(const Duration(milliseconds: 300));
        }));
  });

  group('buckets tab', () {
    testWidgets('all', (t) => shoot(t, 'discovery_buckets_all', const BucketsScreen()));
    testWidgets('fish filter', (t) async {
      BucketsFilter.category.value = 'fish';
      await shoot(t, 'discovery_buckets_fish', const BucketsScreen());
    });
    testWidgets('bulk filter', (t) => shoot(t, 'discovery_buckets_bulk', const BucketsScreen(), act: (t) async {
          await t.tap(find.text('Bulk').first);
          await t.pump(const Duration(milliseconds: 300));
        }));
    testWidgets('past', (t) => shoot(t, 'discovery_buckets_past', const BucketsScreen(),
        act: (t) => _scroll(t, 6000, on: find.byType(Scrollable).last)));
  });

  group('cards', () {
    testWidgets('compact', (t) => shoot(t, 'discovery_cards_compact', const _Gallery(compact: true)));
    testWidgets('full', (t) => shoot(t, 'discovery_cards_full', const _Gallery(compact: false)));
    test('facts and captions per type', () {
      expect(_b('b_seer').facts, ['5.2 kg', '8 cuts', 'Serves 8 families']);
      expect(_b('b_seer').progressCaption, '6 of 8 cuts');
      expect(_b('b_basmati').nextTierCaption, '13 kg to ₹88');
      expect(_b('b_pest').progressCaption, '31 of 50 flats');
      expect(_b('b_trip').progressCaption, '186 of 300 kg booked');
      expect(_b('b_trip').displayPrice, 22);
      expect(searchBuckets(_buckets(), 'seafood').map((b) => b.id), containsAll(['b_seer', 'b_paarai']));
      expect(_buckets().where((b) => inCategory(b, 'staples')).map((b) => b.id), ['b_basmati']);
    });
  });

  group('onboarding + auth', () {
    for (var i = 0; i < 3; i++) {
      testWidgets('slide ${i + 1}', (t) => shoot(t, 'discovery_onboarding_${i + 1}', WelcomeScreen(initialPage: i)));
    }
    testWidgets('phone', (t) => shoot(t, 'discovery_phone', const PhoneScreen()));
    testWidgets('otp filled', (t) => shoot(
          t,
          'discovery_otp',
          const OtpScreen(phone: '9000000001'),
          // Verify "succeeds" with an empty session so the screen stays put for the shot.
          overrides: {'POST /api/auth/verify': {'sessionToken': '', 'user': {'id': 'u_ananya', 'name': 'Ananya'}, 'nexconn': {}}},
          act: (t) async {
            await t.enterText(find.byType(TextField).first, '1234');
            await t.pump(const Duration(milliseconds: 200));
          },
        ));
    testWidgets('join community', (t) => shoot(
          t,
          'discovery_join',
          const JoinCommunityScreen(),
          overrides: {
            '/api/communities': [
              fixture('community'),
              {'id': 'c_seabreeze_res', 'name': 'Sea Breeze Residency', 'kind': 'society', 'area': 'Thoraipakkam', 'city': 'Chennai', 'flats': 180, 'stats': {'members': 12}},
              {'id': 'c_palmgrove', 'name': 'Palm Grove Apartments', 'kind': 'society', 'area': 'Perungudi', 'city': 'Chennai', 'flats': 96, 'stats': {'members': 0}},
            ],
          },
          act: (t) async {
            await t.tap(find.text('Sea Breeze Towers'));
            await t.pump(const Duration(milliseconds: 300));
          },
        ));
  });
}
