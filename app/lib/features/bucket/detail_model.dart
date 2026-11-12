import 'dart:convert';

import '../../core/models/models.dart';

/// Fields from the server build ("Additions" in docs/CONTRACT.md) that the
/// core [Bucket] model doesn't carry yet. Parsed from the same raw JSON.
class BucketExtras {
  const BucketExtras({
    this.minQty,
    this.maxQty,
    this.lotQty,
    this.maxUnitsPerMember,
    this.optionGroups = const [],
    this.minLoadKg,
    this.transportFee,
    this.closedAt,
    this.goAt,
    this.transportPerKg,
    this.itemKg = const {},
    this.itemRetail = const {},
    this.itemMax = const {},
    this.shareLabels = const {},
    this.myShareLabel,
    this.mySavings,
    this.meetPlace,
    this.meetAt,
    this.meetNote,
  });

  final int? minQty;
  final int? maxQty;
  final int? lotQty;
  final int? maxUnitsPerMember;
  final List<OptionGroup> optionGroups;
  final num? minLoadKg;
  final int? transportFee;
  final DateTime? closedAt;
  final num? goAt;
  final num? transportPerKg;

  /// Trip item id → kg per unit, retail price, max per member.
  final Map<String, double> itemKg;
  final Map<String, int> itemRetail;
  final Map<String, num> itemMax;

  /// Share id → `qtyLabel` ("Steak 1", "15 kg").
  final Map<String, String> shareLabels;
  final String? myShareLabel;
  final int? mySavings;

  final String? meetPlace;
  final DateTime? meetAt;
  final String? meetNote;

  factory BucketExtras.fromJson(Json j) {
    final items = j['items'] is List ? (j['items'] as List).whereType<Map>() : const <Map>[];
    final meet = asJson(j['meet']);
    final progress = asJson(j['progress']) ?? const {};
    final my = asJson(j['myShare']);
    return BucketExtras(
      minQty: asIntOrNull(j['minQty']),
      maxQty: asIntOrNull(j['maxQty']),
      lotQty: asIntOrNull(j['lotQty']),
      maxUnitsPerMember: asIntOrNull(j['maxUnitsPerMember']),
      optionGroups: asList(j['optionGroups'], OptionGroup.fromJson).where((g) => g.choices.isNotEmpty).toList(),
      minLoadKg: j['minLoadKg'] is num ? j['minLoadKg'] as num : null,
      transportFee: asIntOrNull(j['transportFee']),
      closedAt: asTime(j['closedAt']),
      goAt: progress['goAt'] is num ? progress['goAt'] as num : null,
      transportPerKg: progress['transportPerKg'] is num ? progress['transportPerKg'] as num : null,
      itemKg: {for (final i in items) asString(i['id']): asDouble(i['kgPerUnit'], 1)},
      itemRetail: {for (final i in items) if (i['retailPrice'] != null) asString(i['id']): asInt(i['retailPrice'])},
      itemMax: {for (final i in items) if (i['maxQty'] is num) asString(i['id']): i['maxQty'] as num},
      shareLabels: {
        if (j['shares'] is List)
          for (final s in (j['shares'] as List).whereType<Map>())
            if (s['qtyLabel'] != null) asString(s['id']): asString(s['qtyLabel']),
      },
      myShareLabel: asStringOrNull(my?['qtyLabel']),
      mySavings: asIntOrNull(my?['savings']),
      meetPlace: asStringOrNull(meet?['place']),
      meetAt: asTime(meet?['at']),
      meetNote: asStringOrNull(meet?['note']),
    );
  }
}

class OptionGroup {
  const OptionGroup({required this.key, required this.label, required this.choices});

  final String key;
  final String label;
  final List<String> choices;

  factory OptionGroup.fromJson(Json j) =>
      OptionGroup(key: asString(j['key']), label: asString(j['label']), choices: asStringList(j['choices']));
}

