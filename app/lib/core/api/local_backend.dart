import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Standalone demo backend: an in-app `http.Client` that answers the REST API in docs/CONTRACT.md from a snapshot of
/// the demo server (assets/demo/snapshot.json, recorded by scripts/snapshot-demo.mjs) and applies the main rules of
/// server/src/service.js in memory (claim, UPI hold, lock into an order, leave, book-and-meet, create bucket,
/// handover). Only Nexconn (chat, calls) uses the network. State is kept per phone in SharedPreferences.
///
/// Times: the snapshot is stored in its own time frame and every ISO time in a reply is shifted by
/// `now - takenAt`, so cutoffs and "2 days ago" stay relative to today.
class LocalBackend extends http.BaseClient {
  LocalBackend._(this._snap, this._prefs) : _delta = DateTime.now().toUtc().difference(DateTime.parse(_snap['takenAt'] as String));

  static Future<LocalBackend> load() async {
    final raw = await rootBundle.loadString('assets/demo/snapshot.json');
    return LocalBackend._(jsonDecode(raw) as Map<String, dynamic>, await SharedPreferences.getInstance());
  }

  final Map<String, dynamic> _snap;
  final SharedPreferences _prefs;
  final Duration _delta;
  final _rng = Random();
  final Map<String, Map<String, dynamic>> _states = {};

  static const _templatePhone = '9100000006';
  static const _committed = {'held', 'booked', 'captured', 'checked_in', 'collected'};
  static const _active = {'pending_payment', ..._committed};
  static final _iso = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$');

  Map<String, dynamic> get _users => (_snap['users'] as Map).cast<String, dynamic>();

