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
      RouteOpened() => _reduceRouteOpened(current, event),
      RouteOpenFailed() => _reduceRouteOpenFailed(current, event),
      RouteClosed() => _reduceRouteClosed(current, event),
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
      if (snapshot.version < current.latestAuthoritativeVersion) {
        return false;
      }
      if (current.isTerminal && snapshot.lifecycle.isNonTerminal) {
        return false;
      }
    }

    if (current.isTerminal && event is! CallSnapshotReceived) {
      return event is CleanupCompleted || event is RouteClosed;
    }

    return true;
  }

  CallReduction _reduceSnapshot(
    CallSessionState current,
    CallSnapshotReceived event,
  ) {
    final snapshot = event.snapshot;
    final lifecycle = snapshot.lifecycle;
    final callId = snapshot.callId;
    final effects = <CallEffect>[];
    var incomingRoutePresented = current.incomingRoutePresented;
    var callRouteState = current.callRouteState;
    var cleanupStatus = current.cleanupStatus;
    var nativePresentationState = current.nativePresentationState;
    var localPhase = current.localPhase;

    if (lifecycle == CallLifecycle.ringing) {
      if (event.localParticipantRole == CallParticipantRole.callee &&
          !incomingRoutePresented) {
        effects.add(CallEffect.presentIncomingRoute(callId));
        incomingRoutePresented = true;
      }
      localPhase = event.localParticipantRole == CallParticipantRole.callee
          ? CallLocalPhase.presentingIncoming
          : CallLocalPhase.outgoingRinging;
    } else if (lifecycle == CallLifecycle.accepted ||
        lifecycle == CallLifecycle.active) {
      incomingRoutePresented = false;
      if (callRouteState == CallRouteState.notRequested ||
          callRouteState == CallRouteState.closed) {
        effects.add(CallEffect.openCallRoute(callId));
        callRouteState = CallRouteState.opening;
      }
      localPhase = callRouteState == CallRouteState.open
          ? CallLocalPhase.inCall
          : CallLocalPhase.openingCallRoute;
    } else if (lifecycle.isTerminal) {
      incomingRoutePresented = false;
      nativePresentationState = NativePresentationState.endedNatively;
      if (cleanupStatus == CleanupStatus.notRequested) {
        effects.addAll(_terminalCleanupEffects(callId));
        cleanupStatus = CleanupStatus.requested;
      }
      localPhase = CallLocalPhase.closing;
    }

    final next = current
        .copyWith(
          callId: callId,
          latestAuthoritativeVersion: snapshot.version,
          lifecycle: lifecycle,
          localParticipantRole: event.localParticipantRole,
          localMediaState: snapshot.mediaStateFor(event.localParticipantRole),
          peerMediaState:
              snapshot.peerMediaStateFor(event.localParticipantRole),
          localPhase: localPhase,
          nativePresentationState: nativePresentationState,
          incomingRoutePresented: incomingRoutePresented,
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

  CallReduction _reduceRouteOpened(
    CallSessionState current,
    RouteOpened event,
  ) {
    if (current.callId == null) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    final next = current.copyWith(
      incomingRoutePresented: false,
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
    if (current.callId == null || current.isTerminal) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    if (current.lifecycle != CallLifecycle.accepted &&
        current.lifecycle != CallLifecycle.active) {
      return _withEffects(
        current,
        event,
        <CallEffect>[
          CallEffect.recordDiagnosticEvent(
            callId: event.callId,
            code: 'route.open_failed_ignored',
            reason: event.reason,
          ),
        ],
      );
    }

    final effects = <CallEffect>[
      CallEffect.recordDiagnosticEvent(
        callId: event.callId,
        code: 'route.open_failed',
        reason: event.reason,
      ),
      CallEffect.openCallRoute(event.callId),
    ];
    final next = current.copyWith(
      callRouteState: CallRouteState.opening,
      localPhase: CallLocalPhase.openingCallRoute,
    );
    return _withEffects(next, event, effects);
  }

  CallReduction _reduceRouteClosed(
    CallSessionState current,
    RouteClosed event,
  ) {
    if (current.callId == null) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    final next = current.copyWith(
      incomingRoutePresented: false,
      callRouteState: CallRouteState.closed,
      localPhase:
          current.isTerminal ? CallLocalPhase.closing : current.localPhase,
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
      CallEffect.clearScopedLocalSession(callId),
    ];
  }
}
