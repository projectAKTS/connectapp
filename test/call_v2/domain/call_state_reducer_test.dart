import 'package:connect_app/call_v2/domain/call_effect.dart';
import 'package:connect_app/call_v2/domain/call_event.dart';
import 'package:connect_app/call_v2/domain/call_lifecycle.dart';
import 'package:connect_app/call_v2/domain/call_local_phase.dart';
import 'package:connect_app/call_v2/domain/call_session_state.dart';
import 'package:connect_app/call_v2/domain/call_snapshot.dart';
import 'package:connect_app/call_v2/domain/call_state_reducer.dart';
import 'package:connect_app/call_v2/domain/participant_media_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const reducer = CallStateReducer();

  group('CallStateReducer', () {
    test('initial idle state receives a ringing snapshot', () {
      final reduction = reducer.reduce(
        CallSessionState.initial(),
        _snapshotEvent(lifecycle: CallLifecycle.ringing),
      );

      expect(reduction.state.callId, 'call_a');
      expect(reduction.state.lifecycle, CallLifecycle.ringing);
      expect(reduction.state.localPhase, CallLocalPhase.presentingIncoming);
      expect(
        reduction.effects,
        contains(const CallEffect.presentIncomingRoute('call_a')),
      );
    });

    test('duplicate ringing snapshot produces no duplicate presentation effect',
        () {
      final event = _snapshotEvent(lifecycle: CallLifecycle.ringing);

      final first = reducer.reduce(CallSessionState.initial(), event);
      final second = reducer.reduce(first.state, event);

      expect(first.effects.where(_isPresentIncoming), hasLength(1));
      expect(second.effects.where(_isPresentIncoming), isEmpty);
    });

    test('older snapshot version is ignored', () {
      final accepted = reducer.reduce(
        CallSessionState.initial(),
        _snapshotEvent(version: 2, lifecycle: CallLifecycle.accepted),
      );

      final stale = reducer.reduce(
        accepted.state,
        _snapshotEvent(version: 1, lifecycle: CallLifecycle.ringing),
      );

      expect(stale.state.lifecycle, CallLifecycle.accepted);
      expect(stale.state.latestAuthoritativeVersion, 2);
      expect(stale.effects, isEmpty);
    });

    test('snapshot for another callId is rejected while a session is active',
        () {
      final active = reducer.reduce(
        CallSessionState.initial(),
        _snapshotEvent(callId: 'call_a'),
      );

      final unrelated = reducer.reduce(
        active.state,
        _snapshotEvent(callId: 'call_b', version: 2),
      );

      expect(unrelated.state.callId, 'call_a');
      expect(unrelated.effects, isEmpty);
    });

    test('ringing transitions to accepted from authoritative snapshot', () {
      final ringing = _withSnapshot(CallLifecycle.ringing);
      final accepted = reducer.reduce(
        ringing.state,
        _snapshotEvent(version: 2, lifecycle: CallLifecycle.accepted),
      );

      expect(accepted.state.lifecycle, CallLifecycle.accepted);
      expect(accepted.state.callRouteState, CallRouteState.opening);
      expect(
        accepted.effects,
        contains(const CallEffect.openCallRoute('call_a')),
      );
      expect(accepted.effects.where(_isJoinAgora), isEmpty);
    });

    test(
        'both participants joined while backend lifecycle is accepted remains accepted',
        () {
      final reduction = reducer.reduce(
        CallSessionState.initial(),
        _snapshotEvent(
          lifecycle: CallLifecycle.accepted,
          callerMediaState: ParticipantMediaState.joined,
          calleeMediaState: ParticipantMediaState.joined,
        ),
      );

      expect(reduction.state.lifecycle, CallLifecycle.accepted);
      expect(reduction.state.localMediaState, ParticipantMediaState.joined);
      expect(reduction.state.peerMediaState, ParticipantMediaState.joined);
    });

    test('only an authoritative active snapshot sets active', () {
      final accepted = reducer.reduce(
        CallSessionState.initial(),
        _snapshotEvent(
          lifecycle: CallLifecycle.accepted,
          callerMediaState: ParticipantMediaState.joined,
          calleeMediaState: ParticipantMediaState.joined,
        ),
      );
      final active = reducer.reduce(
        accepted.state,
        _snapshotEvent(
          version: 2,
          lifecycle: CallLifecycle.active,
          callerMediaState: ParticipantMediaState.joined,
          calleeMediaState: ParticipantMediaState.joined,
        ),
      );

      expect(accepted.state.lifecycle, CallLifecycle.accepted);
      expect(active.state.lifecycle, CallLifecycle.active);
    });

    test('remoteDetected alone does not promote to active', () {
      final accepted = _withSnapshot(CallLifecycle.accepted);
      final detected = reducer.reduce(
        accepted.state,
        const RemoteDetected(callId: 'call_a', eventId: 'remote-1'),
      );

      expect(detected.state.lifecycle, CallLifecycle.accepted);
      expect(
        detected.effects,
        contains(
          const CallEffect.recordDiagnosticEvent(
            callId: 'call_a',
            code: 'agora.remote_detected',
          ),
        ),
      );
    });

    test('active transitions to completed from authoritative snapshot', () {
      final active = _withSnapshot(CallLifecycle.active);
      final completed = reducer.reduce(
        active.state,
        _snapshotEvent(version: 2, lifecycle: CallLifecycle.completed),
      );

      expect(completed.state.lifecycle, CallLifecycle.completed);
      expect(completed.state.cleanupStatus, CleanupStatus.requested);
      expect(completed.effects,
          contains(const CallEffect.closeCallRoute('call_a')));
      expect(
          completed.effects, contains(const CallEffect.leaveAgora('call_a')));
    });

    test('ringing transitions to declined', () {
      final ringing = _withSnapshot(CallLifecycle.ringing);
      final declined = reducer.reduce(
        ringing.state,
        _snapshotEvent(version: 2, lifecycle: CallLifecycle.declined),
      );

      expect(declined.state.lifecycle, CallLifecycle.declined);
    });

    test('ringing transitions to cancelled', () {
      final ringing = _withSnapshot(CallLifecycle.ringing);
      final cancelled = reducer.reduce(
        ringing.state,
        _snapshotEvent(version: 2, lifecycle: CallLifecycle.cancelled),
      );

      expect(cancelled.state.lifecycle, CallLifecycle.cancelled);
    });

    test('ringing transitions to missed', () {
      final ringing = _withSnapshot(CallLifecycle.ringing);
      final missed = reducer.reduce(
        ringing.state,
        _snapshotEvent(version: 2, lifecycle: CallLifecycle.missed),
      );

      expect(missed.state.lifecycle, CallLifecycle.missed);
    });

    test('accepted transitions to failed', () {
      final accepted = _withSnapshot(CallLifecycle.accepted);
      final failed = reducer.reduce(
        accepted.state,
        _snapshotEvent(version: 2, lifecycle: CallLifecycle.failed),
      );

      expect(failed.state.lifecycle, CallLifecycle.failed);
    });

    test('terminal to non-terminal transition is rejected', () {
      final completed = _withSnapshot(CallLifecycle.completed);
      final rejected = reducer.reduce(
        completed.state,
        _snapshotEvent(version: 2, lifecycle: CallLifecycle.accepted),
      );

      expect(rejected.state.lifecycle, CallLifecycle.completed);
      expect(rejected.effects, isEmpty);
    });

    test('duplicate terminal snapshot does not emit duplicate cleanup effects',
        () {
      final ringing = _withSnapshot(CallLifecycle.ringing);
      final terminalEvent =
          _snapshotEvent(version: 2, lifecycle: CallLifecycle.completed);

      final first = reducer.reduce(ringing.state, terminalEvent);
      final second = reducer.reduce(first.state, terminalEvent);

      expect(first.effects.where(_isCleanupEffect), hasLength(4));
      expect(second.effects.where(_isCleanupEffect), isEmpty);
    });

    test('route presentation is emitted at most once per callId', () {
      var state = CallSessionState.initial();
      for (var version = 1; version <= 3; version++) {
        final reduction = reducer.reduce(
          state,
          _snapshotEvent(
            version: version,
            lifecycle: CallLifecycle.ringing,
          ),
        );
        state = reduction.state;
        if (version == 1) {
          expect(reduction.effects.where(_isPresentIncoming), hasLength(1));
        } else {
          expect(reduction.effects.where(_isPresentIncoming), isEmpty);
        }
      }
    });

    test('route closure is idempotent', () {
      final accepted = _withSnapshot(CallLifecycle.accepted);
      final opened = reducer.reduce(
        accepted.state,
        const RouteOpened(callId: 'call_a', eventId: 'route-open-1'),
      );
      final firstClose = reducer.reduce(
        opened.state,
        const RouteClosed(callId: 'call_a', eventId: 'route-close-1'),
      );
      final secondClose = reducer.reduce(
        firstClose.state,
        const RouteClosed(callId: 'call_a', eventId: 'route-close-2'),
      );

      expect(firstClose.state.callRouteState, CallRouteState.closed);
      expect(secondClose.state.callRouteState, CallRouteState.closed);
      expect(secondClose.effects, isEmpty);
    });

    test('media reconnecting and rejoined keep active lifecycle', () {
      final active = _withSnapshot(CallLifecycle.active);
      final reconnecting = reducer.reduce(
        active.state,
        const MediaReconnecting(callId: 'call_a', eventId: 'reconnect-1'),
      );
      final rejoined = reducer.reduce(
        reconnecting.state,
        const MediaReconnected(callId: 'call_a', eventId: 'rejoined-1'),
      );

      expect(reconnecting.state.lifecycle, CallLifecycle.active);
      expect(
        reconnecting.state.localMediaState,
        ParticipantMediaState.reconnecting,
      );
      expect(rejoined.state.lifecycle, CallLifecycle.active);
      expect(rejoined.state.localMediaState, ParticipantMediaState.joined);
    });

    test('stale snapshot cannot reopen UI', () {
      final accepted = _withSnapshot(CallLifecycle.accepted, version: 5);
      final staleRinging = reducer.reduce(
        accepted.state,
        _snapshotEvent(version: 4, lifecycle: CallLifecycle.ringing),
      );

      expect(staleRinging.state.lifecycle, CallLifecycle.accepted);
      expect(staleRinging.effects.where(_isPresentIncoming), isEmpty);
    });

    test('cleanup effects are scoped to the matching callId', () {
      final ringing = _withSnapshot(CallLifecycle.ringing);
      final completed = reducer.reduce(
        ringing.state,
        _snapshotEvent(version: 2, lifecycle: CallLifecycle.completed),
      );

      expect(completed.effects.where(_isCleanupEffect), isNotEmpty);
      expect(
        completed.effects
            .where(_isCleanupEffect)
            .map((effect) => effect.callId),
        everyElement('call_a'),
      );
    });

    test('prepare and join request events do not form callback effect loops',
        () {
      final accepted = _withSnapshot(CallLifecycle.accepted);
      final prepareRequest = reducer.reduce(
        accepted.state,
        const PrepareMediaRequested(callId: 'call_a', eventId: 'prepare-req-1'),
      );
      final preparingCallback = reducer.reduce(
        prepareRequest.state,
        const LocalMediaPreparing(callId: 'call_a', eventId: 'preparing-cb-1'),
      );
      final joinRequest = reducer.reduce(
        preparingCallback.state,
        const JoinMediaRequested(callId: 'call_a', eventId: 'join-req-1'),
      );
      final joiningCallback = reducer.reduce(
        joinRequest.state,
        const LocalMediaJoining(callId: 'call_a', eventId: 'joining-cb-1'),
      );
      final joinedCallback = reducer.reduce(
        joiningCallback.state,
        const LocalMediaJoined(callId: 'call_a', eventId: 'joined-cb-1'),
      );

      expect(prepareRequest.effects, [const CallEffect.prepareAgora('call_a')]);
      expect(preparingCallback.effects.where(_isPrepareAgora), isEmpty);
      expect(
        preparingCallback.effects.single.command,
        BackendCommandType.reportMediaPreparing,
      );
      expect(joinRequest.effects, [const CallEffect.joinAgora('call_a')]);
      expect(joiningCallback.effects.where(_isJoinAgora), isEmpty);
      expect(
        joiningCallback.effects.single.command,
        BackendCommandType.reportMediaJoining,
      );
      expect(joinedCallback.effects.where(_isJoinAgora), isEmpty);
      expect(
        joinedCallback.effects.single.command,
        BackendCommandType.reportMediaJoined,
      );
    });

    test('two reconnect cycles with different event IDs are both processed',
        () {
      final active = _withSnapshot(CallLifecycle.active);
      final reconnectOne = reducer.reduce(
        active.state,
        const MediaReconnecting(callId: 'call_a', eventId: 'reconnect-1'),
      );
      final rejoinedOne = reducer.reduce(
        reconnectOne.state,
        const MediaReconnected(callId: 'call_a', eventId: 'rejoined-1'),
      );
      final reconnectTwo = reducer.reduce(
        rejoinedOne.state,
        const MediaReconnecting(callId: 'call_a', eventId: 'reconnect-2'),
      );

      expect(
        reconnectOne.effects.single.command,
        BackendCommandType.reportMediaConnection,
      );
      expect(
        reconnectTwo.effects.single.command,
        BackendCommandType.reportMediaConnection,
      );
      expect(reconnectTwo.state.localMediaState,
          ParticipantMediaState.reconnecting);
    });

    test('the same reconnect ID is processed once', () {
      final active = _withSnapshot(CallLifecycle.active);
      const event = MediaReconnecting(
        callId: 'call_a',
        eventId: 'reconnect-1',
      );

      final first = reducer.reduce(active.state, event);
      final second = reducer.reduce(first.state, event);

      expect(first.effects.single.command,
          BackendCommandType.reportMediaConnection);
      expect(second.effects, isEmpty);
    });

    test('terminal snapshot sets cleanup to requested, not completed', () {
      final ringing = _withSnapshot(CallLifecycle.ringing);
      final terminal = reducer.reduce(
        ringing.state,
        _snapshotEvent(version: 2, lifecycle: CallLifecycle.completed),
      );

      expect(terminal.state.cleanupStatus, CleanupStatus.requested);
      expect(terminal.state.isIdle, isFalse);
    });

    test('matching cleanup completion returns state to true idle', () {
      final terminal = reducer.reduce(
        _withSnapshot(CallLifecycle.ringing).state,
        _snapshotEvent(version: 2, lifecycle: CallLifecycle.completed),
      );
      final idle = reducer.reduce(
        terminal.state,
        const CleanupCompleted(callId: 'call_a', eventId: 'cleanup-done-1'),
      );

      expect(idle.state.isIdle, isTrue);
      expect(idle.state.callId, isNull);
      expect(idle.state.lifecycle, isNull);
      expect(idle.state.localParticipantRole, isNull);
      expect(idle.state.cleanupStatus, CleanupStatus.notRequested);
      expect(idle.state.processedEventIds, isEmpty);
    });

    test('a different call can begin after scoped cleanup', () {
      final terminal = reducer.reduce(
        _withSnapshot(CallLifecycle.ringing).state,
        _snapshotEvent(version: 2, lifecycle: CallLifecycle.completed),
      );
      final idle = reducer.reduce(
        terminal.state,
        const CleanupCompleted(callId: 'call_a', eventId: 'cleanup-done-1'),
      );
      final nextCall = reducer.reduce(
        idle.state,
        _snapshotEvent(callId: 'call_b', lifecycle: CallLifecycle.ringing),
      );

      expect(nextCall.state.callId, 'call_b');
      expect(nextCall.effects,
          contains(const CallEffect.presentIncomingRoute('call_b')));
    });

    test('route opening is acknowledged and safely retryable after failure',
        () {
      final accepted = _withSnapshot(CallLifecycle.accepted);
      expect(accepted.state.callRouteState, CallRouteState.opening);

      final failed = reducer.reduce(
        accepted.state,
        const RouteOpenFailed(
          callId: 'call_a',
          eventId: 'route-failed-1',
          reason: 'navigator_busy',
        ),
      );
      final opened = reducer.reduce(
        failed.state,
        const RouteOpened(callId: 'call_a', eventId: 'route-opened-1'),
      );

      expect(failed.effects.where(_isOpenCallRoute), hasLength(1));
      expect(failed.state.callRouteState, CallRouteState.opening);
      expect(opened.state.callRouteState, CallRouteState.open);
      expect(opened.state.localPhase, CallLocalPhase.inCall);
    });

    test('duplicate snapshots while opening do not open duplicate routes', () {
      final accepted = _withSnapshot(CallLifecycle.accepted);
      final duplicateSameVersion = reducer.reduce(
        accepted.state,
        _snapshotEvent(version: 1, lifecycle: CallLifecycle.accepted),
      );
      final newerWhileOpening = reducer.reduce(
        accepted.state,
        _snapshotEvent(version: 2, lifecycle: CallLifecycle.accepted),
      );

      expect(accepted.effects.where(_isOpenCallRoute), hasLength(1));
      expect(duplicateSameVersion.effects.where(_isOpenCallRoute), isEmpty);
      expect(newerWhileOpening.effects.where(_isOpenCallRoute), isEmpty);
      expect(newerWhileOpening.state.callRouteState, CallRouteState.opening);
    });
  });
}

