import 'dart:async';

import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/models/bucket.dart';
import '../../core/nexconn/js_messages.dart';
import '../../core/nexconn/nexconn_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import '../bucket/bucket_visuals.dart';

/// Builders to pass to `ChatPage(customMessageBubbleBuilders: jsBubbleBuilders)`.
final Map<MessageType, ChatMessageBubbleBuilder> jsBubbleBuilders = {
  MessageType.customMessage: (context, message, config) => JsMessageBubble(message: message),
};

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
      JsType.event => _EventBubble(fields: f),
      JsType.order => _OrderBubble(fields: f),
      JsType.otp => _OtpBubble(fields: f),
      _ => _Unknown(type: type ?? '?'),
    };
  }
}

/// The live `js:bucket` card. Seeds from the message's metadata (history
/// loads include it) and redraws on every `onMessageMetadataUpdated` for its
/// messageId via [NexconnService.watchMetadata].
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
  bool _flash = false;

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
    if (kDebugMode) {
      debugPrint('[spike] js:bucket id=${widget.message.messageId} fields=$_fields '
          'metadata=${widget.message.metadata} canIncludeMetadata=${widget.message.canIncludeMetadata}');
    }
    final id = widget.message.messageId;
    if (id != null) {
      _sub = _nx.watchMetadata(id).listen((u) {
        if (!mounted) return;
        setState(() {
          _meta = u.metadata;
          _flash = true;
        });
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) setState(() => _flash = false);
        });
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _devSetMetadata() async {
    final messenger = ScaffoldMessenger.of(context);
    final p = _card.progress;
    final filled = (p?.filled ?? 0) + 1;
    final target = p?.target ?? 100;
    final code = await _nx.setMetadata(widget.message, {
      'p': '{"filled":$filled,"target":$target}',
      's': 'live',
    });
    debugPrint('[spike] client setMetadata -> $code');
    messenger.showSnackBar(SnackBar(content: Text('Client setMetadata result: $code')));
  }

  BucketCardData get _card => BucketCardData.from(_fields, _meta);

  @override
  Widget build(BuildContext context) {
    final c = _card;
    final p = c.progress;
    final visual = BucketVisual.of(c.image ?? c.title);
    final unit = c.unitLabel ?? (c.type == BucketType.bulk ? 'kg' : 'share');
    return GestureDetector(
      onTap: c.bucketId.isEmpty ? null : () => context.push('/bucket/${c.bucketId}'),
      onLongPress: kDebugMode && AppConfig.hasDevToken ? _devSetMetadata : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 264,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(color: _flash ? AppColors.brand : AppColors.line, width: _flash ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: BucketPhoto(visual: visual, height: 104, badge: _typeLabel(c.type)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(c.title, style: AppText.heading, maxLines: 2, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                _statusPill(c.status),
              ]),
              if (c.subtitle != null || c.vendor != null) ...[
                const SizedBox(height: 2),
                Text(c.subtitle ?? c.vendor!, style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 10),
              AppProgressBar(value: p?.fraction ?? 0),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: Text(
                    p == null ? 'Waiting for the first share' : '${_num(p.filled)} of ${_num(p.target)} $unit',
                    style: AppText.label,
                  ),
                ),
                if (p != null) Text('${p.percentRounded}%', style: AppText.label.copyWith(color: AppColors.brand)),
              ]),
              if (p?.nextTier != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${_num(p!.nextTier!.remaining)} $unit more → ${Fmt.rupees(p.nextTier!.unitPrice)}/$unit',
                  style: AppText.caption.copyWith(color: AppColors.save),
                ),
              ],
              if (c.cutoffAt != null) ...[
                const SizedBox(height: 4),
                Text('Cutoff ${Fmt.time(c.cutoffAt!)} · ${Fmt.timeLeft(c.cutoffAt!)}', style: AppText.caption),
              ],
              const SizedBox(height: 10),
              Container(
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.status.isOpen ? AppColors.brand : AppColors.canvas,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  c.status.isOpen ? 'Join bucket' : 'View bucket',
                  style: AppText.label.copyWith(color: c.status.isOpen ? Colors.white : AppColors.ink),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  static String _num(num n) => n == n.roundToDouble() ? n.round().toString() : n.toStringAsFixed(1);

  static String _typeLabel(BucketType t) => switch (t) {
        BucketType.split => 'Split',
        BucketType.bulk => 'Bulk',
        BucketType.service => 'Service',
        BucketType.trip => 'Market trip',
        BucketType.unknown => 'Bucket',
      };

  static Widget _statusPill(BucketStatus s) => switch (s) {
        BucketStatus.live => const StatusPill('Live', tone: PillTone.brand),
        BucketStatus.ordered => const StatusPill('Full', tone: PillTone.captured),
        BucketStatus.marketDay => const StatusPill('Market day', tone: PillTone.brand),
        BucketStatus.delivering => const StatusPill('On the way', tone: PillTone.held),
        BucketStatus.completed => const StatusPill('Done', tone: PillTone.captured),
        BucketStatus.expired => const StatusPill('Expired', tone: PillTone.released),
        BucketStatus.cancelled => const StatusPill('Cancelled', tone: PillTone.released),
        BucketStatus.unknown => const StatusPill('—'),
      };
}

