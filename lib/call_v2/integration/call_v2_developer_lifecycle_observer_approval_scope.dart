import 'call_v2_developer_lifecycle_observer_skeleton.dart';
import 'call_v2_developer_pre_wiring_safety_gate.dart';

enum CallV2DeveloperLifecycleObserverApprovalEvidence {
  phase7MHumanApproved,
  lifecycleObserverOnly,
  developerOnly,
  rolloutFalse,
  noRuntime,
  noBackendFirebase,
  noRtcPermissions,
  noNavigator,
  noRouteRegistryMutation,
  noFrameworkLifecycleHook,
  noBindingLifecycleHook,
  noStartupMainRouterWiring,
  noPubspecPlatformConfig,
  noRulesFunctionsConfig,
  noDeployment,
  v1Protected,
}

enum CallV2DeveloperLifecycleObserverApprovalRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2DeveloperLifecycleObserverApprovalScope {
  factory CallV2DeveloperLifecycleObserverApprovalScope({
    required CallV2DeveloperPreWiringSafetyGate preWiringGate,
    required CallV2DeveloperLifecycleObserverSkeleton lifecycleSkeleton,
    required List<CallV2DeveloperLifecycleObserverApprovalEvidence> evidence,
    required List<String> allowedFutureFiles,
    required List<String> forbiddenFutureFiles,
    required List<CallV2DeveloperLifecycleObserverApprovalRollback> rollback,
  }) {
    return CallV2DeveloperLifecycleObserverApprovalScope._(
      preWiringGate,
      lifecycleSkeleton,
      List<CallV2DeveloperLifecycleObserverApprovalEvidence>.unmodifiable(
        evidence,
      ),
      List<String>.unmodifiable(allowedFutureFiles),
      List<String>.unmodifiable(forbiddenFutureFiles),
      List<CallV2DeveloperLifecycleObserverApprovalRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2DeveloperLifecycleObserverApprovalScope._(
    this.preWiringGate,
    this.lifecycleSkeleton,
    this.evidence,
    this.allowedFutureFiles,
    this.forbiddenFutureFiles,
    this.rollback,
  );

  final CallV2DeveloperPreWiringSafetyGate preWiringGate;
  final CallV2DeveloperLifecycleObserverSkeleton lifecycleSkeleton;
  final List<CallV2DeveloperLifecycleObserverApprovalEvidence> evidence;
  final List<String> allowedFutureFiles;
  final List<String> forbiddenFutureFiles;
  final List<CallV2DeveloperLifecycleObserverApprovalRollback> rollback;

  CallV2DeveloperPreWiringSafetyGate get evaluatedGate =>
      preWiringGate.evaluateFutureScope(
        selectedScope: CallV2DeveloperPreWiringScope.lifecycleObserverOnly,
        explicitFutureApproval: true,
        allowedFilesListed: true,
        oneCommitRollbackConfirmed: true,
      );

  bool get hasHumanApproval => evidence.contains(
        CallV2DeveloperLifecycleObserverApprovalEvidence.phase7MHumanApproved,
      );

  bool get isLifecycleObserverOnly => evidence.contains(
        CallV2DeveloperLifecycleObserverApprovalEvidence.lifecycleObserverOnly,
      );

  bool get isDeveloperOnly => evidence.contains(
        CallV2DeveloperLifecycleObserverApprovalEvidence.developerOnly,
      );

  bool get isRolloutEnabled => !evidence.contains(
        CallV2DeveloperLifecycleObserverApprovalEvidence.rolloutFalse,
      );

  bool get startsRuntime => !evidence.contains(
        CallV2DeveloperLifecycleObserverApprovalEvidence.noRuntime,
      );

  bool get accessesBackendFirebase => !evidence.contains(
        CallV2DeveloperLifecycleObserverApprovalEvidence.noBackendFirebase,
      );

  bool get accessesRtcPermissions => !evidence.contains(
        CallV2DeveloperLifecycleObserverApprovalEvidence.noRtcPermissions,
      );

  bool get wiresNavigator => !evidence.contains(
        CallV2DeveloperLifecycleObserverApprovalEvidence.noNavigator,
      );

  bool get mutatesRouteRegistry => !evidence.contains(
        CallV2DeveloperLifecycleObserverApprovalEvidence
            .noRouteRegistryMutation,
      );

  bool get registersFrameworkLifecycleHook => !evidence.contains(
        CallV2DeveloperLifecycleObserverApprovalEvidence
            .noFrameworkLifecycleHook,
      );

  bool get registersBindingLifecycleHook => !evidence.contains(
        CallV2DeveloperLifecycleObserverApprovalEvidence.noBindingLifecycleHook,
      );

  bool get wiresStartupMainRouter => !evidence.contains(
        CallV2DeveloperLifecycleObserverApprovalEvidence
            .noStartupMainRouterWiring,
      );

  bool get changesPubspecPlatformConfig => !evidence.contains(
        CallV2DeveloperLifecycleObserverApprovalEvidence
            .noPubspecPlatformConfig,
      );

  bool get changesRulesFunctionsConfig => !evidence.contains(
        CallV2DeveloperLifecycleObserverApprovalEvidence.noRulesFunctionsConfig,
      );

  bool get isDeploymentApproved => !evidence.contains(
        CallV2DeveloperLifecycleObserverApprovalEvidence.noDeployment,
      );

  bool get protectsV1 => evidence.contains(
        CallV2DeveloperLifecycleObserverApprovalEvidence.v1Protected,
      );

  bool get allowedFutureFilesAreLifecycleObserverOnly =>
      allowedFutureFiles.length == 2 &&
      allowedFutureFiles.contains(
        'lib/call_v2/integration/call_v2_lifecycle_observer.dart',
      ) &&
      allowedFutureFiles.contains(
        'test/call_v2/integration/call_v2_lifecycle_observer_test.dart',
      );

  bool get forbidsOutOfScopeFutureFiles =>
      forbiddenFutureFiles.contains('lib/main.dart') &&
      forbiddenFutureFiles.contains('lib/navigation/app_router.dart') &&
      forbiddenFutureFiles.contains('lib/call_v2/startup/**') &&
      forbiddenFutureFiles.contains('lib/call_v2/runtime/**') &&
      forbiddenFutureFiles.contains('lib/call_v2/firebase/**') &&
      forbiddenFutureFiles.contains('lib/call_v2/rtc/**') &&
      forbiddenFutureFiles.contains('lib/call_v2/permissions/**') &&
      forbiddenFutureFiles.contains(
        'lib/call_v2/integration/call_v2_route_registry.dart',
      ) &&
      forbiddenFutureFiles.contains('lib/call_v2/integration/navigator/**') &&
      forbiddenFutureFiles.contains('pubspec.yaml') &&
      forbiddenFutureFiles.contains('pubspec.lock') &&
      forbiddenFutureFiles.contains('android/**') &&
      forbiddenFutureFiles.contains('ios/**') &&
      forbiddenFutureFiles.contains('firestore.rules') &&
      forbiddenFutureFiles.contains('firebase.json') &&
      forbiddenFutureFiles.contains('connect_functions/**');

  bool get rollbackPreserved =>
      rollback.contains(
        CallV2DeveloperLifecycleObserverApprovalRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2DeveloperLifecycleObserverApprovalRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2DeveloperLifecycleObserverApprovalRollback.keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2DeveloperLifecycleObserverApprovalRollback.keepDisabledOwnerInert,
      ) &&
      rollback.contains(
        CallV2DeveloperLifecycleObserverApprovalRollback.noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2DeveloperLifecycleObserverApprovalRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2DeveloperLifecycleObserverApprovalRollback.v1Unaffected,
      );

  bool get lifecycleSkeletonIsDisabled =>
      lifecycleSkeleton.isHardDisabled &&
      !lifecycleSkeleton.isReachable &&
      !lifecycleSkeleton.registersFrameworkHook &&
      !lifecycleSkeleton.registersBindingHook &&
      !lifecycleSkeleton.opensAsyncHandles;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'evidenceCount': evidence.length,
      'allowedFutureFileCount': allowedFutureFiles.length,
      'forbiddenFutureFileCount': forbiddenFutureFiles.length,
      'rollbackCount': rollback.length,
      'gateDecision': evaluatedGate.decision.name,
      'humanApproved': hasHumanApproval,
      'lifecycleObserverOnly': isLifecycleObserverOnly,
      'developerOnly': isDeveloperOnly,
      'rolloutEnabled': isRolloutEnabled,
      'startsRuntime': startsRuntime,
      'accessesBackend': accessesBackendFirebase,
      'accessesMediaCapabilities': accessesRtcPermissions,
      'wiresNavigator': wiresNavigator,
      'mutatesRouteRegistry': mutatesRouteRegistry,
      'registersFrameworkLifecycleHook': registersFrameworkLifecycleHook,
      'registersBindingLifecycleHook': registersBindingLifecycleHook,
      'wiresStartupMainRouter': wiresStartupMainRouter,
      'changesPubspecPlatformConfig': changesPubspecPlatformConfig,
      'changesServerConfig': changesRulesFunctionsConfig,
      'deploymentApproved': isDeploymentApproved,
      'allowedFilesScoped': allowedFutureFilesAreLifecycleObserverOnly,
      'forbiddenFilesScoped': forbidsOutOfScopeFutureFiles,
      'lifecycleSkeletonDisabled': lifecycleSkeletonIsDisabled,
      'rollbackPreserved': rollbackPreserved,
      'protectsV1': protectsV1,
    };
  }

