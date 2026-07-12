enum CallV2ProductionBackendFirebaseStatus {
  noRealBackendFirebaseIntegrationImplemented,
  noFirestoreListenersOpened,
  noAuthProviderCalls,
  noCallableBackendCalls,
  noFirestoreReads,
  noFirestoreWrites,
  noSecurityRulesModified,
  noFunctionsModified,
  runtimeNotStarted,
  rolloutFalse,
  callV2Unreachable,
  deploymentNotAuthorized,
}

enum CallV2ProductionBackendFirebaseAllowedLocation {
  isolatedCallV2BackendFirebaseOwner,
  isolatedProductionIntegrationOwnerOnlyIfApproved,
  developerOnlyBackendFirebasePrOnly,
}

enum CallV2ProductionBackendFirebaseForbiddenLocation {
  mainDart,
  appStartup,
  appRouter,
  routeRegistry,
  v1Files,
}

enum CallV2ProductionBackendFirebaseForbiddenAction {
  modifyMainDart,
  modifyAppStartup,
  modifyAppRouter,
  modifyRouteRegistry,
  changeRolloutFlag,
  openFirestoreListeners,
  readFirestore,
  writeFirestore,
  callAuthProvider,
  callCallableBackend,
  modifyConnectFunctions,
  modifyFirestoreRules,
  modifyFirebaseJson,
  deployRulesOrFunctions,
  startRuntime,
  startRtc,
  requestPermissions,
  addRouteOrNavigatorWiring,
}

enum CallV2ProductionBackendDataSafetyRule {
  sanitizeBackendSnapshotsBeforeBridgeRuntimeUi,
  noRawFirestoreSnapshotStored,
  noRawAuthUserStored,
  noRawCallableResultStored,
  noIdsTokensChannelsCredentialsInLogsDebugUiRoutes,
  noRawBackendPayloadInErrors,
  noRawExceptionStackExposure,
  noRouteArguments,
  noCredentialRefreshWithoutSeparateApproval,
  safeEnumBooleanGenerationModelsOnly,
}

enum CallV2ProductionBackendListenerSafetyRule {
  noListenerBeforeExplicitStartupApproval,
  noListenerWhileRolloutFalse,
  listenerOwnerDisposable,
  duplicateListenersRejectedOrNoOp,
  staleGenerationIgnored,
  terminalStateUnsubscribes,
  signOutUnsubscribes,
  authInvalidUnsubscribes,
  backgroundLifecycleCleanupDoesNotStartListeners,
  listenersCoveredByRollback,
}

enum CallV2ProductionBackendFirebaseGate {
  authGateApproved,
  firestoreRulesReviewed,
  emulatorRulesTestsPassed,
  functionsDeploymentValidationPassed,
  appCheckBehaviorReviewed,
  noDebugTokenLeakage,
  leastPrivilegeReadWriteShapeReviewed,
  backendIndexesReviewedIfNeeded,
  explicitHumanApprovalRequired,
  developerOnlyAllowlistRequired,
}

enum CallV2ProductionBackendCallStateConsistencyRule {
  staleSnapshotIgnored,
  duplicateSnapshotNoOp,
  outOfOrderStateRejectedOrNoOp,
  ownershipMismatchRejected,
  terminalMismatchControlledClose,
  credentialExpiryControlledFailureNoRefreshUnlessApproved,
  remoteDisconnectReconnectSanitized,
  backendTimeoutMapsToControlledFailure,
}

enum CallV2ProductionBackendFirebaseRollback {
  oneCommit,
  removeBackendFirebaseOwnerWiring,
  removeListeners,
  rolloutFalse,
  runtimeRemainsNotStarted,
  routeRegistryDisabledNull,
  noDeploymentWithoutApproval,
  backupBranchProtected,
}

