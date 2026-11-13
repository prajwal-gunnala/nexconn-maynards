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

// Fixed "now" so cutoff labels in the shots don't drift (Fri 13 Nov 2026, 10:30 am).
DateTime _now() => DateTime(2026, 11, 13, 10, 30);

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

const _ananya = {'userId': 'u_ananya', 'name': 'Ananya', 'unit': 'B-1204'};

Map<String, Object?> _line(String id, String name, String unit, num qty, String label, int amount,
        {String pay = 'hold', String status = 'captured', String? otp, bool collected = false, int savings = 0, Map<String, String>? options}) =>
    {
      'shareId': 's_$id', 'userId': id, 'name': name, 'unit': unit, 'qty': qty, 'qtyLabel': label, 'amount': amount,
      'payMode': pay, 'paymentStatus': status, 'otp': otp, 'collected': collected, 'options': options, 'savings': savings,
    };

final _riceLines = [
  _line('u_ananya', 'Ananya', 'B-1204', 10, '10 kg', 880, otp: '5193', savings: 470),
  _line('u_meera', 'Meera', 'A-303', 15, '15 kg', 1320, savings: 705),
  _line('u_ravi', 'Ravi', 'C-801', 20, '20 kg', 1760, savings: 940),
  _line('u_kiran', 'Kiran', 'B-402', 10, '10 kg', 880, savings: 470),
  _line('u_priya', 'Priya', 'A-1101', 12, '12 kg', 1056, savings: 564),
  _line('u_arjun', 'Arjun', 'B-702', 15, '15 kg', 1320, savings: 705),
  _line('u_sunita', 'Sunita', 'A-201', 10, '10 kg', 880, savings: 470),
  _line('n_venkat', 'Venkat', 'D-604', 12, '12 kg', 1056, savings: 564),
];

final Map<String, Object?> _riceOrder = {
  'id': 'JS-2043', 'bucketId': 'b_basmati', 'communityId': 'c_seabreeze', 'vendorId': 'v_balaji',
  'title': 'Aged Basmati Rice (1121)', 'image': 'basmati', 'total': 9152, 'heldTotal': 9152, 'atPickupTotal': 0,
  'status': 'packed', 'createdAt': '2026-11-13T14:30:00.000Z', 'pickupPoint': 'Clubhouse', 'window': 'Sat 10:00 am–12:00 pm',
  'lines': _riceLines, 'myLine': {..._riceLines.first, 'heldAmount': 960},
};

final _fishLines = [
  _line('u_ravi', 'Ravi', 'C-801', 1, 'Head half', 760, pay: 'at_market', status: 'due', savings: 500, options: {'cut': 'Curry cut'}),
  _line('u_ananya', 'Ananya', 'B-1204', 1, 'Tail half', 700, pay: 'at_market', status: 'due', otp: '4826', savings: 560,
      options: {'cut': 'Fry slices'}),
];

final Map<String, Object?> _fishOrder = {
  'id': 'JS-2044', 'bucketId': 'b_paarai', 'communityId': 'c_seabreeze', 'vendorId': 'v_murugan',
  'title': 'Kasimedu Book & Meet: Whole Paarai', 'image': 'paarai', 'total': 1460, 'heldTotal': 0, 'atPickupTotal': 1460,
  'status': 'created', 'createdAt': '2026-11-14T16:30:00.000Z', 'pickupPoint': 'Gate 3', 'window': 'Sun 6:00 am at Gate 3',
  'lines': _fishLines, 'myLine': _fishLines.last,
};

Map<String, Object?> _orderOverrides() => {
      '/api/me/orders': [_fishOrder, _riceOrder, ...(fixture('orders') as List)],
      '/api/orders/JS-2043': _riceOrder,
      '/api/orders/JS-2044': _fishOrder,
      '/api/buckets/b_basmati': {
        ...(fixture('bucket_b_basmati') as Map<String, dynamic>),
        'status': 'ordered',
        'myShare': {
          'id': 's_u_ananya', 'bucketId': 'b_basmati', 'user': _ananya, 'qty': 10, 'payMode': 'hold', 'status': 'captured',
          'estAmount': 960, 'finalAmount': 880, 'hold': {'id': 'h_r', 'amount': 960, 'status': 'captured', 'vpa': 'ananya@okaxis'},
        },
      },
    };

DateTime _walletNow() => DateTime(2026, 11, 13, 10, 30);

