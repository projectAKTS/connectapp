import '../call_v2_api.dart';
import '../call_v2_callable_results.dart';

abstract interface class CallV2StartupBridge {
  CallV2StartupBridgeState get state;

  Future<void> start(CallV2StartupRequest request);
  Future<void> stop();
  Future<void> dispose();
}

enum CallV2StartupBridgeStatus {
  idle,
  starting,
  running,
  stopping,
  stopped,
  failed,
  disposed,
}

enum CallV2LocalParticipantRole {
  caller,
  callee,
}

class CallV2StartupBridgeState {
  const CallV2StartupBridgeState({
    required this.status,
    this.errorCode,
  });

  static const idle = CallV2StartupBridgeState(
    status: CallV2StartupBridgeStatus.idle,
  );

  final CallV2StartupBridgeStatus status;
  final CallV2ClientErrorCode? errorCode;

  @override
  String toString() {
    return 'CallV2StartupBridgeState('
        'status: $status, '
        'errorCode: $errorCode'
        ')';
  }
}

class CallV2StartupRequest {
  CallV2StartupRequest({
    required String callId,
    required String remoteParticipantUid,
    required this.localRole,
    required this.isVideo,
  })  : callId = _validateIdentifier(callId),
        remoteParticipantUid = _validateIdentifier(remoteParticipantUid);

  final String callId;
  final String remoteParticipantUid;
  final CallV2LocalParticipantRole localRole;
  final bool isVideo;

  bool matches(CallV2StartupRequest other) {
    return callId == other.callId &&
        remoteParticipantUid == other.remoteParticipantUid &&
        localRole == other.localRole &&
        isVideo == other.isVideo;
  }

  @override
  String toString() {
    return 'CallV2StartupRequest('
        'hasCallId: ${callId.isNotEmpty}, '
        'hasRemoteParticipantUid: ${remoteParticipantUid.isNotEmpty}, '
        'localRole: ${localRole.name}, '
        'isVideo: $isVideo'
        ')';
  }
}

String _validateIdentifier(String value) {
  if (value.isEmpty ||
      value.trim() != value ||
      value.length > callV2MaxCallableIdentifierLength ||
      value.contains('/')) {
    throw const CallV2ClientError(CallV2ClientErrorCode.invalidRequest);
  }
  return value;
}
