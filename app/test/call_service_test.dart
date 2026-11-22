import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jugaad_street/core/call/call_service.dart';
import 'package:jugaad_street/core/nexconn/nexconn_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const codec = StandardMethodCodec();
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(const MethodChannel('jugaad/call'), (c) async {
      calls.add(c);
      return c.method == 'permissions' ? true : null;
    });
    messenger.setMockMethodCallHandler(const MethodChannel('jugaad/call/events'), (_) async => null);
  });

  Future<void> emit(Map<String, Object?> event) async {
    await messenger.handlePlatformMessage('jugaad/call/events', codec.encodeSuccessEnvelope(event), (_) {});
    await Future<void>.delayed(Duration.zero);
  }

  test('incoming call, accept, connect and end follow the native events', () async {
    final svc = CallService(NexconnService(EngineProvider()));
    final rang = <CallInfo>[];
    svc.incoming.listen(rang.add);
    await Future<void>.delayed(Duration.zero);

    await emit({
      'type': 'incoming',
      'callId': 'c1',
      'callType': 'SINGLE',
      'video': true,
      'callerUserId': 'v_balaji',
      'participants': [
        {'userId': 'v_balaji'},
      ],
    });
    expect(rang, hasLength(1));
    expect(svc.info.value.phase, CallPhase.incoming);
    expect(svc.info.value.peerIds, ['v_balaji']);
    expect(svc.info.value.video, isTrue);

    await svc.accept();
    expect(calls.map((c) => c.method), containsAllInOrder(['permissions', 'accept']));
    expect(svc.info.value.phase, CallPhase.connecting);

    await emit({'type': 'connected', 'callId': 'c1', 'participants': []});
    expect(svc.info.value.phase, CallPhase.connected);
    expect(svc.info.value.connectedAt, isNotNull);

    await emit({'type': 'ended', 'reason': 'REMOTE_HANGUP'});
    expect(svc.info.value.phase, CallPhase.ended);
    svc.reset();
    expect(svc.info.value.phase, CallPhase.idle);
  });

  test('a failed start reports the Call SDK status code', () async {
    final svc = CallService(NexconnService(EngineProvider()));
    await Future<void>.delayed(Duration.zero);
    svc.info.value = const CallInfo(phase: CallPhase.outgoing, peerIds: ['u_priya']);
    await emit({'type': 'startResult', 'code': 80006, 'codeName': 'VOIP_SERVICE_UNAVAILABLE'});
    expect(svc.info.value.phase, CallPhase.ended);
    expect(svc.info.value.errorCode, 80006);
    expect(svc.info.value.errorName, 'VOIP_SERVICE_UNAVAILABLE');
  });
}
