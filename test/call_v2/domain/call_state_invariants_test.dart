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

    test('version is monotonic', () {
      final versionThree = reducer.reduce(
        _stateWith(CallLifecycle.ringing),
        _snapshotEvent(version: 3, lifecycle: CallLifecycle.accepted),
      );
      final versionTwo = reducer.reduce(
        versionThree.state,
        _snapshotEvent(version: 2, lifecycle: CallLifecycle.ringing),
      );

      expect(versionThree.state.latestVersion, 3);
      expect(versionTwo.state.latestVersion, 3);
      expect(versionTwo.state.lifecycle, CallLifecycle.accepted);
    });

    test('callId isolation rejects unrelated events', () {
      final state = _stateWith(CallLifecycle.ringing);
      final unrelated = reducer.reduce(
        state,
        CallSnapshotReceived(
          snapshot: _snapshot(
            callId: 'other_call',
            version: 2,
            lifecycle: CallLifecycle.accepted,
            callerMediaState: ParticipantMediaState.notJoined,
            calleeMediaState: ParticipantMediaState.notJoined,
          ),
          localParticipantRole: CallParticipantRole.callee,
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
        version: 2,
        dedupeKey: 'media-joined-1',
      );

      final first = reducer.reduce(accepted, event);
      final second = reducer.reduce(first.state, event);

      expect(
        first.effects.where(_isReportMediaJoinedCommand),
        hasLength(1),
      );
      expect(second.effects.where(_isReportMediaJoinedCommand), isEmpty);
    });

    test('active promotion requires both participant media states joined', () {
      final oneJoined = reducer.reduce(
        CallSessionState.initial(),
        _snapshotEvent(
          lifecycle: CallLifecycle.accepted,
          callerMediaState: ParticipantMediaState.joined,
        ),
      );
      final bothJoined = reducer.reduce(
        CallSessionState.initial(),
        _snapshotEvent(
          lifecycle: CallLifecycle.accepted,
          callerMediaState: ParticipantMediaState.joined,
          calleeMediaState: ParticipantMediaState.joined,
        ),
      );

      expect(oneJoined.state.lifecycle, CallLifecycle.accepted);
      expect(bothJoined.state.lifecycle, CallLifecycle.active);
    });

    test('remote detection is diagnostic and not an active promotion input',
        () {
      final accepted = _stateWith(CallLifecycle.accepted);
      final remoteDetected = reducer.reduce(
        accepted,
        const RemoteDetected(callId: 'call_a', version: 2),
      );

      expect(remoteDetected.state.lifecycle, CallLifecycle.accepted);
      expect(
        remoteDetected.effects.single,
        const CallEffect.recordDiagnosticEvent(
          callId: 'call_a',
          code: 'agora.remote_detected',
        ),
      );
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
    snapshot: _snapshot(
      callId: callId,
      version: version,
      lifecycle: lifecycle,
      callerMediaState: callerMediaState,
      calleeMediaState: calleeMediaState,
    ),
    localParticipantRole: CallParticipantRole.callee,
  );
}

CallSnapshot _snapshot({
  required String callId,
  required int version,
  required CallLifecycle lifecycle,
  required ParticipantMediaState callerMediaState,
  required ParticipantMediaState calleeMediaState,
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

bool _isReportMediaJoinedCommand(CallEffect effect) {
  return effect.type == CallEffectType.requestBackendCommand &&
      effect.command == BackendCommandType.reportMediaJoined;
}

bool _isPresentIncoming(CallEffect effect) {
  return effect.type == CallEffectType.presentIncomingRoute;
}
