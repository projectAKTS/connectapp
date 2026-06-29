import 'domain/call_v2_models.dart';

enum CallNavigationIntentType {
  open,
  close,
}

class CallNavigationIntent {
  const CallNavigationIntent._(this.type, this.callId, this.version);

  const CallNavigationIntent.open({
    required String callId,
    required int version,
  }) : this._(CallNavigationIntentType.open, callId, version);

  const CallNavigationIntent.close({
    required String callId,
    required int version,
  }) : this._(CallNavigationIntentType.close, callId, version);

  final CallNavigationIntentType type;
  final String callId;
  final int version;
}

class CallNavigationCoordinatorV2 {
  const CallNavigationCoordinatorV2();

  CallNavigationIntent? openIntentFor(CallV2Snapshot snapshot) {
    if (snapshot.lifecycle.isTerminal) return null;
    return CallNavigationIntent.open(
        callId: snapshot.callId, version: snapshot.version);
  }

  CallNavigationIntent closeIntentFor(CallV2Snapshot snapshot) {
    return CallNavigationIntent.close(
        callId: snapshot.callId, version: snapshot.version);
  }
}
