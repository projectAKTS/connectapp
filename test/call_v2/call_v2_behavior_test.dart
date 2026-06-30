import 'dart:async';

import 'package:connect_app/call_v2/call_v2_harness.dart';
import 'package:connect_app/call_v2/call_navigation_coordinator_v2.dart';
import 'package:connect_app/call_v2/call_session_manager_v2.dart';
import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/call_v2_feature_gate.dart';
import 'package:connect_app/call_v2/call_v2_presenter.dart';
import 'package:connect_app/call_v2/domain/call_lifecycle.dart';
import 'package:connect_app/call_v2/domain/call_local_phase.dart';
import 'package:connect_app/call_v2/domain/call_snapshot.dart';
import 'package:connect_app/call_v2/domain/participant_media_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi implements CallableCallV2Api {
  final calls = <String, List<Map<String, Object?>>>{};
  int startCount = 0;
  int acceptCount = 0;
  Completer<void>? startGate;
  Completer<void>? acceptGate;
  Object? startResult = _startResult(callId: 'server_call');
  Object? acceptResult = _lifecycleResult(lifecycleState: 'accepted');
  Object? declineResult = _lifecycleResult(lifecycleState: 'declined');
  Object? cancelResult = _lifecycleResult(lifecycleState: 'cancelled');
  Object? endResult = _lifecycleResult(lifecycleState: 'completed');
  Object? mediaResult = _mediaResult(lifecycleState: 'active');
  Object? leaseResult = _leaseResult();

  @override
  Future<Object?> acceptCallV2(Map<String, Object?> request) async {
    acceptCount += 1;
    calls.putIfAbsent('accept', () => <Map<String, Object?>>[]).add(request);
    acceptGate ??= Completer<void>();
    await acceptGate!.future;
    return acceptResult;
  }

  @override
  Future<Object?> cancelCallV2(Map<String, Object?> request) async {
    calls.putIfAbsent('cancel', () => <Map<String, Object?>>[]).add(request);
    return cancelResult;
  }

  @override
  Future<Object?> declineCallV2(Map<String, Object?> request) async {
    calls.putIfAbsent('decline', () => <Map<String, Object?>>[]).add(request);
    return declineResult;
  }

  @override
  Future<Object?> endCallV2(Map<String, Object?> request) async {
    calls.putIfAbsent('end', () => <Map<String, Object?>>[]).add(request);
    return endResult;
  }

  @override
  Future<Object?> renewActiveCallLeaseV2(Map<String, Object?> request) async {
    calls.putIfAbsent('lease', () => <Map<String, Object?>>[]).add(request);
    return leaseResult;
  }

  @override
  Future<Object?> reportParticipantMediaV2(Map<String, Object?> request) async {
    calls.putIfAbsent('media', () => <Map<String, Object?>>[]).add(request);
    return mediaResult;
  }

  @override
  Future<Object?> startCallV2(Map<String, Object?> request) async {
    startCount += 1;
    calls.putIfAbsent('start', () => <Map<String, Object?>>[]).add(request);
    await startGate?.future;
    return startResult;
  }
}

class _FailingApi implements CallableCallV2Api {
  @override
  Future<Object?> acceptCallV2(Map<String, Object?> request) =>
      throw StateError('provider stack leak');
  @override
  Future<Object?> cancelCallV2(Map<String, Object?> request) =>
      throw StateError('provider stack leak');
  @override
  Future<Object?> declineCallV2(Map<String, Object?> request) =>
      throw StateError('provider stack leak');
  @override
  Future<Object?> endCallV2(Map<String, Object?> request) =>
      throw StateError('provider stack leak');
  @override
  Future<Object?> renewActiveCallLeaseV2(Map<String, Object?> request) =>
      throw StateError('provider stack leak');
  @override
  Future<Object?> reportParticipantMediaV2(Map<String, Object?> request) =>
      throw StateError('provider stack leak');
  @override
  Future<Object?> startCallV2(Map<String, Object?> request) =>
      throw StateError('provider stack leak');
}

