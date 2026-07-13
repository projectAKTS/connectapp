enum CallV2DeveloperRtcPermissionOwnerSkeletonStatus {
  developerOnly,
  hardDisabled,
  rolloutFalse,
  callV2Unreachable,
  noRtcPermissionAttach,
  noRtcPermissionImports,
  noRtcEngineInitialization,
  noRtcChannelJoin,
  noRtcTokenChannelConsumption,
  noPermissionPrompt,
  noDeviceEnumeration,
  noMediaCapture,
  noAudioVideoPublish,
  noRtcCallbacksOrSubscriptions,
  noRuntimeConstruction,
  noRuntimeStart,
  noBackendServiceAccess,
  noCompositionConstruction,
  noStartupBridgeWiring,
  noRouteRegistryMutation,
  noNavigationAccess,
  noAsyncHandles,
  noPubspecPlatformConfigChanges,
  deploymentNotApproved,
  v1Protected,
}

enum CallV2DeveloperRtcPermissionAction {
  prepareRtcPermissionOwner,
  requestPermissionGate,
  receiveSanitizedPermissionResult,
  requestRtcAttach,
  receiveSanitizedRtcEvent,
  detachRtcOwner,
  disposeRtcOwner,
}

enum CallV2DeveloperSanitizedPermissionResult {
  microphoneGranted,
  microphoneDenied,
  microphonePermanentlyDenied,
  cameraGranted,
  cameraDenied,
  cameraPermanentlyDenied,
  permissionUnavailable,
}

enum CallV2DeveloperSanitizedRtcEvent {
  rtcPrepared,
  rtcConnecting,
  rtcJoined,
  rtcReconnecting,
  rtcRemoteJoined,
  rtcRemoteLeft,
  rtcLeaving,
  rtcLeft,
  rtcFailure,
  rtcTimeout,
}

enum CallV2DeveloperRtcPermissionOwnershipRule {
  explicitHumanApprovalRequired,
  developerOnlyAllowlistRequired,
  rolloutFalseBlocksRtcPermissionAttach,
  noRtcPermissionImports,
  noRtcEngineInitialization,
  noRtcChannelJoin,
  noRtcTokenChannelConsumption,
  noPermissionPrompt,
  noDeviceEnumeration,
  noMediaCapture,
  noAudioVideoPublish,
  noRtcCallbacksOrSubscriptions,
  sanitizedEnumBooleanGenerationOnly,
  duplicateRtcEventNoOp,
  staleRtcEventIgnored,
  permissionDeniedControlledFailure,
  permanentlyDeniedRequiresUserAction,
  missingCredentialRejected,
  terminalRtcEventDetaches,
  mediaFailureControlledOnly,
}

enum CallV2DeveloperRtcPermissionDecisionStatus {
  disabledInert,
  rejected,
  duplicateNoOp,
  staleIgnored,
  detached,
}

enum CallV2DeveloperRtcPermissionRejection {
  disposed,
  terminal,
  staleGeneration,
  duplicateGeneration,
  permissionDenied,
  permissionPermanentlyDenied,
  missingCredential,
  mediaUnavailable,
  rtcFailure,
  rawPayloadRejected,
  controlledFailure,
}

enum CallV2DeveloperRtcPermissionRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noPubspecPlatformConfigChanges,
  v1Unaffected,
}

final class CallV2DeveloperRtcPermissionDecision {
  const CallV2DeveloperRtcPermissionDecision._({
    required this.status,
    required this.action,
    required this.generation,
    this.permissionResult,
    this.rtcEvent,
    this.rejection,
  });

  const CallV2DeveloperRtcPermissionDecision.disabledInert({
    required CallV2DeveloperRtcPermissionAction action,
    required int generation,
    CallV2DeveloperSanitizedPermissionResult? permissionResult,
    CallV2DeveloperSanitizedRtcEvent? rtcEvent,
  }) : this._(
          status: CallV2DeveloperRtcPermissionDecisionStatus.disabledInert,
          action: action,
          generation: generation,
          permissionResult: permissionResult,
          rtcEvent: rtcEvent,
        );

