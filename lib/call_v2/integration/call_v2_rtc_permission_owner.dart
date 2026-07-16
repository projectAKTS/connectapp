enum CallV2RtcPermissionOwnerStatus {
  developerOnly,
  hardDisabled,
  rolloutFalse,
  unreachable,
  noRtcPermissionImports,
  noRtcEngineCreation,
  noRtcChannelJoin,
  noRtcTokenChannelConsumption,
  noPermissionRequest,
  noMicrophoneCameraPrompt,
  noDeviceEnumeration,
  noMediaCapture,
  noCameraPreview,
  noAudioVideoPublish,
  noRtcCallbacksListenersSubscriptions,
  noRuntimeConstruction,
  noRuntimeStart,
  noBackendFirebaseAccess,
  noNavigationAccess,
  noLifecycleRegistration,
  noRouteRegistryMutation,
  noAsyncHandles,
  noPubspecPlatformConfigChanges,
  noDeployment,
  v1Protected,
}

enum CallV2RtcPermissionOwnerAction {
  prepareRtcPermissionOwner,
  requestMicrophone,
  requestCamera,
  prepareRtcEngine,
  joinRtcChannel,
  publishAudio,
  publishVideo,
  enumerateDevices,
  disposeRtc,
}

enum CallV2SanitizedPermissionResult {
  microphoneGranted,
  cameraGranted,
  microphoneDenied,
  cameraDenied,
  permissionUnknown,
}

enum CallV2SanitizedRtcEvent {
  rtcPrepared,
  rtcJoined,
  rtcPublishing,
  rtcEnded,
  rtcFailed,
  rtcUnknown,
}

enum CallV2RtcPermissionOwnerDecisionKind {
  disabledInert,
  duplicateNoOp,
  staleIgnored,
  permissionDeniedRejected,
  unsafeTransitionRejected,
  ownershipRejected,
  rawDeviceRejected,
  terminalIgnored,
}

enum CallV2RtcPermissionOwnerRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2RtcPermissionOwnerDecision {
  const CallV2RtcPermissionOwnerDecision({
    required this.kind,
    required this.action,
    required this.generation,
    this.latestGeneration,
    this.permissionResult,
    this.rtcEvent,
    this.previousRtcEvent,
  });

  final CallV2RtcPermissionOwnerDecisionKind kind;
  final CallV2RtcPermissionOwnerAction action;
  final int generation;
  final int? latestGeneration;
  final CallV2SanitizedPermissionResult? permissionResult;
  final CallV2SanitizedRtcEvent? rtcEvent;
  final CallV2SanitizedRtcEvent? previousRtcEvent;

  bool get importsRtcPermissionPackages => false;
  bool get createsRtcEngine => false;
  bool get joinsRtcChannel => false;
  bool get consumesRtcTokenChannel => false;
  bool get requestsPermission => false;
  bool get promptsMicrophoneCamera => false;
  bool get enumeratesDevices => false;
  bool get capturesMedia => false;
  bool get startsCameraPreview => false;
  bool get publishesAudioVideo => false;
  bool get opensRtcCallbacksListenersSubscriptions => false;
  bool get constructsRuntime => false;
  bool get startsRuntime => false;
  bool get accessesBackendFirebase => false;
  bool get accessesNavigation => false;
  bool get registersLifecycleObserver => false;
  bool get mutatesRouteRegistry => false;
  bool get opensAsyncHandles => false;
  bool get changesPubspecPlatformConfig => false;
  bool get mutatesV1State => false;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'kind': kind.name,
      'actionKnown': true,
      'generationKnown': generation >= 0,
      'latestGenerationKnown': latestGeneration != null,
      'hasPermissionResult': permissionResult != null,
      'hasRtcEvent': rtcEvent != null,
      'hasPreviousRtcEvent': previousRtcEvent != null,
      'importsProviderPackages': importsRtcPermissionPackages,
      'createsMediaEngine': createsRtcEngine,
      'joinsMediaSession': joinsRtcChannel,
      'usesCredentialMaterial': consumesRtcTokenChannel,
      'requestsPermission': requestsPermission,
      'promptsMicrophoneCamera': promptsMicrophoneCamera,
      'enumeratesDevices': enumeratesDevices,
      'capturesMedia': capturesMedia,
      'startsCameraPreview': startsCameraPreview,
      'publishesAudioVideo': publishesAudioVideo,
      'opensProviderCallbacks': opensRtcCallbacksListenersSubscriptions,
      'constructsRuntime': constructsRuntime,
      'startsRuntime': startsRuntime,
      'accessesBackend': accessesBackendFirebase,
      'accessesNavigation': accessesNavigation,
      'registersLifecycleObserver': registersLifecycleObserver,
      'mutatesRouteRegistry': mutatesRouteRegistry,
      'opensAsyncHandles': opensAsyncHandles,
      'changesPubspecPlatformConfig': changesPubspecPlatformConfig,
      'mutatesV1State': mutatesV1State,
    };
  }

  @override
  String toString() {
    return 'CallV2RtcPermissionOwnerDecision(${toSafeDebugMap()})';
  }
}

