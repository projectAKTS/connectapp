import 'call_v2_rollout_policy.dart';
import 'call_v2_rtc_permission_owner.dart';

enum CallV2RtcPermissionOwnerHardeningAuditStatus {
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
  actionsExact,
  permissionResultsExact,
  rtcEventsExact,
  defaultDecisionsInert,
  duplicateDecisionNoOp,
  staleDecisionIgnored,
  permissionDeniedRejected,
  unsafeTransitionRejected,
  ownershipMismatchRejected,
  rawDeviceRejected,
  terminalDecisionIgnored,
  safeDebugOnly,
  routeRegistryNullWhileFalse,
  disabledOwnerInert,
  rollbackOneCommit,
  v1Protected,
}

enum CallV2RtcPermissionOwnerHardeningAuditDecision {
  pass,
  blocked,
}

enum CallV2RtcPermissionOwnerHardeningRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2RtcPermissionOwnerHardeningAudit {
  factory CallV2RtcPermissionOwnerHardeningAudit({
    required CallV2RtcPermissionOwnerBoundary boundary,
    required List<CallV2RtcPermissionOwnerHardeningAuditStatus> statuses,
    required List<CallV2RtcPermissionOwnerHardeningRollback> rollback,
  }) {
    return CallV2RtcPermissionOwnerHardeningAudit._(
      boundary,
      List<CallV2RtcPermissionOwnerHardeningAuditStatus>.unmodifiable(
        statuses,
      ),
      List<CallV2RtcPermissionOwnerHardeningRollback>.unmodifiable(rollback),
    );
  }

  const CallV2RtcPermissionOwnerHardeningAudit._(
    this.boundary,
    this.statuses,
    this.rollback,
  );

  final CallV2RtcPermissionOwnerBoundary boundary;
  final List<CallV2RtcPermissionOwnerHardeningAuditStatus> statuses;
  final List<CallV2RtcPermissionOwnerHardeningRollback> rollback;

  CallV2RtcPermissionOwnerHardeningAuditDecision get decision {
    return passes
        ? CallV2RtcPermissionOwnerHardeningAuditDecision.pass
        : CallV2RtcPermissionOwnerHardeningAuditDecision.blocked;
  }

  bool get passes =>
      recordsDeveloperOnly &&
      recordsHardDisabled &&
      recordsRolloutFalse &&
      recordsUnreachable &&
      recordsNoRtcPermissionImports &&
      recordsNoRtcEngineCreation &&
      recordsNoRtcChannelJoin &&
      recordsNoRtcTokenChannelConsumption &&
      recordsNoPermissionRequest &&
      recordsNoMicrophoneCameraPrompt &&
      recordsNoDeviceEnumeration &&
      recordsNoMediaCapture &&
      recordsNoCameraPreview &&
      recordsNoAudioVideoPublish &&
      recordsNoRtcCallbacksListenersSubscriptions &&
      recordsNoRuntimeConstruction &&
      recordsNoRuntimeStart &&
      recordsNoBackendFirebaseAccess &&
      recordsNoNavigationAccess &&
      recordsNoLifecycleRegistration &&
      recordsNoRouteRegistryMutation &&
      recordsNoAsyncHandles &&
      recordsNoPubspecPlatformConfigChanges &&
      recordsNoDeployment &&
      actionsAreExact &&
      permissionResultsAreExact &&
      rtcEventsAreExact &&
      defaultDecisionsAreInert &&
      duplicateDecisionIsNoOp &&
      staleDecisionIsIgnored &&
      permissionDeniedIsRejected &&
      unsafeTransitionIsRejected &&
      ownershipMismatchIsRejected &&
      rawDeviceIsRejected &&
      terminalDecisionIsIgnored &&
      recordsSafeDebugOnly &&
      recordsRouteRegistryNullWhileFalse &&
      recordsDisabledOwnerInert &&
      rollbackPreserved &&
      protectsV1;

