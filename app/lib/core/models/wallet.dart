import 'json.dart';

/// One wallet row. The contract doesn't pin the WalletEntry shape yet, so the
/// common fields are read leniently and the original JSON is kept in [raw].
class WalletEntry {
  const WalletEntry({
    required this.id,
    required this.kind,
    required this.amount,
    required this.title,
    this.bucketId,
    this.at,
    this.raw = const {},
  });

  final String id;

  /// held | captured | released | saved | paid ...
  final String kind;
  final int amount;
  final String title;
  final String? bucketId;
  final DateTime? at;
  final Json raw;

  factory WalletEntry.fromJson(Json j) => WalletEntry(
        id: asString(j['id']),
        kind: asString(j['kind'] ?? j['status'] ?? j['type']),
        amount: asInt(j['amount']),
        title: asString(j['title'] ?? j['text']),
        bucketId: asStringOrNull(j['bucketId']),
        at: asTime(j['at'] ?? j['createdAt']),
        raw: j,
      );
}

/// `GET /api/me/wallet`
class Wallet {
  const Wallet({
    this.heldNow = 0,
    this.paidThisMonth = 0,
    this.releasedThisMonth = 0,
    this.savedTotal = 0,
    this.savedThisMonth = 0,
    this.entries = const [],
  });

  final int heldNow;
  final int paidThisMonth;
  final int releasedThisMonth;
  final int savedTotal;
  final int savedThisMonth;
  final List<WalletEntry> entries;

  factory Wallet.fromJson(Json j) => Wallet(
        heldNow: asInt(j['heldNow']),
        paidThisMonth: asInt(j['paidThisMonth']),
        releasedThisMonth: asInt(j['releasedThisMonth']),
        savedTotal: asInt(j['savedTotal']),
        savedThisMonth: asInt(j['savedThisMonth']),
        entries: asList(j['entries'], WalletEntry.fromJson),
      );
}
