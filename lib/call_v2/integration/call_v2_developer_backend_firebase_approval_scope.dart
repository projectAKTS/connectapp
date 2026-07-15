import 'call_v2_developer_pre_wiring_safety_gate.dart';

enum CallV2DeveloperBackendFirebaseApprovalEvidence {
  phase7VHumanApproved,
  backendFirebaseOwnerOnly,
  developerOnly,
  rolloutFalse,
  noRuntimeConstruction,
  noRuntimeStartup,
  noNavigation,
  noRtcPermissions,
  noLifecycleRegistration,
  noRouteRegistryMutation,
  noFirestoreListeners,
  noFirestoreReads,
  noFirestoreWrites,
  noFirebaseAuth,
  noFirebaseFunctions,
  noFirebaseAppCheck,
  noProductionServiceContact,
  noStartupMainRouterWiring,
  noPubspecPlatformConfig,
  noRulesFunctionsConfig,
  noDeployment,
  v1Protected,
}

enum CallV2DeveloperBackendFirebaseApprovalRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2DeveloperBackendFirebaseApprovalScope {
  factory CallV2DeveloperBackendFirebaseApprovalScope({
    required CallV2DeveloperPreWiringSafetyGate preWiringGate,
    required List<CallV2DeveloperBackendFirebaseApprovalEvidence> evidence,
    required List<String> allowedFutureFiles,
    required List<String> forbiddenFutureFiles,
    required List<CallV2DeveloperBackendFirebaseApprovalRollback> rollback,
  }) {
    return CallV2DeveloperBackendFirebaseApprovalScope._(
      preWiringGate,
      List<CallV2DeveloperBackendFirebaseApprovalEvidence>.unmodifiable(
        evidence,
      ),
      List<String>.unmodifiable(allowedFutureFiles),
      List<String>.unmodifiable(forbiddenFutureFiles),
      List<CallV2DeveloperBackendFirebaseApprovalRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2DeveloperBackendFirebaseApprovalScope._(
    this.preWiringGate,
    this.evidence,
    this.allowedFutureFiles,
    this.forbiddenFutureFiles,
    this.rollback,
  );

  final CallV2DeveloperPreWiringSafetyGate preWiringGate;
  final List<CallV2DeveloperBackendFirebaseApprovalEvidence> evidence;
  final List<String> allowedFutureFiles;
  final List<String> forbiddenFutureFiles;
  final List<CallV2DeveloperBackendFirebaseApprovalRollback> rollback;

  CallV2DeveloperPreWiringSafetyGate get evaluatedGate =>
      preWiringGate.evaluateFutureScope(
        selectedScope: CallV2DeveloperPreWiringScope.backendFirebaseOwnerOnly,
        explicitFutureApproval: true,
        allowedFilesListed: true,
        oneCommitRollbackConfirmed: true,
      );

  bool get hasHumanApproval => evidence.contains(
        CallV2DeveloperBackendFirebaseApprovalEvidence.phase7VHumanApproved,
      );

  bool get isBackendFirebaseOwnerOnly => evidence.contains(
        CallV2DeveloperBackendFirebaseApprovalEvidence.backendFirebaseOwnerOnly,
      );

  bool get isDeveloperOnly => evidence.contains(
        CallV2DeveloperBackendFirebaseApprovalEvidence.developerOnly,
      );

  bool get isRolloutEnabled => !evidence.contains(
        CallV2DeveloperBackendFirebaseApprovalEvidence.rolloutFalse,
      );

  bool get constructsRuntime => !evidence.contains(
        CallV2DeveloperBackendFirebaseApprovalEvidence.noRuntimeConstruction,
      );

  bool get startsRuntime => !evidence.contains(
        CallV2DeveloperBackendFirebaseApprovalEvidence.noRuntimeStartup,
      );

  bool get wiresNavigation => !evidence.contains(
        CallV2DeveloperBackendFirebaseApprovalEvidence.noNavigation,
      );

  bool get accessesRtcPermissions => !evidence.contains(
        CallV2DeveloperBackendFirebaseApprovalEvidence.noRtcPermissions,
      );

  bool get registersLifecycleObserver => !evidence.contains(
        CallV2DeveloperBackendFirebaseApprovalEvidence.noLifecycleRegistration,
      );

  bool get mutatesRouteRegistry => !evidence.contains(
        CallV2DeveloperBackendFirebaseApprovalEvidence.noRouteRegistryMutation,
      );

  bool get opensFirestoreListeners => !evidence.contains(
        CallV2DeveloperBackendFirebaseApprovalEvidence.noFirestoreListeners,
      );

  bool get readsFirestore => !evidence.contains(
        CallV2DeveloperBackendFirebaseApprovalEvidence.noFirestoreReads,
      );

  bool get writesFirestore => !evidence.contains(
        CallV2DeveloperBackendFirebaseApprovalEvidence.noFirestoreWrites,
      );

  bool get callsFirebaseAuth => !evidence.contains(
        CallV2DeveloperBackendFirebaseApprovalEvidence.noFirebaseAuth,
      );

  bool get callsFirebaseFunctions => !evidence.contains(
        CallV2DeveloperBackendFirebaseApprovalEvidence.noFirebaseFunctions,
      );

  bool get callsFirebaseAppCheck => !evidence.contains(
        CallV2DeveloperBackendFirebaseApprovalEvidence.noFirebaseAppCheck,
      );

  bool get contactsProductionServices => !evidence.contains(
        CallV2DeveloperBackendFirebaseApprovalEvidence
            .noProductionServiceContact,
      );

  bool get wiresStartupMainRouter => !evidence.contains(
        CallV2DeveloperBackendFirebaseApprovalEvidence
            .noStartupMainRouterWiring,
      );

  bool get changesPubspecPlatformConfig => !evidence.contains(
        CallV2DeveloperBackendFirebaseApprovalEvidence.noPubspecPlatformConfig,
      );

  bool get changesRulesFunctionsConfig => !evidence.contains(
        CallV2DeveloperBackendFirebaseApprovalEvidence.noRulesFunctionsConfig,
      );

  bool get isDeploymentApproved => !evidence.contains(
        CallV2DeveloperBackendFirebaseApprovalEvidence.noDeployment,
      );

  bool get protectsV1 => evidence.contains(
        CallV2DeveloperBackendFirebaseApprovalEvidence.v1Protected,
      );

  bool get allowedFutureFilesAreBackendFirebaseOwnerOnly =>
      allowedFutureFiles.length == 2 &&
      allowedFutureFiles.contains(
        'lib/call_v2/integration/call_v2_backend_firebase_owner.dart',
      ) &&
      allowedFutureFiles.contains(
        'test/call_v2/integration/call_v2_backend_firebase_owner_test.dart',
      );

  bool get forbidsOutOfScopeFutureFiles =>
      forbiddenFutureFiles.contains('lib/main.dart') &&
      forbiddenFutureFiles.contains('lib/navigation/app_router.dart') &&
      forbiddenFutureFiles.contains('lib/call_v2/startup/**') &&
      forbiddenFutureFiles.contains('lib/call_v2/runtime/**') &&
      forbiddenFutureFiles.contains(
        'lib/call_v2/integration/call_v2_route_registry.dart',
      ) &&
      forbiddenFutureFiles.contains(
        'lib/call_v2/integration/call_v2_lifecycle_observer.dart',
      ) &&
      forbiddenFutureFiles.contains(
        'lib/call_v2/integration/call_v2_navigator_owner.dart',
      ) &&
      forbiddenFutureFiles.contains('lib/call_v2/rtc/**') &&
      forbiddenFutureFiles.contains('lib/call_v2/permissions/**') &&
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
        CallV2DeveloperBackendFirebaseApprovalRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2DeveloperBackendFirebaseApprovalRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2DeveloperBackendFirebaseApprovalRollback.keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2DeveloperBackendFirebaseApprovalRollback.keepDisabledOwnerInert,
      ) &&
      rollback.contains(
        CallV2DeveloperBackendFirebaseApprovalRollback.noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2DeveloperBackendFirebaseApprovalRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2DeveloperBackendFirebaseApprovalRollback.v1Unaffected,
      );

  bool get isStrictlyClosed =>
      hasHumanApproval &&
      isBackendFirebaseOwnerOnly &&
      isDeveloperOnly &&
      !isRolloutEnabled &&
      !constructsRuntime &&
      !startsRuntime &&
      !wiresNavigation &&
      !accessesRtcPermissions &&
      !registersLifecycleObserver &&
      !mutatesRouteRegistry &&
      !opensFirestoreListeners &&
      !readsFirestore &&
      !writesFirestore &&
      !callsFirebaseAuth &&
      !callsFirebaseFunctions &&
      !callsFirebaseAppCheck &&
      !contactsProductionServices &&
      !wiresStartupMainRouter &&
      !changesPubspecPlatformConfig &&
      !changesRulesFunctionsConfig &&
      !isDeploymentApproved &&
      protectsV1 &&
      allowedFutureFilesAreBackendFirebaseOwnerOnly &&
      forbidsOutOfScopeFutureFiles &&
      rollbackPreserved;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'evidenceCount': evidence.length,
      'allowedFutureFileCount': allowedFutureFiles.length,
      'forbiddenFutureFileCount': forbiddenFutureFiles.length,
      'rollbackCount': rollback.length,
      'gateDecision': evaluatedGate.decision.name,
      'humanApproved': hasHumanApproval,
      'ownerOnly': isBackendFirebaseOwnerOnly,
      'developerOnly': isDeveloperOnly,
      'rolloutEnabled': isRolloutEnabled,
      'constructsRuntime': constructsRuntime,
      'startsRuntime': startsRuntime,
      'wiresNavigation': wiresNavigation,
      'accessesMediaCapabilities': accessesRtcPermissions,
      'registersLifecycleObserver': registersLifecycleObserver,
      'mutatesRouteRegistry': mutatesRouteRegistry,
      'opensDocumentListeners': opensFirestoreListeners,
      'readsDocuments': readsFirestore,
      'writesDocuments': writesFirestore,
      'callsAuth': callsFirebaseAuth,
      'callsFunctions': callsFirebaseFunctions,
      'callsIntegrityCheck': callsFirebaseAppCheck,
      'contactsProductionServices': contactsProductionServices,
      'wiresStartupMainRouter': wiresStartupMainRouter,
      'changesPubspecPlatformConfig': changesPubspecPlatformConfig,
      'changesServerConfig': changesRulesFunctionsConfig,
      'deploymentApproved': isDeploymentApproved,
      'allowedFilesScoped': allowedFutureFilesAreBackendFirebaseOwnerOnly,
      'forbiddenFilesScoped': forbidsOutOfScopeFutureFiles,
      'rollbackPreserved': rollbackPreserved,
      'protectsV1': protectsV1,
      'strictlyClosed': isStrictlyClosed,
    };
  }

  @override
  String toString() {
    return 'CallV2DeveloperBackendFirebaseApprovalScope'
        '(${toSafeDebugMap()})';
  }
}