enum CallV2ProductionBackendFirebaseV1Protection {
  noV1DataModelChanges,
  noV1RouteBehaviorChanges,
  noV1ChatBehaviorChanges,
  noV1CallBehaviorChanges,
  noExistingFirestoreRulesRegression,
  v1SmokeBeforeAndAfterBackendWiring,
  immediateRollbackOnV1Regression,
}

enum CallV2ProductionBackendFirebaseTestRequirement {
  phase6YTests,
  phase6XTests,
  phase6WTests,
  phase6VTests,
  phase6UTests,
  allCallV2DesignTests,
  allCallV2IntegrationTests,
  allCallV2UiTests,
  preIntegrationVerification,
  productionCompositionTests,
  finalReadinessTests,
  allCallV2FlutterTests,
  backendCheck,
  deploymentValidation,
  firestoreRulesTests,
  emulatorTests,
  fullFlutterAnalyze,
  diffCheck,
}

final class CallV2ProductionBackendFirebaseDesign {
  factory CallV2ProductionBackendFirebaseDesign({
    required String protectedBackupBranch,
    required String protectedBackupSha,
    required List<CallV2ProductionBackendFirebaseStatus> currentStatus,
    required List<CallV2ProductionBackendFirebaseAllowedLocation>
        allowedFutureLocations,
    required List<CallV2ProductionBackendFirebaseForbiddenLocation>
        forbiddenLocations,
    required List<CallV2ProductionBackendFirebaseForbiddenAction>
        forbiddenActions,
    required List<CallV2ProductionBackendDataSafetyRule> dataSafetyRules,
    required List<CallV2ProductionBackendListenerSafetyRule>
        listenerSafetyRules,
    required List<CallV2ProductionBackendFirebaseGate> gates,
    required List<CallV2ProductionBackendCallStateConsistencyRule>
        callStateConsistencyRules,
    required List<CallV2ProductionBackendFirebaseRollback> rollbackControls,
    required List<CallV2ProductionBackendFirebaseV1Protection> v1Protections,
    required List<CallV2ProductionBackendFirebaseTestRequirement>
        testRequirements,
  }) {
    return CallV2ProductionBackendFirebaseDesign._(
      protectedBackupBranch,
      protectedBackupSha,
      List<CallV2ProductionBackendFirebaseStatus>.unmodifiable(currentStatus),
      List<CallV2ProductionBackendFirebaseAllowedLocation>.unmodifiable(
        allowedFutureLocations,
      ),
      List<CallV2ProductionBackendFirebaseForbiddenLocation>.unmodifiable(
        forbiddenLocations,
      ),
      List<CallV2ProductionBackendFirebaseForbiddenAction>.unmodifiable(
        forbiddenActions,
      ),
      List<CallV2ProductionBackendDataSafetyRule>.unmodifiable(
        dataSafetyRules,
      ),
      List<CallV2ProductionBackendListenerSafetyRule>.unmodifiable(
        listenerSafetyRules,
      ),
      List<CallV2ProductionBackendFirebaseGate>.unmodifiable(gates),
      List<CallV2ProductionBackendCallStateConsistencyRule>.unmodifiable(
        callStateConsistencyRules,
      ),
      List<CallV2ProductionBackendFirebaseRollback>.unmodifiable(
        rollbackControls,
      ),
      List<CallV2ProductionBackendFirebaseV1Protection>.unmodifiable(
        v1Protections,
      ),
      List<CallV2ProductionBackendFirebaseTestRequirement>.unmodifiable(
        testRequirements,
      ),
    );
  }

  const CallV2ProductionBackendFirebaseDesign._(
    this.protectedBackupBranch,
    this.protectedBackupSha,
    this.currentStatus,
    this.allowedFutureLocations,
    this.forbiddenLocations,
    this.forbiddenActions,
    this.dataSafetyRules,
    this.listenerSafetyRules,
    this.gates,
    this.callStateConsistencyRules,
    this.rollbackControls,
    this.v1Protections,
    this.testRequirements,
  );

