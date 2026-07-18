import 'call_v2_backend_firebase_owner_hardening_audit.dart';
import 'call_v2_final_staged_pre_runtime_integration_audit.dart';
import 'call_v2_rollout_policy.dart';
import 'call_v2_runtime_startup_owner_recognition_hardening_audit.dart';

enum CallV2BackendFirebaseOwnerRecognitionStatus {
  developerOnly,
  rolloutFalse,
  metadataOnly,
  runtimeStartupRecognitionHardeningPass,
  finalStagedPreRuntimeAuditPass,
  backendFirebaseOwnerHardeningPass,
  backendFirebaseOwnerClosed,
  noFirebaseAccess,
  noFirestoreListeners,
  noFirestoreReads,
  noFirestoreWrites,
  noAuthCalls,
  noFunctionsCalls,
  noAppCheckCalls,
  noRulesFunctionsConfigChanges,
  runtimeUnconstructed,
  runtimeNotStarted,
  productionCompositionUnconstructed,
  startupBridgeUncalled,
  mainDartUnchanged,
  appRouterUnchanged,
  routesUnreachable,
  routeResolverNullWhileFalse,
  disabledRegistryNull,
  noRtcPermissionMediaDeviceAccess,
  noNavigatorWiring,
  noLifecycleRegistration,
  noAsyncHandles,
  noDependencyPlatformConfigChanges,
  noDeployment,
  rollbackOneCommit,
  v1Protected,
}

enum CallV2BackendFirebaseOwnerRecognitionDecision {
  pass,
  blocked,
}

final class CallV2BackendFirebaseOwnerRecognition {
  factory CallV2BackendFirebaseOwnerRecognition({
    required List<CallV2BackendFirebaseOwnerRecognitionStatus> statuses,
  }) {
    return CallV2BackendFirebaseOwnerRecognition._(
      List<CallV2BackendFirebaseOwnerRecognitionStatus>.unmodifiable(statuses),
    );
  }

  const CallV2BackendFirebaseOwnerRecognition._(this.statuses);

  final List<CallV2BackendFirebaseOwnerRecognitionStatus> statuses;

  CallV2BackendFirebaseOwnerRecognitionDecision get decision {
    return passes
        ? CallV2BackendFirebaseOwnerRecognitionDecision.pass
        : CallV2BackendFirebaseOwnerRecognitionDecision.blocked;
  }

  bool get passes =>
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsMetadataOnly &&
      recordsRuntimeStartupRecognitionHardeningPass &&
      recordsFinalStagedPreRuntimeAuditPass &&
      recordsBackendFirebaseOwnerHardeningPass &&
      recordsBackendFirebaseOwnerClosed &&
      recordsNoFirebaseAccess &&
      recordsNoFirestoreListeners &&
      recordsNoFirestoreReads &&
      recordsNoFirestoreWrites &&
      recordsNoAuthCalls &&
      recordsNoFunctionsCalls &&
      recordsNoAppCheckCalls &&
      recordsNoRulesFunctionsConfigChanges &&
      recordsRuntimeUnconstructed &&
      recordsRuntimeNotStarted &&
      recordsProductionCompositionUnconstructed &&
      recordsStartupBridgeUncalled &&
      recordsMainDartUnchanged &&
      recordsAppRouterUnchanged &&
      recordsRoutesUnreachable &&
      recordsRouteResolverNullWhileFalse &&
      recordsDisabledRegistryNull &&
      recordsNoRtcPermissionMediaDeviceAccess &&
      recordsNoNavigatorWiring &&
      recordsNoLifecycleRegistration &&
      recordsNoAsyncHandles &&
      recordsNoDependencyPlatformConfigChanges &&
      recordsNoDeployment &&
      recordsRollbackOneCommit &&
      recordsV1Protected;

  bool get recordsDeveloperOnly =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus.developerOnly,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit.recordsDeveloperOnly;

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit.recordsRolloutFalse;

  bool get recordsMetadataOnly =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus.metadataOnly,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit.recordsMetadataOnly;

  bool get recordsRuntimeStartupRecognitionHardeningPass =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus
            .runtimeStartupRecognitionHardeningPass,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit.decision ==
          CallV2RuntimeStartupOwnerRecognitionHardeningAuditDecision.pass;

