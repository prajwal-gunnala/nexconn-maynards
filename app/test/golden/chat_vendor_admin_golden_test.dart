@Tags(['golden'])
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jugaad_street/core/nexconn/js_messages.dart';
import 'package:jugaad_street/core/theme/tokens.dart';
import 'package:jugaad_street/features/admin/admin_screen.dart';
import 'package:jugaad_street/features/chat/chat_avatar.dart';
import 'package:jugaad_street/features/chat/js_bubbles.dart';
import 'package:jugaad_street/features/vendor/handover_screen.dart';
import 'package:jugaad_street/features/vendor/vendor_screen.dart';

import 'harness.dart';

// All data comes from test/fixtures (recorded from a fresh seed) and matches the buyer-side goldens
// (create_orders_wallet_golden_test.dart): basmati order JS-2043, Ananya B-1204 10 kg ₹880, OTP 5193.

Map<String, dynamic> _bucket(String id) => (fixture('bucket_$id') as Map).cast<String, dynamic>();

/// `js:bucket` content fields exactly as the server posts them for a fixture bucket.
Map<String, String> _cardFields(Map<String, dynamic> b) => {
      'bucketId': b['id'] as String,
      'type': b['type'] as String,
      'title': b['title'] as String,
      'subtitle': (b['subtitle'] ?? '') as String,
      'image': (b['image'] ?? '') as String,
      'vendor': ((b['vendor'] as Map?)?['name'] ?? '') as String,
      'cutoffAt': DateTime.now().add(const Duration(hours: 9, minutes: 55)).toUtc().toIso8601String(),
      'unitLabel': (b['unitLabel'] ?? '') as String,
    };

/// Card metadata (`p`, `s`, `u`) for a fixture bucket, optionally with progress changes.
Map<String, String> _cardMeta(Map<String, dynamic> b, {Map<String, dynamic> progress = const {}}) {
  final units = b['units'] as List?;
  return {
    'p': jsonEncode({...(b['progress'] as Map), ...progress}),
    's': b['status'] as String,
    if (units != null)
      'u': jsonEncode([
        for (final u in units.cast<Map>())
          [u['id'], ((u['owner'] as Map?)?['name'] as String?)?.substring(0, 1) ?? ''],
      ]),
  };
}

Widget _chatCanvas(List<Widget> children) => Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.gutter),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final c in children) Padding(padding: const EdgeInsets.only(bottom: AppSpace.md), child: c),
          ]),
        ),
      ),
    );

Map<String, Object?> _line(String id, String name, String unit, num qty, String label, int amount, {bool collected = false}) => {
      'shareId': 's_$id', 'userId': id, 'name': name, 'unit': unit, 'qty': qty, 'qtyLabel': label, 'amount': amount,
      'payMode': 'hold', 'paymentStatus': 'captured', 'otp': null, 'collected': collected, 'options': null,
    };

/// Same lines as the buyer's order detail (vendor view: no OTPs).
final _riceLines = [
  _line('u_ananya', 'Ananya', 'B-1204', 10, '10 kg', 880),
  _line('u_meera', 'Meera', 'A-303', 15, '15 kg', 1320),
  _line('u_ravi', 'Ravi', 'C-801', 20, '20 kg', 1760),
  _line('u_kiran', 'Kiran', 'B-402', 10, '10 kg', 880),
  _line('u_priya', 'Priya', 'A-1101', 12, '12 kg', 1056),
  _line('u_arjun', 'Arjun', 'B-702', 15, '15 kg', 1320),
  _line('u_sunita', 'Sunita', 'A-201', 10, '10 kg', 880),
  _line('n_venkat', 'Venkat', 'D-604', 12, '12 kg', 1056),
];

Map<String, Object?> _riceOrder(List<Map<String, Object?>> lines) => {
      'id': 'JS-2043', 'bucketId': 'b_basmati', 'communityId': 'c_seabreeze', 'vendorId': 'v_balaji',
      'title': 'Aged Basmati Rice (1121)', 'image': 'basmati', 'total': 9152, 'heldTotal': 9152, 'atPickupTotal': 0,
      'status': 'packed', 'pickupPoint': 'Clubhouse', 'window': 'Sat 10:00 am–12:00 pm', 'lines': lines,
    };

/// The vendor dashboard after basmati filled: basmati moves to "ordered" and its lines join the packing list.
Map<String, dynamic> _vendorAfterOrder() {
  final d = (fixture('vendor_dashboard') as Map).cast<String, dynamic>();
  final buckets = (d['buckets'] as List).cast<Map<String, dynamic>>();
  final rice = buckets.firstWhere((b) => b['id'] == 'b_basmati');
  final held = ((rice['progress'] as Map)['held'] as num).toInt();
  return {
    ...d,
    'heldDemand': (d['heldDemand'] as num).toInt() - held,
    'buckets': [
      for (final b in buckets)
        b['id'] == 'b_basmati'
            ? {
                ...b,
                'status': 'ordered',
                'orderId': 'JS-2043',
                'progress': {...(b['progress'] as Map), 'filled': 104, 'members': 8, 'percent': 100, 'unitPrice': 88, 'held': 0, 'nextTier': null},
              }
            : b,
    ],
    'packing': [
      {
        'communityId': 'c_seabreeze',
        'communityName': 'Sea Breeze Towers',
        'lines': [for (final l in _riceLines) {...l, 'orderId': 'JS-2043', 'title': 'Aged Basmati Rice (1121)'}],
      },
    ],
  };
}

