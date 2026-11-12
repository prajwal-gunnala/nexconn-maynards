import 'package:flutter/material.dart';

import '../../core/models/json.dart';

/// The four bucket types, with the copy shown on the type tiles.
enum DraftKind {
  split('split', 'Split', 'One big thing, cut into shares', Icons.set_meal_rounded),
  bulk('bulk', 'Bulk', 'Price drops as the group buys more', Icons.inventory_2_rounded),
  service('service', 'Service', 'Per-flat price drops as flats join', Icons.cleaning_services_rounded),
  trip('trip', 'Market trip', 'One run to the market, a shared list', Icons.local_shipping_rounded);

  const DraftKind(this.wire, this.label, this.blurb, this.icon);
  final String wire;
  final String label;
  final String blurb;
  final IconData icon;

  bool get hasTiers => this == bulk || this == service;
}

/// How a split bucket is divided. Labels are the claimable parts.
class SharePreset {
  const SharePreset(this.id, this.label, this.unitLabel, this.parts);
  final String id;
  final String label;
  final String unitLabel;
  final List<String> parts;

  static const halves = SharePreset('halves', 'Halves', 'half', ['Head half', 'Tail half']);
  static const cuts8 =
      SharePreset('cuts8', '8 cuts', 'cut', ['Head', 'Steak 1', 'Steak 2', 'Steak 3', 'Steak 4', 'Steak 5', 'Steak 6', 'Tail']);
  static const shares7 = SharePreset('shares7', '7 shares', 'share', [
    'Front leg (L)',
    'Front leg (R)',
    'Hind leg (L)',
    'Hind leg (R)',
    'Ribs & chops',
    'Shoulder & neck',
    'Liver & keema',
  ]);
  static const custom = SharePreset('custom', 'Custom', 'share', []);

  static const all = [halves, cuts8, shares7, custom];
  static SharePreset byId(String id) => all.firstWhere((p) => p.id == id, orElse: () => custom);

  List<String> labelsFor(int customCount) =>
      parts.isNotEmpty ? parts : [for (var i = 1; i <= customCount; i++) 'Share $i'];
}

/// Seeded vendors the creator can pick (server `vendorId`), or none: "I'll buy it myself".
class VendorOption {
  const VendorOption(this.id, this.name, this.place);
  final String id;
  final String name;
  final String place;

  static const all = [
    VendorOption('v_murugan', 'Murugan Fish Stall', 'Kasimedu'),
    VendorOption('v_balaji', 'Sri Balaji Traders', 'Koyambedu'),
    VendorOption('v_alnoor', 'Al-Noor Meats', 'Pallavaram'),
    VendorOption('v_devgad', 'Devgad Mango FPO', 'Devgad'),
    VendorOption('v_safehome', 'SafeHome Pest Services', 'OMR'),
  ];

  static VendorOption? byId(String? id) => all.where((v) => v.id == id).firstOrNull;
}

/// Server categories (bucket `category`).
const draftCategories = <(String, String)>[
  ('fish', 'Fish'),
  ('meat', 'Meat'),
  ('fruit', 'Fruit'),
  ('veg', 'Veg'),
  ('grocery', 'Grocery'),
  ('service', 'Service'),
];

/// Photo keys the creator can choose (mapped to bundled photos by AppImages).
const draftPhotos = <String>[
  'seer', 'seer_steaks', 'paarai', 'prawns', 'goat', 'basmati', 'toor_dal', 'oil', //
  'alphonso', 'koyambedu', 'eggs', 'paneer', 'dry_fruits', 'pest', 'tank',
];

const pickupPoints = <String>['Gate 1', 'Gate 2', 'Clubhouse', 'Basement B2', 'Your flat'];

class TripItemSeed {
  const TripItemSeed(this.name, this.unit, this.price, this.retail, {this.kgPerUnit = 1});
  final String name;
  final String unit;
  final int price;
  final int? retail;
  final double kgPerUnit;
}

/// When a template's cutoff lands, relative to "now".
enum CutoffPreset { inThreeHours, tonight, tomorrowEvening, beforeMeet }

/// Plain values that prefill step 2 (a template, or the blank default for a type).
class DraftSeed {
  const DraftSeed({
    required this.kind,
    this.title = '',
    this.subtitle = '',
    this.image,
    this.category,
    this.vendorId,
    this.weightKg = '',
    this.preset = 'halves',
    this.customCount = 4,
    this.pricePerKg,
    this.retail,
    this.unitLabel,
    this.tiers = const [],
    this.minQty,
    this.maxQty,
    this.items = const [],
    this.capacity,
    this.transportFee,
    this.atMarket = false,
    this.meetPlace = '',
    this.cutoff = CutoffPreset.tonight,
    this.pickupPoint = 'Gate 2',
  });

