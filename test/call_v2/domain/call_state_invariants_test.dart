import 'package:connect_app/call_v2/domain/call_effect.dart';
import 'package:connect_app/call_v2/domain/call_event.dart';
import 'package:connect_app/call_v2/domain/call_lifecycle.dart';
import 'package:connect_app/call_v2/domain/call_session_state.dart';
import 'package:connect_app/call_v2/domain/call_snapshot.dart';
import 'package:connect_app/call_v2/domain/call_state_reducer.dart';
import 'package:connect_app/call_v2/domain/participant_media_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const reducer = CallStateReducer();

  group('CallStateReducer invariants', () {
    test('terminal lifecycle is monotonic', () {
      final terminal = reducer.reduce(
        _stateWith(CallLifecycle.ringing),
        _snapshotEvent(version: 2, lifecycle: CallLifecycle.completed),
      );
      final reopened = reducer.reduce(
        terminal.state,
        _snapshotEvent(version: 3, lifecycle: CallLifecycle.active),
      );

      expect(terminal.state.lifecycle, CallLifecycle.completed);
      expect(reopened.state.lifecycle, CallLifecycle.completed);
      expect(reopened.effects, isEmpty);
    });

    test('authoritative version is controlled by snapshots only', () {
      final versionThree = reducer.reduce(
        _stateWith(CallLifecycle.ringing),
        _snapshotEvent(version: 3, lifecycle: CallLifecycle.accepted),
      );
      final command = reducer.reduce(
        versionThree.state,
        const LocalUserEnded(callId: 'call_a', commandId: 'end-1'),
      );
      final media = reducer.reduce(
        command.state,
        const LocalMediaJoined(callId: 'call_a', eventId: 'media-joined-1'),
      );

      expect(versionThree.state.latestAuthoritativeVersion, 3);
      expect(command.state.latestAuthoritativeVersion, 3);
      expect(media.state.latestAuthoritativeVersion, 3);
    });

    test('older snapshot cannot reduce authoritative version', () {
      final versionThree = reducer.reduce(
        _stateWith(CallLifecycle.ringing),
        _snapshotEvent(version: 3, lifecycle: CallLifecycle.accepted),
      );
      final versionTwo = reducer.reduce(
        versionThree.state,
        _snapshotEvent(version: 2, lifecycle: CallLifecycle.ringing),
      );

      expect(versionTwo.state.latestAuthoritativeVersion, 3);
      expect(versionTwo.state.lifecycle, CallLifecycle.accepted);
    });

    test('callId isolation rejects unrelated events', () {
      final state = _stateWith(CallLifecycle.ringing);
      final unrelated = reducer.reduce(
        state,
        _snapshotEvent(
          callId: 'other_call',
          version: 2,
          lifecycle: CallLifecycle.accepted,
        ),
      );

      expect(unrelated.state.callId, 'call_a');
      expect(unrelated.state.lifecycle, CallLifecycle.ringing);
      expect(unrelated.effects, isEmpty);
    });

    test('duplicate event idempotency suppresses repeated command effects', () {
      final accepted = _stateWith(CallLifecycle.accepted);
      const event = LocalMediaJoined(
        callId: 'call_a',
        eventId: 'media-joined-1',
      );

      final first = reducer.reduce(accepted, event);
      final second = reducer.reduce(first.state, event);

      expect(first.effects.where(_isReportMediaJoinedCommand), hasLength(1));
      expect(second.effects.where(_isReportMediaJoinedCommand), isEmpty);
    });

    test('active promotion is authoritative snapshot only', () {
      final bothJoinedAccepted = reducer.reduce(
        CallSessionState.initial(),
        _snapshotEvent(
          lifecycle: CallLifecycle.accepted,
          callerMediaState: ParticipantMediaState.joined,
          calleeMediaState: ParticipantMediaState.joined,
        ),
      );
      final active = reducer.reduce(
        bothJoinedAccepted.state,
        _snapshotEvent(
          version: 2,
          lifecycle: CallLifecycle.active,
          callerMediaState: ParticipantMediaState.joined,
          calleeMediaState: ParticipantMediaState.joined,
        ),
      );

      expect(bothJoinedAccepted.state.lifecycle, CallLifecycle.accepted);
      expect(active.state.lifecycle, CallLifecycle.active);
    });

    test('effect deduplication prevents repeated route presentation', () {
      final first = reducer.reduce(
        CallSessionState.initial(),
        _snapshotEvent(lifecycle: CallLifecycle.ringing),
      );
      final second = reducer.reduce(
        first.state,
        _snapshotEvent(version: 2, lifecycle: CallLifecycle.ringing),
      );

      expect(first.effects.where(_isPresentIncoming), hasLength(1));
      expect(second.effects.where(_isPresentIncoming), isEmpty);
    });

    test('processed event IDs are bounded during a long session', () {
      var state = _stateWith(CallLifecycle.active);
      for (var i = 0; i < CallSessionState.maxProcessedEventIds + 10; i++) {
        state = reducer
            .reduce(
              state,
              MediaReconnecting(callId: 'call_a', eventId: 'reconnect-$i'),
            )
            .state;
      }

      expect(
        state.processedEventIds.length,
        CallSessionState.maxProcessedEventIds,
      );
    });

    test('dedupe state is removed when the session clears', () {
      final terminal = reducer.reduce(
        _stateWith(CallLifecycle.ringing),
        _snapshotEvent(version: 2, lifecycle: CallLifecycle.completed),
      );
      final idle = reducer.reduce(
        terminal.state,
        const CleanupCompleted(callId: 'call_a', eventId: 'cleanup-done-1'),
      );

      expect(terminal.state.processedEventIds, isNotEmpty);
      expect(idle.state.isIdle, isTrue);
      expect(idle.state.processedEventIds, isEmpty);
    });
  });
}

CallSessionState _stateWith(CallLifecycle lifecycle) {
  const reducer = CallStateReducer();
  return reducer
      .reduce(
        CallSessionState.initial(),
        _snapshotEvent(lifecycle: lifecycle),
      )
      .state;
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

bool _isReportMediaJoinedCommand(CallEffect effect) {
  return effect.type == CallEffectType.requestBackendCommand &&
      effect.command == BackendCommandType.reportMediaJoined;
}

bool _isPresentIncoming(CallEffect effect) {
  return effect.type == CallEffectType.presentIncomingRoute;
}
