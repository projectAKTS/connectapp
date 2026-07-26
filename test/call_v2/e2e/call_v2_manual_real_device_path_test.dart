import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/firebase/fake_call_v2_token_provider.dart';
import 'package:connect_app/call_v2/firebase/firebase_call_v2_callable_transport.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/permissions/call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/permissions/fake_call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/permissions/real_call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/rtc/agora_call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/rtc/call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/rtc/fake_call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/runtime/call_v2_internal_step_controller.dart';
import 'package:connect_app/call_v2/runtime/call_v2_manual_session_inputs.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_config.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_factory.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual real-device path with fake platform clients is explicit',
      () async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await harness.controller.startOutgoingVideo();
    expect(
        harness.controller.state.phase, CallV2RuntimePhase.permissionPreflight);
    expect(harness.permissions.requestMicrophoneCount, 0);
    expect(harness.access.resolveCount, 0);
    expect(harness.rtc.initializeCount, 0);

    await harness.controller.requestPermissions();
    await harness.controller.requestAccess();
    await harness.controller.initializeRtc();
    await harness.controller.joinRtc();
    await harness.controller.activate();
    await harness.controller.end();
    await harness.controller.dispose();
    await harness.controller.dispose();

    expect(harness.permissions.requestMicrophoneCount, 1);
    expect(harness.permissions.requestCameraCount, 1);
    expect(harness.access.resolveCount, 1);
    expect(harness.rtc.initializeCount, 1);
    expect(harness.rtc.joinCount, 1);
    expect(harness.rtc.leaveCount, 1);
    expect(harness.rtc.disposeCount, 1);
  });

  test('manual real-device path recovers through controlled failures',
      () async {
    final tokenFailure = _Harness(access: FakeCallV2TokenProvider(fail: true));
    final initFailure =
        _Harness(rtc: FakeCallV2RtcAdapter(failInitialize: true));
    final joinFailure = _Harness(rtc: FakeCallV2RtcAdapter(failJoin: true));
    addTearDown(tokenFailure.dispose);
    addTearDown(initFailure.dispose);
    addTearDown(joinFailure.dispose);

    await tokenFailure.startThroughPermissions();
    await tokenFailure.controller.requestAccess();
    expect(tokenFailure.controller.state.errorCategory,
        CallV2RuntimeErrorCategory.backendUnavailable);

    await initFailure.startThroughAccess();
    await initFailure.controller.initializeRtc();
    expect(initFailure.controller.state.errorCategory,
        CallV2RuntimeErrorCategory.rtcUnavailable);

    await joinFailure.startThroughAccess();
    await joinFailure.controller.initializeRtc();
    await joinFailure.controller.joinRtc();
    expect(joinFailure.controller.state.errorCategory,
        CallV2RuntimeErrorCategory.rtcUnavailable);
  });

  test('manual real-device path keeps rollout false and no public route', () {
    final router = File('lib/navigation/app_router.dart').readAsStringSync();

    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(router, isNot(contains('CallV2ManualDevEntry')));
    expect(router, isNot(contains('/call-v2/manual')));
  });

  test('manual real-device path uses fake clients one explicit step at a time',
      () async {
    final callable = _FakeCallableClient();
    final permissions = _RealPermissionFake();
    final rtc = _AgoraFake();
    final inputs = _inputs(local: 'manual_a', remote: 'manual_b');
    final controller = CallV2InternalStepController(
      config: inputs.toRuntimeConfig(),
      runtimeFactory: CallV2RuntimeFactory.manualRealDevice(
        inputs: inputs,
        transport: FirebaseCallV2CallableTransport(client: callable),
        permissionClient: permissions,
        rtcClient: rtc,
      ),
    );
    addTearDown(controller.dispose);

    expect(callable.calls, 0);
    expect(permissions.requests, 0);
    expect(rtc.initializes, 0);

    await controller.startOutgoingVideo();
    await controller.requestPermissions();
    await controller.requestAccess();
    await controller.initializeRtc();
    await controller.joinRtc();
    await controller.activate();
    await controller.end();
    await controller.dispose();

    expect(permissions.requests, 2);
    expect(callable.calls, 1);
    expect(rtc.initializes, 1);
    expect(rtc.joins, 1);
    expect(rtc.leaves, 1);
    expect(controller.state.phase, CallV2RuntimePhase.ended);
  });

  test('two-device mirrored inputs produce same routing readiness', () {
    final a = _inputs(local: 'manual_a', remote: 'manual_b');
    final b = _inputs(local: 'manual_b', remote: 'manual_a');

    expect(a.sessionIdentifier, b.sessionIdentifier);
    expect(a.toTokenBackendData()['callId'], b.toTokenBackendData()['callId']);
    expect(a.toTokenBackendData()['participantUid'], 'manual_a');
    expect(b.toTokenBackendData()['participantUid'], 'manual_b');
    expect(a.toSafeDebugMap()['realAdaptersReady'], isTrue);
    expect(b.toSafeDebugMap()['realAdaptersReady'], isTrue);
    expect(a.toString(), isNot(contains('manual_a')));
    expect(b.toString(), isNot(contains('manual_b')));
  });

  test(
      'two-device mirrored explicit access uses same route and distinct handles',
      () async {
    final callableA = _FakeCallableClient(rtcUid: 101);
    final callableB = _FakeCallableClient(rtcUid: 202);
    final inputsA = _inputs(local: 'manual_a', remote: 'manual_b');
    final inputsB = _inputs(local: 'manual_b', remote: 'manual_a');
    final controllerA = _controllerFor(inputsA, callableA);
    final controllerB = _controllerFor(inputsB, callableB);
    addTearDown(controllerA.dispose);
    addTearDown(controllerB.dispose);

    await controllerA.startOutgoingVideo();
    await controllerB.startOutgoingVideo();
    await controllerA.requestPermissions();
    await controllerB.requestPermissions();
    await controllerA.requestAccess();
    await controllerB.requestAccess();

    expect(callableA.lastData['callId'], callableB.lastData['callId']);
    expect(callableA.lastData['participantUid'], 'manual_a');
    expect(callableB.lastData['participantUid'], 'manual_b');
    expect(callableA.lastData['isVideo'], isTrue);
    expect(callableB.lastData['isVideo'], isTrue);
    expect(controllerA.state.phase, CallV2RuntimePhase.connecting);
    expect(controllerB.state.phase, CallV2RuntimePhase.connecting);
  });

  test('disabled callable and missing app id fail safely', () async {
    final disabled = _Harness(access: FakeCallV2TokenProvider(fail: true));
    addTearDown(disabled.dispose);
    await disabled.startThroughPermissions();
    await disabled.controller.requestAccess();
    expect(
      disabled.controller.state.errorCategory,
      CallV2RuntimeErrorCategory.backendUnavailable,
    );

    final missingApp = _inputs(app: '');
    final controller = CallV2InternalStepController(
      config: missingApp.toRuntimeConfig(),
      runtimeFactory: CallV2RuntimeFactory.manualRealDevice(
        inputs: missingApp,
        transport: FirebaseCallV2CallableTransport(
          client: _FakeCallableClient(),
        ),
        permissionClient: _RealPermissionFake(),
        rtcClient: _AgoraFake(),
      ),
    );
    addTearDown(controller.dispose);
    await controller.startOutgoingAudio();
    await controller.requestPermissions();
    await controller.requestAccess();
    expect(
      () => controller.initializeRtc(),
      throwsA(isA<CallV2ClientError>()),
    );
  });
}