  const CallV2DeveloperRtcPermissionDecision.rejected({
    required CallV2DeveloperRtcPermissionAction action,
    required int generation,
    required CallV2DeveloperRtcPermissionRejection rejection,
    CallV2DeveloperSanitizedPermissionResult? permissionResult,
    CallV2DeveloperSanitizedRtcEvent? rtcEvent,
  }) : this._(
          status: CallV2DeveloperRtcPermissionDecisionStatus.rejected,
          action: action,
          generation: generation,
          permissionResult: permissionResult,
          rtcEvent: rtcEvent,
          rejection: rejection,
        );

  const CallV2DeveloperRtcPermissionDecision.duplicateNoOp({
    required CallV2DeveloperRtcPermissionAction action,
    required int generation,
    CallV2DeveloperSanitizedPermissionResult? permissionResult,
    CallV2DeveloperSanitizedRtcEvent? rtcEvent,
  }) : this._(
          status: CallV2DeveloperRtcPermissionDecisionStatus.duplicateNoOp,
          action: action,
          generation: generation,
          permissionResult: permissionResult,
          rtcEvent: rtcEvent,
          rejection: CallV2DeveloperRtcPermissionRejection.duplicateGeneration,
        );

  const CallV2DeveloperRtcPermissionDecision.staleIgnored({
    required CallV2DeveloperRtcPermissionAction action,
    required int generation,
    CallV2DeveloperSanitizedPermissionResult? permissionResult,
    CallV2DeveloperSanitizedRtcEvent? rtcEvent,
  }) : this._(
          status: CallV2DeveloperRtcPermissionDecisionStatus.staleIgnored,
          action: action,
          generation: generation,
          permissionResult: permissionResult,
          rtcEvent: rtcEvent,
          rejection: CallV2DeveloperRtcPermissionRejection.staleGeneration,
        );

  const CallV2DeveloperRtcPermissionDecision.detached({
    required CallV2DeveloperRtcPermissionAction action,
    required int generation,
    CallV2DeveloperSanitizedRtcEvent? rtcEvent,
    CallV2DeveloperRtcPermissionRejection? rejection,
  }) : this._(
          status: CallV2DeveloperRtcPermissionDecisionStatus.detached,
          action: action,
          generation: generation,
          rtcEvent: rtcEvent,
          rejection: rejection,
        );

  final CallV2DeveloperRtcPermissionDecisionStatus status;
  final CallV2DeveloperRtcPermissionAction action;
  final int generation;
  final CallV2DeveloperSanitizedPermissionResult? permissionResult;
  final CallV2DeveloperSanitizedRtcEvent? rtcEvent;
  final CallV2DeveloperRtcPermissionRejection? rejection;

  bool get attachesRtcPermission => false;
  bool get importsRtcPermissionPackages => false;
  bool get initializesRtcEngine => false;
  bool get joinsRtcChannel => false;
  bool get consumesRtcCredentialMaterial => false;
  bool get promptsForPermissions => false;
  bool get enumeratesDevices => false;
  bool get capturesMedia => false;
  bool get publishesAudioVideo => false;
  bool get opensRtcCallbacksOrSubscriptions => false;
  bool get constructsRuntime => false;
  bool get startsRuntime => false;
  bool get accessesBackendServices => false;
  bool get constructsComposition => false;
  bool get wiresStartupBridge => false;
  bool get mutatesRouteRegistry => false;
  bool get accessesNavigation => false;
  bool get mutatesV1State => false;
  bool get opensAsyncHandles => false;
  bool get changesPubspecPlatformConfig => false;
  bool get controlledFailureOnly => true;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'status': status.name,
      'rejected': status == CallV2DeveloperRtcPermissionDecisionStatus.rejected,
      'duplicate':
          status == CallV2DeveloperRtcPermissionDecisionStatus.duplicateNoOp,
      'stale':
          status == CallV2DeveloperRtcPermissionDecisionStatus.staleIgnored,
      'detached': status == CallV2DeveloperRtcPermissionDecisionStatus.detached,
      'hasPermissionResult': permissionResult != null,
      'hasRtcEvent': rtcEvent != null,
      'hasReason': rejection != null,
      'generationKnown': generation >= 0,
      'attachesRtcPermission': attachesRtcPermission,
      'importsRtcPermissionPackages': importsRtcPermissionPackages,
      'initializesRtcEngine': initializesRtcEngine,
      'joinsRtc': joinsRtcChannel,
      'usesCredentialMaterial': consumesRtcCredentialMaterial,
      'promptsForPermissions': promptsForPermissions,
      'enumeratesDevices': enumeratesDevices,
      'capturesMedia': capturesMedia,
      'publishesAudioVideo': publishesAudioVideo,
      'opensRtcCallbacksOrSubscriptions': opensRtcCallbacksOrSubscriptions,
      'constructsRuntime': constructsRuntime,
      'startsRuntime': startsRuntime,
      'accessesBackendServices': accessesBackendServices,
      'constructsComposition': constructsComposition,
      'wiresStartupBridge': wiresStartupBridge,
      'mutatesRouteRegistry': mutatesRouteRegistry,
      'accessesNavigation': accessesNavigation,
      'mutatesV1State': mutatesV1State,
      'opensAsyncHandles': opensAsyncHandles,
      'changesPubspecPlatformConfig': changesPubspecPlatformConfig,
      'controlledFailureOnly': controlledFailureOnly,
    };
  }

  @override
  String toString() {
    return 'CallV2DeveloperRtcPermissionDecision(${toSafeDebugMap()})';
  }
}