void main() {
  test('snapshot parser rejects private and duplicate identity fields', () {
    expect(CallSnapshot.fromPublicData(_snapshotData()), isNotNull);

    for (final key in <String>[
      'authenticatedUid',
      'uid',
      'staff',
      'rolloutMode',
      'percentage',
      'salt',
      'allowlist',
      'cohort',
      'fencingToken',
      'lockClaim',
      'taskId',
      'commandId',
      'task',
      'command',
    ]) {
      expect(
        () => CallSnapshot.fromPublicData({..._snapshotData(), key: 'x'}),
        throwsFormatException,
        reason: 'rejected key $key',
      );
    }
  });

  test('request shapes exclude authenticated identity and private rollout data',
      () async {
    final fake = _FakeApi();
    final api = CallV2Api(fake);
    await api.startCallV2(const StartCallV2Request(
      calleeUid: 'callee',
      isVideo: true,
      idempotencyKey: 'start_key',
    ));
    final request = fake.calls['start']!.single;
    expect(request, <String, Object?>{
      'calleeUid': 'callee',
      'isVideo': true,
      'idempotencyKey': 'start_key',
    });
    for (final key in <String>[
      'actorUid',
      'authenticatedUid',
      'uid',
      'callerUid',
      'version',
      'mediaVersion',
      'staff',
      'rolloutMode',
      'percentage',
      'salt',
      'allowlist',
      'cohort',
      'fencingToken',
      'lockClaim',
      'taskId',
      'commandId',
    ]) {
      expect(request.containsKey(key), isFalse, reason: key);
    }
  });

  test('controlled errors expose only a small code contract', () async {
    final api = CallV2Api(_FailingApi());
    await expectLater(
      api.startCallV2(const StartCallV2Request(
        calleeUid: 'callee',
        isVideo: true,
        idempotencyKey: 'start_key',
      )),
      throwsA(
        isA<CallV2ClientError>().having(
          (error) => error.code,
          'code',
          CallV2ClientErrorCode.unavailable,
        ),
      ),
    );
  });

  test('session manager maps caller and callee ringing phases correctly',
      () async {
    final callerManager = CallSessionManagerV2(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: CallV2Api(_FakeApi()),
      localParticipantRole: () => CallParticipantRole.caller,
    );
    final calleeManager = CallSessionManagerV2(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: CallV2Api(_FakeApi()),
      localParticipantRole: () => CallParticipantRole.callee,
    );
    final ringing = CallSnapshot.fromPublicData(_snapshotData());

    callerManager.injectSnapshot(ringing);
    calleeManager.injectSnapshot(ringing);

    expect(callerManager.localPhase, CallLocalPhase.outgoingRinging);
    expect(calleeManager.localPhase, CallLocalPhase.presentingIncoming);
  });

  test('equal and lower snapshots do not regress durable terminal state', () {
    final manager = CallSessionManagerV2(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: CallV2Api(_FakeApi()),
      localParticipantRole: () => CallParticipantRole.callee,
    );
    manager.injectSnapshot(CallSnapshot.fromPublicData(
        _snapshotData(lifecycle: CallLifecycle.completed)));
    manager.injectSnapshot(CallSnapshot.fromPublicData(
        _snapshotData(version: 1, lifecycle: CallLifecycle.ringing)));
    manager.injectSnapshot(CallSnapshot.fromPublicData(
        _snapshotData(version: 0, lifecycle: CallLifecycle.active)));

    expect(manager.snapshot!.lifecycle, CallLifecycle.completed);
    expect(manager.localPhase, CallLocalPhase.closing);
  });

  test('different call ownership is rejected while nonterminal ownership holds',
      () {
    final manager = CallSessionManagerV2(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: CallV2Api(_FakeApi()),
      localParticipantRole: () => CallParticipantRole.callee,
    );
    manager.injectSnapshot(
        CallSnapshot.fromPublicData(_snapshotData(callId: 'call_a')));
    manager.injectSnapshot(
        CallSnapshot.fromPublicData(_snapshotData(callId: 'call_b')));

    expect(manager.snapshot!.callId, 'call_a');
  });

  test('terminal cleanup clears ownership and is idempotent', () async {
    final manager = CallSessionManagerV2(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: CallV2Api(_FakeApi()),
      localParticipantRole: () => CallParticipantRole.callee,
    );
    manager.injectSnapshot(CallSnapshot.fromPublicData(
        _snapshotData(lifecycle: CallLifecycle.completed)));
    await manager.cleanupIfTerminal();
    await manager.cleanupIfTerminal();

    expect(manager.snapshot, isNull);
    expect(manager.localPhase, CallLocalPhase.idle);
  });

  test('duplicate accept taps share the in-flight transport request', () async {
    final fake = _FakeApi();
    final manager = CallSessionManagerV2(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: CallV2Api(fake),
      localParticipantRole: () => CallParticipantRole.callee,
    );
    final first = manager.acceptCall(const CallV2LifecycleCommandRequest(
      callId: 'call_a',
      idempotencyKey: 'accept_key_1',
    ));
    final second = manager.acceptCall(const CallV2LifecycleCommandRequest(
      callId: 'call_a',
      idempotencyKey: 'accept_key_2',
    ));
    await Future<void>.delayed(Duration.zero);

    expect(fake.acceptCount, 1);
    expect(fake.calls['accept'], hasLength(1));

    fake.acceptGate!.complete();
    final results = await Future.wait(<Future<Object?>>[first, second]);
    expect(identical(results[0], results[1]), isTrue);
  });

  test('navigation coordinator dedupes intents without route access', () {
    final coordinator = CallNavigationCoordinatorV2();
    final ringing = CallSnapshot.fromPublicData(
        _snapshotData(version: 1, lifecycle: CallLifecycle.ringing));
    final terminal = CallSnapshot.fromPublicData(
        _snapshotData(version: 2, lifecycle: CallLifecycle.completed));

    expect(coordinator.openIntentFor(ringing), isNotNull);
    expect(coordinator.openIntentFor(ringing), isNull);
    expect(
        coordinator.openIntentFor(
          CallSnapshot.fromPublicData(
              _snapshotData(version: 2, lifecycle: CallLifecycle.ringing)),
        ),
        isNotNull);
    expect(coordinator.closeIntentFor(terminal), isNotNull);
    expect(coordinator.closeIntentFor(terminal), isNull);
  });

  test('disabled harness ignores snapshots and commands', () async {
    final fake = _FakeApi();
    final harness = CallV2Harness(
      featureGate: const CallV2FeatureGate(enabled: false),
      api: CallV2Api(fake),
      localParticipantRole: () => CallParticipantRole.callee,
    );
    final snapshot = CallSnapshot.fromPublicData(
        _snapshotData(lifecycle: CallLifecycle.active));

    harness.injectPublicSnapshot(snapshot);
    await expectLater(
      harness.startCall(const StartCallV2Request(
        calleeUid: 'callee',
        isVideo: true,
        idempotencyKey: 'start_key',
      )),
      throwsA(isA<CallV2ClientError>()),
    );

    expect(harness.snapshot, isNull);
    expect(harness.localPhase, CallLocalPhase.idle);
    expect(fake.calls, isEmpty);
  });

  test('enabled harness starts pending ownership with server callId', () async {
    final fake = _FakeApi();
    final harness = CallV2Harness(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: CallV2Api(fake),
      localParticipantRole: () => CallParticipantRole.callee,
    );

    final result = await harness.startCall(const StartCallV2Request(
      calleeUid: 'callee',
      isVideo: true,
      idempotencyKey: 'start_key',
    ));

    expect(result.callId, 'server_call');
    expect(harness.pendingStartedCall!.callId, 'server_call');
    expect(harness.pendingStartedCall!.calleeUid, 'callee');
    expect(harness.pendingStartedCall!.idempotencyKey, 'start_key');
    expect(harness.snapshot, isNull);
    expect(harness.localPhase, CallLocalPhase.idle);
    expect(fake.calls['start'], hasLength(1));
    expect(fake.calls['start']!.single, <String, Object?>{
      'calleeUid': 'callee',
      'isVideo': true,
      'idempotencyKey': 'start_key',
    });
  });

  test('same pending start is accepted as server idempotent replay', () async {
    final fake = _FakeApi();
    final harness = CallV2Harness(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: CallV2Api(fake),
      localParticipantRole: () => CallParticipantRole.caller,
    );

    final first = await harness.startCall(const StartCallV2Request(
      calleeUid: 'callee',
      isVideo: true,
      idempotencyKey: 'start_key',
    ));
    fake.startResult = _startResult(
      callId: 'server_call',
      idempotentReplay: true,
    );
    final second = await harness.startCall(const StartCallV2Request(
      calleeUid: 'callee',
      isVideo: true,
      idempotencyKey: 'start_key',
    ));

    expect(first.idempotentReplay, isFalse);
    expect(second.idempotentReplay, isTrue);
    expect(harness.pendingStartedCall!.callId, 'server_call');
    expect(harness.pendingStartedCall!.calleeUid, 'callee');
    expect(harness.pendingStartedCall!.idempotencyKey, 'start_key');
    expect(fake.calls['start'], hasLength(2));
  });

  test('same callee with different start key is rejected before transport',
      () async {
    final fake = _FakeApi();
    final harness = CallV2Harness(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: CallV2Api(fake),
      localParticipantRole: () => CallParticipantRole.caller,
    );

    await harness.startCall(const StartCallV2Request(
      calleeUid: 'callee',
      isVideo: true,
      idempotencyKey: 'start_key',
    ));
    await expectLater(
      harness.startCall(const StartCallV2Request(
        calleeUid: 'callee',
        isVideo: true,
        idempotencyKey: 'other_key',
      )),
      throwsA(isA<CallV2ClientError>().having(
        (error) => error.code,
        'code',
        CallV2ClientErrorCode.rejected,
      )),
    );

    expect(fake.calls['start'], hasLength(1));
    expect(harness.pendingStartedCall!.callId, 'server_call');
    expect(harness.pendingStartedCall!.calleeUid, 'callee');
    expect(harness.pendingStartedCall!.idempotencyKey, 'start_key');
  });

  test('different callee with same start key is rejected before transport',
      () async {
    final fake = _FakeApi();
    final harness = CallV2Harness(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: CallV2Api(fake),
      localParticipantRole: () => CallParticipantRole.caller,
    );

    await harness.startCall(const StartCallV2Request(
      calleeUid: 'callee',
      isVideo: true,
      idempotencyKey: 'start_key',
    ));
    await expectLater(
      harness.startCall(const StartCallV2Request(
        calleeUid: 'other',
        isVideo: true,
        idempotencyKey: 'start_key',
      )),
      throwsA(isA<CallV2ClientError>().having(
        (error) => error.code,
        'code',
        CallV2ClientErrorCode.rejected,
      )),
    );

    expect(fake.calls['start'], hasLength(1));
    expect(harness.pendingStartedCall!.callId, 'server_call');
    expect(harness.pendingStartedCall!.calleeUid, 'callee');
    expect(harness.pendingStartedCall!.idempotencyKey, 'start_key');
  });

  test('exact pending start replay rejects conflicting server call ID',
      () async {
    final fake = _FakeApi();
    final harness = CallV2Harness(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: CallV2Api(fake),
      localParticipantRole: () => CallParticipantRole.caller,
    );

    await harness.startCall(const StartCallV2Request(
      calleeUid: 'callee',
      isVideo: true,
      idempotencyKey: 'start_key',
    ));
    fake.startResult = _startResult(
      callId: 'other_server_call',
      idempotentReplay: true,
    );
    await expectLater(
      harness.startCall(const StartCallV2Request(
        calleeUid: 'callee',
        isVideo: true,
        idempotencyKey: 'start_key',
      )),
      throwsA(isA<CallV2ClientError>().having(
        (error) => error.code,
        'code',
        CallV2ClientErrorCode.rejected,
      )),
    );

    expect(fake.calls['start'], hasLength(2));
    expect(harness.pendingStartedCall!.callId, 'server_call');
    expect(harness.pendingStartedCall!.calleeUid, 'callee');
    expect(harness.pendingStartedCall!.idempotencyKey, 'start_key');
  });

  test('duplicate start taps in flight preserve the first request identity',
      () async {
    final fake = _FakeApi()..startGate = Completer<void>();
    final harness = CallV2Harness(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: CallV2Api(fake),
      localParticipantRole: () => CallParticipantRole.caller,
    );

    final first = harness.startCall(const StartCallV2Request(
      calleeUid: 'callee',
      isVideo: true,
      idempotencyKey: 'start_key',
    ));
    final second = harness.startCall(const StartCallV2Request(
      calleeUid: 'callee',
      isVideo: true,
      idempotencyKey: 'other_key',
    ));
    await Future<void>.delayed(Duration.zero);

    expect(fake.startCount, 1);
    expect(fake.calls['start'], hasLength(1));

    fake.startGate!.complete();
    final results = await Future.wait(<Future<Object?>>[first, second]);

    expect(identical(results[0], results[1]), isTrue);
    expect(harness.pendingStartedCall!.callId, 'server_call');
    expect(harness.pendingStartedCall!.calleeUid, 'callee');
    expect(harness.pendingStartedCall!.idempotencyKey, 'start_key');
  });

  test('harness suppresses duplicate command taps while in flight', () async {
    final fake = _FakeApi();
    final harness = CallV2Harness(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: CallV2Api(fake),
      localParticipantRole: () => CallParticipantRole.callee,
    );

    final first = harness.acceptCall(const CallV2LifecycleCommandRequest(
      callId: 'call_a',
      idempotencyKey: 'accept_key_1',
    ));
    final second = harness.acceptCall(const CallV2LifecycleCommandRequest(
      callId: 'call_a',
      idempotencyKey: 'accept_key_2',
    ));
    await Future<void>.delayed(Duration.zero);

    expect(fake.acceptCount, 1);
    expect(fake.calls['accept'], hasLength(1));

    fake.acceptGate!.complete();
    final results = await Future.wait(<Future<Object?>>[first, second]);
    expect(identical(results[0], results[1]), isTrue);
  });

  test(
      'pending start accepts matching snapshot and rejects different call snapshot',
      () async {
    final fake = _FakeApi();
    final harness = CallV2Harness(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: CallV2Api(fake),
      localParticipantRole: () => CallParticipantRole.caller,
    );

    await harness.startCall(const StartCallV2Request(
      calleeUid: 'callee',
      isVideo: true,
      idempotencyKey: 'start_key',
    ));
    harness.injectPublicSnapshot(
      CallSnapshot.fromPublicData(_snapshotData(callId: 'other_call')),
    );

    expect(harness.snapshot, isNull);
    expect(harness.pendingStartedCall!.callId, 'server_call');

    final matching = CallSnapshot.fromPublicData(
      _snapshotData(callId: 'server_call'),
    );
    harness.injectPublicSnapshot(matching);

    expect(harness.snapshot, same(matching));
    expect(harness.pendingStartedCall, isNull);
  });

  test('failed or malformed start creates no ownership', () async {
    final failingHarness = CallV2Harness(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: CallV2Api(_FailingApi()),
      localParticipantRole: () => CallParticipantRole.caller,
    );
    final malformed = _FakeApi()..startResult = <String, Object?>{'bad': true};
    final malformedHarness = CallV2Harness(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: CallV2Api(malformed),
      localParticipantRole: () => CallParticipantRole.caller,
    );

    await expectLater(
      failingHarness.startCall(const StartCallV2Request(
        calleeUid: 'callee',
        isVideo: true,
        idempotencyKey: 'start_key',
      )),
      throwsA(isA<CallV2ClientError>()),
    );
    await expectLater(
      malformedHarness.startCall(const StartCallV2Request(
        calleeUid: 'callee',
        isVideo: true,
        idempotencyKey: 'start_key',
      )),
      throwsA(isA<CallV2ClientError>()),
    );

    expect(failingHarness.pendingStartedCall, isNull);
    expect(malformedHarness.pendingStartedCall, isNull);
  });

  test('conflicting second start is rejected while pending ownership exists',
      () async {
    final fake = _FakeApi();
    final harness = CallV2Harness(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: CallV2Api(fake),
      localParticipantRole: () => CallParticipantRole.caller,
    );

    await harness.startCall(const StartCallV2Request(
      calleeUid: 'callee',
      isVideo: true,
      idempotencyKey: 'start_key',
    ));
    await expectLater(
      harness.startCall(const StartCallV2Request(
        calleeUid: 'other',
        isVideo: true,
        idempotencyKey: 'other_key',
      )),
      throwsA(isA<CallV2ClientError>().having(
        (error) => error.code,
        'code',
        CallV2ClientErrorCode.rejected,
      )),
    );

    expect(fake.calls['start'], hasLength(1));
    expect(harness.pendingStartedCall!.callId, 'server_call');
  });

  test('cleanup clears pending started ownership', () async {
    final harness = CallV2Harness(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: CallV2Api(_FakeApi()),
      localParticipantRole: () => CallParticipantRole.caller,
    );

    await harness.startCall(const StartCallV2Request(
      calleeUid: 'callee',
      isVideo: true,
      idempotencyKey: 'start_key',
    ));
    await harness.cleanupIfTerminal();

    expect(harness.pendingStartedCall, isNull);
    expect(harness.snapshot, isNull);
  });

  test('harness closes terminal snapshots once and cleanup stays idempotent',
      () async {
    final fake = _FakeApi();
    final harness = CallV2Harness(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: CallV2Api(fake),
      localParticipantRole: () => CallParticipantRole.callee,
    );
    final terminal = CallSnapshot.fromPublicData(
        _snapshotData(version: 2, lifecycle: CallLifecycle.completed));

    harness.injectPublicSnapshot(terminal);

    expect(harness.closeNavigationIntentFor(terminal), isNotNull);
    expect(harness.closeNavigationIntentFor(terminal), isNull);

    await harness.cleanupIfTerminal();
    await harness.cleanupIfTerminal();

    expect(harness.snapshot, isNull);
    expect(harness.localPhase, CallLocalPhase.idle);
    expect(harness.closeNavigationIntentFor(terminal), isNull);
    expect(fake.calls, isEmpty);
  });

  test('disabled presenter remains idle and does not call transport', () async {
    final fake = _FakeApi();
    final harness = _harness(
      fake: fake,
      enabled: false,
      role: CallParticipantRole.callee,
    );
    final presenter = CallV2Presenter(harness: harness);

    presenter.injectPublicSnapshot(CallSnapshot.fromPublicData(
        _snapshotData(lifecycle: CallLifecycle.active)));
    await presenter.acceptCall(idempotencyKey: 'accept_key');
    await presenter.declineCall(idempotencyKey: 'decline_key');
    await presenter.cancelCall(idempotencyKey: 'cancel_key');
    await presenter.endCall(idempotencyKey: 'end_key');
    await presenter.reportMedia(
      mediaState: ParticipantMediaState.joined,
      idempotencyKey: 'media_key',
    );

    expect(presenter.state.localPhase, CallLocalPhase.idle);
    _expectActionsDisabled(presenter.state);
    expect(presenter.state.openNavigationIntentPending, isFalse);
    expect(presenter.state.closeNavigationIntentPending, isFalse);
    expect(harness.snapshot, isNull);
    expect(fake.calls, isEmpty);
  });

  test('presenter derives display-safe state and actions by lifecycle', () {
    final harness = _harness(role: CallParticipantRole.callee);
    final presenter = CallV2Presenter(harness: harness);
    final ringing = CallSnapshot.fromPublicData(_snapshotData(
      version: 1,
      lifecycle: CallLifecycle.ringing,
    ));
    final accepted = CallSnapshot.fromPublicData(_snapshotData(
      version: 2,
      lifecycle: CallLifecycle.accepted,
    ));
    final active = CallSnapshot.fromPublicData(_snapshotData(
      version: 3,
      lifecycle: CallLifecycle.active,
    ));

    presenter.injectPublicSnapshot(ringing);

    expect(harness.snapshot, same(ringing));
    expect(presenter.state.localPhase, CallLocalPhase.presentingIncoming);
    expect(presenter.state.titleKey, 'call_v2.title.incoming');
    expect(presenter.state.statusKey, 'call_v2.status.incoming_ringing');
    _expectActions(
      presenter.state,
      accept: true,
      decline: true,
    );

    presenter.injectPublicSnapshot(accepted);

    expect(harness.snapshot, same(accepted));
    expect(presenter.state.localPhase, CallLocalPhase.openingCallRoute);
    expect(presenter.state.titleKey, 'call_v2.title.connected');
    expect(presenter.state.statusKey, 'call_v2.status.accepted');
    expect(presenter.state.openNavigationIntentPending, isTrue);
    _expectActions(
      presenter.state,
      end: true,
      reportMedia: true,
    );

    presenter.injectPublicSnapshot(active);

    expect(harness.snapshot, same(active));
    expect(presenter.state.localPhase, CallLocalPhase.inCall);
    expect(presenter.state.titleKey, 'call_v2.title.connected');
    expect(presenter.state.statusKey, 'call_v2.status.active');
    expect(presenter.state.openNavigationIntentPending, isTrue);
    _expectActions(
      presenter.state,
      end: true,
      reportMedia: true,
    );
  });

  test('presenter ringing action matrix is role specific', () {
    final callerPresenter =
        CallV2Presenter(harness: _harness(role: CallParticipantRole.caller));
    final calleePresenter =
        CallV2Presenter(harness: _harness(role: CallParticipantRole.callee));
    final ringing = CallSnapshot.fromPublicData(_snapshotData(
      version: 1,
      lifecycle: CallLifecycle.ringing,
    ));

    callerPresenter.injectPublicSnapshot(ringing);
    calleePresenter.injectPublicSnapshot(ringing);

    expect(callerPresenter.state.localPhase, CallLocalPhase.outgoingRinging);
    _expectActions(callerPresenter.state, cancel: true);
    expect(calleePresenter.state.localPhase, CallLocalPhase.presentingIncoming);
    _expectActions(calleePresenter.state, accept: true, decline: true);
  });

  test('presenter accepted and active action matrices allow call controls', () {
    final presenter =
        CallV2Presenter(harness: _harness(role: CallParticipantRole.callee));

    presenter.injectPublicSnapshot(CallSnapshot.fromPublicData(_snapshotData(
      version: 2,
      lifecycle: CallLifecycle.accepted,
    )));

    expect(presenter.state.localPhase, CallLocalPhase.openingCallRoute);
    _expectActions(presenter.state, end: true, reportMedia: true);

    presenter.injectPublicSnapshot(CallSnapshot.fromPublicData(_snapshotData(
      version: 3,
      lifecycle: CallLifecycle.active,
    )));

    expect(presenter.state.localPhase, CallLocalPhase.inCall);
    _expectActions(presenter.state, end: true, reportMedia: true);
  });

  test('presenter terminal action matrix disables all command actions', () {
    final presenter =
        CallV2Presenter(harness: _harness(role: CallParticipantRole.callee));

    presenter.injectPublicSnapshot(CallSnapshot.fromPublicData(_snapshotData(
      version: 4,
      lifecycle: CallLifecycle.completed,
    )));

    expect(presenter.state.localPhase, CallLocalPhase.closing);
    expect(presenter.state.titleKey, 'call_v2.title.ended');
    expect(presenter.state.statusKey, 'call_v2.status.completed');
    expect(presenter.state.closeNavigationIntentPending, isTrue);
    _expectActionsDisabled(presenter.state);
  });

  test('presenter ignores equal and lower lifecycle snapshots', () {
    final harness = _harness(role: CallParticipantRole.callee);
    final presenter = CallV2Presenter(harness: harness);
    final ringing = CallSnapshot.fromPublicData(_snapshotData(
      version: 3,
      lifecycle: CallLifecycle.ringing,
    ));

    presenter.injectPublicSnapshot(ringing);
    presenter.injectPublicSnapshot(CallSnapshot.fromPublicData(_snapshotData(
      version: 3,
      lifecycle: CallLifecycle.accepted,
    )));
    presenter.injectPublicSnapshot(CallSnapshot.fromPublicData(_snapshotData(
      version: 2,
      lifecycle: CallLifecycle.active,
    )));

    expect(harness.snapshot, same(ringing));
    expect(harness.snapshot!.lifecycle, CallLifecycle.ringing);
    expect(presenter.state.localPhase, CallLocalPhase.presentingIncoming);
    _expectActions(presenter.state, accept: true, decline: true);
  });

  test('presenter derives from harness snapshot after rejected incoming data',
      () {
    final harness = _harness(role: CallParticipantRole.callee);
    final presenter = CallV2Presenter(harness: harness);
    final ringing = CallSnapshot.fromPublicData(_snapshotData(
      version: 2,
      lifecycle: CallLifecycle.ringing,
    ));
    final rejectedActive = CallSnapshot.fromPublicData(_snapshotData(
      version: 2,
      lifecycle: CallLifecycle.active,
    ));

    presenter.injectPublicSnapshot(ringing);
    presenter.injectPublicSnapshot(rejectedActive);

    expect(harness.snapshot, same(ringing));
    expect(presenter.state.localPhase, CallLocalPhase.presentingIncoming);
    expect(presenter.state.statusKey, 'call_v2.status.incoming_ringing');
    _expectActions(presenter.state, accept: true, decline: true);
  });

  test('duplicate presenter command taps create one safe transport request',
      () async {
    final fake = _FakeApi();
    final presenter = CallV2Presenter(
      harness: _harness(
        fake: fake,
        role: CallParticipantRole.callee,
      ),
    );

    presenter.injectPublicSnapshot(CallSnapshot.fromPublicData(_snapshotData(
      version: 1,
      lifecycle: CallLifecycle.ringing,
    )));
    final first = presenter.acceptCall(idempotencyKey: 'accept_key_1');
    final second = presenter.acceptCall(idempotencyKey: 'accept_key_2');
    await Future<void>.delayed(Duration.zero);

    expect(fake.acceptCount, 1);
    expect(fake.calls['accept'], hasLength(1));
    expect(fake.calls['accept']!.single, <String, Object?>{
      'callId': 'call_a',
      'idempotencyKey': 'accept_key_1',
    });

    fake.acceptGate!.complete();
    final results = await Future.wait(<Future<Object?>>[first, second]);
    expect(identical(results[0], results[1]), isTrue);
  });

  test('presenter forwards only enabled actions through the harness', () async {
    final fake = _FakeApi();
    final presenter = CallV2Presenter(
      harness: _harness(
        fake: fake,
        role: CallParticipantRole.callee,
      ),
    );

    presenter.injectPublicSnapshot(CallSnapshot.fromPublicData(_snapshotData(
      version: 3,
      lifecycle: CallLifecycle.active,
    )));
    await presenter.acceptCall(idempotencyKey: 'accept_key');
    await presenter.declineCall(idempotencyKey: 'decline_key');
    await presenter.cancelCall(idempotencyKey: 'cancel_key');
    await presenter.endCall(idempotencyKey: 'end_key');
    await presenter.reportMedia(
      mediaState: ParticipantMediaState.joined,
      idempotencyKey: 'media_key',
    );

    expect(fake.calls.keys.toSet(), <String>{'end', 'media'});
    expect(fake.calls['end']!.single, <String, Object?>{
      'callId': 'call_a',
      'idempotencyKey': 'end_key',
    });
    expect(fake.calls['media']!.single, <String, Object?>{
      'callId': 'call_a',
      'mediaState': 'joined',
      'idempotencyKey': 'media_key',
    });
  });

  test(
      'callable command results do not mutate presenter lifecycle or navigation',
      () async {
    final fake = _FakeApi();
    final presenter = CallV2Presenter(
      harness: _harness(
        fake: fake,
        role: CallParticipantRole.callee,
      ),
    );

    presenter.injectPublicSnapshot(CallSnapshot.fromPublicData(_snapshotData(
      version: 2,
      lifecycle: CallLifecycle.accepted,
    )));
    final media = await presenter.reportMedia(
      mediaState: ParticipantMediaState.joined,
      idempotencyKey: 'media_key',
    );

    expect(media!.lifecycle, CallLifecycle.active);
    expect(presenter.state.localPhase, CallLocalPhase.openingCallRoute);
    expect(presenter.state.statusKey, 'call_v2.status.accepted');
    expect(presenter.takeCloseNavigationIntent(), isNull);

    presenter.injectPublicSnapshot(CallSnapshot.fromPublicData(_snapshotData(
      version: 3,
      lifecycle: CallLifecycle.active,
    )));
    expect(presenter.takeOpenNavigationIntent(), isNotNull);
    final end = await presenter.endCall(idempotencyKey: 'end_key');

    expect(end!.lifecycle, CallLifecycle.completed);
    expect(presenter.state.localPhase, CallLocalPhase.inCall);
    expect(presenter.takeCloseNavigationIntent(), isNull);
  });

  test('different command keys remain serialized', () async {
    final fake = _FakeApi();
    final harness = CallV2Harness(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: CallV2Api(fake),
      localParticipantRole: () => CallParticipantRole.callee,
    );

    final first = harness.acceptCall(const CallV2LifecycleCommandRequest(
      callId: 'call_a',
      idempotencyKey: 'accept_key',
    ));
    final second = harness.endCall(const CallV2LifecycleCommandRequest(
      callId: 'call_a',
      idempotencyKey: 'end_key',
    ));
    await Future<void>.delayed(Duration.zero);

    expect(fake.calls['accept'], hasLength(1));
    expect(fake.calls['end'], isNull);

    fake.acceptGate!.complete();
    await Future.wait(<Future<Object?>>[first, second]);

    expect(fake.calls['end'], hasLength(1));
  });

  test('presenter close navigation is emitted once and cleanup is idempotent',
      () async {
    final harness = _harness(role: CallParticipantRole.callee);
    final presenter = CallV2Presenter(harness: harness);

    presenter.injectPublicSnapshot(CallSnapshot.fromPublicData(_snapshotData(
      version: 3,
      lifecycle: CallLifecycle.active,
    )));
    expect(presenter.takeOpenNavigationIntent(), isNotNull);
    expect(presenter.takeOpenNavigationIntent(), isNull);

    presenter.injectPublicSnapshot(CallSnapshot.fromPublicData(_snapshotData(
      version: 4,
      lifecycle: CallLifecycle.completed,
    )));

    expect(presenter.state.closeNavigationIntentPending, isTrue);
    expect(presenter.state.closeNavigationIntentPending, isTrue);
    final close = presenter.takeCloseNavigationIntent();
    expect(close, isNotNull);
    expect(close!.type, CallNavigationIntentType.close);
    expect(close.version, 4);
    expect(presenter.takeCloseNavigationIntent(), isNull);
    expect(presenter.state.closeNavigationIntentPending, isFalse);

    await presenter.cleanupIfTerminal();
    await presenter.cleanupIfTerminal();

    expect(harness.snapshot, isNull);
    expect(presenter.state.localPhase, CallLocalPhase.idle);
    expect(presenter.state.closeNavigationIntentPending, isFalse);
  });

  test('repeated presentation-state reads do not duplicate navigation intents',
      () {
    final presenter =
        CallV2Presenter(harness: _harness(role: CallParticipantRole.callee));

    presenter.injectPublicSnapshot(CallSnapshot.fromPublicData(_snapshotData(
      version: 2,
      lifecycle: CallLifecycle.accepted,
    )));

    expect(presenter.state.openNavigationIntentPending, isTrue);
    expect(presenter.state.openNavigationIntentPending, isTrue);
    final open = presenter.takeOpenNavigationIntent();
    expect(open, isNotNull);
    expect(open!.type, CallNavigationIntentType.open);
    expect(open.version, 2);
    expect(presenter.takeOpenNavigationIntent(), isNull);
    expect(presenter.state.openNavigationIntentPending, isFalse);
  });
}