  bool get recordsDeveloperOnly =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.developerOnly,
      ) &&
      boundary.isDeveloperOnly;

  bool get recordsHardDisabled =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.hardDisabled,
      ) &&
      boundary.isHardDisabled;

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      !boundary.isRolloutEnabled;

  bool get recordsUnreachable =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.unreachable,
      ) &&
      !boundary.isReachable;

  bool get recordsNoRtcPermissionImports =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.noRtcPermissionImports,
      ) &&
      !boundary.importsRtcPermissionPackages;

  bool get recordsNoRtcEngineCreation =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.noRtcEngineCreation,
      ) &&
      !boundary.createsRtcEngine;

  bool get recordsNoRtcChannelJoin =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.noRtcChannelJoin,
      ) &&
      !boundary.joinsRtcChannel;

  bool get recordsNoRtcTokenChannelConsumption =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus
            .noRtcTokenChannelConsumption,
      ) &&
      !boundary.consumesRtcTokenChannel;

  bool get recordsNoPermissionRequest =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.noPermissionRequest,
      ) &&
      !boundary.requestsPermission;

  bool get recordsNoMicrophoneCameraPrompt =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.noMicrophoneCameraPrompt,
      ) &&
      !boundary.promptsMicrophoneCamera;

  bool get recordsNoDeviceEnumeration =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.noDeviceEnumeration,
      ) &&
      !boundary.enumeratesDevices;

  bool get recordsNoMediaCapture =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.noMediaCapture,
      ) &&
      !boundary.capturesMedia;

  bool get recordsNoCameraPreview =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.noCameraPreview,
      ) &&
      !boundary.startsCameraPreview;

  bool get recordsNoAudioVideoPublish =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.noAudioVideoPublish,
      ) &&
      !boundary.publishesAudioVideo;

  bool get recordsNoRtcCallbacksListenersSubscriptions =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus
            .noRtcCallbacksListenersSubscriptions,
      ) &&
      !boundary.opensRtcCallbacksListenersSubscriptions;

  bool get recordsNoRuntimeConstruction =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.noRuntimeConstruction,
      ) &&
      !boundary.constructsRuntime;

  bool get recordsNoRuntimeStart =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.noRuntimeStart,
      ) &&
      !boundary.startsRuntime;

  bool get recordsNoBackendFirebaseAccess =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.noBackendFirebaseAccess,
      ) &&
      !boundary.accessesBackendFirebase;

  bool get recordsNoNavigationAccess =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.noNavigationAccess,
      ) &&
      !boundary.accessesNavigation;

  bool get recordsNoLifecycleRegistration =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.noLifecycleRegistration,
      ) &&
      !boundary.registersLifecycleObserver;

  bool get recordsNoRouteRegistryMutation =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.noRouteRegistryMutation,
      ) &&
      !boundary.mutatesRouteRegistry;

  bool get recordsNoAsyncHandles =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.noAsyncHandles,
      ) &&
      !boundary.opensAsyncHandles;

  bool get recordsNoPubspecPlatformConfigChanges =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus
            .noPubspecPlatformConfigChanges,
      ) &&
      !boundary.changesPubspecPlatformConfig;

  bool get recordsNoDeployment =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.noDeployment,
      ) &&
      !boundary.isDeploymentApproved;

  bool get actionsAreExact =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.actionsExact,
      ) &&
      boundary.actions.length == 9 &&
      boundary.actions[0] ==
          CallV2RtcPermissionOwnerAction.prepareRtcPermissionOwner &&
      boundary.actions[1] == CallV2RtcPermissionOwnerAction.requestMicrophone &&
      boundary.actions[2] == CallV2RtcPermissionOwnerAction.requestCamera &&
      boundary.actions[3] == CallV2RtcPermissionOwnerAction.prepareRtcEngine &&
      boundary.actions[4] == CallV2RtcPermissionOwnerAction.joinRtcChannel &&
      boundary.actions[5] == CallV2RtcPermissionOwnerAction.publishAudio &&
      boundary.actions[6] == CallV2RtcPermissionOwnerAction.publishVideo &&
      boundary.actions[7] == CallV2RtcPermissionOwnerAction.enumerateDevices &&
      boundary.actions[8] == CallV2RtcPermissionOwnerAction.disposeRtc;

  bool get permissionResultsAreExact =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.permissionResultsExact,
      ) &&
      boundary.permissionResults.length == 5 &&
      boundary.permissionResults[0] ==
          CallV2SanitizedPermissionResult.microphoneGranted &&
      boundary.permissionResults[1] ==
          CallV2SanitizedPermissionResult.cameraGranted &&
      boundary.permissionResults[2] ==
          CallV2SanitizedPermissionResult.microphoneDenied &&
      boundary.permissionResults[3] ==
          CallV2SanitizedPermissionResult.cameraDenied &&
      boundary.permissionResults[4] ==
          CallV2SanitizedPermissionResult.permissionUnknown;

  bool get rtcEventsAreExact =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.rtcEventsExact,
      ) &&
      boundary.rtcEvents.length == 6 &&
      boundary.rtcEvents[0] == CallV2SanitizedRtcEvent.rtcPrepared &&
      boundary.rtcEvents[1] == CallV2SanitizedRtcEvent.rtcJoined &&
      boundary.rtcEvents[2] == CallV2SanitizedRtcEvent.rtcPublishing &&
      boundary.rtcEvents[3] == CallV2SanitizedRtcEvent.rtcEnded &&
      boundary.rtcEvents[4] == CallV2SanitizedRtcEvent.rtcFailed &&
      boundary.rtcEvents[5] == CallV2SanitizedRtcEvent.rtcUnknown;

  bool get defaultDecisionsAreInert =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.defaultDecisionsInert,
      ) &&
      boundary.actions.every((action) {
        final decision = boundary.decideWhileDisabled(
          action: action,
          generation: boundary.actions.indexOf(action) + 1,
          permissionResult: CallV2SanitizedPermissionResult.microphoneGranted,
          rtcEvent: CallV2SanitizedRtcEvent.rtcPrepared,
        );
        return decision.kind ==
                CallV2RtcPermissionOwnerDecisionKind.disabledInert &&
            _decisionHasNoSideEffects(decision);
      });

  bool get duplicateDecisionIsNoOp =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.duplicateDecisionNoOp,
      ) &&
      _decisionMatches(
        boundary.decideWhileDisabled(
          action: CallV2RtcPermissionOwnerAction.prepareRtcPermissionOwner,
          generation: 2,
          latestGeneration: 2,
        ),
        CallV2RtcPermissionOwnerDecisionKind.duplicateNoOp,
      );

  bool get staleDecisionIsIgnored =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.staleDecisionIgnored,
      ) &&
      _decisionMatches(
        boundary.decideWhileDisabled(
          action: CallV2RtcPermissionOwnerAction.prepareRtcPermissionOwner,
          generation: 1,
          latestGeneration: 2,
        ),
        CallV2RtcPermissionOwnerDecisionKind.staleIgnored,
      );

  bool get permissionDeniedIsRejected =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.permissionDeniedRejected,
      ) &&
      _decisionMatches(
        boundary.decideWhileDisabled(
          action: CallV2RtcPermissionOwnerAction.requestMicrophone,
          generation: 3,
          permissionResult: CallV2SanitizedPermissionResult.microphoneDenied,
        ),
        CallV2RtcPermissionOwnerDecisionKind.permissionDeniedRejected,
      ) &&
      _decisionMatches(
        boundary.decideWhileDisabled(
          action: CallV2RtcPermissionOwnerAction.requestCamera,
          generation: 4,
          permissionResult: CallV2SanitizedPermissionResult.cameraDenied,
        ),
        CallV2RtcPermissionOwnerDecisionKind.permissionDeniedRejected,
      );

  bool get unsafeTransitionIsRejected =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.unsafeTransitionRejected,
      ) &&
      _decisionMatches(
        boundary.decideWhileDisabled(
          action: CallV2RtcPermissionOwnerAction.prepareRtcEngine,
          generation: 5,
          previousRtcEvent: CallV2SanitizedRtcEvent.rtcPublishing,
          rtcEvent: CallV2SanitizedRtcEvent.rtcPrepared,
        ),
        CallV2RtcPermissionOwnerDecisionKind.unsafeTransitionRejected,
      );

  bool get ownershipMismatchIsRejected =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.ownershipMismatchRejected,
      ) &&
      _decisionMatches(
        boundary.decideWhileDisabled(
          action: CallV2RtcPermissionOwnerAction.joinRtcChannel,
          generation: 6,
          ownershipMatches: false,
        ),
        CallV2RtcPermissionOwnerDecisionKind.ownershipRejected,
      );

  bool get rawDeviceIsRejected =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.rawDeviceRejected,
      ) &&
      _decisionMatches(
        boundary.decideWhileDisabled(
          action: CallV2RtcPermissionOwnerAction.enumerateDevices,
          generation: 7,
          rawDeviceProvided: true,
        ),
        CallV2RtcPermissionOwnerDecisionKind.rawDeviceRejected,
      );

  bool get terminalDecisionIsIgnored =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.terminalDecisionIgnored,
      ) &&
      _decisionMatches(
        boundary.decideWhileDisabled(
          action: CallV2RtcPermissionOwnerAction.disposeRtc,
          generation: 8,
          terminal: true,
          rtcEvent: CallV2SanitizedRtcEvent.rtcEnded,
        ),
        CallV2RtcPermissionOwnerDecisionKind.terminalIgnored,
      );

  bool get recordsSafeDebugOnly => statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.safeDebugOnly,
      );

  bool get recordsRouteRegistryNullWhileFalse => statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus
            .routeRegistryNullWhileFalse,
      );

  bool get recordsDisabledOwnerInert => statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.disabledOwnerInert,
      );

  bool get rollbackPreserved =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2RtcPermissionOwnerHardeningRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2RtcPermissionOwnerHardeningRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2RtcPermissionOwnerHardeningRollback.keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2RtcPermissionOwnerHardeningRollback.keepDisabledOwnerInert,
      ) &&
      rollback.contains(
        CallV2RtcPermissionOwnerHardeningRollback.noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2RtcPermissionOwnerHardeningRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2RtcPermissionOwnerHardeningRollback.v1Unaffected,
      );

  bool get protectsV1 =>
      statuses.contains(
        CallV2RtcPermissionOwnerHardeningAuditStatus.v1Protected,
      ) &&
      boundary.protectsV1;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'actionCount': boundary.actions.length,
      'permissionResultCount': boundary.permissionResults.length,
      'rtcEventCount': boundary.rtcEvents.length,
      'developerOnly': recordsDeveloperOnly,
      'hardDisabled': recordsHardDisabled,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'reachable': boundary.isReachable,
      'actionsExact': actionsAreExact,
      'permissionResultsExact': permissionResultsAreExact,
      'rtcEventsExact': rtcEventsAreExact,
      'defaultDecisionsInert': defaultDecisionsAreInert,
      'duplicateDecisionNoOp': duplicateDecisionIsNoOp,
      'staleDecisionIgnored': staleDecisionIsIgnored,
      'permissionDeniedRejected': permissionDeniedIsRejected,
      'unsafeTransitionRejected': unsafeTransitionIsRejected,
      'ownershipMismatchRejected': ownershipMismatchIsRejected,
      'deviceInputRejected': rawDeviceIsRejected,
      'terminalDecisionIgnored': terminalDecisionIsIgnored,
      'routeRegistryNullWhileFalse': recordsRouteRegistryNullWhileFalse,
      'disabledOwnerInert': recordsDisabledOwnerInert,
      'rollbackPreserved': rollbackPreserved,
      'protectsV1': protectsV1,
    };
  }

  bool _decisionMatches(
    CallV2RtcPermissionOwnerDecision decision,
    CallV2RtcPermissionOwnerDecisionKind expected,
  ) {
    return decision.kind == expected && _decisionHasNoSideEffects(decision);
  }

  bool _decisionHasNoSideEffects(CallV2RtcPermissionOwnerDecision decision) {
    return !decision.importsRtcPermissionPackages &&
        !decision.createsRtcEngine &&
        !decision.joinsRtcChannel &&
        !decision.consumesRtcTokenChannel &&
        !decision.requestsPermission &&
        !decision.promptsMicrophoneCamera &&
        !decision.enumeratesDevices &&
        !decision.capturesMedia &&
        !decision.startsCameraPreview &&
        !decision.publishesAudioVideo &&
        !decision.opensRtcCallbacksListenersSubscriptions &&
        !decision.constructsRuntime &&
        !decision.startsRuntime &&
        !decision.accessesBackendFirebase &&
        !decision.accessesNavigation &&
        !decision.registersLifecycleObserver &&
        !decision.mutatesRouteRegistry &&
        !decision.opensAsyncHandles &&
        !decision.changesPubspecPlatformConfig &&
        !decision.mutatesV1State;
  }

  @override
  String toString() {
    return 'CallV2RtcPermissionOwnerHardeningAudit(${toSafeDebugMap()})';
  }
}

