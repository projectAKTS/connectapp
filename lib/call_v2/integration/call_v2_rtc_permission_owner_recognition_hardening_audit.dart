import 'call_v2_backend_firebase_owner_recognition_hardening_audit.dart';
import 'call_v2_final_staged_pre_runtime_integration_audit.dart';
import 'call_v2_rollout_policy.dart';
import 'call_v2_rtc_permission_owner_hardening_audit.dart';
import 'call_v2_rtc_permission_owner_recognition.dart';

enum CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus {
  developerOnly,
  rolloutFalse,
  metadataOnly,
  rtcPermissionOwnerRecognitionPass,
  backendFirebaseRecognitionHardeningPass,
  finalStagedPreRuntimeAuditPass,
  rtcPermissionOwnerHardeningPass,
  rtcPermissionOwnerClosed,
  noRtcInitialized,
  noRtcEngineCreated,
  noRtcChannelJoined,
  noRtcTokenChannelConsumed,
  noPermissionsRequested,
  noMicrophoneCameraPrompt,
  noDeviceEnumeration,
  noMediaCapture,
  noCameraPreview,
  noAudioVideoPublish,
  noRtcCallbacksListenersSubscriptions,
  noBackendFirebaseAccess,
  runtimeUnconstructed,
  runtimeNotStarted,
  productionCompositionUnconstructed,
  startupBridgeUncalled,
  mainDartUnchanged,
  appRouterUnchanged,
  routesUnreachable,
  routeResolverNullWhileFalse,
  disabledRegistryNull,
  noNavigatorWiring,
  noLifecycleRegistration,
  noAsyncHandles,
  noDependencyPlatformConfigChanges,
  noDeployment,
  rollbackOneCommit,
  v1Protected,
}

enum CallV2RtcPermissionOwnerRecognitionHardeningAuditDecision {
  pass,
  blocked,
}

enum CallV2RtcPermissionOwnerRecognitionHardeningRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2RtcPermissionOwnerRecognitionHardeningAudit {
  factory CallV2RtcPermissionOwnerRecognitionHardeningAudit({
    required List<CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus>
        statuses,
    required List<CallV2RtcPermissionOwnerRecognitionHardeningRollback>
        rollback,
  }) {
    return CallV2RtcPermissionOwnerRecognitionHardeningAudit._(
      List<CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus>.unmodifiable(
          statuses),
      List<CallV2RtcPermissionOwnerRecognitionHardeningRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2RtcPermissionOwnerRecognitionHardeningAudit._(
    this.statuses,
    this.rollback,
  );

  final List<CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus> statuses;
  final List<CallV2RtcPermissionOwnerRecognitionHardeningRollback> rollback;

  CallV2RtcPermissionOwnerRecognitionHardeningAuditDecision get decision {
    return passes
        ? CallV2RtcPermissionOwnerRecognitionHardeningAuditDecision.pass
        : CallV2RtcPermissionOwnerRecognitionHardeningAuditDecision.blocked;
  }

  bool get passes =>
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsMetadataOnly &&
      recordsRtcPermissionOwnerRecognitionPass &&
      recordsBackendFirebaseRecognitionHardeningPass &&
      recordsFinalStagedPreRuntimeAuditPass &&
      recordsRtcPermissionOwnerHardeningPass &&
      recordsRtcPermissionOwnerClosed &&
      recordsNoRtcInitialized &&
      recordsNoRtcEngineCreated &&
      recordsNoRtcChannelJoined &&
      recordsNoRtcTokenChannelConsumed &&
      recordsNoPermissionsRequested &&
      recordsNoMicrophoneCameraPrompt &&
      recordsNoDeviceEnumeration &&
      recordsNoMediaCapture &&
      recordsNoCameraPreview &&
      recordsNoAudioVideoPublish &&
      recordsNoRtcCallbacksListenersSubscriptions &&
      recordsNoBackendFirebaseAccess &&
      recordsRuntimeUnconstructed &&
      recordsRuntimeNotStarted &&
      recordsProductionCompositionUnconstructed &&
      recordsStartupBridgeUncalled &&
      recordsMainDartUnchanged &&
      recordsAppRouterUnchanged &&
      recordsRoutesUnreachable &&
      recordsRouteResolverNullWhileFalse &&
      recordsDisabledRegistryNull &&
      recordsNoNavigatorWiring &&
      recordsNoLifecycleRegistration &&
      recordsNoAsyncHandles &&
      recordsNoDependencyPlatformConfigChanges &&
      recordsNoDeployment &&
      recordsRollbackOneCommit &&
      recordsV1Protected;

  bool get recordsDeveloperOnly =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.developerOnly,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsDeveloperOnly;

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2RtcPermissionOwnerRecognition.recordsRolloutFalse;

  bool get recordsMetadataOnly =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.metadataOnly,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsMetadataOnly;

  bool get recordsRtcPermissionOwnerRecognitionPass =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .rtcPermissionOwnerRecognitionPass,
      ) &&
      callV2RtcPermissionOwnerRecognition.decision ==
          CallV2RtcPermissionOwnerRecognitionDecision.pass;

  bool get recordsBackendFirebaseRecognitionHardeningPass =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .backendFirebaseRecognitionHardeningPass,
      ) &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit.decision ==
          CallV2BackendFirebaseOwnerRecognitionHardeningAuditDecision.pass;