  final String protectedBackupBranch;
  final String protectedBackupSha;
  final List<CallV2ProductionBackendFirebaseStatus> currentStatus;
  final List<CallV2ProductionBackendFirebaseAllowedLocation>
      allowedFutureLocations;
  final List<CallV2ProductionBackendFirebaseForbiddenLocation>
      forbiddenLocations;
  final List<CallV2ProductionBackendFirebaseForbiddenAction> forbiddenActions;
  final List<CallV2ProductionBackendDataSafetyRule> dataSafetyRules;
  final List<CallV2ProductionBackendListenerSafetyRule> listenerSafetyRules;
  final List<CallV2ProductionBackendFirebaseGate> gates;
  final List<CallV2ProductionBackendCallStateConsistencyRule>
      callStateConsistencyRules;
  final List<CallV2ProductionBackendFirebaseRollback> rollbackControls;
  final List<CallV2ProductionBackendFirebaseV1Protection> v1Protections;
  final List<CallV2ProductionBackendFirebaseTestRequirement> testRequirements;

  bool get isBackendFirebaseIntegrationImplemented => !currentStatus.contains(
        CallV2ProductionBackendFirebaseStatus
            .noRealBackendFirebaseIntegrationImplemented,
      );

  bool get hasOpenFirestoreListeners => !currentStatus.contains(
        CallV2ProductionBackendFirebaseStatus.noFirestoreListenersOpened,
      );

  bool get hasAuthProviderCalls => !currentStatus.contains(
        CallV2ProductionBackendFirebaseStatus.noAuthProviderCalls,
      );

  bool get hasCallableBackendCalls => !currentStatus.contains(
        CallV2ProductionBackendFirebaseStatus.noCallableBackendCalls,
      );

  bool get hasFirestoreReadsOrWrites =>
      !currentStatus.contains(
        CallV2ProductionBackendFirebaseStatus.noFirestoreReads,
      ) ||
      !currentStatus.contains(
        CallV2ProductionBackendFirebaseStatus.noFirestoreWrites,
      );

  bool get isRuntimeStarted => !currentStatus.contains(
        CallV2ProductionBackendFirebaseStatus.runtimeNotStarted,
      );

  bool get isRolloutEnabled => !currentStatus.contains(
        CallV2ProductionBackendFirebaseStatus.rolloutFalse,
      );

  bool get isCallV2Reachable => !currentStatus.contains(
        CallV2ProductionBackendFirebaseStatus.callV2Unreachable,
      );

  bool get isDeploymentAuthorized => !currentStatus.contains(
        CallV2ProductionBackendFirebaseStatus.deploymentNotAuthorized,
      );

  bool get allowsAutomaticWiring => !gates.contains(
        CallV2ProductionBackendFirebaseGate.explicitHumanApprovalRequired,
      );

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'currentStatusCount': currentStatus.length,
      'allowedFutureLocationCount': allowedFutureLocations.length,
      'forbiddenLocationCount': forbiddenLocations.length,
      'forbiddenActionCount': forbiddenActions.length,
      'dataSafetyRuleCount': dataSafetyRules.length,
      'listenerSafetyRuleCount': listenerSafetyRules.length,
      'gateCount': gates.length,
      'callStateConsistencyRuleCount': callStateConsistencyRules.length,
      'rollbackControlCount': rollbackControls.length,
      'v1ProtectionCount': v1Protections.length,
      'testRequirementCount': testRequirements.length,
      'backendFirebaseIntegrationImplemented':
          isBackendFirebaseIntegrationImplemented,
      'openFirestoreListeners': hasOpenFirestoreListeners,
      'authProviderCalls': hasAuthProviderCalls,
      'callableBackendCalls': hasCallableBackendCalls,
      'firestoreReadsOrWrites': hasFirestoreReadsOrWrites,
      'runtimeStarted': isRuntimeStarted,
      'rolloutEnabled': isRolloutEnabled,
      'callV2Reachable': isCallV2Reachable,
      'deploymentAuthorized': isDeploymentAuthorized,
      'allowsAutomaticWiring': allowsAutomaticWiring,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionBackendFirebaseDesign(${toSafeDebugMap()})';
  }
}

