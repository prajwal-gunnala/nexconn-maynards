import 'dart:convert';

import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';

import '../models/bucket.dart';

/// Our custom Nexconn message types (docs/CONTRACT.md "Nexconn chat contract").
class JsType {
  const JsType._();

  static const bucket = 'js:bucket';
  static const event = 'js:event';
  static const order = 'js:order';
  static const otp = 'js:otp';

  static const all = [bucket, event, order, otp];
}

/// Reads the string fields of a custom message (`CustomMessage.fields`).
Map<String, String> jsFields(Message m) {
  if (m is! CustomMessage) return const {};
  final f = m.fields;
  if (f == null) return const {};
  return f.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
}

/// The custom type identifier (`js:bucket`, ...) or null for other messages.
String? jsTypeOf(Message m) => m is CustomMessage ? m.messageIdentifier : null;

/// Reads a message's metadata (Nexconn "expansion") as strings.
Map<String, String> jsMetadata(Message m) {
  final md = m.metadata;
  if (md == null) return const {};
  return md.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
}

Map<String, dynamic>? _decodeObj(String? s) {
  if (s == null || s.isEmpty) return null;
  try {
    final v = jsonDecode(s);
    return v is Map ? v.cast<String, dynamic>() : null;
  } catch (_) {
    return null;
  }
}

/// The view model of a `js:bucket` chat card: content fields + live metadata.
class BucketCardData {
  const BucketCardData({
    required this.bucketId,
    required this.type,
    required this.title,
    this.subtitle,
    this.image,
    this.vendor,
    this.cutoffAt,
    this.unitLabel,
    this.progress,
    this.status = BucketStatus.live,
    this.units = const [],
  });

  final String bucketId;
  final BucketType type;
  final String title;
  final String? subtitle;
  final String? image;
  final String? vendor;
  final DateTime? cutoffAt;
  final String? unitLabel;

  /// From metadata `p` (JSON progress).
  final Progress? progress;

  /// From metadata `s`.
  final BucketStatus status;

  /// From metadata `u` (split only): `[[unitId, ownerInitial|""], ...]`.
  final List<(String, String)> units;

  /// Builds from the message content [fields] and current [metadata].
  factory BucketCardData.from(Map<String, String> fields, Map<String, String> metadata) {
    final p = _decodeObj(metadata['p']);
    final units = <(String, String)>[];
    final rawU = metadata['u'];
    if (rawU != null && rawU.isNotEmpty) {
      try {
        final v = jsonDecode(rawU);
        if (v is List) {
          for (final e in v) {
            if (e is List && e.isNotEmpty) units.add((e[0].toString(), e.length > 1 ? (e[1]?.toString() ?? '') : ''));
          }
        }
      } catch (_) {}
    }
    // The vendor field may be a plain name or a JSON object.
    final vendorRaw = fields['vendor'];
    final vendorObj = _decodeObj(vendorRaw);
    return BucketCardData(
      bucketId: fields['bucketId'] ?? '',
      type: BucketType.parse(fields['type']),
      title: fields['title'] ?? 'Bucket',
      subtitle: fields['subtitle'],
      image: fields['image'],
      vendor: vendorObj?['name']?.toString() ?? vendorRaw,
      cutoffAt: DateTime.tryParse(fields['cutoffAt'] ?? ''),
      unitLabel: fields['unitLabel'],
      progress: p == null ? null : Progress.fromJson(p),
      status: metadata['s'] == null ? BucketStatus.live : BucketStatus.parse(metadata['s']),
      units: units,
    );
  }
}
