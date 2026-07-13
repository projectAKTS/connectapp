import 'call_v2_developer_pre_wiring_safety_gate.dart';
import 'call_v2_developer_route_registration_skeleton.dart';

enum CallV2DeveloperRouteRegistrationApprovalEvidence {
  phase7JHumanApproved,
  routeRegistrationOnly,
  developerOnly,
  rolloutFalse,
  resolverStillNullWhileFalse,
  noRuntime,
  noBackendFirebase,
  noRtcPermissions,
  noNavigator,
  noLifecycleObserver,
  noPubspecPlatformConfig,
  noRulesFunctionsConfig,
  noDeployment,
  v1Protected,
}

enum CallV2DeveloperRouteRegistrationApprovalRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2DeveloperRouteRegistrationApprovalScope {
  factory CallV2DeveloperRouteRegistrationApprovalScope({
    required CallV2DeveloperPreWiringSafetyGate preWiringGate,
    required CallV2DeveloperRouteRegistrationSkeleton routeRegistrationSkeleton,
    required List<CallV2DeveloperRouteRegistrationApprovalEvidence> evidence,
    required List<String> allowedFutureFiles,
    required List<String> forbiddenFutureFiles,
    required List<CallV2DeveloperRouteRegistrationApprovalRollback> rollback,
  }) {
    return CallV2DeveloperRouteRegistrationApprovalScope._(
      preWiringGate,
      routeRegistrationSkeleton,
      List<CallV2DeveloperRouteRegistrationApprovalEvidence>.unmodifiable(
        evidence,
      ),
      List<String>.unmodifiable(allowedFutureFiles),
      List<String>.unmodifiable(forbiddenFutureFiles),
      List<CallV2DeveloperRouteRegistrationApprovalRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2DeveloperRouteRegistrationApprovalScope._(
    this.preWiringGate,
    this.routeRegistrationSkeleton,
    this.evidence,
    this.allowedFutureFiles,
    this.forbiddenFutureFiles,
    this.rollback,
  );

  final CallV2DeveloperPreWiringSafetyGate preWiringGate;
  final CallV2DeveloperRouteRegistrationSkeleton routeRegistrationSkeleton;
  final List<CallV2DeveloperRouteRegistrationApprovalEvidence> evidence;
  final List<String> allowedFutureFiles;
  final List<String> forbiddenFutureFiles;
  final List<CallV2DeveloperRouteRegistrationApprovalRollback> rollback;

  CallV2DeveloperPreWiringSafetyGate get evaluatedGate =>
      preWiringGate.evaluateFutureScope(
        selectedScope: CallV2DeveloperPreWiringScope.routeRegistrationOnly,
        explicitFutureApproval: true,
        allowedFilesListed: true,
        oneCommitRollbackConfirmed: true,
      );

  bool get hasHumanApproval => evidence.contains(
        CallV2DeveloperRouteRegistrationApprovalEvidence.phase7JHumanApproved,
      );

  bool get isRouteRegistrationOnly => evidence.contains(
        CallV2DeveloperRouteRegistrationApprovalEvidence.routeRegistrationOnly,
      );

  bool get isDeveloperOnly => evidence.contains(
        CallV2DeveloperRouteRegistrationApprovalEvidence.developerOnly,
      );

  bool get isRolloutEnabled => !evidence.contains(
        CallV2DeveloperRouteRegistrationApprovalEvidence.rolloutFalse,
      );

  bool get resolverStillNullWhileFalse => evidence.contains(
        CallV2DeveloperRouteRegistrationApprovalEvidence
            .resolverStillNullWhileFalse,
      );

  bool get startsRuntime => !evidence.contains(
        CallV2DeveloperRouteRegistrationApprovalEvidence.noRuntime,
      );

  bool get accessesBackendFirebase => !evidence.contains(
        CallV2DeveloperRouteRegistrationApprovalEvidence.noBackendFirebase,
      );

  bool get accessesRtcPermissions => !evidence.contains(
        CallV2DeveloperRouteRegistrationApprovalEvidence.noRtcPermissions,
      );

  bool get wiresNavigator => !evidence.contains(
        CallV2DeveloperRouteRegistrationApprovalEvidence.noNavigator,
      );

  bool get registersLifecycleObserver => !evidence.contains(
        CallV2DeveloperRouteRegistrationApprovalEvidence.noLifecycleObserver,
      );

  bool get changesPubspecPlatformConfig => !evidence.contains(
        CallV2DeveloperRouteRegistrationApprovalEvidence
            .noPubspecPlatformConfig,
      );

  bool get changesRulesFunctionsConfig => !evidence.contains(
        CallV2DeveloperRouteRegistrationApprovalEvidence.noRulesFunctionsConfig,
      );

  bool get isDeploymentApproved => !evidence.contains(
        CallV2DeveloperRouteRegistrationApprovalEvidence.noDeployment,
      );

  bool get protectsV1 => evidence.contains(
        CallV2DeveloperRouteRegistrationApprovalEvidence.v1Protected,
      );

  bool get allowedFutureFilesAreRouteRegistrationOnly =>
      allowedFutureFiles.length == 2 &&
      allowedFutureFiles.contains(
        'lib/call_v2/integration/call_v2_route_registry.dart',
      ) &&
      allowedFutureFiles.contains(
        'test/call_v2/integration/call_v2_route_registry_test.dart',
      );

  bool get forbidsOutOfScopeFutureFiles =>
      forbiddenFutureFiles.contains('lib/main.dart') &&
      forbiddenFutureFiles.contains('lib/navigation/app_router.dart') &&
      forbiddenFutureFiles.contains('lib/call_v2/startup/**') &&
      forbiddenFutureFiles.contains('lib/call_v2/runtime/**') &&
      forbiddenFutureFiles.contains('lib/call_v2/firebase/**') &&
      forbiddenFutureFiles.contains('lib/call_v2/rtc/**') &&
      forbiddenFutureFiles.contains('lib/call_v2/permissions/**') &&
      forbiddenFutureFiles.contains('pubspec.yaml') &&
      forbiddenFutureFiles.contains('pubspec.lock') &&
      forbiddenFutureFiles.contains('android/**') &&
      forbiddenFutureFiles.contains('ios/**') &&
      forbiddenFutureFiles.contains('firestore.rules') &&
      forbiddenFutureFiles.contains('firebase.json') &&
      forbiddenFutureFiles.contains('connect_functions/**');

  bool get rollbackPreserved =>
      rollback.contains(
        CallV2DeveloperRouteRegistrationApprovalRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2DeveloperRouteRegistrationApprovalRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2DeveloperRouteRegistrationApprovalRollback.keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2DeveloperRouteRegistrationApprovalRollback.keepDisabledOwnerInert,
      ) &&
      rollback.contains(
        CallV2DeveloperRouteRegistrationApprovalRollback.noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2DeveloperRouteRegistrationApprovalRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2DeveloperRouteRegistrationApprovalRollback.v1Unaffected,
      );

  bool get createsRouteObject => false;
  bool get createsScreen => false;
  bool get usesRouteSink => false;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'evidenceCount': evidence.length,
      'allowedFutureFileCount': allowedFutureFiles.length,
      'forbiddenFutureFileCount': forbiddenFutureFiles.length,
      'rollbackCount': rollback.length,
      'gateDecision': evaluatedGate.decision.name,
      'humanApproved': hasHumanApproval,
      'routeRegistrationOnly': isRouteRegistrationOnly,
      'developerOnly': isDeveloperOnly,
      'rolloutEnabled': isRolloutEnabled,
      'resolverStillNullWhileFalse': resolverStillNullWhileFalse,
      'startsRuntime': startsRuntime,
      'accessesBackend': accessesBackendFirebase,
      'accessesMediaCapabilities': accessesRtcPermissions,
      'wiresNavigator': wiresNavigator,
      'registersLifecycleObserver': registersLifecycleObserver,
      'changesPubspecPlatformConfig': changesPubspecPlatformConfig,
      'changesServerConfig': changesRulesFunctionsConfig,
      'deploymentApproved': isDeploymentApproved,
      'allowedFilesScoped': allowedFutureFilesAreRouteRegistrationOnly,
      'forbiddenFilesScoped': forbidsOutOfScopeFutureFiles,
      'rollbackPreserved': rollbackPreserved,
      'protectsV1': protectsV1,
      'createsRouteObject': createsRouteObject,
      'createsScreen': createsScreen,
      'usesRouteSink': usesRouteSink,
    };
  }

