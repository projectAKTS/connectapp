import '../call_v2_api.dart';
import 'call_v2_production_lifecycle_design.dart';

enum CallV2ProductionFailure {
  rolloutDisabled,
  approvalMissing,
  unauthenticated,
  appCheckUnavailable,
  permissionDenied,
  invalidRequest,
  backendUnavailable,
  backendRejected,
  invalidSnapshot,
  rtcConfigUnavailable,
  rtcInitializeFailure,
  rtcJoinFailure,
  networkInterruption,
  credentialExpiry,
  remoteParticipantAbsent,
  routeSinkUnavailable,
  appDisposed,
  duplicateLaunch,
  selfCallAttempt,
}

enum CallV2ProductionFailureSourceLayer {
  rollout,
  approval,
  authentication,
  appCheck,
  permission,
  backend,
  snapshot,
  rtcConfig,
  rtcSession,
  network,
  routing,
  appLifecycle,
  coordinator,
}

enum CallV2ProductionUserVisibleOutcome {
  remainUnavailable,
  stayOnCurrentScreen,
  showControlledFailure,
  showPermissionPromptResult,
  reconnectingState,
  closeCallFlow,
}

enum CallV2ProductionCleanupPolicy {
  none,
  closeOwnedRoute,
  stopStartupBridge,
  stopRuntime,
  leaveRtcAndStopSubscription,
  disposeComposition,
}

enum CallV2ProductionRetryPolicy {
  never,
  sameRequestOnly,
  afterUserAction,
  afterForegroundRecovery,
  afterConfigurationRecovery,
}

class CallV2ProductionFailureMatrixEntry {
  const CallV2ProductionFailureMatrixEntry({
    required this.failure,
    required this.sourceLayer,
    required this.errorCode,
    required this.userVisibleOutcome,
    required this.cleanupPolicy,
    required this.retryPolicy,
    required this.observabilityEvent,
    required this.rawDetailsSuppressed,
  });

  final CallV2ProductionFailure failure;
  final CallV2ProductionFailureSourceLayer sourceLayer;
  final CallV2ClientErrorCode errorCode;
  final CallV2ProductionUserVisibleOutcome userVisibleOutcome;
  final CallV2ProductionCleanupPolicy cleanupPolicy;
  final CallV2ProductionRetryPolicy retryPolicy;
  final CallV2ProductionObservabilityEvent observabilityEvent;
  final bool rawDetailsSuppressed;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'failure': failure.name,
      'sourceLayer': sourceLayer.name,
      'errorCode': errorCode.name,
      'userVisibleOutcome': userVisibleOutcome.name,
      'cleanupPolicy': cleanupPolicy.name,
      'retryPolicy': retryPolicy.name,
      'observabilityEvent': observabilityEvent.name,
      'rawDetailsSuppressed': rawDetailsSuppressed,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionFailureMatrixEntry(${toSafeDebugMap()})';
  }
}

class CallV2ProductionFailureMatrix {
  factory CallV2ProductionFailureMatrix({
    required List<CallV2ProductionFailureMatrixEntry> entries,
  }) {
    return CallV2ProductionFailureMatrix._(
      List<CallV2ProductionFailureMatrixEntry>.unmodifiable(entries),
    );
  }

  const CallV2ProductionFailureMatrix._(this.entries);

  final List<CallV2ProductionFailureMatrixEntry> entries;

  CallV2ProductionFailureMatrixEntry entryFor(
    CallV2ProductionFailure failure,
  ) {
    return entries.singleWhere((entry) => entry.failure == failure);
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'entries': entries.map((entry) => entry.toSafeDebugMap()).toList(),
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionFailureMatrix(${toSafeDebugMap()})';
  }
}

