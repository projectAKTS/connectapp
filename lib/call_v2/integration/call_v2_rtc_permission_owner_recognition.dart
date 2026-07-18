import 'call_v2_backend_firebase_owner_recognition_hardening_audit.dart';
import 'call_v2_final_staged_pre_runtime_integration_audit.dart';
import 'call_v2_rollout_policy.dart';
import 'call_v2_rtc_permission_owner_hardening_audit.dart';

enum CallV2RtcPermissionOwnerRecognitionStatus {
  developerOnly,
  rolloutFalse,
  metadataOnly,
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

enum CallV2RtcPermissionOwnerRecognitionDecision {
  pass,
  blocked,
}

final class CallV2RtcPermissionOwnerRecognition {
  factory CallV2RtcPermissionOwnerRecognition({
    required List<CallV2RtcPermissionOwnerRecognitionStatus> statuses,
  }) {
    return CallV2RtcPermissionOwnerRecognition._(
      List<CallV2RtcPermissionOwnerRecognitionStatus>.unmodifiable(statuses),
    );
  }

  const CallV2RtcPermissionOwnerRecognition._(this.statuses);

  final List<CallV2RtcPermissionOwnerRecognitionStatus> statuses;

  CallV2RtcPermissionOwnerRecognitionDecision get decision {
    return passes
        ? CallV2RtcPermissionOwnerRecognitionDecision.pass
        : CallV2RtcPermissionOwnerRecognitionDecision.blocked;
  }

  bool get passes =>
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsMetadataOnly &&
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
      statuses
          .contains(CallV2RtcPermissionOwnerRecognitionStatus.developerOnly) &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsDeveloperOnly &&
      callV2RtcPermissionOwnerHardeningAudit.recordsDeveloperOnly;

  bool get recordsRolloutFalse =>
      statuses
          .contains(CallV2RtcPermissionOwnerRecognitionStatus.rolloutFalse) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit.recordsRolloutFalse &&
      callV2RtcPermissionOwnerHardeningAudit.recordsRolloutFalse;

  bool get recordsMetadataOnly =>
      statuses
          .contains(CallV2RtcPermissionOwnerRecognitionStatus.metadataOnly) &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit.recordsMetadataOnly;

  bool get recordsBackendFirebaseRecognitionHardeningPass =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus
            .backendFirebaseRecognitionHardeningPass,
      ) &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit.decision ==
          CallV2BackendFirebaseOwnerRecognitionHardeningAuditDecision.pass;