/// A bucket plus its extras, as loaded by the detail screen.
class BucketView {
  const BucketView(this.bucket, this.x);

  final Bucket bucket;
  final BucketExtras x;

  factory BucketView.fromJson(Json j) => BucketView(Bucket.fromJson(j), BucketExtras.fromJson(j));

  /// Applies live card metadata (`p` progress JSON, `s` status, `u` unit owners).
  BucketView withMetadata(Map<String, String> meta) {
    final b = bucket;
    var progress = b.progress;
    final p = meta['p'];
    if (p != null && p.isNotEmpty) {
      try {
        final d = jsonDecode(p);
        if (d is Map) progress = Progress.fromJson(d.cast<String, dynamic>());
      } catch (_) {}
    }
    var units = b.units;
    final u = meta['u'];
    if (u != null && u.isNotEmpty && units.isNotEmpty) {
      try {
        final d = jsonDecode(u);
        if (d is List) {
          final owners = <String, String>{
            for (final e in d)
              if (e is List && e.length >= 2) e[0].toString(): e[1].toString(),
          };
          units = [
            for (final unit in units)
              if (!owners.containsKey(unit.id))
                unit
              else if (owners[unit.id]!.isEmpty)
                BucketUnit(id: unit.id, label: unit.label, price: unit.price, grams: unit.grams)
              else
                BucketUnit(
                  id: unit.id,
                  label: unit.label,
                  price: unit.price,
                  grams: unit.grams,
                  owner: unit.owner ?? User(id: 'live_${unit.id}', name: owners[unit.id]!),
                ),
          ];
        }
      } catch (_) {}
    }
    final status = meta['s'] == null ? b.status : BucketStatus.parse(meta['s']);
    return BucketView(
      Bucket(
        id: b.id,
        communityId: b.communityId,
        type: b.type,
        title: b.title,
        status: status == BucketStatus.unknown ? b.status : status,
        progress: progress,
        category: b.category,
        subtitle: b.subtitle,
        image: b.image,
        vendor: b.vendor,
        createdBy: b.createdBy,
        settleMode: b.settleMode,
        meet: b.meet,
        cutoffAt: b.cutoffAt,
        deliverAt: b.deliverAt,
        pickupPoint: b.pickupPoint,
        unitLabel: b.unitLabel,
        retailUnitPrice: b.retailUnitPrice,
        netWeight: b.netWeight,
        serves: b.serves,
        units: units,
        tiers: b.tiers,
        items: b.items,
        capacity: b.capacity,
        cardMessageId: b.cardMessageId,
        myShare: b.myShare,
        shares: b.shares,
        baseUnitPrice: b.baseUnitPrice,
        description: b.description,
        orderId: b.orderId,
      ),
      x,
    );
  }
}

/// What the member has picked on the detail screen, carried to the hold flow.
class JoinDraft {
  const JoinDraft({
    this.unitIds = const [],
    this.qty,
    this.items = const {},
    this.options = const {},
  });

  final List<String> unitIds;
  final int? qty;

  /// Trip item id → quantity.
  final Map<String, num> items;
  final Map<String, String> options;

  bool get isEmpty => unitIds.isEmpty && (qty ?? 0) <= 0 && items.values.every((q) => q <= 0);

  JoinDraft copyWith({List<String>? unitIds, int? qty, Map<String, num>? items, Map<String, String>? options}) => JoinDraft(
        unitIds: unitIds ?? this.unitIds,
        qty: qty ?? this.qty,
        items: items ?? this.items,
        options: options ?? this.options,
      );
}

/// Client-side mirror of server/src/domain/pricing.js, used for the live
/// "Hold ₹960" quote. The server's quote is the one that gets held.
class Pricing {
  const Pricing(this.v);

  final BucketView v;
  Bucket get b => v.bucket;

  List<Tier> get tiers => [...b.tiers]..sort((a, c) => a.minQty.compareTo(c.minQty));

