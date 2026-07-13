import 'call_v2_developer_backend_firebase_owner_skeleton.dart';
import 'call_v2_developer_lifecycle_observer_skeleton.dart';
import 'call_v2_developer_navigator_owner_skeleton.dart';
import 'call_v2_developer_route_registration_skeleton.dart';
import 'call_v2_developer_rtc_permission_owner_skeleton.dart';
import 'call_v2_developer_runtime_startup_owner_skeleton.dart';

enum CallV2DeveloperSkeletonComponent {
  routeRegistration,
  lifecycleObserver,
  navigatorOwner,
  runtimeStartupOwner,
  backendFirebaseOwner,
  rtcPermissionOwner,
}

enum CallV2DeveloperSkeletonCompositionInvariant {
  developerOnly,
  hardDisabled,
  rolloutFalse,
  unreachable,
  noRuntimeStart,
  noProductionCompositionStartup,
  noBackendFirebaseAccess,
  noRtcPermissionAccess,
  noNavigatorWiring,
  noLifecycleObserverRegistration,
  noRouteRegistryMutation,
  noAsyncHandles,
  noPubspecPlatformChanges,
  noRulesFunctionsConfigChanges,
  v1Protected,
}

enum CallV2DeveloperSkeletonCompositionDecision {
  pass,
  blocked,
}

enum CallV2DeveloperSkeletonCompositionRollback {
  oneCommitPerSkeleton,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  v1Unaffected,
}

final class CallV2DeveloperSkeletonCompositionAudit {
  factory CallV2DeveloperSkeletonCompositionAudit({
    required List<CallV2DeveloperSkeletonComponent> components,
    required List<CallV2DeveloperSkeletonCompositionInvariant> invariants,
    required List<CallV2DeveloperSkeletonCompositionRollback> rollback,
  }) {
    return CallV2DeveloperSkeletonCompositionAudit._(
      List<CallV2DeveloperSkeletonComponent>.unmodifiable(components),
      List<CallV2DeveloperSkeletonCompositionInvariant>.unmodifiable(
        invariants,
      ),
      List<CallV2DeveloperSkeletonCompositionRollback>.unmodifiable(rollback),
    );
  }

  const CallV2DeveloperSkeletonCompositionAudit._(
    this.components,
    this.invariants,
    this.rollback,
  );

  final List<CallV2DeveloperSkeletonComponent> components;
  final List<CallV2DeveloperSkeletonCompositionInvariant> invariants;
  final List<CallV2DeveloperSkeletonCompositionRollback> rollback;

  bool get includesRouteRegistration =>
      components.contains(CallV2DeveloperSkeletonComponent.routeRegistration);

  bool get includesLifecycleObserver =>
      components.contains(CallV2DeveloperSkeletonComponent.lifecycleObserver);

  bool get includesNavigatorOwner =>
      components.contains(CallV2DeveloperSkeletonComponent.navigatorOwner);

  bool get includesRuntimeStartupOwner =>
      components.contains(CallV2DeveloperSkeletonComponent.runtimeStartupOwner);

  bool get includesBackendFirebaseOwner => components
      .contains(CallV2DeveloperSkeletonComponent.backendFirebaseOwner);

  bool get includesRtcPermissionOwner =>
      components.contains(CallV2DeveloperSkeletonComponent.rtcPermissionOwner);

  bool get allComponentsPresent =>
      components.length == CallV2DeveloperSkeletonComponent.values.length &&
      includesRouteRegistration &&
      includesLifecycleObserver &&
      includesNavigatorOwner &&
      includesRuntimeStartupOwner &&
      includesBackendFirebaseOwner &&
      includesRtcPermissionOwner;

  bool get isDeveloperOnly =>
      invariants.contains(
        CallV2DeveloperSkeletonCompositionInvariant.developerOnly,
      ) &&
      callV2DeveloperRouteRegistrationSkeleton.isDeveloperOnly &&
      callV2DeveloperLifecycleObserverSkeleton.isDeveloperOnly &&
      callV2DeveloperNavigatorOwnerSkeleton.isDeveloperOnly &&
      callV2DeveloperRuntimeStartupOwnerSkeleton.isDeveloperOnly &&
      callV2DeveloperBackendOwnerSkeleton.isDeveloperOnly &&
      callV2DeveloperRtcPermissionOwnerSkeleton.isDeveloperOnly;