final callV2DeveloperBackendFirebaseApprovalScope =
    CallV2DeveloperBackendFirebaseApprovalScope(
  preWiringGate: callV2DeveloperPreWiringSafetyGate,
  evidence: <CallV2DeveloperBackendFirebaseApprovalEvidence>[
    CallV2DeveloperBackendFirebaseApprovalEvidence.phase7VHumanApproved,
    CallV2DeveloperBackendFirebaseApprovalEvidence.backendFirebaseOwnerOnly,
    CallV2DeveloperBackendFirebaseApprovalEvidence.developerOnly,
    CallV2DeveloperBackendFirebaseApprovalEvidence.rolloutFalse,
    CallV2DeveloperBackendFirebaseApprovalEvidence.noRuntimeConstruction,
    CallV2DeveloperBackendFirebaseApprovalEvidence.noRuntimeStartup,
    CallV2DeveloperBackendFirebaseApprovalEvidence.noNavigation,
    CallV2DeveloperBackendFirebaseApprovalEvidence.noRtcPermissions,
    CallV2DeveloperBackendFirebaseApprovalEvidence.noLifecycleRegistration,
    CallV2DeveloperBackendFirebaseApprovalEvidence.noRouteRegistryMutation,
    CallV2DeveloperBackendFirebaseApprovalEvidence.noFirestoreListeners,
    CallV2DeveloperBackendFirebaseApprovalEvidence.noFirestoreReads,
    CallV2DeveloperBackendFirebaseApprovalEvidence.noFirestoreWrites,
    CallV2DeveloperBackendFirebaseApprovalEvidence.noFirebaseAuth,
    CallV2DeveloperBackendFirebaseApprovalEvidence.noFirebaseFunctions,
    CallV2DeveloperBackendFirebaseApprovalEvidence.noFirebaseAppCheck,
    CallV2DeveloperBackendFirebaseApprovalEvidence.noProductionServiceContact,
    CallV2DeveloperBackendFirebaseApprovalEvidence.noStartupMainRouterWiring,
    CallV2DeveloperBackendFirebaseApprovalEvidence.noPubspecPlatformConfig,
    CallV2DeveloperBackendFirebaseApprovalEvidence.noRulesFunctionsConfig,
    CallV2DeveloperBackendFirebaseApprovalEvidence.noDeployment,
    CallV2DeveloperBackendFirebaseApprovalEvidence.v1Protected,
  ],
  allowedFutureFiles: <String>[
    'lib/call_v2/integration/call_v2_backend_firebase_owner.dart',
    'test/call_v2/integration/call_v2_backend_firebase_owner_test.dart',
  ],
  forbiddenFutureFiles: <String>[
    'lib/main.dart',
    'lib/navigation/app_router.dart',
    'lib/call_v2/startup/**',
    'lib/call_v2/runtime/**',
    'lib/call_v2/integration/call_v2_route_registry.dart',
    'lib/call_v2/integration/call_v2_lifecycle_observer.dart',
    'lib/call_v2/integration/call_v2_navigator_owner.dart',
    'lib/call_v2/rtc/**',
    'lib/call_v2/permissions/**',
    'lib/call_v2/production/call_v2_production_composition.dart',
    'pubspec.yaml',
    'pubspec.lock',
    'android/**',
    'ios/**',
    'firestore.rules',
    'firebase.json',
    'connect_functions/**',
  ],
  rollback: <CallV2DeveloperBackendFirebaseApprovalRollback>[
    CallV2DeveloperBackendFirebaseApprovalRollback.oneCommitRevert,
    CallV2DeveloperBackendFirebaseApprovalRollback.keepRolloutFalse,
    CallV2DeveloperBackendFirebaseApprovalRollback.keepRouteRegistryNull,
    CallV2DeveloperBackendFirebaseApprovalRollback.keepDisabledOwnerInert,
    CallV2DeveloperBackendFirebaseApprovalRollback.noDeploymentRequired,
    CallV2DeveloperBackendFirebaseApprovalRollback.noConfigChanges,
    CallV2DeveloperBackendFirebaseApprovalRollback.v1Unaffected,
  ],
);
