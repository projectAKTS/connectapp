import '../design/call_v2_production_first_wiring_approval_checkpoint.dart';
import 'call_v2_backend_firebase_owner_hardening_audit.dart';
import 'call_v2_developer_backend_firebase_approval_scope.dart';
import 'call_v2_developer_lifecycle_observer_approval_scope.dart';
import 'call_v2_developer_navigator_owner_approval_scope.dart';
import 'call_v2_developer_pre_wiring_safety_gate.dart';
import 'call_v2_developer_route_registration_approval_scope.dart';
import 'call_v2_developer_rtc_permission_approval_scope.dart';
import 'call_v2_developer_runtime_startup_approval_scope.dart';
import 'call_v2_developer_skeleton_composition_audit.dart';
import 'call_v2_lifecycle_observer_hardening_audit.dart';
import 'call_v2_navigator_owner_hardening_audit.dart';
import 'call_v2_rollout_policy.dart';
import 'call_v2_route_registry.dart';
import 'call_v2_route_registry_hardening_audit.dart';
import 'call_v2_rtc_permission_owner_hardening_audit.dart';
import 'call_v2_runtime_startup_owner_hardening_audit.dart';

enum CallV2FinalPreWiringConsolidationAuditStatus {
  developerOnly,
  rolloutFalse,
  routesUnreachable,
  routeResolverNullWhileFalse,
  disabledRegistryNull,
  disabledOwnerInert,
  productionCompositionUnconstructed,
  runtimeUnconstructed,
  runtimeNotStarted,
  backendFirebaseOwnerClosed,
  backendFirebaseHardeningPass,
  rtcPermissionOwnerClosed,
  rtcPermissionHardeningPass,
  runtimeStartupOwnerClosed,
  runtimeStartupHardeningPass,
  navigatorOwnerClosed,
  navigatorHardeningPass,
  lifecycleObserverClosed,
  lifecycleHardeningPass,
  routeRegistryHardeningPass,
  backendFirebaseApprovalClosed,
  rtcPermissionApprovalClosed,
  runtimeStartupApprovalClosed,
  navigatorApprovalClosed,
  lifecycleApprovalClosed,
  routeRegistrationApprovalClosed,
  preWiringGateBlocked,
  skeletonCompositionPass,
  noMainDartWiring,
  noAppRouterWiring,
  noStartupBridgeWiring,
  noProductionCompositionWiring,
  noBackendFirebaseAccess,
  noFirestoreListeners,
  noFirestoreReads,
  noFirestoreWrites,
  noAuthFunctionsAppCheck,
  noRtcPermissionMediaDeviceAccess,
  noNavigatorWiring,
  noLifecycleRegistration,
  noAsyncHandles,
  noDependencyPlatformConfigChanges,
  noDeployment,
  rollbackOneCommit,
  v1Protected,
}

enum CallV2FinalPreWiringConsolidationAuditDecision {
  pass,
  blocked,
}

enum CallV2FinalPreWiringConsolidationRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2FinalPreWiringConsolidationAudit {
  factory CallV2FinalPreWiringConsolidationAudit({
    required List<CallV2FinalPreWiringConsolidationAuditStatus> statuses,
    required List<CallV2FinalPreWiringConsolidationRollback> rollback,
  }) {
    return CallV2FinalPreWiringConsolidationAudit._(
      List<CallV2FinalPreWiringConsolidationAuditStatus>.unmodifiable(
        statuses,
      ),
      List<CallV2FinalPreWiringConsolidationRollback>.unmodifiable(rollback),
    );
  }

  const CallV2FinalPreWiringConsolidationAudit._(
    this.statuses,
    this.rollback,
  );

  final List<CallV2FinalPreWiringConsolidationAuditStatus> statuses;
  final List<CallV2FinalPreWiringConsolidationRollback> rollback;

  CallV2FinalPreWiringConsolidationAuditDecision get decision {
    return passes
        ? CallV2FinalPreWiringConsolidationAuditDecision.pass
        : CallV2FinalPreWiringConsolidationAuditDecision.blocked;
  }

