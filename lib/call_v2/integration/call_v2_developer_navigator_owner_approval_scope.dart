import 'call_v2_developer_pre_wiring_safety_gate.dart';

enum CallV2DeveloperNavigationOwnerApprovalEvidence {
  phase7PHumanApproved,
  navigationOwnerOnly,
  developerOnly,
  rolloutFalse,
  noRuntime,
  noBackendFirebase,
  noRtcPermissions,
  noLifecycleRegistration,
  noRouteRegistryMutation,
  noRealNavigationWiring,
  noAppNavigationKey,
  noGlobalAppKey,
  noWidgetContextStorage,
  noMaterialRouteTableWiring,
  noStartupMainRouterWiring,
  noPubspecPlatformConfig,
  noRulesFunctionsConfig,
  noDeployment,
  v1Protected,
}

enum CallV2DeveloperNavigationOwnerApprovalRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2DeveloperNavigationOwnerApprovalScope {
  factory CallV2DeveloperNavigationOwnerApprovalScope({
    required CallV2DeveloperPreWiringSafetyGate preWiringGate,
    required List<CallV2DeveloperNavigationOwnerApprovalEvidence> evidence,
    required List<String> allowedFutureFiles,
    required List<String> forbiddenFutureFiles,
    required List<CallV2DeveloperNavigationOwnerApprovalRollback> rollback,
  }) {
    return CallV2DeveloperNavigationOwnerApprovalScope._(
      preWiringGate,
      List<CallV2DeveloperNavigationOwnerApprovalEvidence>.unmodifiable(
        evidence,
      ),
      List<String>.unmodifiable(allowedFutureFiles),
      List<String>.unmodifiable(forbiddenFutureFiles),
      List<CallV2DeveloperNavigationOwnerApprovalRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2DeveloperNavigationOwnerApprovalScope._(
    this.preWiringGate,
    this.evidence,
    this.allowedFutureFiles,
    this.forbiddenFutureFiles,
    this.rollback,
  );

  final CallV2DeveloperPreWiringSafetyGate preWiringGate;
  final List<CallV2DeveloperNavigationOwnerApprovalEvidence> evidence;
  final List<String> allowedFutureFiles;
  final List<String> forbiddenFutureFiles;
  final List<CallV2DeveloperNavigationOwnerApprovalRollback> rollback;

  CallV2DeveloperPreWiringSafetyGate get evaluatedGate =>
      preWiringGate.evaluateFutureScope(
        selectedScope: CallV2DeveloperPreWiringScope.navigatorOwnerOnly,
        explicitFutureApproval: true,
        allowedFilesListed: true,
        oneCommitRollbackConfirmed: true,
      );

  bool get hasHumanApproval => evidence.contains(
        CallV2DeveloperNavigationOwnerApprovalEvidence.phase7PHumanApproved,
      );

  bool get isNavigationOwnerOnly => evidence.contains(
        CallV2DeveloperNavigationOwnerApprovalEvidence.navigationOwnerOnly,
      );

  bool get isDeveloperOnly => evidence.contains(
        CallV2DeveloperNavigationOwnerApprovalEvidence.developerOnly,
      );

  bool get isRolloutEnabled => !evidence.contains(
        CallV2DeveloperNavigationOwnerApprovalEvidence.rolloutFalse,
      );

  bool get startsRuntime => !evidence.contains(
        CallV2DeveloperNavigationOwnerApprovalEvidence.noRuntime,
      );

  bool get accessesBackendFirebase => !evidence.contains(
        CallV2DeveloperNavigationOwnerApprovalEvidence.noBackendFirebase,
      );

  bool get accessesRtcPermissions => !evidence.contains(
        CallV2DeveloperNavigationOwnerApprovalEvidence.noRtcPermissions,
      );

  bool get registersLifecycleObserver => !evidence.contains(
        CallV2DeveloperNavigationOwnerApprovalEvidence.noLifecycleRegistration,
      );

  bool get mutatesRouteRegistry => !evidence.contains(
        CallV2DeveloperNavigationOwnerApprovalEvidence.noRouteRegistryMutation,
      );

  bool get wiresRealNavigation => !evidence.contains(
        CallV2DeveloperNavigationOwnerApprovalEvidence.noRealNavigationWiring,
      );

  bool get usesAppNavigationKey => !evidence.contains(
        CallV2DeveloperNavigationOwnerApprovalEvidence.noAppNavigationKey,
      );

  bool get usesGlobalAppKey => !evidence.contains(
        CallV2DeveloperNavigationOwnerApprovalEvidence.noGlobalAppKey,
      );

  bool get storesWidgetContext => !evidence.contains(
        CallV2DeveloperNavigationOwnerApprovalEvidence.noWidgetContextStorage,
      );

  bool get wiresMaterialRouteTable => !evidence.contains(
        CallV2DeveloperNavigationOwnerApprovalEvidence
            .noMaterialRouteTableWiring,
      );

  bool get wiresStartupMainRouter => !evidence.contains(
        CallV2DeveloperNavigationOwnerApprovalEvidence
            .noStartupMainRouterWiring,
      );

  bool get changesPubspecPlatformConfig => !evidence.contains(
        CallV2DeveloperNavigationOwnerApprovalEvidence.noPubspecPlatformConfig,
      );

  bool get changesRulesFunctionsConfig => !evidence.contains(
        CallV2DeveloperNavigationOwnerApprovalEvidence.noRulesFunctionsConfig,
      );

  bool get isDeploymentApproved => !evidence.contains(
        CallV2DeveloperNavigationOwnerApprovalEvidence.noDeployment,
      );

  bool get protectsV1 => evidence.contains(
        CallV2DeveloperNavigationOwnerApprovalEvidence.v1Protected,
      );

  bool get allowedFutureFilesAreNavigationOwnerOnly =>
      allowedFutureFiles.length == 2 &&
      allowedFutureFiles.contains(
        'lib/call_v2/integration/call_v2_navigator_owner.dart',
      ) &&
      allowedFutureFiles.contains(
        'test/call_v2/integration/call_v2_navigator_owner_test.dart',
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
        'lib/call_v2/integration/call_v2_lifecycle_observer_hardening_audit.dart',
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
        CallV2DeveloperNavigationOwnerApprovalRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2DeveloperNavigationOwnerApprovalRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2DeveloperNavigationOwnerApprovalRollback.keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2DeveloperNavigationOwnerApprovalRollback.keepDisabledOwnerInert,
      ) &&
      rollback.contains(
        CallV2DeveloperNavigationOwnerApprovalRollback.noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2DeveloperNavigationOwnerApprovalRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2DeveloperNavigationOwnerApprovalRollback.v1Unaffected,
      );

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'evidenceCount': evidence.length,
      'allowedFutureFileCount': allowedFutureFiles.length,
      'forbiddenFutureFileCount': forbiddenFutureFiles.length,
      'rollbackCount': rollback.length,
      'gateDecision': evaluatedGate.decision.name,
      'humanApproved': hasHumanApproval,
      'navigationOwnerOnly': isNavigationOwnerOnly,
      'developerOnly': isDeveloperOnly,
      'rolloutEnabled': isRolloutEnabled,
      'startsRuntime': startsRuntime,
      'accessesBackend': accessesBackendFirebase,
      'accessesMediaCapabilities': accessesRtcPermissions,
      'registersLifecycleObserver': registersLifecycleObserver,
      'mutatesRouteRegistry': mutatesRouteRegistry,
      'wiresRealNavigation': wiresRealNavigation,
      'usesAppNavigationKey': usesAppNavigationKey,
      'usesGlobalAppKey': usesGlobalAppKey,
      'storesWidgetContext': storesWidgetContext,
      'wiresMaterialRouteTable': wiresMaterialRouteTable,
      'wiresStartupMainRouter': wiresStartupMainRouter,
      'changesPubspecPlatformConfig': changesPubspecPlatformConfig,
      'changesServerConfig': changesRulesFunctionsConfig,
      'deploymentApproved': isDeploymentApproved,
      'allowedFilesScoped': allowedFutureFilesAreNavigationOwnerOnly,
      'forbiddenFilesScoped': forbidsOutOfScopeFutureFiles,
      'rollbackPreserved': rollbackPreserved,
      'protectsV1': protectsV1,
    };
  }

