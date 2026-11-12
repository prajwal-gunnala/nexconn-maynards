import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/models.dart';

/// Server error, parsed from `{ "error": { "code", "message" } }`.
class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.status});

  /// Machine code from the server (`PIN_INCORRECT`, `UNAUTHORIZED`, ...), or one of
  /// the client codes [network], [timeout], [badResponse].
  final String code;

  /// Human text, safe to show in a SnackBar.
  final String message;
  final int? status;

  static const network = 'NETWORK';
  static const timeout = 'TIMEOUT';
  static const badResponse = 'BAD_RESPONSE';

  bool get isUnauthorized => status == 401;
  bool get isNetwork => code == network || code == timeout;

  @override
  String toString() => 'ApiException($code, $status): $message';
}

/// Thin JSON client for `server/` (docs/CONTRACT.md). Typed helpers live at the
/// bottom; feature code can also call [get]/[post]/[delete] directly.
class ApiClient {
  ApiClient({String? baseUrl, http.Client? httpClient, this.onUnauthorized})
      : baseUrl = baseUrl ?? AppConfig.apiBase,
        _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  /// Bearer token; set by SessionStore after login.
  String? token;

  /// Called on any 401 so the app can log out.
  void Function()? onUnauthorized;

  static const _timeout = Duration(seconds: 12);