final class CallV2DeveloperRtcPermissionOwnerSkeleton {
  factory CallV2DeveloperRtcPermissionOwnerSkeleton({
    required List<CallV2DeveloperRtcPermissionOwnerSkeletonStatus> status,
    required List<CallV2DeveloperRtcPermissionAction> actions,
    required List<CallV2DeveloperSanitizedPermissionResult>
        sanitizedPermissionResults,
    required List<CallV2DeveloperSanitizedRtcEvent> sanitizedRtcEvents,
    required List<CallV2DeveloperRtcPermissionOwnershipRule> ownershipRules,
    required List<CallV2DeveloperRtcPermissionRollback> rollbackRequirements,
  }) {
    return CallV2DeveloperRtcPermissionOwnerSkeleton._(
      List<CallV2DeveloperRtcPermissionOwnerSkeletonStatus>.unmodifiable(
        status,
      ),
      List<CallV2DeveloperRtcPermissionAction>.unmodifiable(actions),
      List<CallV2DeveloperSanitizedPermissionResult>.unmodifiable(
        sanitizedPermissionResults,
      ),
      List<CallV2DeveloperSanitizedRtcEvent>.unmodifiable(
        sanitizedRtcEvents,
      ),
      List<CallV2DeveloperRtcPermissionOwnershipRule>.unmodifiable(
        ownershipRules,
      ),
      List<CallV2DeveloperRtcPermissionRollback>.unmodifiable(
        rollbackRequirements,
      ),
    );
  }

  const CallV2DeveloperRtcPermissionOwnerSkeleton._(
    this.status,
    this.actions,
    this.sanitizedPermissionResults,
    this.sanitizedRtcEvents,
    this.ownershipRules,
    this.rollbackRequirements,
  );

  final List<CallV2DeveloperRtcPermissionOwnerSkeletonStatus> status;
  final List<CallV2DeveloperRtcPermissionAction> actions;
  final List<CallV2DeveloperSanitizedPermissionResult>
      sanitizedPermissionResults;
  final List<CallV2DeveloperSanitizedRtcEvent> sanitizedRtcEvents;
  final List<CallV2DeveloperRtcPermissionOwnershipRule> ownershipRules;
  final List<CallV2DeveloperRtcPermissionRollback> rollbackRequirements;

  bool get isDeveloperOnly => status.contains(
        CallV2DeveloperRtcPermissionOwnerSkeletonStatus.developerOnly,
      );

  bool get isHardDisabled => status.contains(
        CallV2DeveloperRtcPermissionOwnerSkeletonStatus.hardDisabled,
      );

  bool get isRolloutEnabled => !status.contains(
        CallV2DeveloperRtcPermissionOwnerSkeletonStatus.rolloutFalse,
      );

  bool get isReachable => !status.contains(
        CallV2DeveloperRtcPermissionOwnerSkeletonStatus.callV2Unreachable,
      );

