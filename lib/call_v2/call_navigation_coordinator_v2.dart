import 'domain/call_snapshot.dart';

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
  CallNavigationCoordinatorV2();

  final Map<String, int> _openedVersions = <String, int>{};
  final Set<String> _closedCalls = <String>{};

  CallNavigationIntent? openIntentFor(CallSnapshot snapshot) {
    if (snapshot.lifecycle.isTerminal) return null;
    final lastOpened = _openedVersions[snapshot.callId];
    if (lastOpened != null && snapshot.version <= lastOpened) return null;
    _openedVersions[snapshot.callId] = snapshot.version;
    return CallNavigationIntent.open(
        callId: snapshot.callId, version: snapshot.version);
  }

  CallNavigationIntent? closeIntentFor(CallSnapshot snapshot) {
    if (!snapshot.lifecycle.isTerminal) return null;
    if (_closedCalls.contains(snapshot.callId)) return null;
    _closedCalls.add(snapshot.callId);
    return CallNavigationIntent.close(
        callId: snapshot.callId, version: snapshot.version);
  }
}