  @override
  String toString() {
    return 'CallV2DeveloperRouteRegistrationApprovalScope'
        '(${toSafeDebugMap()})';
  }
}

final callV2DeveloperRouteRegistrationApprovalScope =
    CallV2DeveloperRouteRegistrationApprovalScope(
  preWiringGate: callV2DeveloperPreWiringSafetyGate,
  routeRegistrationSkeleton: callV2DeveloperRouteRegistrationSkeleton,
  evidence: <CallV2DeveloperRouteRegistrationApprovalEvidence>[
    CallV2DeveloperRouteRegistrationApprovalEvidence.phase7JHumanApproved,
    CallV2DeveloperRouteRegistrationApprovalEvidence.routeRegistrationOnly,
    CallV2DeveloperRouteRegistrationApprovalEvidence.developerOnly,
    CallV2DeveloperRouteRegistrationApprovalEvidence.rolloutFalse,
    CallV2DeveloperRouteRegistrationApprovalEvidence
        .resolverStillNullWhileFalse,
    CallV2DeveloperRouteRegistrationApprovalEvidence.noRuntime,
    CallV2DeveloperRouteRegistrationApprovalEvidence.noBackendFirebase,
    CallV2DeveloperRouteRegistrationApprovalEvidence.noRtcPermissions,
    CallV2DeveloperRouteRegistrationApprovalEvidence.noNavigator,
    CallV2DeveloperRouteRegistrationApprovalEvidence.noLifecycleObserver,
    CallV2DeveloperRouteRegistrationApprovalEvidence.noPubspecPlatformConfig,
    CallV2DeveloperRouteRegistrationApprovalEvidence.noRulesFunctionsConfig,
    CallV2DeveloperRouteRegistrationApprovalEvidence.noDeployment,
    CallV2DeveloperRouteRegistrationApprovalEvidence.v1Protected,
  ],
  allowedFutureFiles: <String>[
    'lib/call_v2/integration/call_v2_route_registry.dart',
    'test/call_v2/integration/call_v2_route_registry_test.dart',
  ],
  forbiddenFutureFiles: <String>[
    'lib/main.dart',
    'lib/navigation/app_router.dart',
    'lib/call_v2/startup/**',
    'lib/call_v2/runtime/**',
    'lib/call_v2/firebase/**',
    'lib/call_v2/rtc/**',
    'lib/call_v2/permissions/**',
    'pubspec.yaml',
    'pubspec.lock',
    'android/**',
    'ios/**',
    'firestore.rules',
    'firebase.json',
    'connect_functions/**',
  ],
  rollback: <CallV2DeveloperRouteRegistrationApprovalRollback>[
    CallV2DeveloperRouteRegistrationApprovalRollback.oneCommitRevert,
    CallV2DeveloperRouteRegistrationApprovalRollback.keepRolloutFalse,
    CallV2DeveloperRouteRegistrationApprovalRollback.keepRouteRegistryNull,
    CallV2DeveloperRouteRegistrationApprovalRollback.keepDisabledOwnerInert,
    CallV2DeveloperRouteRegistrationApprovalRollback.noDeploymentRequired,
    CallV2DeveloperRouteRegistrationApprovalRollback.noConfigChanges,
    CallV2DeveloperRouteRegistrationApprovalRollback.v1Unaffected,
  ],
);