final class CallV2RtcPermissionOwnerBoundary {
  factory CallV2RtcPermissionOwnerBoundary({
    required List<CallV2RtcPermissionOwnerStatus> statuses,
    required List<CallV2RtcPermissionOwnerAction> actions,
    required List<CallV2SanitizedPermissionResult> permissionResults,
    required List<CallV2SanitizedRtcEvent> rtcEvents,
    required List<CallV2RtcPermissionOwnerRollback> rollback,
  }) {
    return CallV2RtcPermissionOwnerBoundary._(
      List<CallV2RtcPermissionOwnerStatus>.unmodifiable(statuses),
      List<CallV2RtcPermissionOwnerAction>.unmodifiable(actions),
      List<CallV2SanitizedPermissionResult>.unmodifiable(permissionResults),
      List<CallV2SanitizedRtcEvent>.unmodifiable(rtcEvents),
      List<CallV2RtcPermissionOwnerRollback>.unmodifiable(rollback),
    );
  }

  const CallV2RtcPermissionOwnerBoundary._(
    this.statuses,
    this.actions,
    this.permissionResults,
    this.rtcEvents,
    this.rollback,
  );

  final List<CallV2RtcPermissionOwnerStatus> statuses;
  final List<CallV2RtcPermissionOwnerAction> actions;
  final List<CallV2SanitizedPermissionResult> permissionResults;
  final List<CallV2SanitizedRtcEvent> rtcEvents;
  final List<CallV2RtcPermissionOwnerRollback> rollback;

  bool get isDeveloperOnly => statuses.contains(
        CallV2RtcPermissionOwnerStatus.developerOnly,
      );

  bool get isHardDisabled => statuses.contains(
        CallV2RtcPermissionOwnerStatus.hardDisabled,
      );

  bool get isRolloutEnabled => !statuses.contains(
        CallV2RtcPermissionOwnerStatus.rolloutFalse,
      );

  bool get isReachable => !statuses.contains(
        CallV2RtcPermissionOwnerStatus.unreachable,
      );

  bool get importsRtcPermissionPackages => !statuses.contains(
        CallV2RtcPermissionOwnerStatus.noRtcPermissionImports,
      );

  bool get createsRtcEngine => !statuses.contains(
        CallV2RtcPermissionOwnerStatus.noRtcEngineCreation,
      );

  bool get joinsRtcChannel => !statuses.contains(
        CallV2RtcPermissionOwnerStatus.noRtcChannelJoin,
      );

  bool get consumesRtcTokenChannel => !statuses.contains(
        CallV2RtcPermissionOwnerStatus.noRtcTokenChannelConsumption,
      );

  bool get requestsPermission => !statuses.contains(
        CallV2RtcPermissionOwnerStatus.noPermissionRequest,
      );

  bool get promptsMicrophoneCamera => !statuses.contains(
        CallV2RtcPermissionOwnerStatus.noMicrophoneCameraPrompt,
      );

  bool get enumeratesDevices => !statuses.contains(
        CallV2RtcPermissionOwnerStatus.noDeviceEnumeration,
      );

  bool get capturesMedia => !statuses.contains(
        CallV2RtcPermissionOwnerStatus.noMediaCapture,
      );

  bool get startsCameraPreview => !statuses.contains(
        CallV2RtcPermissionOwnerStatus.noCameraPreview,
      );

  bool get publishesAudioVideo => !statuses.contains(
        CallV2RtcPermissionOwnerStatus.noAudioVideoPublish,
      );

  bool get opensRtcCallbacksListenersSubscriptions => !statuses.contains(
        CallV2RtcPermissionOwnerStatus.noRtcCallbacksListenersSubscriptions,
      );

