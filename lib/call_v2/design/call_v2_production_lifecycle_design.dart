enum CallV2ProductionRuntimeLifecycleState {
  unavailable,
  idle,
  preparing,
  connecting,
  ready,
  reconnecting,
  ending,
  ended,
  failed,
  disposed,
}

enum CallV2ProductionLifecycleOwner {
  appIntegrationOwner,
  uiCoordinator,
  startupBridge,
  runtime,
  rtcAdapter,
  lifecycleOwner,
}

class CallV2ProductionLifecycleTransition {
  const CallV2ProductionLifecycleTransition({
    required this.from,
    required this.to,
    required this.owner,
    required this.allowed,
  });

  final CallV2ProductionRuntimeLifecycleState from;
  final CallV2ProductionRuntimeLifecycleState to;
  final CallV2ProductionLifecycleOwner owner;
  final bool allowed;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'from': from.name,
      'to': to.name,
      'owner': owner.name,
      'allowed': allowed,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionLifecycleTransition(${toSafeDebugMap()})';
  }
}

enum CallV2ProductionRuntimePolicy {
  noAutomaticLaunchOnAppStartup,
  explicitAuthenticatedLaunchOnly,
  duplicateSameLaunchSharesInFlightWork,
  conflictingLaunchRejected,
  leaveDuringConnectStopsStartupAndClosesRoute,
  backgroundDoesNotLaunchNewCall,
  activeAudioContinuesOnlyWhenPlatformAllows,
  videoRenderingPausesWhenBackgrounded,
  cameraMayReleaseWhenBackgrounded,
  foregroundRecoveryIsIdempotent,
  detachedPerformsControlledCleanup,
  authSignOutStopsRuntimeAndClearsSession,
  networkLossMovesToReconnecting,
  tokenRefreshUsesCredentialProviderOnly,
  remoteLeaveEndsOwnedSession,
  startupFailureRollsBackRouteAndRuntime,
  disposeOrderIsLifecycleRouteCoordinatorBridgeRuntimeRtc,
  callbacksDoNotExposeIdentifiers,
}

enum CallV2ProductionAppLifecycleState {
  resumed,
  inactive,
  paused,
  detached,
  hidden,
}

class CallV2ProductionAppLifecyclePolicy {
  const CallV2ProductionAppLifecyclePolicy({
    required this.state,
    required this.policies,
  });

  final CallV2ProductionAppLifecycleState state;
  final List<CallV2ProductionRuntimePolicy> policies;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'state': state.name,
      'policies': policies.map((policy) => policy.name).toList(),
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionAppLifecyclePolicy(${toSafeDebugMap()})';
  }
}

enum CallV2ProductionPermissionTiming {
  afterExplicitUserLaunch,
  beforeBackendMediaJoin,
  neverDuringAppStartup,
  neverDuringComposition,
  neverWhenRolloutDisabled,
}

enum CallV2ProductionPermissionOutcome {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  unavailable,
  requestCancelled,
}

class CallV2ProductionPermissionPolicy {
  const CallV2ProductionPermissionPolicy({
    required this.requiresMicrophone,
    required this.requiresCamera,
    required this.timing,
    required this.outcomes,
    required this.appSettingsRedirectAllowed,
  });

  final bool requiresMicrophone;
  final bool requiresCamera;
  final List<CallV2ProductionPermissionTiming> timing;
  final List<CallV2ProductionPermissionOutcome> outcomes;
  final bool appSettingsRedirectAllowed;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'requiresMicrophone': requiresMicrophone,
      'requiresCamera': requiresCamera,
      'timing': timing.map((item) => item.name).toList(),
      'outcomes': outcomes.map((item) => item.name).toList(),
      'appSettingsRedirectAllowed': appSettingsRedirectAllowed,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionPermissionPolicy(${toSafeDebugMap()})';
  }
}

enum CallV2ProductionAuthAppCheckPolicy {
  authenticatedIdentityRequiredBeforeLaunch,
  localIdentityDerivedInternally,
  remoteParticipantMustDiffer,
  appCheckBeforeBackendCallable,
  authChangeDuringActiveCallEndsOwnedSession,
  signOutTriggersCleanup,
  staleIdentityRejected,
  noIdentityInRouteNames,
  noAnonymousFallbackWithoutSeparateApproval,
}

