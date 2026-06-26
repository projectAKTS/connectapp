import 'dart:math';

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
      LocalMediaPreparing() => _reduceMediaState(
          current,
          event,
          ParticipantMediaState.preparing,
          const <CallEffect Function(String)>[
            CallEffect.prepareAgora,
          ],
          command: BackendCommandType.reportMediaPreparing,
        ),
      LocalMediaJoining() => _reduceMediaState(
          current,
          event,
          ParticipantMediaState.joining,
          const <CallEffect Function(String)>[
            CallEffect.joinAgora,
          ],
          command: BackendCommandType.reportMediaJoining,
        ),
      LocalMediaJoined() => _reduceMediaState(
          current,
          event,
          ParticipantMediaState.joined,
          const <CallEffect Function(String)>[],
          command: BackendCommandType.reportMediaJoined,
        ),
      PeerMediaJoined() => _reducePeerMediaJoined(current, event),
      RemoteDetected() => _reduceDiagnosticOnly(
          current,
          event,
          'agora.remote_detected',
        ),
      MediaReconnecting() => _reduceMediaState(
          current,
          event,
          ParticipantMediaState.reconnecting,
          const <CallEffect Function(String)>[],
          command: BackendCommandType.reportMediaConnection,
        ),
      MediaReconnected() => _reduceMediaState(
          current,
          event,
          ParticipantMediaState.joined,
          const <CallEffect Function(String)>[],
          command: BackendCommandType.reportMediaConnection,
        ),
      MediaFailed() => _reduceMediaState(
          current,
          event,
          ParticipantMediaState.mediaFailed,
          const <CallEffect Function(String)>[],
          command: BackendCommandType.reportCallFailure,
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
      RouteClosed() => _reduceRouteClosed(current, event),
      AppResumed() => _reduceDiagnosticOnly(
          current,
          event,
          'app.resumed',
        ),
    };
  }

  bool _canProcess(CallSessionState current, CallEvent event) {
    final activeCallId = current.callId;
    if (activeCallId != null && activeCallId != event.callId) {
      return false;
    }
    final eventVersion = event.version;
    if (eventVersion != null && eventVersion < current.latestVersion) {
      return false;
    }
    if (current.isTerminal && _eventLifecycle(event)?.isNonTerminal == true) {
      return false;
    }
    return true;
  }

  CallLifecycle? _eventLifecycle(CallEvent event) {
    return switch (event) {
      CallSnapshotReceived(:final snapshot) => snapshot.lifecycle,
      _ => null,
    };
  }

  CallReduction _reduceSnapshot(
    CallSessionState current,
    CallSnapshotReceived event,
  ) {
    final snapshot = event.snapshot;
    final lifecycle = _deriveLifecycle(
      snapshot.lifecycle,
      callerMediaState: snapshot.callerMediaState,
      calleeMediaState: snapshot.calleeMediaState,
    );
    if (current.isTerminal && lifecycle.isNonTerminal) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }

    final callId = snapshot.callId;
    final effects = <CallEffect>[];
    final localMediaState = snapshot.mediaStateFor(event.localParticipantRole);
    final peerMediaState =
        snapshot.peerMediaStateFor(event.localParticipantRole);
    var incomingRoutePresented = current.incomingRoutePresented;
    var callRouteOpening = current.callRouteOpening;
    var callRouteOpen = current.callRouteOpen;
    var terminalCleanupCompleted = current.terminalCleanupCompleted;
    var localPhase = current.localPhase;
    var presentedRouteCallIds = current.presentedRouteCallIds;
    var openedRouteCallIds = current.openedRouteCallIds;
    var cleanupCallIds = current.cleanupCallIds;

    if (lifecycle == CallLifecycle.ringing) {
      if (event.localParticipantRole == CallParticipantRole.callee &&
          !presentedRouteCallIds.contains(callId)) {
        effects.add(CallEffect.presentIncomingRoute(callId));
        presentedRouteCallIds = <String>{...presentedRouteCallIds, callId};
        incomingRoutePresented = true;
      }
      localPhase = event.localParticipantRole == CallParticipantRole.callee
          ? CallLocalPhase.presentingIncoming
          : CallLocalPhase.outgoingRinging;
    } else if (lifecycle == CallLifecycle.accepted ||
        lifecycle == CallLifecycle.active) {
      if (!openedRouteCallIds.contains(callId)) {
        effects.add(CallEffect.openCallRoute(callId));
        effects.add(CallEffect.joinAgora(callId));
        openedRouteCallIds = <String>{...openedRouteCallIds, callId};
        callRouteOpening = true;
      }
      localPhase = callRouteOpen
          ? CallLocalPhase.inCall
          : CallLocalPhase.openingCallRoute;
    } else if (lifecycle.isTerminal) {
      final cleanup = _terminalCleanupEffects(
        callId,
        cleanupCallIds,
      );
      effects.addAll(cleanup.effects);
      cleanupCallIds = cleanup.cleanupCallIds;
      terminalCleanupCompleted = true;
      incomingRoutePresented = false;
      callRouteOpening = false;
      callRouteOpen = false;
      localPhase = CallLocalPhase.closing;
    }

    final next = current
        .copyWith(
          callId: callId,
          latestVersion: max(current.latestVersion, snapshot.version),
          lifecycle: lifecycle,
          localParticipantRole: event.localParticipantRole,
          localMediaState: localMediaState,
          peerMediaState: peerMediaState,
          localPhase: localPhase,
          incomingRoutePresented: incomingRoutePresented,
          callRouteOpening: callRouteOpening,
          callRouteOpen: callRouteOpen,
          terminalCleanupCompleted: terminalCleanupCompleted,
          presentedRouteCallIds: presentedRouteCallIds,
          openedRouteCallIds: openedRouteCallIds,
          cleanupCallIds: cleanupCallIds,
        )
        .markProcessed(event.eventId);

    return CallReduction(state: next, effects: List.unmodifiable(effects));
  }

  CallReduction _reduceBackendCommand(
    CallSessionState current,
    CallEvent event,
    BackendCommandType command,
  ) {
    if (current.callId == null || current.isTerminal) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    final effects = <CallEffect>[
      CallEffect.requestBackendCommand(
        callId: event.callId,
        command: command,
      ),
    ];
    final next = current
        .copyWith(latestVersion: _nextVersion(current, event))
        .markProcessed(event.eventId);
    return CallReduction(state: next, effects: effects);
  }

  CallReduction _reduceMediaState(
    CallSessionState current,
    CallEvent event,
    ParticipantMediaState mediaState,
    List<CallEffect Function(String callId)> localEffects, {
    required BackendCommandType command,
    String? reason,
  }) {
    if (current.callId == null || current.isTerminal) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    final effects = <CallEffect>[
      for (final effect in localEffects) effect(event.callId),
      CallEffect.requestBackendCommand(
        callId: event.callId,
        command: command,
        reason: reason,
      ),
    ];
    final lifecycle = _deriveLifecycleFromLocal(
      current.lifecycle,
      localMediaState: mediaState,
      peerMediaState: current.peerMediaState,
    );
    if (lifecycle == CallLifecycle.active &&
        current.lifecycle == CallLifecycle.accepted) {
      effects.add(
        const CallEffect.requestBackendCommand(
          callId: '',
          command: BackendCommandType.promoteActive,
        ).forCall(event.callId),
      );
    }
    final next = current
        .copyWith(
          latestVersion: _nextVersion(current, event),
          lifecycle: lifecycle,
          localMediaState: mediaState,
          localPhase:
              lifecycle == CallLifecycle.active ? CallLocalPhase.inCall : null,
        )
        .markProcessed(event.eventId);
    return CallReduction(state: next, effects: List.unmodifiable(effects));
  }

  CallReduction _reducePeerMediaJoined(
    CallSessionState current,
    PeerMediaJoined event,
  ) {
    if (current.callId == null || current.isTerminal) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    final lifecycle = _deriveLifecycleFromLocal(
      current.lifecycle,
      localMediaState: current.localMediaState,
      peerMediaState: ParticipantMediaState.joined,
    );
    final effects = <CallEffect>[
      const CallEffect.recordDiagnosticEvent(
        callId: '',
        code: 'peer.media_joined',
      ).forCall(event.callId),
    ];
    if (lifecycle == CallLifecycle.active &&
        current.lifecycle == CallLifecycle.accepted) {
      effects.add(
        const CallEffect.requestBackendCommand(
          callId: '',
          command: BackendCommandType.promoteActive,
        ).forCall(event.callId),
      );
    }
    final next = current
        .copyWith(
          latestVersion: _nextVersion(current, event),
          lifecycle: lifecycle,
          peerMediaState: ParticipantMediaState.joined,
          localPhase:
              lifecycle == CallLifecycle.active ? CallLocalPhase.inCall : null,
        )
        .markProcessed(event.eventId);
    return CallReduction(state: next, effects: List.unmodifiable(effects));
  }

  CallReduction _reduceDiagnosticOnly(
    CallSessionState current,
    CallEvent event,
    String code,
  ) {
    if (current.callId == null) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    final next = current.markProcessed(event.eventId);
    return CallReduction(
      state: next,
      effects: <CallEffect>[
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
    final next = current
        .copyWith(nativePresentationState: nativeState)
        .markProcessed(event.eventId);
    return CallReduction(
      state: next,
      effects: <CallEffect>[
        CallEffect.recordDiagnosticEvent(callId: event.callId, code: code),
      ],
    );
  }

  CallReduction _reduceNativeCommand(
    CallSessionState current,
    CallEvent event,
    NativePresentationState nativeState,
    BackendCommandType command,
    String code,
  ) {
    if (current.callId == null || current.isTerminal) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    final next = current
        .copyWith(nativePresentationState: nativeState)
        .markProcessed(event.eventId);
    return CallReduction(
      state: next,
      effects: <CallEffect>[
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
    final next = current
        .copyWith(
          callRouteOpen: true,
          callRouteOpening: false,
          incomingRoutePresented: false,
          localPhase: current.isTerminal
              ? CallLocalPhase.closing
              : CallLocalPhase.inCall,
        )
        .markProcessed(event.eventId);
    return CallReduction(state: next, effects: const <CallEffect>[]);
  }

  CallReduction _reduceRouteClosed(
    CallSessionState current,
    RouteClosed event,
  ) {
    if (current.callId == null) {
      return CallReduction(state: current, effects: const <CallEffect>[]);
    }
    final alreadyClosed = !current.callRouteOpen &&
        !current.callRouteOpening &&
        !current.incomingRoutePresented;
    final next = current
        .copyWith(
          callRouteOpen: false,
          callRouteOpening: false,
          incomingRoutePresented: false,
          localPhase:
              current.isTerminal ? CallLocalPhase.closing : current.localPhase,
        )
        .markProcessed(event.eventId);
    return CallReduction(
      state: next,
      effects: alreadyClosed ? const <CallEffect>[] : const <CallEffect>[],
    );
  }

  CallLifecycle _deriveLifecycle(
    CallLifecycle lifecycle, {
    required ParticipantMediaState callerMediaState,
    required ParticipantMediaState calleeMediaState,
  }) {
    if (lifecycle == CallLifecycle.accepted &&
        callerMediaState == ParticipantMediaState.joined &&
        calleeMediaState == ParticipantMediaState.joined) {
      return CallLifecycle.active;
    }
    return lifecycle;
  }

  CallLifecycle? _deriveLifecycleFromLocal(
    CallLifecycle? lifecycle, {
    required ParticipantMediaState localMediaState,
    required ParticipantMediaState peerMediaState,
  }) {
    if (lifecycle == CallLifecycle.accepted &&
        localMediaState == ParticipantMediaState.joined &&
        peerMediaState == ParticipantMediaState.joined) {
      return CallLifecycle.active;
    }
    return lifecycle;
  }

  int _nextVersion(CallSessionState current, CallEvent event) {
    final eventVersion = event.version;
    if (eventVersion == null) return current.latestVersion;
    return max(current.latestVersion, eventVersion);
  }

  _TerminalCleanup _terminalCleanupEffects(
    String callId,
    Set<String> cleanupCallIds,
  ) {
    if (cleanupCallIds.contains(callId)) {
      return _TerminalCleanup(
        effects: const <CallEffect>[],
        cleanupCallIds: cleanupCallIds,
      );
    }
    return _TerminalCleanup(
      effects: <CallEffect>[
        CallEffect.closeCallRoute(callId),
        CallEffect.leaveAgora(callId),
        CallEffect.endMatchingNativeCall(callId),
        CallEffect.clearScopedLocalSession(callId),
      ],
      cleanupCallIds: <String>{...cleanupCallIds, callId},
    );
  }
}

class _TerminalCleanup {
  const _TerminalCleanup({
    required this.effects,
    required this.cleanupCallIds,
  });

  final List<CallEffect> effects;
  final Set<String> cleanupCallIds;
}

extension on CallEffect {
  CallEffect forCall(String callId) {
    return CallEffect(
      type: type,
      callId: callId,
      command: command,
      code: code,
      reason: reason,
    );
  }
}