  bool get recordsFinalStagedPreRuntimeAuditPass =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus
            .finalStagedPreRuntimeAuditPass,
      ) &&
      callV2FinalStagedPreRuntimeIntegrationAudit.decision ==
          CallV2FinalStagedPreRuntimeIntegrationAuditDecision.pass;

  bool get recordsRtcPermissionOwnerHardeningPass =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus
            .rtcPermissionOwnerHardeningPass,
      ) &&
      callV2RtcPermissionOwnerHardeningAudit.decision ==
          CallV2RtcPermissionOwnerHardeningAuditDecision.pass;

  bool get recordsRtcPermissionOwnerClosed =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus.rtcPermissionOwnerClosed,
      ) &&
      callV2RtcPermissionOwnerHardeningAudit.recordsHardDisabled &&
      callV2RtcPermissionOwnerHardeningAudit.recordsUnreachable &&
      callV2RtcPermissionOwnerHardeningAudit.recordsDisabledOwnerInert;

  bool get recordsNoRtcInitialized =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus.noRtcInitialized,
      ) &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoRtcPermissionImports;

  bool get recordsNoRtcEngineCreated =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus.noRtcEngineCreated,
      ) &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoRtcEngineCreation;

  bool get recordsNoRtcChannelJoined =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus.noRtcChannelJoined,
      ) &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoRtcChannelJoin;

  bool get recordsNoRtcTokenChannelConsumed =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus.noRtcTokenChannelConsumed,
      ) &&
      callV2RtcPermissionOwnerHardeningAudit
          .recordsNoRtcTokenChannelConsumption;

  bool get recordsNoPermissionsRequested =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus.noPermissionsRequested,
      ) &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoPermissionRequest;

  bool get recordsNoMicrophoneCameraPrompt =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus.noMicrophoneCameraPrompt,
      ) &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoMicrophoneCameraPrompt;

  bool get recordsNoDeviceEnumeration =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus.noDeviceEnumeration,
      ) &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoDeviceEnumeration;

  bool get recordsNoMediaCapture =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus.noMediaCapture,
      ) &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoMediaCapture;

  bool get recordsNoCameraPreview =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus.noCameraPreview,
      ) &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoCameraPreview;

  bool get recordsNoAudioVideoPublish =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus.noAudioVideoPublish,
      ) &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoAudioVideoPublish;

  bool get recordsNoRtcCallbacksListenersSubscriptions =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus
            .noRtcCallbacksListenersSubscriptions,
      ) &&
      callV2RtcPermissionOwnerHardeningAudit
          .recordsNoRtcCallbacksListenersSubscriptions;

  bool get recordsNoBackendFirebaseAccess =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus.noBackendFirebaseAccess,
      ) &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsNoFirebaseAccess &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoBackendFirebaseAccess;

  bool get recordsRuntimeUnconstructed =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus.runtimeUnconstructed,
      ) &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsRuntimeUnconstructed &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoRuntimeConstruction;

  bool get recordsRuntimeNotStarted =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus.runtimeNotStarted,
      ) &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsRuntimeNotStarted &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoRuntimeStart;

  bool get recordsProductionCompositionUnconstructed =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus
            .productionCompositionUnconstructed,
      ) &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsProductionCompositionUnconstructed;

  bool get recordsStartupBridgeUncalled =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus.startupBridgeUncalled,
      ) &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsStartupBridgeUncalled;

  bool get recordsMainDartUnchanged =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus.mainDartUnchanged,
      ) &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsMainDartUnchanged;

  bool get recordsAppRouterUnchanged =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus.appRouterUnchanged,
      ) &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsAppRouterUnchanged;

  bool get recordsRoutesUnreachable =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus.routesUnreachable,
      ) &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsRoutesUnreachable;

  bool get recordsRouteResolverNullWhileFalse =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus.routeResolverNullWhileFalse,
      ) &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsRouteResolverNullWhileFalse &&
      callV2RtcPermissionOwnerHardeningAudit.recordsRouteRegistryNullWhileFalse;

  bool get recordsDisabledRegistryNull =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus.disabledRegistryNull,
      ) &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsDisabledRegistryNull;

  bool get recordsNoNavigatorWiring =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus.noNavigatorWiring,
      ) &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsNoNavigatorWiring &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoNavigationAccess;

  bool get recordsNoLifecycleRegistration =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus.noLifecycleRegistration,
      ) &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsNoLifecycleRegistration &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoLifecycleRegistration;

  bool get recordsNoAsyncHandles =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus.noAsyncHandles,
      ) &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsNoAsyncHandles &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoAsyncHandles;

  bool get recordsNoDependencyPlatformConfigChanges =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus
            .noDependencyPlatformConfigChanges,
      ) &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsNoDependencyPlatformConfigChanges &&
      callV2RtcPermissionOwnerHardeningAudit
          .recordsNoPubspecPlatformConfigChanges;

  bool get recordsNoDeployment =>
      statuses
          .contains(CallV2RtcPermissionOwnerRecognitionStatus.noDeployment) &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit.recordsNoDeployment &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoDeployment;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2RtcPermissionOwnerRecognitionStatus.rollbackOneCommit,
      ) &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsRollbackOneCommit &&
      callV2RtcPermissionOwnerHardeningAudit.rollbackPreserved;

  bool get recordsV1Protected =>
      statuses
          .contains(CallV2RtcPermissionOwnerRecognitionStatus.v1Protected) &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit.recordsV1Protected &&
      callV2RtcPermissionOwnerHardeningAudit.protectsV1;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'metadataOnly': recordsMetadataOnly,
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
    return 'CallV2RtcPermissionOwnerRecognition(${toSafeDebugMap()})';
  }
}