  bool get constructsRuntime => !statuses.contains(
        CallV2RtcPermissionOwnerStatus.noRuntimeConstruction,
      );

  bool get startsRuntime => !statuses.contains(
        CallV2RtcPermissionOwnerStatus.noRuntimeStart,
      );

  bool get accessesBackendFirebase => !statuses.contains(
        CallV2RtcPermissionOwnerStatus.noBackendFirebaseAccess,
      );

  bool get accessesNavigation => !statuses.contains(
        CallV2RtcPermissionOwnerStatus.noNavigationAccess,
      );

  bool get registersLifecycleObserver => !statuses.contains(
        CallV2RtcPermissionOwnerStatus.noLifecycleRegistration,
      );

  bool get mutatesRouteRegistry => !statuses.contains(
        CallV2RtcPermissionOwnerStatus.noRouteRegistryMutation,
      );

  bool get opensAsyncHandles => !statuses.contains(
        CallV2RtcPermissionOwnerStatus.noAsyncHandles,
      );

  bool get changesPubspecPlatformConfig => !statuses.contains(
        CallV2RtcPermissionOwnerStatus.noPubspecPlatformConfigChanges,
      );

  bool get isDeploymentApproved => !statuses.contains(
        CallV2RtcPermissionOwnerStatus.noDeployment,
      );

  bool get protectsV1 => statuses.contains(
        CallV2RtcPermissionOwnerStatus.v1Protected,
      );

  bool get rollbackPreserved =>
      rollback.contains(CallV2RtcPermissionOwnerRollback.oneCommitRevert) &&
      rollback.contains(CallV2RtcPermissionOwnerRollback.keepRolloutFalse) &&
      rollback
          .contains(CallV2RtcPermissionOwnerRollback.keepRouteRegistryNull) &&
      rollback.contains(
        CallV2RtcPermissionOwnerRollback.keepDisabledOwnerInert,
      ) &&
      rollback
          .contains(CallV2RtcPermissionOwnerRollback.noDeploymentRequired) &&
      rollback.contains(CallV2RtcPermissionOwnerRollback.noConfigChanges) &&
      rollback.contains(CallV2RtcPermissionOwnerRollback.v1Unaffected);

  bool get isStrictlyClosed =>
      isDeveloperOnly &&
      isHardDisabled &&
      !isRolloutEnabled &&
      !isReachable &&
      !importsRtcPermissionPackages &&
      !createsRtcEngine &&
      !joinsRtcChannel &&
      !consumesRtcTokenChannel &&
      !requestsPermission &&
      !promptsMicrophoneCamera &&
      !enumeratesDevices &&
      !capturesMedia &&
      !startsCameraPreview &&
      !publishesAudioVideo &&
      !opensRtcCallbacksListenersSubscriptions &&
      !constructsRuntime &&
      !startsRuntime &&
      !accessesBackendFirebase &&
      !accessesNavigation &&
      !registersLifecycleObserver &&
      !mutatesRouteRegistry &&
      !opensAsyncHandles &&
      !changesPubspecPlatformConfig &&
      !isDeploymentApproved &&
      protectsV1 &&
      rollbackPreserved;

