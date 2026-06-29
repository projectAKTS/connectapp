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
  int acceptCount = 0;
  Completer<void>? acceptGate;

  @override
  Future<void> acceptCallV2(Map<String, Object?> request) async {
    acceptCount += 1;
    calls.putIfAbsent('accept', () => <Map<String, Object?>>[]).add(request);
    acceptGate ??= Completer<void>();
    return acceptGate!.future;
  }

  @override
  Future<void> cancelCallV2(Map<String, Object?> request) async {
    calls.putIfAbsent('cancel', () => <Map<String, Object?>>[]).add(request);
  }

  @override
  Future<void> declineCallV2(Map<String, Object?> request) async {
    calls.putIfAbsent('decline', () => <Map<String, Object?>>[]).add(request);
  }

  @override
  Future<void> endCallV2(Map<String, Object?> request) async {
    calls.putIfAbsent('end', () => <Map<String, Object?>>[]).add(request);
  }

  @override
  Future<void> renewActiveCallLeaseV2(Map<String, Object?> request) async {
    calls.putIfAbsent('lease', () => <Map<String, Object?>>[]).add(request);
  }

  @override
  Future<void> reportParticipantMediaV2(Map<String, Object?> request) async {
    calls.putIfAbsent('media', () => <Map<String, Object?>>[]).add(request);
  }

  @override
  Future<void> startCallV2(Map<String, Object?> request) async {
    calls.putIfAbsent('start', () => <Map<String, Object?>>[]).add(request);
  }
}

class _FailingApi implements CallableCallV2Api {
  @override
  Future<void> acceptCallV2(Map<String, Object?> request) =>
      throw StateError('provider stack leak');
  @override
  Future<void> cancelCallV2(Map<String, Object?> request) =>
      throw StateError('provider stack leak');
  @override
  Future<void> declineCallV2(Map<String, Object?> request) =>
      throw StateError('provider stack leak');
  @override
  Future<void> endCallV2(Map<String, Object?> request) =>
      throw StateError('provider stack leak');
  @override
  Future<void> renewActiveCallLeaseV2(Map<String, Object?> request) =>
      throw StateError('provider stack leak');
  @override
  Future<void> reportParticipantMediaV2(Map<String, Object?> request) =>
      throw StateError('provider stack leak');
  @override
  Future<void> startCallV2(Map<String, Object?> request) =>
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
    await api.startCallV2(const CallV2RequestContext(
      callId: 'call_a',
      version: 1,
    ));
    final request = fake.calls['start']!.single;
    expect(request, containsPair('callId', 'call_a'));
    expect(request, containsPair('version', 1));
    for (final key in <String>[
      'actorUid',
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
    ]) {
      expect(request.containsKey(key), isFalse, reason: key);
    }
  });

  test('controlled errors expose only a small code contract', () async {
    final api = CallV2Api(_FailingApi());
    await expectLater(
      api.startCallV2(const CallV2RequestContext(
        callId: 'call_a',
        version: 1,
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
    final first = manager.acceptCall(const CallV2RequestContext(
      callId: 'call_a',
      version: 1,
    ));
    final second = manager.acceptCall(const CallV2RequestContext(
      callId: 'call_a',
      version: 1,
    ));
    await Future<void>.delayed(Duration.zero);

    expect(fake.acceptCount, 1);
    expect(fake.calls['accept'], hasLength(1));

    fake.acceptGate!.complete();
    await Future.wait(<Future<void>>[first, second]);
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
    await harness.startCall(const CallV2RequestContext(
      callId: 'call_a',
      version: 1,
    ));

    expect(harness.snapshot, isNull);
    expect(harness.localPhase, CallLocalPhase.idle);
    expect(fake.calls, isEmpty);
  });

  test('enabled harness derives phase and emits one safe request', () async {
    final fake = _FakeApi();
    final harness = CallV2Harness(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: CallV2Api(fake),
      localParticipantRole: () => CallParticipantRole.callee,
    );
    final snapshot = CallSnapshot.fromPublicData(
        _snapshotData(lifecycle: CallLifecycle.active));

    harness.injectPublicSnapshot(snapshot);
    await harness.startCall(const CallV2RequestContext(
      callId: 'call_a',
      version: 1,
    ));

    expect(harness.snapshot, same(snapshot));
    expect(harness.localPhase, CallLocalPhase.inCall);
    expect(fake.calls['start'], hasLength(1));
  });

  test('harness suppresses duplicate command taps while in flight', () async {
    final fake = _FakeApi();
    final harness = CallV2Harness(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: CallV2Api(fake),
      localParticipantRole: () => CallParticipantRole.callee,
    );

    final first = harness.acceptCall(const CallV2RequestContext(
      callId: 'call_a',
      version: 1,
    ));
    final second = harness.acceptCall(const CallV2RequestContext(
      callId: 'call_a',
      version: 1,
    ));
    await Future<void>.delayed(Duration.zero);

    expect(fake.acceptCount, 1);
    expect(fake.calls['accept'], hasLength(1));

    fake.acceptGate!.complete();
    await Future.wait(<Future<void>>[first, second]);
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
    await presenter.acceptCall();
    await presenter.declineCall();
    await presenter.cancelCall();
    await presenter.endCall();
    await presenter.reportMedia(
      mediaState: ParticipantMediaState.joined,
      mediaVersion: 1,
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
    final first = presenter.acceptCall();
    final second = presenter.acceptCall();
    await Future<void>.delayed(Duration.zero);

    expect(fake.acceptCount, 1);
    expect(fake.calls['accept'], hasLength(1));
    expect(fake.calls['accept']!.single, <String, Object?>{
      'callId': 'call_a',
      'version': 1,
    });

    fake.acceptGate!.complete();
    await Future.wait(<Future<void>>[first, second]);
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
    await presenter.acceptCall();
    await presenter.declineCall();
    await presenter.cancelCall();
    await presenter.endCall();
    await presenter.reportMedia(
      mediaState: ParticipantMediaState.joined,
      mediaVersion: 7,
    );

    expect(fake.calls.keys.toSet(), <String>{'end', 'media'});
    expect(fake.calls['end']!.single, <String, Object?>{
      'callId': 'call_a',
      'version': 3,
    });
    expect(fake.calls['media']!.single, <String, Object?>{
      'callId': 'call_a',
      'version': 3,
      'mediaState': 'joined',
      'mediaVersion': 7,
    });
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