Future<void> _typeOtp(WidgetTester t, String otp) async {
  for (final k in otp.split('')) {
    await t.tap(find.bySemanticsLabel(k).last);
    await t.pump();
  }
}

void main() {
  testWidgets('chat bubbles: bucket cards', (t) async {
    final seer = _bucket('b_seer');
    final rice = _bucket('b_basmati');
    // Live: Venkat's 12 kg took basmati from 92 to 104 kg and unlocked ₹88/kg.
    final riceMeta = _cardMeta(rice, progress: {'filled': 104, 'members': 8, 'percent': 100, 'unitPrice': 88, 'nextTier': null});
    await shoot(
      t,
      'chat_bubbles_cards',
      _chatCanvas([
        BucketChatCard(data: BucketCardData.from(_cardFields(seer), _cardMeta(seer)), meta: _cardMeta(seer)),
        BucketChatCard(data: BucketCardData.from(_cardFields(rice), riceMeta), meta: riceMeta, flash: true, oldPrice: 96),
      ]),
    );
  });

  testWidgets('chat bubbles: events, order, otp', (t) async {
    await shoot(
      t,
      'chat_bubbles_system',
      _chatCanvas([
        const Center(child: JsEventPill(fields: {'bucketId': 'b_basmati', 'kind': 'joined', 'text': 'Ananya (B-1204) took 10 kg'})),
        const Center(
          child: JsEventPill(fields: {
            'bucketId': 'b_basmati',
            'kind': 'joined',
            'text': 'Venkat (D-604) took 12 kg and unlocked ₹88/kg for everyone!',
          }),
        ),
        const Center(
          child: JsEventPill(fields: {
            'bucketId': 'b_seer',
            'kind': 'nudge',
            'text': 'Whole Seer (Vanjaram): Steak 2 and Tail are still open. 2 cuts left.',
          }),
        ),
        const JsOrderCard(fields: {'orderId': 'JS-2043', 'bucketId': 'b_basmati', 'title': 'Aged Basmati Rice (1121)', 'total': '9152', 'members': '8'}),
        const JsOtpCard(fields: {'orderId': 'JS-2043', 'otp': '5193', 'pickupPoint': 'Clubhouse', 'window': 'Sat 10:00 am–12:00 pm'}),
      ]),
    );
  });

  testWidgets('chat avatars', (t) async {
    await shoot(
      t,
      'chat_avatars',
      _chatCanvas([
        const Wrap(spacing: 12, runSpacing: 12, children: [
          ChatAvatar(id: 'jugaad_bot', kind: 'bot', size: 48),
          ChatAvatar(id: 'u_ravi', name: 'Ravi', size: 48),
          ChatAvatar(id: 'u_meera', name: 'Meera', size: 48),
          ChatAvatar(id: 'u_ananya', name: 'Ananya', size: 48),
          ChatAvatar(id: 'u_priya', name: 'Priya', kind: 'admin', size: 48),
          ChatAvatar(id: 'v_murugan', name: 'Murugan Fish Stall', kind: 'vendor', size: 48),
          ChatAvatar(id: 'v_balaji', name: 'Sri Balaji Traders', kind: 'vendor', size: 48),
        ]),
      ]),
    );
  });

  testWidgets('vendor today (fixture)', (t) async {
    await shoot(t, 'vendor_today', const VendorScreen());
  });

  testWidgets('vendor after basmati filled', (t) async {
    await shoot(t, 'vendor_today_order', const VendorScreen(), overrides: {'/api/vendor/dashboard': _vendorAfterOrder()});
  });

  testWidgets('vendor packing list', (t) async {
    await shoot(
      t,
      'vendor_today_packing',
      const VendorScreen(),
      overrides: {'/api/vendor/dashboard': _vendorAfterOrder()},
      act: (t) async {
        await t.drag(find.byType(CustomScrollView), const Offset(0, -900));
        await t.pump(const Duration(milliseconds: 500));
      },
    );
  });

  testWidgets('handover keypad', (t) async {
    await shoot(
      t,
      'vendor_handover',
      const HandoverScreen(orderId: 'JS-2043', communityName: 'Sea Breeze Towers'),
      overrides: {'/api/orders/JS-2043': _riceOrder(_riceLines)},
      act: (t) => _typeOtp(t, '519'),
    );
  });

  testWidgets('handover confirmed', (t) async {
    final after = [for (final l in _riceLines) l['userId'] == 'u_ananya' ? {...l, 'collected': true} : l];
    await shoot(
      t,
      'vendor_handover_done',
      const HandoverScreen(orderId: 'JS-2043', communityName: 'Sea Breeze Towers'),
      overrides: {
        '/api/orders/JS-2043': _riceOrder(_riceLines),
        'POST /api/orders/JS-2043/handover': {'order': _riceOrder(after)},
      },
      act: (t) async {
        await _typeOtp(t, '5193');
        await t.runAsync(() async {
          await t.tap(find.text('Confirm handover'));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await t.pump(const Duration(milliseconds: 300));
      },
    );
  });

  testWidgets('admin community', (t) async {
    await shoot(t, 'admin_community', const AdminScreen());
  });

  testWidgets('admin community scrolled', (t) async {
    await shoot(
      t,
      'admin_community_nudges',
      const AdminScreen(),
      act: (t) async {
        await t.tap(find.text('Approve').first);
        await t.pump(const Duration(milliseconds: 300));
        await t.drag(find.byType(ListView), const Offset(0, -700));
        await t.pump(const Duration(milliseconds: 500));
      },
    );
  });
}
