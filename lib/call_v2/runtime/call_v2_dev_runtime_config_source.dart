import 'call_v2_manual_session_inputs.dart';
import 'call_v2_runtime_config.dart';

class CallV2DevRuntimeConfigSource {
  const CallV2DevRuntimeConfigSource(this.inputs);

  final CallV2ManualSessionInputs inputs;

  CallV2RuntimeConfig buildConfig() => inputs.toRuntimeConfig();

  bool get blocksRtcSetup => inputs.useRealAdapters && !inputs.applicationReady;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'inputReady': true,
      'applicationReady': inputs.applicationReady,
      'realAdaptersReady': inputs.canUseRealAdapters,
      'setupBlocked': blocksRtcSetup,
    };
  }

  @override
  String toString() => 'CallV2DevRuntimeConfigSource(${toSafeDebugMap()})';
}