  final DraftKind kind;
  final String title;
  final String subtitle;
  final String? image;
  final String? category;
  final String? vendorId;
  final String weightKg;
  final String preset;
  final int customCount;
  final int? pricePerKg;
  final int? retail;
  final String? unitLabel;
  final List<(int, int)> tiers;
  final int? minQty;
  final int? maxQty;
  final List<TripItemSeed> items;
  final int? capacity;
  final int? transportFee;
  final bool atMarket;
  final String meetPlace;
  final CutoffPreset cutoff;
  final String pickupPoint;

  /// Starting point when the creator picks a type tile instead of a template.
  static DraftSeed blank(DraftKind k) => switch (k) {
        DraftKind.split => const DraftSeed(kind: DraftKind.split, preset: 'halves', category: 'fish'),
        DraftKind.bulk => const DraftSeed(kind: DraftKind.bulk, unitLabel: 'kg', tiers: [(25, 0)], minQty: 1, category: 'grocery'),
        DraftKind.service =>
          const DraftSeed(kind: DraftKind.service, unitLabel: 'flat', tiers: [(10, 0)], minQty: 1, maxQty: 1, category: 'service', pickupPoint: 'Your flat'),
        DraftKind.trip => const DraftSeed(kind: DraftKind.trip, capacity: 300, transportFee: 1800, category: 'veg', pickupPoint: 'Basement B2', items: [
            TripItemSeed('Onion', 'kg', 28, 45),
          ]),
      };
}

/// A Licious-style quick start: photo card on step 1 that fills step 2.
class BucketTemplate {
  const BucketTemplate({required this.id, required this.name, required this.meta, required this.priceLine, required this.seed});
  final String id;
  final String name;
  final String meta;
  final String priceLine;
  final DraftSeed seed;

  String get image => seed.image ?? 'seer';

  static const all = <BucketTemplate>[
    BucketTemplate(
      id: 'seer',
      name: 'Whole seer',
      meta: 'Split · 8 cuts',
      priceLine: '₹950/kg',
      seed: DraftSeed(
        kind: DraftKind.split,
        title: 'Whole Seer (Vanjaram)',
        subtitle: 'Fresh off the boat at Kasimedu',
        image: 'seer',
        category: 'fish',
        vendorId: 'v_murugan',
        weightKg: '5.2',
        preset: 'cuts8',
        pricePerKg: 950,
        retail: 1400,
        cutoff: CutoffPreset.inThreeHours,
        pickupPoint: 'Gate 2',
      ),
    ),
    BucketTemplate(
      id: 'rice',
      name: 'Rice sack',
      meta: 'Bulk · 2 price tiers',
      priceLine: '₹96, then ₹88/kg',
      seed: DraftSeed(
        kind: DraftKind.bulk,
        title: 'Aged Basmati Rice (1121)',
        subtitle: 'Koyambedu wholesale, packed in 5 kg bags',
        image: 'basmati',
        category: 'grocery',
        vendorId: 'v_balaji',
        unitLabel: 'kg',
        retail: 135,
        tiers: [(25, 96), (100, 88)],
        minQty: 5,
        maxQty: 50,
        cutoff: CutoffPreset.tomorrowEvening,
        pickupPoint: 'Clubhouse',
      ),
    ),
    BucketTemplate(
      id: 'alphonso',
      name: 'Alphonso peti',
      meta: 'Bulk · by the dozen',
      priceLine: '₹1,150, then ₹990/dz',
      seed: DraftSeed(
        kind: DraftKind.bulk,
        title: 'Devgad Alphonso Peti',
        subtitle: 'GI-tagged, farm-direct, 1 dozen boxes',
        image: 'alphonso',
        category: 'fruit',
        vendorId: 'v_devgad',
        unitLabel: 'dozen',
        retail: 1450,
        tiers: [(12, 1150), (24, 990)],
        minQty: 1,
        maxQty: 4,
        cutoff: CutoffPreset.tomorrowEvening,
        pickupPoint: 'Clubhouse',
      ),
    ),
    BucketTemplate(
      id: 'goat',
      name: 'Goat share',
      meta: 'Split · 7 shares',
      priceLine: '₹860/kg',
      seed: DraftSeed(
        kind: DraftKind.split,
        title: 'Whole Goat, 7-share Split',
        subtitle: 'Halal, Bakrid-style cut to order',
        image: 'goat',
        category: 'meat',
        vendorId: 'v_alnoor',
        weightKg: '14',
        preset: 'shares7',
        pricePerKg: 860,
        retail: 1000,
        cutoff: CutoffPreset.tomorrowEvening,
        pickupPoint: 'Gate 1',
      ),
    ),
    BucketTemplate(
      id: 'pest',
      name: 'Pest control',
      meta: 'Service · per flat',
      priceLine: '₹480 down to ₹340',
      seed: DraftSeed(
        kind: DraftKind.service,
        title: 'Tower Pest Control (Gel + Spray)',
        subtitle: 'Cockroach and ant treatment, 90-day warranty',
        image: 'pest',
        category: 'service',
        vendorId: 'v_safehome',
        unitLabel: 'flat',
        retail: 650,
        tiers: [(10, 480), (25, 400), (50, 340)],
        minQty: 1,
        maxQty: 1,
        cutoff: CutoffPreset.tomorrowEvening,
        pickupPoint: 'Your flat',
      ),
    ),
    BucketTemplate(
      id: 'koyambedu',
      name: 'Koyambedu run',
      meta: 'Market trip · 300 kg',
      priceLine: 'Shared tempo',
      seed: DraftSeed(
        kind: DraftKind.trip,
        title: 'Koyambedu Saturday Run',
        subtitle: 'Wholesale veg and fruit, back by 9 am',
        image: 'koyambedu',
        category: 'veg',
        capacity: 300,
        transportFee: 1800,
        items: [
          TripItemSeed('Onion', 'kg', 28, 45),
          TripItemSeed('Tomato', 'kg', 22, 40),
          TripItemSeed('Potato', 'kg', 30, 42),
          TripItemSeed('Banana (Poovan)', 'dozen', 45, 70, kgPerUnit: 1.5),
          TripItemSeed('Coconut', 'pc', 22, 38, kgPerUnit: 0.5),
        ],
        cutoff: CutoffPreset.tomorrowEvening,
        pickupPoint: 'Basement B2',
      ),
    ),
    BucketTemplate(
      id: 'meetup',
      name: 'Fish market meet-up',
      meta: 'Split halves · pay at the market',
      priceLine: '₹520/kg',
      seed: DraftSeed(
        kind: DraftKind.split,
        title: 'Kasimedu Book & Meet: Whole Paarai',
        subtitle: 'Trevally, about 2.8 kg, split in two halves',
        image: 'paarai',
        category: 'fish',
        vendorId: 'v_murugan',
        weightKg: '2.8',
        preset: 'halves',
        pricePerKg: 520,
        retail: 900,
        atMarket: true,
        meetPlace: 'Kasimedu, Gate 3',
        cutoff: CutoffPreset.beforeMeet,
        pickupPoint: 'Gate 3',
      ),
    ),
  ];
}