  Future<dynamic> get(String path, {Map<String, String?>? query}) => _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body ?? const {});
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, String?>? query}) async {
    final q = query == null ? null : {for (final e in query.entries) if (e.value != null && e.value!.isNotEmpty) e.key: e.value!};
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: (q == null || q.isEmpty) ? null : q);
    final req = http.Request(method, uri)
      ..headers['Accept'] = 'application/json'
      ..headers['Content-Type'] = 'application/json';
    if (token != null && token!.isNotEmpty) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) req.body = jsonEncode(body);

    final http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(_timeout));
    } on TimeoutException {
      throw const ApiException(ApiException.timeout, 'The server took too long. Try again.');
    } on SocketException {
      throw const ApiException(ApiException.network, "Can't reach the server. Check your connection.");
    } on http.ClientException catch (e) {
      throw ApiException(ApiException.network, "Can't reach the server (${e.message}).");
    }

    dynamic data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        throw ApiException(ApiException.badResponse, 'Unexpected reply from the server.', status: res.statusCode);
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    final err = data is Map ? asJson(data['error']) : null;
    final ex = ApiException(
      asString(err?['code'], 'HTTP_${res.statusCode}'),
      asString(err?['message'], 'Something went wrong (${res.statusCode}).'),
      status: res.statusCode,
    );
    if (ex.isUnauthorized) onUnauthorized?.call();
    throw ex;
  }

  Json _obj(dynamic d) => d is Map ? d.cast<String, dynamic>() : <String, dynamic>{};
  List<T> _list<T>(dynamic d, T Function(Json) f) => asList(d, f);

  // ---- Health & auth -------------------------------------------------------

  Future<bool> health() async {
    try {
      final d = _obj(await get('/api/health'));
      return d['ok'] == true;
    } on ApiException {
      return false;
    }
  }

  Future<String?> requestOtp(String phone) async =>
      asStringOrNull(_obj(await post('/api/auth/otp', {'phone': phone}))['devCode']);

  /// Returns `{sessionToken, user, nexconn}`.
  Future<AuthResult> verifyOtp(String phone, String code, {String? name}) async =>
      AuthResult.fromJson(_obj(await post('/api/auth/verify', {'phone': phone, 'code': code, 'name': ?name})));

  Future<MeResult> me() async => MeResult.fromJson(_obj(await get('/api/me')));

  // ---- Communities ---------------------------------------------------------

  Future<List<Community>> communities({String? q}) async =>
      _list(await get('/api/communities', query: {'q': q}), Community.fromJson);

  Future<Community> community(String id) async => Community.fromJson(_obj(await get('/api/communities/$id')));

  Future<Json> joinCommunity(String id, {required String unit}) async =>
      _obj(await post('/api/communities/$id/join', {'unit': unit}));

  // ---- Buckets -------------------------------------------------------------

  Future<List<Bucket>> buckets(String communityId, {String? category, String? type, String? status = 'live'}) async =>
      _list(
        await get('/api/communities/$communityId/buckets', query: {'category': category, 'type': type, 'status': status}),
        Bucket.fromJson,
      );

  Future<Bucket> bucket(String id) async => Bucket.fromJson(_obj(await get('/api/buckets/$id')));

  Future<Bucket> createBucket(Json draft) async => Bucket.fromJson(_obj(await post('/api/buckets', draft)));

  /// `payMode`: `hold` | `at_market`. Returns `{share, bucket}`.
  Future<ShareResult> addShare(
    String bucketId, {
    required PayMode payMode,
    List<String>? unitIds,
    num? qty,
    List<Json>? items,
    Map<String, String>? options,
  }) async =>
      ShareResult.fromJson(_obj(await post('/api/buckets/$bucketId/shares', {
        'payMode': payMode.wire,
        'unitIds': ?unitIds,
        'qty': ?qty,
        'items': ?items,
        'options': ?options,
      })));

  Future<ShareResult> authorizeHold(String holdId, {required String vpa, required String pin}) async =>
      ShareResult.fromJson(_obj(await post('/api/holds/$holdId/authorize', {'vpa': vpa, 'pin': pin})));

  Future<Bucket> leaveShare(String shareId) async =>
      Bucket.fromJson(asJson(_obj(await delete('/api/shares/$shareId'))['bucket']) ?? const {});

  Future<Json> closeBucket(String bucketId) async => _obj(await post('/api/buckets/$bucketId/close'));

  Future<Json> checkIn(String shareId) async => _obj(await post('/api/shares/$shareId/checkin'));

  // ---- Orders, wallet, vendor, admin --------------------------------------

  Future<Order> order(String id) async => Order.fromJson(_obj(await get('/api/orders/$id')));

  Future<List<Order>> myOrders() async => _list(await get('/api/me/orders'), Order.fromJson);

  Future<Order> handover(String orderId, String otp) async =>
      Order.fromJson(asJson(_obj(await post('/api/orders/$orderId/handover', {'otp': otp}))['order']) ?? const {});

  Future<Wallet> wallet() async => Wallet.fromJson(_obj(await get('/api/me/wallet')));

  Future<Json> vendorDashboard() async => _obj(await get('/api/vendor/dashboard'));

  Future<Json> adminCommunity(String id) async => _obj(await get('/api/admin/communities/$id'));

  Future<void> nudge(String bucketId) async => post('/api/admin/nudge', {'bucketId': bucketId});
}

class AuthResult {
  const AuthResult({required this.sessionToken, required this.user, required this.nexconn});

  final String sessionToken;
  final User user;
  final NexconnCreds nexconn;

  factory AuthResult.fromJson(Json j) => AuthResult(
        sessionToken: asString(j['sessionToken']),
        user: User.fromJson(asJson(j['user']) ?? const {}),
        nexconn: NexconnCreds.fromJson(asJson(j['nexconn']) ?? const {}),
      );
}

class MeResult {
  const MeResult({required this.user, required this.memberships});

  final User user;
  final List<Membership> memberships;

  factory MeResult.fromJson(Json j) => MeResult(
        user: User.fromJson(asJson(j['user']) ?? const {}),
        memberships: asList(j['memberships'], Membership.fromJson),
      );
}

class ShareResult {
  const ShareResult({required this.share, required this.bucket});

  final Share? share;
  final Bucket? bucket;

  factory ShareResult.fromJson(Json j) => ShareResult(
        share: asJson(j['share']) == null ? null : Share.fromJson(asJson(j['share'])!),
        bucket: asJson(j['bucket']) == null ? null : Bucket.fromJson(asJson(j['bucket'])!),
      );
}
