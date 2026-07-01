import 'dart:async';
import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/call_v2_feature_gate.dart';
import 'package:connect_app/call_v2/call_v2_firestore_subscription_coordinator.dart';
import 'package:connect_app/call_v2/call_v2_harness.dart';
import 'package:connect_app/call_v2/call_v2_media_orchestrator.dart';
import 'package:connect_app/call_v2/call_v2_media_session_controller.dart';
import 'package:connect_app/call_v2/call_v2_runtime.dart';
import 'package:connect_app/call_v2/domain/call_lifecycle.dart';
import 'package:connect_app/call_v2/domain/call_snapshot.dart';
import 'package:connect_app/call_v2/domain/participant_media_state.dart';
import 'package:connect_app/call_v2/rtc/call_v2_resolved_rtc_config.dart';
import 'package:connect_app/call_v2/rtc/call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/rtc/call_v2_rtc_config_provider.dart';
import 'package:connect_app/call_v2/rtc/call_v2_rtc_config_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('constructor has no side effects and exposes injected components',
      () async {
    final dependencies = _Dependencies();

    final runtime = _runtime(dependencies: dependencies);

    expect(runtime.harness, same(dependencies.harness));
    expect(runtime.subscriptionCoordinator, same(dependencies.coordinator));
    expect(runtime.configResolver, same(dependencies.resolver));
    expect(runtime.mediaController, same(dependencies.media));
    expect(runtime.mediaOrchestrator, same(dependencies.orchestrator));
    expect(dependencies.coordinator.startCount, 0);
    expect(dependencies.resolver.resolveCount, 0);
    expect(dependencies.media.startCount, 0);
    expect(dependencies.orchestrator.snapshots, isEmpty);
    expect(runtime.state.status, CallV2RuntimeStatus.idle);
  });

  test('factory is pure and shares one accepted component graph', () async {
    final transport = _FakeCallableApi();
    final rtcConfigProvider = _FakeRtcConfigProvider();
    final rtcAdapter = _FakeRtcAdapter();
    var localUidReads = 0;
    var roleReads = 0;
    var mediaKeyCalls = 0;
    var orchestrationKeyCalls = 0;
    final runtime = createCallV2Runtime(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: transport,
      callDocumentStream: (_) => const Stream.empty(),
      participantDocumentStream: (_, __) => const Stream.empty(),
      rtcConfigProvider: rtcConfigProvider,
      rtcAdapter: rtcAdapter,
      localParticipantUid: () {
        localUidReads += 1;
        return 'caller';
      },
      localParticipantRole: () {
        roleReads += 1;
        return CallParticipantRole.caller;
      },
      mediaReportKeyFactory: (_, __) {
        mediaKeyCalls += 1;
        return 'media_key';
      },
      orchestrationKeyFactory: (_, __) {
        orchestrationKeyCalls += 1;
        return 'orchestration_key';
      },
    );

    expect(runtime.harness, isA<CallV2Harness>());
    expect(runtime.subscriptionCoordinator,
        isA<CallV2FirestoreSubscriptionCoordinator>());
    expect(runtime.configResolver, isA<CallV2RtcConfigResolver>());
    expect(runtime.mediaController, isA<CallV2MediaSessionController>());
    expect(runtime.mediaOrchestrator, isA<CallV2MediaOrchestrator>());
    expect(transport.invocations, isEmpty);
    expect(rtcConfigProvider.resolveCount, 0);
    expect(rtcAdapter.initializeCount, 0);
    expect(localUidReads, 0);
    expect(roleReads, 0);
    expect(mediaKeyCalls, 0);
    expect(orchestrationKeyCalls, 0);
  });

  test('disabled runtime operations are inert and consistently rejected',
      () async {
    final dependencies = _Dependencies(enabled: false);
    final runtime = _runtime(dependencies: dependencies, enabled: false);

    await expectLater(
      runtime.start(
        callId: 'call_a',
        callerUid: 'caller',
        calleeUid: 'callee',
        localUid: 'caller',
      ),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    await expectLater(
      runtime.handleAuthoritativeSnapshot(_snapshot(), isVideo: true),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    await runtime.stop();

    expect(dependencies.coordinator.startCount, 0);
    expect(dependencies.orchestrator.snapshots, isEmpty);
    expect(dependencies.orchestrator.stopCount, 0);
    expect(runtime.state.status, CallV2RuntimeStatus.stopped);
    expect(runtime.state.errorCode, CallV2ClientErrorCode.rejected);
  });

  test('valid start invokes only the subscription coordinator', () async {
    final dependencies = _Dependencies();
    final runtime = _runtime(dependencies: dependencies);

    await runtime.start(
      callId: 'call_a',
      callerUid: 'caller',
      calleeUid: 'callee',
      localUid: 'caller',
    );

    expect(dependencies.coordinator.startCount, 1);
    expect(dependencies.coordinator.startRequests, <_StartRequest>[
      const _StartRequest('call_a', 'caller', 'callee'),
    ]);
    expect(dependencies.resolver.resolveCount, 0);
    expect(dependencies.media.startCount, 0);
    expect(runtime.state.status, CallV2RuntimeStatus.running);
    expect(runtime.state.callId, 'call_a');
  });

  test('start validates identity before coordinator invocation', () async {
    final dependencies = _Dependencies();
    final runtime = _runtime(dependencies: dependencies);

    for (final identity
        in <({String callId, String caller, String callee, String local})>[
      (callId: '', caller: 'caller', callee: 'callee', local: 'caller'),
      (callId: ' call_a', caller: 'caller', callee: 'callee', local: 'caller'),
      (callId: 'call/a', caller: 'caller', callee: 'callee', local: 'caller'),
    ]) {
      await expectLater(
        runtime.start(
          callId: identity.callId,
          callerUid: identity.caller,
          calleeUid: identity.callee,
          localUid: identity.local,
        ),
        throwsA(_clientError(CallV2ClientErrorCode.invalidRequest)),
      );
    }
    await expectLater(
      runtime.start(
        callId: 'call_a',
        callerUid: 'same',
        calleeUid: 'same',
        localUid: 'same',
      ),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    await expectLater(
      runtime.start(
        callId: 'call_a',
        callerUid: 'caller',
        calleeUid: 'callee',
        localUid: 'third',
      ),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );

    expect(dependencies.coordinator.startCount, 0);
  });

  test('duplicate exact start shares one coordinator startup', () async {
    final dependencies = _Dependencies()
      ..coordinator.heldStart = Completer<void>();
    final runtime = _runtime(dependencies: dependencies);

    final first = runtime.start(
      callId: 'call_a',
      callerUid: 'caller',
      calleeUid: 'callee',
      localUid: 'caller',
    );
    final second = runtime.start(
      callId: 'call_a',
      callerUid: 'caller',
      calleeUid: 'callee',
      localUid: 'caller',
    );

    expect(dependencies.coordinator.startCount, 1);
    dependencies.coordinator.heldStart!.complete();
    await Future.wait(<Future<void>>[first, second]);
    expect(runtime.state.status, CallV2RuntimeStatus.running);
  });

  test('conflicting starts are rejected without a second coordinator call',
      () async {
    final dependencies = _Dependencies()
      ..coordinator.heldStart = Completer<void>();
    final runtime = _runtime(dependencies: dependencies);

    final first = runtime.start(
      callId: 'call_a',
      callerUid: 'caller',
      calleeUid: 'callee',
      localUid: 'caller',
    );
    await expectLater(
      runtime.start(
        callId: 'call_b',
        callerUid: 'caller',
        calleeUid: 'callee',
        localUid: 'caller',
      ),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    await expectLater(
      runtime.start(
        callId: 'call_a',
        callerUid: 'caller',
        calleeUid: 'callee',
        localUid: 'callee',
      ),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );

    dependencies.coordinator.heldStart!.complete();
    await first;
    expect(dependencies.coordinator.startCount, 1);
  });

  test('controlled and unknown coordinator errors normalize and permit retry',
      () async {
    final dependencies = _Dependencies()
      ..coordinator.nextStartError =
          const CallV2ClientError(CallV2ClientErrorCode.unauthorized);
    final runtime = _runtime(dependencies: dependencies);

    await expectLater(
      runtime.start(
        callId: 'call_a',
        callerUid: 'caller',
        calleeUid: 'callee',
        localUid: 'caller',
      ),
      throwsA(_clientError(CallV2ClientErrorCode.unauthorized)),
    );
    expect(runtime.state.status, CallV2RuntimeStatus.failed);
    expect(runtime.state.errorCode, CallV2ClientErrorCode.unauthorized);

    dependencies.coordinator.nextStartError = StateError('secret channel');
    await expectLater(
      runtime.start(
        callId: 'call_a',
        callerUid: 'caller',
        calleeUid: 'callee',
        localUid: 'caller',
      ),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );
    expect(runtime.state.errorCode, CallV2ClientErrorCode.unavailable);

    await runtime.start(
      callId: 'call_a',
      callerUid: 'caller',
      calleeUid: 'callee',
      localUid: 'caller',
    );
    expect(runtime.state.status, CallV2RuntimeStatus.running);
  });

  test('same-call snapshots delegate only to the media orchestrator', () async {
    final dependencies = _Dependencies();
    final runtime = _runtime(dependencies: dependencies);
    await _start(runtime);

    for (final lifecycle in <CallLifecycle>[
      CallLifecycle.ringing,
      CallLifecycle.accepted,
      CallLifecycle.active,
      CallLifecycle.completed,
    ]) {
      await runtime.handleAuthoritativeSnapshot(
        _snapshot(lifecycle: lifecycle),
        isVideo: true,
      );
    }

    expect(dependencies.orchestrator.handledCallIds,
        <String>['call_a', 'call_a', 'call_a', 'call_a']);
    expect(dependencies.orchestrator.isVideoRequests,
        <bool>[true, true, true, true]);
    expect(dependencies.resolver.resolveCount, 0);
    expect(dependencies.media.startCount, 0);
    expect(runtime.state.status, CallV2RuntimeStatus.running);
  });

  test('different-call snapshot is rejected before orchestrator forwarding',
      () async {
    final dependencies = _Dependencies();
    final runtime = _runtime(dependencies: dependencies);
    await _start(runtime);

    await expectLater(
      runtime.handleAuthoritativeSnapshot(
        _snapshot(callId: 'call_b', lifecycle: CallLifecycle.active),
        isVideo: true,
      ),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );

    expect(dependencies.orchestrator.snapshots, isEmpty);
  });

  test('snapshot before running and during stopping is rejected safely',
      () async {
    final dependencies = _Dependencies();
    final runtime = _runtime(dependencies: dependencies);

    await expectLater(
      runtime.handleAuthoritativeSnapshot(_snapshot(), isVideo: true),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );

    await _start(runtime);
    dependencies.coordinator.heldStop = Completer<void>();
    final stop = runtime.stop();
    await expectLater(
      runtime.handleAuthoritativeSnapshot(_snapshot(), isVideo: true),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    dependencies.coordinator.heldStop!.complete();
    await stop;
    expect(dependencies.orchestrator.snapshots, isEmpty);
  });

  test('stop after running calls orchestrator and coordinator in order',
      () async {
    final dependencies = _Dependencies();
    final runtime = _runtime(dependencies: dependencies);
    await _start(runtime);

    await runtime.stop();

    expect(dependencies.events, <String>[
      'coordinator.start:call_a',
      'orchestrator.stop',
      'coordinator.stop',
    ]);
    expect(runtime.state.status, CallV2RuntimeStatus.stopped);
    expect(runtime.state.callId, isNull);
  });

  test('stop attempts both cleanup calls and preserves controlled error',
      () async {
    final dependencies = _Dependencies()
      ..orchestrator.nextStopError =
          const CallV2ClientError(CallV2ClientErrorCode.unauthorized);
    final runtime = _runtime(dependencies: dependencies);
    await _start(runtime);

    await expectLater(
      runtime.stop(),
      throwsA(_clientError(CallV2ClientErrorCode.unauthorized)),
    );

    expect(dependencies.orchestrator.stopCount, 1);
    expect(dependencies.coordinator.stopCount, 1);
    expect(runtime.state.status, CallV2RuntimeStatus.stopped);
    expect(runtime.state.errorCode, CallV2ClientErrorCode.unauthorized);
  });

  test('unknown cleanup errors are unavailable and still finish stopped',
      () async {
    final dependencies = _Dependencies()
      ..coordinator.nextStopError = StateError('raw provider token');
    final runtime = _runtime(dependencies: dependencies);
    await _start(runtime);

    await expectLater(
      runtime.stop(),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );

    expect(dependencies.orchestrator.stopCount, 1);
    expect(dependencies.coordinator.stopCount, 1);
    expect(runtime.state.status, CallV2RuntimeStatus.stopped);
    expect(runtime.state.toString(), isNot(contains('raw provider token')));
  });

  test('duplicate stop shares one cleanup future and stop before start is safe',
      () async {
    final dependencies = _Dependencies();
    final idleRuntime = _runtime(dependencies: dependencies);
    await idleRuntime.stop();
    expect(idleRuntime.state.status, CallV2RuntimeStatus.stopped);
    expect(dependencies.orchestrator.stopCount, 0);

    final runtime = _runtime(dependencies: dependencies);
    await _start(runtime);
    dependencies.coordinator.heldStop = Completer<void>();
    final first = runtime.stop();
    final second = runtime.stop();
    await _pump();

    expect(dependencies.orchestrator.stopCount, 1);
    expect(dependencies.coordinator.stopCount, 1);
    dependencies.coordinator.heldStop!.complete();
    await Future.wait(<Future<void>>[first, second]);
    expect(runtime.state.status, CallV2RuntimeStatus.stopped);
  });

  test('fresh start works after stop', () async {
    final dependencies = _Dependencies();
    final runtime = _runtime(dependencies: dependencies);

    await _start(runtime);
    await runtime.stop();
    await runtime.start(
      callId: 'call_b',
      callerUid: 'caller',
      calleeUid: 'callee',
      localUid: 'caller',
    );

    expect(runtime.state.status, CallV2RuntimeStatus.running);
    expect(runtime.state.callId, 'call_b');
    expect(dependencies.coordinator.startRequests.last,
        const _StartRequest('call_b', 'caller', 'callee'));
  });

  test('stop during coordinator start prevents later running state', () async {
    final dependencies = _Dependencies()
      ..coordinator.heldStart = Completer<void>();
    final runtime = _runtime(dependencies: dependencies);

    final start = runtime.start(
      callId: 'call_a',
      callerUid: 'caller',
      calleeUid: 'callee',
      localUid: 'caller',
    );
    final stop = runtime.stop();
    dependencies.coordinator.heldStart!.complete();

    await expectLater(
      start,
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    await stop;

    expect(runtime.state.status, CallV2RuntimeStatus.stopped);
    expect(runtime.state.callId, isNull);
  });

  test('old start completion cannot clear newer retry', () async {
    final dependencies = _Dependencies()
      ..coordinator.heldStart = Completer<void>();
    final runtime = _runtime(dependencies: dependencies);

    final oldStart = runtime.start(
      callId: 'call_a',
      callerUid: 'caller',
      calleeUid: 'callee',
      localUid: 'caller',
    );
    final stop = runtime.stop();
    dependencies.coordinator.heldStart!.complete();
    await expectLater(
      oldStart,
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    await stop;

    await runtime.start(
      callId: 'call_a',
      callerUid: 'caller',
      calleeUid: 'callee',
      localUid: 'caller',
    );
    expect(runtime.state.status, CallV2RuntimeStatus.running);
  });

  test('fresh call is preserved after prior stop completed', () async {
    final dependencies = _Dependencies();
    final runtime = _runtime(dependencies: dependencies);

    await _start(runtime);
    await runtime.stop();
    await runtime.start(
      callId: 'call_b',
      callerUid: 'caller',
      calleeUid: 'callee',
      localUid: 'callee',
    );

    expect(runtime.state.callId, 'call_b');
    expect(runtime.state.status, CallV2RuntimeStatus.running);
  });

  test('runtime source stays isolated from startup and provider singletons',
      () async {
    final source =
        await File('lib/call_v2/call_v2_runtime.dart').readAsString();

    expect(source, isNot(contains('main.dart')));
    expect(source, isNot(contains('Navigator')));
    expect(source, isNot(contains('Firebase.initializeApp')));
    expect(source, isNot(contains('FirebaseFirestore.instance')));
    expect(source, isNot(contains('FirebaseFunctions.instance')));
    expect(source, isNot(contains('FirebaseAuth.instance')));
    expect(source, isNot(contains('Agora')));
    expect(source, isNot(contains('getIt')));
    expect(source, isNot(contains('ProviderScope')));
  });
}

CallV2Runtime _runtime({
  _Dependencies? dependencies,
  bool enabled = true,
}) {
  final deps = dependencies ?? _Dependencies(enabled: enabled);
  return CallV2Runtime(
    featureGate: deps.featureGate,
    harness: deps.harness,
    subscriptionCoordinator: deps.coordinator,
    configResolver: deps.resolver,
    mediaController: deps.media,
    mediaOrchestrator: deps.orchestrator,
  );
}

Future<void> _start(CallV2Runtime runtime) {
  return runtime.start(
    callId: 'call_a',
    callerUid: 'caller',
    calleeUid: 'callee',
    localUid: 'caller',
  );
}

CallSnapshot _snapshot({
  String callId = 'call_a',
  CallLifecycle lifecycle = CallLifecycle.ringing,
  int version = 7,
}) {
  return CallSnapshot(
    callId: callId,
    version: version,
    lifecycle: lifecycle,
    callerUid: 'caller',
    calleeUid: 'callee',
    callerMediaState: ParticipantMediaState.notJoined,
    calleeMediaState: ParticipantMediaState.notJoined,
  );
}

Matcher _clientError(CallV2ClientErrorCode code) {
  return isA<CallV2ClientError>().having(
    (error) => error.code,
    'code',
    code,
  );
}

Future<void> _pump() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _Dependencies {
  _Dependencies({bool enabled = true}) {
    featureGate = CallV2FeatureGate(enabled: enabled);
    harness = CallV2Harness(
      featureGate: featureGate,
      api: CallV2Api(_FakeCallableApi()),
      localParticipantRole: () => CallParticipantRole.caller,
    );
    coordinator = _FakeCoordinator(events);
    resolver = _FakeResolver();
    media = _FakeMediaController();
    orchestrator = _FakeOrchestrator(events);
  }

  final events = <String>[];
  late final CallV2FeatureGate featureGate;
  late final CallV2Harness harness;
  late final _FakeCoordinator coordinator;
  late final _FakeResolver resolver;
  late final _FakeMediaController media;
  late final _FakeOrchestrator orchestrator;
}

class _FakeCoordinator implements CallV2FirestoreSubscriptionCoordinating {
  _FakeCoordinator(this.events);

  final List<String> events;
  final startRequests = <_StartRequest>[];
  int startCount = 0;
  int stopCount = 0;
  Completer<void>? heldStart;
  Completer<void>? heldStop;
  Object? nextStartError;
  Object? nextStopError;

  @override
  Future<void> start({
    required String callId,
    required String callerUid,
    required String calleeUid,
  }) async {
    startCount += 1;
    startRequests.add(_StartRequest(callId, callerUid, calleeUid));
    events.add('coordinator.start:$callId');
    await heldStart?.future;
    final error = nextStartError;
    nextStartError = null;
    if (error != null) throw error;
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
    events.add('coordinator.stop');
    await heldStop?.future;
    final error = nextStopError;
    nextStopError = null;
    if (error != null) throw error;
  }
}

class _FakeOrchestrator implements CallV2MediaOrchestrator {
  _FakeOrchestrator(this.events);

  final List<String> events;
  final snapshots = <CallSnapshot>[];
  final isVideoRequests = <bool>[];
  int stopCount = 0;
  Object? nextStopError;

  List<String> get handledCallIds {
    return snapshots.map((snapshot) => snapshot.callId).toList();
  }

  @override
  Future<void> handleAuthoritativeSnapshot(
    CallSnapshot snapshot, {
    required bool isVideo,
  }) async {
    snapshots.add(snapshot);
    isVideoRequests.add(isVideo);
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
    events.add('orchestrator.stop');
    final error = nextStopError;
    nextStopError = null;
    if (error != null) throw error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeResolver implements CallV2RtcConfigResolving {
  int resolveCount = 0;

  @override
  Future<CallV2ResolvedRtcConfig> resolve({
    required bool isVideo,
    required String idempotencyKey,
  }) async {
    resolveCount += 1;
    throw StateError('resolver should not be called directly');
  }

  @override
  void invalidate() {}

  @override
  void handleAuthoritativeSnapshot(CallSnapshot snapshot) {}
}

class _FakeMediaController implements CallV2MediaSessionControlling {
  int startCount = 0;

  @override
  Future<void> start({
    required CallV2RtcSessionConfig config,
    required String preparingIdempotencyKey,
    required String joiningIdempotencyKey,
  }) async {
    startCount += 1;
    throw StateError('media should not be called directly');
  }

  @override
  Future<void> handleAuthoritativeSnapshot(CallSnapshot snapshot) async {}

  @override
  Future<void> leave({required String idempotencyKey}) async {}
}

class _FakeCallableApi implements CallableCallV2Api {
  final invocations = <String>[];

  @override
  Future<Object?> acceptCallV2(Map<String, Object?> request) async {
    invocations.add('accept');
    return null;
  }

  @override
  Future<Object?> cancelCallV2(Map<String, Object?> request) async {
    invocations.add('cancel');
    return null;
  }

  @override
  Future<Object?> declineCallV2(Map<String, Object?> request) async {
    invocations.add('decline');
    return null;
  }

  @override
  Future<Object?> endCallV2(Map<String, Object?> request) async {
    invocations.add('end');
    return null;
  }

  @override
  Future<Object?> renewActiveCallLeaseV2(Map<String, Object?> request) async {
    invocations.add('lease');
    return null;
  }

  @override
  Future<Object?> reportParticipantMediaV2(Map<String, Object?> request) async {
    invocations.add('media');
    return null;
  }

  @override
  Future<Object?> startCallV2(Map<String, Object?> request) async {
    invocations.add('start');
    return null;
  }
}

class _FakeRtcConfigProvider implements CallV2RtcConfigProvider {
  int resolveCount = 0;

  @override
  Future<Object?> resolveRtcConfig(CallV2RtcConfigRequest request) async {
    resolveCount += 1;
    return null;
  }
}

class _FakeRtcAdapter implements CallV2RtcAdapter {
  int initializeCount = 0;
  final _events = StreamController<CallV2RtcEvent>.broadcast();

  @override
  Future<void> dispose() async {}

  @override
  Stream<CallV2RtcEvent> get events => _events.stream;

  @override
  Future<void> initialize(CallV2RtcSessionConfig config) async {
    initializeCount += 1;
  }

  @override
  Future<void> joinChannel() async {}

  @override
  Future<void> leaveChannel() async {}

  @override
  Future<void> setCameraEnabled(bool enabled) async {}

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {}
}

class _StartRequest {
  const _StartRequest(this.callId, this.callerUid, this.calleeUid);

  final String callId;
  final String callerUid;
  final String calleeUid;

  @override
  bool operator ==(Object other) {
    return other is _StartRequest &&
        other.callId == callId &&
        other.callerUid == callerUid &&
        other.calleeUid == calleeUid;
  }

  @override
  int get hashCode => Object.hash(callId, callerUid, calleeUid);
}
