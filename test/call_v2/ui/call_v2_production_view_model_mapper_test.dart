import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_presentation_snapshot.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_user_action.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_view_model_mapper.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_view_model_result.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_view_state.dart';
import 'package:connect_app/call_v2/ui/call_v2_ui_session_reference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = CallV2ProductionViewModelMapper();

  test('none and terminal disposed snapshots produce no view', () {
    expect(
      mapper.map(CallV2ProductionPresentationSnapshot.none(generation: 1)),
      isA<CallV2ProductionViewModelNoView>(),
    );
    expect(
      mapper.map(
        CallV2ProductionPresentationSnapshot.none(
          generation: 2,
          terminalStatus:
              CallV2ProductionPresentationTerminalStatus.terminalDisposed,
        ),
      ),
      isA<CallV2ProductionViewModelNoView>(),
    );
  });

  test('connecting snapshot maps to connecting view model', () {
    final result = mapper.map(_connectingSnapshot());

    final model = _successValue<CallV2ConnectingProductionViewModel>(result);
    expect(model.value.mediaMode, CallV2ProductionMediaMode.audio);
    expect(model.value.cancelEnabled, isTrue);
    expect(model.value.connecting, isTrue);
    expect(model.value.allowedActions, <CallV2ProductionUserAction>{
      CallV2ProductionUserAction.cancelConnecting,
    });
  });

  test('active audio snapshot maps to audio view model', () {
    final result = mapper.map(_audioSnapshot());

    final model = _successValue<CallV2ActiveAudioProductionViewModel>(result);
    expect(model.value.muted, isFalse);
    expect(model.value.speakerEnabled, isTrue);
    expect(model.value.elapsedSeconds, 42);
    expect(model.value.allowedActions, <CallV2ProductionUserAction>{
      CallV2ProductionUserAction.toggleMute,
      CallV2ProductionUserAction.toggleSpeaker,
      CallV2ProductionUserAction.leave,
    });
  });

  test('active video snapshot maps to video view model', () {
    final result = mapper.map(_videoSnapshot());

    final model = _successValue<CallV2ActiveVideoProductionViewModel>(result);
    expect(model.value.microphoneMuted, isTrue);
    expect(model.value.localCameraEnabled, isFalse);
    expect(model.value.remoteVideoAvailable, isTrue);
    expect(model.value.cameraSwitchEnabled, isTrue);
    expect(model.value.allowedActions, <CallV2ProductionUserAction>{
      CallV2ProductionUserAction.toggleMute,
      CallV2ProductionUserAction.toggleCamera,
      CallV2ProductionUserAction.switchCamera,
      CallV2ProductionUserAction.leave,
    });
  });

  test('controlled failure snapshot maps to failure view model', () {
    final result = mapper.map(_failureSnapshot());

    final model =
        _successValue<CallV2ControlledFailureProductionViewModel>(result);
    expect(model.value.errorCode, CallV2ClientErrorCode.rejected);
    expect(model.value.retryEnabled, isTrue);
    expect(model.value.dismissEnabled, isFalse);
    expect(model.value.allowedActions, <CallV2ProductionUserAction>{
      CallV2ProductionUserAction.retryControlledFailure,
    });
  });

  test('stale generation is rejected', () {
    final result =
        mapper.map(_audioSnapshot(generation: 3), minimumGeneration: 4);

    expect(result, isA<CallV2ProductionViewModelRejected>());
    expect(
      (result as CallV2ProductionViewModelRejected).error,
      CallV2ProductionViewModelError.staleGeneration,
    );
  });

  test('negative minimum generation is rejected', () {
    final result = mapper.map(_audioSnapshot(), minimumGeneration: -1);

    expect(result, isA<CallV2ProductionViewModelRejected>());
    expect(
      (result as CallV2ProductionViewModelRejected).error,
      CallV2ProductionViewModelError.invalidInput,
    );
  });

  test('mapper does not mutate source snapshot', () {
    final snapshot = _videoSnapshot();
    final before = snapshot.toString();

    expect(mapper.map(snapshot), isA<CallV2ProductionViewModelSuccess>());
    expect(snapshot.toString(), before);
  });

  test('rejection debug output contains no sensitive data', () {
    final result = mapper.map(_audioSnapshot(), minimumGeneration: 99);
    final debug = result.toString();

    for (final forbidden in <String>[
      'uid',
      'callId',
      'participant',
      'token',
      'channel',
      'credential',
      'Exception',
      'StackTrace',
      '/call-v2',
    ]) {
      expect(debug, isNot(contains(forbidden)));
    }
  });
}

T _successValue<T extends CallV2ProductionViewModel>(
  CallV2ProductionViewModelResult<CallV2ProductionViewModel> result,
) {
  expect(result, isA<CallV2ProductionViewModelSuccess>());
  return (result as CallV2ProductionViewModelSuccess<CallV2ProductionViewModel>)
      .value as T;
}

CallV2ProductionPresentationSnapshot _connectingSnapshot({
  int generation = 1,
}) {
  return CallV2ProductionPresentationSnapshot.connecting(
    sessionReference: _session(generation: generation),
    screenState: const CallV2ProductionConnectingScreenState(
      mediaMode: CallV2ProductionMediaMode.audio,
      cancelAvailable: true,
      connectionPhase: CallV2ProductionConnectionPhase.connecting,
    ),
  );
}

CallV2ProductionPresentationSnapshot _audioSnapshot({
  int generation = 1,
}) {
  return CallV2ProductionPresentationSnapshot.activeAudio(
    sessionReference: _session(generation: generation),
    screenState: const CallV2ProductionActiveAudioScreenState(
      muted: false,
      speakerEnabled: true,
      leaveEnabled: true,
      connectionPhase: CallV2ProductionConnectionPhase.connected,
      elapsedSeconds: 42,
      reconnecting: false,
    ),
  );
}

CallV2ProductionPresentationSnapshot _videoSnapshot({
  int generation = 1,
}) {
  return CallV2ProductionPresentationSnapshot.activeVideo(
    sessionReference: _session(
      generation: generation,
      mediaMode: CallV2ProductionMediaMode.video,
    ),
    screenState: const CallV2ProductionActiveVideoScreenState(
      microphoneMuted: true,
      localCameraEnabled: false,
      remoteVideoAvailable: true,
      cameraSwitchAvailable: true,
      leaveEnabled: true,
      connectionPhase: CallV2ProductionConnectionPhase.reconnecting,
      renderingState: CallV2ProductionVideoRenderingState.rendering,
      reconnecting: true,
    ),
  );
}

CallV2ProductionPresentationSnapshot _failureSnapshot({
  int generation = 1,
}) {
  return CallV2ProductionPresentationSnapshot.controlledFailure(
    generation: generation,
    sessionReference: null,
    screenState: const CallV2ProductionControlledFailureScreenState(
      errorCode: CallV2ClientErrorCode.rejected,
      retryPolicy: CallV2ProductionFailureRetryPolicy.retryAllowed,
      dismissPolicy: CallV2ProductionFailureDismissPolicy.dismissUnavailable,
    ),
  );
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