  CallV2RtcPermissionOwnerDecision decideWhileDisabled({
    required CallV2RtcPermissionOwnerAction action,
    required int generation,
    int? latestGeneration,
    CallV2SanitizedPermissionResult? permissionResult,
    CallV2SanitizedRtcEvent? rtcEvent,
    CallV2SanitizedRtcEvent? previousRtcEvent,
    bool ownershipMatches = true,
    bool rawDeviceProvided = false,
    bool terminal = false,
  }) {
    final kind = _decisionKindFor(
      generation: generation,
      latestGeneration: latestGeneration,
      permissionResult: permissionResult,
      rtcEvent: rtcEvent,
      previousRtcEvent: previousRtcEvent,
      ownershipMatches: ownershipMatches,
      rawDeviceProvided: rawDeviceProvided,
      terminal: terminal,
    );

    return CallV2RtcPermissionOwnerDecision(
      kind: kind,
      action: action,
      generation: generation,
      latestGeneration: latestGeneration,
      permissionResult: permissionResult,
      rtcEvent: rtcEvent,
      previousRtcEvent: previousRtcEvent,
    );
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'statusCount': statuses.length,
      'actionCount': actions.length,
      'permissionResultCount': permissionResults.length,
      'rtcEventCount': rtcEvents.length,
      'rollbackCount': rollback.length,
      'developerOnly': isDeveloperOnly,
      'hardDisabled': isHardDisabled,
      'rolloutEnabled': isRolloutEnabled,
      'reachable': isReachable,
      'importsProviderPackages': importsRtcPermissionPackages,
      'createsMediaEngine': createsRtcEngine,
      'joinsMediaSession': joinsRtcChannel,
      'usesCredentialMaterial': consumesRtcTokenChannel,
      'requestsPermission': requestsPermission,
      'promptsMicrophoneCamera': promptsMicrophoneCamera,
      'enumeratesDevices': enumeratesDevices,
      'capturesMedia': capturesMedia,
      'startsCameraPreview': startsCameraPreview,
      'publishesAudioVideo': publishesAudioVideo,
      'opensProviderCallbacks': opensRtcCallbacksListenersSubscriptions,
      'constructsRuntime': constructsRuntime,
      'startsRuntime': startsRuntime,
      'accessesBackend': accessesBackendFirebase,
      'accessesNavigation': accessesNavigation,
      'registersLifecycleObserver': registersLifecycleObserver,
      'mutatesRouteRegistry': mutatesRouteRegistry,
      'opensAsyncHandles': opensAsyncHandles,
      'changesPubspecPlatformConfig': changesPubspecPlatformConfig,
      'deploymentApproved': isDeploymentApproved,
      'rollbackPreserved': rollbackPreserved,
      'protectsV1': protectsV1,
      'strictlyClosed': isStrictlyClosed,
    };
  }

  @override
  String toString() {
    return 'CallV2RtcPermissionOwnerBoundary(${toSafeDebugMap()})';
  }
}

CallV2RtcPermissionOwnerDecisionKind _decisionKindFor({
  required int generation,
  required int? latestGeneration,
  required CallV2SanitizedPermissionResult? permissionResult,
  required CallV2SanitizedRtcEvent? rtcEvent,
  required CallV2SanitizedRtcEvent? previousRtcEvent,
  required bool ownershipMatches,
  required bool rawDeviceProvided,
  required bool terminal,
}) {
  if (terminal) return CallV2RtcPermissionOwnerDecisionKind.terminalIgnored;
  if (!ownershipMatches) {
    return CallV2RtcPermissionOwnerDecisionKind.ownershipRejected;
  }
  if (rawDeviceProvided) {
    return CallV2RtcPermissionOwnerDecisionKind.rawDeviceRejected;
  }
  if (latestGeneration != null && generation < latestGeneration) {
    return CallV2RtcPermissionOwnerDecisionKind.staleIgnored;
  }
  if (latestGeneration != null && generation == latestGeneration) {
    return CallV2RtcPermissionOwnerDecisionKind.duplicateNoOp;
  }
  if (_permissionDenied(permissionResult)) {
    return CallV2RtcPermissionOwnerDecisionKind.permissionDeniedRejected;
  }
  if (_unsafeTransition(previousRtcEvent, rtcEvent)) {
    return CallV2RtcPermissionOwnerDecisionKind.unsafeTransitionRejected;
  }
  return CallV2RtcPermissionOwnerDecisionKind.disabledInert;
}

bool _permissionDenied(CallV2SanitizedPermissionResult? result) {
  return result == CallV2SanitizedPermissionResult.microphoneDenied ||
      result == CallV2SanitizedPermissionResult.cameraDenied;
}

bool _unsafeTransition(
  CallV2SanitizedRtcEvent? previous,
  CallV2SanitizedRtcEvent? current,
) {
  if (previous == null || current == null) return false;
  return _eventRank(current) < _eventRank(previous);
}

int _eventRank(CallV2SanitizedRtcEvent event) {
  return switch (event) {
    CallV2SanitizedRtcEvent.rtcUnknown => 0,
    CallV2SanitizedRtcEvent.rtcPrepared => 1,
    CallV2SanitizedRtcEvent.rtcJoined => 2,
    CallV2SanitizedRtcEvent.rtcPublishing => 3,
    CallV2SanitizedRtcEvent.rtcEnded => 4,
    CallV2SanitizedRtcEvent.rtcFailed => 4,
  };
}