final callV2ProductionBackendFirebaseDesign =
    CallV2ProductionBackendFirebaseDesign(
  protectedBackupBranch: 'backup/call-v2-pre-phase6b-2026-07-04',
  protectedBackupSha: '2a1ea8d6864ab0098d17c52bdf5ec70f66979e4d',
  currentStatus: <CallV2ProductionBackendFirebaseStatus>[
    CallV2ProductionBackendFirebaseStatus
        .noRealBackendFirebaseIntegrationImplemented,
    CallV2ProductionBackendFirebaseStatus.noFirestoreListenersOpened,
    CallV2ProductionBackendFirebaseStatus.noAuthProviderCalls,
    CallV2ProductionBackendFirebaseStatus.noCallableBackendCalls,
    CallV2ProductionBackendFirebaseStatus.noFirestoreReads,
    CallV2ProductionBackendFirebaseStatus.noFirestoreWrites,
    CallV2ProductionBackendFirebaseStatus.noSecurityRulesModified,
    CallV2ProductionBackendFirebaseStatus.noFunctionsModified,
    CallV2ProductionBackendFirebaseStatus.runtimeNotStarted,
    CallV2ProductionBackendFirebaseStatus.rolloutFalse,
    CallV2ProductionBackendFirebaseStatus.callV2Unreachable,
    CallV2ProductionBackendFirebaseStatus.deploymentNotAuthorized,
  ],
  allowedFutureLocations: <CallV2ProductionBackendFirebaseAllowedLocation>[
    CallV2ProductionBackendFirebaseAllowedLocation
        .isolatedCallV2BackendFirebaseOwner,
    CallV2ProductionBackendFirebaseAllowedLocation
        .isolatedProductionIntegrationOwnerOnlyIfApproved,
    CallV2ProductionBackendFirebaseAllowedLocation
        .developerOnlyBackendFirebasePrOnly,
  ],
  forbiddenLocations: <CallV2ProductionBackendFirebaseForbiddenLocation>[
    CallV2ProductionBackendFirebaseForbiddenLocation.mainDart,
    CallV2ProductionBackendFirebaseForbiddenLocation.appStartup,
    CallV2ProductionBackendFirebaseForbiddenLocation.appRouter,
    CallV2ProductionBackendFirebaseForbiddenLocation.routeRegistry,
    CallV2ProductionBackendFirebaseForbiddenLocation.v1Files,
  ],
  forbiddenActions: <CallV2ProductionBackendFirebaseForbiddenAction>[
    CallV2ProductionBackendFirebaseForbiddenAction.modifyMainDart,
    CallV2ProductionBackendFirebaseForbiddenAction.modifyAppStartup,
    CallV2ProductionBackendFirebaseForbiddenAction.modifyAppRouter,
    CallV2ProductionBackendFirebaseForbiddenAction.modifyRouteRegistry,
    CallV2ProductionBackendFirebaseForbiddenAction.changeRolloutFlag,
    CallV2ProductionBackendFirebaseForbiddenAction.openFirestoreListeners,
    CallV2ProductionBackendFirebaseForbiddenAction.readFirestore,
    CallV2ProductionBackendFirebaseForbiddenAction.writeFirestore,
    CallV2ProductionBackendFirebaseForbiddenAction.callAuthProvider,
    CallV2ProductionBackendFirebaseForbiddenAction.callCallableBackend,
    CallV2ProductionBackendFirebaseForbiddenAction.modifyConnectFunctions,
    CallV2ProductionBackendFirebaseForbiddenAction.modifyFirestoreRules,
    CallV2ProductionBackendFirebaseForbiddenAction.modifyFirebaseJson,
    CallV2ProductionBackendFirebaseForbiddenAction.deployRulesOrFunctions,
    CallV2ProductionBackendFirebaseForbiddenAction.startRuntime,
    CallV2ProductionBackendFirebaseForbiddenAction.startRtc,
    CallV2ProductionBackendFirebaseForbiddenAction.requestPermissions,
    CallV2ProductionBackendFirebaseForbiddenAction.addRouteOrNavigatorWiring,
  ],
  dataSafetyRules: <CallV2ProductionBackendDataSafetyRule>[
    CallV2ProductionBackendDataSafetyRule
        .sanitizeBackendSnapshotsBeforeBridgeRuntimeUi,
    CallV2ProductionBackendDataSafetyRule.noRawFirestoreSnapshotStored,
    CallV2ProductionBackendDataSafetyRule.noRawAuthUserStored,
    CallV2ProductionBackendDataSafetyRule.noRawCallableResultStored,
    CallV2ProductionBackendDataSafetyRule
        .noIdsTokensChannelsCredentialsInLogsDebugUiRoutes,
    CallV2ProductionBackendDataSafetyRule.noRawBackendPayloadInErrors,
    CallV2ProductionBackendDataSafetyRule.noRawExceptionStackExposure,
    CallV2ProductionBackendDataSafetyRule.noRouteArguments,
    CallV2ProductionBackendDataSafetyRule
        .noCredentialRefreshWithoutSeparateApproval,
    CallV2ProductionBackendDataSafetyRule.safeEnumBooleanGenerationModelsOnly,
  ],
  listenerSafetyRules: <CallV2ProductionBackendListenerSafetyRule>[
    CallV2ProductionBackendListenerSafetyRule
        .noListenerBeforeExplicitStartupApproval,
    CallV2ProductionBackendListenerSafetyRule.noListenerWhileRolloutFalse,
    CallV2ProductionBackendListenerSafetyRule.listenerOwnerDisposable,
    CallV2ProductionBackendListenerSafetyRule.duplicateListenersRejectedOrNoOp,
    CallV2ProductionBackendListenerSafetyRule.staleGenerationIgnored,
    CallV2ProductionBackendListenerSafetyRule.terminalStateUnsubscribes,
    CallV2ProductionBackendListenerSafetyRule.signOutUnsubscribes,
    CallV2ProductionBackendListenerSafetyRule.authInvalidUnsubscribes,
    CallV2ProductionBackendListenerSafetyRule
        .backgroundLifecycleCleanupDoesNotStartListeners,
    CallV2ProductionBackendListenerSafetyRule.listenersCoveredByRollback,
  ],
  gates: <CallV2ProductionBackendFirebaseGate>[
    CallV2ProductionBackendFirebaseGate.authGateApproved,
    CallV2ProductionBackendFirebaseGate.firestoreRulesReviewed,
    CallV2ProductionBackendFirebaseGate.emulatorRulesTestsPassed,
    CallV2ProductionBackendFirebaseGate.functionsDeploymentValidationPassed,
    CallV2ProductionBackendFirebaseGate.appCheckBehaviorReviewed,
    CallV2ProductionBackendFirebaseGate.noDebugTokenLeakage,
    CallV2ProductionBackendFirebaseGate.leastPrivilegeReadWriteShapeReviewed,
    CallV2ProductionBackendFirebaseGate.backendIndexesReviewedIfNeeded,
    CallV2ProductionBackendFirebaseGate.explicitHumanApprovalRequired,
    CallV2ProductionBackendFirebaseGate.developerOnlyAllowlistRequired,
  ],
  callStateConsistencyRules: <CallV2ProductionBackendCallStateConsistencyRule>[
    CallV2ProductionBackendCallStateConsistencyRule.staleSnapshotIgnored,
    CallV2ProductionBackendCallStateConsistencyRule.duplicateSnapshotNoOp,
    CallV2ProductionBackendCallStateConsistencyRule
        .outOfOrderStateRejectedOrNoOp,
    CallV2ProductionBackendCallStateConsistencyRule.ownershipMismatchRejected,
    CallV2ProductionBackendCallStateConsistencyRule
        .terminalMismatchControlledClose,
    CallV2ProductionBackendCallStateConsistencyRule
        .credentialExpiryControlledFailureNoRefreshUnlessApproved,
    CallV2ProductionBackendCallStateConsistencyRule
        .remoteDisconnectReconnectSanitized,
    CallV2ProductionBackendCallStateConsistencyRule
        .backendTimeoutMapsToControlledFailure,
  ],
  rollbackControls: <CallV2ProductionBackendFirebaseRollback>[
    CallV2ProductionBackendFirebaseRollback.oneCommit,
    CallV2ProductionBackendFirebaseRollback.removeBackendFirebaseOwnerWiring,
    CallV2ProductionBackendFirebaseRollback.removeListeners,
    CallV2ProductionBackendFirebaseRollback.rolloutFalse,
    CallV2ProductionBackendFirebaseRollback.runtimeRemainsNotStarted,
    CallV2ProductionBackendFirebaseRollback.routeRegistryDisabledNull,
    CallV2ProductionBackendFirebaseRollback.noDeploymentWithoutApproval,
    CallV2ProductionBackendFirebaseRollback.backupBranchProtected,
  ],
  v1Protections: <CallV2ProductionBackendFirebaseV1Protection>[
    CallV2ProductionBackendFirebaseV1Protection.noV1DataModelChanges,
    CallV2ProductionBackendFirebaseV1Protection.noV1RouteBehaviorChanges,
    CallV2ProductionBackendFirebaseV1Protection.noV1ChatBehaviorChanges,
    CallV2ProductionBackendFirebaseV1Protection.noV1CallBehaviorChanges,
    CallV2ProductionBackendFirebaseV1Protection
        .noExistingFirestoreRulesRegression,
    CallV2ProductionBackendFirebaseV1Protection
        .v1SmokeBeforeAndAfterBackendWiring,
    CallV2ProductionBackendFirebaseV1Protection.immediateRollbackOnV1Regression,
  ],
  testRequirements: <CallV2ProductionBackendFirebaseTestRequirement>[
    CallV2ProductionBackendFirebaseTestRequirement.phase6YTests,
    CallV2ProductionBackendFirebaseTestRequirement.phase6XTests,
    CallV2ProductionBackendFirebaseTestRequirement.phase6WTests,
    CallV2ProductionBackendFirebaseTestRequirement.phase6VTests,
    CallV2ProductionBackendFirebaseTestRequirement.phase6UTests,
    CallV2ProductionBackendFirebaseTestRequirement.allCallV2DesignTests,
    CallV2ProductionBackendFirebaseTestRequirement.allCallV2IntegrationTests,
    CallV2ProductionBackendFirebaseTestRequirement.allCallV2UiTests,
    CallV2ProductionBackendFirebaseTestRequirement.preIntegrationVerification,
    CallV2ProductionBackendFirebaseTestRequirement.productionCompositionTests,
    CallV2ProductionBackendFirebaseTestRequirement.finalReadinessTests,
    CallV2ProductionBackendFirebaseTestRequirement.allCallV2FlutterTests,
    CallV2ProductionBackendFirebaseTestRequirement.backendCheck,
    CallV2ProductionBackendFirebaseTestRequirement.deploymentValidation,
    CallV2ProductionBackendFirebaseTestRequirement.firestoreRulesTests,
    CallV2ProductionBackendFirebaseTestRequirement.emulatorTests,
    CallV2ProductionBackendFirebaseTestRequirement.fullFlutterAnalyze,
    CallV2ProductionBackendFirebaseTestRequirement.diffCheck,
  ],
);
