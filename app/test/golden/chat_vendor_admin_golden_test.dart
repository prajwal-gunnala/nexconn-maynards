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

final _cutoff = DateTime.now().add(const Duration(hours: 3, minutes: 12)).toUtc().toIso8601String();

Map<String, String> _card(String id, String type, String title, String sub, String image, String vendor, String unit) => {
      'bucketId': id,
      'type': type,
      'title': title,
      'subtitle': sub,
      'image': image,
      'vendor': vendor,
      'cutoffAt': _cutoff,
      'unitLabel': unit,
    };

final _seerFields = _card('b_seer', 'split', 'Whole Seer (Vanjaram)', 'Landed 6:10 am at Kasimedu', 'seer', 'Murugan Fish Stall', 'cut');
final _seerMeta = {
  'p': jsonEncode({'filled': 6, 'target': 8, 'members': 6, 'held': 3680, 'unitPrice': 950, 'nextTier': null, 'percent': 75, 'goAt': 8}),
  's': 'live',
  'u': jsonEncode([
    ['head', 'S'], ['s1', 'R'], ['s2', ''], ['s3', 'M'], ['s4', 'K'], ['s5', 'P'], ['s6', 'A'], ['tail', ''],
  ]),
};
final _basmatiFields = _card('b_basmati', 'bulk', 'Aged Basmati Rice (1121)', '25 kg sacks, split at the gate', 'basmati', 'Sri Balaji Traders', 'kg');
Map<String, String> _basmatiMeta(int filled) => {
      'p': jsonEncode({
        'filled': filled, 'target': 100, 'members': 7, 'held': 8352, 'unitPrice': 96,
        'nextTier': {'minQty': 100, 'unitPrice': 88, 'remaining': 100 - filled}, 'percent': filled, 'goAt': 25,
      }),
      's': 'live',
    };

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

Map<String, dynamic> _line(String user, String name, String unit, String qty, int amount,
        {bool collected = false, Map<String, String>? options, String payMode = 'hold'}) =>
    {
      'userId': user, 'name': name, 'unit': unit, 'qty': 1, 'qtyLabel': qty, 'amount': amount, 'payMode': payMode,
      'paymentStatus': payMode == 'hold' ? 'captured' : 'due', 'otp': null, 'collected': collected, 'options': options,
    };

final _orderLines = [
  _line('u_ananya', 'Ananya', 'B-1204', '18 kg', 1584),
  _line('u_meera', 'Meera', 'A-303', '15 kg', 1320, collected: true),
  _line('u_ravi', 'Ravi', 'C-801', '10 kg', 880, collected: true),
  _line('u_kiran', 'Kiran', 'B-402', '25 kg', 2200),
  _line('u_sunita', 'Sunita', 'A-201', '12 kg', 1056),
  _line('u_arjun', 'Arjun', 'B-702', '20 kg', 1760, collected: true),
];

Map<String, dynamic> _order(List<Map<String, dynamic>> lines) => {
      'id': 'JS-2050', 'bucketId': 'b_basmati', 'communityId': 'c_seabreeze', 'vendorId': 'v_balaji',
      'title': 'Aged Basmati Rice (1121)', 'image': 'basmati', 'total': 8800, 'status': 'packed',
      'pickupPoint': 'Gate 2', 'window': 'Sat 7:00–9:00 am', 'lines': lines,
    };

Map<String, dynamic> _vendorDashboard() {
  final d = (fixture('vendor_dashboard') as Map).cast<String, dynamic>();
  return {
    ...d,
    'packing': [
      {
        'communityId': 'c_seabreeze',
        'communityName': 'Sea Breeze Towers',
        'lines': [
          for (final l in _orderLines) {...l, 'orderId': 'JS-2050', 'title': 'Aged Basmati Rice (1121)'},
          {
            ..._line('u_priya', 'Priya', 'A-1101', '1 half', 520, options: {'cut': 'Curry', 'clean': 'Yes'}, payMode: 'at_market'),
            'orderId': 'JS-2051',
            'title': 'Kasimedu Book & Meet: Whole Paarai',
          },
        ],
      },
    ],
  };
}

void main() {
  testWidgets('chat bubbles: bucket cards', (t) async {
    await shoot(
      t,
      'chat_bubbles_cards',
      _chatCanvas([
        BucketChatCard(data: BucketCardData.from(_seerFields, _seerMeta), meta: _seerMeta),
        BucketChatCard(data: BucketCardData.from(_basmatiFields, _basmatiMeta(87)), meta: _basmatiMeta(87), flash: true),
      ]),
    );
  });

  testWidgets('chat bubbles: events, order, otp', (t) async {
    await shoot(
      t,
      'chat_bubbles_system',
      _chatCanvas([
        const Center(child: JsEventPill(fields: {'bucketId': 'b_basmati', 'kind': 'joined', 'text': 'Ananya (B-1204) took 18 kg'})),
        const Center(child: JsEventPill(fields: {'bucketId': 'b_seer', 'kind': 'nudge', 'text': 'Whole Seer: Steak 2 and Tail are still open. 2 cuts left.'})),
        const Center(child: JsEventPill(fields: {'bucketId': 'b_goat', 'kind': 'locked', 'text': 'Whole Goat is full. Order JS-2052 placed.'})),
        const JsOrderCard(fields: {'orderId': 'JS-2041', 'bucketId': 'b_basmati', 'title': 'Aged Basmati Rice (1121)', 'total': '8800', 'members': '7'}),
        const JsOtpCard(fields: {'orderId': 'JS-2041', 'otp': '5193', 'pickupPoint': 'Gate 2, Sea Breeze Towers', 'window': 'Sat 7:00–9:00 am'}),
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

  testWidgets('vendor today', (t) async {
    await shoot(t, 'vendor_today', const VendorScreen(), overrides: {'/api/vendor/dashboard': _vendorDashboard()});
  });

  testWidgets('vendor today scrolled', (t) async {
    await shoot(
      t,
      'vendor_today_packing',
      const VendorScreen(),
      overrides: {'/api/vendor/dashboard': _vendorDashboard()},
      act: (t) async {
        await t.drag(find.byType(CustomScrollView), const Offset(0, -900));
        await t.pump(const Duration(milliseconds: 500));
      },
    );
  });

  testWidgets('vendor empty packing', (t) async {
    await shoot(t, 'vendor_today_empty', const VendorScreen());
  });

  testWidgets('handover keypad', (t) async {
    await shoot(
      t,
      'vendor_handover',
      const HandoverScreen(orderId: 'JS-2050', communityName: 'Sea Breeze Towers'),
      overrides: {'/api/orders/JS-2050': _order(_orderLines)},
      act: (t) async {
        for (final k in ['5', '1', '9']) {
          await t.tap(find.bySemanticsLabel(k).last);
          await t.pump();
        }
      },
    );
  });

  testWidgets('handover confirmed', (t) async {
    final after = [for (final l in _orderLines) l['userId'] == 'u_ananya' ? {...l, 'collected': true} : l];
    await shoot(
      t,
      'vendor_handover_done',
      const HandoverScreen(orderId: 'JS-2050', communityName: 'Sea Breeze Towers'),
      overrides: {
        '/api/orders/JS-2050': _order(_orderLines),
        'POST /api/orders/JS-2050/handover': {'order': _order(after)},
      },
      act: (t) async {
        for (final k in ['5', '1', '9', '3']) {
          await t.tap(find.bySemanticsLabel(k).last);
          await t.pump();
        }
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
