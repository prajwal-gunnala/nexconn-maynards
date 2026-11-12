import 'json.dart';

class CommunityStats {
  const CommunityStats({this.members = 0, this.savedThisMonth = 0, this.liveBuckets = 0});

  final int members;
  final int savedThisMonth;
  final int liveBuckets;

  factory CommunityStats.fromJson(Json j) => CommunityStats(
        members: asInt(j['members']),
        savedThisMonth: asInt(j['savedThisMonth']),
        liveBuckets: asInt(j['liveBuckets']),
      );
}

/// A society, street, office or hostel. Its Street chat is the Nexconn group
/// `street_<id>` (see [streetChannelId]).
class Community {
  const Community({
    required this.id,
    required this.name,
    this.kind,
    this.area,
    this.city,
    this.flats,
    this.memberCount,
    this.inviteCode,
    this.stats,
    this.streetGroupId,
    this.raw = const {},
  });

  final String id;
  final String name;
  final String? kind;
  final String? area;
  final String? city;
  final int? flats;
  final int? memberCount;
  final String? inviteCode;
  final CommunityStats? stats;

  /// Server-provided Street group id (falls back to `street_<id>`).
  final String? streetGroupId;

  /// The original JSON, for fields the contract adds later.
  final Json raw;

  String get streetChannelId => streetGroupId ?? 'street_$id';

  /// `Society · OMR, Chennai · 412 flats`
  String get subtitle => [
        ?kind,
        [area, city].whereType<String>().join(', '),
        if (flats != null) '$flats flats',
      ].where((s) => s.isNotEmpty).join(' · ');

  factory Community.fromJson(Json j) => Community(
        id: asString(j['id']),
        name: asString(j['name']),
        kind: asStringOrNull(j['kind'] ?? j['type']),
        area: asStringOrNull(j['area'] ?? j['locality']),
        city: asStringOrNull(j['city']),
        flats: asIntOrNull(j['flats'] ?? j['units']),
        memberCount: asIntOrNull(j['memberCount'] ?? j['members']),
        inviteCode: asStringOrNull(j['inviteCode']),
        stats: asJson(j['stats']) == null ? null : CommunityStats.fromJson(asJson(j['stats'])!),
        streetGroupId: asStringOrNull(j['streetGroupId']),
        raw: j,
      );
}

/// `{community, unit, role}` from `/api/me`.
class Membership {
  const Membership({required this.community, this.unit, this.role = 'member'});

  final Community community;
  final String? unit;
  final String role;

  bool get isAdmin => role == 'admin';

  factory Membership.fromJson(Json j) => Membership(
        community: Community.fromJson(asJson(j['community']) ?? const {}),
        unit: asStringOrNull(j['unit']),
        role: asString(j['role'], 'member'),
      );
}
