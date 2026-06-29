import 'package:connect_app/call_v2/call_navigation_coordinator_v2.dart';
import 'package:connect_app/call_v2/call_session_manager_v2.dart';
import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/call_v2_feature_gate.dart';
import 'package:connect_app/call_v2/domain/call_v2_models.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi implements CallableCallV2Api {
  final calls = <String, Map<String, Object?>>{};
  final attemptOrder = <String>[];

  @override
  Future<void> acceptCallV2(Map<String, Object?> request) async {
    attemptOrder.add('accept');
    calls['accept'] = request;
  }

  @override
  Future<void> cancelCallV2(Map<String, Object?> request) async {
    attemptOrder.add('cancel');
    calls['cancel'] = request;
  }

  @override
  Future<void> declineCallV2(Map<String, Object?> request) async {
    attemptOrder.add('decline');
    calls['decline'] = request;
  }

  @override
  Future<void> endCallV2(Map<String, Object?> request) async {
    attemptOrder.add('end');
    calls['end'] = request;
  }

  @override
  Future<void> renewActiveCallLeaseV2(Map<String, Object?> request) async {
    attemptOrder.add('lease');
    calls['lease'] = request;
  }

  @override
  Future<void> reportParticipantMediaV2(Map<String, Object?> request) async {
    attemptOrder.add('media');
    calls['media'] = request;
  }

  @override
  Future<void> startCallV2(Map<String, Object?> request) async {
    attemptOrder.add('start');
    calls['start'] = request;
  }
}

class _FailingApi implements CallableCallV2Api {
  @override
  Future<void> acceptCallV2(Map<String, Object?> request) =>
      throw StateError('backend');
  @override
  Future<void> cancelCallV2(Map<String, Object?> request) =>
      throw StateError('backend');
  @override
  Future<void> declineCallV2(Map<String, Object?> request) =>
      throw StateError('backend');
  @override
  Future<void> endCallV2(Map<String, Object?> request) =>
      throw StateError('backend');
  @override
  Future<void> renewActiveCallLeaseV2(Map<String, Object?> request) =>
      throw StateError('backend');
  @override
  Future<void> reportParticipantMediaV2(Map<String, Object?> request) =>
      throw StateError('backend');
  @override
  Future<void> startCallV2(Map<String, Object?> request) =>
      throw StateError('backend');
}

void main() {
  test('parses public call data and rejects private fields', () {
    final snapshot = CallV2Snapshot.fromPublicData(_data());
    expect(snapshot.callSystem, 'v2');
    expect(snapshot.participants, hasLength(2));
    expect(
      () =>
          CallV2Snapshot.fromPublicData({..._data(), 'authenticatedUid': 'x'}),
      throwsFormatException,
    );
  });

  test('API request shapes keep private fields out', () async {
    final fake = _FakeApi();
    final api = CallV2Api(fake);
    await api.startCallV2(const CallV2RequestContext(
      callId: 'call_a',
      version: 1,
      actorUid: 'caller',
      participantRole: CallV2ParticipantRole.caller,
    ));
    final request = fake.calls['start']!;
    expect(request, isNot(contains('authenticatedUid')));
    expect(request, isNot(contains('staffRollout')));
    expect(request, isNot(contains('cohort')));
    expect(request, isNot(contains('lock')));
    expect(request, isNot(contains('fencing')));
    expect(request, isNot(contains('task')));
    expect(request, isNot(contains('command')));
    expect(request, isNot(contains('operation')));
  });

  test('client error normalization hides backend details', () async {
    final api = CallV2Api(_FailingApi());
    await expectLater(
      api.startCallV2(const CallV2RequestContext(
        callId: 'call_a',
        version: 1,
        actorUid: 'caller',
        participantRole: CallV2ParticipantRole.caller,
      )),
      throwsA(isA<CallV2ClientError>()),
    );
  });

  test('feature gate disables transport and manager ownership', () async {
    final fake = _FakeApi();
    final manager = CallSessionManagerV2(
      featureGate: const CallV2FeatureGate(),
      api: CallV2Api(fake),
    );
    await manager.startCall(const CallV2RequestContext(
      callId: 'call_a',
      version: 1,
      actorUid: 'caller',
      participantRole: CallV2ParticipantRole.caller,
    ));
    expect(fake.calls, isEmpty);
    expect(manager.snapshot, isNull);
  });

  test('manager deduplicates stale snapshots and serializes duplicate commands',
      () async {
    final fake = _FakeApi();
    final manager = CallSessionManagerV2(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: CallV2Api(fake),
    );
    final base = CallV2Snapshot.fromPublicData(_data());
    manager.injectSnapshot(base);
    manager.injectSnapshot(CallV2Snapshot.fromPublicData({
      ..._data(),
      'version': 0,
      'lifecycle': 'ringing',
    }));
    expect(manager.snapshot!.version, 1);
    await manager.acceptCall(const CallV2RequestContext(
      callId: 'call_a',
      version: 1,
      actorUid: 'caller',
      participantRole: CallV2ParticipantRole.caller,
    ));
    await manager.acceptCall(const CallV2RequestContext(
      callId: 'call_a',
      version: 1,
      actorUid: 'caller',
      participantRole: CallV2ParticipantRole.caller,
    ));
    expect(fake.attemptOrder.where((item) => item == 'accept'), hasLength(2));
  });

  test('terminal cleanup is idempotent and local phase is deterministic',
      () async {
    final manager = CallSessionManagerV2(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: CallV2Api(_FakeApi()),
    );
    manager.injectSnapshot(CallV2Snapshot.fromPublicData({
      ..._data(),
      'lifecycle': 'completed',
    }));
    expect(manager.localPhase, CallV2LocalPhase.closing);
    await manager.cleanupIfTerminal();
    await manager.cleanupIfTerminal();
  });

  test('navigation coordinator dedupes open intent by snapshot version', () {
    final coordinator = CallNavigationCoordinatorV2();
    final snapshot = CallV2Snapshot.fromPublicData(_data());
    expect(coordinator.openIntentFor(snapshot), isNotNull);
    expect(
      coordinator.closeIntentFor(snapshot).type,
      CallNavigationIntentType.close,
    );
  });
}

Map<String, Object?> _data() => <String, Object?>{
      'callSystem': 'v2',
      'callId': 'call_a',
      'version': 1,
      'lifecycle': 'ringing',
      'callerUid': 'caller',
      'calleeUid': 'callee',
      'participants': <Map<String, Object?>>[
        {
          'uid': 'caller',
          'role': 'caller',
          'mediaState': 'notJoined',
          'mediaVersion': 0,
        },
        {
          'uid': 'callee',
          'role': 'callee',
          'mediaState': 'notJoined',
          'mediaVersion': 0,
        },
      ],
    };
