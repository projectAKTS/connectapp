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
        CallSnapshotReceived(
          snapshot: _snapshot(lifecycle: CallLifecycle.ringing),
          localParticipantRole: CallParticipantRole.callee,
        ),
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
      final event = CallSnapshotReceived(
        snapshot: _snapshot(lifecycle: CallLifecycle.ringing),
        localParticipantRole: CallParticipantRole.callee,
      );

      final first = reducer.reduce(CallSessionState.initial(), event);
      final second = reducer.reduce(first.state, event);

      expect(first.effects.where(_isPresentIncoming), hasLength(1));
      expect(second.effects.where(_isPresentIncoming), isEmpty);
    });

    test('older snapshot version is ignored', () {
      final accepted = reducer.reduce(
        CallSessionState.initial(),
        CallSnapshotReceived(
          snapshot: _snapshot(
            version: 2,
            lifecycle: CallLifecycle.accepted,
          ),
          localParticipantRole: CallParticipantRole.callee,
        ),
      );

      final stale = reducer.reduce(
        accepted.state,
        CallSnapshotReceived(
          snapshot: _snapshot(version: 1, lifecycle: CallLifecycle.ringing),
          localParticipantRole: CallParticipantRole.callee,
        ),
      );

      expect(stale.state.lifecycle, CallLifecycle.accepted);
      expect(stale.state.latestVersion, 2);
      expect(stale.effects, isEmpty);
    });

    test('snapshot for another callId is rejected while a session is active',
        () {
      final active = reducer.reduce(
        CallSessionState.initial(),
        CallSnapshotReceived(
          snapshot: _snapshot(callId: 'call_a'),
          localParticipantRole: CallParticipantRole.callee,
        ),
      );

      final unrelated = reducer.reduce(
        active.state,
        CallSnapshotReceived(
          snapshot: _snapshot(callId: 'call_b', version: 2),
          localParticipantRole: CallParticipantRole.callee,
        ),
      );

      expect(unrelated.state.callId, 'call_a');
      expect(unrelated.effects, isEmpty);
    });

    test('ringing transitions to accepted', () {
      final ringing = _withSnapshot(CallLifecycle.ringing);
      final accepted = reducer.reduce(
        ringing.state,
        CallSnapshotReceived(
          snapshot: _snapshot(version: 2, lifecycle: CallLifecycle.accepted),
          localParticipantRole: CallParticipantRole.callee,
        ),
      );

      expect(accepted.state.lifecycle, CallLifecycle.accepted);
      expect(
          accepted.effects, contains(const CallEffect.openCallRoute('call_a')));
      expect(accepted.effects, contains(const CallEffect.joinAgora('call_a')));
    });

    test('accepted with only caller joined remains accepted', () {
      final reduction = reducer.reduce(
        CallSessionState.initial(),
        CallSnapshotReceived(
          snapshot: _snapshot(
            lifecycle: CallLifecycle.accepted,
            callerMediaState: ParticipantMediaState.joined,
          ),
          localParticipantRole: CallParticipantRole.callee,
        ),
      );

      expect(reduction.state.lifecycle, CallLifecycle.accepted);
    });

    test('accepted with both caller and callee joined becomes active', () {
      final reduction = reducer.reduce(
        CallSessionState.initial(),
        CallSnapshotReceived(
          snapshot: _snapshot(
            lifecycle: CallLifecycle.accepted,
            callerMediaState: ParticipantMediaState.joined,
            calleeMediaState: ParticipantMediaState.joined,
          ),
          localParticipantRole: CallParticipantRole.callee,
        ),
      );

      expect(reduction.state.lifecycle, CallLifecycle.active);
    });

    test('remoteDetected alone does not promote to active', () {
      final accepted = _withSnapshot(CallLifecycle.accepted);
      final detected = reducer.reduce(
        accepted.state,
        const RemoteDetected(callId: 'call_a', version: 2),
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

    test('active transitions to completed', () {
      final active = _withSnapshot(
        CallLifecycle.active,
        callerMediaState: ParticipantMediaState.joined,
        calleeMediaState: ParticipantMediaState.joined,
      );
      final completed = reducer.reduce(
        active.state,
        TerminalSnapshotReceived(
          snapshot: _snapshot(version: 2, lifecycle: CallLifecycle.completed),
          localParticipantRole: CallParticipantRole.callee,
        ),
      );

      expect(completed.state.lifecycle, CallLifecycle.completed);
      expect(completed.effects,
          contains(const CallEffect.closeCallRoute('call_a')));
      expect(
          completed.effects, contains(const CallEffect.leaveAgora('call_a')));
    });

    test('ringing transitions to declined', () {
      final ringing = _withSnapshot(CallLifecycle.ringing);
      final declined = reducer.reduce(
        ringing.state,
        TerminalSnapshotReceived(
          snapshot: _snapshot(version: 2, lifecycle: CallLifecycle.declined),
          localParticipantRole: CallParticipantRole.callee,
        ),
      );

      expect(declined.state.lifecycle, CallLifecycle.declined);
    });

    test('ringing transitions to cancelled', () {
      final ringing = _withSnapshot(CallLifecycle.ringing);
      final cancelled = reducer.reduce(
        ringing.state,
        TerminalSnapshotReceived(
          snapshot: _snapshot(version: 2, lifecycle: CallLifecycle.cancelled),
          localParticipantRole: CallParticipantRole.callee,
        ),
      );

      expect(cancelled.state.lifecycle, CallLifecycle.cancelled);
    });

    test('ringing transitions to missed', () {
      final ringing = _withSnapshot(CallLifecycle.ringing);
      final missed = reducer.reduce(
        ringing.state,
        TerminalSnapshotReceived(
          snapshot: _snapshot(version: 2, lifecycle: CallLifecycle.missed),
          localParticipantRole: CallParticipantRole.callee,
        ),
      );

      expect(missed.state.lifecycle, CallLifecycle.missed);
    });

    test('accepted transitions to failed', () {
      final accepted = _withSnapshot(CallLifecycle.accepted);
      final failed = reducer.reduce(
        accepted.state,
        TerminalSnapshotReceived(
          snapshot: _snapshot(version: 2, lifecycle: CallLifecycle.failed),
          localParticipantRole: CallParticipantRole.callee,
        ),
      );

      expect(failed.state.lifecycle, CallLifecycle.failed);
    });

    test('terminal to non-terminal transition is rejected', () {
      final completed = _withSnapshot(CallLifecycle.completed);
      final rejected = reducer.reduce(
        completed.state,
        CallSnapshotReceived(
          snapshot: _snapshot(version: 2, lifecycle: CallLifecycle.accepted),
          localParticipantRole: CallParticipantRole.callee,
        ),
      );

      expect(rejected.state.lifecycle, CallLifecycle.completed);
      expect(rejected.effects, isEmpty);
    });

    test('duplicate terminal event does not emit duplicate cleanup effects',
        () {
      final ringing = _withSnapshot(CallLifecycle.ringing);
      final terminalEvent = TerminalSnapshotReceived(
        snapshot: _snapshot(version: 2, lifecycle: CallLifecycle.completed),
        localParticipantRole: CallParticipantRole.callee,
      );

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
          CallSnapshotReceived(
            snapshot: _snapshot(
              version: version,
              lifecycle: CallLifecycle.ringing,
            ),
            localParticipantRole: CallParticipantRole.callee,
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
        const RouteOpened(callId: 'call_a', version: 2),
      );
      final firstClose = reducer.reduce(
        opened.state,
        const RouteClosed(callId: 'call_a', version: 3, dedupeKey: 'close-1'),
      );
      final secondClose = reducer.reduce(
        firstClose.state,
        const RouteClosed(callId: 'call_a', version: 4, dedupeKey: 'close-2'),
      );

      expect(firstClose.state.callRouteOpen, isFalse);
      expect(secondClose.state.callRouteOpen, isFalse);
      expect(secondClose.effects, isEmpty);
    });

    test('media reconnecting and rejoined keep active lifecycle', () {
      final active = _withSnapshot(
        CallLifecycle.active,
        callerMediaState: ParticipantMediaState.joined,
        calleeMediaState: ParticipantMediaState.joined,
      );
      final reconnecting = reducer.reduce(
        active.state,
        const MediaReconnecting(callId: 'call_a', version: 2),
      );
      final rejoined = reducer.reduce(
        reconnecting.state,
        const MediaReconnected(callId: 'call_a', version: 3),
      );

      expect(reconnecting.state.lifecycle, CallLifecycle.active);
      expect(reconnecting.state.localMediaState,
          ParticipantMediaState.reconnecting);
      expect(rejoined.state.lifecycle, CallLifecycle.active);
      expect(rejoined.state.localMediaState, ParticipantMediaState.joined);
    });

    test('event with stale version cannot reopen UI', () {
      final accepted = _withSnapshot(CallLifecycle.accepted, version: 5);
      final staleRinging = reducer.reduce(
        accepted.state,
        CallSnapshotReceived(
          snapshot: _snapshot(version: 4, lifecycle: CallLifecycle.ringing),
          localParticipantRole: CallParticipantRole.callee,
        ),
      );

      expect(staleRinging.state.lifecycle, CallLifecycle.accepted);
      expect(staleRinging.effects.where(_isPresentIncoming), isEmpty);
    });

    test('cleanup effects are scoped to the matching callId', () {
      final ringing = _withSnapshot(CallLifecycle.ringing);
      final completed = reducer.reduce(
        ringing.state,
        TerminalSnapshotReceived(
          snapshot: _snapshot(version: 2, lifecycle: CallLifecycle.completed),
          localParticipantRole: CallParticipantRole.callee,
        ),
      );

      expect(completed.effects.where(_isCleanupEffect), isNotEmpty);
      expect(
        completed.effects
            .where(_isCleanupEffect)
            .map((effect) => effect.callId),
        everyElement('call_a'),
      );
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
    CallSnapshotReceived(
      snapshot: _snapshot(
        version: version,
        lifecycle: lifecycle,
        callerMediaState: callerMediaState,
        calleeMediaState: calleeMediaState,
      ),
      localParticipantRole: CallParticipantRole.callee,
    ),
  );
}

CallSnapshot _snapshot({
  String callId = 'call_a',
  int version = 1,
  CallLifecycle lifecycle = CallLifecycle.ringing,
  ParticipantMediaState callerMediaState = ParticipantMediaState.notJoined,
  ParticipantMediaState calleeMediaState = ParticipantMediaState.notJoined,
}) {
  return CallSnapshot(
    callId: callId,
    version: version,
    lifecycle: lifecycle,
    callerUid: 'caller',
    calleeUid: 'callee',
    callerMediaState: callerMediaState,
    calleeMediaState: calleeMediaState,
  );
}

bool _isPresentIncoming(CallEffect effect) {
  return effect.type == CallEffectType.presentIncomingRoute;
}

bool _isCleanupEffect(CallEffect effect) {
  return effect.type == CallEffectType.closeCallRoute ||
      effect.type == CallEffectType.leaveAgora ||
      effect.type == CallEffectType.endMatchingNativeCall ||
      effect.type == CallEffectType.clearScopedLocalSession;
}