  bool get passes =>
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsRoutesUnreachable &&
      recordsRouteResolverNullWhileFalse &&
      recordsDisabledRegistryNull &&
      recordsDisabledOwnerInert &&
      recordsProductionCompositionUnconstructed &&
      recordsRuntimeUnconstructed &&
      recordsRuntimeNotStarted &&
      backendFirebaseOwnerClosed &&
      backendFirebaseHardeningPasses &&
      rtcPermissionOwnerClosed &&
      rtcPermissionHardeningPasses &&
      runtimeStartupOwnerClosed &&
      runtimeStartupHardeningPasses &&
      navigatorOwnerClosed &&
      navigatorHardeningPasses &&
      lifecycleObserverClosed &&
      lifecycleHardeningPasses &&
      routeRegistryHardeningPasses &&
      backendFirebaseApprovalClosed &&
      rtcPermissionApprovalClosed &&
      runtimeStartupApprovalClosed &&
      navigatorApprovalClosed &&
      lifecycleApprovalClosed &&
      routeRegistrationApprovalClosed &&
      preWiringSafetyGateBlocked &&
      skeletonCompositionPasses &&
      recordsNoMainDartWiring &&
      recordsNoAppRouterWiring &&
      recordsNoStartupBridgeWiring &&
      recordsNoProductionCompositionWiring &&
      recordsNoBackendFirebaseAccess &&
      recordsNoFirestoreListeners &&
      recordsNoFirestoreReads &&
      recordsNoFirestoreWrites &&
      recordsNoAuthFunctionsAppCheck &&
      recordsNoRtcPermissionMediaDeviceAccess &&
      recordsNoNavigatorWiring &&
      recordsNoLifecycleRegistration &&
      recordsNoAsyncHandles &&
      recordsNoDependencyPlatformConfigChanges &&
      recordsNoDeployment &&
      rollbackPreserved &&
      protectsV1;