void main() {
  group('create bucket', () {
    testWidgets('step 1', (t) => shoot(t, 'create_step1', const CreateBucketScreen(clock: _now)));

    testWidgets('step 2 split (seer template)', (t) => shoot(t, 'create_step2_split', const CreateBucketScreen(clock: _now),
        act: (t) => _template(t, 'seer')));

    testWidgets('step 2 split shares', (t) => shoot(t, 'create_step2_split_shares', const CreateBucketScreen(clock: _now), act: (t) async {
          await _template(t, 'seer');
          await _scrollTo(t, _section('Total and shares'));
        }));

    testWidgets('step 2 bulk tiers', (t) => shoot(t, 'create_step2_bulk', const CreateBucketScreen(clock: _now), act: (t) async {
          await _template(t, 'rice');
          await _scrollTo(t, _section('Price tiers'));
        }));

    testWidgets('step 2 trip list', (t) => shoot(t, 'create_step2_trip', const CreateBucketScreen(clock: _now), act: (t) async {
          await _template(t, 'koyambedu');
          await _scrollTo(t, _section('The shopping list'));
        }));

    testWidgets('step 2 at market', (t) => shoot(t, 'create_step2_market', const CreateBucketScreen(clock: _now), act: (t) async {
          await _template(t, 'meetup');
          await _scrollTo(t, _section('How do members pay?'));
        }));

    testWidgets('preview', (t) => shoot(t, 'create_preview', const CreateBucketScreen(clock: _now), act: (t) async {
          await _template(t, 'seer');
          await _scrollTo(t, find.byKey(const Key('draft-preview')), extra: 200);
        }));

    testWidgets('validation', (t) => shoot(t, 'create_validation', const CreateBucketScreen(clock: _now), act: (t) async {
          await t.tap(find.text('Bulk'));
          await t.pump(const Duration(milliseconds: 200));
          await t.tap(find.text('Continue with Bulk'));
          await t.pump(const Duration(milliseconds: 400));
          await t.tap(find.byKey(const Key('create-post')));
          await t.pump(const Duration(milliseconds: 500));
        }));

    testWidgets('success', (t) => shoot(t, 'create_success', const CreateBucketScreen(clock: _now),
            overrides: {'POST /api/buckets': fixture('bucket_b_seer')}, act: (t) async {
          await _template(t, 'seer');
          await t.tap(find.byKey(const Key('create-post')));
          for (var i = 0; i < 5; i++) {
            await t.pump(const Duration(milliseconds: 20));
          }
          await t.pump(const Duration(milliseconds: 700));
        }));
  });
  group('orders', () {
    testWidgets('list active', (t) => shoot(t, 'orders_active', const OrdersScreen(), overrides: _orderOverrides()));
    testWidgets('list past', (t) => shoot(t, 'orders_past', const OrdersScreen(), overrides: _orderOverrides(), act: (t) async {
          await t.tap(find.textContaining('Past'));
          await t.pump(const Duration(milliseconds: 300));
          await _images(t);
        }));
    testWidgets('list empty active', (t) => shoot(t, 'orders_empty', const OrdersScreen(), overrides: {'/api/me/orders': []}));
    testWidgets('detail with OTP', (t) => shoot(t, 'order_detail_otp', const OrderScreen(orderId: 'JS-2043'), overrides: _orderOverrides()));
    testWidgets('detail members', (t) => shoot(t, 'order_detail_members', const OrderScreen(orderId: 'JS-2043'), overrides: _orderOverrides(),
        act: (t) async {
          await t.drag(find.byType(Scrollable).first, const Offset(0, -700));
          await t.pump(const Duration(milliseconds: 400));
        }));
    testWidgets('detail at market', (t) => shoot(t, 'order_detail_market', const OrderScreen(orderId: 'JS-2044'), overrides: _orderOverrides()));
    testWidgets('detail at market lower', (t) => shoot(t, 'order_detail_market_lower', const OrderScreen(orderId: 'JS-2044'),
        overrides: _orderOverrides(), act: (t) async {
          await t.drag(find.byType(Scrollable).first, const Offset(0, -700));
          await t.pump(const Duration(milliseconds: 400));
        }));
    testWidgets('detail delivered', (t) => shoot(t, 'order_detail_delivered', const OrderScreen(orderId: 'JS-2041')));
    testWidgets('detail error', (t) => shoot(t, 'order_detail_error', const OrderScreen(orderId: 'JS-9999'), overrides: {'/api/orders/JS-9999': null}));
  });

  group('wallet', () {
    testWidgets('default', (t) => shoot(t, 'wallet', const WalletScreen(clock: _walletNow)));
    testWidgets('filter paid', (t) => shoot(t, 'wallet_filter_paid', const WalletScreen(clock: _walletNow), act: (t) async {
          await t.drag(find.byType(Scrollable).first, const Offset(0, -300));
          await t.pump(const Duration(milliseconds: 300));
          await t.tap(find.byKey(const Key('wallet-filter-paid')));
          await t.pump(const Duration(milliseconds: 400));
        }));
    testWidgets('empty', (t) => shoot(t, 'wallet_empty', const WalletScreen(clock: _walletNow), overrides: {
          '/api/me/wallet': {'heldNow': 0, 'paidThisMonth': 0, 'releasedThisMonth': 0, 'savedTotal': 0, 'savedThisMonth': 0, 'entries': []},
        }));
  });
}
