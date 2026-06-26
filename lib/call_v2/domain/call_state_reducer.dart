import 'call_effect.dart';
import 'call_event.dart';
import 'call_lifecycle.dart';
import 'call_local_phase.dart';
import 'call_session_state.dart';
import 'call_snapshot.dart';
import 'participant_media_state.dart';

class CallReduction {
  const CallReduction({
    required this.state,
    required this.effects,
  });

  final CallSessionState state;
  final List<CallEffect> effects;
}

class CallStateReducer {
  const CallStateReducer();

  CallReduction reduce(CallSessionState current, CallEvent event) {
    if (!_canProcess(current, event)) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    if (current.processedEventIds.contains(event.eventId)) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }

    return switch (event) {
      CallSnapshotReceived() => _reduceSnapshot(current, event),
      LocalUserAccepted() => _reduceBackendCommand(
          current,
          event,
          BackendCommandType.acceptCall,
        ),
      LocalUserDeclined() => _reduceBackendCommand(
          current,
          event,
          BackendCommandType.declineCall,
        ),
      LocalUserCancelled() => _reduceBackendCommand(
          current,
          event,
          BackendCommandType.cancelCall,
        ),
      LocalUserEnded() => _reduceBackendCommand(
          current,
          event,
          BackendCommandType.endCall,
        ),
      PrepareMediaRequested() => _reduceLocalEffect(
          current,
          event,
          CallEffect.prepareAgora,
        ),
      JoinMediaRequested() => _reduceJoinMediaRequested(current, event),
      LocalMediaPreparing() => _reduceMediaCallback(
          current,
          event,
          ParticipantMediaState.preparing,
          BackendCommandType.reportMediaPreparing,
        ),
      LocalMediaJoining() => _reduceMediaCallback(
          current,
          event,
          ParticipantMediaState.joining,
          BackendCommandType.reportMediaJoining,
        ),
      LocalMediaJoined() => _reduceMediaCallback(
          current,
          event,
          ParticipantMediaState.joined,
          BackendCommandType.reportMediaJoined,
        ),
      PeerMediaJoined() => _reducePeerMediaJoined(current, event),
      RemoteDetected() => _reduceDiagnosticOnly(
          current,
          event,
          'agora.remote_detected',
        ),
      MediaReconnecting() => _reduceMediaCallback(
          current,
          event,
          ParticipantMediaState.reconnecting,
          BackendCommandType.reportMediaConnection,
        ),
      MediaReconnected() => _reduceMediaCallback(
          current,
          event,
          ParticipantMediaState.joined,
          BackendCommandType.reportMediaConnection,
        ),
      MediaFailed() => _reduceMediaCallback(
          current,
          event,
          ParticipantMediaState.mediaFailed,
          BackendCommandType.reportCallFailure,
          reason: event.failureCode,
        ),
      NativeIncomingPresented() => _reduceNative(
          current,
          event,
          NativePresentationState.callkitPresented,
          'callkit.presented',
        ),
      NativeAccepted() => _reduceNativeCommand(
          current,
          event,
          NativePresentationState.acceptedNatively,
          BackendCommandType.acceptCall,
          'callkit.accepted',
        ),
      NativeDeclined() => _reduceNativeCommand(
          current,
          event,
          NativePresentationState.declinedNatively,
          BackendCommandType.declineCall,
          'callkit.declined',
        ),
      NativeCallEnded() => _reduceNativeCallEnded(current, event),
      RouteOpened() => _reduceRouteOpened(current, event),
      RouteOpenFailed() => _reduceRouteOpenFailed(current, event),
      RetryOpenCallRouteRequested() => _reduceRouteOpenRetry(current, event),
      RouteClosed() => _reduceRouteClosed(current, event),
      IncomingRoutePresented() => _reduceIncomingRoutePresented(
          current,
          event,
        ),
      IncomingRoutePresentationFailed() => _reduceIncomingRouteFailed(
          current,
          event,
        ),
      RetryIncomingRoutePresentationRequested() => _reduceIncomingRouteRetry(
          current,
          event,
        ),
      IncomingRouteClosed() => _reduceIncomingRouteClosed(current, event),
      AppResumed() => _reduceDiagnosticOnly(
          current,
          event,
          'app.resumed',
        ),
      CleanupCompleted() => _reduceCleanupCompleted(current, event),
    };
  }

  bool _canProcess(CallSessionState current, CallEvent event) {
    final activeCallId = current.callId;
    if (activeCallId != null && activeCallId != event.callId) {
      return false;
    }

    if (event case CallSnapshotReceived(:final snapshot)) {
      if (current.isTerminal && snapshot.lifecycle.isNonTerminal) {
        return false;
      }
    }

    if (current.isTerminal && event is! CallSnapshotReceived) {
      return event is CleanupCompleted ||
          event is RouteClosed ||
          event is IncomingRouteClosed ||
          event is NativeCallEnded;
    }

    return true;
  }

  CallReduction _reduceSnapshot(
    CallSessionState current,
    CallSnapshotReceived event,
  ) {
    final snapshot = event.snapshot;
    final callId = snapshot.callId;
    final localRole =
        current.localParticipantRole ?? event.localParticipantRole;
    final effects = <CallEffect>[];

    var lifecycle = current.lifecycle;
    var latestAuthoritativeVersion = current.latestAuthoritativeVersion;
    var localMediaState = current.localMediaState;
    var peerMediaState = current.peerMediaState;
    var localMediaVersion = current.localMediaVersion;
    var peerMediaVersion = current.peerMediaVersion;
    var incomingRouteState = current.incomingRouteState;
    var callRouteState = current.callRouteState;
    var cleanupStatus = current.cleanupStatus;
    var nativePresentationState = current.nativePresentationState;
    var localPhase = current.localPhase;

    final canUpdateLifecycle = current.lifecycle == null ||
        snapshot.version > current.latestAuthoritativeVersion;
    if (canUpdateLifecycle) {
      lifecycle = snapshot.lifecycle;
      latestAuthoritativeVersion = snapshot.version;
    }

    final snapshotLocalMediaVersion = snapshot.mediaVersionFor(localRole);
    if (current.callId == null ||
        snapshotLocalMediaVersion > current.localMediaVersion) {
      localMediaState = snapshot.mediaStateFor(localRole);
      localMediaVersion = snapshotLocalMediaVersion;
    }

    final snapshotPeerMediaVersion = snapshot.peerMediaVersionFor(localRole);
    if (current.callId == null ||
        snapshotPeerMediaVersion > current.peerMediaVersion) {
      peerMediaState = snapshot.peerMediaStateFor(localRole);
      peerMediaVersion = snapshotPeerMediaVersion;
    }

    if (lifecycle == CallLifecycle.ringing) {
      if (localRole == CallParticipantRole.callee &&
          incomingRouteState == IncomingRouteState.notRequested) {
        effects.add(CallEffect.presentIncomingRoute(callId));
        incomingRouteState = IncomingRouteState.opening;
      }
      localPhase = localRole == CallParticipantRole.callee
          ? CallLocalPhase.presentingIncoming
          : CallLocalPhase.outgoingRinging;
    } else if (lifecycle == CallLifecycle.accepted ||
        lifecycle == CallLifecycle.active) {
      if (incomingRouteState == IncomingRouteState.opening ||
          incomingRouteState == IncomingRouteState.presented) {
        incomingRouteState = IncomingRouteState.closed;
      }
      if (callRouteState == CallRouteState.notRequested ||
          callRouteState == CallRouteState.closed) {
        effects.add(CallEffect.openCallRoute(callId));
        callRouteState = CallRouteState.opening;
      }
      localPhase = callRouteState == CallRouteState.open
          ? CallLocalPhase.inCall
          : CallLocalPhase.openingCallRoute;
    } else if (lifecycle?.isTerminal == true) {
      if (nativePresentationState != NativePresentationState.endedNatively) {
        nativePresentationState = NativePresentationState.endingRequested;
      }
      if (cleanupStatus == CleanupStatus.notRequested) {
        effects.addAll(_terminalCleanupEffects(callId));
        cleanupStatus = CleanupStatus.requested;
      }
      localPhase = CallLocalPhase.closing;
    }

    final next = current
        .copyWith(
          callId: callId,
          latestAuthoritativeVersion: latestAuthoritativeVersion,
          lifecycle: lifecycle,
          localParticipantRole: localRole,
          localMediaState: localMediaState,
          peerMediaState: peerMediaState,
          localMediaVersion: localMediaVersion,
          peerMediaVersion: peerMediaVersion,
          localPhase: localPhase,
          nativePresentationState: nativePresentationState,
          incomingRouteState: incomingRouteState,
          callRouteState: callRouteState,
          cleanupStatus: cleanupStatus,
        )
        .markProcessed(event.eventId);

    return CallReduction(state: next, effects: List.unmodifiable(effects));
  }

  CallReduction _reduceBackendCommand(
    CallSessionState current,
    UserCommandEvent event,
    BackendCommandType command,
  ) {
    if (current.callId == null || current.isTerminal) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    return _withEffects(
      current,
      event,
      <CallEffect>[
        CallEffect.requestBackendCommand(
          callId: event.callId,
          command: command,
        ),
      ],
    );
  }

  CallReduction _reduceLocalEffect(
    CallSessionState current,
    CallEvent event,
    CallEffect Function(String callId) effect,
  ) {
    if (current.callId == null || current.isTerminal) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    return _withEffects(current, event, <CallEffect>[effect(event.callId)]);
  }

  CallReduction _reduceJoinMediaRequested(
    CallSessionState current,
    JoinMediaRequested event,
  ) {
    if (current.callId == null ||
        current.isTerminal ||
        current.lifecycle == CallLifecycle.ringing) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    return _withEffects(
      current,
      event,
      <CallEffect>[CallEffect.joinAgora(event.callId)],
    );
  }

  CallReduction _reduceMediaCallback(
    CallSessionState current,
    CallEvent event,
    ParticipantMediaState mediaState,
    BackendCommandType command, {
    String? reason,
  }) {
    if (current.callId == null || current.isTerminal) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    final next = current.copyWith(localMediaState: mediaState);
    return _withEffects(
      next,
      event,
      <CallEffect>[
        CallEffect.requestBackendCommand(
          callId: event.callId,
          command: command,
          reason: reason,
        ),
      ],
    );
  }

  CallReduction _reducePeerMediaJoined(
    CallSessionState current,
    PeerMediaJoined event,
  ) {
    if (current.callId == null || current.isTerminal) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    final next = current.copyWith(
      peerMediaState: ParticipantMediaState.joined,
    );
    return _withEffects(
      next,
      event,
      <CallEffect>[
        CallEffect.recordDiagnosticEvent(
          callId: event.callId,
          code: 'peer.media_joined',
        ),
      ],
    );
  }

  CallReduction _reduceDiagnosticOnly(
    CallSessionState current,
    CallEvent event,
    String code,
  ) {
    if (current.callId == null) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    return _withEffects(
      current,
      event,
      <CallEffect>[
        CallEffect.recordDiagnosticEvent(callId: event.callId, code: code),
      ],
    );
  }

  CallReduction _reduceNative(
    CallSessionState current,
    CallEvent event,
    NativePresentationState nativeState,
    String code,
  ) {
    if (current.callId == null) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    final next = current.copyWith(nativePresentationState: nativeState);
    return _withEffects(
      next,
      event,
      <CallEffect>[
        CallEffect.recordDiagnosticEvent(callId: event.callId, code: code),
      ],
    );
  }

  CallReduction _reduceNativeCommand(
    CallSessionState current,
    UserCommandEvent event,
    NativePresentationState nativeState,
    BackendCommandType command,
    String code,
  ) {
    if (current.callId == null || current.isTerminal) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    final next = current.copyWith(nativePresentationState: nativeState);
    return _withEffects(
      next,
      event,
      <CallEffect>[
        CallEffect.recordDiagnosticEvent(callId: event.callId, code: code),
        CallEffect.requestBackendCommand(
          callId: event.callId,
          command: command,
        ),
      ],
    );
  }

  CallReduction _reduceNativeCallEnded(
    CallSessionState current,
    NativeCallEnded event,
  ) {
    if (current.callId == null ||
        current.nativePresentationState !=
            NativePresentationState.endingRequested) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    final next = current.copyWith(
      nativePresentationState: NativePresentationState.endedNatively,
    );
    return _withEffects(next, event, const <CallEffect>[]);
  }

  CallReduction _reduceRouteOpened(
    CallSessionState current,
    RouteOpened event,
  ) {
    if (current.callId == null ||
        current.callRouteState != CallRouteState.opening) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    final next = current.copyWith(
      callRouteState: CallRouteState.open,
      localPhase:
          current.isTerminal ? CallLocalPhase.closing : CallLocalPhase.inCall,
    );
    return _withEffects(next, event, const <CallEffect>[]);
  }

  CallReduction _reduceRouteOpenFailed(
    CallSessionState current,
    RouteOpenFailed event,
  ) {
    if (current.callId == null ||
        current.isTerminal ||
        current.callRouteState != CallRouteState.opening) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    final next = current.copyWith(
      callRouteState: CallRouteState.failed,
      localPhase: CallLocalPhase.openingCallRoute,
    );
    return _withEffects(
      next,
      event,
      <CallEffect>[
        CallEffect.recordDiagnosticEvent(
          callId: event.callId,
          code: 'route.open_failed',
          reason: event.reason,
        ),
      ],
    );
  }

  CallReduction _reduceRouteOpenRetry(
    CallSessionState current,
    RetryOpenCallRouteRequested event,
  ) {
    if (current.callId == null ||
        current.isTerminal ||
        current.callRouteState != CallRouteState.failed ||
        (current.lifecycle != CallLifecycle.accepted &&
            current.lifecycle != CallLifecycle.active)) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    final next = current.copyWith(
      callRouteState: CallRouteState.opening,
      localPhase: CallLocalPhase.openingCallRoute,
    );
    return _withEffects(
      next,
      event,
      <CallEffect>[CallEffect.openCallRoute(event.callId)],
    );
  }

  CallReduction _reduceRouteClosed(
    CallSessionState current,
    RouteClosed event,
  ) {
    if (current.callId == null) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    final next = current.copyWith(
      callRouteState: CallRouteState.closed,
      localPhase:
          current.isTerminal ? CallLocalPhase.closing : current.localPhase,
    );
    return _withEffects(next, event, const <CallEffect>[]);
  }

  CallReduction _reduceIncomingRoutePresented(
    CallSessionState current,
    IncomingRoutePresented event,
  ) {
    if (current.callId == null ||
        current.incomingRouteState != IncomingRouteState.opening) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    final next = current.copyWith(
      incomingRouteState: IncomingRouteState.presented,
    );
    return _withEffects(next, event, const <CallEffect>[]);
  }

  CallReduction _reduceIncomingRouteFailed(
    CallSessionState current,
    IncomingRoutePresentationFailed event,
  ) {
    if (current.callId == null ||
        current.isTerminal ||
        current.incomingRouteState != IncomingRouteState.opening) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    final next = current.copyWith(
      incomingRouteState: IncomingRouteState.failed,
    );
    return _withEffects(
      next,
      event,
      <CallEffect>[
        CallEffect.recordDiagnosticEvent(
          callId: event.callId,
          code: 'incoming_route.present_failed',
          reason: event.reason,
        ),
      ],
    );
  }

  CallReduction _reduceIncomingRouteRetry(
    CallSessionState current,
    RetryIncomingRoutePresentationRequested event,
  ) {
    if (current.callId == null ||
        current.lifecycle != CallLifecycle.ringing ||
        current.incomingRouteState != IncomingRouteState.failed) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    final next = current.copyWith(
      incomingRouteState: IncomingRouteState.opening,
    );
    return _withEffects(
      next,
      event,
      <CallEffect>[CallEffect.presentIncomingRoute(event.callId)],
    );
  }

  CallReduction _reduceIncomingRouteClosed(
    CallSessionState current,
    IncomingRouteClosed event,
  ) {
    if (current.callId == null) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    final next = current.copyWith(
      incomingRouteState: IncomingRouteState.closed,
    );
    return _withEffects(next, event, const <CallEffect>[]);
  }

  CallReduction _reduceCleanupCompleted(
    CallSessionState current,
    CleanupCompleted event,
  ) {
    if (current.callId == null ||
        current.cleanupStatus != CleanupStatus.requested) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    return CallReduction(
      state: CallSessionState.initial(),
      effects: const <CallEffect>[],
    );
  }

  CallReduction _withEffects(
    CallSessionState state,
    CallEvent event,
    List<CallEffect> effects,
  ) {
    return CallReduction(
      state: state.markProcessed(event.eventId),
      effects: List.unmodifiable(effects),
    );
  }

  List<CallEffect> _terminalCleanupEffects(String callId) {
    return <CallEffect>[
      CallEffect.closeCallRoute(callId),
      CallEffect.leaveAgora(callId),
      CallEffect.endMatchingNativeCall(callId),
    ];
  }
}
