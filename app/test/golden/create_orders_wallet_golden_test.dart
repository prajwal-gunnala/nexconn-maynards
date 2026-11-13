@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jugaad_street/features/create_bucket/create_bucket_screen.dart';
import 'package:jugaad_street/features/create_bucket/form_bits.dart';
import 'package:jugaad_street/features/orders/order_screen.dart';
import 'package:jugaad_street/features/orders/orders_screen.dart';
import 'package:jugaad_street/features/wallet/wallet_screen.dart';

import 'harness.dart';

// Same frozen "now" as the other goldens (bucket_golden_test `goldenNow`: Fri 13 Nov, 3:35 am IST), so
// "left" and cutoff labels agree with the home and bucket shots.
DateTime _now() => DateTime.utc(2026, 11, 12, 22, 5).toLocal();

Finder get _form => find.descendant(of: find.byKey(const Key('create-form')), matching: find.byType(Scrollable)).first;

/// Images that appear after the first frame (step 2, scrolled sections) need decoding before the shot.
Future<void> _images(WidgetTester t) async {
  await t.runAsync(() async {
    for (final el in find.byType(Image).evaluate()) {
      await precacheImage((el.widget as Image).image, el, onError: (_, _) {});
    }
  });
  await t.pump(const Duration(milliseconds: 50));
}

Future<void> _template(WidgetTester t, String id) async {
  final f = find.byKey(Key('template-$id'));
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 100));
  await t.tap(f);
  await t.pump(const Duration(milliseconds: 400));
  await _images(t);
}

Future<void> _scrollTo(WidgetTester t, Finder f, {double extra = 0}) async {
  await t.scrollUntilVisible(f, 300, scrollable: _form);
  await t.pump(const Duration(milliseconds: 100));
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 100));
  if (extra != 0) {
    await t.drag(_form, Offset(0, -extra));
    await t.pump(const Duration(milliseconds: 300));
  }
  await _images(t);
}

/// The whole form card for a section title, so the shot starts at the card's top edge.
Finder _section(String title) => find.ancestor(of: find.text(title), matching: find.byType(FormSection));

// ---- One story for test data -------------------------------------------------------------------
// The fixtures have no active orders, so the two below are *derived* from the bucket fixtures (same
// members, quantities, prices, pickup point and times) rather than invented. Canonical basmati order:
// JS-2043, Ananya B-1204, 10 kg, held ₹960 → charged ₹880 → ₹80 back, OTP 5193, 8 households, 100 kg.

Map<String, dynamic> _fx(String name) => (fixture(name) as Map).cast<String, dynamic>();
Map<String, dynamic> _user(Object? u) => (u as Map).cast<String, dynamic>();

const _ist = Duration(hours: 5, minutes: 30);
const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Mirrors server/src/format.js (IST): "Sat 10:00 am" pieces.
(String, String, String) _parts(DateTime utc) {
  final t = utc.toUtc().add(_ist);
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return (_wd[t.weekday - 1], '$h:${t.minute.toString().padLeft(2, '0')}', t.hour < 12 ? 'am' : 'pm');
}

/// Server `fmtWindow(bucket)`: meet → "Sun 6:00 am at Gate 3", else deliverAt + 2 h.
String _window(Map<String, dynamic> b) {
  final meet = b['meet'] as Map?;
  if (meet?['at'] != null) {
    final (d, c, ap) = _parts(DateTime.parse(meet!['at'] as String));
    return '$d $c $ap at ${meet['place']}';
  }
  final from = DateTime.parse(b['deliverAt'] as String);
  final (d, c1, a1) = _parts(from);
  final (_, c2, a2) = _parts(from.add(const Duration(hours: 2)));
  return a1 == a2 ? '$d $c1–$c2 $a2' : '$d $c1 $a1–$c2 $a2';
}

Map<String, Object?> _line(Map<String, dynamic> user, num qty, String label, int amount,
        {String? shareId, String pay = 'hold', String status = 'captured', String? otp, int savings = 0, Object? options}) =>
    {
      'shareId': shareId ?? 's_${user['id']}', 'userId': user['id'], 'name': user['name'], 'unit': user['unit'], 'qty': qty,
      'qtyLabel': label, 'amount': amount, 'payMode': pay, 'paymentStatus': status, 'otp': otp, 'collected': false,
      'options': options, 'savings': savings,
    };

final _basmati = _fx('bucket_b_basmati');
final _ananyaUser = _user(_fx('me')['user']);
final _lakshmi = _user((_fx('bucket_b_pest')['shares'] as List).map(_user).firstWhere((s) => _user(s['user'])['name'] == 'Lakshmi')['user']);

