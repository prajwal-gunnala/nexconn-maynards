import 'dart:async';
import 'dart:convert';

import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/images.dart';
import '../../core/models/bucket.dart';
import '../../core/nexconn/js_messages.dart';
import '../../core/nexconn/nexconn_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';

/// Builders to pass to `ChatPage(customMessageBubbleBuilders: jsBubbleBuilders)`.
final Map<MessageType, ChatMessageBubbleBuilder> jsBubbleBuilders = {
  MessageType.customMessage: (context, message, config) => JsMessageBubble(message: message),
};

/// Installs the Chat UI kit hooks (JUGAAD PATCH, see `jugaad_hooks.dart`):
/// `js:event` as a centred system row and readable previews for `js:*`.
/// The avatar hook is installed by the chat screens (it needs the directory).
void installJsKitHooks() {
  JugaadKitHooks.isSystemRow = (m) => jsTypeOf(m) == JsType.event;
  JugaadKitHooks.summary = jsPreviewText;
}

/// One-line preview for chat lists and reply quotes. Null for non-js messages.
String? jsPreviewText(Message m) {
  final type = jsTypeOf(m);
  if (type == null || !type.startsWith('js:')) return null;
  return jsPreviewFor(type, jsFields(m));
}

/// Preview text for a `js:*` type and its content fields.
String jsPreviewFor(String type, Map<String, String> f) {
  String? v(String k) => (f[k] ?? '').trim().isEmpty ? null : f[k]!.trim();
  return switch (type) {
    JsType.bucket => 'New bucket: ${v('title') ?? 'a group buy'}',
    JsType.event => _eventPreview(stripFlat(v('text') ?? 'Bucket update')),
    JsType.order => v('orderId') == null ? 'Order created' : 'Order ${v('orderId')} created',
    JsType.otp => 'Your pickup code',
    _ => 'New update',
  };
}

String _eventPreview(String text) {
  final u = splitUnlock(text);
  return u == null ? text : '${u.$2} unlocked! ${u.$1}';
}

/// "Ananya (B-1204) took 10 kg" → "Ananya took 10 kg" (list previews only).
String stripFlat(String text) => text.replaceAll(RegExp(r'\s\([A-Z]{1,2}-?\d{1,5}\)'), '');

/// Dispatches on the custom type (`js:bucket`, `js:event`, ...).
class JsMessageBubble extends StatelessWidget {
  const JsMessageBubble({super.key, required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final type = jsTypeOf(message);
    final f = jsFields(message);
    return switch (type) {
      JsType.bucket => BucketCardBubble(key: ValueKey('card-${message.messageId}'), message: message),
      JsType.event => JsEventPill(fields: f),
      JsType.order => JsOrderCard(fields: f),
      JsType.otp => JsOtpCard(fields: f),
      _ => const _Unknown(),
    };
  }
}

// ---- js:bucket ----------------------------------------------------------------------------------

/// The live `js:bucket` card. Seeds from the message's metadata (history
/// loads include it, possibly stale) overlaid with [NexconnService]'s cache,
/// and redraws on every `onMessageMetadataUpdated` for its messageId.
class BucketCardBubble extends StatefulWidget {
  const BucketCardBubble({super.key, required this.message});

  final Message message;

  @override
  State<BucketCardBubble> createState() => _BucketCardBubbleState();
}

class _BucketCardBubbleState extends State<BucketCardBubble> {
  late Map<String, String> _fields;
  late Map<String, String> _meta;
  StreamSubscription<MetadataUpdate>? _sub;
  Timer? _flashTimer;
  bool _flash = false;

  /// Unit price before a live tier change (shown struck through for a few seconds).
  int? _oldPrice;
  Timer? _priceTimer;

  NexconnService get _nx => context.read<NexconnService>();

  @override
  void initState() {
    super.initState();
    _seed();
  }