  bool get attachesRtcPermission => !status.contains(
        CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noRtcPermissionAttach,
      );

  bool get importsRtcPermissionPackages => !status.contains(
        CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noRtcPermissionImports,
      );

  bool get initializesRtcEngine => !status.contains(
        CallV2DeveloperRtcPermissionOwnerSkeletonStatus
            .noRtcEngineInitialization,
      );

  bool get joinsRtcChannel => !status.contains(
        CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noRtcChannelJoin,
      );

  bool get consumesRtcCredentialMaterial => !status.contains(
        CallV2DeveloperRtcPermissionOwnerSkeletonStatus
            .noRtcTokenChannelConsumption,
      );

  bool get promptsForPermissions => !status.contains(
        CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noPermissionPrompt,
      );

  bool get enumeratesDevices => !status.contains(
        CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noDeviceEnumeration,
      );

  bool get capturesMedia => !status.contains(
        CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noMediaCapture,
      );

  bool get publishesAudioVideo => !status.contains(
        CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noAudioVideoPublish,
      );

  bool get opensRtcCallbacksOrSubscriptions => !status.contains(
        CallV2DeveloperRtcPermissionOwnerSkeletonStatus
            .noRtcCallbacksOrSubscriptions,
      );

  bool get constructsRuntime => !status.contains(
        CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noRuntimeConstruction,
      );

  bool get startsRuntime => !status.contains(
        CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noRuntimeStart,
      );

  bool get accessesBackendServices => !status.contains(
        CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noBackendServiceAccess,
      );

  bool get constructsComposition => !status.contains(
        CallV2DeveloperRtcPermissionOwnerSkeletonStatus
            .noCompositionConstruction,
      );

  bool get wiresStartupBridge => !status.contains(
        CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noStartupBridgeWiring,
      );

  bool get mutatesRouteRegistry => !status.contains(
        CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noRouteRegistryMutation,
      );

  bool get accessesNavigation => !status.contains(
        CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noNavigationAccess,
      );

  bool get opensAsyncHandles => !status.contains(
        CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noAsyncHandles,
      );

  bool get changesPubspecPlatformConfig => !status.contains(
        CallV2DeveloperRtcPermissionOwnerSkeletonStatus
            .noPubspecPlatformConfigChanges,
      );

  bool get isDeploymentApproved => !status.contains(
        CallV2DeveloperRtcPermissionOwnerSkeletonStatus.deploymentNotApproved,
      );

  bool get protectsV1 => status.contains(
        CallV2DeveloperRtcPermissionOwnerSkeletonStatus.v1Protected,
      );

