import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../widgets/widgets.dart';

/// One member's line, read from the raw order JSON (the core `OrderLine` doesn't carry
/// `savings`, `shareId` or `collectedAt` yet).
class MemberLine {
  const MemberLine({
    required this.userId,
    required this.name,
    this.unit,
    required this.qtyLabel,
    required this.amount,
    required this.payMode,
    required this.paymentStatus,
    this.otp,
    this.collected = false,
    this.savings = 0,
    this.heldAmount,
    this.shareId,
    this.options = const {},
  });

  final String userId;
  final String name;
  final String? unit;
  final String qtyLabel;
  final int amount;
  final PayMode payMode;

  /// `captured` / `held` (hold) or `due` / `paid` (at_market).
  final String paymentStatus;
  final String? otp;
  final bool collected;
  final int savings;
  final int? heldAmount;
  final String? shareId;
  final Map<String, String> options;

  factory MemberLine.fromJson(Json j) => MemberLine(
        userId: asString(j['userId']),
        name: asString(j['name']),
        unit: asStringOrNull(j['unit']),
        qtyLabel: asString(j['qtyLabel']),
        amount: asInt(j['amount']),
        payMode: PayMode.parse(j['payMode']),
        paymentStatus: asString(j['paymentStatus']),
        otp: asStringOrNull(j['otp']),
        collected: asBool(j['collected']),
        savings: asInt(j['savings']),
        heldAmount: asIntOrNull(j['heldAmount']),
        shareId: asStringOrNull(j['shareId']),
        options: (asJson(j['options']) ?? const {}).map((k, v) => MapEntry(k, v.toString())),
      );

  /// Payment state pill: held / paid / due.
  StatusPill pill() => switch (paymentStatus) {
        'held' => const StatusPill('Held', tone: PillTone.held, icon: Icons.lock_clock_outlined),
        // Charged at the final price when the bucket fills; the vendor is paid at the OTP handover.
        'captured' when collected => const StatusPill('Paid', tone: PillTone.captured, icon: Icons.check_circle_outline),
        'captured' => const StatusPill('Charged', tone: PillTone.captured, icon: Icons.check_circle_outline),
        'paid' => const StatusPill('Paid', tone: PillTone.captured, icon: Icons.check_circle_outline),
        'due' => const StatusPill('Due at market', tone: PillTone.brand),
        'at_pickup' => const StatusPill('At pickup', tone: PillTone.brand),
        'released' => const StatusPill('Released', tone: PillTone.released),
        _ => StatusPill(paymentStatus.isEmpty ? 'Pending' : paymentStatus),
      };
}

/// `Order` plus the server's additions (`image`, `pickupPoint`, `window`, `myLine`, line savings).
class OrderView {
  const OrderView({
    required this.id,
    required this.bucketId,
    required this.title,
    required this.status,
    this.image,
    this.total = 0,
    this.heldTotal = 0,
    this.atPickupTotal = 0,
    this.createdAt,
    this.pickupPoint,
    this.window,
    this.lines = const [],
    this.myLine,
  });

  final String id;
  final String bucketId;
  final String title;
  final OrderStatus status;
  final String? image;
  final int total;
  final int heldTotal;
  final int atPickupTotal;
  final DateTime? createdAt;
  final String? pickupPoint;
  final String? window;
  final List<MemberLine> lines;
  final MemberLine? myLine;

  bool get isPast => status == OrderStatus.delivered;
  bool get atMarket => myLine?.payMode == PayMode.atMarket || (heldTotal == 0 && atPickupTotal > 0);
  int get collectedCount => lines.where((l) => l.collected).length;

  factory OrderView.fromJson(Json j, {String? meId}) {
    final lines = asList(j['lines'], MemberLine.fromJson);
    final mine = asJson(j['myLine']);
    return OrderView(
      id: asString(j['id']),
      bucketId: asString(j['bucketId']),
      title: asString(j['title']),
      status: OrderStatus.parse(j['status']),
      image: asStringOrNull(j['image']),
      total: asInt(j['total']),
      heldTotal: asInt(j['heldTotal']),
      atPickupTotal: asInt(j['atPickupTotal']),
      createdAt: asTime(j['createdAt']),
      pickupPoint: asStringOrNull(j['pickupPoint']),
      window: asStringOrNull(j['window']),
      lines: lines,
      myLine: mine != null ? MemberLine.fromJson(mine) : lines.where((l) => l.userId == meId).firstOrNull,
    );
  }

  /// Status pill for the order card.
  StatusPill statusPill() => switch (status) {
        OrderStatus.created when atMarket => const StatusPill('Booked · pay at stall', tone: PillTone.brand, icon: Icons.storefront_outlined),
        OrderStatus.created => const StatusPill('Order created', tone: PillTone.brand),
        OrderStatus.sent => const StatusPill('Sent to vendor', tone: PillTone.held),
        OrderStatus.packed => const StatusPill('Packed', tone: PillTone.held, icon: Icons.inventory_2_outlined),
        OrderStatus.delivered => const StatusPill('Delivered', tone: PillTone.captured, icon: Icons.check_circle_outline),
        OrderStatus.unknown => const StatusPill('Order'),
      };
}