  @override
  void didUpdateWidget(covariant BucketCardBubble old) {
    super.didUpdateWidget(old);
    if (old.message.messageId != widget.message.messageId) {
      _sub?.cancel();
      _seed();
    }
  }

  void _seed() {
    _fields = jsFields(widget.message);
    _meta = _nx.metadataFor(widget.message);
    final id = widget.message.messageId;
    if (id != null) {
      _sub = _nx.watchMetadata(id).listen((u) {
        if (!mounted) return;
        final before = BucketCardData.from(_fields, _meta).progress?.unitPrice;
        final after = BucketCardData.from(_fields, u.metadata).progress?.unitPrice;
        setState(() {
          _meta = u.metadata;
          _flash = true;
          if (before != null && after != null && after < before) _oldPrice = before;
        });
        if (_oldPrice != null) {
          _priceTimer?.cancel();
          _priceTimer = Timer(const Duration(seconds: 6), () {
            if (mounted) setState(() => _oldPrice = null);
          });
        }
        _flashTimer?.cancel();
        _flashTimer = Timer(const Duration(milliseconds: 1400), () {
          if (mounted) setState(() => _flash = false);
        });
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _flashTimer?.cancel();
    _priceTimer?.cancel();
    super.dispose();
  }

  /// Dev-token spike only: long-press bumps `filled` with a client metadata write.
  Future<void> _devSetMetadata() async {
    final messenger = ScaffoldMessenger.of(context);
    final p = BucketCardData.from(_fields, _meta).progress;
    final code = await _nx.setMetadata(widget.message, {
      'p': '{"filled":${(p?.filled ?? 0) + 1},"target":${p?.target ?? 100}}',
      's': 'live',
    });
    messenger.showSnackBar(SnackBar(content: Text('Client setMetadata result: $code')));
  }

  @override
  Widget build(BuildContext context) {
    final card = BucketCardData.from(_fields, _meta);
    return BucketChatCard(
      data: card,
      meta: _meta,
      flash: _flash,
      oldPrice: _oldPrice,
      onTap: card.bucketId.isEmpty ? null : () => context.push('/bucket/${card.bucketId}'),
      onLongPress: kDebugMode && AppConfig.hasDevToken ? _devSetMetadata : null,
    );
  }
}

/// Visual of the `js:bucket` card (no Nexconn dependency, so it renders in goldens).
class BucketChatCard extends StatelessWidget {
  const BucketChatCard({
    super.key,
    required this.data,
    this.meta = const {},
    this.flash = false,
    this.oldPrice,
    this.onTap,
    this.onLongPress,
    this.width = 272,
  });

  final BucketCardData data;

  /// Raw metadata (for `goAt` and the split unit map).
  final Map<String, String> meta;

  /// Briefly true after a live update: brand border + "Updated" tag.
  final bool flash;

  /// Set right after a live tier drop: the price turns green with the old one struck through.
  final int? oldPrice;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double width;

  static String num_(num n) => n == n.roundToDouble() ? Fmt.number(n.round()) : n.toStringAsFixed(1);

  static String typeLabel(BucketType t) => switch (t) {
        BucketType.split => 'Split',
        BucketType.bulk => 'Bulk buy',
        BucketType.service => 'Service',
        BucketType.trip => 'Market trip',
        BucketType.unknown => 'Bucket',
      };

  static IconData typeIcon(BucketType t) => switch (t) {
        BucketType.split => Icons.pie_chart_outline_rounded,
        BucketType.bulk => Icons.inventory_2_outlined,
        BucketType.service => Icons.handyman_outlined,
        BucketType.trip => Icons.local_shipping_outlined,
        BucketType.unknown => Icons.shopping_basket_outlined,
      };

  static StatusPill statusPill(BucketStatus s) => switch (s) {
        BucketStatus.live => const StatusPill('Live', tone: PillTone.brand),
        BucketStatus.ordered => const StatusPill('Filled', tone: PillTone.captured, icon: Icons.check_circle_outline),
        BucketStatus.marketDay => const StatusPill('Market day', tone: PillTone.brand),
        BucketStatus.delivering => const StatusPill('Handing over', tone: PillTone.held),
        BucketStatus.completed => const StatusPill('Delivered', tone: PillTone.captured),
        BucketStatus.expired => const StatusPill('Expired', tone: PillTone.released),
        BucketStatus.cancelled => const StatusPill('Closed', tone: PillTone.released),
        BucketStatus.unknown => const StatusPill('Bucket'),
      };

  num? get _goAt {
    final raw = meta['p'];
    if (raw == null) return null;
    try {
      final v = jsonDecode(raw);
      return v is Map && v['goAt'] is num ? v['goAt'] as num : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = data;
    final p = c.progress;
    final unit = c.unitLabel ?? (c.type == BucketType.trip ? 'kg' : 'share');
    final open = c.status.isOpen;
    final goAt = _goAt;
    final String hint;
    final Color hintColor;
    if (p == null) {
      hint = 'Be the first to join';
      hintColor = AppColors.inkMuted;
    } else if (goAt != null && p.filled < goAt && c.type != BucketType.split) {
      hint = '${num_(goAt - p.filled)} $unit more to go ahead';
      hintColor = AppColors.brandDeep;
    } else if (p.nextTier != null) {
      hint = '${num_(p.nextTier!.remaining)} $unit more unlocks ${Fmt.rupees(p.nextTier!.unitPrice)}/$unit for all';
      hintColor = AppColors.save;
    } else if (c.type == BucketType.split && p.target > p.filled) {
      final left = p.target - p.filled;
      hint = '${num_(left)} ${left == 1 ? unit : '${unit}s'} still open';
      hintColor = AppColors.brandDeep;
    } else {
      hint = open ? 'Best price unlocked' : '${p.members} neighbours in';
      hintColor = AppColors.save;
    }

    return Semantics(
      button: onTap != null,
      label: '${typeLabel(c.type)} bucket: ${c.title}',
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: width,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: flash ? AppColors.brand : AppColors.line, width: flash ? 1.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.sm, AppSpace.sm, AppSpace.sm, 0),
              child: _photo(c),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.title, style: AppText.heading, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (c.subtitle != null || c.vendor != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    [c.vendor, c.subtitle].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                    style: AppText.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (p?.unitPrice != null) ...[
                  const SizedBox(height: AppSpace.sm),
                  _PriceLine(price: p!.unitPrice!, unit: unit, oldPrice: oldPrice),
                ],
                if (c.type == BucketType.split && c.units.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.sm),
                  _UnitDots(units: c.units),
                ],
                const SizedBox(height: AppSpace.md),
                AppProgressBar(value: p?.fraction ?? 0, color: open ? AppColors.brand : AppColors.save),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: Text(
                      p == null ? 'Nobody yet' : '${num_(p.filled)} of ${num_(p.target)} $unit · ${p.members} joined',
                      style: AppText.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (p != null)
                    Text('${p.percentRounded}%', style: AppText.label.copyWith(color: open ? AppColors.brand : AppColors.save)),
                ]),
                const SizedBox(height: AppSpace.xs),
                Text(hint, style: AppText.caption.copyWith(color: hintColor, fontWeight: FontWeight.w600)),
                if (c.cutoffAt != null && open) ...[
                  const SizedBox(height: AppSpace.sm),
                  Row(children: [
                    const Icon(Icons.schedule_rounded, size: 14, color: AppColors.inkMuted),
                    const SizedBox(width: AppSpace.xs),
                    Expanded(
                      child: Text(
                        'Closes ${Fmt.time(c.cutoffAt!)} · ${Fmt.timeLeft(c.cutoffAt!)}',
                        style: AppText.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ],
                const SizedBox(height: AppSpace.md),
                Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: open ? AppColors.brand : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: open ? null : Border.all(color: AppColors.line),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      open ? 'Join' : 'View bucket',
                      style: AppText.heading.copyWith(fontSize: 15, color: open ? Colors.white : AppColors.ink),
                    ),
                    const SizedBox(width: 6),
                    Icon(open ? Icons.add_rounded : Icons.chevron_right_rounded,
                        size: 20, color: open ? Colors.white : AppColors.ink),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _photo(BucketCardData c) {
    final asset = AppImages.bucket(c.image);
    final fallback = Container(
      color: AppColors.brandTint,
      alignment: Alignment.center,
      child: Icon(typeIcon(c.type), size: 44, color: AppColors.brandDeep.withValues(alpha: 0.6)),
    );
    return ClipRRect(
      borderRadius: AppRadius.photoBorder,
      child: SizedBox(
        height: 128,
        child: Stack(fit: StackFit.expand, children: [
          asset == null ? fallback : Image.asset(asset, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
          Positioned(
            left: AppSpace.sm,
            top: AppSpace.sm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.chip)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(typeIcon(c.type), size: 12, color: AppColors.ink),
                const SizedBox(width: AppSpace.xs),
                Text(typeLabel(c.type), style: AppText.tiny.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          Positioned(right: AppSpace.sm, top: AppSpace.sm, child: statusPill(c.status)),
          if (flash)
            Positioned(
              right: AppSpace.sm,
              bottom: AppSpace.sm,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 3),
                decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(AppRadius.chip)),
                child: Text('Just updated', style: AppText.tiny.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
        ]),
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.price, required this.unit, this.oldPrice});

  final int price;
  final String unit;
  final int? oldPrice;

  @override
  Widget build(BuildContext context) {
    final dropped = oldPrice != null && oldPrice! > price;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: EdgeInsets.symmetric(horizontal: dropped ? AppSpace.sm : 0, vertical: dropped ? AppSpace.xs : 0),
      decoration: BoxDecoration(
        color: dropped ? TierUnlockedPill.bg : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text.rich(TextSpan(children: [
          TextSpan(
            text: Fmt.rupees(price),
            style: AppText.price.copyWith(fontSize: 17, color: dropped ? TierUnlockedPill.fg : AppColors.ink),
          ),
          TextSpan(text: ' /$unit', style: AppText.caption.copyWith(color: dropped ? TierUnlockedPill.fg : null)),
        ])),
        if (dropped) ...[
          const SizedBox(width: AppSpace.sm),
          Text(
            Fmt.rupees(oldPrice!),
            style: AppText.caption.copyWith(decoration: TextDecoration.lineThrough, decorationColor: AppColors.inkMuted),
          ),
          const SizedBox(width: AppSpace.sm),
          const Icon(Icons.trending_down_rounded, size: 16, color: TierUnlockedPill.fg),
          const SizedBox(width: 2),
          Text('New price', style: AppText.tiny.copyWith(color: TierUnlockedPill.fg, fontWeight: FontWeight.w800)),
        ],
      ]),
    );
  }
}

/// Split buckets: one dot per cut/share, filled with the owner's initial.
class _UnitDots extends StatelessWidget {
  const _UnitDots({required this.units});

  final List<(String, String)> units;

  @override
  Widget build(BuildContext context) {
    final taken = units.where((u) => u.$2.isNotEmpty).length;
    return Semantics(
      label: '$taken of ${units.length} taken',
      excludeSemantics: true,
      child: Wrap(spacing: 4, runSpacing: 4, children: [
        for (final u in units)
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: u.$2.isEmpty ? AppColors.surface : AppColors.brandTint,
              border: Border.all(color: u.$2.isEmpty ? AppColors.inkMuted.withValues(alpha: 0.4) : AppColors.brand, width: 1.2),
            ),
            child: u.$2.isEmpty
                ? null
                : Text(u.$2, style: AppText.tiny.copyWith(color: AppColors.brandDeep, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
      ]),
    );
  }
}

// ---- js:event -----------------------------------------------------------------------------------

/// Centred system line: "Ananya (B-1204) took 10 kg".
/// `"Ananya (B-1204) took 8 kg and unlocked ₹88/kg for everyone!"` →
/// (`"Ananya (B-1204) took 8 kg"`, `"₹88/kg"`). Null when there is no unlock.
(String, String)? splitUnlock(String text) {
  final m = RegExp(r'^(.*?)[,\s]+and unlocked\s+(₹[\d,]+(?:/[^\s!.]+)?)', caseSensitive: false).firstMatch(text.trim());
  if (m == null) return null;
  return (m.group(1)!.trim(), m.group(2)!.trim());
}

class JsEventPill extends StatelessWidget {
  const JsEventPill({super.key, required this.fields});

  final Map<String, String> fields;

  @override
  Widget build(BuildContext context) {
    final unlock = splitUnlock(fields['text'] ?? '');
    if (unlock == null) return _pill(context, fields);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _pill(context, {...fields, 'text': unlock.$1}),
      const SizedBox(height: AppSpace.sm),
      TierUnlockedPill(price: unlock.$2, bucketId: fields['bucketId'] ?? ''),
    ]);
  }

  static Widget _pill(BuildContext context, Map<String, String> fields) {
    final kind = fields['kind'] ?? '';
    final (icon, color) = switch (kind) {
      'joined' => (Icons.add_circle_rounded, AppColors.save),
      'left' => (Icons.remove_circle_outline_rounded, AppColors.released),
      'locked' => (Icons.lock_rounded, AppColors.brand),
      'expired' => (Icons.hourglass_bottom_rounded, AppColors.released),
      'nudge' => (Icons.campaign_rounded, AppColors.held),
      'checkin' => (Icons.where_to_vote_rounded, AppColors.brand),
      _ => (Icons.info_outline_rounded, AppColors.inkMuted),
    };
    final tint = switch (kind) {
      'nudge' => AppColors.heldTint,
      'locked' => AppColors.brandTint,
      _ => null,
    };
    final bucketId = fields['bucketId'] ?? '';
    final text = (fields['text'] ?? '').trim().isEmpty ? 'Bucket update' : fields['text']!.trim();
    return Semantics(
      button: bucketId.isNotEmpty,
      child: GestureDetector(
        onTap: bucketId.isEmpty ? null : () => context.push('/bucket/$bucketId'),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320, minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 7),
          decoration: BoxDecoration(
            color: tint ?? AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tint ?? AppColors.line),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The best real-time moment: a join pushed the bucket to a cheaper tier.
class TierUnlockedPill extends StatelessWidget {
  const TierUnlockedPill({super.key, required this.price, this.bucketId = ''});

  /// `₹88/kg`
  final String price;
  final String bucketId;

  static const bg = Color(0xFFE8F5E9);
  static const fg = Color(0xFF1B5E20);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: bucketId.isNotEmpty,
      label: '$price unlocked for everyone',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: bucketId.isEmpty ? null : () => context.push('/bucket/$bucketId'),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.85, end: 1),
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320, minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: fg.withValues(alpha: 0.25)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.auto_awesome_rounded, size: 16, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: price, style: AppText.label.copyWith(color: fg, fontWeight: FontWeight.w800)),
                    TextSpan(text: ' unlocked for everyone', style: AppText.label.copyWith(color: fg)),
                  ]),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.trending_down_rounded, size: 18, color: fg),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---- js:order -----------------------------------------------------------------------------------

/// "Order JS-2041 created" card in the bucket group.
class JsOrderCard extends StatelessWidget {
  const JsOrderCard({super.key, required this.fields});

  final Map<String, String> fields;

  @override
  Widget build(BuildContext context) {
    final total = int.tryParse(fields['total'] ?? '');
    final members = int.tryParse(fields['members'] ?? '');
    final orderId = (fields['orderId'] ?? '').trim();
    return Semantics(
      button: orderId.isNotEmpty,
      label: 'Order ${orderId.isEmpty ? '' : orderId}',
      child: GestureDetector(
        onTap: orderId.isEmpty ? null : () => context.push('/orders/$orderId'),
        child: Container(
          width: 272,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: AppColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Container(
              color: AppColors.saveTint,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.save),
                const SizedBox(width: AppSpace.sm),
                Expanded(child: Text('Bucket filled · order placed', style: AppText.label.copyWith(color: AppColors.save))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(fields['title'] ?? 'Your order', style: AppText.heading, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpace.xs),
                Text(orderId.isEmpty ? 'Order' : 'Order $orderId', style: AppText.caption),
                const SizedBox(height: AppSpace.md),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Total', style: AppText.tiny),
                      Text(total == null ? '—' : Fmt.rupees(total), style: AppText.priceLarge.copyWith(fontSize: 22)),
                    ]),
                  ),
                  if (members != null)
                    StatusPill('$members neighbours', tone: PillTone.neutral, icon: Icons.groups_rounded),
                ]),
                const SizedBox(height: AppSpace.md),
                Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(12)),
                  child: Text('View order', style: AppText.heading.copyWith(fontSize: 15, color: AppColors.brandDeep)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---- js:otp -------------------------------------------------------------------------------------

/// Direct message from the bot with the member's pickup code.
class JsOtpCard extends StatelessWidget {
  const JsOtpCard({super.key, required this.fields});

  final Map<String, String> fields;

  @override
  Widget build(BuildContext context) {
    final otp = (fields['otp'] ?? '').trim();
    final orderId = (fields['orderId'] ?? '').trim();
    final digits = otp.isEmpty ? '----'.split('') : otp.split('');
    final pickup = (fields['pickupPoint'] ?? '').trim();
    final window = (fields['window'] ?? '').trim();
    return Semantics(
      label: 'Pickup code ${digits.join(' ')}',
      button: orderId.isNotEmpty,
      child: GestureDetector(
        onTap: orderId.isEmpty ? null : () => context.push('/orders/$orderId'),
        child: Container(
          width: 272,
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardBorder,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.brand, AppColors.brandDeep],
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Icon(Icons.key_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Expanded(child: Text('Your pickup code', style: AppText.label.copyWith(color: Colors.white))),
              if (orderId.isNotEmpty) Text(orderId, style: AppText.tiny.copyWith(color: Colors.white.withValues(alpha: 0.8))),
            ]),
            const SizedBox(height: AppSpace.md),
            ExcludeSemantics(
              child: Row(children: [
                for (var i = 0; i < digits.length; i++) ...[
                  Expanded(
                    child: Container(
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                      child: Text(digits[i], style: AppText.display.copyWith(fontSize: 30)),
                    ),
                  ),
                  if (i < digits.length - 1) const SizedBox(width: AppSpace.sm),
                ],
              ]),
            ),
            const SizedBox(height: AppSpace.md),
            if (pickup.isNotEmpty) _line(Icons.place_rounded, pickup),
            if (window.isNotEmpty) ...[const SizedBox(height: AppSpace.xs), _line(Icons.schedule_rounded, window)],
            const SizedBox(height: AppSpace.md),
            Text(
              'Show it to the vendor at handover; they are paid only then. Never post it in the Street group.',
              style: AppText.caption.copyWith(color: Colors.white.withValues(alpha: 0.88)),
            ),
          ]),
        ),
      ),
    );
  }

  static Widget _line(IconData icon, String text) => Row(children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: AppText.label.copyWith(color: Colors.white))),
      ]);
}

class _Unknown extends StatelessWidget {
  const _Unknown();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Text('Update the app to see this message', style: AppText.caption),
      );
}
