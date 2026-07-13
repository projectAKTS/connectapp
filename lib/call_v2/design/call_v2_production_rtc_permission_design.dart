enum CallV2ProductionRtcPermissionStatus {
  noRealRtcIntegrationImplemented,
  noRtcEngineInitialized,
  noRtcProviderApisCalled,
  noMicrophonePermissionRequested,
  noCameraPermissionRequested,
  noDeviceEnumeration,
  noDeviceSwitching,
  noBackendFirebaseContact,
  runtimeNotStarted,
  rolloutFalse,
  callV2Unreachable,
  noPubspecDependencyChanges,
  noPlatformPermissionConfigChanges,
  deploymentNotAuthorized,
}

enum CallV2ProductionRtcPermissionAllowedLocation {
  isolatedCallV2RtcPermissionOwner,
  isolatedProductionIntegrationOwnerOnlyIfApproved,
  developerOnlyRtcPermissionPrOnly,
}

enum CallV2ProductionRtcPermissionForbiddenLocation {
  mainDart,
  appStartup,
  appRouter,
  routeRegistry,
  lifecycleEventHandlerAlone,
  v1Files,
}

enum CallV2ProductionRtcPermissionForbiddenAction {
  modifyMainDart,
  modifyAppStartup,
  modifyAppRouter,
  modifyRouteRegistry,
  changeRolloutFlag,
  addRtcDependency,
  modifyPlatformPermissionsConfig,
  initializeRtcEngine,
  joinRtcChannel,
  publishAudio,
  publishVideo,
  requestMicrophonePermission,
  requestCameraPermission,
  enumerateDevices,
  switchDevices,
  startRuntime,
  openBackendFirebaseListeners,
  addRouteOrNavigatorWiring,
  deploy,
}

enum CallV2ProductionPermissionSafetyRule {
  noPermissionRequestBeforeExplicitUserDeveloperAction,
  noPermissionRequestWhileRolloutFalse,
  noRepeatedPermissionPromptLoop,
  deniedPermissionMapsToControlledFailure,
  permanentlyDeniedPermissionRetryBlockedUntilUserAction,
  permissionStatusStoredAsSafeEnumOnly,
  noRawNativePermissionResultStored,
  noPermissionPromptFromLifecycleEventAlone,
}

enum CallV2ProductionRtcSafetyRule {
  noRtcEngineBeforeExplicitStartupApproval,
  noRtcJoinWithoutSanitizedCredentialTokenGate,
  noRawRtcTokenChannelInLogsDebugUiRoutes,
  noRawRtcNativeCallbackPayloadStored,
  duplicateJoinRejectedOrNoOp,
  staleGenerationIgnored,
  terminalStateLeavesChannel,
  signOutLeavesChannel,
  authInvalidLeavesChannel,
  backgroundCleanupDoesNotStartRtc,
  rtcFailureMapsToControlledFailure,
}

enum CallV2ProductionDeviceSafetyRule {
  deviceAvailabilityStoredAsSafeEnumOnly,
  noRawDeviceIdsOrLabelsExposed,
  speakerSwitchFailureControlledNoOp,
  cameraSwitchFailureControlledNoOp,
  cameraToggleIdempotent,
  micToggleIdempotent,
  deviceUnavailableMapsToControlledFailure,
  deviceCleanupCoveredByRollback,
}

enum CallV2ProductionMediaLifecycleRule {
  noCameraMicActiveBeforePermissionAndStartupApproval,
  pausedInactiveHiddenDoNotStartMedia,
  detachedSignOutAuthInvalidCleanupByExplicitPolicyOnly,
  terminalStateStopsMedia,
  disposeStopsMediaIdempotently,
  retryAfterPermissionDenialRequiresExplicitUserAction,
}

enum CallV2ProductionRtcPermissionGate {
  pubspecDependencyReview,
  iosPermissionStringsReview,
  androidPermissionManifestReview,
  appStorePlayStorePrivacyDisclosureReview,
  rtcProviderConfigurationReview,
  tokenCredentialHandlingReview,
  securityPrivacyAuditAccepted,
  backendFirebaseDesignAccepted,
  runtimeStartupDesignAccepted,
  explicitHumanApprovalRequired,
  developerOnlyAllowlistRequired,
  allTestsPassed,
}