  bool get isHardDisabled =>
      invariants.contains(
        CallV2DeveloperSkeletonCompositionInvariant.hardDisabled,
      ) &&
      callV2DeveloperRouteRegistrationSkeleton.isHardDisabled &&
      callV2DeveloperLifecycleObserverSkeleton.isHardDisabled &&
      callV2DeveloperNavigatorOwnerSkeleton.isHardDisabled &&
      callV2DeveloperRuntimeStartupOwnerSkeleton.isHardDisabled &&
      callV2DeveloperBackendOwnerSkeleton.isHardDisabled &&
      callV2DeveloperRtcPermissionOwnerSkeleton.isHardDisabled;

  bool get isRolloutEnabled =>
      !invariants.contains(
        CallV2DeveloperSkeletonCompositionInvariant.rolloutFalse,
      ) ||
      callV2DeveloperRouteRegistrationSkeleton.isRolloutEnabled ||
      callV2DeveloperLifecycleObserverSkeleton.isRolloutEnabled ||
      callV2DeveloperNavigatorOwnerSkeleton.isRolloutEnabled ||
      callV2DeveloperRuntimeStartupOwnerSkeleton.isRolloutEnabled ||
      callV2DeveloperBackendOwnerSkeleton.isRolloutEnabled ||
      callV2DeveloperRtcPermissionOwnerSkeleton.isRolloutEnabled;

  bool get isReachable =>
      !invariants.contains(
        CallV2DeveloperSkeletonCompositionInvariant.unreachable,
      ) ||
      callV2DeveloperRouteRegistrationSkeleton.isReachable ||
      callV2DeveloperLifecycleObserverSkeleton.isReachable ||
      callV2DeveloperNavigatorOwnerSkeleton.isReachable ||
      callV2DeveloperRuntimeStartupOwnerSkeleton.isReachable ||
      callV2DeveloperBackendOwnerSkeleton.isReachable ||
      callV2DeveloperRtcPermissionOwnerSkeleton.isReachable;

  bool get startsRuntime =>
      callV2DeveloperRouteRegistrationSkeleton.startsRuntime ||
      callV2DeveloperLifecycleObserverSkeleton.startsRuntime ||
      callV2DeveloperNavigatorOwnerSkeleton.startsRuntime ||
      callV2DeveloperRuntimeStartupOwnerSkeleton.startsRuntime ||
      callV2DeveloperBackendOwnerSkeleton.startsRuntime ||
      callV2DeveloperRtcPermissionOwnerSkeleton.startsRuntime;

  bool get constructsProductionComposition =>
      callV2DeveloperRuntimeStartupOwnerSkeleton.constructsComposition ||
      callV2DeveloperBackendOwnerSkeleton.constructsComposition ||
      callV2DeveloperRtcPermissionOwnerSkeleton.constructsComposition;

  bool get accessesBackendFirebase =>
      callV2DeveloperRouteRegistrationSkeleton.accessesServices ||
      callV2DeveloperLifecycleObserverSkeleton.accessesServices ||
      callV2DeveloperNavigatorOwnerSkeleton.accessesServices ||
      callV2DeveloperRuntimeStartupOwnerSkeleton.accessesServices ||
      callV2DeveloperBackendOwnerSkeleton.attachesBackend ||
      callV2DeveloperBackendOwnerSkeleton.importsServices ||
      callV2DeveloperBackendOwnerSkeleton.opensDocumentListeners ||
      callV2DeveloperBackendOwnerSkeleton.readsOrWritesDocuments ||
      callV2DeveloperBackendOwnerSkeleton.callsIdentityOrCallable ||
      callV2DeveloperBackendOwnerSkeleton.handlesAppCheckDebugToken ||
      callV2DeveloperRtcPermissionOwnerSkeleton.accessesBackendServices;