  bool get recordsDeveloperOnly =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.developerOnly,
      ) &&
      callV2DeveloperPreWiringSafetyGate.isDeveloperOnly;

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      !isCallV2DeveloperRouteRegistrationEnabled &&
      !callV2ProductionFirstWiringApprovalCheckpoint.isRolloutEnabled;

  bool get recordsRoutesUnreachable =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.routesUnreachable,
      ) &&
      !callV2DeveloperPreWiringSafetyGate.isReachable &&
      !callV2ProductionFirstWiringApprovalCheckpoint.isCallV2Reachable;

  bool get recordsRouteResolverNullWhileFalse =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus
            .routeResolverNullWhileFalse,
      ) &&
      !isCallV2DeveloperRouteRegistrationEnabled &&
      callV2RouteRegistryHardeningAudit.recordsResolverNullWhileFalse;

  bool get recordsDisabledRegistryNull =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.disabledRegistryNull,
      ) &&
      callV2RouteRegistryHardeningAudit.recordsDisabledRegistryNull &&
      !callV2ProductionFirstWiringApprovalCheckpoint.isRouteRegistryEnabled;

  bool get recordsDisabledOwnerInert =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.disabledOwnerInert,
      ) &&
      callV2DeveloperPreWiringSafetyGate.isDisabledOwnerInert &&
      !callV2ProductionFirstWiringApprovalCheckpoint.isDisabledOwnerActive;

  bool get recordsProductionCompositionUnconstructed =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus
            .productionCompositionUnconstructed,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit
          .recordsNoProductionCompositionConstruction;

  bool get recordsRuntimeUnconstructed =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.runtimeUnconstructed,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsNoRuntimeConstruction;

  bool get recordsRuntimeNotStarted =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.runtimeNotStarted,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsNoRuntimeStart &&
      !callV2ProductionFirstWiringApprovalCheckpoint.isRuntimeStarted;

  bool get backendFirebaseOwnerClosed =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.backendFirebaseOwnerClosed,
      ) &&
      callV2BackendFirebaseOwnerHardeningAudit.recordsHardDisabled &&
      !callV2ProductionFirstWiringApprovalCheckpoint
          .hasBackendFirebaseConnection;

  bool get backendFirebaseHardeningPasses =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus
            .backendFirebaseHardeningPass,
      ) &&
      callV2BackendFirebaseOwnerHardeningAudit.decision ==
          CallV2BackendFirebaseOwnerHardeningAuditDecision.pass;

  bool get rtcPermissionOwnerClosed =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.rtcPermissionOwnerClosed,
      ) &&
      callV2RtcPermissionOwnerHardeningAudit.recordsHardDisabled &&
      !callV2ProductionFirstWiringApprovalCheckpoint.hasRtcPermissionConnection;

  bool get rtcPermissionHardeningPasses =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.rtcPermissionHardeningPass,
      ) &&
      callV2RtcPermissionOwnerHardeningAudit.decision ==
          CallV2RtcPermissionOwnerHardeningAuditDecision.pass;

  bool get runtimeStartupOwnerClosed =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.runtimeStartupOwnerClosed,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsHardDisabled;

  bool get runtimeStartupHardeningPasses =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus
            .runtimeStartupHardeningPass,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.decision ==
          CallV2RuntimeStartupOwnerHardeningAuditDecision.pass;

  bool get navigatorOwnerClosed =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.navigatorOwnerClosed,
      ) &&
      callV2NavigatorOwnerHardeningAudit.recordsHardDisabled;

  bool get navigatorHardeningPasses =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.navigatorHardeningPass,
      ) &&
      callV2NavigatorOwnerHardeningAudit.decision ==
          CallV2NavigatorOwnerHardeningAuditDecision.pass;

  bool get lifecycleObserverClosed =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.lifecycleObserverClosed,
      ) &&
      callV2LifecycleObserverHardeningAudit.recordsHardDisabled;

  bool get lifecycleHardeningPasses =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.lifecycleHardeningPass,
      ) &&
      callV2LifecycleObserverHardeningAudit.decision ==
          CallV2LifecycleObserverHardeningAuditDecision.pass;

  bool get routeRegistryHardeningPasses =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.routeRegistryHardeningPass,
      ) &&
      callV2RouteRegistryHardeningAudit.decision ==
          CallV2RouteRegistryHardeningAuditDecision.pass;

  bool get backendFirebaseApprovalClosed =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus
            .backendFirebaseApprovalClosed,
      ) &&
      callV2DeveloperBackendFirebaseApprovalScope.isStrictlyClosed;

  bool get rtcPermissionApprovalClosed =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus
            .rtcPermissionApprovalClosed,
      ) &&
      callV2DeveloperRtcPermissionApprovalScope.isStrictlyClosed;

  bool get runtimeStartupApprovalClosed =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus
            .runtimeStartupApprovalClosed,
      ) &&
      callV2DeveloperRuntimeStartupApprovalScope.isDeveloperOnly &&
      !callV2DeveloperRuntimeStartupApprovalScope.isRolloutEnabled &&
      !callV2DeveloperRuntimeStartupApprovalScope.startsRuntime &&
      !callV2DeveloperRuntimeStartupApprovalScope
          .constructsProductionComposition &&
      !callV2DeveloperRuntimeStartupApprovalScope.wiresStartupMainRouter &&
      !callV2DeveloperRuntimeStartupApprovalScope.isDeploymentApproved &&
      callV2DeveloperRuntimeStartupApprovalScope.rollbackPreserved;

  bool get navigatorApprovalClosed =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.navigatorApprovalClosed,
      ) &&
      callV2DeveloperNavigationOwnerApprovalScope.isDeveloperOnly &&
      !callV2DeveloperNavigationOwnerApprovalScope.isRolloutEnabled &&
      !callV2DeveloperNavigationOwnerApprovalScope.wiresRealNavigation &&
      !callV2DeveloperNavigationOwnerApprovalScope.usesAppNavigationKey &&
      !callV2DeveloperNavigationOwnerApprovalScope.usesGlobalAppKey &&
      !callV2DeveloperNavigationOwnerApprovalScope.storesWidgetContext &&
      !callV2DeveloperNavigationOwnerApprovalScope.wiresMaterialRouteTable &&
      !callV2DeveloperNavigationOwnerApprovalScope.isDeploymentApproved &&
      callV2DeveloperNavigationOwnerApprovalScope.rollbackPreserved;

  bool get lifecycleApprovalClosed =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.lifecycleApprovalClosed,
      ) &&
      callV2DeveloperLifecycleObserverApprovalScope.isDeveloperOnly &&
      !callV2DeveloperLifecycleObserverApprovalScope.isRolloutEnabled &&
      !callV2DeveloperLifecycleObserverApprovalScope
          .registersFrameworkLifecycleHook &&
      !callV2DeveloperLifecycleObserverApprovalScope
          .registersBindingLifecycleHook &&
      !callV2DeveloperLifecycleObserverApprovalScope.isDeploymentApproved &&
      callV2DeveloperLifecycleObserverApprovalScope
          .lifecycleSkeletonIsDisabled &&
      callV2DeveloperLifecycleObserverApprovalScope.rollbackPreserved;

  bool get routeRegistrationApprovalClosed =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus
            .routeRegistrationApprovalClosed,
      ) &&
      callV2DeveloperRouteRegistrationApprovalScope.isDeveloperOnly &&
      !callV2DeveloperRouteRegistrationApprovalScope.isRolloutEnabled &&
      callV2DeveloperRouteRegistrationApprovalScope
          .resolverStillNullWhileFalse &&
      !callV2DeveloperRouteRegistrationApprovalScope.startsRuntime &&
      !callV2DeveloperRouteRegistrationApprovalScope.accessesBackendFirebase &&
      !callV2DeveloperRouteRegistrationApprovalScope.accessesRtcPermissions &&
      !callV2DeveloperRouteRegistrationApprovalScope.wiresNavigator &&
      !callV2DeveloperRouteRegistrationApprovalScope
          .registersLifecycleObserver &&
      !callV2DeveloperRouteRegistrationApprovalScope.isDeploymentApproved &&
      !callV2DeveloperRouteRegistrationApprovalScope.createsRouteObject &&
      !callV2DeveloperRouteRegistrationApprovalScope.createsScreen &&
      !callV2DeveloperRouteRegistrationApprovalScope.usesRouteSink &&
      callV2DeveloperRouteRegistrationApprovalScope.rollbackPreserved;

  bool get preWiringSafetyGateBlocked =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.preWiringGateBlocked,
      ) &&
      callV2DeveloperPreWiringSafetyGate.decision ==
          CallV2DeveloperPreWiringGateDecision.blockedNoScopeSelected &&
      !callV2DeveloperPreWiringSafetyGate.canWireRoutes &&
      !callV2DeveloperPreWiringSafetyGate.canStartRuntime &&
      !callV2DeveloperPreWiringSafetyGate.canRegisterLifecycleObserver &&
      !callV2DeveloperPreWiringSafetyGate.canWireNavigator &&
      !callV2DeveloperPreWiringSafetyGate.canAccessBackendFirebase &&
      !callV2DeveloperPreWiringSafetyGate.canInitializeRtc &&
      !callV2DeveloperPreWiringSafetyGate.canRequestPermissions;

  bool get skeletonCompositionPasses =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.skeletonCompositionPass,
      ) &&
      callV2DeveloperSkeletonCompositionAudit.decision ==
          CallV2DeveloperSkeletonCompositionDecision.pass;

  bool get recordsNoMainDartWiring =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.noMainDartWiring,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsNoMainDartWiring;

  bool get recordsNoAppRouterWiring =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.noAppRouterWiring,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsNoAppRouterWiring &&
      !callV2ProductionFirstWiringApprovalCheckpoint.hasAppRouterConnection;

  bool get recordsNoStartupBridgeWiring =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.noStartupBridgeWiring,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsNoStartupBridgeWiring &&
      !callV2ProductionFirstWiringApprovalCheckpoint.hasMainStartupConnection;

  bool get recordsNoProductionCompositionWiring =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus
            .noProductionCompositionWiring,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit
          .recordsNoProductionCompositionConstruction;

  bool get recordsNoBackendFirebaseAccess =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.noBackendFirebaseAccess,
      ) &&
      callV2BackendFirebaseOwnerHardeningAudit.recordsNoFirebaseImports &&
      callV2BackendFirebaseOwnerHardeningAudit
          .recordsNoProductionServiceContact;

  bool get recordsNoFirestoreListeners =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.noFirestoreListeners,
      ) &&
      callV2BackendFirebaseOwnerHardeningAudit.recordsNoFirestoreListeners;

  bool get recordsNoFirestoreReads =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.noFirestoreReads,
      ) &&
      callV2BackendFirebaseOwnerHardeningAudit.recordsNoFirestoreReads;

  bool get recordsNoFirestoreWrites =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.noFirestoreWrites,
      ) &&
      callV2BackendFirebaseOwnerHardeningAudit.recordsNoFirestoreWrites;

  bool get recordsNoAuthFunctionsAppCheck =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.noAuthFunctionsAppCheck,
      ) &&
      callV2BackendFirebaseOwnerHardeningAudit.recordsNoFirebaseAuthCalls &&
      callV2BackendFirebaseOwnerHardeningAudit
          .recordsNoFirebaseFunctionsCalls &&
      callV2BackendFirebaseOwnerHardeningAudit.recordsNoFirebaseAppCheckCalls;

  bool get recordsNoRtcPermissionMediaDeviceAccess =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus
            .noRtcPermissionMediaDeviceAccess,
      ) &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoRtcEngineCreation &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoRtcChannelJoin &&
      callV2RtcPermissionOwnerHardeningAudit
          .recordsNoRtcTokenChannelConsumption &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoPermissionRequest &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoMicrophoneCameraPrompt &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoDeviceEnumeration &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoMediaCapture &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoCameraPreview &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoAudioVideoPublish &&
      callV2RtcPermissionOwnerHardeningAudit
          .recordsNoRtcCallbacksListenersSubscriptions;

  bool get recordsNoNavigatorWiring =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.noNavigatorWiring,
      ) &&
      !callV2NavigatorOwnerHardeningAudit.wiresRealNavigator &&
      !callV2NavigatorOwnerHardeningAudit.callsNavigator &&
      !callV2NavigatorOwnerHardeningAudit.usesAppNavigatorKey &&
      !callV2NavigatorOwnerHardeningAudit.usesGlobalKey &&
      !callV2NavigatorOwnerHardeningAudit.storesBuildContext &&
      !callV2NavigatorOwnerHardeningAudit.wiresMaterialApp;

  bool get recordsNoLifecycleRegistration =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.noLifecycleRegistration,
      ) &&
      callV2LifecycleObserverHardeningAudit
          .recordsNoFrameworkLifecycleObserver &&
      callV2LifecycleObserverHardeningAudit.recordsNoBindingLifecycleObserver &&
      callV2LifecycleObserverHardeningAudit.recordsNoObserverRegistration &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsNoLifecycleRegistration;

  bool get recordsNoAsyncHandles =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.noAsyncHandles,
      ) &&
      callV2BackendFirebaseOwnerHardeningAudit.recordsNoAsyncHandles &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoAsyncHandles &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsNoAsyncHandles &&
      !callV2NavigatorOwnerHardeningAudit.opensAsyncHandles &&
      callV2LifecycleObserverHardeningAudit.recordsNoAsyncHandles &&
      !callV2RouteRegistryHardeningAudit.createsAsyncHandles;

  bool get recordsNoDependencyPlatformConfigChanges =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus
            .noDependencyPlatformConfigChanges,
      ) &&
      callV2RtcPermissionOwnerHardeningAudit
          .recordsNoPubspecPlatformConfigChanges &&
      !callV2RouteRegistryHardeningAudit.changesPubspecPlatform &&
      !callV2DeveloperPreWiringSafetyGate.canModifyPubspecPlatform &&
      !callV2DeveloperPreWiringSafetyGate.canModifyRulesFunctionsConfig;

  bool get recordsNoDeployment =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.noDeployment,
      ) &&
      callV2BackendFirebaseOwnerHardeningAudit.recordsNoDeployment &&
      callV2RtcPermissionOwnerHardeningAudit.recordsNoDeployment &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsNoDeployment &&
      callV2DeveloperPreWiringSafetyGate.blocksDeployment &&
      !callV2ProductionFirstWiringApprovalCheckpoint.isDeploymentAuthorized;

  bool get rollbackPreserved =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2FinalPreWiringConsolidationRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2FinalPreWiringConsolidationRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2FinalPreWiringConsolidationRollback.keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2FinalPreWiringConsolidationRollback.keepDisabledOwnerInert,
      ) &&
      rollback.contains(
        CallV2FinalPreWiringConsolidationRollback.noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2FinalPreWiringConsolidationRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2FinalPreWiringConsolidationRollback.v1Unaffected,
      );

  bool get protectsV1 =>
      statuses.contains(
        CallV2FinalPreWiringConsolidationAuditStatus.v1Protected,
      ) &&
      callV2BackendFirebaseOwnerHardeningAudit.protectsV1 &&
      callV2RtcPermissionOwnerHardeningAudit.protectsV1 &&
      callV2RuntimeStartupOwnerHardeningAudit.protectsV1 &&
      callV2NavigatorOwnerHardeningAudit.protectsV1 &&
      callV2LifecycleObserverHardeningAudit.protectsV1 &&
      callV2RouteRegistryHardeningAudit.protectsV1 &&
      callV2DeveloperPreWiringSafetyGate.protectsV1;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'developerOnly': recordsDeveloperOnly,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'reachable': !recordsRoutesUnreachable,
      'resolverNullWhileFalse': recordsRouteResolverNullWhileFalse,
      'disabledRegistryNull': recordsDisabledRegistryNull,
      'disabledOwnerInert': recordsDisabledOwnerInert,
      'compositionUnconstructed': recordsProductionCompositionUnconstructed,
      'runtimeUnconstructed': recordsRuntimeUnconstructed,
      'runtimeStarted': !recordsRuntimeNotStarted,
      'backendClosed': backendFirebaseOwnerClosed,
      'rtcPermissionClosed': rtcPermissionOwnerClosed,
      'startupClosed': runtimeStartupOwnerClosed,
      'navigationClosed': navigatorOwnerClosed,
      'lifecycleClosed': lifecycleObserverClosed,
      'approvalsClosed': backendFirebaseApprovalClosed &&
          rtcPermissionApprovalClosed &&
          runtimeStartupApprovalClosed &&
          navigatorApprovalClosed &&
          lifecycleApprovalClosed &&
          routeRegistrationApprovalClosed,
      'preWiringBlocked': preWiringSafetyGateBlocked,
      'skeletonPass': skeletonCompositionPasses,
      'realAppIsolated': recordsNoMainDartWiring &&
          recordsNoAppRouterWiring &&
          recordsNoStartupBridgeWiring &&
          recordsNoProductionCompositionWiring,
      'backendAccess': !recordsNoBackendFirebaseAccess,
      'mediaAccess': !recordsNoRtcPermissionMediaDeviceAccess,
      'navigationWired': !recordsNoNavigatorWiring,
      'lifecycleRegistered': !recordsNoLifecycleRegistration,
      'asyncHandles': !recordsNoAsyncHandles,
      'configChanged': !recordsNoDependencyPlatformConfigChanges,
      'deploymentApproved': !recordsNoDeployment,
      'rollbackPreserved': rollbackPreserved,
      'protectsV1': protectsV1,
    };
  }

  @override
  String toString() {
    return 'CallV2FinalPreWiringConsolidationAudit(${toSafeDebugMap()})';
  }
}

