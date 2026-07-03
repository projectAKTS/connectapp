import '../call_v2_api.dart';
import '../startup/call_v2_startup_bridge.dart';

enum CallV2DiagnosticCategory {
  startup,
  uiFlow,
  runtime,
  subscription,
  rtcConfig,
  rtcSession,
  cleanup,
}

enum CallV2DiagnosticOutcome {
  started,
  succeeded,
  rejected,
  unavailable,
  unauthorized,
  failed,
  cancelled,
  staleCompletionIgnored,
}

enum CallV2DiagnosticStage {
  launch,
  ready,
  leave,
  dispose,
  start,
  stop,
  initialize,
  join,
  leaveChannel,
  cleanup,
  configResolution,
  subscription,
}

class CallV2DiagnosticEvent {
  const CallV2DiagnosticEvent({
    required this.category,
    required this.outcome,
    this.stage,
    this.errorCode,
    this.isVideo,
    this.localRole,
    this.retryAttempted,
    this.cleanupAttempted,
    this.cleanupSucceeded,
  });

  final CallV2DiagnosticCategory category;
  final CallV2DiagnosticOutcome outcome;
  final CallV2DiagnosticStage? stage;
  final CallV2ClientErrorCode? errorCode;
  final bool? isVideo;
  final CallV2LocalParticipantRole? localRole;
  final bool? retryAttempted;
  final bool? cleanupAttempted;
  final bool? cleanupSucceeded;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'category': category.name,
      'outcome': outcome.name,
      if (stage != null) 'stage': stage!.name,
      if (errorCode != null) 'errorCode': errorCode!.name,
      if (isVideo != null) 'isVideo': isVideo,
      if (localRole != null) 'localRole': localRole!.name,
      if (retryAttempted != null) 'retryAttempted': retryAttempted,
      if (cleanupAttempted != null) 'cleanupAttempted': cleanupAttempted,
      if (cleanupSucceeded != null) 'cleanupSucceeded': cleanupSucceeded,
    };
  }

  @override
  String toString() {
    return 'CallV2DiagnosticEvent(${toSafeDebugMap()})';
  }

  @override
  bool operator ==(Object other) {
    return other is CallV2DiagnosticEvent &&
        other.category == category &&
        other.outcome == outcome &&
        other.stage == stage &&
        other.errorCode == errorCode &&
        other.isVideo == isVideo &&
        other.localRole == localRole &&
        other.retryAttempted == retryAttempted &&
        other.cleanupAttempted == cleanupAttempted &&
        other.cleanupSucceeded == cleanupSucceeded;
  }

  @override
  int get hashCode {
    return Object.hash(
      category,
      outcome,
      stage,
      errorCode,
      isVideo,
      localRole,
      retryAttempted,
      cleanupAttempted,
      cleanupSucceeded,
    );
  }
}
