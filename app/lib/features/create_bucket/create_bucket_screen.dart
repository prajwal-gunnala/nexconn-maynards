import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/models/models.dart';
import '../../core/session/session_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import '../bucket/bucket_visuals.dart';
import '../orders/time_fmt.dart';
import 'bucket_draft.dart';
import 'draft_preview.dart';
import 'form_bits.dart';
import 'post_success.dart';
import 'step_one.dart';

/// Start a bucket: step 1 picks the type (or a template), step 2 fills the details with a live
/// chat-card preview, then POST /api/buckets and hand off to the bucket screen.
class CreateBucketScreen extends StatefulWidget {
  const CreateBucketScreen({super.key, this.clock});

  /// Fixed "now" for screenshots; defaults to the wall clock.
  final DateTime Function()? clock;

  @override
  State<CreateBucketScreen> createState() => _CreateBucketScreenState();
}

class _TierRow {
  _TierRow(int? min, int? price)
      : min = TextEditingController(text: min == null || min == 0 ? '' : '$min'),
        price = TextEditingController(text: price == null || price == 0 ? '' : '$price');
  final TextEditingController min;
  final TextEditingController price;
  void dispose() {
    min.dispose();
    price.dispose();
  }
}

class _ItemRow {
  _ItemRow(TripItemSeed? s)
      : name = TextEditingController(text: s?.name ?? ''),
        price = TextEditingController(text: s == null ? '' : '${s.price}'),
        unit = s?.unit ?? 'kg',
        retail = s?.retail,
        kgPerUnit = s?.kgPerUnit ?? 1;
  final TextEditingController name;
  final TextEditingController price;
  String unit;
  int? retail;
  double kgPerUnit;
  void dispose() {
    name.dispose();
    price.dispose();
  }
}

class _CreateBucketScreenState extends State<CreateBucketScreen> {
  DateTime get _now => widget.clock?.call() ?? DateTime.now();

  int _step = 0;
  DraftKind? _kind;
  DraftKind? _filledFor;

  // Basics
  final _title = TextEditingController();
  final _subtitle = TextEditingController();
  String _image = 'seer';
  String _category = 'fish';
  String? _vendorId;

  // Split
  final _weight = TextEditingController();
  String _preset = 'halves';
  int _customCount = 4;
  final _pricePerKg = TextEditingController();
  final _retail = TextEditingController();

  // Bulk / service
  String _unitLabel = 'kg';
  List<_TierRow> _tiers = [];
  final _minQty = TextEditingController();
  final _maxQty = TextEditingController();

  // Trip
  List<_ItemRow> _items = [];
  final _capacity = TextEditingController();
  final _transport = TextEditingController();

  // Money, time, place
  bool _atMarket = false;
  final _meetPlace = TextEditingController();
  DateTime? _meetAt;
  DateTime? _cutoff;
  String _pickup = 'Gate 2';

  Map<String, String> _errors = {};
  bool _posting = false;
  Bucket? _posted;

  final _scroll = ScrollController();
  final _kBasics = GlobalKey();
  final _kDetails = GlobalKey();
  final _kPay = GlobalKey();
  final _kWhen = GlobalKey();