final callV2RtcPermissionOwnerRecognition = CallV2RtcPermissionOwnerRecognition(
  statuses: <CallV2RtcPermissionOwnerRecognitionStatus>[
    CallV2RtcPermissionOwnerRecognitionStatus.developerOnly,
    CallV2RtcPermissionOwnerRecognitionStatus.rolloutFalse,
    CallV2RtcPermissionOwnerRecognitionStatus.metadataOnly,
    CallV2RtcPermissionOwnerRecognitionStatus
        .backendFirebaseRecognitionHardeningPass,
    CallV2RtcPermissionOwnerRecognitionStatus.finalStagedPreRuntimeAuditPass,
    CallV2RtcPermissionOwnerRecognitionStatus.rtcPermissionOwnerHardeningPass,
    CallV2RtcPermissionOwnerRecognitionStatus.rtcPermissionOwnerClosed,
    CallV2RtcPermissionOwnerRecognitionStatus.noRtcInitialized,
    CallV2RtcPermissionOwnerRecognitionStatus.noRtcEngineCreated,
    CallV2RtcPermissionOwnerRecognitionStatus.noRtcChannelJoined,
    CallV2RtcPermissionOwnerRecognitionStatus.noRtcTokenChannelConsumed,
    CallV2RtcPermissionOwnerRecognitionStatus.noPermissionsRequested,
    CallV2RtcPermissionOwnerRecognitionStatus.noMicrophoneCameraPrompt,
    CallV2RtcPermissionOwnerRecognitionStatus.noDeviceEnumeration,
    CallV2RtcPermissionOwnerRecognitionStatus.noMediaCapture,
    CallV2RtcPermissionOwnerRecognitionStatus.noCameraPreview,
    CallV2RtcPermissionOwnerRecognitionStatus.noAudioVideoPublish,
    CallV2RtcPermissionOwnerRecognitionStatus
        .noRtcCallbacksListenersSubscriptions,
    CallV2RtcPermissionOwnerRecognitionStatus.noBackendFirebaseAccess,
    CallV2RtcPermissionOwnerRecognitionStatus.runtimeUnconstructed,
    CallV2RtcPermissionOwnerRecognitionStatus.runtimeNotStarted,
    CallV2RtcPermissionOwnerRecognitionStatus
        .productionCompositionUnconstructed,
    CallV2RtcPermissionOwnerRecognitionStatus.startupBridgeUncalled,
    CallV2RtcPermissionOwnerRecognitionStatus.mainDartUnchanged,
    CallV2RtcPermissionOwnerRecognitionStatus.appRouterUnchanged,
    CallV2RtcPermissionOwnerRecognitionStatus.routesUnreachable,
    CallV2RtcPermissionOwnerRecognitionStatus.routeResolverNullWhileFalse,
    CallV2RtcPermissionOwnerRecognitionStatus.disabledRegistryNull,
    CallV2RtcPermissionOwnerRecognitionStatus.noNavigatorWiring,
    CallV2RtcPermissionOwnerRecognitionStatus.noLifecycleRegistration,
    CallV2RtcPermissionOwnerRecognitionStatus.noAsyncHandles,
    CallV2RtcPermissionOwnerRecognitionStatus.noDependencyPlatformConfigChanges,
    CallV2RtcPermissionOwnerRecognitionStatus.noDeployment,
    CallV2RtcPermissionOwnerRecognitionStatus.rollbackOneCommit,
    CallV2RtcPermissionOwnerRecognitionStatus.v1Protected,
  ],
);