  CallV2DeveloperRtcPermissionDecision decideWhileDisabled({
    required CallV2DeveloperRtcPermissionAction action,
    required int generation,
    int? latestGeneration,
    CallV2DeveloperSanitizedPermissionResult? permissionResult,
    CallV2DeveloperSanitizedRtcEvent? rtcEvent,
    bool disposed = false,
    bool terminal = false,
    bool missingCredential = false,
    bool mediaUnavailable = false,
    bool rawPayloadProvided = false,
    bool controlledFailure = false,
  }) {
    if (disposed) {
      return CallV2DeveloperRtcPermissionDecision.rejected(
        action: action,
        generation: generation,
        permissionResult: permissionResult,
        rtcEvent: rtcEvent,
        rejection: CallV2DeveloperRtcPermissionRejection.disposed,
      );
    }
    if (rawPayloadProvided) {
      return CallV2DeveloperRtcPermissionDecision.rejected(
        action: action,
        generation: generation,
        permissionResult: permissionResult,
        rtcEvent: rtcEvent,
        rejection: CallV2DeveloperRtcPermissionRejection.rawPayloadRejected,
      );
    }
    if (missingCredential) {
      return CallV2DeveloperRtcPermissionDecision.rejected(
        action: action,
        generation: generation,
        permissionResult: permissionResult,
        rtcEvent: rtcEvent,
        rejection: CallV2DeveloperRtcPermissionRejection.missingCredential,
      );
    }
    if (mediaUnavailable) {
      return CallV2DeveloperRtcPermissionDecision.rejected(
        action: action,
        generation: generation,
        permissionResult: permissionResult,
        rtcEvent: rtcEvent,
        rejection: CallV2DeveloperRtcPermissionRejection.mediaUnavailable,
      );
    }
    final permissionRejection = _permissionRejection(permissionResult);
    if (permissionRejection != null) {
      return CallV2DeveloperRtcPermissionDecision.rejected(
        action: action,
        generation: generation,
        permissionResult: permissionResult,
        rtcEvent: rtcEvent,
        rejection: permissionRejection,
      );
    }
    if (controlledFailure) {
      return CallV2DeveloperRtcPermissionDecision.rejected(
        action: action,
        generation: generation,
        permissionResult: permissionResult,
        rtcEvent: rtcEvent,
        rejection: CallV2DeveloperRtcPermissionRejection.controlledFailure,
      );
    }
    if (_isRtcFailure(rtcEvent)) {
      return CallV2DeveloperRtcPermissionDecision.rejected(
        action: action,
        generation: generation,
        permissionResult: permissionResult,
        rtcEvent: rtcEvent,
        rejection: CallV2DeveloperRtcPermissionRejection.rtcFailure,
      );
    }
    if (terminal || _isTerminalRtcEvent(rtcEvent)) {
      return CallV2DeveloperRtcPermissionDecision.detached(
        action: action,
        generation: generation,
        rtcEvent: rtcEvent,
        rejection:
            terminal ? CallV2DeveloperRtcPermissionRejection.terminal : null,
      );
    }
    if (latestGeneration != null && generation < latestGeneration) {
      return CallV2DeveloperRtcPermissionDecision.staleIgnored(
        action: action,
        generation: generation,
        permissionResult: permissionResult,
        rtcEvent: rtcEvent,
      );
    }
    if (latestGeneration != null && generation == latestGeneration) {
      return CallV2DeveloperRtcPermissionDecision.duplicateNoOp(
        action: action,
        generation: generation,
        permissionResult: permissionResult,
        rtcEvent: rtcEvent,
      );
    }
    return CallV2DeveloperRtcPermissionDecision.disabledInert(
      action: action,
      generation: generation,
      permissionResult: permissionResult,
      rtcEvent: rtcEvent,
    );
  }

  CallV2DeveloperRtcPermissionRejection? _permissionRejection(
    CallV2DeveloperSanitizedPermissionResult? result,
  ) {
    switch (result) {
      case CallV2DeveloperSanitizedPermissionResult.microphoneDenied:
      case CallV2DeveloperSanitizedPermissionResult.cameraDenied:
        return CallV2DeveloperRtcPermissionRejection.permissionDenied;
      case CallV2DeveloperSanitizedPermissionResult.microphonePermanentlyDenied:
      case CallV2DeveloperSanitizedPermissionResult.cameraPermanentlyDenied:
        return CallV2DeveloperRtcPermissionRejection
            .permissionPermanentlyDenied;
      case CallV2DeveloperSanitizedPermissionResult.permissionUnavailable:
        return CallV2DeveloperRtcPermissionRejection.mediaUnavailable;
      case CallV2DeveloperSanitizedPermissionResult.microphoneGranted:
      case CallV2DeveloperSanitizedPermissionResult.cameraGranted:
      case null:
        return null;
    }
  }

  bool _isTerminalRtcEvent(CallV2DeveloperSanitizedRtcEvent? event) {
    return event == CallV2DeveloperSanitizedRtcEvent.rtcLeft ||
        event == CallV2DeveloperSanitizedRtcEvent.rtcTimeout;
  }