enum CallV2ProductionObservabilityEvent {
  launchRequested,
  launchRejected,
  compositionUnavailable,
  permissionDenied,
  backendStartAccepted,
  backendStartRejected,
  rtcInitializationStarted,
  rtcInitializationFailed,
  connecting,
  ready,
  reconnecting,
  leaving,
  ended,
  controlledFailure,
}

enum CallV2ProductionObservabilityPolicy {
  noUid,
  noCallId,
  noParticipantId,
  noCredential,
  noChannel,
  noRawError,
  noStackTrace,
  noRouteArguments,
  noPersistenceOrRetryWithoutApproval,
  sinkFailureNeverAffectsCallBehavior,
}

enum CallV2ProductionGate {
  compileTimeRolloutPolicy,
  preIntegrationApproval,
  runtimeFeatureGate,
  productionConfigurationEnabled,
  backendCallableAvailability,
  rtcProviderAvailability,
}

enum CallV2ProductionGateClosurePhase {
  beforeComposition,
  beforeLaunch,
  duringConnecting,
  duringActiveCall,
  duringReconnecting,
}

class CallV2ProductionGateClosurePolicy {
  const CallV2ProductionGateClosurePolicy({
    required this.gate,
    required this.phase,
    required this.policy,
  });

  final CallV2ProductionGate gate;
  final CallV2ProductionGateClosurePhase phase;
  final CallV2ProductionRuntimePolicy policy;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'gate': gate.name,
      'phase': phase.name,
      'policy': policy.name,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionGateClosurePolicy(${toSafeDebugMap()})';
  }
}

class CallV2ProductionLifecycleDesign {
  factory CallV2ProductionLifecycleDesign({
    required List<CallV2ProductionLifecycleTransition> transitions,
    required List<CallV2ProductionRuntimePolicy> runtimePolicies,
    required List<CallV2ProductionAppLifecyclePolicy> appLifecyclePolicies,
    required CallV2ProductionPermissionPolicy audioPermissionPolicy,
    required CallV2ProductionPermissionPolicy videoPermissionPolicy,
    required List<CallV2ProductionAuthAppCheckPolicy> authAppCheckPolicies,
    required List<CallV2ProductionObservabilityEvent> observabilityEvents,
    required List<CallV2ProductionObservabilityPolicy> observabilityPolicies,
    required List<CallV2ProductionGateClosurePolicy> gateClosurePolicies,
  }) {
    return CallV2ProductionLifecycleDesign._(
      List<CallV2ProductionLifecycleTransition>.unmodifiable(transitions),
      List<CallV2ProductionRuntimePolicy>.unmodifiable(runtimePolicies),
      List<CallV2ProductionAppLifecyclePolicy>.unmodifiable(
        appLifecyclePolicies,
      ),
      audioPermissionPolicy,
      videoPermissionPolicy,
      List<CallV2ProductionAuthAppCheckPolicy>.unmodifiable(
        authAppCheckPolicies,
      ),
      List<CallV2ProductionObservabilityEvent>.unmodifiable(
        observabilityEvents,
      ),
      List<CallV2ProductionObservabilityPolicy>.unmodifiable(
        observabilityPolicies,
      ),
      List<CallV2ProductionGateClosurePolicy>.unmodifiable(
        gateClosurePolicies,
      ),
    );
  }

  const CallV2ProductionLifecycleDesign._(
    this.transitions,
    this.runtimePolicies,
    this.appLifecyclePolicies,
    this.audioPermissionPolicy,
    this.videoPermissionPolicy,
    this.authAppCheckPolicies,
    this.observabilityEvents,
    this.observabilityPolicies,
    this.gateClosurePolicies,
  );

  final List<CallV2ProductionLifecycleTransition> transitions;
  final List<CallV2ProductionRuntimePolicy> runtimePolicies;
  final List<CallV2ProductionAppLifecyclePolicy> appLifecyclePolicies;
  final CallV2ProductionPermissionPolicy audioPermissionPolicy;
  final CallV2ProductionPermissionPolicy videoPermissionPolicy;
  final List<CallV2ProductionAuthAppCheckPolicy> authAppCheckPolicies;
  final List<CallV2ProductionObservabilityEvent> observabilityEvents;
  final List<CallV2ProductionObservabilityPolicy> observabilityPolicies;
  final List<CallV2ProductionGateClosurePolicy> gateClosurePolicies;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'transitions':
          transitions.map((transition) => transition.toSafeDebugMap()).toList(),
      'runtimePolicies': runtimePolicies.map((policy) => policy.name).toList(),
      'appLifecyclePolicies': appLifecyclePolicies
          .map((policy) => policy.toSafeDebugMap())
          .toList(),
      'audioPermissionPolicy': audioPermissionPolicy.toSafeDebugMap(),
      'videoPermissionPolicy': videoPermissionPolicy.toSafeDebugMap(),
      'authAppCheckPolicies':
          authAppCheckPolicies.map((policy) => policy.name).toList(),
      'observabilityEvents':
          observabilityEvents.map((event) => event.name).toList(),
      'observabilityPolicies':
          observabilityPolicies.map((policy) => policy.name).toList(),
      'gateClosurePolicies':
          gateClosurePolicies.map((policy) => policy.toSafeDebugMap()).toList(),
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionLifecycleDesign(${toSafeDebugMap()})';
  }
}

