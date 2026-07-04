import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_presentation_snapshot.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_view_state.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_transition_policy.dart';
import 'package:connect_app/call_v2/ui/call_v2_ui_session_reference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = CallV2ProductionTransitionPolicy();

  test('all allowed high-level transitions are accepted', () {
    final none = CallV2ProductionPresentationSnapshot.none(generation: 1);
    final connecting = _connecting(2);
    final audio = _audio(3);
    final video = _video(3);
    final failure = _failure(4);
    final dismissed = CallV2ProductionPresentationSnapshot.none(generation: 5);

    expect(
      policy.canTransition(
        from: none,
        to: connecting,
        transition: CallV2ProductionPresentationTransition.openConnecting,
      ),
      isTrue,
    );
    expect(
      policy.canTransition(
        from: connecting,
        to: audio,
        transition: CallV2ProductionPresentationTransition.becomeActiveAudio,
      ),
      isTrue,
    );
    expect(
      policy.canTransition(
        from: connecting,
        to: video,
        transition: CallV2ProductionPresentationTransition.becomeActiveVideo,
      ),
      isTrue,
    );
    expect(
      policy.canTransition(
        from: connecting,
        to: failure,
        transition: CallV2ProductionPresentationTransition.failControlled,
      ),
      isTrue,
    );
    expect(
      policy.canTransition(
        from: connecting,
        to: dismissed,
        transition: CallV2ProductionPresentationTransition.cancel,
      ),
      isTrue,
    );
    expect(
      policy.canTransition(
        from: audio,
        to: failure,
        transition: CallV2ProductionPresentationTransition.failControlled,
      ),
      isTrue,
    );
    expect(
      policy.canTransition(
        from: video,
        to: dismissed,
        transition: CallV2ProductionPresentationTransition.leaveOrEnd,
      ),
      isTrue,
    );
    expect(
      policy.canTransition(
        from: failure,
        to: _connecting(5),
        transition: CallV2ProductionPresentationTransition.retry,
      ),
      isTrue,
    );
    expect(
      policy.canTransition(
        from: failure,
        to: dismissed,
        transition: CallV2ProductionPresentationTransition.dismiss,
      ),
      isTrue,
    );
  });

  test('audio and video direct transitions are forbidden', () {
    expect(
      policy.canTransition(
        from: _audio(2),
        to: _video(3),
        transition: CallV2ProductionPresentationTransition.becomeActiveVideo,
      ),
      isFalse,
    );
    expect(
      policy.canTransition(
        from: _video(2),
        to: _audio(3),
        transition: CallV2ProductionPresentationTransition.becomeActiveAudio,
      ),
      isFalse,
    );
  });

  test('stale generation and post-terminal transitions are rejected', () {
    expect(
      policy.canTransition(
        from: _connecting(5),
        to: _audio(4),
        transition: CallV2ProductionPresentationTransition.becomeActiveAudio,
      ),
      isFalse,
    );

    final terminal = CallV2ProductionPresentationSnapshot.none(
      generation: 5,
      terminalStatus:
          CallV2ProductionPresentationTerminalStatus.terminalDisposed,
    );
    expect(
      policy.canTransition(
        from: terminal,
        to: _connecting(6),
        transition: CallV2ProductionPresentationTransition.openConnecting,
      ),
      isFalse,
    );
  });

  test('retry and dismiss require typed failure permissions', () {
    final noRetry = _failure(
      2,
      retryPolicy: CallV2ProductionFailureRetryPolicy.retryUnavailable,
      dismissPolicy: CallV2ProductionFailureDismissPolicy.dismissUnavailable,
    );
    expect(
      policy.canTransition(
        from: noRetry,
        to: _connecting(3),
        transition: CallV2ProductionPresentationTransition.retry,
      ),
      isFalse,
    );
    expect(
      policy.canTransition(
        from: noRetry,
        to: CallV2ProductionPresentationSnapshot.none(generation: 3),
        transition: CallV2ProductionPresentationTransition.dismiss,
      ),
      isFalse,
    );
  });

  test('transition policy has no side effects', () {
    final from = _connecting(1);
    final to = _audio(2);
    final before = from.toString();

    final first = policy.canTransition(
      from: from,
      to: to,
      transition: CallV2ProductionPresentationTransition.becomeActiveAudio,
    );
    final second = policy.canTransition(
      from: from,
      to: to,
      transition: CallV2ProductionPresentationTransition.becomeActiveAudio,
    );

    expect(first, isTrue);
    expect(second, isTrue);
    expect(from.toString(), before);
  });
}

CallV2ProductionPresentationSnapshot _connecting(int generation) {
  return CallV2ProductionPresentationSnapshot.connecting(
    sessionReference: _session(generation),
    screenState: const CallV2ProductionConnectingScreenState(
      mediaMode: CallV2ProductionMediaMode.audio,
      cancelAvailable: true,
      connectionPhase: CallV2ProductionConnectionPhase.connecting,
    ),
  );
}

CallV2ProductionPresentationSnapshot _audio(int generation) {
  return CallV2ProductionPresentationSnapshot.activeAudio(
    sessionReference: _session(generation),
    screenState: const CallV2ProductionActiveAudioScreenState(
      muted: false,
      speakerEnabled: true,
      leaveEnabled: true,
      connectionPhase: CallV2ProductionConnectionPhase.connected,
      elapsedSeconds: 1,
      reconnecting: false,
    ),
  );
}

CallV2ProductionPresentationSnapshot _video(int generation) {
  return CallV2ProductionPresentationSnapshot.activeVideo(
    sessionReference: _session(
      generation,
      mediaMode: CallV2ProductionMediaMode.video,
    ),
    screenState: const CallV2ProductionActiveVideoScreenState(
      microphoneMuted: false,
      localCameraEnabled: true,
      remoteVideoAvailable: true,
      cameraSwitchAvailable: true,
      leaveEnabled: true,
      connectionPhase: CallV2ProductionConnectionPhase.connected,
      renderingState: CallV2ProductionVideoRenderingState.rendering,
      reconnecting: false,
    ),
  );
}

CallV2ProductionPresentationSnapshot _failure(
  int generation, {
  CallV2ProductionFailureRetryPolicy retryPolicy =
      CallV2ProductionFailureRetryPolicy.retryAllowed,
  CallV2ProductionFailureDismissPolicy dismissPolicy =
      CallV2ProductionFailureDismissPolicy.dismissAllowed,
}) {
  return CallV2ProductionPresentationSnapshot.controlledFailure(
    sessionReference: _session(generation),
    screenState: CallV2ProductionControlledFailureScreenState(
      errorCode: CallV2ClientErrorCode.rejected,
      retryPolicy: retryPolicy,
      dismissPolicy: dismissPolicy,
    ),
  );
}

CallV2UiSessionReference _session(
  int generation, {
  CallV2ProductionMediaMode mediaMode = CallV2ProductionMediaMode.audio,
}) {
  return CallV2UiSessionReference(
    generation: generation,
    mediaMode: mediaMode,
    localLifecycleStatus: CallV2ProductionLocalLifecycleStatus.active,
    connectionPhase: CallV2ProductionConnectionPhase.connected,
  );
}
