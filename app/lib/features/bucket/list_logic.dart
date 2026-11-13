import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/images.dart';
import '../../core/models/models.dart';
import '../../widgets/progress_bar.dart';

/// Clock for countdowns. Tests pin it so screenshots stay stable.
class StreetClock {
  StreetClock._();

  static DateTime Function() now = DateTime.now;
}

/// Filters shared between Street home (category grid, banners) and the Buckets tab.
/// Home sets them and switches tab; the Buckets screen listens.
class BucketsFilter {
  BucketsFilter._();

  /// Category id from [AppImages.categories], or null for all.
  static final category = ValueNotifier<String?>(null);
  static final type = ValueNotifier<BucketType?>(null);
}

enum BucketSort { closingSoon, biggestSaving }

/// Category ids (home grid) → the bucket `category` values the server uses.
const _categoryAliases = <String, Set<String>>{
  'fish': {'fish', 'seafood'},
  'meat': {'meat', 'mutton', 'chicken'},
  'fruits': {'fruit', 'fruits'},
  'vegetables': {'veg', 'vegetable', 'vegetables'},
  'staples': {'grocery', 'staples', 'rice'},
  'dairy': {'dairy', 'eggs'},
  'festive': {'festive'},
  'services': {'service', 'services'},
};

bool inCategory(Bucket b, String categoryId) =>
    (_categoryAliases[categoryId] ?? {categoryId}).contains(b.category);

String categoryLabel(String id) =>
    AppImages.categories.firstWhere((c) => c.$1 == id, orElse: () => (id, id)).$2;

/// Short label for chips ("Fish & Seafood" → "Fish").
String categoryShortLabel(String id) => switch (id) {
      'fish' => 'Fish',
      'dairy' => 'Dairy',
      'services' => 'Services',
      _ => categoryLabel(id),
    };

/// Tint + icon used when a category photo is missing.
(Color, IconData) categoryArt(String id) => switch (id) {
      'fish' => (const Color(0xFFE3F0FA), Icons.set_meal_rounded),
      'meat' => (const Color(0xFFFBE7E3), Icons.kebab_dining_rounded),
      'fruits' => (const Color(0xFFFFF1D6), Icons.spa_rounded),
      'vegetables' => (const Color(0xFFEAF5DF), Icons.eco_rounded),
      'staples' => (const Color(0xFFF7EEDD), Icons.rice_bowl_rounded),
      'dairy' => (const Color(0xFFFFF8E7), Icons.egg_rounded),
      'festive' => (const Color(0xFFFDE8F0), Icons.celebration_rounded),
      'services' => (const Color(0xFFE6F5EE), Icons.cleaning_services_rounded),
      _ => (const Color(0xFFFFF1EC), Icons.shopping_basket_rounded),
    };

/// `87` for 87.0, `2.5` for 2.5.
String qtyText(num n) => n == n.roundToDouble() ? n.round().toString() : n.toStringAsFixed(1);

/// `cut` → `cuts`, `half` → `halves`, `kg` stays.
String plural(String label, num n) {
  if (n == 1) return label;
  const same = {'kg', 'g', 'dozen', 'pc', 'pcs', 'l', 'litre'};
  if (same.contains(label)) return label;
  if (label == 'half') return 'halves';
  if (label.endsWith('s')) return label;
  return '${label}s';
}

extension BucketDisplay on Bucket {
  bool get isLive => status.isOpen;

  String get typeLabel => switch (type) {
        BucketType.split => 'Split',
        BucketType.bulk => 'Bulk',
        BucketType.service => 'Service',
        BucketType.trip => 'Market trip',
        BucketType.unknown => 'Bucket',
      };

  String get unit => unitLabel ?? 'share';

  /// What the shown price is per: split buckets are priced by weight.
  String get priceUnit => switch (type) {
        BucketType.split || BucketType.trip => 'kg',
        _ => unit,
      };

  /// Price on the card. Trip shows the cheapest item ("From ₹22/kg").
  int? get displayPrice {
    if (type == BucketType.trip) {
      final prices = items.where((i) => i.unit == 'kg').map((i) => i.price);
      return prices.isEmpty ? null : prices.reduce((a, b) => a < b ? a : b);
    }
    return unitPrice;
  }

  int? get displayRetail => type == BucketType.trip ? null : retailUnitPrice;

  int? get savePercent {
    final p = displayPrice, r = displayRetail;
    return p == null || r == null ? null : Fmt.savePercent(price: p, retail: r);
  }

