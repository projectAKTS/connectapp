import 'dart:async';

import '../call_v2_api.dart';
import '../call_v2_callable_results.dart';
import '../startup/call_v2_startup_bridge.dart';
import 'call_v2_route_intent.dart';

enum CallV2UiStatus {
  idle,
  launching,
  connecting,
  ready,
  leaving,
  closed,
  failed,
  disposed,
}

class CallV2UiState {
  const CallV2UiState({
    required this.status,
    this.errorCode,
  });

  static const idle = CallV2UiState(status: CallV2UiStatus.idle);

  final CallV2UiStatus status;
  final CallV2ClientErrorCode? errorCode;

  @override
  String toString() {
    return 'CallV2UiState(status: $status, errorCode: $errorCode)';
  }
}

class CallV2UiLaunchRequest {
  CallV2UiLaunchRequest({
    required String callId,
    required String remoteParticipantUid,
    required this.localRole,
    required this.isVideo,
  })  : callId = _validateUiIdentifier(callId),
        remoteParticipantUid = _validateUiIdentifier(remoteParticipantUid);

  final String callId;
  final String remoteParticipantUid;
  final CallV2LocalParticipantRole localRole;
  final bool isVideo;

  CallV2StartupRequest toStartupRequest() {
    return CallV2StartupRequest(
      callId: callId,
      remoteParticipantUid: remoteParticipantUid,
      localRole: localRole,
      isVideo: isVideo,
    );
  }

  bool matches(CallV2UiLaunchRequest other) {
    return callId == other.callId &&
        remoteParticipantUid == other.remoteParticipantUid &&
        localRole == other.localRole &&
        isVideo == other.isVideo;
  }

  @override
  String toString() {
    return 'CallV2UiLaunchRequest('
        'hasCallId: ${callId.isNotEmpty}, '
        'hasRemoteParticipantUid: ${remoteParticipantUid.isNotEmpty}, '
        'hasLocalRole: true, '
        'isVideo: $isVideo'
        ')';
  }
}

abstract interface class CallV2UiCoordinator {
  CallV2UiState get state;
  Stream<CallV2UiState> get states;
  Stream<CallV2RouteIntent> get routeIntents;

  Future<void> launch(CallV2UiLaunchRequest request);
  Future<void> leave();
  Future<void> dispose();
}

String _validateUiIdentifier(String value) {
  if (value.isEmpty ||
      value.trim() != value ||
      value.length > callV2MaxCallableIdentifierLength ||
      value.contains('/')) {
    throw const CallV2ClientError(CallV2ClientErrorCode.invalidRequest);
  }
  return value;
}
