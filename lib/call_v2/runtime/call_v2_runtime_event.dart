import 'call_v2_runtime_state.dart';

enum CallV2RuntimeEventType {
  startOutgoingCallRequested,
  permissionPreflightPassed,
  permissionDenied,
  fakeRtcConnecting,
  fakeRtcReady,
  callActivated,
  endRequested,
  ended,
  failure,
}

class CallV2RuntimeEvent {
  const CallV2RuntimeEvent._({
    required this.type,
    this.mode,
    this.errorCategory = CallV2RuntimeErrorCategory.none,
  });

  const CallV2RuntimeEvent.startOutgoingCallRequested({
    required CallV2RuntimeCallMode mode,
  }) : this._(
          type: CallV2RuntimeEventType.startOutgoingCallRequested,
          mode: mode,
        );

  const CallV2RuntimeEvent.permissionPreflightPassed()
      : this._(type: CallV2RuntimeEventType.permissionPreflightPassed);

  const CallV2RuntimeEvent.permissionDenied()
      : this._(
          type: CallV2RuntimeEventType.permissionDenied,
          errorCategory: CallV2RuntimeErrorCategory.permissionDenied,
        );

  const CallV2RuntimeEvent.fakeRtcConnecting()
      : this._(type: CallV2RuntimeEventType.fakeRtcConnecting);

  const CallV2RuntimeEvent.fakeRtcReady()
      : this._(type: CallV2RuntimeEventType.fakeRtcReady);

  const CallV2RuntimeEvent.callActivated()
      : this._(type: CallV2RuntimeEventType.callActivated);

  const CallV2RuntimeEvent.endRequested()
      : this._(type: CallV2RuntimeEventType.endRequested);

  const CallV2RuntimeEvent.ended() : this._(type: CallV2RuntimeEventType.ended);

  const CallV2RuntimeEvent.failure(this.errorCategory)
      : type = CallV2RuntimeEventType.failure,
        mode = null;

  final CallV2RuntimeEventType type;
  final CallV2RuntimeCallMode? mode;
  final CallV2RuntimeErrorCategory errorCategory;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'type': type.name,
      'mode': mode?.name,
      'errorCategory': errorCategory.name,
    };
  }
}
