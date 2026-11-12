import 'json.dart';
import 'share.dart';

/// One member's line in an order.
class OrderLine {
  const OrderLine({
    required this.userId,
    required this.name,
    required this.qtyLabel,
    required this.amount,
    required this.payMode,
    required this.paymentStatus,
    this.unit,
    this.qty = 0,
    this.otp,
    this.collected = false,
  });

  final String userId;
  final String name;
  final String? unit;
  final double qty;
  final String qtyLabel;
  final int amount;
  final PayMode payMode;

  /// e.g. `captured`, `at_pickup`, `paid`.
  final String paymentStatus;
  final String? otp;
  final bool collected;

  factory OrderLine.fromJson(Json j) => OrderLine(
        userId: asString(j['userId']),
        name: asString(j['name']),
        unit: asStringOrNull(j['unit']),
        qty: asDouble(j['qty']),
        qtyLabel: asString(j['qtyLabel']),
        amount: asInt(j['amount']),
        payMode: PayMode.parse(j['payMode']),
        paymentStatus: asString(j['paymentStatus']),
        otp: asStringOrNull(j['otp']),
        collected: asBool(j['collected']),
      );
}

/// created | sent | packed | delivered
enum OrderStatus {
  created,
  sent,
  packed,
  delivered,
  unknown;

  static OrderStatus parse(Object? v) =>
      values.firstWhere((s) => s.name == v, orElse: () => OrderStatus.unknown);
}

/// Created when a bucket fills; one line per member.
class Order {
  const Order({
    required this.id,
    required this.bucketId,
    required this.title,
    required this.total,
    required this.status,
    this.heldTotal = 0,
    this.atPickupTotal = 0,
    this.createdAt,
    this.lines = const [],
  });

  final String id;
  final String bucketId;
  final String title;
  final int total;
  final int heldTotal;
  final int atPickupTotal;
  final OrderStatus status;
  final DateTime? createdAt;
  final List<OrderLine> lines;

  int get collectedCount => lines.where((l) => l.collected).length;

  factory Order.fromJson(Json j) => Order(
        id: asString(j['id']),
        bucketId: asString(j['bucketId']),
        title: asString(j['title']),
        total: asInt(j['total']),
        heldTotal: asInt(j['heldTotal']),
        atPickupTotal: asInt(j['atPickupTotal']),
        status: OrderStatus.parse(j['status']),
        createdAt: asTime(j['createdAt']),
        lines: asList(j['lines'], OrderLine.fromJson),
      );
}
