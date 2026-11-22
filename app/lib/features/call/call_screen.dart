import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/call/call_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../router.dart';
import '../chat/chat_avatar.dart';
import '../chat/chat_directory.dart';

/// Opens the call screen on the root navigator (outgoing or incoming).
void showCallScreen(CallService calls) {
  final nav = rootNavigatorKey.currentState;
  if (nav == null || _CallScreenState._open) return;
  nav.push(PageRouteBuilder<void>(
    opaque: true,
    fullscreenDialog: true,
    pageBuilder: (_, _, _) => CallScreen(calls: calls),
    transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
  ));
}

/// Places a 1-to-1 call from a chat and shows the call screen; reports a reason as a snackbar if it can't.
Future<void> startDirectCall(BuildContext context, String userId, {required String title, bool video = false}) async {
  final calls = CallService.instance;
  if (calls == null) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final err = await calls.call(userId, title: title, video: video);
  if (err != null) {
    messenger?.showSnackBar(SnackBar(content: Text(err)));
    return;
  }
  showCallScreen(calls);
}

/// Places a group call with [userIds] for the group channel [groupId].
Future<void> startGroupCall(BuildContext context, String groupId, Future<List<String>> userIds,
    {required String title, bool video = false}) async {
  final calls = CallService.instance;
  if (calls == null) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final ids = await userIds;
  final err = await calls.groupCall(groupId, ids, title: title, video: video);
  if (err != null) {
    messenger?.showSnackBar(SnackBar(content: Text(err)));
    return;
  }
  showCallScreen(calls);
}

/// Full-screen call UI: who, status ("Calling…", "Ringing", "00:12"), mute / speaker / camera, end.
/// Incoming calls show Accept / Decline first.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.calls});

  final CallService calls;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  static bool _open = false;
  Timer? _tick;
  bool _closing = false;

  CallService get _calls => widget.calls;

  @override
  void initState() {
    super.initState();
    _open = true;
    _calls.info.addListener(_changed);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _calls.info.value.phase == CallPhase.connected) setState(() {});
    });
  }

  @override
  void dispose() {
    _open = false;
    _tick?.cancel();
    _calls.info.removeListener(_changed);
    _calls.reset();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    final c = _calls.info.value;
    if (c.phase == CallPhase.ended && !_closing) {
      _closing = true;
      // Leave the end state (or the SDK error code) visible for a moment.
      Future.delayed(Duration(milliseconds: c.errorCode != null ? 3500 : 1400), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  String _status(CallInfo c) {
    switch (c.phase) {
      case CallPhase.idle:
        return '';
      case CallPhase.outgoing:
        return c.ringing ? 'Ringing…' : 'Calling…';
      case CallPhase.incoming:
        return c.group
            ? 'Incoming group ${c.video ? 'video' : 'voice'} call'
            : 'Incoming ${c.video ? 'video' : 'voice'} call';
      case CallPhase.connecting:
        return 'Connecting…';
      case CallPhase.connected:
        final d = DateTime.now().difference(c.connectedAt ?? DateTime.now());
        final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
        final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
        return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
      case CallPhase.ended:
        if (c.errorCode != null) return 'Call failed · ${c.errorName ?? 'error'} (${c.errorCode})';
        return switch (c.endReason) {
          'REMOTE_REJECT' || 'REMOTE_BUSY_LINE' => 'Declined',
          'NO_ANSWER' || 'REMOTE_NO_ANSWER' => 'No answer',
          _ => 'Call ended',
        };
    }
  }

  String _title(BuildContext context, CallInfo c) {
    if (c.title.isNotEmpty) return c.title;
    final dir = ChatDirectory.of(context);
    final names = c.peerIds.map((id) => dir.person(id)?.name).whereType<String>().toList();
    for (final id in c.peerIds) {
      if (dir.person(id) == null) dir.resolve(id).then((_) => mounted ? setState(() {}) : null);
    }
    if (names.isEmpty) return c.group ? 'Group call' : 'Neighbour';
    if (!c.group) return names.first;
    return names.length <= 2 ? names.join(', ') : '${names.take(2).join(', ')} +${names.length - 2}';
  }

  @override
  Widget build(BuildContext context) {
    final c = _calls.info.value;
    final videoLive = c.video && c.phase == CallPhase.connected && !kIsWeb;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: !c.active,
        child: Scaffold(
          backgroundColor: const Color(0xFF1A1210),
          body: Stack(fit: StackFit.expand, children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.brandDeep, Color(0xFF3A1B10), Color(0xFF1A1210)],
                ),
              ),
            ),
            if (videoLive && c.peerIds.isNotEmpty) _RemoteVideo(userIds: c.group ? c.peerIds : [c.peerIds.first]),
            SafeArea(
              child: Column(children: [
                const SizedBox(height: AppSpace.md),
                const _PoweredBy(),
                const SizedBox(height: AppSpace.xxxl),
                if (!videoLive) ...[
                  _Avatars(ids: c.peerIds, group: c.group),
                  const SizedBox(height: AppSpace.xl),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.xxl),
                  child: Text(
                    _title(context, c),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.display.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  _status(c),
                  style: AppText.heading.copyWith(
                    color: c.errorCode != null ? const Color(0xFFFFB4A8) : Colors.white.withValues(alpha: 0.78),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                if (videoLive && c.cameraOn)
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(right: AppSpace.lg, bottom: AppSpace.lg),
                      child: _LocalVideo(),
                    ),
                  ),
                if (c.phase == CallPhase.incoming) _incomingControls() else _inCallControls(c),
                const SizedBox(height: AppSpace.xxxl),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _incomingControls() => Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _RoundButton(
          icon: Icons.call_end_rounded,
          label: 'Decline',
          color: AppColors.danger,
          onTap: _calls.hangup,
        ),
        _RoundButton(
          icon: _calls.info.value.video ? Icons.videocam_rounded : Icons.call_rounded,
          label: 'Accept',
          color: AppColors.save,
          onTap: () async {
            final err = await _calls.accept();
            if (err != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
          },
        ),
      ]);

  Widget _inCallControls(CallInfo c) {
    final enabled = c.phase != CallPhase.ended;
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _ToggleButton(
          icon: c.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
          label: c.muted ? 'Unmute' : 'Mute',
          on: c.muted,
          onTap: enabled ? () => _calls.setMuted(!c.muted) : null,
        ),
        _ToggleButton(
          icon: c.speaker ? Icons.volume_up_rounded : Icons.hearing_rounded,
          label: 'Speaker',
          on: c.speaker,
          onTap: enabled ? () => _calls.setSpeaker(!c.speaker) : null,
        ),
        if (c.video) ...[
          _ToggleButton(
            icon: c.cameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
            label: 'Camera',
            on: !c.cameraOn,
            onTap: enabled ? () => _calls.setCamera(!c.cameraOn) : null,
          ),
          _ToggleButton(
            icon: Icons.cameraswitch_rounded,
            label: 'Flip',
            on: false,
            onTap: enabled ? _calls.switchCamera : null,
          ),
        ],
      ]),
      const SizedBox(height: AppSpace.xxl),
      _RoundButton(
        icon: Icons.call_end_rounded,
        label: enabled ? 'End' : 'Close',
        color: AppColors.danger,
        onTap: enabled ? _calls.hangup : () => Navigator.of(context).maybePop(),
      ),
    ]);
  }
}