  bool get recordsFinalStagedPreRuntimeAuditPass =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus
            .finalStagedPreRuntimeAuditPass,
      ) &&
      callV2FinalStagedPreRuntimeIntegrationAudit.decision ==
          CallV2FinalStagedPreRuntimeIntegrationAuditDecision.pass;

  bool get recordsBackendFirebaseOwnerHardeningPass =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus
            .backendFirebaseOwnerHardeningPass,
      ) &&
      callV2BackendFirebaseOwnerHardeningAudit.decision ==
          CallV2BackendFirebaseOwnerHardeningAuditDecision.pass;

  bool get recordsBackendFirebaseOwnerClosed =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus.backendFirebaseOwnerClosed,
      ) &&
      callV2BackendFirebaseOwnerHardeningAudit.recordsHardDisabled &&
      callV2BackendFirebaseOwnerHardeningAudit.recordsUnreachable &&
      callV2BackendFirebaseOwnerHardeningAudit.recordsDisabledOwnerInert;

  bool get recordsNoFirebaseAccess =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus.noFirebaseAccess,
      ) &&
      callV2BackendFirebaseOwnerHardeningAudit.recordsNoFirebaseImports &&
      callV2BackendFirebaseOwnerHardeningAudit
          .recordsNoProductionServiceContact;

  bool get recordsNoFirestoreListeners =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus.noFirestoreListeners,
      ) &&
      callV2BackendFirebaseOwnerHardeningAudit.recordsNoFirestoreListeners;

  bool get recordsNoFirestoreReads =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus.noFirestoreReads,
      ) &&
      callV2BackendFirebaseOwnerHardeningAudit.recordsNoFirestoreReads;

  bool get recordsNoFirestoreWrites =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus.noFirestoreWrites,
      ) &&
      callV2BackendFirebaseOwnerHardeningAudit.recordsNoFirestoreWrites;

  bool get recordsNoAuthCalls =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus.noAuthCalls,
      ) &&
      callV2BackendFirebaseOwnerHardeningAudit.recordsNoFirebaseAuthCalls;

  bool get recordsNoFunctionsCalls =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus.noFunctionsCalls,
      ) &&
      callV2BackendFirebaseOwnerHardeningAudit.recordsNoFirebaseFunctionsCalls;

  bool get recordsNoAppCheckCalls =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus.noAppCheckCalls,
      ) &&
      callV2BackendFirebaseOwnerHardeningAudit.recordsNoFirebaseAppCheckCalls;

  bool get recordsNoRulesFunctionsConfigChanges =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus
            .noRulesFunctionsConfigChanges,
      ) &&
      callV2BackendFirebaseOwnerHardeningAudit
          .recordsNoRulesFunctionsConfigChanges;

  bool get recordsRuntimeUnconstructed =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus.runtimeUnconstructed,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsRuntimeUnconstructed;

  bool get recordsRuntimeNotStarted =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus.runtimeNotStarted,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsRuntimeNotStarted;

  bool get recordsProductionCompositionUnconstructed =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus
            .productionCompositionUnconstructed,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsProductionCompositionUnconstructed;

  bool get recordsStartupBridgeUncalled =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus.startupBridgeUncalled,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsStartupBridgeUncalled;

  bool get recordsMainDartUnchanged =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus.mainDartUnchanged,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsMainDartUnchanged;

  bool get recordsAppRouterUnchanged =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus.appRouterUnchanged,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsAppRouterUnchanged;

  bool get recordsRoutesUnreachable =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus.routesUnreachable,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsRoutesUnreachable;

  bool get recordsRouteResolverNullWhileFalse =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus.routeResolverNullWhileFalse,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsRouteResolverNullWhileFalse;

  bool get recordsDisabledRegistryNull =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus.disabledRegistryNull,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsDisabledRegistryNull;

  bool get recordsNoRtcPermissionMediaDeviceAccess =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus
            .noRtcPermissionMediaDeviceAccess,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsNoRtcPermissionMediaDeviceAccess;

  bool get recordsNoNavigatorWiring =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus.noNavigatorWiring,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsNoNavigatorWiring;

  bool get recordsNoLifecycleRegistration =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus.noLifecycleRegistration,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsNoLifecycleRegistration;

  bool get recordsNoAsyncHandles =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus.noAsyncHandles,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit.recordsNoAsyncHandles;

  bool get recordsNoDependencyPlatformConfigChanges =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus
            .noDependencyPlatformConfigChanges,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsNoDependencyPlatformConfigChanges;

  bool get recordsNoDeployment =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus.noDeployment,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit.recordsNoDeployment;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus.rollbackOneCommit,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsRollbackOneCommit &&
      callV2BackendFirebaseOwnerHardeningAudit.rollbackPreserved;

  bool get recordsV1Protected =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionStatus.v1Protected,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit.recordsV1Protected &&
      callV2BackendFirebaseOwnerHardeningAudit.protectsV1;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'metadataOnly': recordsMetadataOnly,
      'runtimeRecognitionHardeningPass':
          recordsRuntimeStartupRecognitionHardeningPass,
      'finalStagedPreRuntimeAuditPass': recordsFinalStagedPreRuntimeAuditPass,
      'backendOwnerHardeningPass': recordsBackendFirebaseOwnerHardeningPass,
      'backendOwnerClosed': recordsBackendFirebaseOwnerClosed,
      'firebaseAccess': false,
      'firestoreListenerOpened': false,
      'firestoreRead': false,
      'firestoreWrite': false,
      'authCalled': false,
      'functionsCalled': false,
      'appCheckCalled': false,
      'runtimeConstructed': false,
      'runtimeStarted': false,
      'routesReachable': false,
      'deploymentChanged': false,
      'v1Protected': recordsV1Protected,
    };
  }

  @override
  String toString() {
    return 'CallV2BackendFirebaseOwnerRecognition(${toSafeDebugMap()})';
  }
}