final callV2FinalPreWiringConsolidationAudit =
    CallV2FinalPreWiringConsolidationAudit(
  statuses: <CallV2FinalPreWiringConsolidationAuditStatus>[
    CallV2FinalPreWiringConsolidationAuditStatus.developerOnly,
    CallV2FinalPreWiringConsolidationAuditStatus.rolloutFalse,
    CallV2FinalPreWiringConsolidationAuditStatus.routesUnreachable,
    CallV2FinalPreWiringConsolidationAuditStatus.routeResolverNullWhileFalse,
    CallV2FinalPreWiringConsolidationAuditStatus.disabledRegistryNull,
    CallV2FinalPreWiringConsolidationAuditStatus.disabledOwnerInert,
    CallV2FinalPreWiringConsolidationAuditStatus
        .productionCompositionUnconstructed,
    CallV2FinalPreWiringConsolidationAuditStatus.runtimeUnconstructed,
    CallV2FinalPreWiringConsolidationAuditStatus.runtimeNotStarted,
    CallV2FinalPreWiringConsolidationAuditStatus.backendFirebaseOwnerClosed,
    CallV2FinalPreWiringConsolidationAuditStatus.backendFirebaseHardeningPass,
    CallV2FinalPreWiringConsolidationAuditStatus.rtcPermissionOwnerClosed,
    CallV2FinalPreWiringConsolidationAuditStatus.rtcPermissionHardeningPass,
    CallV2FinalPreWiringConsolidationAuditStatus.runtimeStartupOwnerClosed,
    CallV2FinalPreWiringConsolidationAuditStatus.runtimeStartupHardeningPass,
    CallV2FinalPreWiringConsolidationAuditStatus.navigatorOwnerClosed,
    CallV2FinalPreWiringConsolidationAuditStatus.navigatorHardeningPass,
    CallV2FinalPreWiringConsolidationAuditStatus.lifecycleObserverClosed,
    CallV2FinalPreWiringConsolidationAuditStatus.lifecycleHardeningPass,
    CallV2FinalPreWiringConsolidationAuditStatus.routeRegistryHardeningPass,
    CallV2FinalPreWiringConsolidationAuditStatus.backendFirebaseApprovalClosed,
    CallV2FinalPreWiringConsolidationAuditStatus.rtcPermissionApprovalClosed,
    CallV2FinalPreWiringConsolidationAuditStatus.runtimeStartupApprovalClosed,
    CallV2FinalPreWiringConsolidationAuditStatus.navigatorApprovalClosed,
    CallV2FinalPreWiringConsolidationAuditStatus.lifecycleApprovalClosed,
    CallV2FinalPreWiringConsolidationAuditStatus
        .routeRegistrationApprovalClosed,
    CallV2FinalPreWiringConsolidationAuditStatus.preWiringGateBlocked,
    CallV2FinalPreWiringConsolidationAuditStatus.skeletonCompositionPass,
    CallV2FinalPreWiringConsolidationAuditStatus.noMainDartWiring,
    CallV2FinalPreWiringConsolidationAuditStatus.noAppRouterWiring,
    CallV2FinalPreWiringConsolidationAuditStatus.noStartupBridgeWiring,
    CallV2FinalPreWiringConsolidationAuditStatus.noProductionCompositionWiring,
    CallV2FinalPreWiringConsolidationAuditStatus.noBackendFirebaseAccess,
    CallV2FinalPreWiringConsolidationAuditStatus.noFirestoreListeners,
    CallV2FinalPreWiringConsolidationAuditStatus.noFirestoreReads,
    CallV2FinalPreWiringConsolidationAuditStatus.noFirestoreWrites,
    CallV2FinalPreWiringConsolidationAuditStatus.noAuthFunctionsAppCheck,
    CallV2FinalPreWiringConsolidationAuditStatus
        .noRtcPermissionMediaDeviceAccess,
    CallV2FinalPreWiringConsolidationAuditStatus.noNavigatorWiring,
    CallV2FinalPreWiringConsolidationAuditStatus.noLifecycleRegistration,
    CallV2FinalPreWiringConsolidationAuditStatus.noAsyncHandles,
    CallV2FinalPreWiringConsolidationAuditStatus
        .noDependencyPlatformConfigChanges,
    CallV2FinalPreWiringConsolidationAuditStatus.noDeployment,
    CallV2FinalPreWiringConsolidationAuditStatus.rollbackOneCommit,
    CallV2FinalPreWiringConsolidationAuditStatus.v1Protected,
  ],
  rollback: <CallV2FinalPreWiringConsolidationRollback>[
    CallV2FinalPreWiringConsolidationRollback.oneCommitRevert,
    CallV2FinalPreWiringConsolidationRollback.keepRolloutFalse,
    CallV2FinalPreWiringConsolidationRollback.keepRouteRegistryNull,
    CallV2FinalPreWiringConsolidationRollback.keepDisabledOwnerInert,
    CallV2FinalPreWiringConsolidationRollback.noDeploymentRequired,
    CallV2FinalPreWiringConsolidationRollback.noConfigChanges,
    CallV2FinalPreWiringConsolidationRollback.v1Unaffected,
  ],
);