  bool get opensFirestoreListeners =>
      callV2DeveloperBackendOwnerSkeleton.opensDocumentListeners;

  bool get callsAuthFunctions =>
      callV2DeveloperBackendOwnerSkeleton.callsIdentityOrCallable;

  bool get accessesRtcPermissions =>
      callV2DeveloperLifecycleObserverSkeleton.accessesMedia ||
      callV2DeveloperLifecycleObserverSkeleton.promptsForCapabilities ||
      callV2DeveloperNavigatorOwnerSkeleton.accessesMedia ||
      callV2DeveloperNavigatorOwnerSkeleton.promptsForCapabilities ||
      callV2DeveloperRuntimeStartupOwnerSkeleton.accessesMedia ||
      callV2DeveloperRuntimeStartupOwnerSkeleton.promptsForCapabilities ||
      callV2DeveloperBackendOwnerSkeleton.accessesMedia ||
      callV2DeveloperBackendOwnerSkeleton.promptsForCapabilities ||
      callV2DeveloperRtcPermissionOwnerSkeleton.attachesRtcPermission ||
      callV2DeveloperRtcPermissionOwnerSkeleton.importsRtcPermissionPackages ||
      callV2DeveloperRtcPermissionOwnerSkeleton.initializesRtcEngine ||
      callV2DeveloperRtcPermissionOwnerSkeleton.joinsRtcChannel ||
      callV2DeveloperRtcPermissionOwnerSkeleton.consumesRtcCredentialMaterial ||
      callV2DeveloperRtcPermissionOwnerSkeleton.promptsForPermissions ||
      callV2DeveloperRtcPermissionOwnerSkeleton.enumeratesDevices ||
      callV2DeveloperRtcPermissionOwnerSkeleton.capturesMedia ||
      callV2DeveloperRtcPermissionOwnerSkeleton.publishesAudioVideo ||
      callV2DeveloperRtcPermissionOwnerSkeleton
          .opensRtcCallbacksOrSubscriptions;

  bool get initializesRtc =>
      callV2DeveloperRtcPermissionOwnerSkeleton.initializesRtcEngine;

  bool get requestsPermissions =>
      callV2DeveloperRtcPermissionOwnerSkeleton.promptsForPermissions;

  bool get enumeratesDevices =>
      callV2DeveloperRtcPermissionOwnerSkeleton.enumeratesDevices;

  bool get capturesMedia =>
      callV2DeveloperRtcPermissionOwnerSkeleton.capturesMedia;

  bool get wiresNavigator =>
      callV2DeveloperRouteRegistrationSkeleton.accessesNavigator ||
      callV2DeveloperLifecycleObserverSkeleton.accessesNavigation ||
      callV2DeveloperNavigatorOwnerSkeleton.wiresRealNavigation ||
      callV2DeveloperNavigatorOwnerSkeleton.usesAppNavigationKey ||
      callV2DeveloperNavigatorOwnerSkeleton.usesGlobalAppKey ||
      callV2DeveloperNavigatorOwnerSkeleton.storesWidgetContext ||
      callV2DeveloperNavigatorOwnerSkeleton.callsNavigation ||
      callV2DeveloperNavigatorOwnerSkeleton.wiresMaterialRouteTable ||
      callV2DeveloperNavigatorOwnerSkeleton.wiresAppRouter ||
      callV2DeveloperNavigatorOwnerSkeleton.pushesRoutes ||
      callV2DeveloperNavigatorOwnerSkeleton.popsRoutes ||
      callV2DeveloperNavigatorOwnerSkeleton.replacesRoutes ||
      callV2DeveloperRuntimeStartupOwnerSkeleton.accessesNavigation ||
      callV2DeveloperBackendOwnerSkeleton.accessesNavigation ||
      callV2DeveloperRtcPermissionOwnerSkeleton.accessesNavigation;