  bool get recordsFinalStagedPreRuntimeAuditPass =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .finalStagedPreRuntimeAuditPass,
      ) &&
      callV2FinalStagedPreRuntimeIntegrationAudit.decision ==
          CallV2FinalStagedPreRuntimeIntegrationAuditDecision.pass;

  bool get recordsRtcPermissionOwnerHardeningPass =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .rtcPermissionOwnerHardeningPass,
      ) &&
      callV2RtcPermissionOwnerHardeningAudit.decision ==
          CallV2RtcPermissionOwnerHardeningAuditDecision.pass;

  bool get recordsRtcPermissionOwnerClosed =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .rtcPermissionOwnerClosed,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsRtcPermissionOwnerClosed &&
      callV2RtcPermissionOwnerHardeningAudit.recordsHardDisabled &&
      callV2RtcPermissionOwnerHardeningAudit.recordsUnreachable &&
      callV2RtcPermissionOwnerHardeningAudit.recordsDisabledOwnerInert;

  bool get recordsNoRtcInitialized =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .noRtcInitialized,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsNoRtcInitialized;

  bool get recordsNoRtcEngineCreated =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .noRtcEngineCreated,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsNoRtcEngineCreated;

  bool get recordsNoRtcChannelJoined =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .noRtcChannelJoined,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsNoRtcChannelJoined;

  bool get recordsNoRtcTokenChannelConsumed =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .noRtcTokenChannelConsumed,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsNoRtcTokenChannelConsumed;

  bool get recordsNoPermissionsRequested =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .noPermissionsRequested,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsNoPermissionsRequested;

  bool get recordsNoMicrophoneCameraPrompt =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .noMicrophoneCameraPrompt,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsNoMicrophoneCameraPrompt;

  bool get recordsNoDeviceEnumeration =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .noDeviceEnumeration,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsNoDeviceEnumeration;

  bool get recordsNoMediaCapture =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.noMediaCapture,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsNoMediaCapture;

  bool get recordsNoCameraPreview =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.noCameraPreview,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsNoCameraPreview;

  bool get recordsNoAudioVideoPublish =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .noAudioVideoPublish,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsNoAudioVideoPublish;

  bool get recordsNoRtcCallbacksListenersSubscriptions =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .noRtcCallbacksListenersSubscriptions,
      ) &&
      callV2RtcPermissionOwnerRecognition
          .recordsNoRtcCallbacksListenersSubscriptions;

  bool get recordsNoBackendFirebaseAccess =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .noBackendFirebaseAccess,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsNoBackendFirebaseAccess;

  bool get recordsRuntimeUnconstructed =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .runtimeUnconstructed,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsRuntimeUnconstructed;

  bool get recordsRuntimeNotStarted =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .runtimeNotStarted,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsRuntimeNotStarted;

  bool get recordsProductionCompositionUnconstructed =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .productionCompositionUnconstructed,
      ) &&
      callV2RtcPermissionOwnerRecognition
          .recordsProductionCompositionUnconstructed;

  bool get recordsStartupBridgeUncalled =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .startupBridgeUncalled,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsStartupBridgeUncalled;

  bool get recordsMainDartUnchanged =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .mainDartUnchanged,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsMainDartUnchanged;

  bool get recordsAppRouterUnchanged =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .appRouterUnchanged,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsAppRouterUnchanged;

  bool get recordsRoutesUnreachable =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .routesUnreachable,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsRoutesUnreachable;

  bool get recordsRouteResolverNullWhileFalse =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .routeResolverNullWhileFalse,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsRouteResolverNullWhileFalse;

  bool get recordsDisabledRegistryNull =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .disabledRegistryNull,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsDisabledRegistryNull;

  bool get recordsNoNavigatorWiring =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .noNavigatorWiring,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsNoNavigatorWiring;

  bool get recordsNoLifecycleRegistration =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .noLifecycleRegistration,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsNoLifecycleRegistration;

  bool get recordsNoAsyncHandles =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.noAsyncHandles,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsNoAsyncHandles;

  bool get recordsNoDependencyPlatformConfigChanges =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .noDependencyPlatformConfigChanges,
      ) &&
      callV2RtcPermissionOwnerRecognition
          .recordsNoDependencyPlatformConfigChanges;

  bool get recordsNoDeployment =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.noDeployment,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsNoDeployment;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
            .rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningRollback
            .keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningRollback
            .keepDisabledOwnerInert,
      ) &&
      rollback.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningRollback
            .noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningRollback.v1Unaffected,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsRollbackOneCommit &&
      callV2RtcPermissionOwnerHardeningAudit.rollbackPreserved;

  bool get recordsV1Protected =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.v1Protected,
      ) &&
      callV2RtcPermissionOwnerRecognition.recordsV1Protected &&
      callV2RtcPermissionOwnerHardeningAudit.protectsV1;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'metadataOnly': recordsMetadataOnly,
      'recognitionPass': recordsRtcPermissionOwnerRecognitionPass,
      'backendRecognitionHardeningPass':
          recordsBackendFirebaseRecognitionHardeningPass,
      'finalStagedPreRuntimeAuditPass': recordsFinalStagedPreRuntimeAuditPass,
      'rtcOwnerHardeningPass': recordsRtcPermissionOwnerHardeningPass,
      'rtcOwnerClosed': recordsRtcPermissionOwnerClosed,
      'rtcInitialized': false,
      'rtcEngineCreated': false,
      'rtcJoined': false,
      'rtcInputConsumed': false,
      'accessRequested': false,
      'promptShown': false,
      'devicesEnumerated': false,
      'mediaCaptured': false,
      'previewStarted': false,
      'mediaPublished': false,
      'rtcAsyncRegistered': false,
      'backendAccess': false,
      'runtimeConstructed': false,
      'runtimeStarted': false,
      'routesReachable': false,
      'routeResolverNullWhileFalse': recordsRouteResolverNullWhileFalse,
      'disabledRegistryNull': recordsDisabledRegistryNull,
      'deploymentChanged': false,
      'v1Protected': recordsV1Protected,
    };
  }

  @override
  String toString() {
    return 'CallV2RtcPermissionOwnerRecognitionHardeningAudit('
        '${toSafeDebugMap()})';
  }
}