/// Basmati at the ₹88 tier: the six fixture shares, Ananya's 10 kg and Lakshmi's 8 kg (= 100 kg).
final _riceLines = () {
  final tiers = (_basmati['tiers'] as List).map(_user).toList();
  final price = tiers.last['unitPrice'] as int; // 88, reached at 100 kg
  final retail = _basmati['retailUnitPrice'] as int; // 135
  Map<String, Object?> at(Map<String, dynamic> u, int kg, {String? id, String? otp}) =>
      _line(u, kg, '$kg kg', kg * price, shareId: id, otp: otp, savings: kg * (retail - price));
  return [
    for (final s in (_basmati['shares'] as List).map(_user)) at(_user(s['user']), s['qty'] as int, id: s['id'] as String),
    at(_ananyaUser, 10, otp: '5193'),
    at(_lakshmi, 8),
  ];
}();

int _sum(List<Map<String, Object?>> lines) => lines.fold(0, (a, l) => a + (l['amount'] as int));

final Map<String, Object?> _riceOrder = {
  'id': 'JS-2043', 'bucketId': 'b_basmati', 'communityId': _basmati['communityId'], 'vendorId': _user(_basmati['vendor'])['id'],
  'title': _basmati['title'], 'image': _basmati['image'], 'total': _sum(_riceLines), 'heldTotal': _sum(_riceLines), 'atPickupTotal': 0,
  'status': 'packed', 'createdAt': _basmati['cutoffAt'], 'pickupPoint': _basmati['pickupPoint'], 'window': _window(_basmati),
  'lines': _riceLines, 'myLine': {..._riceLines[6], 'heldAmount': 960},
};

/// The basmati bucket once it locked into JS-2043.
Map<String, dynamic> _basmatiOrdered() => {
      ..._basmati,
      'status': 'ordered',
      'orderId': 'JS-2043',
      'progress': {...(_basmati['progress'] as Map), 'filled': 100, 'members': 8, 'percent': 100, 'unitPrice': 88, 'nextTier': null},
      'myShare': {
        'id': 's_u_ananya', 'bucketId': 'b_basmati', 'user': _ananyaUser, 'qty': 10, 'qtyLabel': '10 kg', 'payMode': 'hold',
        'status': 'captured', 'estAmount': 960, 'finalAmount': 880, 'otp': '5193', 'orderId': 'JS-2043',
        'hold': {'id': 'h_r', 'amount': 960, 'status': 'captured', 'vpa': 'ananya@okaxis'},
      },
    };

/// Paarai book-and-meet once Ananya books the open tail half (Ravi has the head half in the fixture).
final _paarai = _fx('bucket_b_paarai');
final _fishLines = () {
  final retail = _paarai['retailUnitPrice'] as int;
  final units = (_paarai['units'] as List).map(_user).toList();
  final ravi = (_paarai['shares'] as List).map(_user).first;
  Map<String, Object?> half(Map<String, dynamic> u, Map<String, dynamic> unit, {String? otp, String? id, Object? options}) => _line(
        u, 1, unit['label'] as String, unit['price'] as int,
        shareId: id, pay: 'at_market', status: 'due', otp: otp, options: options,
        savings: ((unit['grams'] as int) / 1000 * retail).round() - (unit['price'] as int));
  return [
    half(_user(ravi['user']), units.firstWhere((u) => u['id'] == 'head_half'), id: ravi['id'] as String, options: ravi['options']),
    half(_ananyaUser, units.firstWhere((u) => u['id'] == 'tail_half'), otp: '4826', options: {'cut': 'Fry slices'}),
  ];
}();

final Map<String, Object?> _fishOrder = {
  'id': 'JS-2044', 'bucketId': 'b_paarai', 'communityId': _paarai['communityId'], 'vendorId': _user(_paarai['vendor'])['id'],
  'title': _paarai['title'], 'image': _paarai['image'], 'total': _sum(_fishLines), 'heldTotal': 0, 'atPickupTotal': _sum(_fishLines),
  'status': 'created', 'createdAt': _paarai['cutoffAt'], 'pickupPoint': (_paarai['meet'] as Map)['place'], 'window': _window(_paarai),
  'lines': _fishLines, 'myLine': _fishLines.last,
};

Map<String, Object?> _orderOverrides() => {
      '/api/me/orders': [_fishOrder, _riceOrder, ...(fixture('orders') as List)],
      '/api/orders/JS-2043': _riceOrder,
      '/api/orders/JS-2044': _fishOrder,
      '/api/buckets/b_basmati': _basmatiOrdered(),
    };


/// Registers the shot at 412×915 and again at a small phone (360×800, `NAME_360`).
void _shot(String desc, String name, Widget Function() screen,
    {Map<String, Object?> overrides = const {}, Future<void> Function(WidgetTester t)? act}) {
  testWidgets(desc, (t) => shoot(t, name, screen(), overrides: overrides, act: act));
  testWidgets('$desc @360', (t) => shoot(t, '${name}_360', screen(), overrides: overrides, act: (t) async {
        t.view.devicePixelRatio = 3;
        t.view.physicalSize = const Size(360, 800) * 3;
        await t.pump(const Duration(milliseconds: 200));
        await _images(t);
        if (act != null) await act(t);
      }));
}