  // ---- http plumbing -----------------------------------------------------------------------

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    Object? body;
    if (request is http.Request && request.body.isNotEmpty) {
      try {
        body = jsonDecode(request.body);
      } catch (_) {}
    }
    int status = 200;
    Object? out;
    try {
      out = await _handle(request.method, request.url, request.headers['Authorization'] ?? request.headers['authorization'], body);
    } on _Fail catch (e) {
      status = e.status;
      out = {'error': {'code': e.code, 'message': e.message}};
    } catch (e, st) {
      assert(() {
        // ignore: avoid_print
        print('LocalBackend: $e\n$st');
        return true;
      }());
      status = 500;
      out = {'error': {'code': 'LOCAL_ERROR', 'message': 'Something went wrong ($e).'}};
    }
    final bytes = utf8.encode(jsonEncode(_shift(out, _delta)));
    return http.StreamedResponse(Stream.value(bytes), status,
        headers: {'content-type': 'application/json; charset=utf-8'}, request: request);
  }

  /// Shifts every ISO time string in [v] by [d] (deep copy).
  dynamic _shift(dynamic v, Duration d) {
    if (v is Map) return {for (final e in v.entries) e.key as String: _shift(e.value, d)};
    if (v is List) return [for (final x in v) _shift(x, d)];
    if (v is String && _iso.hasMatch(v)) {
      final t = DateTime.tryParse(v);
      if (t != null) return t.toUtc().add(d).toIso8601String();
    }
    return v;
  }

  String _rawNow() {
    final t = DateTime.now().toUtc().subtract(_delta);
    return DateTime.fromMillisecondsSinceEpoch(t.millisecondsSinceEpoch, isUtc: true).toIso8601String();
  }

  String _hex(int n) => List.generate(n, (_) => _rng.nextInt(16).toRadixString(16)).join();
  String _id(String p) => '${p}_${_hex(8)}';

  dynamic _copy(dynamic v) => jsonDecode(jsonEncode(v));

  // ---- state ---------------------------------------------------------------------------------

  String? _phoneFor(String? auth) {
    if (auth == null) return null;
    final t = auth.replaceFirst('Bearer ', '').trim();
    return t.startsWith('local-') ? t.substring(6) : null;
  }

  Map<String, dynamic> _state(String phone) {
    final cached = _states[phone];
    if (cached != null) return cached;
    final saved = _prefs.getString('local.state.$phone');
    Map<String, dynamic>? st;
    if (saved != null) {
      try {
        st = (jsonDecode(saved) as Map).cast<String, dynamic>();
      } catch (_) {}
    }
    st ??= _fresh(phone);
    return _states[phone] = st;
  }

  Map<String, dynamic> _fresh(String phone) {
    final rec = _users[phone];
    if (rec != null) return (_copy(rec) as Map).cast<String, dynamic>();
    // A new phone: start from a tester's view with no membership, shares, orders or wallet.
    final local = (jsonDecode(_prefs.getString('local.users') ?? '{}') as Map)[phone] as Map?;
    final st = (_copy(_users[_templatePhone]) as Map).cast<String, dynamic>();
    final user = {'id': local?['id'] ?? 'u_${_hex(8)}', 'name': local?['name'] ?? 'Neighbour', 'phone': phone, 'kind': 'member'};
    st['user'] = user;
    final get = (st['get'] as Map).cast<String, dynamic>();
    get['/api/me'] = {'user': user, 'memberships': []};
    get.removeWhere((k, _) => k.startsWith('/api/orders/') || k.startsWith('/api/admin/') || k == '/api/vendor/dashboard');
    get['/api/me/orders'] = [];
    get['/api/me/wallet'] = {'heldNow': 0, 'paidThisMonth': 0, 'releasedThisMonth': 0, 'savedTotal': 0, 'savedThisMonth': 0, 'entries': []};
    for (final k in get.keys.toList()) {
      if (k.startsWith('/api/buckets/')) (get[k] as Map)['myShare'] = null;
    }
    for (final k in get.keys.where((k) => k.contains('/buckets?')).toList()) {
      for (final b in get[k] as List) {
        (b as Map)['myShare'] = null;
      }
    }
    return st;
  }

  Future<void> _save(String phone) async {
    final st = _states[phone];
    if (st != null) await _prefs.setString('local.state.$phone', jsonEncode(st));
  }

  Map<String, dynamic> _get(Map<String, dynamic> st) => (st['get'] as Map).cast<String, dynamic>();

  Map<String, dynamic> _bucket(Map<String, dynamic> st, String id) {
    final b = _get(st)['/api/buckets/$id'];
    if (b == null) throw const _Fail(404, 'NOT_FOUND', 'No such bucket.');
    return (b as Map).cast<String, dynamic>();
  }

  Iterable<Map<String, dynamic>> _allBuckets(Map<String, dynamic> st) => _get(st)
      .entries
      .where((e) => e.key.startsWith('/api/buckets/'))
      .map((e) => (e.value as Map).cast<String, dynamic>());

  String _unitOf(Map<String, dynamic> st, String communityId) {
    final ms = (_get(st)['/api/me'] as Map)['memberships'] as List;
    for (final m in ms) {
      if ((m as Map)['community']['id'] == communityId) return m['unit'] as String;
    }
    throw const _Fail(403, 'NOT_MEMBER', 'Join this community first.');
  }

  // ---- router --------------------------------------------------------------------------------

  Future<Object?> _handle(String method, Uri url, String? auth, Object? body) async {
    final path = url.path;
    final b = body is Map ? body.cast<String, dynamic>() : <String, dynamic>{};
    if (path == '/api/health') return {'ok': true, 'nexconn': 'ok', 'mode': 'standalone'};
    if (method == 'POST' && path == '/api/auth/otp') {
      _normPhone(b['phone']);
      return {'ok': true, 'devCode': '1234'};
    }
    if (method == 'POST' && path == '/api/auth/verify') return _verify(b);

    final phone = _phoneFor(auth);
    if (phone == null) throw const _Fail(401, 'UNAUTHORIZED', 'Please log in again.');
    final st = _state(phone);
    final get = _get(st);
    final seg = path.split('/').where((s) => s.isNotEmpty).toList();

    if (method == 'GET') {
      if (path == '/api/users') return _profiles(url.queryParameters['ids'] ?? '', st);
      if (seg.length == 4 && seg[1] == 'communities' && seg[3] == 'buckets') return _list(st, seg[2], url.queryParameters);
      final hit = get[path];
      if (hit == null) {
        if (path == '/api/vendor/dashboard') throw const _Fail(403, 'NOT_VENDOR', 'This account is not a vendor.');
        if (seg.length >= 2 && seg[1] == 'admin') throw const _Fail(403, 'FORBIDDEN', 'Only the community admin can do this.');
        throw const _Fail(404, 'NOT_FOUND', 'Not found.');
      }
      return hit;
    }

    Object? out;
    if (method == 'POST' && seg.length == 4 && seg[1] == 'communities' && seg[3] == 'join') {
      out = _join(st, seg[2], b);
    } else if (method == 'POST' && path == '/api/buckets') {
      out = _create(st, b);
    } else if (method == 'POST' && seg.length == 4 && seg[1] == 'buckets' && seg[3] == 'shares') {
      out = _addShare(st, seg[2], b);
    } else if (method == 'POST' && seg.length == 4 && seg[1] == 'holds' && seg[3] == 'authorize') {
      out = _authorize(st, seg[2], b);
    } else if (method == 'DELETE' && seg.length == 3 && seg[1] == 'shares') {
      out = _leave(st, seg[2]);
    } else if (method == 'POST' && seg.length == 4 && seg[1] == 'buckets' && seg[3] == 'close') {
      out = _close(st, seg[2]);
    } else if (method == 'POST' && seg.length == 4 && seg[1] == 'shares' && seg[3] == 'checkin') {
      out = _checkin(st, seg[2]);
    } else if (method == 'POST' && seg.length == 4 && seg[1] == 'orders' && seg[3] == 'handover') {
      out = _handover(st, seg[2], b);
    } else if (method == 'POST' && path == '/api/admin/nudge') {
      final id = '${b['bucketId'] ?? ''}';
      final admin = get.entries.where((e) => e.key.startsWith('/api/admin/')).map((e) => e.value as Map).firstOrNull;
      final n = (admin?['nudges'] as List?)?.cast<Map>().where((x) => x['bucketId'] == id).firstOrNull;
      out = {'ok': true, 'text': n?['text'] ?? 'Nudge sent.'};
    } else {
      throw _Fail(404, 'NOT_FOUND', 'No route for $method $path.');
    }
    await _save(phone);
    return out;
  }

  // ---- auth ----------------------------------------------------------------------------------

  String _normPhone(Object? phone) {
    var d = '${phone ?? ''}'.replaceAll(RegExp(r'\D'), '');
    if (d.length > 10) d = d.substring(d.length - 10);
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(d)) throw const _Fail(400, 'INVALID_PHONE', 'Enter a 10-digit mobile number.');
    return d;
  }

  Future<Object?> _verify(Map<String, dynamic> b) async {
    final phone = _normPhone(b['phone']);
    if ('${b['code'] ?? ''}'.trim() != '1234') throw const _Fail(400, 'OTP_INVALID', 'That code is not right. (Demo code: 1234)');
    final appKey = _snap['appKey'] as String? ?? '';
    var rec = _users[phone] as Map?;
    Map? nexconn = rec?['nexconn'] as Map?;
    if (rec == null) {
      final locals = (jsonDecode(_prefs.getString('local.users') ?? '{}') as Map).cast<String, dynamic>();
      if (locals[phone] == null) {
        final name = '${b['name'] ?? ''}'.trim();
        if (name.isEmpty) throw const _Fail(400, 'NAME_REQUIRED', 'Tell us your name to create your account.');
        locals[phone] = {'id': 'u_${_hex(8)}', 'name': name.length > 40 ? name.substring(0, 40) : name};
        await _prefs.setString('local.users', jsonEncode(locals));
      }
      // New people chat as the shared demo tester (tokens are issued server-side only).
      nexconn = _users[_templatePhone]?['nexconn'] as Map?;
    }
    final st = _state(phone);
    await _save(phone);
    return {
      'sessionToken': 'local-$phone',
      'user': st['user'],
      'nexconn': {'appKey': appKey, 'token': nexconn?['token'] ?? '', 'userId': nexconn?['userId'] ?? ''},
    };
  }

  List<Object?> _profiles(String ids, Map<String, dynamic> st) {
    final want = ids.split(',').where((s) => s.isNotEmpty).toSet();
    final all = (_snap['profiles'] as List).cast<Map>();
    return [for (final p in all) if (want.contains(p['id'])) p];
  }

  // ---- communities ---------------------------------------------------------------------------

  Object? _join(Map<String, dynamic> st, String id, Map<String, dynamic> b) {
    final c = _get(st)['/api/communities/$id'];
    if (c == null) throw const _Fail(404, 'NOT_FOUND', 'No such community.');
    final unit = '${b['unit'] ?? ''}'.trim().toUpperCase();
    if (unit.isEmpty || unit.length > 16) throw const _Fail(400, 'BAD_REQUEST', 'Tell us your flat or unit, like B-1204.');
    final me = _get(st)['/api/me'] as Map;
    final ms = me['memberships'] as List;
    final existing = ms.cast<Map>().where((m) => m['community']['id'] == id).firstOrNull;
    final m = existing ?? {'community': c, 'unit': unit, 'role': 'member'};
    m['unit'] = unit;
    if (existing == null) ms.add(m);
    return {'membership': m};
  }

  List<Object?> _list(Map<String, dynamic> st, String communityId, Map<String, String> q) {
    final get = _get(st);
    if (get['/api/communities/$communityId'] == null) throw const _Fail(404, 'NOT_FOUND', 'No such community.');
    final status = q['status'] ?? '';
    final out = _allBuckets(st).where((b) =>
        b['communityId'] == communityId &&
        ((q['category'] ?? '').isEmpty || b['category'] == q['category']) &&
        ((q['type'] ?? '').isEmpty || b['type'] == q['type']) &&
        (status.isEmpty || status == 'all' || b['status'] == status)).toList();
    int rank(Map b) => b['status'] == 'live' ? 0 : 1;
    out.sort((a, b) {
      final r = rank(a) - rank(b);
      if (r != 0) return r;
      final c = '${a['cutoffAt']}'.compareTo('${b['cutoffAt']}');
      return rank(a) == 0 ? c : -c;
    });
    return out;
  }

  // ---- pricing (mirrors server/src/domain/pricing.js) ----------------------------------------

  List<Map> _tiers(Map b) {
    final t = ((b['tiers'] as List?) ?? const []).cast<Map>().toList();
    t.sort((x, y) => (x['minQty'] as num).compareTo(y['minQty'] as num));
    return t;
  }

  Map? _tierFor(Map b, num qty) {
    Map? hit;
    for (final t in _tiers(b)) {
      if (qty >= (t['minQty'] as num)) hit = t;
    }
    return hit;
  }

  int _unitPriceAt(Map b, num qty) {
    final t = _tierFor(b, qty);
    if (t != null) return (t['unitPrice'] as num).toInt();
    final ts = _tiers(b);
    return ((b['unitPrice'] as num?) ?? (ts.isEmpty ? 0 : ts.first['unitPrice'] as num)).toInt();
  }

  num _goAt(Map b) {
    if (b['type'] == 'split') return (b['units'] as List).length;
    if (b['type'] == 'trip') return (b['minLoadKg'] as num?) ?? 1;
    final ts = _tiers(b);
    return ts.isEmpty ? 1 : ts.first['minQty'] as num;
  }

  num _target(Map b) {
    if (b['type'] == 'split') return (b['units'] as List).length;
    if (b['type'] == 'trip') return (b['capacity'] as num?) ?? 1;
    final ts = _tiers(b);
    return (b['lotQty'] as num?) ?? (ts.isEmpty ? 1 : ts.last['minQty'] as num);
  }

  Map? _item(Map b, Object? id) => ((b['items'] as List?) ?? const []).cast<Map>().where((i) => i['id'] == id).firstOrNull;
  Map? _unit(Map b, Object? id) => ((b['units'] as List?) ?? const []).cast<Map>().where((u) => u['id'] == id).firstOrNull;

  num _itemsKg(Map b, List? items) {
    num kg = 0;
    for (final it in (items ?? const []).cast<Map>()) {
      kg += (it['qty'] as num) * ((_item(b, it['id'])?['kgPerUnit'] as num?) ?? 1);
    }
    return _tidy(kg);
  }

  int _itemsGoods(Map b, List? items) {
    num sum = 0;
    for (final it in (items ?? const []).cast<Map>()) {
      sum += (it['qty'] as num) * ((_item(b, it['id'])?['price'] as num?) ?? 0);
    }
    return sum.round();
  }

  num _shareQty(Map b, Map s) {
    if (b['type'] == 'split') return ((s['unitIds'] as List?) ?? const []).length;
    if (b['type'] == 'trip') return _itemsKg(b, s['items'] as List?);
    return (s['qty'] as num?) ?? 0;
  }

  num _filled(Map b) => ((b['shares'] as List?) ?? const [])
      .cast<Map>()
      .where((s) => _committed.contains(s['status']))
      .fold<num>(0, (n, s) => n + _shareQty(b, s));

  int _splitPrice(Map b, List ids) => ids.fold<int>(0, (n, id) => n + ((_unit(b, id)?['price'] as num?) ?? 0).toInt());

  int _retail(Map b, Map s) {
    if (b['type'] == 'split') {
      return ((s['unitIds'] as List?) ?? const []).fold<int>(0, (sum, id) {
        final u = _unit(b, id);
        if (u == null) return sum;
        if (u['retailPrice'] != null) return sum + (u['retailPrice'] as num).toInt();
        return sum + ((((u['grams'] as num?) ?? 0) / 1000) * ((b['retailUnitPrice'] as num?) ?? 0)).round();
      });
    }
    if (b['type'] == 'trip') {
      return ((s['items'] as List?) ?? const []).cast<Map>().fold<num>(0, (sum, it) {
        final d = _item(b, it['id']);
        return sum + (it['qty'] as num) * ((d?['retailPrice'] as num?) ?? (d?['price'] as num?) ?? 0);
      }).round();
    }
    return (((s['qty'] as num?) ?? 0) * ((b['retailUnitPrice'] as num?) ?? 0)).round();
  }

  String _plural(num n, String label) {
    const noPlural = {'kg', 'g', 'l', 'L', 'dozen', 'ml', 'pc', 'pcs'};
    final ns = n == n.roundToDouble() ? '${n.toInt()}' : '$n';
    return '$ns ${n == 1 || noPlural.contains(label) ? label : '${label}s'}';
  }

  String _qtyLabel(Map b, Map s) {
    if (b['type'] == 'split') {
      return ((s['unitIds'] as List?) ?? const []).map((id) => _unit(b, id)?['label'] ?? id).join(', ');
    }
    if (b['type'] == 'trip') {
      return ((s['items'] as List?) ?? const []).cast<Map>().map((it) {
        final d = _item(b, it['id']);
        return '${d?['name'] ?? it['id']} ${_plural(it['qty'] as num, '${d?['unit'] ?? 'kg'}')}';
      }).join(' · ');
    }
    return _plural((s['qty'] as num?) ?? 0, '${b['unitLabel'] ?? ''}');
  }

  /// Recomputes unit owners, trip item totals and the progress block from the bucket's active shares.
  /// `progress.held` is kept incrementally (other members' hold amounts are not in the view).
  void _refresh(Map b) {
    final shares = ((b['shares'] as List?) ?? const []).cast<Map>();
    final active = shares.where((s) => _active.contains(s['status'])).toList();
    if (b['type'] == 'split') {
      final owner = <Object?, Object?>{};
      for (final s in active) {
        for (final id in (s['unitIds'] as List?) ?? const []) {
          owner[id] = s['user'];
        }
      }
      for (final u in (b['units'] as List).cast<Map>()) {
        u['owner'] = owner[u['id']];
      }
    }
    if (b['type'] == 'trip') {
      for (final it in ((b['items'] as List?) ?? const []).cast<Map>()) {
        final using = active.where((s) => ((s['items'] as List?) ?? const []).cast<Map>().any((x) => x['id'] == it['id']));
        it['qty'] = using.fold<num>(0, (n, s) => n + ((s['items'] as List).cast<Map>().firstWhere((x) => x['id'] == it['id'])['qty'] as num));
        it['members'] = using.length;
      }
    }
    final filled = _filled(b);
    final tgt = _target(b);
    final p = <String, dynamic>{...?(b['progress'] as Map?)};
    final tiered = b['type'] == 'bulk' || b['type'] == 'service';
    Map? next;
    if (tiered) {
      final t = _tiers(b).where((x) => (x['minQty'] as num) > filled).firstOrNull;
      if (t != null) next = {'minQty': t['minQty'], 'unitPrice': t['unitPrice'], 'remaining': (t['minQty'] as num) - filled};
    }
    p
      ..['filled'] = _tidy(filled)
      ..['target'] = tgt
      ..['members'] = shares.where((s) => _committed.contains(s['status'])).length
      ..['held'] = p['held'] ?? 0
      ..['unitPrice'] = tiered ? _unitPriceAt(b, filled) : (b['type'] == 'split' ? b['unitPrice'] : null)
      ..['nextTier'] = next
      ..['percent'] = tgt == 0 ? 0 : min(100, (filled / tgt * 100).round())
      ..['goAt'] = _goAt(b);
    if (b['type'] == 'trip') {
      p['transportPerKg'] = ((((b['transportFee'] as num?) ?? 0) / max(filled, (b['minLoadKg'] as num?) ?? 1)) * 100).round() / 100;
    }
    b['progress'] = p;
    for (final s in shares) {
      s['qtyLabel'] = _qtyLabel(b, s);
    }
    final mine = b['myShare'] as Map?;
    if (mine != null) mine['qtyLabel'] = _qtyLabel(b, mine);
  }

  /// 2 decimals, and whole numbers as ints (so `7`, not `7.0`).
  num _tidy(num n) {
    final r = (n * 100).round() / 100;
    return r == r.roundToDouble() ? r.toInt() : r;
  }

  bool _isFilled(Map b) {
    final f = _filled(b);
    if (b['type'] == 'split') return f >= (b['units'] as List).length;
    if (b['type'] == 'trip') return f >= ((b['capacity'] as num?) ?? double.infinity);
    return b['lotQty'] != null && f >= (b['lotQty'] as num);
  }

  // ---- shares & holds ------------------------------------------------------------------------

  Map<String, dynamic> _wallet(Map<String, dynamic> st) => (_get(st)['/api/me/wallet'] as Map).cast<String, dynamic>();

  void _bump(Map w, String k, num by) => w[k] = ((w[k] as num?) ?? 0) + by;

  Map _publicShare(Map s) => {
        for (final k in ['id', 'bucketId', 'user', 'qty', 'qtyLabel', 'unitIds', 'items', 'options', 'payMode', 'status', 'createdAt']) k: s[k],
      };

  void _syncPublic(Map b, Map mine) {
    final shares = ((b['shares'] as List?) ?? []).cast<Map>().toList();
    shares.removeWhere((s) => s['id'] == mine['id']);
    if (_active.contains(mine['status'])) shares.add(_publicShare(mine));
    b['shares'] = shares;
  }

  /// Mirrors a bucket's view into every cached bucket list of that community.
  void _put(Map<String, dynamic> st, Map b) => _get(st)['/api/buckets/${b['id']}'] = b;

  Object? _addShare(Map<String, dynamic> st, String bucketId, Map<String, dynamic> body) {
    final b = _bucket(st, bucketId);
    final unit = _unitOf(st, b['communityId'] as String);
    if (b['status'] != 'live') throw const _Fail(409, 'BUCKET_CLOSED', 'This bucket is no longer taking shares.');
    final mine = b['myShare'] as Map?;
    if (mine != null && _active.contains(mine['status'])) {
      throw const _Fail(409, 'ALREADY_JOINED', 'You already have a share in this bucket. Leave it first to change it.');
    }
    final payMode = '${body['payMode'] ?? b['settleMode']}';
    if (payMode != b['settleMode']) {
      throw _Fail(400, 'PAY_MODE_NOT_ALLOWED',
          b['settleMode'] == 'at_market' ? 'This bucket is book-and-meet: you pay at the market.' : 'This bucket needs a UPI hold.');
    }
    final filled = _filled(b);
    List? unitIds;
    num? qty;
    List? items;
    int est;
    switch (b['type']) {
      case 'split':
        unitIds = (body['unitIds'] as List?)?.map((e) => '$e').toList();
        if (unitIds == null || unitIds.isEmpty) throw const _Fail(400, 'BAD_REQUEST', 'Pick at least one part (unitIds).');
        final maxU = b['maxUnitsPerMember'] as num?;
        if (maxU != null && unitIds.length > maxU) throw _Fail(400, 'QTY_TOO_HIGH', 'You can take at most $maxU parts.');
        for (final id in unitIds) {
          final u = _unit(b, id);
          if (u == null) throw _Fail(400, 'UNKNOWN_UNIT', 'There is no part "$id" in this bucket.');
          if (u['owner'] != null) throw _Fail(409, 'UNIT_TAKEN', '${u['label']} was just taken by a neighbour.');
        }
        qty = unitIds.length;
        est = _splitPrice(b, unitIds);
      case 'trip':
        items = ((body['items'] as List?) ?? const []).cast<Map>().map((it) => {'id': '${it['id']}', 'qty': it['qty']}).toList();
        if (items.isEmpty) throw const _Fail(400, 'BAD_REQUEST', 'Add at least one item.');
        final kg = _itemsKg(b, items);
        final cap = (b['capacity'] as num?) ?? double.infinity;
        if (filled + kg > cap) throw _Fail(409, 'CAPACITY_FULL', 'The vehicle has room for ${max(0, cap - filled).round()} kg more.');
        final fee = (b['transportFee'] as num?) ?? 0;
        est = _itemsGoods(b, items) + (fee * kg / max(filled + kg, (b['minLoadKg'] as num?) ?? 1)).round();
        qty = kg;
      default:
        final q = body['qty'];
        qty = q is num ? q : num.tryParse('$q');
        if (qty == null || qty <= 0) throw const _Fail(400, 'BAD_REQUEST', 'qty must be a whole number above 0.');
        final mn = b['minQty'] as num?;
        final mx = b['maxQty'] as num?;
        if (mn != null && qty < mn) throw _Fail(400, 'QTY_TOO_LOW', 'The minimum is $mn ${b['unitLabel']}.');
        if (mx != null && qty > mx) throw _Fail(400, 'QTY_TOO_HIGH', 'The maximum per member is $mx ${b['unitLabel']}.');
        final lot = b['lotQty'] as num?;
        if (lot != null && filled + qty > lot) {
          throw _Fail(409, 'SOLD_OUT', lot - filled > 0 ? 'Only ${lot - filled} ${b['unitLabel']} left.' : 'This lot is fully claimed.');
        }
        est = (qty * _unitPriceAt(b, filled + qty)).round();
    }
    final user = st['user'] as Map;
    final now = _rawNow();
    final hold = payMode == 'hold' ? {'id': _id('h'), 'amount': est, 'status': 'created', 'vpa': null} : null;
    final share = <String, dynamic>{
      'id': _id('s'), 'bucketId': b['id'], 'user': {'id': user['id'], 'name': user['name'], 'unit': unit},
      'qty': qty, 'qtyLabel': '', 'unitIds': unitIds, 'items': items, 'options': body['options'], 'payMode': payMode,
      'status': payMode == 'hold' ? 'pending_payment' : 'booked', 'createdAt': now,
      'estAmount': est, 'finalAmount': null, 'hold': hold, 'otp': null, 'orderId': null, 'savings': null,
    };
    b['myShare'] = share;
    _syncPublic(b, share);
    _refresh(b);
    if (share['status'] == 'booked' && _isFilled(b)) _lock(st, b);
    _put(st, b);
    return {'share': b['myShare'], 'bucket': b};
  }

  Object? _authorize(Map<String, dynamic> st, String holdId, Map<String, dynamic> body) {
    final b = _allBuckets(st).where((x) => (x['myShare'] as Map?)?['hold']?['id'] == holdId).firstOrNull;
    if (b == null) throw const _Fail(404, 'NOT_FOUND', 'No such payment hold.');
    final s = b['myShare'] as Map;
    final h = s['hold'] as Map;
    if (h['status'] != 'created') throw _Fail(409, 'INVALID_HOLD_STATE', 'This payment is already ${h['status']}.');
    if (b['status'] != 'live' || s['status'] != 'pending_payment') {
      throw const _Fail(409, 'BUCKET_CLOSED', 'This bucket is closed, so nothing was blocked.');
    }
    final pin = '${body['pin'] ?? ''}';
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) throw const _Fail(400, 'INVALID_PIN', 'Enter your 4–6 digit UPI PIN.');
    if (pin == '0000') throw const _Fail(400, 'PIN_INCORRECT', 'Incorrect UPI PIN. No money was blocked.');
    final vpa = '${body['vpa'] ?? ''}'.trim();
    if (!RegExp(r'^[\w.-]+@[a-zA-Z][\w]{1,}$').hasMatch(vpa)) throw const _Fail(400, 'INVALID_VPA', 'Enter a UPI ID like name@okaxis.');
    final now = _rawNow();
    h
      ..['status'] = 'held'
      ..['vpa'] = vpa
      ..['heldAt'] = now;
    s['status'] = 'held';
    final p = b['progress'] as Map;
    p['held'] = ((p['held'] as num?) ?? 0) + (h['amount'] as num);
    final w = _wallet(st);
    (w['entries'] as List).insert(0, {
      'shareId': s['id'], 'bucketId': b['id'], 'title': b['title'], 'image': b['image'], 'orderId': null,
      'id': '${h['id']}_held', 'kind': 'held', 'amount': h['amount'], 'savings': 0, 'at': now,
    });
    _bump(w, 'heldNow', h['amount'] as num);
    _syncPublic(b, s);
    _refresh(b);
    if (_isFilled(b)) _lock(st, b);
    _put(st, b);
    return {'share': b['myShare'], 'bucket': b};
  }

  Object? _leave(Map<String, dynamic> st, String shareId) {
    final b = _allBuckets(st).where((x) => (x['myShare'] as Map?)?['id'] == shareId).firstOrNull;
    if (b == null) throw const _Fail(404, 'NOT_FOUND', 'No such share.');
    final s = b['myShare'] as Map;
    if (b['status'] != 'live' || !['pending_payment', 'held', 'booked'].contains(s['status'])) {
      throw const _Fail(409, 'SHARE_LOCKED', 'This share is locked into an order and cannot be cancelled.');
    }
    _release(st, b, s);
    s['status'] = 'left';
    _syncPublic(b, s);
    b['myShare'] = null;
    _refresh(b);
    _put(st, b);
    return {'bucket': b};
  }

  void _release(Map<String, dynamic> st, Map b, Map s) {
    final h = s['hold'] as Map?;
    if (h == null || !(h['status'] == 'created' || h['status'] == 'held')) return;
    final wasHeld = h['status'] == 'held';
    final now = _rawNow();
    h
      ..['status'] = 'released'
      ..['releasedAt'] = now;
    if (!wasHeld) return;
    final p = b['progress'] as Map;
    p['held'] = max(0, ((p['held'] as num?) ?? 0) - (h['amount'] as num));
    final w = _wallet(st);
    final entries = w['entries'] as List;
    entries.removeWhere((e) => (e as Map)['id'] == '${h['id']}_held');
    entries.insert(0, {
      'shareId': s['id'], 'bucketId': b['id'], 'title': b['title'], 'image': b['image'], 'orderId': null,
      'id': '${h['id']}_released', 'kind': 'released', 'amount': h['amount'], 'savings': 0, 'at': now,
    });
    _bump(w, 'heldNow', -(h['amount'] as num));
    _bump(w, 'releasedThisMonth', h['amount'] as num);
  }

  Object? _close(Map<String, dynamic> st, String bucketId) {
    final b = _bucket(st, bucketId);
    if (b['status'] != 'live') throw _Fail(409, 'BUCKET_CLOSED', 'This bucket is already ${b['status']}.');
    final committed = ((b['shares'] as List?) ?? const []).cast<Map>().where((s) => _committed.contains(s['status']));
    Map? order;
    if (committed.isNotEmpty && _filled(b) >= _goAt(b)) {
      order = _lock(st, b);
    } else {
      final s = b['myShare'] as Map?;
      if (s != null && _active.contains(s['status'])) {
        _release(st, b, s);
        s['status'] = 'released';
      }
      for (final x in ((b['shares'] as List?) ?? const []).cast<Map>()) {
        x['status'] = 'released';
      }
      b['shares'] = [];
      b['status'] = 'expired';
      b['closedAt'] = _rawNow();
      _refresh(b);
    }
    _put(st, b);
    return {'bucket': b, 'order': order};
  }

  String _otp(Set<String> used) {
    while (true) {
      final o = '${1000 + _rng.nextInt(9000)}';
      if (used.add(o)) return o;
    }
  }

  /// The bucket goes ahead: one order line per committed share, holds captured, my OTP issued.
  Map _lock(Map<String, dynamic> st, Map b) {
    final now = _rawNow();
    final shares = ((b['shares'] as List?) ?? const []).cast<Map>();
    final committed = shares.where((s) => _committed.contains(s['status'])).toList();
    final price = _unitPriceAt(b, _filled(b));
    final fee = (b['transportFee'] as num?) ?? 0;
    final totalKg = b['type'] == 'trip' ? committed.fold<num>(0, (n, s) => n + _itemsKg(b, s['items'] as List?)) : 0;
    final mine = b['myShare'] as Map?;
    final user = st['user'] as Map;
    final used = <String>{};
    final orderId = 'JS-${7000 + _rng.nextInt(2999)}';
    final lines = <Map<String, dynamic>>[];
    for (final s in committed) {
      int amount;
      int? transport;
      if (b['type'] == 'split') {
        amount = _splitPrice(b, (s['unitIds'] as List?) ?? const []);
      } else if (b['type'] == 'trip') {
        final kg = _itemsKg(b, s['items'] as List?);
        transport = totalKg == 0 ? 0 : (fee * kg / totalKg).round();
        amount = _itemsGoods(b, s['items'] as List?) + transport;
      } else {
        amount = (((s['qty'] as num?) ?? 0) * price).round();
      }
      final isMine = mine != null && s['id'] == mine['id'];
      final num? held = isMine ? ((mine['hold'] as Map?)?['amount'] as num?) : null;
      if (s['payMode'] == 'hold' && held != null) amount = min(amount, held.toInt());
      lines.add({
        'shareId': s['id'], 'userId': (s['user'] as Map)['id'], 'name': (s['user'] as Map)['name'], 'unit': (s['user'] as Map)['unit'],
        'qty': s['qty'], 'qtyLabel': _qtyLabel(b, s), 'amount': amount, 'transport': ?transport,
        'payMode': s['payMode'], 'paymentStatus': s['payMode'] == 'hold' ? 'captured' : 'due',
        'otp': isMine ? _otp(used) : null, 'collected': false, 'options': s['options'], 'savings': max(0, _retail(b, s) - amount),
      });
    }
    int sum(bool Function(Map) f) => lines.where(f).fold<int>(0, (n, l) => n + (l['amount'] as int));
    final myLine = lines.where((l) => l['userId'] == user['id']).firstOrNull;
    final order = <String, dynamic>{
      'id': orderId, 'bucketId': b['id'], 'communityId': b['communityId'], 'vendorId': (b['vendor'] as Map?)?['id'],
      'title': b['title'], 'image': b['image'], 'total': sum((_) => true), 'heldTotal': sum((l) => l['payMode'] == 'hold'),
      'atPickupTotal': sum((l) => l['payMode'] == 'at_market'), 'status': 'created', 'createdAt': now,
      'pickupPoint': (b['meet'] as Map?)?['place'] ?? b['pickupPoint'] ?? '', 'window': b['pickupPoint'] ?? '',
      'lines': lines, 'groupId': b['groupId'], 'myLine': myLine,
    };
    for (final s in committed) {
      if (s['payMode'] == 'hold') s['status'] = 'captured';
    }
    b['shares'] = committed;
    if (mine != null && myLine != null) {
      final amount = myLine['amount'] as int;
      mine
        ..['finalAmount'] = amount
        ..['otp'] = myLine['otp']
        ..['orderId'] = orderId
        ..['savings'] = myLine['savings'];
      final h = mine['hold'] as Map?;
      final w = _wallet(st);
      final entries = w['entries'] as List;
      if (mine['payMode'] == 'hold' && h != null) {
        mine['status'] = 'captured';
        h
          ..['status'] = 'captured'
          ..['capturedAmount'] = amount
          ..['capturedAt'] = now;
        entries.removeWhere((e) => (e as Map)['id'] == '${h['id']}_held');
        entries.insert(0, {
          'shareId': mine['id'], 'bucketId': b['id'], 'title': b['title'], 'image': b['image'], 'orderId': orderId,
          'id': '${h['id']}_paid', 'kind': 'paid', 'amount': amount, 'heldAmount': h['amount'], 'savings': myLine['savings'], 'at': now,
        });
        _bump(w, 'heldNow', -(h['amount'] as num));
        _bump(w, 'paidThisMonth', amount);
      } else {
        entries.insert(0, {
          'shareId': mine['id'], 'bucketId': b['id'], 'title': b['title'], 'image': b['image'], 'orderId': orderId,
          'id': '${mine['id']}_market', 'kind': 'at_market', 'amount': amount, 'savings': myLine['savings'], 'at': now,
        });
      }
      _bump(w, 'savedTotal', myLine['savings'] as num);
      _bump(w, 'savedThisMonth', myLine['savings'] as num);
      final p = b['progress'] as Map;
      if (h != null) p['held'] = max(0, ((p['held'] as num?) ?? 0) - (h['amount'] as num));
      _syncPublic(b, mine);
    }
    b['status'] = b['settleMode'] == 'at_market' ? 'market_day' : 'ordered';
    b['orderId'] = orderId;
    b['closedAt'] = now;
    _refresh(b);
    final get = _get(st);
    get['/api/orders/$orderId'] = order;
    if (myLine != null) (get['/api/me/orders'] as List).insert(0, order);
    return order;
  }

  Object? _checkin(Map<String, dynamic> st, String shareId) {
    final b = _allBuckets(st).where((x) => (x['myShare'] as Map?)?['id'] == shareId).firstOrNull;
    if (b == null) throw const _Fail(404, 'NOT_FOUND', 'No such share.');
    final s = b['myShare'] as Map;
    if (!['ordered', 'market_day', 'delivering'].contains(b['status']) || !['booked', 'captured'].contains(s['status'])) {
      throw const _Fail(409, 'BAD_STATE', 'You can check in once the bucket is confirmed.');
    }
    s['status'] = 'checked_in';
    _syncPublic(b, s);
    _put(st, b);
    return {'share': s, 'bucket': b};
  }

  // ---- vendor ---------------------------------------------------------------------------------

  Object? _handover(Map<String, dynamic> st, String orderId, Map<String, dynamic> body) {
    final get = _get(st);
    final o = get['/api/orders/$orderId'] as Map?;
    if (o == null) throw const _Fail(404, 'NOT_FOUND', 'No such order.');
    final otp = '${body['otp'] ?? ''}'.trim();
    final known = ((_snap['otps'] as Map?)?[orderId] as Map?) ?? const {};
    final line = (o['lines'] as List).cast<Map>().where((l) => l['otp'] == otp || known[l['userId']] == otp).firstOrNull;
    if (line == null) throw const _Fail(400, 'OTP_INVALID', 'That OTP does not match anyone in this order.');
    if (line['collected'] == true) throw _Fail(409, 'ALREADY_COLLECTED', '${line['name']} has already collected.');
    line
      ..['collected'] = true
      ..['collectedAt'] = _rawNow();
    if (line['payMode'] == 'at_market') line['paymentStatus'] = 'paid';
    final all = (o['lines'] as List).cast<Map>().every((l) => l['collected'] == true);
    if (all) o['status'] = 'delivered';
    final b = get['/api/buckets/${o['bucketId']}'] as Map?;
    if (b != null) b['status'] = all ? 'completed' : 'delivering';
    final dash = get['/api/vendor/dashboard'] as Map?;
    if (dash != null) {
      for (final g in ((dash['packing'] as List?) ?? const []).cast<Map>()) {
        for (final l in ((g['lines'] as List?) ?? const []).cast<Map>()) {
          if (l['orderId'] == orderId && l['userId'] == line['userId']) {
            l['collected'] = true;
            if (l['payMode'] == 'at_market') l['paymentStatus'] = 'paid';
          }
        }
      }
      for (final x in ((dash['buckets'] as List?) ?? const []).cast<Map>()) {
        if (x['id'] == o['bucketId'] && b != null) x['status'] = b['status'];
      }
    }
    return {'order': o};
  }

  // ---- create bucket -------------------------------------------------------------------------

  Object? _create(Map<String, dynamic> st, Map<String, dynamic> d0) {
    final d = (_shift(d0, -_delta) as Map).cast<String, dynamic>();
    DateTime? rawTime(Object? v) => DateTime.tryParse('${v ?? ''}')?.toUtc().subtract(_delta);
    final cid = '${d['communityId'] ?? ''}';
    if (_get(st)['/api/communities/$cid'] == null) throw const _Fail(400, 'BAD_REQUEST', 'communityId is not a known community.');
    final unit = _unitOf(st, cid);
    final type = '${d['type'] ?? ''}';
    if (!{'split', 'bulk', 'service', 'trip'}.contains(type)) throw const _Fail(400, 'BAD_REQUEST', 'type must be split, bulk, service or trip.');
    final title = '${d['title'] ?? ''}'.trim();
    if (title.isEmpty) throw const _Fail(400, 'BAD_REQUEST', 'Give the bucket a title.');
    final cutoff = rawTime(d0['cutoffAt']);
    if (cutoff == null) throw const _Fail(400, 'BAD_REQUEST', 'cutoffAt must be a future time.');
    int whole(Object? v) => v is num ? v.round() : int.tryParse('$v') ?? 0;
    List? units;
    List? tiers;
    List? items;
    if (type == 'split') {
      final us = (d['units'] as List?) ?? const [];
      if (us.isEmpty) throw const _Fail(400, 'BAD_REQUEST', 'A split bucket needs units.');
      var i = 0;
      units = us.cast<Map>().map((u) {
        i++;
        return {'id': '${u['id'] ?? 'u$i'}', 'label': '${u['label'] ?? 'Share $i'}', 'grams': u['grams'], 'price': whole(u['price']), 'owner': null};
      }).toList();
    } else if (type == 'bulk' || type == 'service') {
      final ts = (d['tiers'] as List?) ?? const [];
      if (ts.isEmpty) throw const _Fail(400, 'BAD_REQUEST', 'Bulk and service buckets need price tiers.');
      tiers = ts.cast<Map>().map((t) => {'minQty': t['minQty'], 'unitPrice': whole(t['unitPrice'])}).toList()
        ..sort((a, b) => (a['minQty'] as num).compareTo(b['minQty'] as num));
    } else {
      final its = (d['items'] as List?) ?? const [];
      if (its.isEmpty) throw const _Fail(400, 'BAD_REQUEST', 'A trip needs a list of items.');
      var i = 0;
      items = its.cast<Map>().map((it) {
        i++;
        return {
          'id': '${it['id'] ?? 'i$i'}', 'name': '${it['name'] ?? 'Item $i'}', 'unit': it['unit'] ?? 'kg', 'price': whole(it['price']),
          'kgPerUnit': it['kgPerUnit'] ?? 1, 'retailPrice': it['retailPrice'], 'qty': 0, 'members': 0,
        };
      }).toList();
    }
    Map? vendor;
    final vid = d['vendorId'];
    for (final x in [..._allBuckets(st), for (final r in _users.values) ...((r['get'] as Map).values.whereType<Map>())]) {
      final v = x['vendor'] as Map?;
      if (v != null && vid != null && v['id'] == vid) {
        vendor = v;
        break;
      }
    }
    final user = st['user'] as Map;
    const defUnit = {'split': 'share', 'bulk': 'kg', 'service': 'flat', 'trip': 'kg'};
    final capacity = type == 'trip' ? (d['capacity'] as num?) ?? 100 : null;
    final b = <String, dynamic>{
      'id': 'b_${_hex(6)}', 'communityId': cid, 'type': type, 'category': d['category'] ?? 'other', 'title': title,
      'subtitle': d['subtitle'] ?? '', 'image': d['image'] ?? d['category'] ?? type, 'vendor': vendor,
      'createdBy': {'id': user['id'], 'name': user['name'], 'unit': unit}, 'settleMode': d['settleMode'] ?? 'hold',
      'meet': d['meet'], 'cutoffAt': cutoff.toUtc().toIso8601String(),
      'deliverAt': (rawTime(d0['deliverAt']) ?? cutoff.add(const Duration(hours: 12))).toIso8601String(),
      'pickupPoint': d['pickupPoint'] ?? 'Main gate', 'unitLabel': d['unitLabel'] ?? defUnit[type],
      'retailUnitPrice': d['retailUnitPrice'], 'unitPrice': d['unitPrice'], 'netWeight': d['netWeight'], 'serves': d['serves'],
      'description': d['description'], 'units': units, 'tiers': tiers, 'items': items, 'capacity': capacity,
      'minLoadKg': (type == 'trip' ? (d['minLoadKg'] ?? (capacity! / 2).round()) : null),
      'transportFee': type == 'trip' ? whole(d['transportFee']) : null,
      'minQty': d['minQty'], 'maxQty': d['maxQty'], 'lotQty': d['lotQty'], 'maxUnitsPerMember': d['maxUnitsPerMember'],
      'optionGroups': d['optionGroups'], 'status': 'live', 'cardMessageId': null, 'orderId': null, 'createdAt': _rawNow(),
      'progress': {'held': 0}, 'groupId': null, 'myShare': null, 'shares': [],
    };
    _refresh(b);
    _put(st, b);
    return b;
  }
}

class _Fail implements Exception {
  const _Fail(this.status, this.code, this.message);
  final int status;
  final String code;
  final String message;
}
