// Tolerant JSON readers. The server is built in parallel, so models never throw
// on a missing or mistyped field; they fall back to sensible defaults.

typedef Json = Map<String, dynamic>;

int asInt(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.round() ?? fallback;
  return fallback;
}

int? asIntOrNull(Object? v) => v == null ? null : asInt(v);

double asDouble(Object? v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

String asString(Object? v, [String fallback = '']) => v == null ? fallback : v.toString();

String? asStringOrNull(Object? v) => v?.toString();

bool asBool(Object? v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is String) return v == 'true';
  if (v is num) return v != 0;
  return fallback;
}

DateTime? asTime(Object? v) => v is String ? DateTime.tryParse(v) : null;

Json? asJson(Object? v) => v is Map ? v.cast<String, dynamic>() : null;

List<T> asList<T>(Object? v, T Function(Json) f) =>
    v is List ? v.whereType<Map>().map((e) => f(e.cast<String, dynamic>())).toList() : <T>[];

List<String> asStringList(Object? v) =>
    v is List ? v.map((e) => e.toString()).toList() : const <String>[];