enum CallV2ProductionRtcPermissionRollback {
  oneCommit,
  removeRtcPermissionOwnerWiring,
  leaveRtcChannel,
  stopLocalMedia,
  rolloutFalse,
  runtimeRemainsNotStarted,
  routeRegistryDisabledNull,
  noDeploymentWithoutApproval,
  backupBranchProtected,
}

enum CallV2ProductionRtcPermissionV1Protection {
  noV1CallMediaBehaviorChanges,
  noV1RouteBehaviorChanges,
  noV1ChatBehaviorChanges,
  noAppStartupRegression,
  noPlatformConfigRegression,
  v1SmokeBeforeAndAfterRtcPermissionWiring,
  immediateRollbackOnV1Regression,
}

enum CallV2ProductionRtcPermissionTestRequirement {
  phase6ZTests,
  phase6YTests,
  phase6XTests,
  phase6WTests,
  phase6VTests,
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

final class CallV2ProductionRtcPermissionDesign {
  factory CallV2ProductionRtcPermissionDesign({
    required String protectedBackupBranch,
    required String protectedBackupSha,
    required List<CallV2ProductionRtcPermissionStatus> currentStatus,
    required List<CallV2ProductionRtcPermissionAllowedLocation>
        allowedFutureLocations,
    required List<CallV2ProductionRtcPermissionForbiddenLocation>
        forbiddenLocations,
    required List<CallV2ProductionRtcPermissionForbiddenAction>
        forbiddenActions,
    required List<CallV2ProductionPermissionSafetyRule> permissionSafetyRules,
    required List<CallV2ProductionRtcSafetyRule> rtcSafetyRules,
    required List<CallV2ProductionDeviceSafetyRule> deviceSafetyRules,
    required List<CallV2ProductionMediaLifecycleRule> mediaLifecycleRules,
    required List<CallV2ProductionRtcPermissionGate> gates,
    required List<CallV2ProductionRtcPermissionRollback> rollbackControls,
    required List<CallV2ProductionRtcPermissionV1Protection> v1Protections,
    required List<CallV2ProductionRtcPermissionTestRequirement>
        testRequirements,
  }) {
    return CallV2ProductionRtcPermissionDesign._(
      protectedBackupBranch,
      protectedBackupSha,
      List<CallV2ProductionRtcPermissionStatus>.unmodifiable(currentStatus),
      List<CallV2ProductionRtcPermissionAllowedLocation>.unmodifiable(
        allowedFutureLocations,
      ),
      List<CallV2ProductionRtcPermissionForbiddenLocation>.unmodifiable(
        forbiddenLocations,
      ),
      List<CallV2ProductionRtcPermissionForbiddenAction>.unmodifiable(
        forbiddenActions,
      ),
      List<CallV2ProductionPermissionSafetyRule>.unmodifiable(
        permissionSafetyRules,
      ),
      List<CallV2ProductionRtcSafetyRule>.unmodifiable(rtcSafetyRules),
      List<CallV2ProductionDeviceSafetyRule>.unmodifiable(deviceSafetyRules),
      List<CallV2ProductionMediaLifecycleRule>.unmodifiable(
        mediaLifecycleRules,
      ),
      List<CallV2ProductionRtcPermissionGate>.unmodifiable(gates),
      List<CallV2ProductionRtcPermissionRollback>.unmodifiable(
        rollbackControls,
      ),
      List<CallV2ProductionRtcPermissionV1Protection>.unmodifiable(
        v1Protections,
      ),
      List<CallV2ProductionRtcPermissionTestRequirement>.unmodifiable(
        testRequirements,
      ),
    );
  }

  const CallV2ProductionRtcPermissionDesign._(
    this.protectedBackupBranch,
    this.protectedBackupSha,
    this.currentStatus,
    this.allowedFutureLocations,
    this.forbiddenLocations,
    this.forbiddenActions,
    this.permissionSafetyRules,
    this.rtcSafetyRules,
    this.deviceSafetyRules,
    this.mediaLifecycleRules,
    this.gates,
    this.rollbackControls,
    this.v1Protections,
    this.testRequirements,
  );