final callV2RtcPermissionOwnerHardeningAudit =
    CallV2RtcPermissionOwnerHardeningAudit(
  boundary: callV2RtcPermissionOwnerBoundary,
  statuses: <CallV2RtcPermissionOwnerHardeningAuditStatus>[
    CallV2RtcPermissionOwnerHardeningAuditStatus.developerOnly,
    CallV2RtcPermissionOwnerHardeningAuditStatus.hardDisabled,
    CallV2RtcPermissionOwnerHardeningAuditStatus.rolloutFalse,
    CallV2RtcPermissionOwnerHardeningAuditStatus.unreachable,
    CallV2RtcPermissionOwnerHardeningAuditStatus.noRtcPermissionImports,
    CallV2RtcPermissionOwnerHardeningAuditStatus.noRtcEngineCreation,
    CallV2RtcPermissionOwnerHardeningAuditStatus.noRtcChannelJoin,
    CallV2RtcPermissionOwnerHardeningAuditStatus.noRtcTokenChannelConsumption,
    CallV2RtcPermissionOwnerHardeningAuditStatus.noPermissionRequest,
    CallV2RtcPermissionOwnerHardeningAuditStatus.noMicrophoneCameraPrompt,
    CallV2RtcPermissionOwnerHardeningAuditStatus.noDeviceEnumeration,
    CallV2RtcPermissionOwnerHardeningAuditStatus.noMediaCapture,
    CallV2RtcPermissionOwnerHardeningAuditStatus.noCameraPreview,
    CallV2RtcPermissionOwnerHardeningAuditStatus.noAudioVideoPublish,
    CallV2RtcPermissionOwnerHardeningAuditStatus
        .noRtcCallbacksListenersSubscriptions,
    CallV2RtcPermissionOwnerHardeningAuditStatus.noRuntimeConstruction,
    CallV2RtcPermissionOwnerHardeningAuditStatus.noRuntimeStart,
    CallV2RtcPermissionOwnerHardeningAuditStatus.noBackendFirebaseAccess,
    CallV2RtcPermissionOwnerHardeningAuditStatus.noNavigationAccess,
    CallV2RtcPermissionOwnerHardeningAuditStatus.noLifecycleRegistration,
    CallV2RtcPermissionOwnerHardeningAuditStatus.noRouteRegistryMutation,
    CallV2RtcPermissionOwnerHardeningAuditStatus.noAsyncHandles,
    CallV2RtcPermissionOwnerHardeningAuditStatus.noPubspecPlatformConfigChanges,
    CallV2RtcPermissionOwnerHardeningAuditStatus.noDeployment,
    CallV2RtcPermissionOwnerHardeningAuditStatus.actionsExact,
    CallV2RtcPermissionOwnerHardeningAuditStatus.permissionResultsExact,
    CallV2RtcPermissionOwnerHardeningAuditStatus.rtcEventsExact,
    CallV2RtcPermissionOwnerHardeningAuditStatus.defaultDecisionsInert,
    CallV2RtcPermissionOwnerHardeningAuditStatus.duplicateDecisionNoOp,
    CallV2RtcPermissionOwnerHardeningAuditStatus.staleDecisionIgnored,
    CallV2RtcPermissionOwnerHardeningAuditStatus.permissionDeniedRejected,
    CallV2RtcPermissionOwnerHardeningAuditStatus.unsafeTransitionRejected,
    CallV2RtcPermissionOwnerHardeningAuditStatus.ownershipMismatchRejected,
    CallV2RtcPermissionOwnerHardeningAuditStatus.rawDeviceRejected,
    CallV2RtcPermissionOwnerHardeningAuditStatus.terminalDecisionIgnored,
    CallV2RtcPermissionOwnerHardeningAuditStatus.safeDebugOnly,
    CallV2RtcPermissionOwnerHardeningAuditStatus.routeRegistryNullWhileFalse,
    CallV2RtcPermissionOwnerHardeningAuditStatus.disabledOwnerInert,
    CallV2RtcPermissionOwnerHardeningAuditStatus.rollbackOneCommit,
    CallV2RtcPermissionOwnerHardeningAuditStatus.v1Protected,
  ],
  rollback: <CallV2RtcPermissionOwnerHardeningRollback>[
    CallV2RtcPermissionOwnerHardeningRollback.oneCommitRevert,
    CallV2RtcPermissionOwnerHardeningRollback.keepRolloutFalse,
    CallV2RtcPermissionOwnerHardeningRollback.keepRouteRegistryNull,
    CallV2RtcPermissionOwnerHardeningRollback.keepDisabledOwnerInert,
    CallV2RtcPermissionOwnerHardeningRollback.noDeploymentRequired,
    CallV2RtcPermissionOwnerHardeningRollback.noConfigChanges,
    CallV2RtcPermissionOwnerHardeningRollback.v1Unaffected,
  ],
);
