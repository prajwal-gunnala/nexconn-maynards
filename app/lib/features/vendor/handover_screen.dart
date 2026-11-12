import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import 'vendor_models.dart';
import 'vendor_screen.dart' show PackLineRow, shortCommunityName;

/// Vendor at the gate: pick a buyer, type their 4-digit OTP, confirm.
/// `POST /api/orders/:id/handover {otp}` marks that line collected and
/// releases the payment.
class HandoverScreen extends StatefulWidget {
  const HandoverScreen({super.key, required this.orderId, this.communityName});

  final String orderId;
  final String? communityName;

  @override
  State<HandoverScreen> createState() => _HandoverScreenState();
}

class _HandoverScreenState extends State<HandoverScreen> {
  static const otpLength = 4;

  VendorOrder? _order;
  Object? _loadError;
  int? _selected;
  String _otp = '';
  String? _error;
  bool _busy = false;

  ApiClient get _api => context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = VendorOrder.fromJson(asJson(await _api.get('/api/orders/${widget.orderId}')) ?? const {});
      if (!mounted) return;
      setState(() {
        _order = o;
        _loadError = null;
        _selected = _firstOpen(o);
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  static int? _firstOpen(VendorOrder o) {
    final i = o.lines.indexWhere((l) => !l.collected);
    return i < 0 ? null : i;
  }

  void _key(String k) {
    if (_busy) return;
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      if (k == '<') {
        if (_otp.isNotEmpty) _otp = _otp.substring(0, _otp.length - 1);
      } else if (k == 'C') {
        _otp = '';
      } else if (_otp.length < otpLength) {
        _otp += k;
      }
    });
  }

  Future<void> _confirm() async {
    final o = _order;
    if (o == null || _otp.length != otpLength || _busy) return;
    final before = o.lines;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = asJson(await _api.post('/api/orders/${o.id}/handover', {'otp': _otp}));
      final updated = VendorOrder.fromJson(asJson(res?['order']) ?? const {});
      if (!mounted) return;
      // Which line just turned collected (the OTP may belong to another buyer than the one selected).
      PackLine? who;
      for (var i = 0; i < updated.lines.length && i < before.length; i++) {
        if (updated.lines[i].collected && !before[i].collected) who = updated.lines[i];
      }
      HapticFeedback.mediumImpact();
      setState(() {
        _order = updated;
        _otp = '';
        _selected = _firstOpen(updated);
      });
      final line = who;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(line == null
            ? 'Handed over'
            : line.payMode == PayMode.atMarket
                ? 'Handed to ${line.name} · collect ${Fmt.rupees(line.amount)}'
                : 'Handed to ${line.name} · ${Fmt.rupees(line.amount)} released'),
      ));
    } on ApiException catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _error = e.message;
          _otp = '';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    final place = [
      o?.pickupPoint,
      if (widget.communityName != null) shortCommunityName(widget.communityName!),
    ].whereType<String>().join(' · ');
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(place.isEmpty ? 'Handover' : place, style: AppText.heading),
          Text(o == null ? widget.orderId : '${o.title} · ${o.id}', style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
      body: _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.xxl),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    _loadError is ApiException ? (_loadError as ApiException).message : 'Couldn’t load this order.',
                    style: AppText.body,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  AppButton.ghost(label: 'Try again', expand: false, onPressed: _load),
                ]),
              ),
            )
          : o == null
              ? const Center(child: CircularProgressIndicator())
              : Column(children: [
                  _Summary(order: o),
                  Expanded(
                    child: ListView(padding: const EdgeInsets.only(bottom: AppSpace.md), children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.md, AppSpace.gutter, AppSpace.sm),
                        child: Text('Pick the buyer at the gate', style: AppText.label.copyWith(color: AppColors.inkMuted)),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadius.cardBorder,
                          border: Border.all(color: AppColors.line),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(children: [
                          for (var i = 0; i < o.lines.length; i++) ...[
                            if (i > 0) const Divider(height: 1),
                            PackLineRow(
                              line: o.lines[i],
                              selected: _selected == i,
                              onTap: o.lines[i].collected
                                  ? null
                                  : () => setState(() {
                                        _selected = i;
                                        _otp = '';
                                        _error = null;
                                      }),
                            ),
                          ],
                        ]),
                      ),
                    ]),
                  ),
                  if (o.allCollected) _AllDone(order: o) else _OtpPanel(
                    line: _selected == null ? null : o.lines[_selected!],
                    otp: _otp,
                    length: otpLength,
                    error: _error,
                    busy: _busy,
                    onKey: _key,
                    onConfirm: _confirm,
                  ),
                ]),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.order});
  final VendorOrder order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.md, AppSpace.gutter, AppSpace.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '${o.collectedCount}', style: AppText.priceLarge),
              TextSpan(text: ' of ${o.lines.length} collected', style: AppText.body),
            ])),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(Fmt.rupees(o.releasedAmount), style: AppText.price.copyWith(color: AppColors.save)),
            Text('released to you', style: AppText.tiny),
          ]),
        ]),
        const SizedBox(height: AppSpace.sm),
        AppProgressBar(value: o.lines.isEmpty ? 0 : o.collectedCount / o.lines.length, color: AppColors.save),
        if (o.window != null) ...[
          const SizedBox(height: AppSpace.sm),
          Row(children: [
            const Icon(Icons.schedule_rounded, size: 14, color: AppColors.inkMuted),
            const SizedBox(width: AppSpace.xs),
            Text(o.window!, style: AppText.caption),
          ]),
        ],
      ]),
    );
  }
}