const callV2ProductionLifecycleTransitions =
    <CallV2ProductionLifecycleTransition>[
  CallV2ProductionLifecycleTransition(
    from: CallV2ProductionRuntimeLifecycleState.unavailable,
    to: CallV2ProductionRuntimeLifecycleState.idle,
    owner: CallV2ProductionLifecycleOwner.appIntegrationOwner,
    allowed: true,
  ),
  CallV2ProductionLifecycleTransition(
    from: CallV2ProductionRuntimeLifecycleState.idle,
    to: CallV2ProductionRuntimeLifecycleState.preparing,
    owner: CallV2ProductionLifecycleOwner.uiCoordinator,
    allowed: true,
  ),
  CallV2ProductionLifecycleTransition(
    from: CallV2ProductionRuntimeLifecycleState.preparing,
    to: CallV2ProductionRuntimeLifecycleState.connecting,
    owner: CallV2ProductionLifecycleOwner.startupBridge,
    allowed: true,
  ),
  CallV2ProductionLifecycleTransition(
    from: CallV2ProductionRuntimeLifecycleState.connecting,
    to: CallV2ProductionRuntimeLifecycleState.ready,
    owner: CallV2ProductionLifecycleOwner.runtime,
    allowed: true,
  ),
  CallV2ProductionLifecycleTransition(
    from: CallV2ProductionRuntimeLifecycleState.ready,
    to: CallV2ProductionRuntimeLifecycleState.reconnecting,
    owner: CallV2ProductionLifecycleOwner.rtcAdapter,
    allowed: true,
  ),
  CallV2ProductionLifecycleTransition(
    from: CallV2ProductionRuntimeLifecycleState.reconnecting,
    to: CallV2ProductionRuntimeLifecycleState.ready,
    owner: CallV2ProductionLifecycleOwner.rtcAdapter,
    allowed: true,
  ),
  CallV2ProductionLifecycleTransition(
    from: CallV2ProductionRuntimeLifecycleState.ready,
    to: CallV2ProductionRuntimeLifecycleState.ending,
    owner: CallV2ProductionLifecycleOwner.uiCoordinator,
    allowed: true,
  ),
  CallV2ProductionLifecycleTransition(
    from: CallV2ProductionRuntimeLifecycleState.connecting,
    to: CallV2ProductionRuntimeLifecycleState.ending,
    owner: CallV2ProductionLifecycleOwner.uiCoordinator,
    allowed: true,
  ),
  CallV2ProductionLifecycleTransition(
    from: CallV2ProductionRuntimeLifecycleState.ending,
    to: CallV2ProductionRuntimeLifecycleState.ended,
    owner: CallV2ProductionLifecycleOwner.runtime,
    allowed: true,
  ),
  CallV2ProductionLifecycleTransition(
    from: CallV2ProductionRuntimeLifecycleState.failed,
    to: CallV2ProductionRuntimeLifecycleState.idle,
    owner: CallV2ProductionLifecycleOwner.uiCoordinator,
    allowed: true,
  ),
  CallV2ProductionLifecycleTransition(
    from: CallV2ProductionRuntimeLifecycleState.ready,
    to: CallV2ProductionRuntimeLifecycleState.idle,
    owner: CallV2ProductionLifecycleOwner.runtime,
    allowed: false,
  ),
  CallV2ProductionLifecycleTransition(
    from: CallV2ProductionRuntimeLifecycleState.disposed,
    to: CallV2ProductionRuntimeLifecycleState.ready,
    owner: CallV2ProductionLifecycleOwner.appIntegrationOwner,
    allowed: false,
  ),
];