  @override
  void dispose() {
    for (final c in [_title, _subtitle, _weight, _pricePerKg, _retail, _minQty, _maxQty, _capacity, _transport, _meetPlace]) {
      c.dispose();
    }
    for (final r in _tiers) {
      r.dispose();
    }
    for (final r in _items) {
      r.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  // ---- filling ------------------------------------------------------------------------------

  void _apply(DraftSeed s) {
    final now = _now;
    _kind = s.kind;
    _filledFor = s.kind;
    _title.text = s.title;
    _subtitle.text = s.subtitle;
    _image = s.image ?? switch (s.kind) {
      DraftKind.split => 'seer',
      DraftKind.bulk => 'basmati',
      DraftKind.service => 'pest',
      DraftKind.trip => 'koyambedu',
    };
    _category = s.category ?? 'fish';
    _vendorId = s.vendorId;
    _weight.text = s.weightKg;
    _preset = s.preset;
    _customCount = s.customCount;
    _pricePerKg.text = s.pricePerKg?.toString() ?? '';
    _retail.text = s.retail?.toString() ?? '';
    _unitLabel = s.unitLabel ?? (s.kind == DraftKind.service ? 'flat' : 'kg');
    for (final r in _tiers) {
      r.dispose();
    }
    _tiers = [for (final t in s.tiers) _TierRow(t.$1, t.$2)];
    _minQty.text = s.minQty?.toString() ?? '';
    _maxQty.text = s.maxQty?.toString() ?? '';
    for (final r in _items) {
      r.dispose();
    }
    _items = [for (final i in s.items) _ItemRow(i)];
    _capacity.text = s.capacity?.toString() ?? '';
    _transport.text = s.transportFee?.toString() ?? '';
    _atMarket = s.atMarket;
    _meetPlace.text = s.meetPlace;
    _meetAt = s.atMarket ? defaultMeetAt(now) : null;
    _cutoff = cutoffFor(s.cutoff, now, meetAt: _meetAt);
    _pickup = s.pickupPoint;
    _errors = {};
  }

  void _pickTemplate(BucketTemplate t) {
    HapticFeedback.selectionClick();
    setState(() {
      _apply(t.seed);
      _step = 1;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _continue() {
    final k = _kind;
    if (k == null) return;
    setState(() {
      if (_filledFor != k) _apply(DraftSeed.blank(k));
      _step = 1;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  // ---- derived ------------------------------------------------------------------------------

  int? _int(TextEditingController c) => int.tryParse(c.text.trim());
  double get _kg => double.tryParse(_weight.text.trim()) ?? 0;
  SharePreset get _sharePreset => SharePreset.byId(_preset);
  List<SplitPart> get _parts => splitParts(_sharePreset.labelsFor(_customCount), _kg, _int(_pricePerKg) ?? 0);
  String get _unit => _kind == DraftKind.split ? _sharePreset.unitLabel : (_kind == DraftKind.trip ? 'kg' : _unitLabel);

  List<(int, int)> get _validTiers {
    final out = <(int, int)>[];
    for (final r in _tiers) {
      final m = _int(r.min);
      final p = _int(r.price);
      if (m != null && m > 0 && p != null && p > 0) out.add((m, p));
    }
    out.sort((a, b) => a.$1.compareTo(b.$1));
    return out;
  }

  String get _streetName {
    final name = context.read<SessionStore>().community?.name ?? '';
    if (name.isEmpty) return 'your Street';
    final words = name.split(' ');
    const suffixes = {'Towers', 'Tower', 'Apartments', 'Residency', 'Enclave', 'Heights', 'Society', 'Homes'};
    if (words.length > 1 && suffixes.contains(words.last)) words.removeLast();
    return '${words.join(' ')} Street';
  }

  static String _plural(String unit, num n) {
    if (n == 1 || const {'kg', 'dozen', 'pc', 'litre', 'g'}.contains(unit)) return unit;
    if (unit == 'half') return 'halves';
    return '${unit}s';
  }

  PreviewData _preview() {
    final k = _kind ?? DraftKind.split;
    final session = context.read<SessionStore>();
    final vendor = VendorOption.byId(_vendorId);
    int? price;
    int? retail;
    String goal;
    String? hint;
    switch (k) {
      case DraftKind.split:
        final parts = _parts;
        final grams = parts.isEmpty ? 0 : parts.first.grams;
        price = parts.isEmpty || parts.first.price == 0 ? null : parts.first.price;
        final r = _int(_retail);
        retail = r == null || grams == 0 ? null : (grams / 1000 * r).round();
        goal = '0 of ${parts.length} ${_plural(_unit, parts.length)} taken';
        if (grams > 0) hint = 'About ${gramsLabel(grams)} each';
      case DraftKind.bulk || DraftKind.service:
        final t = _validTiers;
        price = t.isEmpty ? null : t.first.$2;
        retail = _int(_retail);
        goal = t.isEmpty ? 'Add a price tier' : '0 of ${t.first.$1} ${_plural(_unit, t.first.$1)} to go ahead';
        if (t.length > 1) hint = 'At ${t.last.$1} ${_plural(_unit, t.last.$1)} everyone pays ${Fmt.rupees(t.last.$2)}/$_unit';
      case DraftKind.trip:
        final cap = _int(_capacity) ?? 0;
        goal = '0 of $cap kg booked';
        final n = _items.where((i) => i.name.text.trim().isNotEmpty).length;
        final fee = _int(_transport) ?? 0;
        hint = '$n ${n == 1 ? 'item' : 'items'} on the list${fee > 0 && cap > 0 ? ' · transport about ${Fmt.rupees((fee / cap).ceil())}/kg when full' : ''}';
    }
    return PreviewData(
      kind: k,
      title: _title.text.trim(),
      subtitle: _subtitle.text.trim(),
      vendor: vendor?.name,
      image: _image,
      price: price,
      retail: retail,
      per: _unit,
      goal: goal,
      tierHint: hint,
      cutoffAt: _cutoff,
      atMarket: _atMarket,
      meetLine: _atMarket && _meetAt != null
          ? 'Meet at ${_meetPlace.text.trim().isEmpty ? 'the market' : _meetPlace.text.trim()} · ${dayTimeR(_meetAt!)}'
          : null,
      poster: session.user == null ? null : '${session.user!.name}${session.unit == null ? '' : ' · ${session.unit}'}',
    );
  }

  // ---- validation + post --------------------------------------------------------------------

  Map<String, String> _validate() {
    final e = <String, String>{};
    final now = _now;
    if (_title.text.trim().isEmpty) e['title'] = 'Give it a name neighbours will recognise.';
    switch (_kind!) {
      case DraftKind.split:
        if (_kg <= 0) e['weight'] = 'Enter the total weight.';
        if ((_int(_pricePerKg) ?? 0) <= 0) e['pricePerKg'] = 'Enter the price per kg.';
      case DraftKind.bulk || DraftKind.service:
        if (_tiers.isEmpty) e['tiers'] = 'Add at least one price tier.';
        final seen = <int>{};
        for (var i = 0; i < _tiers.length; i++) {
          final m = _int(_tiers[i].min);
          final p = _int(_tiers[i].price);
          if (m == null || m <= 0) e['tier_${i}_min'] = 'Qty?';
          if (p == null || p <= 0) e['tier_${i}_price'] = 'Price?';
          if (m != null && m > 0 && !seen.add(m)) e['tier_${i}_min'] = 'Repeated';
        }
        final t = _validTiers;
        for (var i = 1; i < t.length; i++) {
          if (t[i].$2 >= t[i - 1].$2) e['tiers'] = 'Prices should drop as the group buys more.';
        }
        final mn = _int(_minQty);
        final mx = _int(_maxQty);
        if (mn != null && mx != null && mx < mn) e['maxQty'] = 'Less than the minimum.';
      case DraftKind.trip:
        if (_items.isEmpty) e['items'] = 'Add at least one item to the list.';
        for (var i = 0; i < _items.length; i++) {
          if (_items[i].name.text.trim().isEmpty) e['item_${i}_name'] = 'Name?';
          if ((_int(_items[i].price) ?? 0) <= 0) e['item_${i}_price'] = 'Price?';
        }
        if ((_int(_capacity) ?? 0) <= 0) e['capacity'] = 'How much fits?';
    }
    if (_cutoff == null || !_cutoff!.isAfter(now)) e['cutoff'] = 'Pick a cutoff in the future.';
    if (_atMarket) {
      if (_meetPlace.text.trim().isEmpty) e['meetPlace'] = 'Where do you meet?';
      if (_meetAt == null || (_cutoff != null && !_meetAt!.isAfter(_cutoff!))) e['meetAt'] = 'Meet after the cutoff.';
    }
    return e;
  }

  GlobalKey _sectionFor(String errorKey) {
    if (errorKey == 'title') return _kBasics;
    if (errorKey == 'cutoff' || errorKey.startsWith('meet')) return errorKey == 'cutoff' ? _kWhen : _kPay;
    return _kDetails;
  }

  Json _draftJson(String communityId) {
    final k = _kind!;
    final meet = _meetPlace.text.trim();
    final j = <String, dynamic>{
      'communityId': communityId,
      'type': k.wire,
      'title': _title.text.trim(),
      'subtitle': _subtitle.text.trim(),
      'image': _image,
      'category': _category,
      'vendorId': ?_vendorId,
      'settleMode': _atMarket ? 'at_market' : 'hold',
      'cutoffAt': _cutoff!.toUtc().toIso8601String(),
      'pickupPoint': _atMarket ? meet : _pickup,
      'unitLabel': _unit,
      'retailUnitPrice': ?_int(_retail),
    };
    if (_atMarket) {
      j['meet'] = {'place': meet, 'at': _meetAt!.toUtc().toIso8601String()};
      j['deliverAt'] = _meetAt!.toUtc().toIso8601String();
    }
    switch (k) {
      case DraftKind.split:
        final parts = _parts;
        j['unitPrice'] = _int(_pricePerKg);
        j['netWeight'] = '${_weight.text.trim()} kg';
        j['serves'] = '${parts.length} families';
        j['units'] = [for (final p in parts) p.toJson()];
      case DraftKind.bulk || DraftKind.service:
        j['tiers'] = [for (final t in _validTiers) {'minQty': t.$1, 'unitPrice': t.$2}];
        j['minQty'] = _int(_minQty);
        j['maxQty'] = _int(_maxQty);
      case DraftKind.trip:
        final cap = _int(_capacity)!;
        j['capacity'] = cap;
        j['minLoadKg'] = (cap / 2).round();
        j['transportFee'] = _int(_transport) ?? 0;
        j['items'] = [
          for (var i = 0; i < _items.length; i++)
            {
              'id': _items[i].name.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
              'name': _items[i].name.text.trim(),
              'unit': _items[i].unit,
              'price': _int(_items[i].price),
              'kgPerUnit': _items[i].kgPerUnit,
              'retailPrice': _items[i].retail,
            },
        ];
    }
    return j;
  }

  Future<void> _post() async {
    FocusScope.of(context).unfocus();
    final errors = _validate();
    setState(() => _errors = errors);
    if (errors.isNotEmpty) {
      HapticFeedback.mediumImpact();
      final ctx = _sectionFor(errors.keys.first).currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic, alignment: 0.05);
      }
      return;
    }
    final session = context.read<SessionStore>();
    final api = context.read<ApiClient>();
    final messenger = ScaffoldMessenger.of(context);
    final communityId = session.community?.id;
    if (communityId == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Join a community before starting a bucket.')));
      return;
    }
    setState(() => _posting = true);
    try {
      final b = await api.createBucket(_draftJson(communityId));
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _posting = false;
        _posted = b;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // ---- pickers ------------------------------------------------------------------------------

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final now = _now;
    final d = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
    );
    if (d == null || !mounted) return null;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (t == null) return null;
    // Snap to :00 / :30 so every screen shows a time a person would pick.
    return roundHalfHour(DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _close() async {
    if (_step == 1 && _title.text.trim().isNotEmpty && _posted == null) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Discard this bucket?'),
          content: const Text('Nothing has been posted yet.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep editing')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Discard')),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/street');
    }
  }

  // ---- build --------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_posted != null) {
      final b = _posted!;
      final street = context.read<SessionStore>().streetChannelId;
      return PostSuccess(
        bucket: b,
        streetName: _streetName,
        onDone: () => context.go('/bucket/${b.id}'),
        onOpenChat: () => context.go('/chat/group/$street?title=${Uri.encodeComponent(_streetName)}'),
      );
    }
    return PopScope(
      canPop: _step == 0 && !_posting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step == 1 && !_posting) setState(() => _step = 0);
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            _header(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(a),
                    child: child,
                  ),
                ),
                child: _step == 0
                    ? StepOne(kind: _kind, onKind: (k) => setState(() => _kind = k), onTemplate: _pickTemplate)
                    : _stepTwo(),
              ),
            ),
          ]),
        ),
        bottomNavigationBar: StickyCta(
          child: _step == 0
              ? AppButton(
                  label: _kind == null ? 'Pick a type to continue' : 'Continue with ${_kind!.label}',
                  icon: _kind == null ? null : Icons.arrow_forward_rounded,
                  onPressed: _kind == null ? null : _continue,
                )
              : AppButton(
                  key: const Key('create-post'),
                  label: 'Post to $_streetName',
                  icon: Icons.send_rounded,
                  loading: _posting,
                  onPressed: _post,
                ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(4, 4, AppSpace.gutter, AppSpace.md),
      child: Column(children: [
        Row(children: [
          if (_step == 0)
            IconButton(onPressed: _close, tooltip: 'Close', icon: const Icon(Icons.close_rounded), style: IconButton.styleFrom(minimumSize: const Size(48, 48)))
          else
            IconButton(
              onPressed: _posting ? null : () => setState(() => _step = 0),
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_rounded),
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            ),
          const SizedBox(width: 4),
          Expanded(child: Text(_step == 0 ? 'New bucket' : 'Bucket details', style: AppText.heading.copyWith(fontSize: 18))),
          Text('Step ${_step + 1} of 2', style: AppText.label.copyWith(color: AppColors.inkMuted)),
        ]),
        const SizedBox(height: AppSpace.sm),
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(children: [
            for (var i = 0; i < 2; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= _step ? AppColors.brand : AppColors.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  // ---- step 2 -------------------------------------------------------------------------------

  void _touch() => setState(() {});

  void _clearError(String key) {
    if (_errors.containsKey(key)) setState(() => _errors = {..._errors}..remove(key));
  }

  Widget _stepTwo() {
    final k = _kind!;
    const gap = SizedBox(height: AppSpace.lg);
    return ListView(
      key: const Key('create-form'),
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(top: AppSpace.lg, bottom: AppSpace.xxxl),
      children: [
        _typeSummary(k),
        gap,
        KeyedSubtree(key: _kBasics, child: _basics()),
        gap,
        _vendor(),
        gap,
        KeyedSubtree(
          key: _kDetails,
          child: switch (k) {
            DraftKind.split => _splitSection(),
            DraftKind.bulk || DraftKind.service => _tierSection(k),
            DraftKind.trip => _tripSection(),
          },
        ),
        gap,
        KeyedSubtree(key: _kPay, child: _paySection()),
        gap,
        KeyedSubtree(key: _kWhen, child: _whenSection()),
        gap,
        _shareWith(),
        const SizedBox(height: AppSpace.xxl),
        Padding(
          key: const Key('draft-preview'),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(header: true, child: Text('How it looks in the chat', style: AppText.heading.copyWith(fontSize: 18))),
            const SizedBox(height: 2),
            Text('Updates live as you edit. Neighbours tap it to take a share.', style: AppText.caption),
            const SizedBox(height: AppSpace.md),
            DraftPreview(data: _preview(), now: _now),
          ]),
        ),
      ],
    );
  }

  Widget _typeSummary(DraftKind k) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(12)),
          child: Icon(k.icon, color: AppColors.brand, size: 22),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_atMarket ? '${k.label} · book and meet' : '${k.label} bucket', style: AppText.heading),
            Text(k.blurb, style: AppText.caption),
          ]),
        ),
        TextButton(
          onPressed: () => setState(() => _step = 0),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: AppColors.brandDeep),
          child: Text('Change', style: AppText.label.copyWith(color: AppColors.brandDeep)),
        ),
      ]),
    );
  }

  Widget _basics() {
    return FormSection(
      title: 'The basics',
      helper: 'What neighbours see first on the card.',
      children: [
        LabeledField(
          label: 'Title',
          controller: _title,
          hint: switch (_kind) {
            DraftKind.bulk => 'e.g. Aged Basmati Rice (1121)',
            DraftKind.service => 'e.g. Tower Pest Control',
            DraftKind.trip => 'e.g. Koyambedu Saturday Run',
            _ => 'e.g. Whole Seer (Vanjaram)',
          },
          error: _errors['title'],
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) {
            _clearError('title');
            _touch();
          },
        ),
        const SizedBox(height: AppSpace.md),
        LabeledField(
          label: 'One line about it (optional)',
          controller: _subtitle,
          hint: 'e.g. Landed 6:10 am at Kasimedu',
          maxLength: 80,
          onChanged: (_) => _touch(),
        ),
        const SizedBox(height: AppSpace.lg),
        Text('Photo', style: AppText.label.copyWith(color: AppColors.inkMuted)),
        const SizedBox(height: AppSpace.sm),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: draftPhotos.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.sm),
            itemBuilder: (_, i) {
              final key = draftPhotos[i];
              final on = key == _image;
              return Semantics(
                button: true,
                selected: on,
                label: 'Photo ${key.replaceAll('_', ' ')}',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => setState(() => _image = key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 72,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: on ? AppColors.brand : Colors.transparent, width: 2),
                    ),
                    child: BucketPhoto(visual: BucketVisual.of(key), height: 62),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Text('Category', style: AppText.label.copyWith(color: AppColors.inkMuted)),
        const SizedBox(height: 4),
        PillWrap(children: [
          for (final (id, label) in draftCategories)
            ChoicePill(label: label, selected: _category == id, onTap: () => setState(() => _category = id)),
        ]),
      ],
    );
  }

  Widget _vendor() {
    final mine = _vendorId == null;
    return FormSection(
      title: "Who's selling?",
      helper: mine
          ? 'You buy it and hand it over at the pickup point.'
          : 'The vendor joins the order group and gets the packing list.',
      children: [
        PillWrap(children: [
          ChoicePill(
            label: "I'll buy it myself",
            icon: Icons.directions_walk_rounded,
            selected: mine,
            onTap: () => setState(() => _vendorId = null),
          ),
          for (final v in VendorOption.all)
            ChoicePill(
              label: v.name,
              icon: Icons.storefront_outlined,
              selected: _vendorId == v.id,
              onTap: () => setState(() => _vendorId = v.id),
            ),
        ]),
      ],
    );
  }

  Widget _splitSection() {
    final parts = _parts;
    final retail = _int(_retail);
    final price = _int(_pricePerKg) ?? 0;
    final save = parts.isEmpty || retail == null || retail <= price ? 0 : ((retail - price) * parts.first.grams / 1000).round();
    return FormSection(
      title: 'Total and shares',
      helper: 'Cut into equal parts by weight. Each neighbour claims one or more.',
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: LabeledField(
              label: 'Total weight',
              controller: _weight,
              hint: '5.2',
              suffix: 'kg',
              number: true,
              decimal: true,
              error: _errors['weight'],
              onChanged: (_) {
                _clearError('weight');
                _touch();
              },
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Each ${_sharePreset.unitLabel}', style: AppText.label.copyWith(color: AppColors.inkMuted)),
              const SizedBox(height: 6),
              Container(
                height: 48,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  parts.isEmpty || parts.first.grams == 0
                      ? '—'
                      : '${gramsLabel(parts.first.grams)}${parts.first.price > 0 ? ' · ${Fmt.rupees(parts.first.price)}' : ''}',
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: AppSpace.lg),
        Text('Cut into', style: AppText.label.copyWith(color: AppColors.inkMuted)),
        const SizedBox(height: 4),
        PillWrap(children: [
          for (final p in SharePreset.all)
            ChoicePill(label: p.label, selected: _preset == p.id, onTap: () => setState(() => _preset = p.id)),
        ]),
        if (_preset == 'custom') ...[
          const SizedBox(height: AppSpace.sm),
          Row(children: [
            Expanded(child: Text('Number of shares', style: AppText.body)),
            RoundIconButton(
              icon: Icons.remove_circle_outline,
              semantic: 'Fewer shares',
              onTap: _customCount > 2 ? () => setState(() => _customCount--) : null,
            ),
            SizedBox(
              width: 32,
              child: Text('$_customCount', textAlign: TextAlign.center, style: AppText.heading.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            ),
            RoundIconButton(
              icon: Icons.add_circle_outline,
              semantic: 'More shares',
              color: AppColors.brand,
              onTap: _customCount < 20 ? () => setState(() => _customCount++) : null,
            ),
          ]),
        ],
        const SizedBox(height: AppSpace.md),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final p in parts)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: p.label, style: AppText.tiny.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700)),
                if (p.grams > 0) TextSpan(text: '  ${gramsLabel(p.grams)}', style: AppText.tiny),
                if (p.price > 0) TextSpan(text: '  ${Fmt.rupees(p.price)}', style: AppText.tiny.copyWith(color: AppColors.brandDeep)),
              ])),
            ),
        ]),
        const SizedBox(height: AppSpace.lg),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: LabeledField(
              label: 'Price per kg',
              controller: _pricePerKg,
              hint: '950',
              prefix: '₹ ',
              suffix: '/kg',
              number: true,
              error: _errors['pricePerKg'],
              onChanged: (_) {
                _clearError('pricePerKg');
                _touch();
              },
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: LabeledField(
              label: 'Shop price',
              controller: _retail,
              hint: '1400',
              prefix: '₹ ',
              suffix: '/kg',
              number: true,
              onChanged: (_) => _touch(),
            ),
          ),
        ]),
        if (save > 0) ...[
          const SizedBox(height: AppSpace.md),
          _savingsNote('Each ${_sharePreset.unitLabel} saves a neighbour about ${Fmt.rupees(save)} on the shop price.'),
        ],
      ],
    );
  }

  Widget _savingsNote(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 10),
        decoration: BoxDecoration(color: AppColors.saveTint, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.savings_outlined, size: 18, color: AppColors.save),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text(text, style: AppText.caption.copyWith(color: AppColors.save, fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _tierSection(DraftKind k) {
    final units = k == DraftKind.service ? const ['flat', 'villa', 'visit'] : const ['kg', 'dozen', 'bag', 'litre'];
    final u = _unitLabel;
    final t = _validTiers;
    final retail = _int(_retail);
    final best = t.isEmpty ? null : t.last.$2;
    const tab = [FontFeature.tabularFigures()];
    InputDecoration deco(String? err, {String? prefix, String? suffix, String? hint}) => InputDecoration(
          isDense: true,
          errorText: err,
          hintText: hint,
          prefixText: prefix,
          prefixStyle: AppText.body.copyWith(fontWeight: FontWeight.w700),
          suffixText: suffix,
          suffixStyle: AppText.bodyMuted,
        );
    return FormSection(
      title: k == DraftKind.service ? 'Price per $u' : 'Price tiers',
      helper: 'Everyone pays the tier the group reaches at the cutoff.',
      children: [
        Text('Sold per', style: AppText.label.copyWith(color: AppColors.inkMuted)),
        const SizedBox(height: 4),
        PillWrap(children: [
          for (final x in units) ChoicePill(label: x, selected: u == x, onTap: () => setState(() => _unitLabel = x)),
        ]),
        const SizedBox(height: AppSpace.md),
        Row(children: [
          Expanded(child: Text('When the group reaches', style: AppText.caption)),
          const SizedBox(width: 28),
          Expanded(child: Text('Everyone pays', style: AppText.caption)),
          const SizedBox(width: 48),
        ]),
        const SizedBox(height: 6),
        for (var i = 0; i < _tiers.length; i++)
          Padding(
            key: ObjectKey(_tiers[i]),
            padding: const EdgeInsets.only(bottom: AppSpace.sm),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: TextField(
                  controller: _tiers[i].min,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700, fontFeatures: tab),
                  decoration: deco(_errors['tier_${i}_min'], suffix: _plural(u, 2), hint: '25'),
                  onChanged: (_) {
                    _clearError('tier_${i}_min');
                    _clearError('tiers');
                    _touch();
                  },
                ),
              ),
              const SizedBox(
                width: 28,
                height: 48,
                child: Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.inkMuted),
              ),
              Expanded(
                child: TextField(
                  controller: _tiers[i].price,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700, fontFeatures: tab),
                  decoration: deco(_errors['tier_${i}_price'], prefix: '₹ ', suffix: '/$u', hint: '96'),
                  onChanged: (_) {
                    _clearError('tier_${i}_price');
                    _clearError('tiers');
                    _touch();
                  },
                ),
              ),
              RoundIconButton(
                icon: Icons.delete_outline_rounded,
                semantic: 'Remove tier ${i + 1}',
                onTap: _tiers.length > 1
                    ? () => setState(() {
                          _tiers.removeAt(i).dispose();
                          _errors = {};
                        })
                    : null,
              ),
            ]),
          ),
        if (_errors['tiers'] != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.sm),
            child: Text(_errors['tiers']!, style: AppText.caption.copyWith(color: AppColors.danger)),
          ),
        AddRowButton(
          label: 'Add tier',
          onTap: _tiers.length >= 5
              ? null
              : () => setState(() {
                    final last = _validTiers.isEmpty ? null : _validTiers.last;
                    _tiers.add(_TierRow(last == null ? null : last.$1 * 2, null));
                  }),
        ),
        const SizedBox(height: AppSpace.lg),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: LabeledField(
              label: 'Shop price',
              controller: _retail,
              hint: '135',
              prefix: '₹ ',
              suffix: '/$u',
              number: true,
              onChanged: (_) => _touch(),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: LabeledField(label: 'Min each', controller: _minQty, hint: '1', number: true, onChanged: (_) => _touch())),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: LabeledField(
                  label: 'Max each',
                  controller: _maxQty,
                  hint: 'Any',
                  number: true,
                  error: _errors['maxQty'],
                  onChanged: (_) {
                    _clearError('maxQty');
                    _touch();
                  },
                ),
              ),
            ]),
          ),
        ]),
        if (retail != null && best != null && retail > best) ...[
          const SizedBox(height: AppSpace.md),
          _savingsNote('At the top tier neighbours save ${Fmt.rupees(retail - best)} per $u '
              '(${Fmt.savePercent(price: best, retail: retail)}% off the shop price).'),
        ],
      ],
    );
  }

  Widget _tripSection() {
    final cap = _int(_capacity) ?? 0;
    final fee = _int(_transport) ?? 0;
    const tab = [FontFeature.tabularFigures()];
    return FormSection(
      title: 'The shopping list',
      helper: 'Neighbours add quantities from this list. Transport is split by weight.',
      children: [
        for (var i = 0; i < _items.length; i++)
          Padding(
            key: ObjectKey(_items[i]),
            padding: const EdgeInsets.only(bottom: AppSpace.sm),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 5,
                child: TextField(
                  controller: _items[i].name,
                  textCapitalization: TextCapitalization.words,
                  style: AppText.body,
                  decoration: InputDecoration(isDense: true, hintText: 'Item', errorText: _errors['item_${i}_name']),
                  onChanged: (_) {
                    _clearError('item_${i}_name');
                    _touch();
                  },
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _items[i].price,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700, fontFeatures: tab),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '28',
                    errorText: _errors['item_${i}_price'],
                    prefixText: '₹ ',
                    prefixStyle: AppText.body.copyWith(fontWeight: FontWeight.w700),
                    suffixIcon: _unitMenu(_items[i]),
                    suffixIconConstraints: const BoxConstraints(minHeight: 40, minWidth: 40),
                  ),
                  onChanged: (_) {
                    _clearError('item_${i}_price');
                    _touch();
                  },
                ),
              ),
              RoundIconButton(
                icon: Icons.delete_outline_rounded,
                semantic: 'Remove ${_items[i].name.text}',
                onTap: _items.length > 1
                    ? () => setState(() {
                          _items.removeAt(i).dispose();
                          _errors = {};
                        })
                    : null,
              ),
            ]),
          ),
        if (_errors['items'] != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.sm),
            child: Text(_errors['items']!, style: AppText.caption.copyWith(color: AppColors.danger)),
          ),
        AddRowButton(
          label: 'Add an item',
          onTap: _items.length >= 15 ? null : () => setState(() => _items.add(_ItemRow(null))),
        ),
        const SizedBox(height: AppSpace.lg),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: LabeledField(
              label: 'Vehicle capacity',
              controller: _capacity,
              hint: '300',
              suffix: 'kg',
              number: true,
              error: _errors['capacity'],
              onChanged: (_) {
                _clearError('capacity');
                _touch();
              },
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: LabeledField(
              label: 'Transport fee',
              controller: _transport,
              hint: '1800',
              prefix: '₹ ',
              number: true,
              onChanged: (_) => _touch(),
            ),
          ),
        ]),
        if (cap > 0 && fee > 0) ...[
          const SizedBox(height: AppSpace.md),
          Text(
            'Goes ahead once ${(cap / 2).round()} kg is booked. Full load: about ${Fmt.rupees((fee / cap).ceil())} per kg for transport.',
            style: AppText.caption,
          ),
        ],
      ],
    );
  }

  Widget _unitMenu(_ItemRow row) {
    return PopupMenuButton<String>(
      tooltip: 'Unit',
      initialValue: row.unit,
      onSelected: (v) => setState(() {
        row.unit = v;
        row.kgPerUnit = switch (v) {
          'dozen' => 1.5,
          'pc' => 0.5,
          _ => 1,
        };
      }),
      itemBuilder: (_) => [for (final u in const ['kg', 'dozen', 'pc', 'bunch']) PopupMenuItem(value: u, child: Text('per $u'))],
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('/${row.unit}', style: AppText.bodyMuted),
          const Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.inkMuted),
        ]),
      ),
    );
  }

  Widget _paySection() {
    return FormSection(
      title: 'How do members pay?',
      children: [
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: _PayOption(
                key: const Key('pay-hold'),
                icon: Icons.lock_clock_outlined,
                title: 'Hold with UPI',
                body: 'Money is blocked now and taken only if the bucket fills.',
                selected: !_atMarket,
                onTap: () => setState(() => _atMarket = false),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: _PayOption(
                key: const Key('pay-market'),
                icon: Icons.storefront_outlined,
                title: 'Pay at the market',
                body: 'Members book now and pay the seller when you meet.',
                selected: _atMarket,
                onTap: () => setState(() {
                  _atMarket = true;
                  _meetAt ??= defaultMeetAt(_now);
                  if (_cutoff != null && !_meetAt!.isAfter(_cutoff!)) {
                    _cutoff = cutoffFor(CutoffPreset.beforeMeet, _now, meetAt: _meetAt);
                  }
                }),
              ),
            ),
          ]),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !_atMarket
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: AppSpace.lg),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    LabeledField(
                      label: 'Meet at',
                      controller: _meetPlace,
                      hint: 'e.g. Kasimedu, Gate 3',
                      error: _errors['meetPlace'],
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) {
                        _clearError('meetPlace');
                        _touch();
                      },
                    ),
                    const SizedBox(height: AppSpace.md),
                    PickerTile(
                      label: 'Meet time',
                      value: _meetAt == null ? 'Pick a time' : dayTimeR(_meetAt!),
                      icon: Icons.schedule_rounded,
                      error: _errors['meetAt'],
                      onTap: () async {
                        final v = await _pickDateTime(_meetAt ?? defaultMeetAt(_now));
                        if (v != null) {
                          setState(() {
                            _meetAt = v;
                            _errors = {..._errors}..remove('meetAt');
                          });
                        }
                      },
                    ),
                  ]),
                ),
        ),
      ],
    );
  }

  Widget _whenSection() {
    final now = _now;
    final presets = <(String, DateTime)>[
      ('In 3 hours', cutoffFor(CutoffPreset.inThreeHours, now)),
      ('Tonight 9 pm', cutoffFor(CutoffPreset.tonight, now)),
      ('Tomorrow 8 pm', cutoffFor(CutoffPreset.tomorrowEvening, now)),
      if (_atMarket && _meetAt != null) ('Night before', _meetAt!.subtract(const Duration(hours: 8))),
    ];
    return FormSection(
      title: 'Cutoff and pickup',
      helper: 'If it fills by the cutoff, it becomes an order. If not, every hold is released.',
      children: [
        PickerTile(
          label: 'Closes',
          value: _cutoff == null ? 'Pick a time' : dayTimeR(_cutoff!),
          hint: _cutoff == null ? null : Fmt.timeLeft(_cutoff!, now: now),
          icon: Icons.timer_outlined,
          error: _errors['cutoff'],
          onTap: () async {
            final v = await _pickDateTime(_cutoff ?? now.add(const Duration(hours: 3)));
            if (v != null) {
              setState(() {
                _cutoff = v;
                _errors = {..._errors}..remove('cutoff');
              });
            }
          },
        ),
        const SizedBox(height: AppSpace.sm),
        PillWrap(children: [
          for (final (label, t) in presets)
            ChoicePill(
              label: label,
              selected: _cutoff == t,
              onTap: () => setState(() {
                _cutoff = t;
                _errors = {..._errors}..remove('cutoff');
              }),
            ),
        ]),
        if (!_atMarket) ...[
          const SizedBox(height: AppSpace.lg),
          Text('Pickup point', style: AppText.label.copyWith(color: AppColors.inkMuted)),
          const SizedBox(height: 4),
          PillWrap(children: [
            for (final p in pickupPoints)
              ChoicePill(label: p, icon: Icons.place_outlined, selected: _pickup == p, onTap: () => setState(() => _pickup = p)),
          ]),
        ] else ...[
          const SizedBox(height: AppSpace.md),
          Row(children: [
            const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.inkMuted),
            const SizedBox(width: 6),
            Expanded(child: Text('Members collect at the meet point, so there is no separate pickup.', style: AppText.caption)),
          ]),
        ],
      ],
    );
  }

  Widget _shareWith() {
    final c = context.read<SessionStore>().community;
    final members = c?.stats?.members;
    return FormSection(
      title: 'Share with',
      children: [
        PillWrap(children: [
          ChoicePill(label: _streetName, icon: Icons.forum_outlined, selected: true, onTap: () {}),
        ]),
        const SizedBox(height: AppSpace.xs),
        Text(
          members == null
              ? 'The live card is posted in your Street chat.'
              : 'The live card is posted in your Street chat for all $members neighbours.',
          style: AppText.caption,
        ),
      ],
    );
  }
}

class _PayOption extends StatelessWidget {
  const _PayOption({super.key, required this.icon, required this.title, required this.body, required this.selected, required this.onTap});

  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $body',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandTint : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.brand : AppColors.line, width: selected ? 2 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 20, color: selected ? AppColors.brand : AppColors.inkMuted),
              const Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.brand : AppColors.surface,
                  border: Border.all(color: selected ? AppColors.brand : AppColors.line, width: 2),
                ),
                child: selected ? const Icon(Icons.check_rounded, size: 13, color: Colors.white) : null,
              ),
            ]),
            const SizedBox(height: AppSpace.sm),
            Text(title, style: AppText.label.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(body, style: AppText.caption),
          ]),
        ),
      ),
    );
  }
}
