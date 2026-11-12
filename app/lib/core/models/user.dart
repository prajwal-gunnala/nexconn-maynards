import 'json.dart';

/// A person (neighbour, vendor or admin). `unit` is the flat, e.g. `B-1204`.
class User {
  const User({required this.id, required this.name, this.unit, this.phone, this.role});

  final String id;
  final String name;
  final String? unit;
  final String? phone;
  final String? role;

  String get initial => name.isEmpty ? '?' : name[0].toUpperCase();

  factory User.fromJson(Json j) => User(
        id: asString(j['id']),
        name: asString(j['name']),
        unit: asStringOrNull(j['unit']),
        phone: asStringOrNull(j['phone']),
        role: asStringOrNull(j['role'] ?? j['kind']),
      );

  Json toJson() => {
        'id': id,
        'name': name,
        if (unit != null) 'unit': unit,
        if (phone != null) 'phone': phone,
        if (role != null) 'role': role,
      };
}

/// Nexconn credentials returned by `/api/auth/verify`.
class NexconnCreds {
  const NexconnCreds({required this.appKey, required this.token, required this.userId});

  final String appKey;
  final String token;
  final String userId;

  factory NexconnCreds.fromJson(Json j) => NexconnCreds(
        appKey: asString(j['appKey']),
        token: asString(j['token']),
        userId: asString(j['userId']),
      );

  Json toJson() => {'appKey': appKey, 'token': token, 'userId': userId};
}