final callV2RtcPermissionOwnerBoundary = CallV2RtcPermissionOwnerBoundary(
  statuses: <CallV2RtcPermissionOwnerStatus>[
    CallV2RtcPermissionOwnerStatus.developerOnly,
    CallV2RtcPermissionOwnerStatus.hardDisabled,
    CallV2RtcPermissionOwnerStatus.rolloutFalse,
    CallV2RtcPermissionOwnerStatus.unreachable,
    CallV2RtcPermissionOwnerStatus.noRtcPermissionImports,
    CallV2RtcPermissionOwnerStatus.noRtcEngineCreation,
    CallV2RtcPermissionOwnerStatus.noRtcChannelJoin,
    CallV2RtcPermissionOwnerStatus.noRtcTokenChannelConsumption,
    CallV2RtcPermissionOwnerStatus.noPermissionRequest,
    CallV2RtcPermissionOwnerStatus.noMicrophoneCameraPrompt,
    CallV2RtcPermissionOwnerStatus.noDeviceEnumeration,
    CallV2RtcPermissionOwnerStatus.noMediaCapture,
    CallV2RtcPermissionOwnerStatus.noCameraPreview,
    CallV2RtcPermissionOwnerStatus.noAudioVideoPublish,
    CallV2RtcPermissionOwnerStatus.noRtcCallbacksListenersSubscriptions,
    CallV2RtcPermissionOwnerStatus.noRuntimeConstruction,
    CallV2RtcPermissionOwnerStatus.noRuntimeStart,
    CallV2RtcPermissionOwnerStatus.noBackendFirebaseAccess,
    CallV2RtcPermissionOwnerStatus.noNavigationAccess,
    CallV2RtcPermissionOwnerStatus.noLifecycleRegistration,
    CallV2RtcPermissionOwnerStatus.noRouteRegistryMutation,
    CallV2RtcPermissionOwnerStatus.noAsyncHandles,
    CallV2RtcPermissionOwnerStatus.noPubspecPlatformConfigChanges,
    CallV2RtcPermissionOwnerStatus.noDeployment,
    CallV2RtcPermissionOwnerStatus.v1Protected,
  ],
  actions: <CallV2RtcPermissionOwnerAction>[
    CallV2RtcPermissionOwnerAction.prepareRtcPermissionOwner,
    CallV2RtcPermissionOwnerAction.requestMicrophone,
    CallV2RtcPermissionOwnerAction.requestCamera,
    CallV2RtcPermissionOwnerAction.prepareRtcEngine,
    CallV2RtcPermissionOwnerAction.joinRtcChannel,
    CallV2RtcPermissionOwnerAction.publishAudio,
    CallV2RtcPermissionOwnerAction.publishVideo,
    CallV2RtcPermissionOwnerAction.enumerateDevices,
    CallV2RtcPermissionOwnerAction.disposeRtc,
  ],
  permissionResults: <CallV2SanitizedPermissionResult>[
    CallV2SanitizedPermissionResult.microphoneGranted,
    CallV2SanitizedPermissionResult.cameraGranted,
    CallV2SanitizedPermissionResult.microphoneDenied,
    CallV2SanitizedPermissionResult.cameraDenied,
    CallV2SanitizedPermissionResult.permissionUnknown,
  ],
  rtcEvents: <CallV2SanitizedRtcEvent>[
    CallV2SanitizedRtcEvent.rtcPrepared,
    CallV2SanitizedRtcEvent.rtcJoined,
    CallV2SanitizedRtcEvent.rtcPublishing,
    CallV2SanitizedRtcEvent.rtcEnded,
    CallV2SanitizedRtcEvent.rtcFailed,
    CallV2SanitizedRtcEvent.rtcUnknown,
  ],
  rollback: <CallV2RtcPermissionOwnerRollback>[
    CallV2RtcPermissionOwnerRollback.oneCommitRevert,
    CallV2RtcPermissionOwnerRollback.keepRolloutFalse,
    CallV2RtcPermissionOwnerRollback.keepRouteRegistryNull,
    CallV2RtcPermissionOwnerRollback.keepDisabledOwnerInert,
    CallV2RtcPermissionOwnerRollback.noDeploymentRequired,
    CallV2RtcPermissionOwnerRollback.noConfigChanges,
    CallV2RtcPermissionOwnerRollback.v1Unaffected,
  ],
);
