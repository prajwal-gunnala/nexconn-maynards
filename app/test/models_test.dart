import 'package:flutter_test/flutter_test.dart';
import 'package:jugaad_street/core/models/models.dart';
import 'package:jugaad_street/core/nexconn/js_messages.dart';

void main() {
  test('Bucket.fromJson parses the contract example', () {
    final b = Bucket.fromJson({
      'id': 'b_seer', 'communityId': 'c_seabreeze', 'type': 'split', 'category': 'fish',
      'title': 'Whole Seer (Vanjaram)', 'subtitle': 'Landed 6:10 am at Kasimedu', 'image': 'seer',
      'vendor': {'id': 'v_murugan', 'name': 'Murugan Fish Stall', 'place': 'Kasimedu Harbour', 'rating': 4.8},
      'createdBy': {'id': 'u_ravi', 'name': 'Ravi', 'unit': 'C-801'},
      'settleMode': 'hold', 'meet': null, 'cutoffAt': '2026-11-16T03:00:00.000Z',
      'unitLabel': 'cut', 'retailUnitPrice': 1400, 'netWeight': '5.2 kg', 'serves': '8 families',
      'units': [
        {'id': 'head', 'label': 'Head', 'grams': 600, 'price': 420, 'owner': {'id': 'u_s', 'name': 'Sunita', 'unit': 'A-201'}},
        {'id': 's2', 'label': 'Steak 2', 'grams': 700, 'price': 700, 'owner': null},
      ],
      'tiers': [{'minQty': 25, 'unitPrice': 96}, {'minQty': 100, 'unitPrice': 88}],
      'progress': {'filled': 6, 'target': 8, 'members': 6, 'held': 3920, 'unitPrice': 950,
                   'nextTier': {'minQty': 100, 'unitPrice': 88, 'remaining': 18}, 'percent': 75},
      'status': 'live', 'cardMessageId': 'ABC',
      'myShare': {
        'id': 's_1', 'bucketId': 'b_seer', 'user': {'id': 'u_ananya', 'name': 'Ananya', 'unit': 'B-1204'},
        'qty': 1, 'unitIds': ['s2'], 'items': null, 'options': {'cut': 'Curry'}, 'payMode': 'hold',
        'estAmount': 700, 'finalAmount': null, 'status': 'pending_payment',
        'hold': {'id': 'h_1', 'amount': 700, 'status': 'created', 'vpa': 'ananya@okaxis'}, 'otp': null,
      },
    });
    expect(b.type, BucketType.split);
    expect(b.status, BucketStatus.live);
    expect(b.vendor!.rating, 4.8);
    expect(b.units.first.owner!.name, 'Sunita');
    expect(b.openUnits, 1);
    expect(b.tiers.last.unitPrice, 88);
    expect(b.progress.fraction, 0.75);
    expect(b.progress.nextTier!.remaining, 18);
    expect(b.unitPrice, 950);
    expect(b.cutoffAt!.isUtc, isTrue);
    expect(b.myShare!.status, ShareStatus.pendingPayment);
    expect(b.myShare!.hold!.status, HoldStatus.created);
    expect(b.myShare!.options['cut'], 'Curry');
  });

  test('models tolerate missing fields', () {
    final b = Bucket.fromJson({'id': 'x'});
    expect(b.type, BucketType.unknown);
    expect(b.progress.fraction, 0);
    expect(Order.fromJson({}).lines, isEmpty);
    expect(Wallet.fromJson({'heldNow': '700'}).heldNow, 700);
  });

  test('Order + lines', () {
    final o = Order.fromJson({
      'id': 'JS-2041', 'bucketId': 'b_basmati', 'title': 'Basmati', 'total': 9152, 'heldTotal': 7920,
      'atPickupTotal': 1232, 'status': 'sent', 'createdAt': '2026-11-16T03:00:00Z',
      'lines': [
        {'userId': 'u_ananya', 'name': 'Ananya', 'unit': 'B-1204', 'qty': 10, 'qtyLabel': '10 kg', 'amount': 880,
         'payMode': 'hold', 'paymentStatus': 'captured', 'otp': '5193', 'collected': true},
        {'userId': 'u_ravi', 'name': 'Ravi', 'qty': 5, 'qtyLabel': '5 kg', 'amount': 440, 'payMode': 'at_market',
         'paymentStatus': 'at_pickup', 'collected': false},
      ],
    });
    expect(o.status, OrderStatus.sent);
    expect(o.collectedCount, 1);
    expect(o.lines[1].payMode, PayMode.atMarket);
  });

  test('BucketCardData reads js:bucket fields + metadata', () {
    final c = BucketCardData.from(
      {'bucketId': 'b_test', 'type': 'bulk', 'title': 'Basmati test'},
      {'p': '{"filled":95,"target":100}', 's': 'live', 'u': '[["head","S"],["s2",""]]'},
    );
    expect(c.type, BucketType.bulk);
    expect(c.progress!.fraction, 0.95);
    expect(c.status, BucketStatus.live);
    expect(c.units, [('head', 'S'), ('s2', '')]);

    final empty = BucketCardData.from({'title': 'x'}, {'p': 'not json'});
    expect(empty.progress, isNull);
  });
}