final callV2BackendFirebaseOwnerRecognition =
    CallV2BackendFirebaseOwnerRecognition(
  statuses: <CallV2BackendFirebaseOwnerRecognitionStatus>[
    CallV2BackendFirebaseOwnerRecognitionStatus.developerOnly,
    CallV2BackendFirebaseOwnerRecognitionStatus.rolloutFalse,
    CallV2BackendFirebaseOwnerRecognitionStatus.metadataOnly,
    CallV2BackendFirebaseOwnerRecognitionStatus
        .runtimeStartupRecognitionHardeningPass,
    CallV2BackendFirebaseOwnerRecognitionStatus.finalStagedPreRuntimeAuditPass,
    CallV2BackendFirebaseOwnerRecognitionStatus
        .backendFirebaseOwnerHardeningPass,
    CallV2BackendFirebaseOwnerRecognitionStatus.backendFirebaseOwnerClosed,
    CallV2BackendFirebaseOwnerRecognitionStatus.noFirebaseAccess,
    CallV2BackendFirebaseOwnerRecognitionStatus.noFirestoreListeners,
    CallV2BackendFirebaseOwnerRecognitionStatus.noFirestoreReads,
    CallV2BackendFirebaseOwnerRecognitionStatus.noFirestoreWrites,
    CallV2BackendFirebaseOwnerRecognitionStatus.noAuthCalls,
    CallV2BackendFirebaseOwnerRecognitionStatus.noFunctionsCalls,
    CallV2BackendFirebaseOwnerRecognitionStatus.noAppCheckCalls,
    CallV2BackendFirebaseOwnerRecognitionStatus.noRulesFunctionsConfigChanges,
    CallV2BackendFirebaseOwnerRecognitionStatus.runtimeUnconstructed,
    CallV2BackendFirebaseOwnerRecognitionStatus.runtimeNotStarted,
    CallV2BackendFirebaseOwnerRecognitionStatus
        .productionCompositionUnconstructed,
    CallV2BackendFirebaseOwnerRecognitionStatus.startupBridgeUncalled,
    CallV2BackendFirebaseOwnerRecognitionStatus.mainDartUnchanged,
    CallV2BackendFirebaseOwnerRecognitionStatus.appRouterUnchanged,
    CallV2BackendFirebaseOwnerRecognitionStatus.routesUnreachable,
    CallV2BackendFirebaseOwnerRecognitionStatus.routeResolverNullWhileFalse,
    CallV2BackendFirebaseOwnerRecognitionStatus.disabledRegistryNull,
    CallV2BackendFirebaseOwnerRecognitionStatus
        .noRtcPermissionMediaDeviceAccess,
    CallV2BackendFirebaseOwnerRecognitionStatus.noNavigatorWiring,
    CallV2BackendFirebaseOwnerRecognitionStatus.noLifecycleRegistration,
    CallV2BackendFirebaseOwnerRecognitionStatus.noAsyncHandles,
    CallV2BackendFirebaseOwnerRecognitionStatus
        .noDependencyPlatformConfigChanges,
    CallV2BackendFirebaseOwnerRecognitionStatus.noDeployment,
    CallV2BackendFirebaseOwnerRecognitionStatus.rollbackOneCommit,
    CallV2BackendFirebaseOwnerRecognitionStatus.v1Protected,
  ],
);