  bool get registersLifecycleObserver =>
      callV2DeveloperLifecycleObserverSkeleton.registersFrameworkHook ||
      callV2DeveloperLifecycleObserverSkeleton.registersBindingHook ||
      callV2DeveloperRuntimeStartupOwnerSkeleton.registersLifecycleHook;

  bool get mutatesRouteRegistry =>
      callV2DeveloperRouteRegistrationSkeleton.createsRouteObjects ||
      callV2DeveloperLifecycleObserverSkeleton
          .decideWhileDisabled(
            event: CallV2DeveloperLifecycleEvent.dispose,
            generation: 1,
          )
          .changesRouteRegistry ||
      callV2DeveloperRuntimeStartupOwnerSkeleton.mutatesRouteRegistry ||
      callV2DeveloperBackendOwnerSkeleton.mutatesRouteRegistry ||
      callV2DeveloperRtcPermissionOwnerSkeleton.mutatesRouteRegistry;

  bool get opensAsyncHandles =>
      callV2DeveloperLifecycleObserverSkeleton.opensAsyncHandles ||
      callV2DeveloperRuntimeStartupOwnerSkeleton.opensAsyncHandles ||
      callV2DeveloperBackendOwnerSkeleton.opensAsyncHandles ||
      callV2DeveloperRtcPermissionOwnerSkeleton.opensAsyncHandles;

  bool get changesPubspecPlatformConfig =>
      callV2DeveloperRtcPermissionOwnerSkeleton.changesPubspecPlatformConfig;

  bool get changesRulesFunctionsConfig =>
      callV2DeveloperBackendOwnerSkeleton.changesServerRulesConfig;

  bool get protectsV1 =>
      invariants
          .contains(CallV2DeveloperSkeletonCompositionInvariant.v1Protected) &&
      callV2DeveloperRouteRegistrationSkeleton.status.contains(
        CallV2DeveloperRouteRegistrationSkeletonStatus.v1Protected,
      ) &&
      callV2DeveloperLifecycleObserverSkeleton.protectsV1 &&
      callV2DeveloperNavigatorOwnerSkeleton.protectsV1 &&
      callV2DeveloperRuntimeStartupOwnerSkeleton.protectsV1 &&
      callV2DeveloperBackendOwnerSkeleton.protectsV1 &&
      callV2DeveloperRtcPermissionOwnerSkeleton.protectsV1;

  bool get rollbackPreserved =>
      rollback.contains(
        CallV2DeveloperSkeletonCompositionRollback.oneCommitPerSkeleton,
      ) &&
      rollback.contains(
        CallV2DeveloperSkeletonCompositionRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2DeveloperSkeletonCompositionRollback.keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2DeveloperSkeletonCompositionRollback.keepDisabledOwnerInert,
      ) &&
      rollback.contains(
        CallV2DeveloperSkeletonCompositionRollback.noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2DeveloperSkeletonCompositionRollback.v1Unaffected,
      );

  bool get passesSharedInvariants =>
      allComponentsPresent &&
      isDeveloperOnly &&
      isHardDisabled &&
      !isRolloutEnabled &&
      !isReachable &&
      !startsRuntime &&
      !constructsProductionComposition &&
      !accessesBackendFirebase &&
      !opensFirestoreListeners &&
      !callsAuthFunctions &&
      !accessesRtcPermissions &&
      !initializesRtc &&
      !requestsPermissions &&
      !enumeratesDevices &&
      !capturesMedia &&
      !wiresNavigator &&
      !registersLifecycleObserver &&
      !mutatesRouteRegistry &&
      !opensAsyncHandles &&
      !changesPubspecPlatformConfig &&
      !changesRulesFunctionsConfig &&
      protectsV1 &&
      rollbackPreserved;

