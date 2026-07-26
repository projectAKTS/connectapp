import 'dart:io';

import 'package:connect_app/call_v2/firebase/fake_call_v2_token_provider.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/permissions/fake_call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/rtc/fake_call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/runtime/call_v2_internal_step_controller.dart';
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