class _PoweredBy extends StatelessWidget {
  const _PoweredBy();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs + 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_rounded, size: 12, color: Colors.white.withValues(alpha: 0.8)),
          const SizedBox(width: AppSpace.xs + 2),
          Text('Nexconn Call', style: AppText.tiny.copyWith(color: Colors.white.withValues(alpha: 0.85))),
        ]),
      );
}

class _Avatars extends StatelessWidget {
  const _Avatars({required this.ids, required this.group});

  final List<String> ids;
  final bool group;

  @override
  Widget build(BuildContext context) {
    if (ids.isEmpty) {
      return const CircleAvatar(radius: 56, backgroundColor: Colors.white24, child: Icon(Icons.groups_rounded, size: 48));
    }
    if (!group || ids.length == 1) return _ring(ChatPersonAvatar(id: ids.first, size: 112));
    final shown = ids.take(4).toList();
    return SizedBox(
      height: 84,
      width: 60.0 * shown.length + 24,
      child: Stack(children: [
        for (var i = 0; i < shown.length; i++)
          Positioned(left: i * 60.0, child: _ring(ChatPersonAvatar(id: shown[i], size: 76))),
      ]),
    );
  }

  Widget _ring(Widget child) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.9)),
        child: child,
      );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Semantics(
          button: true,
          label: label,
          child: Material(
            color: color,
            shape: const CircleBorder(),
            elevation: 6,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(width: 72, height: 72, child: Icon(icon, color: Colors.white, size: 32)),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(label, style: AppText.label.copyWith(color: Colors.white.withValues(alpha: 0.85))),
      ]);
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({required this.icon, required this.label, required this.on, required this.onTap});

  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Semantics(
          button: true,
          toggled: on,
          label: label,
          child: Material(
            color: on ? Colors.white : Colors.white.withValues(alpha: 0.14),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 58,
                height: 58,
                child: Icon(icon, color: on ? AppColors.ink : Colors.white, size: 26),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(label, style: AppText.caption.copyWith(color: Colors.white.withValues(alpha: 0.8))),
      ]);
}

/// Remote video (one tile per participant) rendered by the Call SDK's own TextureView via a platform view.
class _RemoteVideo extends StatelessWidget {
  const _RemoteVideo({required this.userIds});

  final List<String> userIds;

  @override
  Widget build(BuildContext context) {
    if (userIds.length == 1) return _VideoView(userId: userIds.first);
    return GridView.count(
      crossAxisCount: 2,
      physics: const NeverScrollableScrollPhysics(),
      children: [for (final id in userIds) _VideoView(userId: id)],
    );
  }
}

class _LocalVideo extends StatelessWidget {
  const _LocalVideo();

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: const SizedBox(width: 110, height: 160, child: _VideoView(userId: null)),
      );
}

class _VideoView extends StatelessWidget {
  const _VideoView({required this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context) => AndroidView(
        key: ValueKey('video-${userId ?? 'local'}'),
        viewType: 'jugaad/call-video',
        creationParams: {'userId': userId},
        creationParamsCodec: const StandardMessageCodec(),
      );
}
