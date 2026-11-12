import 'package:flutter/material.dart';
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
import '../bucket/detail_model.dart';
import '../bucket/detail_widgets.dart';
import 'hold_draft.dart';
import 'hold_success.dart';
import 'upi_pin_pad.dart';

enum _Phase { creating, pin, success, booked, failed }

/// `/bucket/:id/hold`: creates the share, then a UPI Reserve sheet with a PIN
/// pad (hold buckets) or a "Booked" confirmation (book-and-meet buckets).
class HoldScreen extends StatefulWidget {
  const HoldScreen({super.key, required this.bucketId, this.request, this.initialPin = ''});

  final String bucketId;

  /// The member's pick. Defaults to what the detail screen left in [HoldRequest].
  final HoldRequest? request;

  /// Pre-filled PIN digits (screenshots only).
  final String initialPin;

  @override
  State<HoldScreen> createState() => _HoldScreenState();
}

class _HoldScreenState extends State<HoldScreen> {
  _Phase _phase = _Phase.creating;
  HoldRequest? _req;
  Share? _share;
  BucketView? _after;
  String? _failure;
  String _pin = '';
  String? _pinError;
  int _shake = 0;
  bool _authorizing = false;
  late String _vpa;

  ApiClient get _api => context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    final name = context.read<SessionStore>().user?.name ?? 'me';
    _vpa = '${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9.]'), '')}@okaxis';
    _pin = widget.initialPin;
    _req = widget.request ?? HoldRequest.take(widget.bucketId);
    _start();
  }

  Future<void> _start() async {
    var req = _req;
    if (req == null) {
      // Opened directly (deep link / restored route): resume a pending share if there is one.
      try {
        final raw = await _api.get('/api/buckets/${widget.bucketId}');
        final v = BucketView.fromJson(asJson(raw) ?? const {});
        final my = v.bucket.myShare;
        if (my != null && my.status == ShareStatus.pendingPayment) {
          req = HoldRequest(view: v, draft: const JoinDraft(), pendingShare: my);
        } else {
          _fail('Pick your share on the bucket page first.');
          return;
        }
      } on ApiException catch (e) {
        _fail(e.message);
        return;
      }
      if (!mounted) return;
      setState(() => _req = req);
    }
    if (req.pendingShare != null) {
      _onShare(req.pendingShare!, null);
      return;
    }
    final b = req.view.bucket;
    final d = req.draft;
    try {
      final r = await _api.addShare(
        b.id,
        payMode: b.settleMode,
        unitIds: b.type == BucketType.split ? d.unitIds : null,
        qty: b.type == BucketType.bulk || b.type == BucketType.service ? d.qty : null,
        items: b.type == BucketType.trip
            ? [for (final e in d.items.entries) if (e.value > 0) {'id': e.key, 'qty': e.value}]
            : null,
        options: d.options.isEmpty ? null : d.options,
      );
      if (!mounted) return;
      if (r.share == null) {
        _fail('The server did not return your share. Try again.');
        return;
      }
      _onShare(r.share!, r.bucket);
    } on ApiException catch (e) {
      _fail(e.message);
    }
  }

  void _onShare(Share s, Bucket? b) {
    if (!mounted) return;
    setState(() {
      _share = s;
      if (b != null) _after = BucketView(b, _req!.view.x);
      _phase = s.status == ShareStatus.booked || s.payMode == PayMode.atMarket ? _Phase.booked : _Phase.pin;
    });
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() {
      _failure = msg;
      _phase = _Phase.failed;
    });
  }

  // ---- PIN ---------------------------------------------------------------------------------

  void _digit(String d) {
    if (_pin.length >= 6 || _authorizing) return;
    setState(() {
      _pin += d;
      _pinError = null;
    });
    if (_pin.length == 6) _authorize();
  }

  void _delete() {
    if (_pin.isEmpty || _authorizing) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _pinError = null;
    });
  }

  Future<void> _authorize() async {
    final hold = _share?.hold;
    if (hold == null || _pin.length < 4) return;
    setState(() => _authorizing = true);
    try {
      final r = await _api.authorizeHold(hold.id, vpa: _vpa, pin: _pin);
      if (!mounted) return;
      setState(() {
        _share = r.share ?? _share;
        if (r.bucket != null) _after = BucketView(r.bucket!, _req!.view.x);
        _phase = _Phase.success;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _pinError = e.message;
        _pin = '';
        _shake++;
      });
    } finally {
      if (mounted) setState(() => _authorizing = false);
    }
  }

  Future<void> _editVpa() async {
    final ctrl = TextEditingController(text: _vpa);
    final v = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pay from'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'name@okaxis', labelText: 'UPI ID'),
          onSubmitted: (s) => Navigator.pop(context, s),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Use this UPI ID')),
        ],
      ),
    );
    if (v != null && v.trim().isNotEmpty && mounted) setState(() => _vpa = v.trim());
  }

  /// Leaving before authorizing frees the part for neighbours straight away.
  Future<void> _cancel() async {
    final s = _share;
    if (_phase == _Phase.pin && s != null && s.status == ShareStatus.pendingPayment && _req?.pendingShare == null) {
      try {
        await _api.delete('/api/shares/${s.id}');
      } catch (_) {
        // The server releases unpaid shares after 15 minutes anyway.
      }
    }
    if (mounted) _close();
  }

  void _close() => context.canPop() ? context.pop() : context.go('/bucket/${widget.bucketId}');

  // ---- build -------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final req = _req;
    final Widget body = switch (_phase) {
      _Phase.creating || _Phase.pin when req != null => _upi(req),
      _Phase.creating => const Center(child: CircularProgressIndicator()),
      _Phase.failed => _failed(),
      _Phase.success => HoldSuccessView(
          view: _after ?? req!.view,
          share: _share!,
          vpa: _vpa,
        ),
      _Phase.booked => BookedView(
          view: _after ?? req!.view,
          share: _share!,
        ),
      _ => const SizedBox.shrink(),
    };
    return PopScope(
      canPop: _phase != _Phase.pin,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        child: KeyedSubtree(key: ValueKey(_phase == _Phase.creating ? _Phase.pin : _phase), child: body),
      ),
    );
  }

  Widget _failed() {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'Close', onPressed: _close)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: AppColors.brandTint, shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, size: 34, color: AppColors.brandDeep),
            ),
            const SizedBox(height: AppSpace.lg),
            Text("Couldn't reserve your share", style: AppText.title, textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.sm),
            Text(_failure ?? 'Something went wrong.', style: AppText.bodyMuted, textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.xs),
            Text('No money was blocked.', style: AppText.label.copyWith(color: AppColors.save)),
            const SizedBox(height: AppSpace.xxl),
            AppButton(label: 'Back to the bucket', onPressed: _close, expand: false),
          ]),
        ),
      ),
    );
  }

  Widget _upi(HoldRequest req) {
    final v = req.view;
    final b = v.bucket;
    final pr = Pricing(v);
    final amount = _share?.hold?.amount ?? _share?.estAmount ?? pr.quote(req.draft);
    final unit = b.unitLabel ?? 'unit';
    final what = switch (b.type) {
      BucketType.split => b.units.where((u) => req.draft.unitIds.contains(u.id)).map((u) => u.label).join(' + '),
      BucketType.trip => '${fmtQty(pr.kgOf(req.draft.items))} kg on the list',
      _ => plural(req.draft.qty ?? 0, unit),
    };
    final shareLabel = _share == null ? what : (what.isEmpty ? plural(_share!.qty, unit) : what);

    // Step 2 copy: the price can only go down.
    String paidLine = 'Only if the bucket fills';
    if (b.type == BucketType.bulk || b.type == BucketType.service) {
      final q = _share?.qty.round() ?? req.draft.qty ?? 0;
      final next = pr.nextTierAfter(b.progress.filled + q);
      paidLine = next == null
          ? '${Fmt.rupees(amount)} at the best tier, only if it goes ahead'
          : '${Fmt.rupees(q * next.unitPrice)} if ${plural(next.minQty, unit)} is reached, ${Fmt.rupees(amount)} if not';
    } else if (b.type == BucketType.trip) {
      paidLine = 'Transport share drops as the tempo fills';
    } else if (b.type == BucketType.split) {
      paidLine = '${Fmt.rupees(amount)}, only once every ${b.unitLabel ?? 'part'} is taken';
    }
    final releaseLine = b.cutoffAt == null ? 'Automatically, at the cutoff' : 'Automatically, ${shortWhen(b.cutoffAt!)}';
    final ready = _phase == _Phase.pin && _share?.hold != null;

    return Scaffold(
      backgroundColor: const Color(0xFF2A2421),
      body: Column(children: [
        // Dimmed summary of what is being held.
        Expanded(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.sm, AppSpace.xs, AppSpace.gutter, AppSpace.lg),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                IconButton(
                  onPressed: _cancel,
                  tooltip: 'Cancel',
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(left: AppSpace.sm),
                  child: Row(children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: BucketPhoto(visual: BucketVisual.of(b.image ?? b.category ?? b.title), url: b.image, height: 64),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(b.title, style: AppText.heading.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          [shareLabel, b.vendor?.name].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                          style: AppText.caption.copyWith(color: Colors.white.withValues(alpha: 0.7)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ]),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        // The UPI Reserve sheet.
        Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.md, AppSpace.xl, AppSpace.md),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: AppSpace.lg),
                Row(children: [
                  Expanded(child: LiveText('Hold ${Fmt.rupees(amount)}', style: AppText.title.copyWith(fontSize: 24))),
                  const StatusPill('UPI Reserve', tone: PillTone.held, icon: Icons.lock_clock_outlined),
                ]),
                const SizedBox(height: AppSpace.lg),
                const _Step(n: '1', title: 'Held in your bank now', sub: 'Still your money. Nothing is paid yet.', on: true),
                _Step(n: '2', title: 'Paid at the final price', sub: paidLine),
                _Step(n: '3', title: "Released if the bucket doesn't fill", sub: releaseLine, last: true),
                const Divider(height: AppSpace.xl),
                Semantics(
                  button: true,
                  label: 'Pay from $_vpa. Tap to change',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: _editVpa,
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 48,
                      child: Row(children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.account_balance_outlined, size: 20, color: AppColors.ink),
                        ),
                        const SizedBox(width: AppSpace.md),
                        Text('From', style: AppText.label.copyWith(color: AppColors.inkMuted)),
                        const SizedBox(width: AppSpace.sm),
                        Expanded(child: Text(_vpa, style: AppText.label.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                        Text('Change', style: AppText.label.copyWith(color: AppColors.brand)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                Center(
                  child: Text(
                    _authorizing ? 'Authorizing with your bank…' : 'Enter your 6-digit UPI PIN',
                    style: AppText.label.copyWith(color: AppColors.inkMuted),
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                PinDots(length: _pin.length, error: _pinError != null, shakeKey: _shake),
                SizedBox(
                  height: 28,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _pinError == null
                          ? (_authorizing
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand))
                              : const SizedBox.shrink())
                          : Text(_pinError!, key: ValueKey(_pinError), style: AppText.label.copyWith(color: AppColors.danger)),
                    ),
                  ),
                ),
                PinPad(
                  enabled: ready && !_authorizing,
                  onDigit: _digit,
                  onDelete: _delete,
                  onSubmit: _pin.length >= 4 ? _authorize : null,
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.title, required this.sub, this.on = false, this.last = false});

  final String n;
  final String title;
  final String sub;
  final bool on;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? AppColors.held : AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: on ? AppColors.held : AppColors.line, width: 1.5),
            ),
            child: Text(n, style: AppText.tiny.copyWith(color: on ? Colors.white : AppColors.inkMuted, fontWeight: FontWeight.w800)),
          ),
          if (!last) Expanded(child: Container(width: 1.5, color: AppColors.line, margin: const EdgeInsets.symmetric(vertical: 2))),
        ]),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : AppSpace.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.label.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 1),
              Text(sub, style: AppText.caption.tab),
            ]),
          ),
        ),
      ]),
    );
  }
}