const callV2ProductionRuntimePolicies = <CallV2ProductionRuntimePolicy>[
  CallV2ProductionRuntimePolicy.noAutomaticLaunchOnAppStartup,
  CallV2ProductionRuntimePolicy.explicitAuthenticatedLaunchOnly,
  CallV2ProductionRuntimePolicy.duplicateSameLaunchSharesInFlightWork,
  CallV2ProductionRuntimePolicy.conflictingLaunchRejected,
  CallV2ProductionRuntimePolicy.leaveDuringConnectStopsStartupAndClosesRoute,
  CallV2ProductionRuntimePolicy.backgroundDoesNotLaunchNewCall,
  CallV2ProductionRuntimePolicy.activeAudioContinuesOnlyWhenPlatformAllows,
  CallV2ProductionRuntimePolicy.videoRenderingPausesWhenBackgrounded,
  CallV2ProductionRuntimePolicy.cameraMayReleaseWhenBackgrounded,
  CallV2ProductionRuntimePolicy.foregroundRecoveryIsIdempotent,
  CallV2ProductionRuntimePolicy.detachedPerformsControlledCleanup,
  CallV2ProductionRuntimePolicy.authSignOutStopsRuntimeAndClearsSession,
  CallV2ProductionRuntimePolicy.networkLossMovesToReconnecting,
  CallV2ProductionRuntimePolicy.tokenRefreshUsesCredentialProviderOnly,
  CallV2ProductionRuntimePolicy.remoteLeaveEndsOwnedSession,
  CallV2ProductionRuntimePolicy.startupFailureRollsBackRouteAndRuntime,
  CallV2ProductionRuntimePolicy
      .disposeOrderIsLifecycleRouteCoordinatorBridgeRuntimeRtc,
  CallV2ProductionRuntimePolicy.callbacksDoNotExposeIdentifiers,
];

const _callV2PermissionTimings = <CallV2ProductionPermissionTiming>[
  CallV2ProductionPermissionTiming.afterExplicitUserLaunch,
  CallV2ProductionPermissionTiming.beforeBackendMediaJoin,
  CallV2ProductionPermissionTiming.neverDuringAppStartup,
  CallV2ProductionPermissionTiming.neverDuringComposition,
  CallV2ProductionPermissionTiming.neverWhenRolloutDisabled,
];

const _callV2PermissionOutcomes = <CallV2ProductionPermissionOutcome>[
  CallV2ProductionPermissionOutcome.granted,
  CallV2ProductionPermissionOutcome.denied,
  CallV2ProductionPermissionOutcome.permanentlyDenied,
  CallV2ProductionPermissionOutcome.restricted,
  CallV2ProductionPermissionOutcome.unavailable,
  CallV2ProductionPermissionOutcome.requestCancelled,
];