class _EventBubble extends StatelessWidget {
  const _EventBubble({required this.fields});
  final Map<String, String> fields;

  @override
  Widget build(BuildContext context) {
    final kind = fields['kind'] ?? '';
    final icon = switch (kind) {
      'joined' => Icons.add_circle_outline,
      'left' => Icons.remove_circle_outline,
      'locked' => Icons.lock_outline,
      'expired' => Icons.hourglass_disabled,
      'nudge' => Icons.campaign_outlined,
      'checkin' => Icons.where_to_vote_outlined,
      _ => Icons.info_outline,
    };
    return GestureDetector(
      onTap: (fields['bucketId'] ?? '').isEmpty ? null : () => context.push('/bucket/${fields['bucketId']}'),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 264),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: AppColors.brandDeep),
          const SizedBox(width: 8),
          Flexible(child: Text(fields['text'] ?? kind, style: AppText.label.copyWith(color: AppColors.brandDeep))),
        ]),
      ),
    );
  }
}

class _OrderBubble extends StatelessWidget {
  const _OrderBubble({required this.fields});
  final Map<String, String> fields;

  @override
  Widget build(BuildContext context) {
    final total = int.tryParse(fields['total'] ?? '');
    return GestureDetector(
      onTap: (fields['orderId'] ?? '').isEmpty ? null : () => context.push('/orders/${fields['orderId']}'),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(color: AppColors.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const StatusPill('Order placed', tone: PillTone.captured, icon: Icons.receipt_long_outlined),
          const SizedBox(height: 8),
          Text(fields['title'] ?? 'Order', style: AppText.heading),
          const SizedBox(height: 4),
          Text(
            [
              if (fields['orderId'] != null) fields['orderId']!,
              if (total != null) Fmt.rupees(total),
              if (fields['members'] != null) '${fields['members']} members',
            ].join(' · '),
            style: AppText.caption,
          ),
        ]),
      ),
    );
  }
}

class _OtpBubble extends StatelessWidget {
  const _OtpBubble({required this.fields});
  final Map<String, String> fields;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Pickup OTP', style: AppText.caption),
        const SizedBox(height: 4),
        Text(fields['otp'] ?? '----', style: AppText.display.copyWith(letterSpacing: 6)),
        const SizedBox(height: 4),
        Text([fields['pickupPoint'], fields['window']].whereType<String>().join(' · '), style: AppText.caption),
      ]),
    );
  }
}

class _Unknown extends StatelessWidget {
  const _Unknown({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
        child: Text('Unsupported message ($type)', style: AppText.caption),
      );
}
