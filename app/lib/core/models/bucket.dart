import 'json.dart';
import 'share.dart';
import 'user.dart';

enum BucketType {
  split,
  bulk,
  service,
  trip,
  unknown;

  static BucketType parse(Object? v) =>
      values.firstWhere((t) => t.name == v, orElse: () => BucketType.unknown);
}

/// live | ordered | market_day | delivering | completed | expired | cancelled
enum BucketStatus {
  live('live'),
  ordered('ordered'),
  marketDay('market_day'),
  delivering('delivering'),
  completed('completed'),
  expired('expired'),
  cancelled('cancelled'),
  unknown('unknown');

  const BucketStatus(this.wire);
  final String wire;

  bool get isOpen => this == BucketStatus.live;

  static BucketStatus parse(Object? v) =>
      values.firstWhere((s) => s.wire == v, orElse: () => BucketStatus.unknown);
}

class Vendor {
  const Vendor({required this.id, required this.name, this.place, this.rating});

  final String id;
  final String name;
  final String? place;
  final double? rating;

  factory Vendor.fromJson(Json j) => Vendor(
        id: asString(j['id']),
        name: asString(j['name']),
        place: asStringOrNull(j['place']),
        rating: j['rating'] == null ? null : asDouble(j['rating']),
      );
}

/// A claimable part of a `split` bucket (a cut, a dozen, a half).
class BucketUnit {
  const BucketUnit({required this.id, required this.label, required this.price, this.grams, this.owner});

  final String id;
  final String label;
  final int price;
  final int? grams;
  final User? owner;

  bool get isOpen => owner == null;

  factory BucketUnit.fromJson(Json j) => BucketUnit(
        id: asString(j['id']),
        label: asString(j['label']),
        price: asInt(j['price']),
        grams: asIntOrNull(j['grams']),
        owner: asJson(j['owner']) == null ? null : User.fromJson(asJson(j['owner'])!),
      );
}

/// Volume price tier (bulk and service): at [minQty] the unit price drops to [unitPrice].
class Tier {
  const Tier({required this.minQty, required this.unitPrice});

  final int minQty;
  final int unitPrice;

  factory Tier.fromJson(Json j) => Tier(minQty: asInt(j['minQty']), unitPrice: asInt(j['unitPrice']));
}

/// A line on a market-trip list.
class TripItem {
  const TripItem({required this.id, required this.name, required this.unit, required this.price, this.qty = 0, this.members = 0});

  final String id;
  final String name;
  final String unit;
  final int price;
  final double qty;
  final int members;

  factory TripItem.fromJson(Json j) => TripItem(
        id: asString(j['id']),
        name: asString(j['name']),
        unit: asString(j['unit']),
        price: asInt(j['price']),
        qty: asDouble(j['qty']),
        members: asInt(j['members']),
      );
}

/// Live progress. Also arrives as the `p` metadata key on the chat card
/// (JSON string), so it is parsed from both places with [Progress.fromJson].
class Progress {
  const Progress({
    this.filled = 0,
    this.target = 0,
    this.members = 0,
    this.held = 0,
    this.unitPrice,
    this.nextTier,
    this.percent,
  });

  final num filled;
  final num target;
  final int members;
  final int held;
  final int? unitPrice;
  final NextTier? nextTier;
  final int? percent;

  /// 0..1 for progress bars. Uses `percent` when present, else filled/target.
  double get fraction {
    if (percent != null) return (percent! / 100).clamp(0.0, 1.0);
    if (target <= 0) return 0;
    return (filled / target).clamp(0.0, 1.0).toDouble();
  }

  int get percentRounded => percent ?? (fraction * 100).round();

  factory Progress.fromJson(Json j) => Progress(
        filled: j['filled'] is num ? j['filled'] as num : asDouble(j['filled']),
        target: j['target'] is num ? j['target'] as num : asDouble(j['target']),
        members: asInt(j['members']),
        held: asInt(j['held']),
        unitPrice: asIntOrNull(j['unitPrice']),
        nextTier: asJson(j['nextTier']) == null ? null : NextTier.fromJson(asJson(j['nextTier'])!),
        percent: asIntOrNull(j['percent']),
      );
}

