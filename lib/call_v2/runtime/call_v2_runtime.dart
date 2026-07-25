import 'package:flutter/foundation.dart';

import 'call_v2_runtime_state.dart';

abstract interface class CallV2Runtime implements Listenable {
  CallV2RuntimeState get currentState;

  Future<void> startOutgoingCall({
    required CallV2RuntimeCallMode mode,
  });

  Future<void> acceptIncomingCall({
    required CallV2RuntimeCallMode mode,
  });

  Future<void> endCall();

  Future<void> dispose();
}