  int unitPriceAt(num total) {
    Tier? hit;
    for (final t in tiers) {
      if (total >= t.minQty) hit = t;
    }
    if (hit != null) return hit.unitPrice;
    return b.baseUnitPrice ?? (tiers.isNotEmpty ? tiers.first.unitPrice : 0);
  }

  Tier? nextTierAfter(num total) {
    for (final t in tiers) {
      if (t.minQty > total) return t;
    }
    return null;
  }

  double itemKg(String id, num qty) => qty * (v.x.itemKg[id] ?? 1);

  double kgOf(Map<String, num> items) {
    var kg = 0.0;
    items.forEach((id, q) => kg += itemKg(id, q));
    return (kg * 100).round() / 100;
  }

  int goodsOf(Map<String, num> items) {
    var sum = 0.0;
    items.forEach((id, q) {
      final def = b.items.where((i) => i.id == id).firstOrNull;
      sum += q * (def?.price ?? 0);
    });
    return sum.round();
  }

  int transportFor(num kg) {
    if (kg <= 0) return 0;
    final fee = v.x.transportFee ?? 0;
    final load = b.progress.filled + kg;
    final min = v.x.minLoadKg ?? 1;
    return (fee * kg / (load > min ? load : min)).round();
  }

  /// What gets held for [d] right now.
  int quote(JoinDraft d) {
    switch (b.type) {
      case BucketType.split:
        return d.unitIds.fold(0, (s, id) => s + (b.units.where((u) => u.id == id).firstOrNull?.price ?? 0));
      case BucketType.bulk:
      case BucketType.service:
        final q = d.qty ?? 0;
        return q * unitPriceAt(b.progress.filled + q);
      case BucketType.trip:
        final items = {for (final e in d.items.entries) if (e.value > 0) e.key: e.value};
        return goodsOf(items) + transportFor(kgOf(items));
      case BucketType.unknown:
        return 0;
    }
  }

  /// Shop price of [d], for "you save ₹x vs shop price".
  int retailOf(JoinDraft d) {
    switch (b.type) {
      case BucketType.split:
        return d.unitIds.fold(0, (s, id) {
          final u = b.units.where((u) => u.id == id).firstOrNull;
          return s + (((u?.grams ?? 0) / 1000) * (b.retailUnitPrice ?? 0)).round();
        });
      case BucketType.bulk:
      case BucketType.service:
        return (d.qty ?? 0) * (b.retailUnitPrice ?? 0);
      case BucketType.trip:
        var sum = 0.0;
        d.items.forEach((id, q) {
          final def = b.items.where((i) => i.id == id).firstOrNull;
          sum += q * (v.x.itemRetail[id] ?? def?.price ?? 0);
        });
        return sum.round();
      case BucketType.unknown:
        return 0;
    }
  }

  int savingOf(JoinDraft d) {
    final s = retailOf(d) - quote(d);
    return s > 0 ? s : 0;
  }
}

/// Quantities without a trailing `.0`: `12`, `1.5`.
String fmtQty(num n) => n == n.roundToDouble() ? n.round().toString() : n.toStringAsFixed(n * 10 == (n * 10).roundToDouble() ? 1 : 2);

const _noPlural = {'kg', 'g', 'l', 'L', 'dozen', 'ml', 'pc', 'pcs'};

/// `1 flat`, `3 flats`, `12 kg`, `2 dozen` (server `plural`).
String plural(num n, String label) => '${fmtQty(n)} ${n == 1 || _noPlural.contains(label) ? label : pluralWord(label)}';

/// `half` → `halves`, `cut` → `cuts`, `kg` → `kg`.
String pluralWord(String label) {
  if (_noPlural.contains(label)) return label;
  if (label.endsWith('lf')) return '${label.substring(0, label.length - 1)}ves';
  if (label.endsWith('s')) return label;
  return '${label}s';
}
