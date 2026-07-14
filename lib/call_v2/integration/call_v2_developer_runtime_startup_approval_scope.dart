import 'call_v2_developer_pre_wiring_safety_gate.dart';

enum CallV2DeveloperRuntimeStartupApprovalEvidence {
  phase7SHumanApproved,
  runtimeStartupOwnerOnly,
  developerOnly,
  rolloutFalse,
  noBackendFirebase,
  noRtcPermissions,
  noNavigation,
  noLifecycleRegistration,
  noRouteRegistryMutation,
  noProductionCompositionConstruction,
  noRuntimeStartup,
  noStartupMainRouterWiring,
  noPubspecPlatformConfig,
  noRulesFunctionsConfig,
  noDeployment,
  v1Protected,
}

enum CallV2DeveloperRuntimeStartupApprovalRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2DeveloperRuntimeStartupApprovalScope {
  factory CallV2DeveloperRuntimeStartupApprovalScope({
    required CallV2DeveloperPreWiringSafetyGate preWiringGate,
    required List<CallV2DeveloperRuntimeStartupApprovalEvidence> evidence,
    required List<String> allowedFutureFiles,
    required List<String> forbiddenFutureFiles,
    required List<CallV2DeveloperRuntimeStartupApprovalRollback> rollback,
  }) {
    return CallV2DeveloperRuntimeStartupApprovalScope._(
      preWiringGate,
      List<CallV2DeveloperRuntimeStartupApprovalEvidence>.unmodifiable(
        evidence,
      ),
      List<String>.unmodifiable(allowedFutureFiles),
      List<String>.unmodifiable(forbiddenFutureFiles),
      List<CallV2DeveloperRuntimeStartupApprovalRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2DeveloperRuntimeStartupApprovalScope._(
    this.preWiringGate,
    this.evidence,
    this.allowedFutureFiles,
    this.forbiddenFutureFiles,
    this.rollback,
  );

  final CallV2DeveloperPreWiringSafetyGate preWiringGate;
  final List<CallV2DeveloperRuntimeStartupApprovalEvidence> evidence;
  final List<String> allowedFutureFiles;
  final List<String> forbiddenFutureFiles;
  final List<CallV2DeveloperRuntimeStartupApprovalRollback> rollback;

  CallV2DeveloperPreWiringSafetyGate get evaluatedGate =>
      preWiringGate.evaluateFutureScope(
        selectedScope: CallV2DeveloperPreWiringScope.runtimeStartupOwnerOnly,
        explicitFutureApproval: true,
        allowedFilesListed: true,
        oneCommitRollbackConfirmed: true,
      );

  bool get hasHumanApproval => evidence.contains(
        CallV2DeveloperRuntimeStartupApprovalEvidence.phase7SHumanApproved,
      );

  bool get isRuntimeStartupOwnerOnly => evidence.contains(
        CallV2DeveloperRuntimeStartupApprovalEvidence.runtimeStartupOwnerOnly,
      );

  bool get isDeveloperOnly => evidence.contains(
        CallV2DeveloperRuntimeStartupApprovalEvidence.developerOnly,
      );

  bool get isRolloutEnabled => !evidence.contains(
        CallV2DeveloperRuntimeStartupApprovalEvidence.rolloutFalse,
      );

  bool get accessesBackendFirebase => !evidence.contains(
        CallV2DeveloperRuntimeStartupApprovalEvidence.noBackendFirebase,
      );

  bool get accessesRtcPermissions => !evidence.contains(
        CallV2DeveloperRuntimeStartupApprovalEvidence.noRtcPermissions,
      );

  bool get wiresNavigation => !evidence.contains(
        CallV2DeveloperRuntimeStartupApprovalEvidence.noNavigation,
      );

  bool get registersLifecycleObserver => !evidence.contains(
        CallV2DeveloperRuntimeStartupApprovalEvidence.noLifecycleRegistration,
      );

  bool get mutatesRouteRegistry => !evidence.contains(
        CallV2DeveloperRuntimeStartupApprovalEvidence.noRouteRegistryMutation,
      );

  bool get constructsProductionComposition => !evidence.contains(
        CallV2DeveloperRuntimeStartupApprovalEvidence
            .noProductionCompositionConstruction,
      );

  bool get startsRuntime => !evidence.contains(
        CallV2DeveloperRuntimeStartupApprovalEvidence.noRuntimeStartup,
      );

  bool get wiresStartupMainRouter => !evidence.contains(
        CallV2DeveloperRuntimeStartupApprovalEvidence.noStartupMainRouterWiring,
      );

  bool get changesPubspecPlatformConfig => !evidence.contains(
        CallV2DeveloperRuntimeStartupApprovalEvidence.noPubspecPlatformConfig,
      );

  bool get changesRulesFunctionsConfig => !evidence.contains(
        CallV2DeveloperRuntimeStartupApprovalEvidence.noRulesFunctionsConfig,
      );

  bool get isDeploymentApproved => !evidence.contains(
        CallV2DeveloperRuntimeStartupApprovalEvidence.noDeployment,
      );

  bool get protectsV1 => evidence.contains(
        CallV2DeveloperRuntimeStartupApprovalEvidence.v1Protected,
      );

  bool get allowedFutureFilesAreRuntimeStartupOwnerOnly =>
      allowedFutureFiles.length == 2 &&
      allowedFutureFiles.contains(
        'lib/call_v2/integration/call_v2_runtime_startup_owner.dart',
      ) &&
      allowedFutureFiles.contains(
        'test/call_v2/integration/call_v2_runtime_startup_owner_test.dart',
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
      forbiddenFutureFiles.contains(
        'lib/call_v2/integration/call_v2_lifecycle_observer.dart',
      ) &&
      forbiddenFutureFiles.contains(
        'lib/call_v2/integration/call_v2_navigator_owner.dart',
      ) &&
      forbiddenFutureFiles.contains(
        'lib/call_v2/production/call_v2_production_composition.dart',
      ) &&
      forbiddenFutureFiles.contains('pubspec.yaml') &&
      forbiddenFutureFiles.contains('pubspec.lock') &&
      forbiddenFutureFiles.contains('android/**') &&
      forbiddenFutureFiles.contains('ios/**') &&
      forbiddenFutureFiles.contains('firestore.rules') &&
      forbiddenFutureFiles.contains('firebase.json') &&
      forbiddenFutureFiles.contains('connect_functions/**');

  bool get rollbackPreserved =>
      rollback.contains(
        CallV2DeveloperRuntimeStartupApprovalRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2DeveloperRuntimeStartupApprovalRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2DeveloperRuntimeStartupApprovalRollback.keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2DeveloperRuntimeStartupApprovalRollback.keepDisabledOwnerInert,
      ) &&
      rollback.contains(
        CallV2DeveloperRuntimeStartupApprovalRollback.noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2DeveloperRuntimeStartupApprovalRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2DeveloperRuntimeStartupApprovalRollback.v1Unaffected,
      );

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'evidenceCount': evidence.length,
      'allowedFutureFileCount': allowedFutureFiles.length,
      'forbiddenFutureFileCount': forbiddenFutureFiles.length,
      'rollbackCount': rollback.length,
      'gateDecision': evaluatedGate.decision.name,
      'humanApproved': hasHumanApproval,
      'runtimeStartupOwnerOnly': isRuntimeStartupOwnerOnly,
      'developerOnly': isDeveloperOnly,
      'rolloutEnabled': isRolloutEnabled,
      'startsRuntime': startsRuntime,
      'constructsProductionComposition': constructsProductionComposition,
      'accessesBackend': accessesBackendFirebase,
      'accessesMediaCapabilities': accessesRtcPermissions,
      'wiresNavigation': wiresNavigation,
      'registersLifecycleObserver': registersLifecycleObserver,
      'mutatesRouteRegistry': mutatesRouteRegistry,
      'wiresStartupMainRouter': wiresStartupMainRouter,
      'changesPubspecPlatformConfig': changesPubspecPlatformConfig,
      'changesServerConfig': changesRulesFunctionsConfig,
      'deploymentApproved': isDeploymentApproved,
      'allowedFilesScoped': allowedFutureFilesAreRuntimeStartupOwnerOnly,
      'forbiddenFilesScoped': forbidsOutOfScopeFutureFiles,
      'rollbackPreserved': rollbackPreserved,
      'protectsV1': protectsV1,
    };
  }

  @override
  String toString() {
    return 'CallV2DeveloperRuntimeStartupApprovalScope'
        '(${toSafeDebugMap()})';
  }
}

final callV2DeveloperRuntimeStartupApprovalScope =
    CallV2DeveloperRuntimeStartupApprovalScope(
  preWiringGate: callV2DeveloperPreWiringSafetyGate,
  evidence: <CallV2DeveloperRuntimeStartupApprovalEvidence>[
    CallV2DeveloperRuntimeStartupApprovalEvidence.phase7SHumanApproved,
    CallV2DeveloperRuntimeStartupApprovalEvidence.runtimeStartupOwnerOnly,
    CallV2DeveloperRuntimeStartupApprovalEvidence.developerOnly,
    CallV2DeveloperRuntimeStartupApprovalEvidence.rolloutFalse,
    CallV2DeveloperRuntimeStartupApprovalEvidence.noBackendFirebase,
    CallV2DeveloperRuntimeStartupApprovalEvidence.noRtcPermissions,
    CallV2DeveloperRuntimeStartupApprovalEvidence.noNavigation,
    CallV2DeveloperRuntimeStartupApprovalEvidence.noLifecycleRegistration,
    CallV2DeveloperRuntimeStartupApprovalEvidence.noRouteRegistryMutation,
    CallV2DeveloperRuntimeStartupApprovalEvidence
        .noProductionCompositionConstruction,
    CallV2DeveloperRuntimeStartupApprovalEvidence.noRuntimeStartup,
    CallV2DeveloperRuntimeStartupApprovalEvidence.noStartupMainRouterWiring,
    CallV2DeveloperRuntimeStartupApprovalEvidence.noPubspecPlatformConfig,
    CallV2DeveloperRuntimeStartupApprovalEvidence.noRulesFunctionsConfig,
    CallV2DeveloperRuntimeStartupApprovalEvidence.noDeployment,
    CallV2DeveloperRuntimeStartupApprovalEvidence.v1Protected,
  ],
  allowedFutureFiles: <String>[
    'lib/call_v2/integration/call_v2_runtime_startup_owner.dart',
    'test/call_v2/integration/call_v2_runtime_startup_owner_test.dart',
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
    'lib/call_v2/integration/call_v2_lifecycle_observer.dart',
    'lib/call_v2/integration/call_v2_navigator_owner.dart',
    'lib/call_v2/production/call_v2_production_composition.dart',
    'pubspec.yaml',
    'pubspec.lock',
    'android/**',
    'ios/**',
    'firestore.rules',
    'firebase.json',
    'connect_functions/**',
  ],
  rollback: <CallV2DeveloperRuntimeStartupApprovalRollback>[
    CallV2DeveloperRuntimeStartupApprovalRollback.oneCommitRevert,
    CallV2DeveloperRuntimeStartupApprovalRollback.keepRolloutFalse,
    CallV2DeveloperRuntimeStartupApprovalRollback.keepRouteRegistryNull,
    CallV2DeveloperRuntimeStartupApprovalRollback.keepDisabledOwnerInert,
    CallV2DeveloperRuntimeStartupApprovalRollback.noDeploymentRequired,
    CallV2DeveloperRuntimeStartupApprovalRollback.noConfigChanges,
    CallV2DeveloperRuntimeStartupApprovalRollback.v1Unaffected,
  ],
);