  bool _isRtcFailure(CallV2DeveloperSanitizedRtcEvent? event) {
    return event == CallV2DeveloperSanitizedRtcEvent.rtcFailure;
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'statusCount': status.length,
      'actionCount': actions.length,
      'permissionResultCount': sanitizedPermissionResults.length,
      'rtcEventCount': sanitizedRtcEvents.length,
      'ownershipRuleCount': ownershipRules.length,
      'rollbackRequirementCount': rollbackRequirements.length,
      'developerOnly': isDeveloperOnly,
      'hardDisabled': isHardDisabled,
      'rolloutEnabled': isRolloutEnabled,
      'reachable': isReachable,
      'attachesRtcPermission': attachesRtcPermission,
      'importsRtcPermissionPackages': importsRtcPermissionPackages,
      'initializesRtcEngine': initializesRtcEngine,
      'joinsRtc': joinsRtcChannel,
      'usesCredentialMaterial': consumesRtcCredentialMaterial,
      'promptsForPermissions': promptsForPermissions,
      'enumeratesDevices': enumeratesDevices,
      'capturesMedia': capturesMedia,
      'publishesAudioVideo': publishesAudioVideo,
      'opensRtcCallbacksOrSubscriptions': opensRtcCallbacksOrSubscriptions,
      'constructsRuntime': constructsRuntime,
      'startsRuntime': startsRuntime,
      'accessesBackendServices': accessesBackendServices,
      'constructsComposition': constructsComposition,
      'wiresStartupBridge': wiresStartupBridge,
      'mutatesRouteRegistry': mutatesRouteRegistry,
      'accessesNavigation': accessesNavigation,
      'opensAsyncHandles': opensAsyncHandles,
      'changesPubspecPlatformConfig': changesPubspecPlatformConfig,
      'deploymentApproved': isDeploymentApproved,
      'protectsV1': protectsV1,
    };
  }

  @override
  String toString() {
    return 'CallV2DeveloperRtcPermissionOwnerSkeleton(${toSafeDebugMap()})';
  }
}