  final String protectedBackupBranch;
  final String protectedBackupSha;
  final List<CallV2ProductionRtcPermissionStatus> currentStatus;
  final List<CallV2ProductionRtcPermissionAllowedLocation>
      allowedFutureLocations;
  final List<CallV2ProductionRtcPermissionForbiddenLocation> forbiddenLocations;
  final List<CallV2ProductionRtcPermissionForbiddenAction> forbiddenActions;
  final List<CallV2ProductionPermissionSafetyRule> permissionSafetyRules;
  final List<CallV2ProductionRtcSafetyRule> rtcSafetyRules;
  final List<CallV2ProductionDeviceSafetyRule> deviceSafetyRules;
  final List<CallV2ProductionMediaLifecycleRule> mediaLifecycleRules;
  final List<CallV2ProductionRtcPermissionGate> gates;
  final List<CallV2ProductionRtcPermissionRollback> rollbackControls;
  final List<CallV2ProductionRtcPermissionV1Protection> v1Protections;
  final List<CallV2ProductionRtcPermissionTestRequirement> testRequirements;

  bool get isRtcIntegrationImplemented => !currentStatus.contains(
        CallV2ProductionRtcPermissionStatus.noRealRtcIntegrationImplemented,
      );

  bool get isRtcEngineInitialized => !currentStatus.contains(
        CallV2ProductionRtcPermissionStatus.noRtcEngineInitialized,
      );

  bool get hasRtcProviderApiCalls => !currentStatus.contains(
        CallV2ProductionRtcPermissionStatus.noRtcProviderApisCalled,
      );

  bool get hasPermissionRequests =>
      !currentStatus.contains(
        CallV2ProductionRtcPermissionStatus.noMicrophonePermissionRequested,
      ) ||
      !currentStatus.contains(
        CallV2ProductionRtcPermissionStatus.noCameraPermissionRequested,
      );

  bool get hasDeviceEnumerationOrSwitching =>
      !currentStatus.contains(
        CallV2ProductionRtcPermissionStatus.noDeviceEnumeration,
      ) ||
      !currentStatus.contains(
        CallV2ProductionRtcPermissionStatus.noDeviceSwitching,
      );

  bool get hasBackendFirebaseContact => !currentStatus.contains(
        CallV2ProductionRtcPermissionStatus.noBackendFirebaseContact,
      );

  bool get isRuntimeStarted => !currentStatus.contains(
        CallV2ProductionRtcPermissionStatus.runtimeNotStarted,
      );

  bool get isRolloutEnabled => !currentStatus.contains(
        CallV2ProductionRtcPermissionStatus.rolloutFalse,
      );

  bool get isCallV2Reachable => !currentStatus.contains(
        CallV2ProductionRtcPermissionStatus.callV2Unreachable,
      );

  bool get hasDependencyOrPlatformChanges =>
      !currentStatus.contains(
        CallV2ProductionRtcPermissionStatus.noPubspecDependencyChanges,
      ) ||
      !currentStatus.contains(
        CallV2ProductionRtcPermissionStatus.noPlatformPermissionConfigChanges,
      );

  bool get isDeploymentAuthorized => !currentStatus.contains(
        CallV2ProductionRtcPermissionStatus.deploymentNotAuthorized,
      );

  bool get allowsAutomaticWiring => !gates.contains(
        CallV2ProductionRtcPermissionGate.explicitHumanApprovalRequired,
      );

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'currentStatusCount': currentStatus.length,
      'allowedFutureLocationCount': allowedFutureLocations.length,
      'forbiddenLocationCount': forbiddenLocations.length,
      'forbiddenActionCount': forbiddenActions.length,
      'permissionSafetyRuleCount': permissionSafetyRules.length,
      'rtcSafetyRuleCount': rtcSafetyRules.length,
      'deviceSafetyRuleCount': deviceSafetyRules.length,
      'mediaLifecycleRuleCount': mediaLifecycleRules.length,
      'gateCount': gates.length,
      'rollbackControlCount': rollbackControls.length,
      'v1ProtectionCount': v1Protections.length,
      'testRequirementCount': testRequirements.length,
      'rtcIntegrationImplemented': isRtcIntegrationImplemented,
      'rtcEngineInitialized': isRtcEngineInitialized,
      'rtcProviderApiCalls': hasRtcProviderApiCalls,
      'permissionRequests': hasPermissionRequests,
      'deviceEnumerationOrSwitching': hasDeviceEnumerationOrSwitching,
      'backendFirebaseContact': hasBackendFirebaseContact,
      'runtimeStarted': isRuntimeStarted,
      'rolloutEnabled': isRolloutEnabled,
      'callV2Reachable': isCallV2Reachable,
      'dependencyOrPlatformChanges': hasDependencyOrPlatformChanges,
      'deploymentAuthorized': isDeploymentAuthorized,
      'allowsAutomaticWiring': allowsAutomaticWiring,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionRtcPermissionDesign(${toSafeDebugMap()})';
  }
}

