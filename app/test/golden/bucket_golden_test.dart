@Tags(['golden'])
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:jugaad_street/core/api/api_client.dart';
import 'package:jugaad_street/features/bucket/bucket_detail_screen.dart';
import 'package:jugaad_street/features/bucket/detail_model.dart';
import 'package:jugaad_street/features/bucket/detail_widgets.dart';
import 'package:jugaad_street/features/hold/hold_draft.dart';
import 'package:jugaad_street/features/hold/hold_screen.dart';

import 'harness.dart';

// ---- fixtures with times moved to "now", so countdowns look like a live demo ----------------

Map<String, dynamic> bucketFx(String id, {Duration closesIn = const Duration(hours: 6)}) {
  final j = (fixture('bucket_$id') as Map).cast<String, dynamic>();
  final cutoff = DateTime.tryParse(j['cutoffAt'] as String? ?? '');
  if (cutoff == null || j['status'] != 'live') return j;
  final delta = DateTime.now().add(closesIn).difference(cutoff);
  String? shift(Object? v) => v is String ? DateTime.parse(v).add(delta).toUtc().toIso8601String() : null;
  j['cutoffAt'] = shift(j['cutoffAt']);
  j['deliverAt'] = shift(j['deliverAt']);
  final meet = j['meet'];
  if (meet is Map) j['meet'] = {...meet, 'at': shift(meet['at'])};
  return j;
}

Map<String, dynamic> me() => {'id': 'u_ananya', 'name': 'Ananya', 'unit': 'B-1204'};

/// Wraps [child] with its own ApiClient so a test can return errors or hang.
Widget withApi(Widget child, Future<http.Response> Function(http.Request req, MockClient fallback) handler,
    {Map<String, Object?> overrides = const {}}) {
  final fallback = fixtureHttp(overrides: overrides);
  final api = ApiClient(baseUrl: 'http://test', httpClient: MockClient((req) => handler(req, fallback)));
  return Provider<ApiClient>.value(value: api, child: child);
}

Future<http.Response> passThrough(http.Request req, MockClient fallback) async {
  final copy = http.Request(req.method, req.url)
    ..headers.addAll(req.headers)
    ..body = req.body;
  return http.Response.fromStream(await fallback.send(copy));
}

http.Response jsonError(int status, String code, String message) => http.Response(
      jsonEncode({'error': {'code': code, 'message': message}}),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Future<void> settle(WidgetTester t, {int ms = 900}) async {
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> scrollDown(WidgetTester t, double dy) async {
  await t.drag(find.byType(CustomScrollView).first, Offset(0, -dy));
  await t.pump(const Duration(milliseconds: 600));
}

Future<void> scrollTo(WidgetTester t, Finder f, {double alignment = 0.15}) async {
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 600));
}

/// Scrolls until [f] is near the top of the page (below the pinned bar), then [up] px back.
Future<void> reveal(WidgetTester t, Finder f, {double up = 0}) async {
  await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first, maxScrolls: 40);
  await t.pump(const Duration(milliseconds: 300));
  final y = t.getTopLeft(f).dy;
  final dy = y - 120 - up;
  if (dy.abs() > 4) await t.drag(find.byType(CustomScrollView).first, Offset(0, -dy));
  await t.pump(const Duration(milliseconds: 600));
}

Map<String, Object?> detailOv(String id, Map<String, dynamic> j) => {'/api/buckets/$id': j};

