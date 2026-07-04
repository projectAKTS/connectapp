import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_mapping_result.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_presentation_mapper.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_presentation_snapshot.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_destination.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_user_action.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_view_state.dart';
import 'package:connect_app/call_v2/ui/call_v2_ui_session_reference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = CallV2ProductionPresentationMapper();

  test('preparing and connecting map to connecting snapshots', () {
    for (final state in <CallV2ProductionPresentationInputState>[
      CallV2ProductionPresentationInputState.preparing,
      CallV2ProductionPresentationInputState.connecting,
    ]) {
      final snapshot = _success(mapper.map(_input(state: state)));
      expect(snapshot.destination, CallV2ProductionRouteDestination.connecting);
    }
  });

  test('ready audio and ready video map to active destinations', () {
    expect(
      _success(mapper.map(_input(
        state: CallV2ProductionPresentationInputState.ready,
      ))).destination,
      CallV2ProductionRouteDestination.activeAudio,
    );
    expect(
      _success(mapper.map(_input(
        state: CallV2ProductionPresentationInputState.ready,
        mediaMode: CallV2ProductionMediaMode.video,
        cameraAvailable: true,
        cameraEnabled: true,
        renderingState: CallV2ProductionVideoRenderingState.rendering,
      ))).destination,
      CallV2ProductionRouteDestination.activeVideo,
    );
  });

  test('reconnecting preserves audio or video destination', () {
    final audio = _success(mapper.map(_input(
      state: CallV2ProductionPresentationInputState.reconnecting,
      connectionPhase: CallV2ProductionConnectionPhase.reconnecting,
    )));
    final video = _success(mapper.map(_input(
      state: CallV2ProductionPresentationInputState.reconnecting,
      mediaMode: CallV2ProductionMediaMode.video,
      cameraAvailable: true,
      cameraEnabled: true,
      connectionPhase: CallV2ProductionConnectionPhase.reconnecting,
      renderingState: CallV2ProductionVideoRenderingState.interrupted,
    )));

    expect(audio.destination, CallV2ProductionRouteDestination.activeAudio);
    expect(video.destination, CallV2ProductionRouteDestination.activeVideo);
    expect(
        (audio.screenState as CallV2ProductionActiveAudioScreenState)
            .reconnecting,
        isTrue);
    expect(
        (video.screenState as CallV2ProductionActiveVideoScreenState)
            .reconnecting,
        isTrue);
  });

  test('controlled failure maps to failure snapshot and respects retry policy',
      () {
    final snapshot = _success(mapper.map(_input(
      state: CallV2ProductionPresentationInputState.controlledFailure,
      errorCode: CallV2ClientErrorCode.rejected,
      retryPolicy: CallV2ProductionFailureRetryPolicy.retryAllowed,
      dismissPolicy: CallV2ProductionFailureDismissPolicy.dismissAllowed,
      retryActionRequested: true,
    )));

    expect(
      snapshot.destination,
      CallV2ProductionRouteDestination.controlledFailure,
    );
    expect(
      snapshot.allowedActions,
      contains(CallV2ProductionUserAction.retryControlledFailure),
    );
  });

  test('ended idle and unavailable map to no route', () {
    for (final state in <CallV2ProductionPresentationInputState>[
      CallV2ProductionPresentationInputState.ended,
      CallV2ProductionPresentationInputState.idle,
      CallV2ProductionPresentationInputState.unavailable,
    ]) {
      final result = mapper.map(CallV2ProductionPresentationInput(
        generation: 5,
        state: state,
      ));
      expect(result, isA<CallV2ProductionMappingNoRoute>());
      final snapshot = (result as CallV2ProductionMappingNoRoute<
              CallV2ProductionPresentationSnapshot>)
          .value;
      expect(snapshot?.destination, isNull);
      expect(snapshot?.isTerminal, isFalse);
    }
  });

  test('disposed maps to terminal no-route snapshot', () {
    final result = mapper.map(const CallV2ProductionPresentationInput(
      generation: 6,
      state: CallV2ProductionPresentationInputState.disposed,
    ));

    expect(result, isA<CallV2ProductionMappingNoRoute>());
    final snapshot = (result as CallV2ProductionMappingNoRoute<
            CallV2ProductionPresentationSnapshot>)
        .value;
    expect(snapshot?.isTerminal, isTrue);
  });

  test('invalid inputs are controlled rejections', () {
    final cases = <CallV2ProductionPresentationInput>[
      _input(generation: -1),
      _input(elapsedSeconds: -1),
      _input(
        mediaMode: CallV2ProductionMediaMode.audio,
        renderingState: CallV2ProductionVideoRenderingState.rendering,
      ),
      _input(
        state: CallV2ProductionPresentationInputState.ready,
        mediaMode: null,
      ),
      _input(
        state: CallV2ProductionPresentationInputState.ready,
        mediaMode: CallV2ProductionMediaMode.video,
        cameraAvailable: false,
      ),
      const CallV2ProductionPresentationInput(
        generation: 1,
        state: CallV2ProductionPresentationInputState.controlledFailure,
      ),
      _input(
        state: CallV2ProductionPresentationInputState.controlledFailure,
        errorCode: CallV2ClientErrorCode.rejected,
        retryActionRequested: true,
        retryPolicy: CallV2ProductionFailureRetryPolicy.retryUnavailable,
      ),
      const CallV2ProductionPresentationInput(
        generation: 1,
        state: CallV2ProductionPresentationInputState.disposed,
        mediaMode: CallV2ProductionMediaMode.audio,
      ),
    ];

    for (final input in cases) {
      final result = mapper.map(input);
      expect(result, isA<CallV2ProductionMappingRejected>());
      expect(
        (result as CallV2ProductionMappingRejected).error,
        CallV2ProductionMappingError.invalidInput,
      );
    }
  });

  test('stale input generation is rejected', () {
    final result = mapper.map(_input(generation: 3), minimumGeneration: 4);

    expect(result, isA<CallV2ProductionMappingRejected>());
    expect(
      (result as CallV2ProductionMappingRejected).error,
      CallV2ProductionMappingError.staleGeneration,
    );
  });

  test('debug output contains no sensitive data', () {
    final input = _input(
      state: CallV2ProductionPresentationInputState.controlledFailure,
      errorCode: CallV2ClientErrorCode.rejected,
    );
    final result = mapper.map(input);
    final debug = '${input.toString()} ${result.toString()}';

    for (final forbidden in <String>[
      'uid',
      'callId',
      'participant',
      'token',
      'channel',
      'credential',
      'Exception',
      'StackTrace',
    ]) {
      expect(debug, isNot(contains(forbidden)));
    }
  });
}