final callV2RtcPermissionOwnerRecognitionHardeningAudit =
    CallV2RtcPermissionOwnerRecognitionHardeningAudit(
  statuses: <CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus>[
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.developerOnly,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.rolloutFalse,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.metadataOnly,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
        .rtcPermissionOwnerRecognitionPass,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
        .backendFirebaseRecognitionHardeningPass,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
        .finalStagedPreRuntimeAuditPass,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
        .rtcPermissionOwnerHardeningPass,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
        .rtcPermissionOwnerClosed,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.noRtcInitialized,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.noRtcEngineCreated,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.noRtcChannelJoined,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
        .noRtcTokenChannelConsumed,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
        .noPermissionsRequested,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
        .noMicrophoneCameraPrompt,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.noDeviceEnumeration,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.noMediaCapture,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.noCameraPreview,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.noAudioVideoPublish,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
        .noRtcCallbacksListenersSubscriptions,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
        .noBackendFirebaseAccess,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
        .runtimeUnconstructed,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.runtimeNotStarted,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
        .productionCompositionUnconstructed,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
        .startupBridgeUncalled,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.mainDartUnchanged,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.appRouterUnchanged,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.routesUnreachable,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
        .routeResolverNullWhileFalse,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
        .disabledRegistryNull,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.noNavigatorWiring,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
        .noLifecycleRegistration,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.noAsyncHandles,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus
        .noDependencyPlatformConfigChanges,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.noDeployment,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.rollbackOneCommit,
    CallV2RtcPermissionOwnerRecognitionHardeningAuditStatus.v1Protected,
  ],
  rollback: <CallV2RtcPermissionOwnerRecognitionHardeningRollback>[
    CallV2RtcPermissionOwnerRecognitionHardeningRollback.oneCommitRevert,
    CallV2RtcPermissionOwnerRecognitionHardeningRollback.keepRolloutFalse,
    CallV2RtcPermissionOwnerRecognitionHardeningRollback.keepRouteRegistryNull,
    CallV2RtcPermissionOwnerRecognitionHardeningRollback.keepDisabledOwnerInert,
    CallV2RtcPermissionOwnerRecognitionHardeningRollback.noDeploymentRequired,
    CallV2RtcPermissionOwnerRecognitionHardeningRollback.noConfigChanges,
    CallV2RtcPermissionOwnerRecognitionHardeningRollback.v1Unaffected,
  ],
);