CallV2Harness _harness({
  _FakeApi? fake,
  bool enabled = true,
  required CallParticipantRole role,
}) {
  return CallV2Harness(
    featureGate: CallV2FeatureGate(enabled: enabled),
    api: CallV2Api(fake ?? _FakeApi()),
    localParticipantRole: () => role,
  );
}

void _expectActionsDisabled(CallV2PresentationState state) {
  _expectActions(state);
}

void _expectActions(
  CallV2PresentationState state, {
  bool accept = false,
  bool decline = false,
  bool cancel = false,
  bool end = false,
  bool reportMedia = false,
}) {
  expect(state.acceptEnabled, accept);
  expect(state.declineEnabled, decline);
  expect(state.cancelEnabled, cancel);
  expect(state.endEnabled, end);
  expect(state.reportMediaEnabled, reportMedia);
}

Map<String, Object?> _snapshotData({
  String callId = 'call_a',
  int version = 1,
  CallLifecycle lifecycle = CallLifecycle.ringing,
}) {
  return <String, Object?>{
    'callSystem': 'v2',
    'callId': callId,
    'version': version,
    'lifecycle': lifecycle.name,
    'callerUid': 'caller',
    'calleeUid': 'callee',
    'participantUids': <String>['caller', 'callee'],
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
}

Map<String, Object?> _startResult({
  String callId = 'server_call',
  String lifecycleState = 'ringing',
  int version = 1,
  bool idempotentReplay = false,
}) {
  return <String, Object?>{
    'callId': callId,
    'lifecycleState': lifecycleState,
    'version': version,
    'ringingDeadlineAt': '2026-06-25T12:01:00.000Z',
    'idempotentReplay': idempotentReplay,
  };
}

Map<String, Object?> _lifecycleResult({
  String callId = 'call_a',
  String lifecycleState = 'accepted',
  int version = 2,
  bool idempotentReplay = false,
}) {
  final terminal = <String>{
    'completed',
    'declined',
    'cancelled',
    'missed',
    'failed',
  }.contains(lifecycleState);
  return <String, Object?>{
    'callId': callId,
    'lifecycleState': lifecycleState,
    'version': version,
    if (terminal) 'terminal': true,
    if (terminal) 'endedAt': '2026-06-25T12:05:00.000Z',
    if (terminal) 'endReason': lifecycleState,
    'idempotentReplay': idempotentReplay,
  };
}

Map<String, Object?> _mediaResult({
  String callId = 'call_a',
  String mediaState = 'joined',
  int mediaVersion = 1,
  bool mediaChanged = true,
  String lifecycleState = 'active',
  int callVersion = 3,
  bool promotedToActive = true,
}) {
  return <String, Object?>{
    'callId': callId,
    'participantUid': 'caller',
    'mediaState': mediaState,
    'mediaVersion': mediaVersion,
    'mediaChanged': mediaChanged,
    'lifecycleState': lifecycleState,
    'callVersion': callVersion,
    'promotedToActive': promotedToActive,
    'activeAt': '2026-06-25T12:00:00.000Z',
    'reconnectDeadlineAt': null,
    'idempotentReplay': false,
  };
}

Map<String, Object?> _leaseResult({
  String callId = 'call_a',
  int heartbeatVersion = 1,
  String lifecycleState = 'active',
  int callVersion = 3,
}) {
  return <String, Object?>{
    'callId': callId,
    'participantUid': 'caller',
    'heartbeatVersion': heartbeatVersion,
    'lastHeartbeatAt': '2026-06-25T12:00:00.000Z',
    'leaseExpiresAt': '2026-06-25T12:01:00.000Z',
    'lifecycleState': lifecycleState,
    'callVersion': callVersion,
    'idempotentReplay': false,
  };
}