  @override
  String toString() {
    return 'CallV2DeveloperNavigationOwnerApprovalScope'
        '(${toSafeDebugMap()})';
  }
}

final callV2DeveloperNavigationOwnerApprovalScope =
    CallV2DeveloperNavigationOwnerApprovalScope(
  preWiringGate: callV2DeveloperPreWiringSafetyGate,
  evidence: <CallV2DeveloperNavigationOwnerApprovalEvidence>[
    CallV2DeveloperNavigationOwnerApprovalEvidence.phase7PHumanApproved,
    CallV2DeveloperNavigationOwnerApprovalEvidence.navigationOwnerOnly,
    CallV2DeveloperNavigationOwnerApprovalEvidence.developerOnly,
    CallV2DeveloperNavigationOwnerApprovalEvidence.rolloutFalse,
    CallV2DeveloperNavigationOwnerApprovalEvidence.noRuntime,
    CallV2DeveloperNavigationOwnerApprovalEvidence.noBackendFirebase,
    CallV2DeveloperNavigationOwnerApprovalEvidence.noRtcPermissions,
    CallV2DeveloperNavigationOwnerApprovalEvidence.noLifecycleRegistration,
    CallV2DeveloperNavigationOwnerApprovalEvidence.noRouteRegistryMutation,
    CallV2DeveloperNavigationOwnerApprovalEvidence.noRealNavigationWiring,
    CallV2DeveloperNavigationOwnerApprovalEvidence.noAppNavigationKey,
    CallV2DeveloperNavigationOwnerApprovalEvidence.noGlobalAppKey,
    CallV2DeveloperNavigationOwnerApprovalEvidence.noWidgetContextStorage,
    CallV2DeveloperNavigationOwnerApprovalEvidence.noMaterialRouteTableWiring,
    CallV2DeveloperNavigationOwnerApprovalEvidence.noStartupMainRouterWiring,
    CallV2DeveloperNavigationOwnerApprovalEvidence.noPubspecPlatformConfig,
    CallV2DeveloperNavigationOwnerApprovalEvidence.noRulesFunctionsConfig,
    CallV2DeveloperNavigationOwnerApprovalEvidence.noDeployment,
    CallV2DeveloperNavigationOwnerApprovalEvidence.v1Protected,
  ],
  allowedFutureFiles: <String>[
    'lib/call_v2/integration/call_v2_navigator_owner.dart',
    'test/call_v2/integration/call_v2_navigator_owner_test.dart',
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
    'lib/call_v2/integration/call_v2_lifecycle_observer_hardening_audit.dart',
    'pubspec.yaml',
    'pubspec.lock',
    'android/**',
    'ios/**',
    'firestore.rules',
    'firebase.json',
    'connect_functions/**',
  ],
  rollback: <CallV2DeveloperNavigationOwnerApprovalRollback>[
    CallV2DeveloperNavigationOwnerApprovalRollback.oneCommitRevert,
    CallV2DeveloperNavigationOwnerApprovalRollback.keepRolloutFalse,
    CallV2DeveloperNavigationOwnerApprovalRollback.keepRouteRegistryNull,
    CallV2DeveloperNavigationOwnerApprovalRollback.keepDisabledOwnerInert,
    CallV2DeveloperNavigationOwnerApprovalRollback.noDeploymentRequired,
    CallV2DeveloperNavigationOwnerApprovalRollback.noConfigChanges,
    CallV2DeveloperNavigationOwnerApprovalRollback.v1Unaffected,
  ],
);