CallV2InternalStepController _controllerFor(
  CallV2ManualSessionInputs inputs,
  _FakeCallableClient callable,
) {
  return CallV2InternalStepController(
    config: inputs.toRuntimeConfig(),
    runtimeFactory: CallV2RuntimeFactory.manualRealDevice(
      inputs: inputs,
      transport: FirebaseCallV2CallableTransport(client: callable),
      permissionClient: _RealPermissionFake(),
      rtcClient: _AgoraFake(),
    ),
  );
}

class _Harness {
  _Harness({
    FakeCallV2PermissionAdapter? permissions,
    FakeCallV2TokenProvider? access,
    FakeCallV2RtcAdapter? rtc,
  })  : permissions = permissions ?? FakeCallV2PermissionAdapter(),
        access = access ?? FakeCallV2TokenProvider(),
        rtc = rtc ?? FakeCallV2RtcAdapter() {
    controller = CallV2InternalStepController(
      config: const CallV2RuntimeConfig.internalRealDevice(
        allowPermissionRequests: true,
        allowTokenRequests: true,
        allowRtcInitialization: true,
        allowRtcJoin: true,
        exposeDevUi: true,
        useRealAdapters: true,
      ),
      runtimeFactory: CallV2RuntimeFactory(
        permissionAdapter: this.permissions,
        tokenProvider: this.access,
        rtcAdapter: this.rtc,
      ),
    );
  }

