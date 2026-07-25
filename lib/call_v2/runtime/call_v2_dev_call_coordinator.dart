import '../firebase/fake_call_v2_token_provider.dart';
import '../permissions/fake_call_v2_permission_adapter.dart';
import '../rtc/fake_call_v2_rtc_adapter.dart';
import 'call_v2_runtime_state.dart';
import 'fake_call_v2_runtime.dart';

class CallV2DevCallCoordinator {
  CallV2DevCallCoordinator({
    FakeCallV2Runtime? runtime,
    FakeCallV2PermissionAdapter? permissionAdapter,
    FakeCallV2RtcAdapter? rtcAdapter,
    FakeCallV2TokenProvider? tokenProvider,
  }) : runtime = runtime ??
            FakeCallV2Runtime(
              permissionAdapter: permissionAdapter,
              rtcAdapter: rtcAdapter,
              tokenProvider: tokenProvider,
            );

  final FakeCallV2Runtime runtime;

  Future<void> startOutgoingFakeCall({
    required CallV2RuntimeCallMode mode,
  }) async {
    await runtime.startOutgoingCall(mode: mode);
    await runtime.requestRequiredPermissions();
    if (runtime.currentState.phase != CallV2RuntimePhase.connecting) return;
    await runtime.connectFakeRtc();
    if (runtime.currentState.phase != CallV2RuntimePhase.ready) return;
    await runtime.activateCall();
  }

  Future<void> endCall() {
    return runtime.endCall();
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'runtime': runtime.toSafeDebugMap(),
    };
  }
}