final callV2ProductionLifecycleDesign = CallV2ProductionLifecycleDesign(
  transitions: callV2ProductionLifecycleTransitions,
  runtimePolicies: callV2ProductionRuntimePolicies,
  appLifecyclePolicies: <CallV2ProductionAppLifecyclePolicy>[
    const CallV2ProductionAppLifecyclePolicy(
      state: CallV2ProductionAppLifecycleState.resumed,
      policies: <CallV2ProductionRuntimePolicy>[
        CallV2ProductionRuntimePolicy.backgroundDoesNotLaunchNewCall,
        CallV2ProductionRuntimePolicy.foregroundRecoveryIsIdempotent,
      ],
    ),
    const CallV2ProductionAppLifecyclePolicy(
      state: CallV2ProductionAppLifecycleState.inactive,
      policies: <CallV2ProductionRuntimePolicy>[
        CallV2ProductionRuntimePolicy.videoRenderingPausesWhenBackgrounded,
        CallV2ProductionRuntimePolicy.cameraMayReleaseWhenBackgrounded,
      ],
    ),
    const CallV2ProductionAppLifecyclePolicy(
      state: CallV2ProductionAppLifecycleState.paused,
      policies: <CallV2ProductionRuntimePolicy>[
        CallV2ProductionRuntimePolicy
            .activeAudioContinuesOnlyWhenPlatformAllows,
        CallV2ProductionRuntimePolicy.videoRenderingPausesWhenBackgrounded,
      ],
    ),
    const CallV2ProductionAppLifecyclePolicy(
      state: CallV2ProductionAppLifecycleState.detached,
      policies: <CallV2ProductionRuntimePolicy>[
        CallV2ProductionRuntimePolicy.detachedPerformsControlledCleanup,
      ],
    ),
    const CallV2ProductionAppLifecyclePolicy(
      state: CallV2ProductionAppLifecycleState.hidden,
      policies: <CallV2ProductionRuntimePolicy>[
        CallV2ProductionRuntimePolicy.videoRenderingPausesWhenBackgrounded,
        CallV2ProductionRuntimePolicy.callbacksDoNotExposeIdentifiers,
      ],
    ),
  ],
  audioPermissionPolicy: const CallV2ProductionPermissionPolicy(
    requiresMicrophone: true,
    requiresCamera: false,
    timing: _callV2PermissionTimings,
    outcomes: _callV2PermissionOutcomes,
    appSettingsRedirectAllowed: true,
  ),
  videoPermissionPolicy: const CallV2ProductionPermissionPolicy(
    requiresMicrophone: true,
    requiresCamera: true,
    timing: _callV2PermissionTimings,
    outcomes: _callV2PermissionOutcomes,
    appSettingsRedirectAllowed: true,
  ),
  authAppCheckPolicies: <CallV2ProductionAuthAppCheckPolicy>[
    CallV2ProductionAuthAppCheckPolicy
        .authenticatedIdentityRequiredBeforeLaunch,
    CallV2ProductionAuthAppCheckPolicy.localIdentityDerivedInternally,
    CallV2ProductionAuthAppCheckPolicy.remoteParticipantMustDiffer,
    CallV2ProductionAuthAppCheckPolicy.appCheckBeforeBackendCallable,
    CallV2ProductionAuthAppCheckPolicy
        .authChangeDuringActiveCallEndsOwnedSession,
    CallV2ProductionAuthAppCheckPolicy.signOutTriggersCleanup,
    CallV2ProductionAuthAppCheckPolicy.staleIdentityRejected,
    CallV2ProductionAuthAppCheckPolicy.noIdentityInRouteNames,
    CallV2ProductionAuthAppCheckPolicy
        .noAnonymousFallbackWithoutSeparateApproval,
  ],
  observabilityEvents: <CallV2ProductionObservabilityEvent>[
    CallV2ProductionObservabilityEvent.launchRequested,
    CallV2ProductionObservabilityEvent.launchRejected,
    CallV2ProductionObservabilityEvent.compositionUnavailable,
    CallV2ProductionObservabilityEvent.permissionDenied,
    CallV2ProductionObservabilityEvent.backendStartAccepted,
    CallV2ProductionObservabilityEvent.backendStartRejected,
    CallV2ProductionObservabilityEvent.rtcInitializationStarted,
    CallV2ProductionObservabilityEvent.rtcInitializationFailed,
    CallV2ProductionObservabilityEvent.connecting,
    CallV2ProductionObservabilityEvent.ready,
    CallV2ProductionObservabilityEvent.reconnecting,
    CallV2ProductionObservabilityEvent.leaving,
    CallV2ProductionObservabilityEvent.ended,
    CallV2ProductionObservabilityEvent.controlledFailure,
  ],
  observabilityPolicies: <CallV2ProductionObservabilityPolicy>[
    CallV2ProductionObservabilityPolicy.noUid,
    CallV2ProductionObservabilityPolicy.noCallId,
    CallV2ProductionObservabilityPolicy.noParticipantId,
    CallV2ProductionObservabilityPolicy.noCredential,
    CallV2ProductionObservabilityPolicy.noChannel,
    CallV2ProductionObservabilityPolicy.noRawError,
    CallV2ProductionObservabilityPolicy.noStackTrace,
    CallV2ProductionObservabilityPolicy.noRouteArguments,
    CallV2ProductionObservabilityPolicy.noPersistenceOrRetryWithoutApproval,
    CallV2ProductionObservabilityPolicy.sinkFailureNeverAffectsCallBehavior,
  ],
  gateClosurePolicies: <CallV2ProductionGateClosurePolicy>[
    for (final gate in CallV2ProductionGate.values)
      for (final phase in CallV2ProductionGateClosurePhase.values)
        CallV2ProductionGateClosurePolicy(
          gate: gate,
          phase: phase,
          policy: phase == CallV2ProductionGateClosurePhase.beforeComposition ||
                  phase == CallV2ProductionGateClosurePhase.beforeLaunch
              ? CallV2ProductionRuntimePolicy.conflictingLaunchRejected
              : CallV2ProductionRuntimePolicy
                  .startupFailureRollsBackRouteAndRuntime,
        ),
  ],
);