final callV2ProductionRtcPermissionDesign = CallV2ProductionRtcPermissionDesign(
  protectedBackupBranch: 'backup/call-v2-pre-phase6b-2026-07-04',
  protectedBackupSha: '2a1ea8d6864ab0098d17c52bdf5ec70f66979e4d',
  currentStatus: <CallV2ProductionRtcPermissionStatus>[
    CallV2ProductionRtcPermissionStatus.noRealRtcIntegrationImplemented,
    CallV2ProductionRtcPermissionStatus.noRtcEngineInitialized,
    CallV2ProductionRtcPermissionStatus.noRtcProviderApisCalled,
    CallV2ProductionRtcPermissionStatus.noMicrophonePermissionRequested,
    CallV2ProductionRtcPermissionStatus.noCameraPermissionRequested,
    CallV2ProductionRtcPermissionStatus.noDeviceEnumeration,
    CallV2ProductionRtcPermissionStatus.noDeviceSwitching,
    CallV2ProductionRtcPermissionStatus.noBackendFirebaseContact,
    CallV2ProductionRtcPermissionStatus.runtimeNotStarted,
    CallV2ProductionRtcPermissionStatus.rolloutFalse,
    CallV2ProductionRtcPermissionStatus.callV2Unreachable,
    CallV2ProductionRtcPermissionStatus.noPubspecDependencyChanges,
    CallV2ProductionRtcPermissionStatus.noPlatformPermissionConfigChanges,
    CallV2ProductionRtcPermissionStatus.deploymentNotAuthorized,
  ],
  allowedFutureLocations: <CallV2ProductionRtcPermissionAllowedLocation>[
    CallV2ProductionRtcPermissionAllowedLocation
        .isolatedCallV2RtcPermissionOwner,
    CallV2ProductionRtcPermissionAllowedLocation
        .isolatedProductionIntegrationOwnerOnlyIfApproved,
    CallV2ProductionRtcPermissionAllowedLocation
        .developerOnlyRtcPermissionPrOnly,
  ],
  forbiddenLocations: <CallV2ProductionRtcPermissionForbiddenLocation>[
    CallV2ProductionRtcPermissionForbiddenLocation.mainDart,
    CallV2ProductionRtcPermissionForbiddenLocation.appStartup,
    CallV2ProductionRtcPermissionForbiddenLocation.appRouter,
    CallV2ProductionRtcPermissionForbiddenLocation.routeRegistry,
    CallV2ProductionRtcPermissionForbiddenLocation.lifecycleEventHandlerAlone,
    CallV2ProductionRtcPermissionForbiddenLocation.v1Files,
  ],
  forbiddenActions: <CallV2ProductionRtcPermissionForbiddenAction>[
    CallV2ProductionRtcPermissionForbiddenAction.modifyMainDart,
    CallV2ProductionRtcPermissionForbiddenAction.modifyAppStartup,
    CallV2ProductionRtcPermissionForbiddenAction.modifyAppRouter,
    CallV2ProductionRtcPermissionForbiddenAction.modifyRouteRegistry,
    CallV2ProductionRtcPermissionForbiddenAction.changeRolloutFlag,
    CallV2ProductionRtcPermissionForbiddenAction.addRtcDependency,
    CallV2ProductionRtcPermissionForbiddenAction
        .modifyPlatformPermissionsConfig,
    CallV2ProductionRtcPermissionForbiddenAction.initializeRtcEngine,
    CallV2ProductionRtcPermissionForbiddenAction.joinRtcChannel,
    CallV2ProductionRtcPermissionForbiddenAction.publishAudio,
    CallV2ProductionRtcPermissionForbiddenAction.publishVideo,
    CallV2ProductionRtcPermissionForbiddenAction.requestMicrophonePermission,
    CallV2ProductionRtcPermissionForbiddenAction.requestCameraPermission,
    CallV2ProductionRtcPermissionForbiddenAction.enumerateDevices,
    CallV2ProductionRtcPermissionForbiddenAction.switchDevices,
    CallV2ProductionRtcPermissionForbiddenAction.startRuntime,
    CallV2ProductionRtcPermissionForbiddenAction.openBackendFirebaseListeners,
    CallV2ProductionRtcPermissionForbiddenAction.addRouteOrNavigatorWiring,
    CallV2ProductionRtcPermissionForbiddenAction.deploy,
  ],
  permissionSafetyRules: <CallV2ProductionPermissionSafetyRule>[
    CallV2ProductionPermissionSafetyRule
        .noPermissionRequestBeforeExplicitUserDeveloperAction,
    CallV2ProductionPermissionSafetyRule.noPermissionRequestWhileRolloutFalse,
    CallV2ProductionPermissionSafetyRule.noRepeatedPermissionPromptLoop,
    CallV2ProductionPermissionSafetyRule
        .deniedPermissionMapsToControlledFailure,
    CallV2ProductionPermissionSafetyRule
        .permanentlyDeniedPermissionRetryBlockedUntilUserAction,
    CallV2ProductionPermissionSafetyRule.permissionStatusStoredAsSafeEnumOnly,
    CallV2ProductionPermissionSafetyRule.noRawNativePermissionResultStored,
    CallV2ProductionPermissionSafetyRule
        .noPermissionPromptFromLifecycleEventAlone,
  ],
  rtcSafetyRules: <CallV2ProductionRtcSafetyRule>[
    CallV2ProductionRtcSafetyRule.noRtcEngineBeforeExplicitStartupApproval,
    CallV2ProductionRtcSafetyRule.noRtcJoinWithoutSanitizedCredentialTokenGate,
    CallV2ProductionRtcSafetyRule.noRawRtcTokenChannelInLogsDebugUiRoutes,
    CallV2ProductionRtcSafetyRule.noRawRtcNativeCallbackPayloadStored,
    CallV2ProductionRtcSafetyRule.duplicateJoinRejectedOrNoOp,
    CallV2ProductionRtcSafetyRule.staleGenerationIgnored,
    CallV2ProductionRtcSafetyRule.terminalStateLeavesChannel,
    CallV2ProductionRtcSafetyRule.signOutLeavesChannel,
    CallV2ProductionRtcSafetyRule.authInvalidLeavesChannel,
    CallV2ProductionRtcSafetyRule.backgroundCleanupDoesNotStartRtc,
    CallV2ProductionRtcSafetyRule.rtcFailureMapsToControlledFailure,
  ],
  deviceSafetyRules: <CallV2ProductionDeviceSafetyRule>[
    CallV2ProductionDeviceSafetyRule.deviceAvailabilityStoredAsSafeEnumOnly,
    CallV2ProductionDeviceSafetyRule.noRawDeviceIdsOrLabelsExposed,
    CallV2ProductionDeviceSafetyRule.speakerSwitchFailureControlledNoOp,
    CallV2ProductionDeviceSafetyRule.cameraSwitchFailureControlledNoOp,
    CallV2ProductionDeviceSafetyRule.cameraToggleIdempotent,
    CallV2ProductionDeviceSafetyRule.micToggleIdempotent,
    CallV2ProductionDeviceSafetyRule.deviceUnavailableMapsToControlledFailure,
    CallV2ProductionDeviceSafetyRule.deviceCleanupCoveredByRollback,
  ],
  mediaLifecycleRules: <CallV2ProductionMediaLifecycleRule>[
    CallV2ProductionMediaLifecycleRule
        .noCameraMicActiveBeforePermissionAndStartupApproval,
    CallV2ProductionMediaLifecycleRule.pausedInactiveHiddenDoNotStartMedia,
    CallV2ProductionMediaLifecycleRule
        .detachedSignOutAuthInvalidCleanupByExplicitPolicyOnly,
    CallV2ProductionMediaLifecycleRule.terminalStateStopsMedia,
    CallV2ProductionMediaLifecycleRule.disposeStopsMediaIdempotently,
    CallV2ProductionMediaLifecycleRule
        .retryAfterPermissionDenialRequiresExplicitUserAction,
  ],
  gates: <CallV2ProductionRtcPermissionGate>[
    CallV2ProductionRtcPermissionGate.pubspecDependencyReview,
    CallV2ProductionRtcPermissionGate.iosPermissionStringsReview,
    CallV2ProductionRtcPermissionGate.androidPermissionManifestReview,
    CallV2ProductionRtcPermissionGate.appStorePlayStorePrivacyDisclosureReview,
    CallV2ProductionRtcPermissionGate.rtcProviderConfigurationReview,
    CallV2ProductionRtcPermissionGate.tokenCredentialHandlingReview,
    CallV2ProductionRtcPermissionGate.securityPrivacyAuditAccepted,
    CallV2ProductionRtcPermissionGate.backendFirebaseDesignAccepted,
    CallV2ProductionRtcPermissionGate.runtimeStartupDesignAccepted,
    CallV2ProductionRtcPermissionGate.explicitHumanApprovalRequired,
    CallV2ProductionRtcPermissionGate.developerOnlyAllowlistRequired,
    CallV2ProductionRtcPermissionGate.allTestsPassed,
  ],
  rollbackControls: <CallV2ProductionRtcPermissionRollback>[
    CallV2ProductionRtcPermissionRollback.oneCommit,
    CallV2ProductionRtcPermissionRollback.removeRtcPermissionOwnerWiring,
    CallV2ProductionRtcPermissionRollback.leaveRtcChannel,
    CallV2ProductionRtcPermissionRollback.stopLocalMedia,
    CallV2ProductionRtcPermissionRollback.rolloutFalse,
    CallV2ProductionRtcPermissionRollback.runtimeRemainsNotStarted,
    CallV2ProductionRtcPermissionRollback.routeRegistryDisabledNull,
    CallV2ProductionRtcPermissionRollback.noDeploymentWithoutApproval,
    CallV2ProductionRtcPermissionRollback.backupBranchProtected,
  ],
  v1Protections: <CallV2ProductionRtcPermissionV1Protection>[
    CallV2ProductionRtcPermissionV1Protection.noV1CallMediaBehaviorChanges,
    CallV2ProductionRtcPermissionV1Protection.noV1RouteBehaviorChanges,
    CallV2ProductionRtcPermissionV1Protection.noV1ChatBehaviorChanges,
    CallV2ProductionRtcPermissionV1Protection.noAppStartupRegression,
    CallV2ProductionRtcPermissionV1Protection.noPlatformConfigRegression,
    CallV2ProductionRtcPermissionV1Protection
        .v1SmokeBeforeAndAfterRtcPermissionWiring,
    CallV2ProductionRtcPermissionV1Protection.immediateRollbackOnV1Regression,
  ],
  testRequirements: <CallV2ProductionRtcPermissionTestRequirement>[
    CallV2ProductionRtcPermissionTestRequirement.phase6ZTests,
    CallV2ProductionRtcPermissionTestRequirement.phase6YTests,
    CallV2ProductionRtcPermissionTestRequirement.phase6XTests,
    CallV2ProductionRtcPermissionTestRequirement.phase6WTests,
    CallV2ProductionRtcPermissionTestRequirement.phase6VTests,
    CallV2ProductionRtcPermissionTestRequirement.allCallV2DesignTests,
    CallV2ProductionRtcPermissionTestRequirement.allCallV2IntegrationTests,
    CallV2ProductionRtcPermissionTestRequirement.allCallV2UiTests,
    CallV2ProductionRtcPermissionTestRequirement.preIntegrationVerification,
    CallV2ProductionRtcPermissionTestRequirement.productionCompositionTests,
    CallV2ProductionRtcPermissionTestRequirement.finalReadinessTests,
    CallV2ProductionRtcPermissionTestRequirement.allCallV2FlutterTests,
    CallV2ProductionRtcPermissionTestRequirement.backendCheck,
    CallV2ProductionRtcPermissionTestRequirement.deploymentValidation,
    CallV2ProductionRtcPermissionTestRequirement.firestoreRulesTests,
    CallV2ProductionRtcPermissionTestRequirement.emulatorTests,
    CallV2ProductionRtcPermissionTestRequirement.fullFlutterAnalyze,
    CallV2ProductionRtcPermissionTestRequirement.diffCheck,
  ],
);
