import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../nexconn/nexconn_service.dart';

/// Phase of the one call this device can be in.
enum CallPhase { idle, outgoing, incoming, connecting, connected, ended }

/// Snapshot of the current call, for the call screen.
@immutable
class CallInfo {
  const CallInfo({
    this.phase = CallPhase.idle,
    this.callId,
    this.video = false,
    this.group = false,
    this.peerIds = const [],
    this.title = '',
    this.groupId,
    this.connectedAt,
    this.endReason,
    this.errorCode,
    this.errorName,
    this.muted = false,
    this.speaker = false,
    this.cameraOn = true,
    this.ringing = false,
  });

  final CallPhase phase;
  final String? callId;
  final bool video;
  final bool group;

  /// Remote user ids (the callee, the caller, or the group members).
  final List<String> peerIds;
  final String title;
  final String? groupId;
  final DateTime? connectedAt;
  final String? endReason;

  /// Call SDK status code when an API call failed (e.g. 80006 VOIP_SERVICE_UNAVAILABLE).
  final int? errorCode;
  final String? errorName;
  final bool muted;
  final bool speaker;
  final bool cameraOn;

  /// Outgoing: the callee's device is ringing.
  final bool ringing;

  bool get active => phase != CallPhase.idle && phase != CallPhase.ended;

  CallInfo copyWith({
    CallPhase? phase,
    String? callId,
    bool? video,
    bool? group,
    List<String>? peerIds,
    String? title,
    String? groupId,
    DateTime? connectedAt,
    String? endReason,
    int? errorCode,
    String? errorName,
    bool? muted,
    bool? speaker,
    bool? cameraOn,
    bool? ringing,
  }) =>
      CallInfo(
        phase: phase ?? this.phase,
        callId: callId ?? this.callId,
        video: video ?? this.video,
        group: group ?? this.group,
        peerIds: peerIds ?? this.peerIds,
        title: title ?? this.title,
        groupId: groupId ?? this.groupId,
        connectedAt: connectedAt ?? this.connectedAt,
        endReason: endReason ?? this.endReason,
        errorCode: errorCode ?? this.errorCode,
        errorName: errorName ?? this.errorName,
        muted: muted ?? this.muted,
        speaker: speaker ?? this.speaker,
        cameraOn: cameraOn ?? this.cameraOn,
        ringing: ringing ?? this.ringing,
      );
}

/// Nexconn Call SDK (native Android, via `jugaad/call`) for 1-to-1 and group voice/video calls.
///
/// The SDK is initialised once the Nexconn chat connects (it reuses that IM connection). [incoming] fires when
/// someone calls us; [info] tracks the current call for the call screen.
class CallService {
  CallService(this.nexconn) {
    _events.receiveBroadcastStream().listen(_onEvent, onError: (Object e) => debugPrint('[call] events error $e'));
    nexconn.state.addListener(_maybeInit);
    _maybeInit();
  }

  final NexconnService nexconn;

  static const _ch = MethodChannel('jugaad/call');
  static const _events = EventChannel('jugaad/call/events');

  /// Set by the app root; used by entry points that have no BuildContext of their own.
  static CallService? instance;

  final info = ValueNotifier<CallInfo>(const CallInfo());
  final _incoming = StreamController<CallInfo>.broadcast();
  Stream<CallInfo> get incoming => _incoming.stream;

  String? _initedFor;
  String? sdkVersion;

  bool get supported => defaultTargetPlatform == TargetPlatform.android && !kIsWeb;

  Future<void> _maybeInit() async {
    if (!supported || !nexconn.isConnected) return;
    final uid = nexconn.userId;
    if (uid == null) {
      // The SDK reports "connected" a moment before connect() records the user id: try again shortly.
      Future.delayed(const Duration(milliseconds: 500), _maybeInit);
      return;
    }
    if (uid == _initedFor) return;
    _initedFor = uid;
    try {
      final r = await _ch.invokeMapMethod<String, Object?>('init', {'userId': uid});
      sdkVersion = r?['version'] as String?;
      debugPrint('[call] Nexconn Call SDK init -> $r');
    } catch (e) {
      _initedFor = null;
      debugPrint('[call] init failed: $e');
    }
  }

