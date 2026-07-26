import '../call_v2_api.dart';
import 'call_v2_dev_control_state.dart';
import 'call_v2_runtime.dart';
import 'call_v2_runtime_config.dart';
import 'call_v2_runtime_factory.dart';
import 'call_v2_runtime_state.dart';
import 'disabled_call_v2_runtime.dart';
import 'fake_call_v2_runtime.dart';
import 'internal_call_v2_runtime.dart';

class CallV2InternalStepController {
  CallV2InternalStepController({
    required this.config,
    CallV2RuntimeFactory runtimeFactory = const CallV2RuntimeFactory(),
  }) : runtime = runtimeFactory.create(config);

  final CallV2RuntimeConfig config;
  final CallV2Runtime runtime;

  CallV2RuntimeState get state => runtime.currentState;

  CallV2DevControlState get controls {
    final runtime = this.runtime;
    if (runtime is InternalCallV2Runtime) {
      return CallV2DevControlState.fromRuntime(
        config: config,
        state: runtime.currentState,
        hasAccess: runtime.hasAccess,
        isRtcInitialized: runtime.isRtcInitialized,
        isRtcJoined: runtime.isRtcJoined,
        isDisposed: runtime.isDisposed,
      );
    }
    if (runtime is DisabledCallV2Runtime) {
      return CallV2DevControlState.fromRuntime(
        config: const CallV2RuntimeConfig.productionDisabled(),
        state: runtime.currentState,
        hasAccess: false,
        isRtcInitialized: false,
        isRtcJoined: false,
        isDisposed: false,
      );
    }
    return CallV2DevControlState.fromRuntime(
      config: config,
      state: runtime.currentState,
      hasAccess: false,
      isRtcInitialized: false,
      isRtcJoined: false,
      isDisposed: false,
    );
  }

  Future<void> startOutgoingAudio() {
    return runtime.startOutgoingCall(mode: CallV2RuntimeCallMode.audio);
  }

  Future<void> startOutgoingVideo() {
    return runtime.startOutgoingCall(mode: CallV2RuntimeCallMode.video);
  }

  Future<void> requestPermissions() {
    final runtime = this.runtime;
    if (runtime is FakeCallV2Runtime) {
      return runtime.requestRequiredPermissions();
    }
    if (runtime is InternalCallV2Runtime) {
      return runtime.requestPermissionsExplicitly();
    }
    throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
  }

  Future<void> requestAccess() {
    final runtime = this.runtime;
    if (runtime is InternalCallV2Runtime) {
      return runtime.requestTokenExplicitly();
    }
    if (runtime is FakeCallV2Runtime) {
      return runtime.connectFakeRtc();
    }
    throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
  }

  Future<void> initializeRtc() {
    final runtime = this.runtime;
    if (runtime is InternalCallV2Runtime) {
      return runtime.initializeRtcExplicitly();
    }
    throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
  }

  Future<void> joinRtc() {
    final runtime = this.runtime;
    if (runtime is InternalCallV2Runtime) {
      return runtime.joinRtcExplicitly();
    }
    throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
  }

  Future<void> activate() {
    final runtime = this.runtime;
    if (runtime is FakeCallV2Runtime) {
      return runtime.activateCall();
    }
    if (runtime is InternalCallV2Runtime) {
      return runtime.activateCall();
    }
    throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
  }

  Future<void> end() => runtime.endCall();

  Future<void> dispose() => runtime.dispose();

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'state': state.toSafeDebugMap(),
      'controls': controls.toSafeDebugMap(),
    };
  }

  @override
  String toString() => 'CallV2InternalStepController(${toSafeDebugMap()})';
}
