import '../../core/models/models.dart';

/// `/api/vendor/dashboard` → `{vendor, heldDemand, buckets, packing}`.
class VendorDashboard {
  const VendorDashboard({
    required this.vendor,
    required this.heldDemand,
    required this.buckets,
    required this.packing,
    this.category,
  });

  final Vendor vendor;
  final String? category;
  final int heldDemand;
  final List<Bucket> buckets;
  final List<PackingGroup> packing;

  List<Bucket> get live => buckets.where((b) => b.status.isOpen).toList();

  /// Households with money held across live buckets.
  int get liveHouseholds => live.fold(0, (n, b) => n + b.progress.members);

  int get communities => {for (final b in live) b.communityId}.length;

  factory VendorDashboard.fromJson(Json j) {
    final v = asJson(j['vendor']) ?? const {};
    return VendorDashboard(
      vendor: Vendor.fromJson(v),
      category: asStringOrNull(v['category']),
      heldDemand: asInt(j['heldDemand']),
      buckets: asList(j['buckets'], Bucket.fromJson),
      packing: asList(j['packing'], PackingGroup.fromJson),
    );
  }
}

/// One community's packing lines.
class PackingGroup {
  const PackingGroup({required this.communityId, required this.communityName, required this.lines});

  final String communityId;
  final String communityName;
  final List<PackLine> lines;

  /// Lines grouped by order, in first-seen order.
  Map<String, List<PackLine>> get byOrder {
    final m = <String, List<PackLine>>{};
    for (final l in lines) {
      (m[l.orderId] ??= []).add(l);
    }
    return m;
  }

  factory PackingGroup.fromJson(Json j) => PackingGroup(
        communityId: asString(j['communityId']),
        communityName: asString(j['communityName'], 'Community'),
        lines: asList(j['lines'], PackLine.fromJson),
      );
}

/// An order line as the vendor sees it (no OTP).
class PackLine {
  const PackLine({
    required this.orderId,
    required this.userId,
    required this.name,
    required this.qtyLabel,
    required this.amount,
    this.title,
    this.unit,
    this.payMode = PayMode.hold,
    this.paymentStatus = '',
    this.options = const {},
    this.collected = false,
    this.transport = 0,
  });

  final String orderId;
  final String? title;
  final String userId;
  final String name;
  final String? unit;
  final String qtyLabel;
  final int amount;
  final PayMode payMode;
  final String paymentStatus;
  final Map<String, String> options;
  final bool collected;
  final int transport;

  /// `Cut: Curry · Cleaning: Yes`
  String get optionsText => options.entries.map((e) => '${_cap(e.key)}: ${e.value}').join(' · ');

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  factory PackLine.fromJson(Json j) {
    final opts = asJson(j['options']);
    return PackLine(
      orderId: asString(j['orderId']),
      title: asStringOrNull(j['title']),
      userId: asString(j['userId']),
      name: asString(j['name'], 'Neighbour'),
      unit: asStringOrNull(j['unit']),
      qtyLabel: asString(j['qtyLabel'], asString(j['qty'])),
      amount: asInt(j['amount']),
      payMode: PayMode.parse(j['payMode']),
      paymentStatus: asString(j['paymentStatus']),
      options: opts == null ? const {} : opts.map((k, v) => MapEntry(k, v.toString())),
      collected: asBool(j['collected']),
      transport: asInt(j['transport']),
    );
  }
}

/// `/api/orders/:id` as the vendor sees it (pickup point, window, lines).
class VendorOrder {
  const VendorOrder({
    required this.id,
    required this.title,
    required this.lines,
    this.bucketId,
    this.communityId,
    this.image,
    this.pickupPoint,
    this.window,
    this.status = OrderStatus.created,
    this.total = 0,
  });

  final String id;
  final String title;
  final String? bucketId;
  final String? communityId;
  final String? image;
  final String? pickupPoint;
  final String? window;
  final OrderStatus status;
  final int total;
  final List<PackLine> lines;

  int get collectedCount => lines.where((l) => l.collected).length;
  int get releasedAmount => lines.where((l) => l.collected).fold(0, (n, l) => n + l.amount);
  bool get allCollected => lines.isNotEmpty && lines.every((l) => l.collected);

  factory VendorOrder.fromJson(Json j) {
    final id = asString(j['id']);
    return VendorOrder(
      id: id,
      title: asString(j['title'], 'Order'),
      bucketId: asStringOrNull(j['bucketId']),
      communityId: asStringOrNull(j['communityId']),
      image: asStringOrNull(j['image']),
      pickupPoint: asStringOrNull(j['pickupPoint']),
      window: asStringOrNull(j['window']),
      status: OrderStatus.parse(j['status']),
      total: asInt(j['total']),
      lines: asList(j['lines'], (l) => PackLine.fromJson({...l, 'orderId': id})),
    );
  }
}