CallReduction _withSnapshot(
  CallLifecycle lifecycle, {
  int version = 1,
  ParticipantMediaState callerMediaState = ParticipantMediaState.notJoined,
  ParticipantMediaState calleeMediaState = ParticipantMediaState.notJoined,
}) {
  const reducer = CallStateReducer();
  return reducer.reduce(
    CallSessionState.initial(),
    _snapshotEvent(
      version: version,
      lifecycle: lifecycle,
      callerMediaState: callerMediaState,
      calleeMediaState: calleeMediaState,
    ),
  );
}

CallSnapshotReceived _snapshotEvent({
  String callId = 'call_a',
  int version = 1,
  CallLifecycle lifecycle = CallLifecycle.ringing,
  ParticipantMediaState callerMediaState = ParticipantMediaState.notJoined,
  ParticipantMediaState calleeMediaState = ParticipantMediaState.notJoined,
}) {
  return CallSnapshotReceived(
    snapshot: CallSnapshot(
      callId: callId,
      version: version,
      lifecycle: lifecycle,
      callerUid: 'caller',
      calleeUid: 'callee',
      callerMediaState: callerMediaState,
      calleeMediaState: calleeMediaState,
    ),
    localParticipantRole: CallParticipantRole.callee,
  );
}

bool _isPresentIncoming(CallEffect effect) {
  return effect.type == CallEffectType.presentIncomingRoute;
}

bool _isOpenCallRoute(CallEffect effect) {
  return effect.type == CallEffectType.openCallRoute;
}

bool _isPrepareAgora(CallEffect effect) {
  return effect.type == CallEffectType.prepareAgora;
}

bool _isJoinAgora(CallEffect effect) {
  return effect.type == CallEffectType.joinAgora;
}

bool _isCleanupEffect(CallEffect effect) {
  return effect.type == CallEffectType.closeCallRoute ||
      effect.type == CallEffectType.leaveAgora ||
      effect.type == CallEffectType.endMatchingNativeCall ||
      effect.type == CallEffectType.clearScopedLocalSession;
}
