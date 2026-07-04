import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_presentation_snapshot.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_destination.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_view_state.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_user_action.dart';
import 'package:connect_app/call_v2/ui/call_v2_ui_session_reference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compatible destination and state combinations are accepted', () {
    final connecting = CallV2ProductionPresentationSnapshot.connecting(
      sessionReference: _session(),
      screenState: _connecting(),
    );
    final audio = CallV2ProductionPresentationSnapshot.activeAudio(
      sessionReference: _session(),
      screenState: _audio(),
    );
    final video = CallV2ProductionPresentationSnapshot.activeVideo(
      sessionReference: _session(mediaMode: CallV2ProductionMediaMode.video),
      screenState: _video(),
    );
    final failure = CallV2ProductionPresentationSnapshot.controlledFailure(
      sessionReference: _session(),
      screenState: _failure(),
    );

    expect(connecting.destination, CallV2ProductionRouteDestination.connecting);
    expect(audio.destination, CallV2ProductionRouteDestination.activeAudio);
    expect(video.destination, CallV2ProductionRouteDestination.activeVideo);
    expect(
      failure.destination,
      CallV2ProductionRouteDestination.controlledFailure,
    );
  });

  test('snapshot derives allowed actions and generation', () {
    final snapshot = CallV2ProductionPresentationSnapshot.activeAudio(
      sessionReference: _session(generation: 9),
      screenState: _audio(),
    );

    expect(snapshot.generation, 9);
    expect(snapshot.terminalStatus,
        CallV2ProductionPresentationTerminalStatus.nonterminal);
    expect(
      snapshot.allowedActions,
      containsAll(<CallV2ProductionUserAction>[
        CallV2ProductionUserAction.toggleMute,
        CallV2ProductionUserAction.toggleSpeaker,
        CallV2ProductionUserAction.leave,
      ]),
    );
  });

  test('none snapshot has no destination, state, session, or actions', () {
    final snapshot = CallV2ProductionPresentationSnapshot.none(generation: 10);

    expect(snapshot.destination, isNull);
    expect(snapshot.sessionReference, isNull);
    expect(snapshot.screenState, isNull);
    expect(snapshot.allowedActions, isEmpty);
    expect(snapshot.isTerminal, isFalse);
  });

  test('terminal none snapshot is explicitly terminal', () {
    final snapshot = CallV2ProductionPresentationSnapshot.none(
      generation: 10,
      terminalStatus:
          CallV2ProductionPresentationTerminalStatus.terminalDisposed,
    );

    expect(snapshot.isTerminal, isTrue);
  });

  test('incoming review cannot create an available snapshot', () {
    expect(
      () => CallV2ProductionPresentationSnapshot.reservedIncomingReview(
        generation: 1,
      ),
      throwsArgumentError,
    );
  });

  test('debug output contains no sensitive data', () {
    final snapshot = CallV2ProductionPresentationSnapshot.controlledFailure(
      sessionReference: _session(),
      screenState: _failure(),
    );
    final debug = snapshot.toString();

    for (final forbidden in <String>[
      'uid',
      'callId',
      'token',
      'channel',
      'credential',
      'raw',
      'StackTrace',
      'Exception',
    ]) {
      expect(debug, isNot(contains(forbidden)));
    }
  });
}

CallV2UiSessionReference _session({
  int generation = 1,
  CallV2ProductionMediaMode mediaMode = CallV2ProductionMediaMode.audio,
}) {
  return CallV2UiSessionReference(
    generation: generation,
    mediaMode: mediaMode,
    localLifecycleStatus: CallV2ProductionLocalLifecycleStatus.active,
    connectionPhase: CallV2ProductionConnectionPhase.connected,
  );
}

CallV2ProductionConnectingScreenState _connecting() {
  return const CallV2ProductionConnectingScreenState(
    mediaMode: CallV2ProductionMediaMode.audio,
    cancelAvailable: true,
    connectionPhase: CallV2ProductionConnectionPhase.connecting,
  );
}

CallV2ProductionActiveAudioScreenState _audio() {
  return const CallV2ProductionActiveAudioScreenState(
    muted: false,
    speakerEnabled: true,
    leaveEnabled: true,
    connectionPhase: CallV2ProductionConnectionPhase.connected,
    elapsedSeconds: 3,
    reconnecting: false,
  );
}

CallV2ProductionActiveVideoScreenState _video() {
  return const CallV2ProductionActiveVideoScreenState(
    microphoneMuted: false,
    localCameraEnabled: true,
    remoteVideoAvailable: true,
    cameraSwitchAvailable: true,
    leaveEnabled: true,
    connectionPhase: CallV2ProductionConnectionPhase.connected,
    renderingState: CallV2ProductionVideoRenderingState.rendering,
    reconnecting: false,
  );
}

CallV2ProductionControlledFailureScreenState _failure() {
  return const CallV2ProductionControlledFailureScreenState(
    errorCode: CallV2ClientErrorCode.rejected,
    retryPolicy: CallV2ProductionFailureRetryPolicy.retryAllowed,
    dismissPolicy: CallV2ProductionFailureDismissPolicy.dismissAllowed,
  );
}
