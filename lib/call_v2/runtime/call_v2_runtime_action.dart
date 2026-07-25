enum CallV2RuntimeActionType {
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

class CallV2RuntimeAction {
  const CallV2RuntimeAction(this.type);

  final CallV2RuntimeActionType type;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{'type': type.name};
  }
}
