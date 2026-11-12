/// One place that maps image keys to bundled photos (lead-owned).
/// Product photos are Google Flow generations (watermark kept, as required); see media/flow/MANIFEST.md.
class AppImages {
  AppImages._();

  static const _p = 'assets/images/products';
  static const _c = 'assets/images/categories';
  static const _b = 'assets/images/banners';
  static const _o = 'assets/images/onboarding';

  /// Server bucket `image` keys → photo. Null means "use the tinted icon placeholder".
  static const Map<String, String> _bucket = {
    'seer': '$_p/seer_whole.jpg',
    'seer_steaks': '$_p/seer_steaks.jpg',
    'basmati': '$_p/basmati_sack.jpg',
    'pest': '$_p/pest_control_kit.jpg',
    'tank': '$_p/tank_cleaning_kit.jpg',
    'koyambedu': '$_p/mandi_crates.jpg',
    'banana': '$_p/mandi_crates.jpg',
    'alphonso': '$_p/alphonso_crate.jpg',
    'goat': '$_p/mutton_curry_cut.jpg',
    'paarai': '$_p/rohu_whole.jpg',
    'rohu': '$_p/rohu_whole.jpg',
    'prawns': '$_p/tiger_prawns.jpg',
    'toor_dal': '$_p/toor_dal_sack.jpg',
    'oil': '$_p/groundnut_oil_tin.jpg',
    'dry_fruits': '$_p/dry_fruits.jpg',
    'eggs': '$_p/country_eggs.jpg',
    'paneer': '$_p/paneer_block.jpg',
  };

  static String? bucket(String? key) => key == null ? null : _bucket[key];

  /// Category ids used across the app (home grid, filters, create-bucket picker).
  static const categories = <(String id, String label)>[
    ('fish', 'Fish & Seafood'),
    ('meat', 'Meat'),
    ('fruits', 'Fruits'),
    ('vegetables', 'Vegetables'),
    ('staples', 'Staples'),
    ('dairy', 'Dairy & Eggs'),
    ('festive', 'Festive'),
    ('services', 'Home Services'),
  ];
  static String category(String id) => '$_c/cat_$id.jpg';

  static const banners = <String>['$_b/banner_kasimedu.jpg', '$_b/banner_mango.jpg', '$_b/banner_society.jpg'];
  static String onboarding(int i) => '$_o/onboard_$i.jpg';
}
