import 'package:connect_app/call_v2/firebase/fake_call_v2_token_provider.dart';
import 'package:connect_app/call_v2/firebase/real_call_v2_token_provider.dart';
import 'package:connect_app/call_v2/firebase/firebase_call_v2_callable_transport.dart';
import 'package:connect_app/call_v2/permissions/fake_call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/permissions/call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/permissions/real_call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/rtc/agora_call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/rtc/call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/rtc/fake_call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/runtime/call_v2_manual_session_inputs.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_config.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_factory.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_state.dart';
import 'package:connect_app/call_v2/runtime/disabled_call_v2_runtime.dart';
import 'package:connect_app/call_v2/runtime/fake_call_v2_runtime.dart';
import 'package:connect_app/call_v2/runtime/internal_call_v2_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('factory creates fake runtime for fake mode', () {
    final runtime = const CallV2RuntimeFactory().create(
      const CallV2RuntimeConfig.fake(),
    );
    addTearDown(runtime.dispose);

    expect(runtime, isA<FakeCallV2Runtime>());
  });

  test('factory creates disabled runtime for production disabled mode', () {
    final runtime = const CallV2RuntimeFactory().create(
      const CallV2RuntimeConfig.productionDisabled(),
    );
    addTearDown(runtime.dispose);

    expect(runtime, isA<DisabledCallV2Runtime>());
  });

  test('factory creates internal shell without side effects', () {
    final permissions = FakeCallV2PermissionAdapter();
    final rtc = FakeCallV2RtcAdapter();
    final access = FakeCallV2TokenProvider();
    final runtime = CallV2RuntimeFactory(
      permissionAdapter: permissions,
      rtcAdapter: rtc,
      tokenProvider: access,
    ).create(
      const CallV2RuntimeConfig.internalRealDevice(
        allowPermissionRequests: true,
        allowTokenRequests: true,
        allowRtcInitialization: true,
        allowRtcJoin: true,
      ),
    );
    addTearDown(runtime.dispose);

    expect(runtime, isA<InternalCallV2Runtime>());
    expect(permissions.requestMicrophoneCount, 0);
    expect(access.resolveCount, 0);
    expect(rtc.initializeCount, 0);
    expect(rtc.joinCount, 0);
  });

  test('factory creates real internal adapter path only when explicit', () {
    final runtime = const CallV2RuntimeFactory().create(
      const CallV2RuntimeConfig.internalRealDevice(
        allowPermissionRequests: true,
        allowTokenRequests: true,
        allowRtcInitialization: true,
        allowRtcJoin: true,
        useRealAdapters: true,
        rtcApplicationIdentifier: 'app-for-test',
      ),
    );
    addTearDown(runtime.dispose);

    expect(runtime, isA<InternalCallV2Runtime>());
    final internal = runtime as InternalCallV2Runtime;
    expect(internal.permissionAdapter, isA<RealCallV2PermissionAdapter>());
    expect(internal.tokenProvider, isA<RealCallV2TokenProvider>());
    expect(internal.rtcAdapter, isA<AgoraCallV2RtcAdapter>());
    expect(internal.currentState.phase.name, 'idle');
    expect(internal.hasAccess, isFalse);
    expect(internal.isRtcInitialized, isFalse);
    expect(internal.isRtcJoined, isFalse);
  });

  test('manual real-device factory injects callable permission and rtc clients',
      () {
    final callable = _FakeCallableClient();
    final permission = _FakePermissionClient();
    final rtc = _FakeRtcClient();
    final inputs = CallV2ManualSessionInputs(
      rtcApplicationIdentifier: 'app-for-test',
      sessionIdentifier: 'session_a',
      localParticipantIdentifier: 'local_a',
      remoteParticipantIdentifier: 'remote_b',
      mode: CallV2RuntimeCallMode.audio,
      useRealAdapters: true,
      allowPermissionRequests: true,
      allowTokenRequests: true,
      allowRtcInitialization: true,
      allowRtcJoin: true,
    );

    final runtime = CallV2RuntimeFactory.manualRealDevice(
      inputs: inputs,
      transport: FirebaseCallV2CallableTransport(client: callable),
      permissionClient: permission,
      rtcClient: rtc,
    ).create(inputs.toRuntimeConfig());
    addTearDown(runtime.dispose);

    expect(runtime, isA<InternalCallV2Runtime>());
    expect(callable.calls, 0);
    expect(permission.requests, 0);
    expect(rtc.initializes, 0);
  });

  test('real adapter config safe debug exposes booleans only', () {
    const config = CallV2RuntimeConfig.internalRealDevice(
      allowPermissionRequests: true,
      allowTokenRequests: true,
      allowRtcInitialization: true,
      allowRtcJoin: true,
      useRealAdapters: true,
      rtcApplicationIdentifier: 'unsafe-app-id',
    );

    final debug = config.toSafeDebugMap().toString().toLowerCase();

    expect(debug, isNot(contains('unsafe-app-id')));
    for (final forbidden in <String>[
      'token',
      'channel',
      'uid',
      'user',
      'participant',
      'callid',
      'device',
      'credential',
      'secret',
      'raw',
      'payload',
      'stack',
    ]) {
      expect(debug, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}

class _FakeCallableClient implements FirebaseCallV2CallableClient {
  int calls = 0;

  @override
  Future<Object?> call(String name, Map<String, Object?> data) async {
    calls += 1;
    return <String, Object?>{'status': 'disabled'};
  }
}

class _FakePermissionClient implements RealCallV2PermissionClient {
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

class _FakeRtcClient implements AgoraCallV2RtcEngineClient {
  int initializes = 0;

  @override
  Future<void> initialize({
    required CallV2RtcSessionConfig config,
    required void Function(CallV2RtcEvent event) emit,
  }) async {
    initializes += 1;
  }

  @override
  Future<void> join() async {}

  @override
  Future<void> leave() async {}

  @override
  Future<void> setCameraEnabled(bool enabled) async {}

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {}

  @override
  Future<void> dispose() async {}
}
