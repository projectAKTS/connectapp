import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/firebase/fake_call_v2_token_provider.dart';
import 'package:connect_app/call_v2/permissions/fake_call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/rtc/fake_call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/runtime/call_v2_internal_step_controller.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_config.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_factory.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('drives internal real-device path through explicit controls', () async {
    final permissions = FakeCallV2PermissionAdapter();
    final access = FakeCallV2TokenProvider();
    final rtc = FakeCallV2RtcAdapter();
    final controller = _controller(
      permissions: permissions,
      access: access,
      rtc: rtc,
    );
    addTearDown(controller.dispose);

    expect(controller.controls.canStart, isTrue);
    await controller.startOutgoingAudio();
    expect(controller.state.phase, CallV2RuntimePhase.permissionPreflight);
    expect(controller.controls.canRequestPermissions, isTrue);

    await controller.requestPermissions();
    expect(controller.state.phase, CallV2RuntimePhase.connecting);
    expect(permissions.requestMicrophoneCount, 1);

    await controller.requestAccess();
    expect(access.resolveCount, 1);
    expect(controller.controls.canInitializeRtc, isTrue);

    await controller.initializeRtc();
    expect(rtc.initializeCount, 1);
    expect(controller.controls.canJoinRtc, isTrue);

    await controller.joinRtc();
    expect(rtc.joinCount, 1);
    expect(controller.state.phase, CallV2RuntimePhase.ready);
    expect(controller.controls.canActivate, isTrue);

    await controller.activate();
    expect(controller.state.phase, CallV2RuntimePhase.active);

    await controller.end();
    expect(controller.state.phase, CallV2RuntimePhase.ended);
    expect(rtc.leaveCount, 1);
  });

  test('blocked config rejects permission access init and join steps',
      () async {
    final controller = _controller(
      config: const CallV2RuntimeConfig.internalRealDevice(),
    );
    addTearDown(controller.dispose);

    await controller.startOutgoingAudio();
    await expectLater(
      controller.requestPermissions(),
      throwsA(isA<CallV2ClientError>()),
    );
    await expectLater(
      controller.requestAccess(),
      throwsA(isA<CallV2ClientError>()),
    );
    await expectLater(
      controller.initializeRtc(),
      throwsA(isA<CallV2ClientError>()),
    );
    await expectLater(
      controller.joinRtc(),
      throwsA(isA<CallV2ClientError>()),
    );
  });

  test('production disabled rejects start and exposes no unsafe debug',
      () async {
    final controller = CallV2InternalStepController(
      config: const CallV2RuntimeConfig.productionDisabled(),
    );
    addTearDown(controller.dispose);

    await expectLater(
      controller.startOutgoingAudio(),
      throwsA(isA<CallV2ClientError>()),
    );
    final output =
        '${controller.toSafeDebugMap()} ${controller.toString()}'.toLowerCase();
    for (final forbidden in _forbiddenDebugFragments) {
      expect(output, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}

CallV2InternalStepController _controller({
  CallV2RuntimeConfig config = _enabledConfig,
  FakeCallV2PermissionAdapter? permissions,
  FakeCallV2TokenProvider? access,
  FakeCallV2RtcAdapter? rtc,
}) {
  return CallV2InternalStepController(
    config: config,
    runtimeFactory: CallV2RuntimeFactory(
      permissionAdapter: permissions ?? FakeCallV2PermissionAdapter(),
      tokenProvider: access ?? FakeCallV2TokenProvider(),
      rtcAdapter: rtc ?? FakeCallV2RtcAdapter(),
    ),
  );
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
