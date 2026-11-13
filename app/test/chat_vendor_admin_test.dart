import 'package:flutter_test/flutter_test.dart';
import 'package:jugaad_street/core/nexconn/js_messages.dart';
import 'package:jugaad_street/features/admin/admin_screen.dart';
import 'package:jugaad_street/features/chat/chat_avatar.dart';
import 'package:jugaad_street/features/chat/chat_directory.dart';
import 'package:jugaad_street/features/chat/js_bubbles.dart';
import 'package:jugaad_street/features/vendor/vendor_models.dart';

void main() {
  test('channel ids and titles', () {
    expect(ChatDirectory.kindOfId('street_c_seabreeze'), ChatChannelKind.street);
    expect(ChatDirectory.kindOfId('bucket_b_seer'), ChatChannelKind.bucket);
    expect(ChatDirectory.kindOfId('v_murugan', direct: true), ChatChannelKind.direct);
    expect(ChatDirectory.refOf('street_c_seabreeze'), 'c_seabreeze');
    expect(ChatDirectory.refOf('bucket_b_past_prawns'), 'b_past_prawns');
    expect(ChatDirectory.streetTitle('Sea Breeze Towers'), 'Sea Breeze Street');
    expect(ChatDirectory.streetTitle('Palm Grove Apartments'), 'Palm Grove Street');
  });

  test('previews for js messages', () {
    expect(jsPreviewFor(JsType.bucket, {'title': 'Whole Seer'}), 'New bucket: Whole Seer');
    expect(jsPreviewFor(JsType.event, {'text': 'Ananya (B-1204) took 10 kg'}), 'Ananya took 10 kg');
    expect(jsPreviewFor(JsType.order, {'orderId': 'JS-2041'}), 'Order JS-2041 created');
    expect(jsPreviewFor(JsType.otp, {'otp': '5193'}), 'Your pickup code');
    expect(splitUnlock('Venkat (D-604) took 12 kg and unlocked ₹88/kg for everyone!'), ('Venkat (D-604) took 12 kg', '₹88/kg'));
    expect(splitUnlock('Ananya (B-1204) took 10 kg'), isNull);
    expect(jsPreviewFor(JsType.event, {'text': 'Venkat (D-604) took 12 kg and unlocked ₹88/kg for everyone!'}),
        '₹88/kg unlocked! Venkat took 12 kg');
  });

  test('short bucket titles for list rows', () {
    expect(ChatDirectory.shortBucketTitle('Kasimedu Book & Meet: Whole Paarai'), 'Whole Paarai');
    expect(ChatDirectory.shortBucketTitle('Aged Basmati Rice (1121)'), 'Aged Basmati Rice');
    expect(ChatDirectory.shortBucketTitle('Whole Goat, 7-share Split'), 'Whole Goat');
  });

  test('avatar initials and stable colours', () {
    expect(ChatAvatar.initialsOf('Ravi'), 'R');
    expect(ChatAvatar.initialsOf('Murugan Fish Stall'), 'MF');
    expect(ChatAvatar.colorsFor('u_ravi'), ChatAvatar.colorsFor('u_ravi'));
  });

  test('vendor order lines and admin nudges parse', () {
    final o = VendorOrder.fromJson({
      'id': 'JS-1',
      'title': 'Basmati',
      'pickupPoint': 'Gate 2',
      'lines': [
        {'userId': 'u_a', 'name': 'Ananya', 'unit': 'B-1204', 'qtyLabel': '10 kg', 'amount': 880, 'collected': true},
        {'userId': 'u_m', 'name': 'Meera', 'unit': 'A-303', 'qtyLabel': '1 cut', 'amount': 500, 'options': {'cut': 'Curry'}},
      ],
    });
    expect(o.collectedCount, 1);
    expect(o.releasedAmount, 880);
    expect(o.lines.last.optionsText, 'Cut: Curry');
    expect(o.lines.first.orderId, 'JS-1');

    final n = Nudge.fromJson({'bucketId': 'b_seer', 'title': 'Whole Seer', 'text': 'Whole Seer: 2 cuts left.'});
    expect(n.body, '2 cuts left.');
  });
}