  /// Licious "450 g | 3-5 pieces | Serves 5", adapted per bucket type.
  List<String> get facts {
    final tierFloor = tiers.isEmpty ? null : tiers.first.minQty;
    switch (type) {
      case BucketType.split:
        return [
          ?netWeight,
          if (units.isNotEmpty) '${units.length} ${plural(unit, units.length)}',
          if (serves != null) 'Serves $serves',
        ];
      case BucketType.bulk:
        return [
          netWeight ?? 'Sold by the $unit',
          if (tiers.length > 1) '${tiers.length} price tiers',
          if (tierFloor != null) 'Goes at $tierFloor ${plural(unit, tierFloor)}',
        ];
      case BucketType.service:
        return [
          'Per $unit',
          if (tiers.length > 1) '${tiers.length} price tiers',
          if (tierFloor != null) 'Goes at $tierFloor ${plural(unit, tierFloor)}',
        ];
      case BucketType.trip:
        return [
          if (capacity != null) '$capacity kg tempo',
          if (items.isNotEmpty) '${items.length} items',
          if (pickupPoint != null) 'Pickup $pickupPoint',
        ];
      case BucketType.unknown:
        return [?netWeight, if (serves != null) 'Serves $serves'];
    }
  }

  /// "6 of 8 cuts", "87 of 100 kg", "31 of 50 flats", "186 of 300 kg booked".
  String get progressCaption {
    final p = progress;
    final label = type == BucketType.trip ? 'kg' : unit;
    final base = '${qtyText(p.filled)} of ${qtyText(p.target)} ${plural(label, p.target)}';
    return type == BucketType.trip ? '$base booked' : base;
  }

  /// "13 kg to ₹88" when a cheaper tier is in reach.
  String? get nextTierCaption {
    final n = progress.nextTier;
    if (n == null || !isLive) return null;
    return '${qtyText(n.remaining)} ${plural(unit, n.remaining)} to ${Fmt.rupees(n.unitPrice)}';
  }

  Duration? timeLeft([DateTime? now]) => cutoffAt?.difference(now ?? StreetClock.now());

  String get statusLabel => switch (status) {
        BucketStatus.live => 'Live',
        BucketStatus.ordered => 'Order placed',
        BucketStatus.marketDay => 'Market day',
        BucketStatus.delivering => 'On the way',
        BucketStatus.completed => 'Completed',
        BucketStatus.expired => 'Expired',
        BucketStatus.cancelled => 'Cancelled',
        BucketStatus.unknown => 'Closed',
      };

  /// Rupees saved per unit vs retail (for "Biggest saving" sort).
  double get savingScore => (savePercent ?? 0).toDouble();

  /// Latest neighbour activity, e.g. `Ravi took Steak 1`.
  String? get latestActivity {
    if (shares.isEmpty) return null;
    final s = shares.last;
    String what;
    if (type == BucketType.split && s.unitIds.isNotEmpty) {
      what = units.where((u) => u.id == s.unitIds.first).map((u) => u.label).firstOrNull ?? 'a $unit';
    } else {
      final label = type == BucketType.trip ? 'kg' : unit;
      what = '${qtyText(s.qty)} ${plural(label, s.qty)}';
    }
    return '${s.user.name} took $what';
  }

  /// Copy with live values from the chat card metadata.
  Bucket withLive({Progress? progress, BucketStatus? status}) => Bucket(
        id: id,
        communityId: communityId,
        type: type,
        title: title,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        category: category,
        subtitle: subtitle,
        image: image,
        vendor: vendor,
        createdBy: createdBy,
        settleMode: settleMode,
        meet: meet,
        cutoffAt: cutoffAt,
        deliverAt: deliverAt,
        pickupPoint: pickupPoint,
        unitLabel: unitLabel,
        retailUnitPrice: retailUnitPrice,
        netWeight: netWeight,
        serves: serves,
        units: units,
        tiers: tiers,
        items: items,
        capacity: capacity,
        cardMessageId: cardMessageId,
        myShare: myShare,
        shares: shares,
        baseUnitPrice: baseUnitPrice,
        description: description,
        orderId: orderId,
      );
}

List<Bucket> sortBuckets(Iterable<Bucket> list, BucketSort sort) {
  final out = list.toList();
  final far = DateTime(2100);
  switch (sort) {
    case BucketSort.closingSoon:
      out.sort((a, b) => (a.cutoffAt ?? far).compareTo(b.cutoffAt ?? far));
    case BucketSort.biggestSaving:
      out.sort((a, b) => b.savingScore.compareTo(a.savingScore));
  }
  return out;
}

final _wordSplit = RegExp(r'[^a-z0-9]+');

/// Client-side search: every query word must start a word in the title,
/// subtitle, vendor, category or type (so "rice" finds basmati, not "price").
List<Bucket> searchBuckets(Iterable<Bucket> list, String query) {
  final words = query.trim().toLowerCase().split(_wordSplit).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return list.toList();
  return list.where((b) {
    final cat = AppImages.categories.where((c) => inCategory(b, c.$1)).map((c) => c.$2).join(' ');
    final tokens = [b.title, b.subtitle, b.vendor?.name, b.vendor?.place, b.category, cat, b.typeLabel]
        .whereType<String>()
        .join(' ')
        .toLowerCase()
        .split(_wordSplit)
        .where((t) => t.isNotEmpty)
        .toList();
    return words.every((w) => tokens.any((t) => t.startsWith(w)));
  }).toList();
}

