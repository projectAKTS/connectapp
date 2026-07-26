import 'package:flutter/foundation.dart';

import '../call_v2_api.dart';
import 'call_v2_runtime.dart';
import 'call_v2_runtime_state.dart';

class DisabledCallV2Runtime extends ChangeNotifier implements CallV2Runtime {
  DisabledCallV2Runtime()
      : _currentState = const CallV2RuntimeState(
          phase: CallV2RuntimePhase.failed,
          errorCategory: CallV2RuntimeErrorCategory.invalidState,
        );

  CallV2RuntimeState _currentState;
  bool _disposed = false;

  @override
  CallV2RuntimeState get currentState => _currentState;

  @override
  Future<void> startOutgoingCall({
    required CallV2RuntimeCallMode mode,
  }) async {
    _reject();
  }

  @override
  Future<void> acceptIncomingCall({
    required CallV2RuntimeCallMode mode,
  }) async {
    _reject();
  }

  @override
  Future<void> endCall() async {
    if (_disposed) return;
    _currentState = _currentState.copyWith(
      phase: CallV2RuntimePhase.ended,
      clearCallShape: true,
    );
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'state': _currentState.toSafeDebugMap(),
      'disabled': true,
      'disposed': _disposed,
    };
  }

  void _reject() {
    throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
  }
}