  Future<bool> _permissions(bool video) async {
    try {
      return await _ch.invokeMethod<bool>('permissions', {'video': video}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 1-to-1 call. Returns null when placed, else a reason to show.
  Future<String?> call(String userId, {required String title, bool video = false}) =>
      _start(peers: [userId], title: title, video: video, group: false);

  /// Group call with [userIds] (excluding ourselves), bound to the group channel [groupId].
  Future<String?> groupCall(String groupId, List<String> userIds, {required String title, bool video = false}) =>
      _start(peers: userIds, title: title, video: video, group: true, groupId: groupId);

  Future<String?> _start({
    required List<String> peers,
    required String title,
    required bool video,
    required bool group,
    String? groupId,
  }) async {
    if (!supported) return 'Calls work in the Android app.';
    if (info.value.active) return 'You are already on a call.';
    final me = nexconn.userId;
    final ids = peers.where((p) => p.isNotEmpty && p != me).toSet().toList();
    if (ids.isEmpty) return group ? 'Nobody else is in this group yet.' : 'Nobody to call.';
    if (!nexconn.isConnected) return 'Chat is still connecting. Try again in a moment.';
    await _maybeInit();
    if (!await _permissions(video)) return 'Allow the microphone${video ? ' and camera' : ''} to call.';
    info.value = CallInfo(
      phase: CallPhase.outgoing,
      video: video,
      group: group,
      peerIds: ids,
      title: title,
      groupId: groupId,
      speaker: video,
    );
    try {
      if (group) {
        await _ch.invokeMethod('startGroupCall', {'groupId': groupId, 'userIds': ids, 'video': video});
      } else {
        await _ch.invokeMethod('startCall', {'targetUserId': ids.first, 'video': video});
      }
      if (video) unawaited(_ch.invokeMethod('speaker', {'on': true}));
      return null;
    } on PlatformException catch (e) {
      info.value = info.value.copyWith(phase: CallPhase.ended, errorCode: int.tryParse(e.code), errorName: e.message);
      return 'Call failed: ${e.message} (${e.code})';
    }
  }

  Future<String?> accept() async {
    final c = info.value;
    if (c.phase != CallPhase.incoming) return null;
    if (!await _permissions(c.video)) return 'Allow the microphone${c.video ? ' and camera' : ''} to answer.';
    info.value = c.copyWith(phase: CallPhase.connecting);
    try {
      await _ch.invokeMethod('accept', {'callId': c.callId});
    } on PlatformException catch (e) {
      info.value = c.copyWith(phase: CallPhase.ended, errorCode: int.tryParse(e.code), errorName: e.message);
      return 'Could not answer: ${e.message}';
    }
    return null;
  }

  Future<void> hangup() async {
    final c = info.value;
    try {
      await _ch.invokeMethod('hangup', {'callId': c.callId});
    } catch (_) {}
    if (c.phase != CallPhase.ended) info.value = c.copyWith(phase: CallPhase.ended, endReason: c.endReason ?? 'HANGUP');
  }

  Future<void> setMuted(bool muted) async {
    info.value = info.value.copyWith(muted: muted);
    try {
      await _ch.invokeMethod('mute', {'muted': muted});
    } catch (_) {}
  }

  Future<void> setSpeaker(bool on) async {
    info.value = info.value.copyWith(speaker: on);
    try {
      await _ch.invokeMethod('speaker', {'on': on});
    } catch (_) {}
  }

  Future<void> setCamera(bool on) async {
    info.value = info.value.copyWith(cameraOn: on);
    try {
      await _ch.invokeMethod('camera', {'on': on});
    } catch (_) {}
  }

  Future<void> switchCamera() async {
    try {
      await _ch.invokeMethod('switchCamera');
    } catch (_) {}
  }

  /// Clears an ended call (after the screen closed).
  void reset() {
    if (!info.value.active) info.value = const CallInfo();
  }

  List<String> _participants(Map m) => [
        for (final p in (m['participants'] as List? ?? const []))
          if (p is Map && p['userId'] is String) p['userId'] as String,
      ];

  void _onEvent(dynamic raw) {
    if (raw is! Map) return;
    final type = raw['type'];
    final c = info.value;
    debugPrint('[call] event $raw');
    switch (type) {
      case 'incoming':
        if (c.active && c.callId != raw['callId']) return; // the SDK reports busy to the caller
        final caller = (raw['callerUserId'] ?? raw['inviterUserId']) as String?;
        final group = raw['callType'] == 'MULTI';
        final peers = {?caller, ..._participants(raw)}.where((p) => p != nexconn.userId).toList();
        final next = CallInfo(
          phase: CallPhase.incoming,
          callId: raw['callId'] as String?,
          video: raw['video'] == true,
          group: group,
          peerIds: peers,
          title: '',
          speaker: raw['video'] == true,
        );
        info.value = next;
        _incoming.add(next);
      case 'startResult':
        final code = raw['code'] as int? ?? -1;
        if (code != 0) {
          info.value = c.copyWith(phase: CallPhase.ended, errorCode: code, errorName: raw['codeName'] as String?);
        } else {
          info.value = c.copyWith(callId: raw['callId'] as String?);
        }
      case 'acceptResult':
        final code = raw['code'] as int? ?? -1;
        if (code != 0) {
          info.value = c.copyWith(phase: CallPhase.ended, errorCode: code, errorName: raw['codeName'] as String?);
        }
      case 'remoteState':
        final s = raw['state'] as String?;
        if (s == 'RINGING' || s == 'BUSY_LINE_RINGING') info.value = c.copyWith(ringing: true);
      case 'connected':
        final peers = _participants(raw);
        info.value = c.copyWith(
          phase: CallPhase.connected,
          callId: raw['callId'] as String?,
          connectedAt: c.connectedAt ?? DateTime.now(),
          peerIds: peers.isEmpty ? c.peerIds : {...c.peerIds, ...peers}.toList(),
        );
        if (c.video) {
          unawaited(_ch.invokeMethod('camera', {'on': true}));
          unawaited(_ch.invokeMethod('speaker', {'on': c.speaker}));
        }
      case 'ended':
        if (c.phase == CallPhase.idle) return;
        info.value = c.copyWith(phase: CallPhase.ended, endReason: raw['reason'] as String?);
      case 'endResult':
        break;
    }
  }
}