class _OtpPanel extends StatelessWidget {
  const _OtpPanel({
    required this.line,
    required this.otp,
    required this.length,
    required this.error,
    required this.busy,
    required this.onKey,
    required this.onConfirm,
  });

  final PackLine? line;
  final String otp;
  final int length;
  final String? error;
  final bool busy;
  final ValueChanged<String> onKey;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l = line;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.md, AppSpace.gutter, AppSpace.md),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              l == null ? 'Enter the buyer’s OTP' : '${l.unit ?? ''} · ${l.name} · ${l.qtyLabel}'.replaceFirst(RegExp(r'^ · '), ''),
              style: AppText.label,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.sm),
            Semantics(
              label: 'OTP, ${otp.length} of $length digits entered',
              liveRegion: true,
              excludeSemantics: true,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < length; i++)
                  Container(
                    width: 52,
                    height: 56,
                    margin: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: error != null
                            ? AppColors.danger
                            : i == otp.length
                                ? AppColors.brand
                                : AppColors.line,
                        width: i == otp.length || error != null ? 1.5 : 1,
                      ),
                    ),
                    child: Text(i < otp.length ? otp[i] : '', style: AppText.display.copyWith(fontSize: 26)),
                  ),
              ]),
            ),
            SizedBox(
              height: 28,
              child: Center(
                child: error == null
                    ? Text('Ask the buyer for the code in their Jugaad Street chat', style: AppText.tiny)
                    : Semantics(
                        liveRegion: true,
                        child: Text(error!, style: AppText.caption.copyWith(color: AppColors.danger, fontWeight: FontWeight.w600)),
                      ),
              ),
            ),
            _Keypad(onKey: onKey),
            const SizedBox(height: AppSpace.md),
            AppButton(
              label: 'Confirm handover',
              icon: Icons.check_rounded,
              loading: busy,
              onPressed: otp.length == length ? onConfirm : null,
            ),
          ]),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey});
  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', '<'],
    ];
    return Column(children: [
      for (final r in rows)
        Row(children: [
          for (final k in r)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Semantics(
                  button: true,
                  label: k == '<' ? 'Delete' : k == 'C' ? 'Clear' : k,
                  excludeSemantics: true,
                  child: Material(
                    color: k == 'C' || k == '<' ? AppColors.surface : AppColors.canvas,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onKey(k),
                      child: SizedBox(
                        height: 50,
                        child: Center(
                          child: k == '<'
                              ? const Icon(Icons.backspace_outlined, color: AppColors.ink)
                              : Text(
                                  k == 'C' ? 'Clear' : k,
                                  style: k == 'C' ? AppText.label : AppText.title.copyWith(fontSize: 22),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
    ]);
  }
}

class _AllDone extends StatelessWidget {
  const _AllDone({required this.order});
  final VendorOrder order;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.gutter),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.verified_rounded, color: AppColors.save, size: 40),
              const SizedBox(height: AppSpace.sm),
              Text('Everyone has collected', style: AppText.heading),
              const SizedBox(height: AppSpace.xs),
              Text('${Fmt.rupees(order.releasedAmount)} released for ${order.id}', style: AppText.bodyMuted),
              const SizedBox(height: AppSpace.lg),
              AppButton(label: 'Back to today', onPressed: () => Navigator.of(context).maybePop()),
            ]),
          ),
        ),
      );
}