void main() {
  // ---- detail, every live type ---------------------------------------------------------------

  testWidgets('seer split', (t) async {
    final j = bucketFx('b_seer', closesIn: const Duration(hours: 2, minutes: 40));
    await shoot(t, 'detail_seer', const BucketDetailScreen(bucketId: 'b_seer'), overrides: detailOv('b_seer', j));
  });

  testWidgets('seer share map', (t) async {
    final j = bucketFx('b_seer', closesIn: const Duration(hours: 2, minutes: 40));
    await shoot(t, 'detail_seer_map', const BucketDetailScreen(bucketId: 'b_seer'),
        overrides: detailOv('b_seer', j), act: (t) async => scrollDown(t, 520));
  });

  testWidgets('seer cut selected', (t) async {
    final j = bucketFx('b_seer', closesIn: const Duration(hours: 2, minutes: 40));
    await shoot(t, 'detail_seer_selected', const BucketDetailScreen(bucketId: 'b_seer'), overrides: detailOv('b_seer', j),
        act: (t) async {
      await scrollDown(t, 560);
      await t.tap(find.text('Steak 2 · ₹680'));
      await t.pump(const Duration(milliseconds: 400));
      await scrollDown(t, 160);
    });
  });

  testWidgets('seer lower page', (t) async {
    final j = bucketFx('b_seer', closesIn: const Duration(hours: 2, minutes: 40));
    await shoot(t, 'detail_seer_lower', const BucketDetailScreen(bucketId: 'b_seer'), overrides: detailOv('b_seer', j),
        act: (t) async => reveal(t, find.text('How your money works')));
  });

  testWidgets('goat tiles', (t) async {
    final j = bucketFx('b_goat', closesIn: const Duration(days: 1, hours: 18));
    await shoot(t, 'detail_goat', const BucketDetailScreen(bucketId: 'b_goat'), overrides: detailOv('b_goat', j),
        act: (t) async {
      await scrollDown(t, 560);
      final open = find.textContaining('Open');
      if (open.evaluate().isNotEmpty) await t.tap(open.first);
      await t.pump(const Duration(milliseconds: 400));
    });
  });

  testWidgets('basmati bulk', (t) async {
    final j = bucketFx('b_basmati', closesIn: const Duration(hours: 17));
    await shoot(t, 'detail_basmati', const BucketDetailScreen(bucketId: 'b_basmati'), overrides: detailOv('b_basmati', j));
  });

  testWidgets('basmati tiers', (t) async {
    final j = bucketFx('b_basmati', closesIn: const Duration(hours: 17));
    await shoot(t, 'detail_basmati_tiers', const BucketDetailScreen(bucketId: 'b_basmati'), overrides: detailOv('b_basmati', j),
        act: (t) async => scrollDown(t, 520));
  });

  testWidgets('alphonso bulk', (t) async {
    final j = bucketFx('b_alphonso', closesIn: const Duration(hours: 20));
    await shoot(t, 'detail_alphonso', const BucketDetailScreen(bucketId: 'b_alphonso'), overrides: detailOv('b_alphonso', j),
        act: (t) async => scrollDown(t, 520));
  });

  testWidgets('pest service live', (t) async {
    final j = bucketFx('b_pest', closesIn: const Duration(days: 2, hours: 4))..['myShare'] = null;
    j['shares'] = (j['shares'] as List).where((s) => (s as Map)['user']['id'] != 'u_ananya').toList();
    await shoot(t, 'detail_pest', const BucketDetailScreen(bucketId: 'b_pest'), overrides: detailOv('b_pest', j),
        act: (t) async => scrollDown(t, 520));
  });

  testWidgets('pest my share', (t) async {
    final j = bucketFx('b_pest', closesIn: const Duration(days: 2, hours: 4));
    await shoot(t, 'detail_pest_myshare', const BucketDetailScreen(bucketId: 'b_pest'), overrides: detailOv('b_pest', j),
        act: (t) async => scrollDown(t, 420));
  });

  testWidgets('trip list', (t) async {
    final j = bucketFx('b_trip', closesIn: const Duration(hours: 9));
    await shoot(t, 'detail_trip', const BucketDetailScreen(bucketId: 'b_trip'), overrides: detailOv('b_trip', j),
        act: (t) async => scrollDown(t, 560));
  });

  testWidgets('trip list with my items', (t) async {
    final j = bucketFx('b_trip', closesIn: const Duration(hours: 9));
    await shoot(t, 'detail_trip_items', const BucketDetailScreen(bucketId: 'b_trip'), overrides: detailOv('b_trip', j),
        act: (t) async {
      final plus = find.descendant(of: find.byType(QtyStepper), matching: find.byIcon(Icons.add_rounded));
      Future<void> add(String name, int extra) async {
        final row = find.ancestor(of: find.text(name), matching: find.byType(Row)).first;
        final btn = find.descendant(of: row, matching: find.text('Add'));
        await t.ensureVisible(btn);
        await t.pump(const Duration(milliseconds: 300));
        await t.tap(btn);
        await t.pump(const Duration(milliseconds: 300));
        for (var i = 0; i < extra; i++) {
          await t.tap(find.descendant(of: row, matching: plus));
          await t.pump(const Duration(milliseconds: 100));
        }
      }
      await add('Onion', 4);
      await add('Tomato', 2);
      await add('Coconut', 3);
      await reveal(t, find.text('Add from the list'));
    });
  });

  testWidgets('paarai book and meet', (t) async {
    final j = bucketFx('b_paarai', closesIn: const Duration(hours: 19));
    await shoot(t, 'detail_paarai', const BucketDetailScreen(bucketId: 'b_paarai'), overrides: detailOv('b_paarai', j),
        act: (t) async {
      await scrollDown(t, 520);
      await t.tap(find.text('Open').first);
      await t.pump(const Duration(milliseconds: 300));
    });
  });

  testWidgets('paarai meet card', (t) async {
    final j = bucketFx('b_paarai', closesIn: const Duration(hours: 19));
    await shoot(t, 'detail_paarai_meet', const BucketDetailScreen(bucketId: 'b_paarai'), overrides: detailOv('b_paarai', j),
        act: (t) async => reveal(t, find.text('Meet at the market')));
  });

  testWidgets('paarai market day check-in', (t) async {
    final j = bucketFx('b_paarai', closesIn: const Duration(hours: 19));
    j['status'] = 'market_day';
    j['orderId'] = 'JS-2044';
    final units = (j['units'] as List).cast<Map<String, dynamic>>();
    units[1] = {...units[1], 'owner': me()};
    final mine = {
      'id': 's_mine', 'bucketId': 'b_paarai', 'user': me(), 'qty': 1, 'qtyLabel': 'Tail half', 'unitIds': ['tail_half'],
      'items': null, 'options': {'cut': 'Fry slices'}, 'payMode': 'at_market', 'status': 'booked', 'estAmount': 700,
      'finalAmount': null, 'hold': null, 'otp': null,
    };
    j['myShare'] = mine;
    j['shares'] = [...(j['shares'] as List), mine];
    j['progress'] = {...(j['progress'] as Map), 'filled': 2, 'members': 2, 'percent': 100};
    await shoot(t, 'detail_paarai_checkin', const BucketDetailScreen(bucketId: 'b_paarai'), overrides: detailOv('b_paarai', j),
        act: (t) async => reveal(t, find.text("I'm here"), up: 560));
  });

  // ---- closed states ---------------------------------------------------------------------

  testWidgets('prawns completed', (t) async {
    await shoot(t, 'detail_prawns_completed', const BucketDetailScreen(bucketId: 'b_past_prawns'));
  });

  testWidgets('prawns completed lower', (t) async {
    await shoot(t, 'detail_prawns_completed_lower', const BucketDetailScreen(bucketId: 'b_past_prawns'),
        act: (t) async => scrollDown(t, 600));
  });

  testWidgets('crab expired', (t) async {
    await shoot(t, 'detail_crab_expired', const BucketDetailScreen(bucketId: 'b_past_crab'));
  });

  // ---- loading + error -------------------------------------------------------------------

  testWidgets('loading skeleton', (t) async {
    final never = Completer<http.Response>();
    await shoot(t, 'detail_loading', withApi(const BucketDetailScreen(bucketId: 'b_seer'), (req, fb) => never.future));
  });

  testWidgets('error', (t) async {
    await shoot(
      t,
      'detail_error',
      withApi(const BucketDetailScreen(bucketId: 'b_seer'),
          (req, fb) async => jsonError(503, 'NETWORK', "Can't reach the server. Check your connection.")),
    );
  });

  // ---- hold flow -------------------------------------------------------------------------

  HoldRequest basmatiReq() =>
      HoldRequest(view: BucketView.fromJson(bucketFx('b_basmati', closesIn: const Duration(hours: 17))), draft: const JoinDraft(qty: 10));

  Map<String, dynamic> pendingShare(int amount) => {
        'id': 's_new', 'bucketId': 'b_basmati', 'user': me(), 'qty': 10, 'qtyLabel': '10 kg', 'unitIds': null, 'items': null,
        'options': null, 'payMode': 'hold', 'status': 'pending_payment', 'estAmount': amount, 'finalAmount': null,
        'hold': {'id': 'h_new', 'amount': amount, 'status': 'created', 'vpa': null}, 'otp': null,
      };

  Map<String, dynamic> basmatiAfter() {
    final j = bucketFx('b_basmati', closesIn: const Duration(hours: 17));
    j['progress'] = {...(j['progress'] as Map), 'filled': 97, 'members': 8, 'percent': 97, 'held': 9312,
      'nextTier': {'minQty': 100, 'unitPrice': 88, 'remaining': 3}};
    return j;
  }

  Map<String, Object?> holdOv() => {
        'POST /api/buckets/b_basmati/shares': {'share': pendingShare(960), 'bucket': bucketFx('b_basmati')},
        'POST /api/holds/h_new/authorize': {
          'share': {...pendingShare(960), 'status': 'held', 'hold': {'id': 'h_new', 'amount': 960, 'status': 'held', 'vpa': 'ananya@okaxis'}},
          'bucket': basmatiAfter(),
        },
      };

  testWidgets('hold sheet empty', (t) async {
    await shoot(t, 'hold_sheet', HoldScreen(bucketId: 'b_basmati', request: basmatiReq()), overrides: holdOv(),
        act: (t) async => settle(t));
  });

  testWidgets('hold sheet 3 digits', (t) async {
    await shoot(t, 'hold_sheet_3digits', HoldScreen(bucketId: 'b_basmati', request: basmatiReq(), initialPin: '123'),
        overrides: holdOv(), act: (t) async => settle(t));
  });

  testWidgets('hold pin error', (t) async {
    final screen = withApi(
      HoldScreen(bucketId: 'b_basmati', request: basmatiReq()),
      (req, fb) async => req.url.path.endsWith('/authorize')
          ? jsonError(400, 'PIN_INCORRECT', 'Incorrect UPI PIN. No money was blocked.')
          : passThrough(req, fb),
      overrides: holdOv(),
    );
    await shoot(t, 'hold_pin_error', screen, act: (t) async {
      await settle(t, ms: 300);
      for (var i = 0; i < 4; i++) {
        await t.tap(find.bySemanticsLabel('Digit 0'));
        await t.pump(const Duration(milliseconds: 50));
      }
      await t.tap(find.bySemanticsLabel('Authorize hold'));
      await settle(t, ms: 500);
    });
  });

  testWidgets('hold success', (t) async {
    await shoot(t, 'hold_success', HoldScreen(bucketId: 'b_basmati', request: basmatiReq()), overrides: holdOv(),
        act: (t) async {
      await settle(t, ms: 300);
      for (final d in '482915'.split('')) {
        await t.tap(find.bySemanticsLabel('Digit $d'));
        await t.pump(const Duration(milliseconds: 50));
      }
      await settle(t, ms: 1500);
    });
  });

  testWidgets('seer hold sheet', (t) async {
    final v = BucketView.fromJson(bucketFx('b_seer', closesIn: const Duration(hours: 2, minutes: 40)));
    final share = {
      ...pendingShare(680), 'bucketId': 'b_seer', 'qty': 1, 'qtyLabel': 'Steak 2', 'unitIds': ['s2'], 'options': {'cut': 'Curry cut'},
    };
    await shoot(
      t,
      'hold_sheet_seer',
      HoldScreen(bucketId: 'b_seer', request: HoldRequest(view: v, draft: const JoinDraft(unitIds: ['s2'], options: {'cut': 'Curry cut'}))),
      overrides: {'POST /api/buckets/b_seer/shares': {'share': share, 'bucket': bucketFx('b_seer')}},
      act: (t) async => settle(t),
    );
  });

  testWidgets('paarai booked', (t) async {
    final j = bucketFx('b_paarai', closesIn: const Duration(hours: 19));
    final after = jsonDecode(jsonEncode(j)) as Map<String, dynamic>;
    final units = (after['units'] as List).cast<Map<String, dynamic>>();
    units[1] = {...units[1], 'owner': me()};
    final mine = {
      'id': 's_mine', 'bucketId': 'b_paarai', 'user': me(), 'qty': 1, 'qtyLabel': 'Tail half', 'unitIds': ['tail_half'],
      'items': null, 'options': {'cut': 'Fry slices'}, 'payMode': 'at_market', 'status': 'booked', 'estAmount': 700,
      'finalAmount': null, 'hold': null, 'otp': null,
    };
    after['shares'] = [...(after['shares'] as List), mine];
    after['myShare'] = mine;
    after['progress'] = {...(after['progress'] as Map), 'filled': 2, 'members': 2, 'percent': 100};
    await shoot(
      t,
      'hold_booked_paarai',
      HoldScreen(
        bucketId: 'b_paarai',
        request: HoldRequest(view: BucketView.fromJson(j), draft: const JoinDraft(unitIds: ['tail_half'], options: {'cut': 'Fry slices'})),
      ),
      overrides: {'POST /api/buckets/b_paarai/shares': {'share': mine, 'bucket': after}},
      act: (t) async => settle(t),
    );
  });
}
