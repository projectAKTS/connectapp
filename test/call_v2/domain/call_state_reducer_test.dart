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

  group('authoritative snapshot reduction', () {
    test('initial idle state receives a ringing snapshot', () {
      final reduction = reducer.reduce(
        CallSessionState.initial(),
        _snapshotEvent(lifecycle: CallLifecycle.ringing),
      );

      expect(reduction.state.callId, 'call_a');
      expect(reduction.state.lifecycle, CallLifecycle.ringing);
      expect(reduction.state.localPhase, CallLocalPhase.presentingIncoming);
      expect(reduction.state.incomingRouteState, IncomingRouteState.opening);
      expect(
        reduction.effects,
        contains(const CallEffect.presentIncomingRoute('call_a')),
      );
    });

    test('older durable snapshot version is ignored for lifecycle', () {
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

    test(
        'both participants joined while backend lifecycle is accepted remains accepted',
        () {
      final reduction = reducer.reduce(
        CallSessionState.initial(),
        _snapshotEvent(
          lifecycle: CallLifecycle.accepted,
          callerMediaState: ParticipantMediaState.joined,
          calleeMediaState: ParticipantMediaState.joined,
          callerMediaVersion: 2,
          calleeMediaVersion: 2,
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
          callerMediaVersion: 2,
          calleeMediaVersion: 2,
        ),
      );
      final active = reducer.reduce(
        accepted.state,
        _snapshotEvent(
          version: 2,
          lifecycle: CallLifecycle.active,
          callerMediaState: ParticipantMediaState.joined,
          calleeMediaState: ParticipantMediaState.joined,
          callerMediaVersion: 2,
          calleeMediaVersion: 2,
        ),
      );

      expect(accepted.state.lifecycle, CallLifecycle.accepted);
      expect(active.state.lifecycle, CallLifecycle.active);
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
  });

  group('participant media revisions', () {
    test(
        'same durable call version with newer caller media version is processed',
        () {
      final base = reducer.reduce(
        CallSessionState.initial(),
        _snapshotEvent(
          version: 5,
          lifecycle: CallLifecycle.accepted,
          localParticipantRole: CallParticipantRole.caller,
          callerMediaVersion: 1,
          calleeMediaVersion: 1,
        ),
      );
      final callerJoined = reducer.reduce(
        base.state,
        _snapshotEvent(
          version: 5,
          lifecycle: CallLifecycle.accepted,
          localParticipantRole: CallParticipantRole.caller,
          callerMediaState: ParticipantMediaState.joined,
          callerMediaVersion: 2,
          calleeMediaVersion: 1,
        ),
      );

      expect(callerJoined.state.latestAuthoritativeVersion, 5);
      expect(callerJoined.state.lifecycle, CallLifecycle.accepted);
      expect(callerJoined.state.localMediaState, ParticipantMediaState.joined);
      expect(callerJoined.state.localMediaVersion, 2);
    });

    test('same composite snapshot revision is deduplicated', () {
      final event = _snapshotEvent(
        version: 5,
        lifecycle: CallLifecycle.accepted,
        callerMediaVersion: 1,
        calleeMediaVersion: 1,
      );

      final first = reducer.reduce(CallSessionState.initial(), event);
      final duplicate = reducer.reduce(first.state, event);

      expect(first.effects.where(_isOpenCallRoute), hasLength(1));
      expect(duplicate.effects, isEmpty);
    });

    test('older caller media version cannot regress caller state', () {
      final joined = reducer.reduce(
        CallSessionState.initial(),
        _snapshotEvent(
          version: 5,
          lifecycle: CallLifecycle.accepted,
          localParticipantRole: CallParticipantRole.caller,
          callerMediaState: ParticipantMediaState.joined,
          callerMediaVersion: 2,
          calleeMediaVersion: 1,
        ),
      );
      final staleCaller = reducer.reduce(
        joined.state,
        _snapshotEvent(
          version: 5,
          lifecycle: CallLifecycle.accepted,
          localParticipantRole: CallParticipantRole.caller,
          callerMediaState: ParticipantMediaState.notJoined,
          callerMediaVersion: 1,
          calleeMediaVersion: 1,
        ),
      );

      expect(staleCaller.state.localMediaState, ParticipantMediaState.joined);
      expect(staleCaller.state.localMediaVersion, 2);
    });

    test('newer caller state and newer callee state can arrive independently',
        () {
      final base = reducer.reduce(
        CallSessionState.initial(),
        _snapshotEvent(
          version: 5,
          lifecycle: CallLifecycle.accepted,
          localParticipantRole: CallParticipantRole.caller,
          callerMediaVersion: 1,
          calleeMediaVersion: 1,
        ),
      );
      final callerJoined = reducer.reduce(
        base.state,
        _snapshotEvent(
          version: 5,
          lifecycle: CallLifecycle.accepted,
          localParticipantRole: CallParticipantRole.caller,
          callerMediaState: ParticipantMediaState.joined,
          callerMediaVersion: 2,
          calleeMediaVersion: 1,
        ),
      );
      final calleeJoined = reducer.reduce(
        callerJoined.state,
        _snapshotEvent(
          version: 5,
          lifecycle: CallLifecycle.accepted,
          localParticipantRole: CallParticipantRole.caller,
          callerMediaState: ParticipantMediaState.joined,
          callerMediaVersion: 2,
          calleeMediaState: ParticipantMediaState.joined,
          calleeMediaVersion: 2,
        ),
      );

      expect(calleeJoined.state.localMediaState, ParticipantMediaState.joined);
      expect(calleeJoined.state.localMediaVersion, 2);
      expect(calleeJoined.state.peerMediaState, ParticipantMediaState.joined);
      expect(calleeJoined.state.peerMediaVersion, 2);
      expect(calleeJoined.state.lifecycle, CallLifecycle.accepted);
    });
  });

  group('media request and callback separation', () {
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
    });

    test('the same reconnect ID is processed once', () {
      final active = _withSnapshot(CallLifecycle.active);
      const event = MediaReconnecting(
        callId: 'call_a',
        eventId: 'reconnect-1',
      );

      final first = reducer.reduce(active.state, event);
      final second = reducer.reduce(first.state, event);

      expect(
        first.effects.single.command,
        BackendCommandType.reportMediaConnection,
      );
      expect(second.effects, isEmpty);
    });
  });

  group('incoming route acknowledgement', () {
    test(
        'ringing snapshot emits one incoming presentation effect and sets opening',
        () {
      final ringing = reducer.reduce(
        CallSessionState.initial(),
        _snapshotEvent(lifecycle: CallLifecycle.ringing),
      );

      expect(ringing.state.incomingRouteState, IncomingRouteState.opening);
      expect(ringing.effects.where(_isPresentIncoming), hasLength(1));
    });

    test('acknowledgement sets presented', () {
      final ringing = _withSnapshot(CallLifecycle.ringing);
      final presented = reducer.reduce(
        ringing.state,
        const IncomingRoutePresented(
          callId: 'call_a',
          eventId: 'incoming-presented-1',
        ),
      );

      expect(presented.state.incomingRouteState, IncomingRouteState.presented);
    });

    test(
        'duplicate ringing snapshots while opening or presented emit no duplicate effect',
        () {
      final opening = _withSnapshot(CallLifecycle.ringing);
      final newerWhileOpening = reducer.reduce(
        opening.state,
        _snapshotEvent(version: 2, lifecycle: CallLifecycle.ringing),
      );
      final presented = reducer.reduce(
        opening.state,
        const IncomingRoutePresented(
          callId: 'call_a',
          eventId: 'incoming-presented-1',
        ),
      );
      final newerWhilePresented = reducer.reduce(
        presented.state,
        _snapshotEvent(version: 3, lifecycle: CallLifecycle.ringing),
      );

      expect(newerWhileOpening.effects.where(_isPresentIncoming), isEmpty);
      expect(newerWhilePresented.effects.where(_isPresentIncoming), isEmpty);
    });

    test('failure sets failed and emits no automatic retry', () {
      final ringing = _withSnapshot(CallLifecycle.ringing);
      final failed = reducer.reduce(
        ringing.state,
        const IncomingRoutePresentationFailed(
          callId: 'call_a',
          eventId: 'incoming-failed-1',
          reason: 'navigator_busy',
        ),
      );

      expect(failed.state.incomingRouteState, IncomingRouteState.failed);
      expect(failed.effects.where(_isPresentIncoming), isEmpty);
      expect(failed.effects.single.type, CallEffectType.recordDiagnosticEvent);
    });

    test('explicit retry emits one presentation effect', () {
      final failed = reducer.reduce(
        _withSnapshot(CallLifecycle.ringing).state,
        const IncomingRoutePresentationFailed(
          callId: 'call_a',
          eventId: 'incoming-failed-1',
        ),
      );
      final retry = reducer.reduce(
        failed.state,
        const RetryIncomingRoutePresentationRequested(
          callId: 'call_a',
          eventId: 'incoming-retry-1',
        ),
      );

      expect(retry.state.incomingRouteState, IncomingRouteState.opening);
      expect(retry.effects.where(_isPresentIncoming), hasLength(1));
    });

    test('stale or unrelated acknowledgements are ignored', () {
      final ringing = _withSnapshot(CallLifecycle.ringing);
      final unrelated = reducer.reduce(
        ringing.state,
        const IncomingRoutePresented(
          callId: 'call_b',
          eventId: 'incoming-presented-other',
        ),
      );
      final presented = reducer.reduce(
        ringing.state,
        const IncomingRoutePresented(
          callId: 'call_a',
          eventId: 'incoming-presented-1',
        ),
      );
      final duplicate = reducer.reduce(
        presented.state,
        const IncomingRoutePresented(
          callId: 'call_a',
          eventId: 'incoming-presented-1',
        ),
      );

      expect(unrelated.state.incomingRouteState, IncomingRouteState.opening);
      expect(unrelated.effects, isEmpty);
      expect(duplicate.effects, isEmpty);
      expect(duplicate.state.incomingRouteState, IncomingRouteState.presented);
    });

    test('delayed incoming failure after successful presentation is ignored',
        () {
      final presented = reducer.reduce(
        _withSnapshot(CallLifecycle.ringing).state,
        const IncomingRoutePresented(
          callId: 'call_a',
          eventId: 'incoming-presented-1',
        ),
      );
      final lateFailure = reducer.reduce(
        presented.state,
        const IncomingRoutePresentationFailed(
          callId: 'call_a',
          eventId: 'incoming-failed-late-1',
        ),
      );

      expect(
          lateFailure.state.incomingRouteState, IncomingRouteState.presented);
      expect(lateFailure.effects, isEmpty);
    });

    test('delayed incoming success after failure is ignored until retry', () {
      final failed = reducer.reduce(
        _withSnapshot(CallLifecycle.ringing).state,
        const IncomingRoutePresentationFailed(
          callId: 'call_a',
          eventId: 'incoming-failed-1',
        ),
      );
      final lateSuccess = reducer.reduce(
        failed.state,
        const IncomingRoutePresented(
          callId: 'call_a',
          eventId: 'incoming-presented-late-1',
        ),
      );
      final retry = reducer.reduce(
        failed.state,
        const RetryIncomingRoutePresentationRequested(
          callId: 'call_a',
          eventId: 'incoming-retry-1',
        ),
      );
      final successAfterRetry = reducer.reduce(
        retry.state,
        const IncomingRoutePresented(
          callId: 'call_a',
          eventId: 'incoming-presented-2',
        ),
      );

      expect(lateSuccess.state.incomingRouteState, IncomingRouteState.failed);
      expect(lateSuccess.effects, isEmpty);
      expect(retry.state.incomingRouteState, IncomingRouteState.opening);
      expect(
        successAfterRetry.state.incomingRouteState,
        IncomingRouteState.presented,
      );
    });
  });

  group('call route acknowledgement and retry', () {
    test('accepted snapshot opens route and duplicate opening snapshots do not',
        () {
      final accepted = _withSnapshot(CallLifecycle.accepted);
      final duplicateSameRevision = reducer.reduce(
        accepted.state,
        _snapshotEvent(version: 1, lifecycle: CallLifecycle.accepted),
      );
      final newerWhileOpening = reducer.reduce(
        accepted.state,
        _snapshotEvent(version: 2, lifecycle: CallLifecycle.accepted),
      );

      expect(accepted.state.callRouteState, CallRouteState.opening);
      expect(accepted.effects.where(_isOpenCallRoute), hasLength(1));
      expect(duplicateSameRevision.effects.where(_isOpenCallRoute), isEmpty);
      expect(newerWhileOpening.effects.where(_isOpenCallRoute), isEmpty);
    });

    test('route opening is acknowledged', () {
      final accepted = _withSnapshot(CallLifecycle.accepted);
      final opened = reducer.reduce(
        accepted.state,
        const RouteOpened(callId: 'call_a', eventId: 'route-opened-1'),
      );

      expect(opened.state.callRouteState, CallRouteState.open);
      expect(opened.state.localPhase, CallLocalPhase.inCall);
    });

    test('delayed route failure after success is ignored', () {
      final opened = reducer.reduce(
        _withSnapshot(CallLifecycle.accepted).state,
        const RouteOpened(callId: 'call_a', eventId: 'route-opened-1'),
      );
      final lateFailure = reducer.reduce(
        opened.state,
        const RouteOpenFailed(
          callId: 'call_a',
          eventId: 'route-failed-late-1',
        ),
      );

      expect(lateFailure.state.callRouteState, CallRouteState.open);
      expect(lateFailure.effects, isEmpty);
    });

    test('delayed route success after failure is ignored until retry', () {
      final failed = reducer.reduce(
        _withSnapshot(CallLifecycle.accepted).state,
        const RouteOpenFailed(callId: 'call_a', eventId: 'route-failed-1'),
      );
      final lateSuccess = reducer.reduce(
        failed.state,
        const RouteOpened(callId: 'call_a', eventId: 'route-opened-late-1'),
      );
      final retry = reducer.reduce(
        failed.state,
        const RetryOpenCallRouteRequested(
          callId: 'call_a',
          eventId: 'route-retry-1',
        ),
      );
      final successAfterRetry = reducer.reduce(
        retry.state,
        const RouteOpened(callId: 'call_a', eventId: 'route-opened-2'),
      );

      expect(lateSuccess.state.callRouteState, CallRouteState.failed);
      expect(lateSuccess.effects, isEmpty);
      expect(retry.state.callRouteState, CallRouteState.opening);
      expect(successAfterRetry.state.callRouteState, CallRouteState.open);
    });

    test('route failure emits no immediate open effect', () {
      final accepted = _withSnapshot(CallLifecycle.accepted);
      final failed = reducer.reduce(
        accepted.state,
        const RouteOpenFailed(
          callId: 'call_a',
          eventId: 'route-failed-1',
          reason: 'navigator_busy',
        ),
      );

      expect(failed.state.callRouteState, CallRouteState.failed);
      expect(failed.effects.where(_isOpenCallRoute), isEmpty);
      expect(failed.effects.single.type, CallEffectType.recordDiagnosticEvent);
    });

    test('explicit retry emits exactly one open effect', () {
      final failed = reducer.reduce(
        _withSnapshot(CallLifecycle.accepted).state,
        const RouteOpenFailed(callId: 'call_a', eventId: 'route-failed-1'),
      );
      final retry = reducer.reduce(
        failed.state,
        const RetryOpenCallRouteRequested(
          callId: 'call_a',
          eventId: 'route-retry-1',
        ),
      );

      expect(retry.state.callRouteState, CallRouteState.opening);
      expect(retry.effects.where(_isOpenCallRoute), hasLength(1));
    });

    test('duplicate failure event ID is ignored', () {
      final accepted = _withSnapshot(CallLifecycle.accepted);
      const failure = RouteOpenFailed(
        callId: 'call_a',
        eventId: 'route-failed-1',
      );

      final first = reducer.reduce(accepted.state, failure);
      final duplicate = reducer.reduce(first.state, failure);

      expect(first.effects.single.type, CallEffectType.recordDiagnosticEvent);
      expect(duplicate.effects, isEmpty);
    });

    test('duplicate retry event ID is ignored', () {
      final failed = reducer.reduce(
        _withSnapshot(CallLifecycle.accepted).state,
        const RouteOpenFailed(callId: 'call_a', eventId: 'route-failed-1'),
      );
      const retry = RetryOpenCallRouteRequested(
        callId: 'call_a',
        eventId: 'route-retry-1',
      );

      final first = reducer.reduce(failed.state, retry);
      final duplicate = reducer.reduce(first.state, retry);

      expect(first.effects.where(_isOpenCallRoute), hasLength(1));
      expect(duplicate.effects, isEmpty);
    });

    test('repeated navigation failures cannot produce an automatic effect loop',
        () {
      final accepted = _withSnapshot(CallLifecycle.accepted);
      final firstFailure = reducer.reduce(
        accepted.state,
        const RouteOpenFailed(callId: 'call_a', eventId: 'route-failed-1'),
      );
      final secondFailure = reducer.reduce(
        firstFailure.state,
        const RouteOpenFailed(callId: 'call_a', eventId: 'route-failed-2'),
      );

      expect(firstFailure.effects.where(_isOpenCallRoute), isEmpty);
      expect(secondFailure.effects.where(_isOpenCallRoute), isEmpty);
      expect(secondFailure.state.callRouteState, CallRouteState.failed);
    });
  });

  group('terminal cleanup and native acknowledgements', () {
    test('terminal snapshot requests cleanup resources only', () {
      final terminal = reducer.reduce(
        _withSnapshot(CallLifecycle.ringing).state,
        _snapshotEvent(version: 2, lifecycle: CallLifecycle.completed),
      );

      expect(terminal.state.cleanupStatus, CleanupStatus.requested);
      expect(terminal.effects.where(_isCleanupEffect), hasLength(3));
      expect(
        terminal.effects.map((effect) => effect.type),
        containsAll(<CallEffectType>[
          CallEffectType.closeCallRoute,
          CallEffectType.leaveAgora,
          CallEffectType.endMatchingNativeCall,
        ]),
      );
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
      expect(
        nextCall.effects,
        contains(const CallEffect.presentIncomingRoute('call_b')),
      );
    });

    test('terminal snapshot requests native ending but does not mark it ended',
        () {
      final terminal = reducer.reduce(
        _withSnapshot(CallLifecycle.ringing).state,
        _snapshotEvent(version: 2, lifecycle: CallLifecycle.completed),
      );

      expect(
        terminal.state.nativePresentationState,
        NativePresentationState.endingRequested,
      );
      expect(
        terminal.effects,
        contains(const CallEffect.endMatchingNativeCall('call_a')),
      );
    });

    test('matching native-ended acknowledgment marks it ended', () {
      final terminal = reducer.reduce(
        _withSnapshot(CallLifecycle.ringing).state,
        _snapshotEvent(version: 2, lifecycle: CallLifecycle.completed),
      );
      final ended = reducer.reduce(
        terminal.state,
        const NativeCallEnded(callId: 'call_a', eventId: 'native-ended-1'),
      );

      expect(
        ended.state.nativePresentationState,
        NativePresentationState.endedNatively,
      );
    });

    test('native-ended acknowledgment before ending requested is ignored', () {
      final ringing = _withSnapshot(CallLifecycle.ringing);
      final ignored = reducer.reduce(
        ringing.state,
        const NativeCallEnded(callId: 'call_a', eventId: 'native-ended-early'),
      );

      expect(
        ignored.state.nativePresentationState,
        NativePresentationState.notPresented,
      );
      expect(ignored.effects, isEmpty);
    });

    test('unrelated native-ended acknowledgment is ignored', () {
      final terminal = reducer.reduce(
        _withSnapshot(CallLifecycle.ringing).state,
        _snapshotEvent(version: 2, lifecycle: CallLifecycle.completed),
      );
      final unrelated = reducer.reduce(
        terminal.state,
        const NativeCallEnded(callId: 'call_b', eventId: 'native-ended-other'),
      );

      expect(
        unrelated.state.nativePresentationState,
        NativePresentationState.endingRequested,
      );
      expect(unrelated.effects, isEmpty);
    });

    test('duplicate native-ended acknowledgment is harmless', () {
      final terminal = reducer.reduce(
        _withSnapshot(CallLifecycle.ringing).state,
        _snapshotEvent(version: 2, lifecycle: CallLifecycle.completed),
      );
      const event = NativeCallEnded(
        callId: 'call_a',
        eventId: 'native-ended-1',
      );

      final first = reducer.reduce(terminal.state, event);
      final duplicate = reducer.reduce(first.state, event);

      expect(
        first.state.nativePresentationState,
        NativePresentationState.endedNatively,
      );
      expect(duplicate.effects, isEmpty);
    });
  });
}

CallReduction _withSnapshot(
  CallLifecycle lifecycle, {
  int version = 1,
  ParticipantMediaState callerMediaState = ParticipantMediaState.notJoined,
  ParticipantMediaState calleeMediaState = ParticipantMediaState.notJoined,
  int callerMediaVersion = 0,
  int calleeMediaVersion = 0,
}) {
  const reducer = CallStateReducer();
  return reducer.reduce(
    CallSessionState.initial(),
    _snapshotEvent(
      version: version,
      lifecycle: lifecycle,
      callerMediaState: callerMediaState,
      calleeMediaState: calleeMediaState,
      callerMediaVersion: callerMediaVersion,
      calleeMediaVersion: calleeMediaVersion,
    ),
  );
}

CallSnapshotReceived _snapshotEvent({
  String callId = 'call_a',
  int version = 1,
  CallLifecycle lifecycle = CallLifecycle.ringing,
  CallParticipantRole localParticipantRole = CallParticipantRole.callee,
  ParticipantMediaState callerMediaState = ParticipantMediaState.notJoined,
  ParticipantMediaState calleeMediaState = ParticipantMediaState.notJoined,
  int callerMediaVersion = 0,
  int calleeMediaVersion = 0,
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
      callerMediaVersion: callerMediaVersion,
      calleeMediaVersion: calleeMediaVersion,
    ),
    localParticipantRole: localParticipantRole,
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
      effect.type == CallEffectType.endMatchingNativeCall;
}