  final FakeCallV2PermissionAdapter permissions;
  final FakeCallV2TokenProvider access;
  final FakeCallV2RtcAdapter rtc;
  late final CallV2InternalStepController controller;

  Future<void> startThroughPermissions() async {
    await controller.startOutgoingAudio();
    await controller.requestPermissions();
  }

  Future<void> startThroughAccess() async {
    await startThroughPermissions();
    await controller.requestAccess();
  }

  Future<void> dispose() => controller.dispose();
}

CallV2ManualSessionInputs _inputs({
  String app = 'app-for-test',
  String local = 'manual_a',
  String remote = 'manual_b',
}) {
  return CallV2ManualSessionInputs(
    rtcApplicationIdentifier: app,
    sessionIdentifier: 'same_session',
    localParticipantIdentifier: local,
    remoteParticipantIdentifier: remote,
    mode: CallV2RuntimeCallMode.video,
    useRealAdapters: true,
    allowPermissionRequests: true,
    allowTokenRequests: true,
    allowRtcInitialization: true,
    allowRtcJoin: true,
  );
}

class _FakeCallableClient implements FirebaseCallV2CallableClient {
  _FakeCallableClient({this.rtcUid = 7});

  final int rtcUid;
  int calls = 0;
  Map<String, Object?> lastData = const <String, Object?>{};

  @override
  Future<Object?> call(String name, Map<String, Object?> data) async {
    calls += 1;
    lastData = Map<String, Object?>.of(data);
    return <String, Object?>{
      'status': 'ok',
      'result': <String, Object?>{
        'channelAlias': 'same-channel',
        'rtcUid': rtcUid,
        'expiresInSeconds': 3600,
        'token': 'same-token',
      },
    };
  }
}

class _RealPermissionFake implements RealCallV2PermissionClient {
  int requests = 0;

  @override
  Future<CallV2PermissionDecision> check(
      CallV2PermissionKind permission) async {
    return CallV2PermissionDecision.granted;
  }

  @override
  Future<CallV2PermissionDecision> request(
    CallV2PermissionKind permission,
  ) async {
    requests += 1;
    return CallV2PermissionDecision.granted;
  }
}

class _AgoraFake implements AgoraCallV2RtcEngineClient {
  int initializes = 0;
  int joins = 0;
  int leaves = 0;

  @override
  Future<void> initialize({
    required CallV2RtcSessionConfig config,
    required void Function(CallV2RtcEvent event) emit,
  }) async {
    initializes += 1;
  }

  @override
  Future<void> join() async {
    joins += 1;
  }

  @override
  Future<void> leave() async {
    leaves += 1;
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {}

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {}

  @override
  Future<void> dispose() async {}
}
