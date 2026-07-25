import 'package:connect_app/call_v2/permissions/call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/permissions/fake_call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/rtc/fake_call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_state.dart';
import 'package:connect_app/call_v2/runtime/fake_call_v2_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('outgoing audio fake call advances manually to active and ended',
      () async {
    final runtime = FakeCallV2Runtime();
    addTearDown(runtime.dispose);

    await runtime.startOutgoingCall(mode: CallV2RuntimeCallMode.audio);
    expect(runtime.currentState.phase, CallV2RuntimePhase.permissionPreflight);

    await runtime.requestRequiredPermissions();
    expect(runtime.currentState.phase, CallV2RuntimePhase.connecting);

    await runtime.connectFakeRtc();
    expect(runtime.currentState.phase, CallV2RuntimePhase.ready);

    await runtime.activateCall();
    expect(runtime.currentState.phase, CallV2RuntimePhase.active);

    await runtime.endCall();
    expect(runtime.currentState.phase, CallV2RuntimePhase.ended);
  });

  test('video fake call requests camera explicitly', () async {
    final permissions = FakeCallV2PermissionAdapter();
    final runtime = FakeCallV2Runtime(permissionAdapter: permissions);
    addTearDown(runtime.dispose);

    await runtime.startOutgoingCall(mode: CallV2RuntimeCallMode.video);
    expect(permissions.requestCameraCount, 0);
    await runtime.requestRequiredPermissions();

    expect(permissions.requestMicrophoneCount, 1);
    expect(permissions.requestCameraCount, 1);
  });

  test('permission denied reaches controlled failed state', () async {
    final runtime = FakeCallV2Runtime(
      permissionAdapter: FakeCallV2PermissionAdapter(
        microphone: CallV2PermissionDecision.denied,
      ),
    );
    addTearDown(runtime.dispose);

    await runtime.startOutgoingCall(mode: CallV2RuntimeCallMode.audio);
    await runtime.requestRequiredPermissions();

    expect(runtime.currentState.phase, CallV2RuntimePhase.failed);
    expect(
      runtime.currentState.errorCategory,
      CallV2RuntimeErrorCategory.permissionDenied,
    );
  });

  test('RTC failure reaches controlled failed state', () async {
    final runtime = FakeCallV2Runtime(
      rtcAdapter: FakeCallV2RtcAdapter(failJoin: true),
    );
    addTearDown(runtime.dispose);

    await runtime.startOutgoingCall(mode: CallV2RuntimeCallMode.audio);
    await runtime.requestRequiredPermissions();
    await runtime.connectFakeRtc();

    expect(runtime.currentState.phase, CallV2RuntimePhase.failed);
    expect(
      runtime.currentState.errorCategory,
      CallV2RuntimeErrorCategory.rtcUnavailable,
    );
  });
}