class NextTier {
  const NextTier({required this.minQty, required this.unitPrice, required this.remaining});

  final int minQty;
  final int unitPrice;
  final num remaining;

  factory NextTier.fromJson(Json j) => NextTier(
        minQty: asInt(j['minQty']),
        unitPrice: asInt(j['unitPrice']),
        remaining: j['remaining'] is num ? j['remaining'] as num : asDouble(j['remaining']),
      );
}

/// A group buy. See docs/CONTRACT.md "Bucket".
class Bucket {
  const Bucket({
    required this.id,
    required this.communityId,
    required this.type,
    required this.title,
    required this.status,
    required this.progress,
    this.category,
    this.subtitle,
    this.image,
    this.vendor,
    this.createdBy,
    this.settleMode = PayMode.hold,
    this.meet,
    this.cutoffAt,
    this.deliverAt,
    this.pickupPoint,
    this.unitLabel,
    this.retailUnitPrice,
    this.netWeight,
    this.serves,
    this.units = const [],
    this.tiers = const [],
    this.items = const [],
    this.capacity,
    this.cardMessageId,
    this.myShare,
    this.shares = const [],
    this.baseUnitPrice,
    this.description,
    this.orderId,
  });

  final String id;
  final String communityId;
  final BucketType type;
  final String? category;
  final String title;
  final String? subtitle;

  /// Image key (e.g. `seer`) or URL.
  final String? image;
  final Vendor? vendor;
  final User? createdBy;
  final PayMode settleMode;
  final Json? meet;
  final DateTime? cutoffAt;
  final DateTime? deliverAt;
  final String? pickupPoint;
  final String? unitLabel;
  final int? retailUnitPrice;
  final String? netWeight;
  final String? serves;
  final List<BucketUnit> units;
  final List<Tier> tiers;
  final List<TripItem> items;
  final int? capacity;
  final Progress progress;
  final BucketStatus status;
  final String? cardMessageId;
  final Share? myShare;
  final List<Share> shares;
  final int? baseUnitPrice;
  final String? description;
  final String? orderId;

  /// Current unit price (from progress, else the first tier).
  int? get unitPrice => progress.unitPrice ?? baseUnitPrice ?? (tiers.isNotEmpty ? tiers.first.unitPrice : null);

  int get openUnits => units.where((u) => u.isOpen).length;

  factory Bucket.fromJson(Json j) => Bucket(
        id: asString(j['id']),
        communityId: asString(j['communityId']),
        type: BucketType.parse(j['type']),
        category: asStringOrNull(j['category']),
        title: asString(j['title']),
        subtitle: asStringOrNull(j['subtitle']),
        image: asStringOrNull(j['image']),
        vendor: asJson(j['vendor']) == null ? null : Vendor.fromJson(asJson(j['vendor'])!),
        createdBy: asJson(j['createdBy']) == null ? null : User.fromJson(asJson(j['createdBy'])!),
        settleMode: PayMode.parse(j['settleMode']),
        meet: asJson(j['meet']),
        cutoffAt: asTime(j['cutoffAt']),
        deliverAt: asTime(j['deliverAt']),
        pickupPoint: asStringOrNull(j['pickupPoint']),
        unitLabel: asStringOrNull(j['unitLabel']),
        retailUnitPrice: asIntOrNull(j['retailUnitPrice']),
        netWeight: asStringOrNull(j['netWeight']),
        serves: asStringOrNull(j['serves']),
        units: asList(j['units'], BucketUnit.fromJson),
        tiers: asList(j['tiers'], Tier.fromJson),
        items: asList(j['items'], TripItem.fromJson),
        capacity: asIntOrNull(j['capacity']),
        progress: Progress.fromJson(asJson(j['progress']) ?? const {}),
        status: BucketStatus.parse(j['status']),
        cardMessageId: asStringOrNull(j['cardMessageId']),
        myShare: asJson(j['myShare']) == null ? null : Share.fromJson(asJson(j['myShare'])!),
        shares: asList(j['shares'], Share.fromJson),
        baseUnitPrice: asIntOrNull(j['unitPrice']),
        description: asStringOrNull(j['description']),
        orderId: asStringOrNull(j['orderId']),
      );
}