final callV2DeveloperRtcPermissionOwnerSkeleton =
    CallV2DeveloperRtcPermissionOwnerSkeleton(
  status: <CallV2DeveloperRtcPermissionOwnerSkeletonStatus>[
    CallV2DeveloperRtcPermissionOwnerSkeletonStatus.developerOnly,
    CallV2DeveloperRtcPermissionOwnerSkeletonStatus.hardDisabled,
    CallV2DeveloperRtcPermissionOwnerSkeletonStatus.rolloutFalse,
    CallV2DeveloperRtcPermissionOwnerSkeletonStatus.callV2Unreachable,
    CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noRtcPermissionAttach,
    CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noRtcPermissionImports,
    CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noRtcEngineInitialization,
    CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noRtcChannelJoin,
    CallV2DeveloperRtcPermissionOwnerSkeletonStatus
        .noRtcTokenChannelConsumption,
    CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noPermissionPrompt,
    CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noDeviceEnumeration,
    CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noMediaCapture,
    CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noAudioVideoPublish,
    CallV2DeveloperRtcPermissionOwnerSkeletonStatus
        .noRtcCallbacksOrSubscriptions,
    CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noRuntimeConstruction,
    CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noRuntimeStart,
    CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noBackendServiceAccess,
    CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noCompositionConstruction,
    CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noStartupBridgeWiring,
    CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noRouteRegistryMutation,
    CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noNavigationAccess,
    CallV2DeveloperRtcPermissionOwnerSkeletonStatus.noAsyncHandles,
    CallV2DeveloperRtcPermissionOwnerSkeletonStatus
        .noPubspecPlatformConfigChanges,
    CallV2DeveloperRtcPermissionOwnerSkeletonStatus.deploymentNotApproved,
    CallV2DeveloperRtcPermissionOwnerSkeletonStatus.v1Protected,
  ],
  actions: <CallV2DeveloperRtcPermissionAction>[
    CallV2DeveloperRtcPermissionAction.prepareRtcPermissionOwner,
    CallV2DeveloperRtcPermissionAction.requestPermissionGate,
    CallV2DeveloperRtcPermissionAction.receiveSanitizedPermissionResult,
    CallV2DeveloperRtcPermissionAction.requestRtcAttach,
    CallV2DeveloperRtcPermissionAction.receiveSanitizedRtcEvent,
    CallV2DeveloperRtcPermissionAction.detachRtcOwner,
    CallV2DeveloperRtcPermissionAction.disposeRtcOwner,
  ],
  sanitizedPermissionResults: <CallV2DeveloperSanitizedPermissionResult>[
    CallV2DeveloperSanitizedPermissionResult.microphoneGranted,
    CallV2DeveloperSanitizedPermissionResult.microphoneDenied,
    CallV2DeveloperSanitizedPermissionResult.microphonePermanentlyDenied,
    CallV2DeveloperSanitizedPermissionResult.cameraGranted,
    CallV2DeveloperSanitizedPermissionResult.cameraDenied,
    CallV2DeveloperSanitizedPermissionResult.cameraPermanentlyDenied,
    CallV2DeveloperSanitizedPermissionResult.permissionUnavailable,
  ],
  sanitizedRtcEvents: <CallV2DeveloperSanitizedRtcEvent>[
    CallV2DeveloperSanitizedRtcEvent.rtcPrepared,
    CallV2DeveloperSanitizedRtcEvent.rtcConnecting,
    CallV2DeveloperSanitizedRtcEvent.rtcJoined,
    CallV2DeveloperSanitizedRtcEvent.rtcReconnecting,
    CallV2DeveloperSanitizedRtcEvent.rtcRemoteJoined,
    CallV2DeveloperSanitizedRtcEvent.rtcRemoteLeft,
    CallV2DeveloperSanitizedRtcEvent.rtcLeaving,
    CallV2DeveloperSanitizedRtcEvent.rtcLeft,
    CallV2DeveloperSanitizedRtcEvent.rtcFailure,
    CallV2DeveloperSanitizedRtcEvent.rtcTimeout,
  ],
  ownershipRules: <CallV2DeveloperRtcPermissionOwnershipRule>[
    CallV2DeveloperRtcPermissionOwnershipRule.explicitHumanApprovalRequired,
    CallV2DeveloperRtcPermissionOwnershipRule.developerOnlyAllowlistRequired,
    CallV2DeveloperRtcPermissionOwnershipRule
        .rolloutFalseBlocksRtcPermissionAttach,
    CallV2DeveloperRtcPermissionOwnershipRule.noRtcPermissionImports,
    CallV2DeveloperRtcPermissionOwnershipRule.noRtcEngineInitialization,
    CallV2DeveloperRtcPermissionOwnershipRule.noRtcChannelJoin,
    CallV2DeveloperRtcPermissionOwnershipRule.noRtcTokenChannelConsumption,
    CallV2DeveloperRtcPermissionOwnershipRule.noPermissionPrompt,
    CallV2DeveloperRtcPermissionOwnershipRule.noDeviceEnumeration,
    CallV2DeveloperRtcPermissionOwnershipRule.noMediaCapture,
    CallV2DeveloperRtcPermissionOwnershipRule.noAudioVideoPublish,
    CallV2DeveloperRtcPermissionOwnershipRule.noRtcCallbacksOrSubscriptions,
    CallV2DeveloperRtcPermissionOwnershipRule
        .sanitizedEnumBooleanGenerationOnly,
    CallV2DeveloperRtcPermissionOwnershipRule.duplicateRtcEventNoOp,
    CallV2DeveloperRtcPermissionOwnershipRule.staleRtcEventIgnored,
    CallV2DeveloperRtcPermissionOwnershipRule.permissionDeniedControlledFailure,
    CallV2DeveloperRtcPermissionOwnershipRule
        .permanentlyDeniedRequiresUserAction,
    CallV2DeveloperRtcPermissionOwnershipRule.missingCredentialRejected,
    CallV2DeveloperRtcPermissionOwnershipRule.terminalRtcEventDetaches,
    CallV2DeveloperRtcPermissionOwnershipRule.mediaFailureControlledOnly,
  ],
  rollbackRequirements: <CallV2DeveloperRtcPermissionRollback>[
    CallV2DeveloperRtcPermissionRollback.oneCommitRevert,
    CallV2DeveloperRtcPermissionRollback.keepRolloutFalse,
    CallV2DeveloperRtcPermissionRollback.keepRouteRegistryNull,
    CallV2DeveloperRtcPermissionRollback.keepDisabledOwnerInert,
    CallV2DeveloperRtcPermissionRollback.noDeploymentRequired,
    CallV2DeveloperRtcPermissionRollback.noPubspecPlatformConfigChanges,
    CallV2DeveloperRtcPermissionRollback.v1Unaffected,
  ],
);
