import 'json.dart';
import 'user.dart';

enum HoldStatus { created, held, captured, released, unknown }

/// Money blocked with UPI (sandbox). Captured when the bucket fills, released
/// if it doesn't.
class Hold {
  const Hold({required this.id, required this.amount, required this.status, this.vpa});

  final String id;
  final int amount;
  final HoldStatus status;
  final String? vpa;

  factory Hold.fromJson(Json j) => Hold(
        id: asString(j['id']),
        amount: asInt(j['amount']),
        status: HoldStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => HoldStatus.unknown,
        ),
        vpa: asStringOrNull(j['vpa']),
      );
}

/// Share lifecycle. `pending_payment` → `held` → `captured` → `checked_in` → `collected`;
/// or `booked` (at_market); or `released` / `left`.
enum ShareStatus {
  pendingPayment('pending_payment'),
  held('held'),
  booked('booked'),
  captured('captured'),
  released('released'),
  checkedIn('checked_in'),
  collected('collected'),
  left('left'),
  unknown('unknown');

  const ShareStatus(this.wire);
  final String wire;

  static ShareStatus parse(Object? v) =>
      values.firstWhere((s) => s.wire == v, orElse: () => ShareStatus.unknown);
}

enum PayMode {
  hold('hold'),
  atMarket('at_market');

  const PayMode(this.wire);
  final String wire;

  static PayMode parse(Object? v) => v == 'at_market' ? PayMode.atMarket : PayMode.hold;
}

/// One trip-list line inside a share (`items`).
class ShareItem {
  const ShareItem({required this.id, required this.qty});
  final String id;
  final double qty;

  factory ShareItem.fromJson(Json j) =>
      ShareItem(id: asString(j['id'] ?? j['itemId']), qty: asDouble(j['qty']));
}

/// One member's part of a bucket.
class Share {
  const Share({
    required this.id,
    required this.bucketId,
    required this.user,
    required this.qty,
    required this.unitIds,
    required this.payMode,
    required this.estAmount,
    required this.status,
    this.items,
    this.options = const {},
    this.finalAmount,
    this.hold,
    this.otp,
  });

  final String id;
  final String bucketId;
  final User user;
  final double qty;
  final List<String> unitIds;
  final List<ShareItem>? items;
  final Map<String, String> options;
  final PayMode payMode;
  final int estAmount;
  final int? finalAmount;
  final ShareStatus status;
  final Hold? hold;
  final String? otp;

  int get amount => finalAmount ?? estAmount;

  factory Share.fromJson(Json j) => Share(
        id: asString(j['id']),
        bucketId: asString(j['bucketId']),
        user: User.fromJson(asJson(j['user']) ?? const {}),
        qty: asDouble(j['qty']),
        unitIds: asStringList(j['unitIds']),
        items: j['items'] is List ? asList(j['items'], ShareItem.fromJson) : null,
        options: (asJson(j['options']) ?? const {}).map((k, v) => MapEntry(k, v.toString())),
        payMode: PayMode.parse(j['payMode']),
        estAmount: asInt(j['estAmount']),
        finalAmount: asIntOrNull(j['finalAmount']),
        status: ShareStatus.parse(j['status']),
        hold: asJson(j['hold']) == null ? null : Hold.fromJson(asJson(j['hold'])!),
        otp: asStringOrNull(j['otp']),
      );
}