  CallV2DeveloperSkeletonCompositionDecision get decision =>
      passesSharedInvariants
          ? CallV2DeveloperSkeletonCompositionDecision.pass
          : CallV2DeveloperSkeletonCompositionDecision.blocked;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'componentCount': components.length,
      'invariantCount': invariants.length,
      'rollbackCount': rollback.length,
      'decision': decision.name,
      'allComponentsPresent': allComponentsPresent,
      'developerOnly': isDeveloperOnly,
      'hardDisabled': isHardDisabled,
      'rolloutEnabled': isRolloutEnabled,
      'reachable': isReachable,
      'startsRuntime': startsRuntime,
      'constructsProductionComposition': constructsProductionComposition,
      'accessesBackend': accessesBackendFirebase,
      'opensDocumentListeners': opensFirestoreListeners,
      'callsIdentityServices': callsAuthFunctions,
      'accessesMediaCapabilities': accessesRtcPermissions,
      'initializesRtc': initializesRtc,
      'requestsPermissions': requestsPermissions,
      'enumeratesDevices': enumeratesDevices,
      'capturesMedia': capturesMedia,
      'wiresNavigator': wiresNavigator,
      'registersLifecycleObserver': registersLifecycleObserver,
      'mutatesRouteRegistry': mutatesRouteRegistry,
      'opensAsyncHandles': opensAsyncHandles,
      'changesPubspecPlatformConfig': changesPubspecPlatformConfig,
      'changesServerConfig': changesRulesFunctionsConfig,
      'protectsV1': protectsV1,
      'rollbackPreserved': rollbackPreserved,
    };
  }

  @override
  String toString() {
    return 'CallV2DeveloperSkeletonCompositionAudit(${toSafeDebugMap()})';
  }
}

final callV2DeveloperSkeletonCompositionAudit =
    CallV2DeveloperSkeletonCompositionAudit(
  components: <CallV2DeveloperSkeletonComponent>[
    CallV2DeveloperSkeletonComponent.routeRegistration,
    CallV2DeveloperSkeletonComponent.lifecycleObserver,
    CallV2DeveloperSkeletonComponent.navigatorOwner,
    CallV2DeveloperSkeletonComponent.runtimeStartupOwner,
    CallV2DeveloperSkeletonComponent.backendFirebaseOwner,
    CallV2DeveloperSkeletonComponent.rtcPermissionOwner,
  ],
  invariants: <CallV2DeveloperSkeletonCompositionInvariant>[
    CallV2DeveloperSkeletonCompositionInvariant.developerOnly,
    CallV2DeveloperSkeletonCompositionInvariant.hardDisabled,
    CallV2DeveloperSkeletonCompositionInvariant.rolloutFalse,
    CallV2DeveloperSkeletonCompositionInvariant.unreachable,
    CallV2DeveloperSkeletonCompositionInvariant.noRuntimeStart,
    CallV2DeveloperSkeletonCompositionInvariant.noProductionCompositionStartup,
    CallV2DeveloperSkeletonCompositionInvariant.noBackendFirebaseAccess,
    CallV2DeveloperSkeletonCompositionInvariant.noRtcPermissionAccess,
    CallV2DeveloperSkeletonCompositionInvariant.noNavigatorWiring,
    CallV2DeveloperSkeletonCompositionInvariant.noLifecycleObserverRegistration,
    CallV2DeveloperSkeletonCompositionInvariant.noRouteRegistryMutation,
    CallV2DeveloperSkeletonCompositionInvariant.noAsyncHandles,
    CallV2DeveloperSkeletonCompositionInvariant.noPubspecPlatformChanges,
    CallV2DeveloperSkeletonCompositionInvariant.noRulesFunctionsConfigChanges,
    CallV2DeveloperSkeletonCompositionInvariant.v1Protected,
  ],
  rollback: <CallV2DeveloperSkeletonCompositionRollback>[
    CallV2DeveloperSkeletonCompositionRollback.oneCommitPerSkeleton,
    CallV2DeveloperSkeletonCompositionRollback.keepRolloutFalse,
    CallV2DeveloperSkeletonCompositionRollback.keepRouteRegistryNull,
    CallV2DeveloperSkeletonCompositionRollback.keepDisabledOwnerInert,
    CallV2DeveloperSkeletonCompositionRollback.noDeploymentRequired,
    CallV2DeveloperSkeletonCompositionRollback.v1Unaffected,
  ],
);
