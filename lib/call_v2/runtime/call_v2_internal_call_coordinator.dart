import 'call_v2_runtime.dart';
import 'call_v2_runtime_config.dart';
import 'call_v2_runtime_factory.dart';
import 'call_v2_runtime_mode.dart';
import 'call_v2_runtime_state.dart';
import 'disabled_call_v2_runtime.dart';
import 'fake_call_v2_runtime.dart';
import 'internal_call_v2_runtime.dart';

class CallV2InternalCallCoordinator {
  CallV2InternalCallCoordinator({
    required this.config,
    CallV2RuntimeFactory factory = const CallV2RuntimeFactory(),
  }) : runtime = factory.create(config);

  final CallV2RuntimeConfig config;
  final CallV2Runtime runtime;

  Future<void> startOutgoing(CallV2RuntimeCallMode mode) {
    return runtime.startOutgoingCall(mode: mode);
  }

  Future<void> startOutgoingFakeFlow(CallV2RuntimeCallMode mode) async {
    if (runtime case final FakeCallV2Runtime fake) {
      await fake.startOutgoingCall(mode: mode);
      await fake.requestRequiredPermissions();
      await fake.connectFakeRtc();
      await fake.activateCall();
      return;
    }
    throw UnsupportedError('fake flow unavailable');
  }

  Future<void> requestPermissions() {
    if (runtime case final InternalCallV2Runtime internal) {
      return internal.requestPermissionsExplicitly();
    }
    if (runtime case final FakeCallV2Runtime fake) {
      return fake.requestRequiredPermissions();
    }
    throw UnsupportedError('permission step unavailable');
  }

  Future<void> requestToken() {
    if (runtime case final InternalCallV2Runtime internal) {
      return internal.requestTokenExplicitly();
    }
    if (runtime case final FakeCallV2Runtime fake) {
      return fake.connectFakeRtc();
    }
    throw UnsupportedError('access step unavailable');
  }

  Future<void> initializeRtc() {
    if (runtime case final InternalCallV2Runtime internal) {
      return internal.initializeRtcExplicitly();
    }
    throw UnsupportedError('setup step unavailable');
  }

  Future<void> joinRtc() {
    if (runtime case final InternalCallV2Runtime internal) {
      return internal.joinRtcExplicitly();
    }
    throw UnsupportedError('join step unavailable');
  }

  Future<void> activate() {
    if (runtime case final InternalCallV2Runtime internal) {
      return internal.activateCall();
    }
    if (runtime case final FakeCallV2Runtime fake) {
      return fake.activateCall();
    }
    throw UnsupportedError('activate step unavailable');
  }

  Future<void> end() {
    return runtime.endCall();
  }

  Future<void> dispose() {
    return runtime.dispose();
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'mode': config.mode.name,
      'fakeDefault': config.mode == CallV2RuntimeMode.fake,
      'disabled': runtime is DisabledCallV2Runtime,
      'state': runtime.currentState.toSafeDebugMap(),
    };
  }
}
