import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/firebase/fake_call_v2_token_provider.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/permissions/call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/permissions/fake_call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/rtc/fake_call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/runtime/call_v2_internal_step_controller.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_config.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_factory.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('internal smoke path reaches active and ends for audio', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await harness.run(CallV2RuntimeCallMode.audio);

    expect(harness.rtc.lastConfig!.isVideo, isFalse);
    expect(harness.controller.state.phase, CallV2RuntimePhase.ended);
    expect(harness.permissions.requestMicrophoneCount, 1);
    expect(harness.permissions.requestCameraCount, 0);
    expect(harness.access.resolveCount, 1);
    expect(harness.rtc.initializeCount, 1);
    expect(harness.rtc.joinCount, 1);
    expect(harness.rtc.leaveCount, 1);
  });

  test('internal smoke path reaches active and ends for video', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await harness.run(CallV2RuntimeCallMode.video);

    expect(harness.rtc.lastConfig!.isVideo, isTrue);
    expect(harness.permissions.requestCameraCount, 1);
    expect(harness.controller.state.phase, CallV2RuntimePhase.ended);
  });

  test('blocked and failure paths remain controlled', () async {
    final blocked =
        _Harness(config: const CallV2RuntimeConfig.internalRealDevice());
    final denied = _Harness(
      permissions: FakeCallV2PermissionAdapter(
        microphone: CallV2PermissionDecision.denied,
      ),
    );
    final rtcFailure = _Harness(rtc: FakeCallV2RtcAdapter(failJoin: true));
    addTearDown(blocked.dispose);
    addTearDown(denied.dispose);
    addTearDown(rtcFailure.dispose);

    await blocked.controller.startOutgoingAudio();
    await expectLater(
      blocked.controller.requestPermissions(),
      throwsA(isA<CallV2ClientError>()),
    );

    await denied.controller.startOutgoingAudio();
    await denied.controller.requestPermissions();
    expect(denied.controller.state.errorCategory,
        CallV2RuntimeErrorCategory.permissionDenied);

    await rtcFailure.controller.startOutgoingAudio();
    await rtcFailure.controller.requestPermissions();
    await rtcFailure.controller.requestAccess();
    await rtcFailure.controller.initializeRtc();
    await rtcFailure.controller.joinRtc();
    expect(rtcFailure.controller.state.errorCategory,
        CallV2RuntimeErrorCategory.rtcUnavailable);
  });

  test('production disabled rejects start and Call V2 remains unreachable',
      () async {
    final controller = CallV2InternalStepController(
      config: const CallV2RuntimeConfig.productionDisabled(),
    );
    addTearDown(controller.dispose);

    await expectLater(
      controller.startOutgoingAudio(),
      throwsA(isA<CallV2ClientError>()),
    );

    final routerSource =
        File('lib/navigation/app_router.dart').readAsStringSync();
    final debug =
        '${controller.toSafeDebugMap()} ${controller.toString()}'.toLowerCase();

    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(routerSource, isNot(contains('/call-v2/dev')));
    for (final forbidden in _forbiddenDebugFragments) {
      expect(debug, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}

class _Harness {
  _Harness({
    this.config = _enabledConfig,
    FakeCallV2PermissionAdapter? permissions,
    FakeCallV2TokenProvider? access,
    FakeCallV2RtcAdapter? rtc,
  })  : permissions = permissions ?? FakeCallV2PermissionAdapter(),
        access = access ?? FakeCallV2TokenProvider(),
        rtc = rtc ?? FakeCallV2RtcAdapter() {
    controller = CallV2InternalStepController(
      config: config,
      runtimeFactory: CallV2RuntimeFactory(
        permissionAdapter: this.permissions,
        tokenProvider: this.access,
        rtcAdapter: this.rtc,
      ),
    );
  }

  final CallV2RuntimeConfig config;
  final FakeCallV2PermissionAdapter permissions;
  final FakeCallV2TokenProvider access;
  final FakeCallV2RtcAdapter rtc;
  late final CallV2InternalStepController controller;

  Future<void> run(CallV2RuntimeCallMode mode) async {
    if (mode == CallV2RuntimeCallMode.video) {
      await controller.startOutgoingVideo();
    } else {
      await controller.startOutgoingAudio();
    }
    await controller.requestPermissions();
    await controller.requestAccess();
    await controller.initializeRtc();
    await controller.joinRtc();
    await controller.activate();
    expect(controller.state.phase, CallV2RuntimePhase.active);
    await controller.end();
  }

  Future<void> dispose() => controller.dispose();
}

const _enabledConfig = CallV2RuntimeConfig.internalRealDevice(
  allowPermissionRequests: true,
  allowTokenRequests: true,
  allowRtcInitialization: true,
  allowRtcJoin: true,
  exposeDevUi: true,
);

const _forbiddenDebugFragments = <String>[
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
];
