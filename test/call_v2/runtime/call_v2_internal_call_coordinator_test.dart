import 'package:connect_app/call_v2/firebase/fake_call_v2_token_provider.dart';
import 'package:connect_app/call_v2/permissions/fake_call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/rtc/fake_call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/runtime/call_v2_internal_call_coordinator.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_config.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_factory.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coordinator keeps fake path as one-step full flow', () async {
    final coordinator = CallV2InternalCallCoordinator(
      config: const CallV2RuntimeConfig.fake(),
    );
    addTearDown(coordinator.dispose);

    await coordinator.startOutgoingFakeFlow(CallV2RuntimeCallMode.audio);

    expect(coordinator.runtime.currentState.phase, CallV2RuntimePhase.active);
    await coordinator.end();
    expect(coordinator.runtime.currentState.phase, CallV2RuntimePhase.ended);
  });

  test('coordinator drives internal path only through explicit steps',
      () async {
    final permissions = FakeCallV2PermissionAdapter();
    final access = FakeCallV2TokenProvider();
    final rtc = FakeCallV2RtcAdapter();
    final coordinator = CallV2InternalCallCoordinator(
      config: const CallV2RuntimeConfig.internalRealDevice(
        allowPermissionRequests: true,
        allowTokenRequests: true,
        allowRtcInitialization: true,
        allowRtcJoin: true,
      ),
      factory: CallV2RuntimeFactory(
        permissionAdapter: permissions,
        tokenProvider: access,
        rtcAdapter: rtc,
      ),
    );
    addTearDown(coordinator.dispose);

    await coordinator.startOutgoing(CallV2RuntimeCallMode.video);
    expect(coordinator.runtime.currentState.phase,
        CallV2RuntimePhase.permissionPreflight);
    expect(permissions.requestMicrophoneCount, 0);

    await coordinator.requestPermissions();
    expect(access.resolveCount, 0);
    await coordinator.requestToken();
    expect(rtc.initializeCount, 0);
    await coordinator.initializeRtc();
    expect(rtc.joinCount, 0);
    await coordinator.joinRtc();
    await coordinator.activate();

    expect(coordinator.runtime.currentState.phase, CallV2RuntimePhase.active);
  });

  test('production disabled coordinator remains blocked', () async {
    final coordinator = CallV2InternalCallCoordinator(
      config: const CallV2RuntimeConfig.productionDisabled(),
    );
    addTearDown(coordinator.dispose);

    await expectLater(
      coordinator.startOutgoing(CallV2RuntimeCallMode.audio),
      throwsA(anything),
    );
  });
}