  @override
  String toString() {
    return 'CallV2DeveloperLifecycleObserverApprovalScope'
        '(${toSafeDebugMap()})';
  }
}

final callV2DeveloperLifecycleObserverApprovalScope =
    CallV2DeveloperLifecycleObserverApprovalScope(
  preWiringGate: callV2DeveloperPreWiringSafetyGate,
  lifecycleSkeleton: callV2DeveloperLifecycleObserverSkeleton,
  evidence: <CallV2DeveloperLifecycleObserverApprovalEvidence>[
    CallV2DeveloperLifecycleObserverApprovalEvidence.phase7MHumanApproved,
    CallV2DeveloperLifecycleObserverApprovalEvidence.lifecycleObserverOnly,
    CallV2DeveloperLifecycleObserverApprovalEvidence.developerOnly,
    CallV2DeveloperLifecycleObserverApprovalEvidence.rolloutFalse,
    CallV2DeveloperLifecycleObserverApprovalEvidence.noRuntime,
    CallV2DeveloperLifecycleObserverApprovalEvidence.noBackendFirebase,
    CallV2DeveloperLifecycleObserverApprovalEvidence.noRtcPermissions,
    CallV2DeveloperLifecycleObserverApprovalEvidence.noNavigator,
    CallV2DeveloperLifecycleObserverApprovalEvidence.noRouteRegistryMutation,
    CallV2DeveloperLifecycleObserverApprovalEvidence.noFrameworkLifecycleHook,
    CallV2DeveloperLifecycleObserverApprovalEvidence.noBindingLifecycleHook,
    CallV2DeveloperLifecycleObserverApprovalEvidence.noStartupMainRouterWiring,
    CallV2DeveloperLifecycleObserverApprovalEvidence.noPubspecPlatformConfig,
    CallV2DeveloperLifecycleObserverApprovalEvidence.noRulesFunctionsConfig,
    CallV2DeveloperLifecycleObserverApprovalEvidence.noDeployment,
    CallV2DeveloperLifecycleObserverApprovalEvidence.v1Protected,
  ],
  allowedFutureFiles: <String>[
    'lib/call_v2/integration/call_v2_lifecycle_observer.dart',
    'test/call_v2/integration/call_v2_lifecycle_observer_test.dart',
  ],
  forbiddenFutureFiles: <String>[
    'lib/main.dart',
    'lib/navigation/app_router.dart',
    'lib/call_v2/startup/**',
    'lib/call_v2/runtime/**',
    'lib/call_v2/firebase/**',
    'lib/call_v2/rtc/**',
    'lib/call_v2/permissions/**',
    'lib/call_v2/integration/call_v2_route_registry.dart',
    'lib/call_v2/integration/navigator/**',
    'pubspec.yaml',
    'pubspec.lock',
    'android/**',
    'ios/**',
    'firestore.rules',
    'firebase.json',
    'connect_functions/**',
  ],
  rollback: <CallV2DeveloperLifecycleObserverApprovalRollback>[
    CallV2DeveloperLifecycleObserverApprovalRollback.oneCommitRevert,
    CallV2DeveloperLifecycleObserverApprovalRollback.keepRolloutFalse,
    CallV2DeveloperLifecycleObserverApprovalRollback.keepRouteRegistryNull,
    CallV2DeveloperLifecycleObserverApprovalRollback.keepDisabledOwnerInert,
    CallV2DeveloperLifecycleObserverApprovalRollback.noDeploymentRequired,
    CallV2DeveloperLifecycleObserverApprovalRollback.noConfigChanges,
    CallV2DeveloperLifecycleObserverApprovalRollback.v1Unaffected,
  ],
);