/// Applies a `js:bucket` metadata change (`p` progress JSON, `s` status) to the
/// matching bucket in [list]. Returns null when nothing matched.
List<Bucket>? applyCardMetadata(List<Bucket> list, String messageId, Map<String, String> meta) {
  final i = list.indexWhere((b) => b.cardMessageId == messageId);
  if (i < 0) return null;
  Progress? p;
  try {
    final raw = meta['p'];
    final v = raw == null ? null : jsonDecode(raw);
    if (v is Map) p = Progress.fromJson(v.cast<String, dynamic>());
  } catch (_) {}
  final s = meta['s'] == null ? null : BucketStatus.parse(meta['s']);
  if (p == null && s == null) return null;
  return [...list]..[i] = list[i].withLive(progress: p, status: s);
}

/// `Whole Seer (Vanjaram)` → `Whole Seer`; `Kasimedu Book & Meet: Whole Paarai` → `Whole Paarai`.
String shortTitle(String title) {
  var t = title.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
  final colon = t.indexOf(': ');
  if (colon > 0 && colon < t.length - 2) t = t.substring(colon + 2);
  return t;
}

/// `Sat 5 am`, `Sun 6:30 am` (local time, lower-case am/pm).
String whenShort(DateTime t) {
  final l = t.toLocal();
  final f = l.minute == 0 ? DateFormat('EEE h a') : DateFormat('EEE h:mm a');
  return f.format(l).replaceAll('AM', 'am').replaceAll('PM', 'pm');
}

extension BucketGroup on Bucket {
  /// Distinct people in the bucket, in the order they joined (the same order
  /// the bucket detail lists them, so names match across screens).
  List<User> get people {
    final seen = <String>{};
    return [for (final s in shares) if (seen.add(s.user.id)) s.user];
  }

  /// `Meera (A-303), Ravi (C-801) and 4 others are in`.
  String peopleLine({String? meId, bool withFlats = true, int names = 2}) {
    final ppl = people;
    final total = math.max(progress.members, ppl.length);
    if (total == 0) return 'Be the first to join';
    String name(User u) => u.id == meId ? 'You' : (u.unit == null || !withFlats ? u.name : '${u.name} (${u.unit})');
    final mine = ppl.where((u) => u.id == meId).toList();
    final named = [...mine, ...ppl.where((u) => u.id != meId)].take(names).map(name).toList();
    final rest = total - named.length;
    if (rest <= 0) return '${named.join(' and ')} ${named.length == 1 && named.first != 'You' ? 'is' : 'are'} in';
    return '${named.join(', ')} and $rest ${rest == 1 ? 'other' : 'others'} are in';
  }

  /// The shared goal in plain words: what the group needs next.
  String get goalHeadline {
    final p = progress;
    final left = (p.target - p.filled).clamp(0, double.infinity);
    switch (type) {
      case BucketType.split:
        if (settleMode == PayMode.atMarket) {
          final at = asTime(meet?['at']) ?? cutoffAt;
          return left > 0
              ? 'Book your $unit · meet ${at == null ? 'at the market' : whenShort(at)}'
              : 'All booked · meet ${at == null ? 'at the market' : whenShort(at)}';
        }
        return left > 0 ? '${qtyText(left)} ${plural(unit, left)} left of a ${shortTitle(title).toLowerCase()}' : 'Fully claimed';
      case BucketType.bulk:
      case BucketType.service:
        final n = p.nextTier;
        if (n != null) {
          return type == BucketType.service
              ? "${qtyText(n.remaining)} more ${plural(unit, n.remaining)} and it's ${Fmt.rupees(n.unitPrice)} a $unit"
              : "${qtyText(n.remaining)} $unit more and it's ${Fmt.rupees(n.unitPrice)}/$unit for everyone";
        }
        return p.unitPrice == null ? 'Best price unlocked' : 'Best price unlocked: ${Fmt.rupees(p.unitPrice!)}/$unit';
      case BucketType.trip:
        return 'Tempo ${p.percentRounded}% full${cutoffAt == null ? '' : ' · leaves ${whenShort(cutoffAt!)}'}';
      case BucketType.unknown:
        return progressCaption;
    }
  }

  /// Price-tier markers along the progress bar (bulk, service).
  List<TierMarker> get tierMarkers {
    final t = progress.target;
    if (t <= 0 || tiers.isEmpty) return const [];
    return [
      for (final tier in tiers)
        if (tier.minQty <= t)
          TierMarker(at: tier.minQty / t, label: Fmt.rupees(tier.unitPrice), reached: progress.filled >= tier.minQty),
    ];
  }
}
