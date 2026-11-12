import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../models/models.dart';

/// Who is logged in and which community they're in. Persisted with
/// shared_preferences. Listen to it (it's a ChangeNotifier); the router
/// redirects on changes.
class SessionStore extends ChangeNotifier {
  SessionStore(this._prefs, this.api) {
    _load();
    api.onUnauthorized = () {
      if (isLoggedIn && !isDev) logout();
    };
  }

  static Future<SessionStore> open(ApiClient api) async =>
      SessionStore(await SharedPreferences.getInstance(), api);

  final SharedPreferences _prefs;
  final ApiClient api;

  static const _kToken = 'session.token';
  static const _kUser = 'session.user';
  static const _kNexconn = 'session.nexconn';
  static const _kCommunity = 'session.community';
  static const _kUnit = 'session.unit';
  static const _kRole = 'session.role';
  static const _kOnboarded = 'session.onboarded';

  String? _token;
  User? _user;
  NexconnCreds? _nexconn;
  Community? _community;
  String? _unit;
  String _role = 'member';
  bool _onboarded = false;
  bool _dev = false;

  String? get token => _token;
  User? get user => _user;
  NexconnCreds? get nexconn => _nexconn;
  Community? get community => _community;
  String? get unit => _unit;
  String get role => _role;
  bool get isAdmin => _role == 'admin';
  bool get onboarded => _onboarded;

  /// Logged in with `--dart-define=DEV_NEXCONN_TOKEN` (no server session).
  bool get isDev => _dev;

  bool get isLoggedIn => (_token != null && _token!.isNotEmpty) || _dev;
  bool get hasCommunity => _community != null;

  /// The Street chat group for the current community.
  String? get streetChannelId => _dev && _community == null ? AppConfig.devChannelId : _community?.streetChannelId;

  void _load() {
    _token = _prefs.getString(_kToken);
    _user = _decode(_kUser, User.fromJson);
    _nexconn = _decode(_kNexconn, NexconnCreds.fromJson);
    _community = _decode(_kCommunity, Community.fromJson);
    _unit = _prefs.getString(_kUnit);
    _role = _prefs.getString(_kRole) ?? 'member';
    _onboarded = _prefs.getBool(_kOnboarded) ?? false;
    api.token = _token;

    if (!isLoggedIn && AppConfig.hasDevToken) {
      _dev = true;
      _onboarded = true;
      _user = const User(id: 'dev', name: 'Dev user');
      _nexconn = const NexconnCreds(appKey: AppConfig.nexconnAppKey, token: AppConfig.devNexconnToken, userId: '');
      _community = const Community(id: 'dev', name: AppConfig.devChannelId);
    }
  }

  T? _decode<T>(String key, T Function(Json) f) {
    final s = _prefs.getString(key);
    if (s == null) return null;
    try {
      return f((jsonDecode(s) as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Future<void> markOnboarded() async {
    _onboarded = true;
    await _prefs.setBool(_kOnboarded, true);
    notifyListeners();
  }

  /// Saves the result of `/api/auth/verify`.
  Future<void> signIn(AuthResult r) async {
    _dev = false;
    _token = r.sessionToken;
    _user = r.user;
    _nexconn = r.nexconn;
    api.token = _token;
    await _prefs.setString(_kToken, r.sessionToken);
    await _prefs.setString(_kUser, jsonEncode(r.user.toJson()));
    await _prefs.setString(_kNexconn, jsonEncode(r.nexconn.toJson()));
    notifyListeners();
  }

  /// Sets the active community (after join, or from `/api/me` memberships).
  Future<void> setCommunity(Community c, {String? unit, String role = 'member'}) async {
    _community = c;
    _unit = unit;
    _role = role;
    await _prefs.setString(_kCommunity, jsonEncode(c.raw.isEmpty ? {'id': c.id, 'name': c.name} : c.raw));
    if (unit != null) await _prefs.setString(_kUnit, unit);
    await _prefs.setString(_kRole, role);
    notifyListeners();
  }

  Future<void> logout() async {
    _dev = false;
    _token = null;
    _user = null;
    _nexconn = null;
    _community = null;
    _unit = null;
    _role = 'member';
    api.token = null;
    for (final k in [_kToken, _kUser, _kNexconn, _kCommunity, _kUnit, _kRole]) {
      await _prefs.remove(k);
    }
    notifyListeners();
  }
}