const callV2ProductionFailureMatrixEntries =
    <CallV2ProductionFailureMatrixEntry>[
  CallV2ProductionFailureMatrixEntry(
    failure: CallV2ProductionFailure.rolloutDisabled,
    sourceLayer: CallV2ProductionFailureSourceLayer.rollout,
    errorCode: CallV2ClientErrorCode.rejected,
    userVisibleOutcome: CallV2ProductionUserVisibleOutcome.remainUnavailable,
    cleanupPolicy: CallV2ProductionCleanupPolicy.none,
    retryPolicy: CallV2ProductionRetryPolicy.afterConfigurationRecovery,
    observabilityEvent: CallV2ProductionObservabilityEvent.launchRejected,
    rawDetailsSuppressed: true,
  ),
  CallV2ProductionFailureMatrixEntry(
    failure: CallV2ProductionFailure.approvalMissing,
    sourceLayer: CallV2ProductionFailureSourceLayer.approval,
    errorCode: CallV2ClientErrorCode.rejected,
    userVisibleOutcome: CallV2ProductionUserVisibleOutcome.remainUnavailable,
    cleanupPolicy: CallV2ProductionCleanupPolicy.none,
    retryPolicy: CallV2ProductionRetryPolicy.afterConfigurationRecovery,
    observabilityEvent: CallV2ProductionObservabilityEvent.launchRejected,
    rawDetailsSuppressed: true,
  ),
  CallV2ProductionFailureMatrixEntry(
    failure: CallV2ProductionFailure.unauthenticated,
    sourceLayer: CallV2ProductionFailureSourceLayer.authentication,
    errorCode: CallV2ClientErrorCode.unauthorized,
    userVisibleOutcome:
        CallV2ProductionUserVisibleOutcome.showControlledFailure,
    cleanupPolicy: CallV2ProductionCleanupPolicy.closeOwnedRoute,
    retryPolicy: CallV2ProductionRetryPolicy.afterUserAction,
    observabilityEvent: CallV2ProductionObservabilityEvent.launchRejected,
    rawDetailsSuppressed: true,
  ),
  CallV2ProductionFailureMatrixEntry(
    failure: CallV2ProductionFailure.appCheckUnavailable,
    sourceLayer: CallV2ProductionFailureSourceLayer.appCheck,
    errorCode: CallV2ClientErrorCode.unavailable,
    userVisibleOutcome:
        CallV2ProductionUserVisibleOutcome.showControlledFailure,
    cleanupPolicy: CallV2ProductionCleanupPolicy.stopStartupBridge,
    retryPolicy: CallV2ProductionRetryPolicy.afterForegroundRecovery,
    observabilityEvent:
        CallV2ProductionObservabilityEvent.compositionUnavailable,
    rawDetailsSuppressed: true,
  ),
  CallV2ProductionFailureMatrixEntry(
    failure: CallV2ProductionFailure.permissionDenied,
    sourceLayer: CallV2ProductionFailureSourceLayer.permission,
    errorCode: CallV2ClientErrorCode.rejected,
    userVisibleOutcome:
        CallV2ProductionUserVisibleOutcome.showPermissionPromptResult,
    cleanupPolicy: CallV2ProductionCleanupPolicy.closeOwnedRoute,
    retryPolicy: CallV2ProductionRetryPolicy.afterUserAction,
    observabilityEvent: CallV2ProductionObservabilityEvent.permissionDenied,
    rawDetailsSuppressed: true,
  ),
  CallV2ProductionFailureMatrixEntry(
    failure: CallV2ProductionFailure.invalidRequest,
    sourceLayer: CallV2ProductionFailureSourceLayer.coordinator,
    errorCode: CallV2ClientErrorCode.invalidRequest,
    userVisibleOutcome:
        CallV2ProductionUserVisibleOutcome.showControlledFailure,
    cleanupPolicy: CallV2ProductionCleanupPolicy.none,
    retryPolicy: CallV2ProductionRetryPolicy.never,
    observabilityEvent: CallV2ProductionObservabilityEvent.launchRejected,
    rawDetailsSuppressed: true,
  ),
  CallV2ProductionFailureMatrixEntry(
    failure: CallV2ProductionFailure.backendUnavailable,
    sourceLayer: CallV2ProductionFailureSourceLayer.backend,
    errorCode: CallV2ClientErrorCode.unavailable,
    userVisibleOutcome:
        CallV2ProductionUserVisibleOutcome.showControlledFailure,
    cleanupPolicy: CallV2ProductionCleanupPolicy.stopRuntime,
    retryPolicy: CallV2ProductionRetryPolicy.afterForegroundRecovery,
    observabilityEvent: CallV2ProductionObservabilityEvent.backendStartRejected,
    rawDetailsSuppressed: true,
  ),
  CallV2ProductionFailureMatrixEntry(
    failure: CallV2ProductionFailure.backendRejected,
    sourceLayer: CallV2ProductionFailureSourceLayer.backend,
    errorCode: CallV2ClientErrorCode.rejected,
    userVisibleOutcome:
        CallV2ProductionUserVisibleOutcome.showControlledFailure,
    cleanupPolicy: CallV2ProductionCleanupPolicy.stopRuntime,
    retryPolicy: CallV2ProductionRetryPolicy.afterUserAction,
    observabilityEvent: CallV2ProductionObservabilityEvent.backendStartRejected,
    rawDetailsSuppressed: true,
  ),
  CallV2ProductionFailureMatrixEntry(
    failure: CallV2ProductionFailure.invalidSnapshot,
    sourceLayer: CallV2ProductionFailureSourceLayer.snapshot,
    errorCode: CallV2ClientErrorCode.rejected,
    userVisibleOutcome:
        CallV2ProductionUserVisibleOutcome.showControlledFailure,
    cleanupPolicy: CallV2ProductionCleanupPolicy.stopRuntime,
    retryPolicy: CallV2ProductionRetryPolicy.never,
    observabilityEvent: CallV2ProductionObservabilityEvent.controlledFailure,
    rawDetailsSuppressed: true,
  ),
  CallV2ProductionFailureMatrixEntry(
    failure: CallV2ProductionFailure.rtcConfigUnavailable,
    sourceLayer: CallV2ProductionFailureSourceLayer.rtcConfig,
    errorCode: CallV2ClientErrorCode.unavailable,
    userVisibleOutcome:
        CallV2ProductionUserVisibleOutcome.showControlledFailure,
    cleanupPolicy: CallV2ProductionCleanupPolicy.stopRuntime,
    retryPolicy: CallV2ProductionRetryPolicy.afterForegroundRecovery,
    observabilityEvent:
        CallV2ProductionObservabilityEvent.rtcInitializationFailed,
    rawDetailsSuppressed: true,
  ),
  CallV2ProductionFailureMatrixEntry(
    failure: CallV2ProductionFailure.rtcInitializeFailure,
    sourceLayer: CallV2ProductionFailureSourceLayer.rtcSession,
    errorCode: CallV2ClientErrorCode.unavailable,
    userVisibleOutcome:
        CallV2ProductionUserVisibleOutcome.showControlledFailure,
    cleanupPolicy: CallV2ProductionCleanupPolicy.leaveRtcAndStopSubscription,
    retryPolicy: CallV2ProductionRetryPolicy.afterUserAction,
    observabilityEvent:
        CallV2ProductionObservabilityEvent.rtcInitializationFailed,
    rawDetailsSuppressed: true,
  ),
  CallV2ProductionFailureMatrixEntry(
    failure: CallV2ProductionFailure.rtcJoinFailure,
    sourceLayer: CallV2ProductionFailureSourceLayer.rtcSession,
    errorCode: CallV2ClientErrorCode.unavailable,
    userVisibleOutcome:
        CallV2ProductionUserVisibleOutcome.showControlledFailure,
    cleanupPolicy: CallV2ProductionCleanupPolicy.leaveRtcAndStopSubscription,
    retryPolicy: CallV2ProductionRetryPolicy.afterUserAction,
    observabilityEvent:
        CallV2ProductionObservabilityEvent.rtcInitializationFailed,
    rawDetailsSuppressed: true,
  ),
  CallV2ProductionFailureMatrixEntry(
    failure: CallV2ProductionFailure.networkInterruption,
    sourceLayer: CallV2ProductionFailureSourceLayer.network,
    errorCode: CallV2ClientErrorCode.unavailable,
    userVisibleOutcome: CallV2ProductionUserVisibleOutcome.reconnectingState,
    cleanupPolicy: CallV2ProductionCleanupPolicy.none,
    retryPolicy: CallV2ProductionRetryPolicy.afterForegroundRecovery,
    observabilityEvent: CallV2ProductionObservabilityEvent.reconnecting,
    rawDetailsSuppressed: true,
  ),
  CallV2ProductionFailureMatrixEntry(
    failure: CallV2ProductionFailure.credentialExpiry,
    sourceLayer: CallV2ProductionFailureSourceLayer.rtcConfig,
    errorCode: CallV2ClientErrorCode.unavailable,
    userVisibleOutcome: CallV2ProductionUserVisibleOutcome.reconnectingState,
    cleanupPolicy: CallV2ProductionCleanupPolicy.none,
    retryPolicy: CallV2ProductionRetryPolicy.sameRequestOnly,
    observabilityEvent: CallV2ProductionObservabilityEvent.reconnecting,
    rawDetailsSuppressed: true,
  ),
  CallV2ProductionFailureMatrixEntry(
    failure: CallV2ProductionFailure.remoteParticipantAbsent,
    sourceLayer: CallV2ProductionFailureSourceLayer.rtcSession,
    errorCode: CallV2ClientErrorCode.rejected,
    userVisibleOutcome: CallV2ProductionUserVisibleOutcome.closeCallFlow,
    cleanupPolicy: CallV2ProductionCleanupPolicy.leaveRtcAndStopSubscription,
    retryPolicy: CallV2ProductionRetryPolicy.never,
    observabilityEvent: CallV2ProductionObservabilityEvent.ended,
    rawDetailsSuppressed: true,
  ),
  CallV2ProductionFailureMatrixEntry(
    failure: CallV2ProductionFailure.routeSinkUnavailable,
    sourceLayer: CallV2ProductionFailureSourceLayer.routing,
    errorCode: CallV2ClientErrorCode.unavailable,
    userVisibleOutcome:
        CallV2ProductionUserVisibleOutcome.showControlledFailure,
    cleanupPolicy: CallV2ProductionCleanupPolicy.stopStartupBridge,
    retryPolicy: CallV2ProductionRetryPolicy.afterForegroundRecovery,
    observabilityEvent: CallV2ProductionObservabilityEvent.controlledFailure,
    rawDetailsSuppressed: true,
  ),
  CallV2ProductionFailureMatrixEntry(
    failure: CallV2ProductionFailure.appDisposed,
    sourceLayer: CallV2ProductionFailureSourceLayer.appLifecycle,
    errorCode: CallV2ClientErrorCode.rejected,
    userVisibleOutcome: CallV2ProductionUserVisibleOutcome.closeCallFlow,
    cleanupPolicy: CallV2ProductionCleanupPolicy.disposeComposition,
    retryPolicy: CallV2ProductionRetryPolicy.never,
    observabilityEvent: CallV2ProductionObservabilityEvent.ended,
    rawDetailsSuppressed: true,
  ),
  CallV2ProductionFailureMatrixEntry(
    failure: CallV2ProductionFailure.duplicateLaunch,
    sourceLayer: CallV2ProductionFailureSourceLayer.coordinator,
    errorCode: CallV2ClientErrorCode.rejected,
    userVisibleOutcome: CallV2ProductionUserVisibleOutcome.stayOnCurrentScreen,
    cleanupPolicy: CallV2ProductionCleanupPolicy.none,
    retryPolicy: CallV2ProductionRetryPolicy.sameRequestOnly,
    observabilityEvent: CallV2ProductionObservabilityEvent.launchRejected,
    rawDetailsSuppressed: true,
  ),
  CallV2ProductionFailureMatrixEntry(
    failure: CallV2ProductionFailure.selfCallAttempt,
    sourceLayer: CallV2ProductionFailureSourceLayer.authentication,
    errorCode: CallV2ClientErrorCode.rejected,
    userVisibleOutcome:
        CallV2ProductionUserVisibleOutcome.showControlledFailure,
    cleanupPolicy: CallV2ProductionCleanupPolicy.closeOwnedRoute,
    retryPolicy: CallV2ProductionRetryPolicy.never,
    observabilityEvent: CallV2ProductionObservabilityEvent.launchRejected,
    rawDetailsSuppressed: true,
  ),
];

final callV2ProductionFailureMatrix = CallV2ProductionFailureMatrix(
  entries: callV2ProductionFailureMatrixEntries,
);