CallV2ProductionPresentationSnapshot _success(
  CallV2ProductionMappingResult<CallV2ProductionPresentationSnapshot> result,
) {
  expect(result, isA<CallV2ProductionMappingSuccess>());
  return (result as CallV2ProductionMappingSuccess<
          CallV2ProductionPresentationSnapshot>)
      .value;
}

CallV2ProductionPresentationInput _input({
  int generation = 1,
  CallV2ProductionPresentationInputState state =
      CallV2ProductionPresentationInputState.ready,
  CallV2ProductionMediaMode? mediaMode = CallV2ProductionMediaMode.audio,
  CallV2ProductionConnectionPhase connectionPhase =
      CallV2ProductionConnectionPhase.connected,
  bool muted = false,
  bool speakerEnabled = true,
  bool cameraEnabled = false,
  bool cameraAvailable = false,
  bool remoteVideoAvailable = false,
  bool cameraSwitchAvailable = false,
  int elapsedSeconds = 0,
  CallV2ProductionVideoRenderingState renderingState =
      CallV2ProductionVideoRenderingState.unavailable,
  CallV2ClientErrorCode? errorCode,
  CallV2ProductionFailureRetryPolicy retryPolicy =
      CallV2ProductionFailureRetryPolicy.retryUnavailable,
  CallV2ProductionFailureDismissPolicy dismissPolicy =
      CallV2ProductionFailureDismissPolicy.dismissUnavailable,
  bool retryActionRequested = false,
}) {
  return CallV2ProductionPresentationInput(
    generation: generation,
    state: state,
    mediaMode: mediaMode,
    connectionPhase: connectionPhase,
    muted: muted,
    speakerEnabled: speakerEnabled,
    cameraEnabled: cameraEnabled,
    cameraAvailable: cameraAvailable,
    remoteVideoAvailable: remoteVideoAvailable,
    cameraSwitchAvailable: cameraSwitchAvailable,
    elapsedSeconds: elapsedSeconds,
    renderingState: renderingState,
    errorCode: errorCode,
    retryPolicy: retryPolicy,
    dismissPolicy: dismissPolicy,
    retryActionRequested: retryActionRequested,
  );
}