void main() {
  group('create bucket', () {
    _shot('step 1', 'create_step1', () => const CreateBucketScreen(clock: _now));
    _shot('step 2 split (seer template)', 'create_step2_split', () => const CreateBucketScreen(clock: _now),
        act: (t) => _template(t, 'seer'));
    _shot('step 2 split shares', 'create_step2_split_shares', () => const CreateBucketScreen(clock: _now), act: (t) async {
      await _template(t, 'seer');
      await _scrollTo(t, _section('Total and shares'));
    });
    _shot('step 2 bulk tiers', 'create_step2_bulk', () => const CreateBucketScreen(clock: _now), act: (t) async {
      await _template(t, 'rice');
      await _scrollTo(t, _section('Price tiers'));
    });
    _shot('step 2 trip list', 'create_step2_trip', () => const CreateBucketScreen(clock: _now), act: (t) async {
      await _template(t, 'koyambedu');
      await _scrollTo(t, _section('The shopping list'));
    });
    _shot('step 2 at market', 'create_step2_market', () => const CreateBucketScreen(clock: _now), act: (t) async {
      await _template(t, 'meetup');
      await _scrollTo(t, _section('How do members pay?'));
    });
    _shot('step 2 at market cutoff', 'create_step2_market_cutoff', () => const CreateBucketScreen(clock: _now), act: (t) async {
      await _template(t, 'meetup');
      await _scrollTo(t, _section('Cutoff'));
    });
    _shot('preview', 'create_preview', () => const CreateBucketScreen(clock: _now), act: (t) async {
      await _template(t, 'seer');
      await _scrollTo(t, find.byKey(const Key('draft-preview')), extra: 200);
    });
    _shot('validation', 'create_validation', () => const CreateBucketScreen(clock: _now), act: (t) async {
      await t.tap(find.text('Bulk'));
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.text('Continue with Bulk'));
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.byKey(const Key('create-post')));
      await t.pump(const Duration(milliseconds: 500));
    });
    _shot('success', 'create_success', () => const CreateBucketScreen(clock: _now),
        overrides: {'POST /api/buckets': fixture('bucket_b_seer')}, act: (t) async {
      await _template(t, 'seer');
      await t.tap(find.byKey(const Key('create-post')));
      for (var i = 0; i < 5; i++) {
        await t.pump(const Duration(milliseconds: 20));
      }
      await t.pump(const Duration(milliseconds: 700));
    });
  });

  group('orders', () {
    _shot('list active', 'orders_active', () => const OrdersScreen(), overrides: _orderOverrides());
    _shot('list past', 'orders_past', () => const OrdersScreen(), overrides: _orderOverrides(), act: (t) async {
      await t.tap(find.textContaining('Past'));
      await t.pump(const Duration(milliseconds: 300));
      await _images(t);
    });
    _shot('list empty active', 'orders_empty', () => const OrdersScreen(), overrides: {'/api/me/orders': []});
    _shot('detail with OTP', 'order_detail_otp', () => const OrderScreen(orderId: 'JS-2043'), overrides: _orderOverrides());
    _shot('detail money', 'order_detail_money', () => const OrderScreen(orderId: 'JS-2043'), overrides: _orderOverrides(),
        act: (t) async {
      await t.drag(find.byType(Scrollable).first, const Offset(0, -450));
      await t.pump(const Duration(milliseconds: 400));
    });
    _shot('detail members', 'order_detail_members', () => const OrderScreen(orderId: 'JS-2043'), overrides: _orderOverrides(),
        act: (t) async {
      await t.drag(find.byType(Scrollable).first, const Offset(0, -900));
      await t.pump(const Duration(milliseconds: 400));
    });
    _shot('detail at market', 'order_detail_market', () => const OrderScreen(orderId: 'JS-2044'), overrides: _orderOverrides());
    _shot('detail at market lower', 'order_detail_market_lower', () => const OrderScreen(orderId: 'JS-2044'),
        overrides: _orderOverrides(), act: (t) async {
      await t.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await t.pump(const Duration(milliseconds: 400));
    });
    _shot('detail delivered', 'order_detail_delivered', () => OrderScreen(orderId: (fixture('orders') as List).first['id'] as String));
    _shot('detail error', 'order_detail_error', () => const OrderScreen(orderId: 'JS-9999'), overrides: {'/api/orders/JS-9999': null});
  });

  group('wallet', () {
    _shot('default', 'wallet', () => const WalletScreen(clock: _now));
    _shot('filter paid', 'wallet_filter_paid', () => const WalletScreen(clock: _now), act: (t) async {
      await t.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const Key('wallet-filter-paid')));
      await t.pump(const Duration(milliseconds: 400));
    });
    _shot('empty', 'wallet_empty', () => const WalletScreen(clock: _now), overrides: {
      '/api/me/wallet': {'heldNow': 0, 'paidThisMonth': 0, 'releasedThisMonth': 0, 'savedTotal': 0, 'savedThisMonth': 0, 'entries': []},
    });
  });
}