/// One part of a split bucket, computed from the total weight and price per kg.
class SplitPart {
  const SplitPart(this.id, this.label, this.grams, this.price);
  final String id;
  final String label;
  final int grams;
  final int price;

  Json toJson() => {'id': id, 'label': label, 'grams': grams, 'price': price};
}

/// Equal parts by weight, priced at [pricePerKg]. Grams round to 10 g.
List<SplitPart> splitParts(List<String> labels, double totalKg, int pricePerKg) {
  if (labels.isEmpty) return const [];
  final grams = totalKg <= 0 ? 0 : ((totalKg * 1000 / labels.length) / 10).round() * 10;
  final price = (grams / 1000 * pricePerKg).round();
  return [
    for (var i = 0; i < labels.length; i++)
      SplitPart(_slug(labels[i], i), labels[i], grams, price),
  ];
}

String _slug(String s, int i) {
  final base = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  return base.isEmpty ? 'u${i + 1}' : base;
}

/// "1.2 kg" / "650 g"
String gramsLabel(int g) {
  if (g >= 1000) {
    final kg = g / 1000;
    return '${kg == kg.roundToDouble() ? kg.round() : kg.toStringAsFixed(1)} kg';
  }
  return '$g g';
}

/// Next occurrence of [weekday] (1 = Mon … 7 = Sun) at [hour]:[minute], strictly after [from].
DateTime nextWeekday(DateTime from, int weekday, int hour, [int minute = 0]) {
  var d = DateTime(from.year, from.month, from.day, hour, minute);
  while (d.weekday != weekday || !d.isAfter(from)) {
    d = d.add(const Duration(days: 1));
    d = DateTime(d.year, d.month, d.day, hour, minute);
  }
  return d;
}

/// Default market meet: next Sunday 6:00 am, at least a day away.
DateTime defaultMeetAt(DateTime now) => nextWeekday(now.add(const Duration(hours: 20)), DateTime.sunday, 6);

DateTime cutoffFor(CutoffPreset p, DateTime now, {DateTime? meetAt}) {
  switch (p) {
    case CutoffPreset.inThreeHours:
      final t = now.add(const Duration(hours: 3));
      return DateTime(t.year, t.month, t.day, t.hour, t.minute < 30 ? 30 : 0).add(Duration(hours: t.minute < 30 ? 0 : 1));
    case CutoffPreset.tonight:
      final t = DateTime(now.year, now.month, now.day, 21);
      return t.difference(now).inMinutes >= 60 ? t : t.add(const Duration(days: 1));
    case CutoffPreset.tomorrowEvening:
      final t = DateTime(now.year, now.month, now.day, 20).add(const Duration(days: 1));
      return t;
    case CutoffPreset.beforeMeet:
      final m = meetAt ?? defaultMeetAt(now);
      return m.subtract(const Duration(hours: 8));
  }
}
