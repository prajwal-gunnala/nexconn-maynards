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

/// Registers the shot at the default phone size (412×915) and again at a small
/// phone (360×800, `NAME_360`), where truncation and overflow show up first.
void _shot(
  String desc,
  String name,
  Widget Function() screen, {
  Map<String, Object?> overrides = const {},
  Future<void> Function(WidgetTester t)? act,
  void Function()? setup,
}) {
  testWidgets(desc, (t) async {
    setup?.call();
    await shoot(t, name, screen(), overrides: overrides, act: act);
  });
  testWidgets('$desc @360', (t) async {
    setup?.call();
    await shoot(t, '${name}_360', screen(), overrides: overrides, act: (t) async {
      t.view.devicePixelRatio = 3;
      t.view.physicalSize = const Size(360, 800) * 3;
      await t.pump(const Duration(milliseconds: 200));
      await t.runAsync(() async {
        for (final el in find.byType(Image).evaluate()) {
          await precacheImage((el.widget as Image).image, el, onError: (_, _) {});
        }
      });
      await t.pump(const Duration(milliseconds: 100));
      if (act != null) await act(t);
    });
  });
}

/// Past rows for each outcome, including a Book & Meet that met at the market.
class _PastGallery extends StatelessWidget {
  const _PastGallery();

  @override
  Widget build(BuildContext context) {
    final raw = (fixture('buckets') as List).cast<Map<String, dynamic>>();
    Bucket with_(String id, String status) => Bucket.fromJson({...raw.firstWhere((j) => j['id'] == id), 'status': status});
    final rows = [
      with_('b_paarai', 'market_day'),
      with_('b_paarai', 'completed'),
      with_('b_basmati', 'ordered'),
      with_('b_goat', 'delivering'),
      _b('b_past_prawns'),
      _b('b_past_crab'),
    ];
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          for (final b in rows) PastBucketRow(bucket: b),
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
    _shot('top', 'discovery_home_top', () => const StreetHomeScreen());
    _shot('join your neighbours', 'discovery_home_join', () => const StreetHomeScreen(), act: (t) => _scroll(t, 560));
    _shot('more cards', 'discovery_home_cards', () => const StreetHomeScreen(), act: (t) => _scroll(t, 1150));
    _shot('feed', 'discovery_home_feed', () => const StreetHomeScreen(), act: (t) => _scroll(t, 1660));
  });

  group('buckets tab', () {
    _shot('all', 'discovery_buckets_all', () => const BucketsScreen());
    _shot('fish filter', 'discovery_buckets_fish', () => const BucketsScreen(), setup: () => BucketsFilter.category.value = 'fish');
    _shot('bulk filter', 'discovery_buckets_bulk', () => const BucketsScreen(), setup: () => BucketsFilter.type.value = BucketType.bulk);
    _shot('search', 'discovery_buckets_search', () => const BucketsScreen(), act: (t) async {
      await t.enterText(find.byType(TextField).first, 'rice');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pump(const Duration(milliseconds: 300));
    });
    _shot('type sheet', 'discovery_buckets_type_sheet', () => const BucketsScreen(), act: (t) async {
      await t.tap(find.text('Type'));
      await t.pump(const Duration(milliseconds: 500));
    });
    _shot('past', 'discovery_buckets_past', () => const BucketsScreen(), act: (t) async {
      for (var i = 0; i < 4; i++) {
        await _scroll(t, 3000, on: find.byType(Scrollable).last);
      }
    });
  });

  group('cards', () {
    _shot('compact', 'discovery_cards_compact', () => const _Gallery(compact: true));
    _shot('full', 'discovery_cards_full', () => const _Gallery(compact: false));
    _shot('past rows', 'discovery_cards_past', () => const _PastGallery());
    test('facts, captions and search', () {
      expect(_b('b_seer').facts, ['5.2 kg', '8 cuts', 'Serves 8 families']);
      expect(_b('b_seer').progressCaption, '6 of 8 cuts');
      expect(_b('b_basmati').nextTierCaption, '13 kg to ₹88');
      expect(_b('b_pest').progressCaption, '31 of 50 flats');
      expect(_b('b_trip').progressCaption, '186 of 300 kg booked');
      expect(_b('b_trip').displayPrice, 22);
      expect(_b('b_seer').goalHeadline, '2 cuts left of a whole seer');
      expect(_b('b_basmati').goalHeadline, "13 kg more and it's ₹88/kg for everyone");
      expect(_b('b_pest').goalHeadline, "19 more flats and it's ₹340 a flat");
      expect(_b('b_seer').peopleLine(), startsWith('Arjun (B-702), Priya (A-1101) and 4 others'));
      expect(searchBuckets(_buckets(), 'seafood').map((b) => b.id), containsAll(['b_seer', 'b_paarai']));
      expect(searchBuckets(_buckets().where((b) => b.isLive), 'rice').map((b) => b.id), ['b_basmati']);
      expect(searchBuckets(_buckets().where((b) => b.isLive), 'kasi').map((b) => b.id), containsAll(['b_seer', 'b_paarai']));
      expect(_buckets().where((b) => inCategory(b, 'staples')).map((b) => b.id), ['b_basmati']);
    });
  });

  group('onboarding + auth', () {
    for (var i = 0; i < 3; i++) {
      _shot('slide ${i + 1}', 'discovery_onboarding_${i + 1}', () => WelcomeScreen(initialPage: i));
    }
    _shot('phone', 'discovery_phone', () => const PhoneScreen(), act: (t) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pump();
    });
    _shot('otp filled', 'discovery_otp', () => const OtpScreen(phone: '9000000001', autoSubmit: false), act: (t) async {
      await t.enterText(find.byType(TextField).first, '1234');
      await t.pump(const Duration(milliseconds: 200));
    });
    _shot(
      'join community',
      'discovery_join',
      () => const JoinCommunityScreen(),
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
    );
  });
}
