import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_presentation_snapshot.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_user_action.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_view_model_mapper.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_view_state.dart';
import 'package:connect_app/call_v2/ui/call_v2_ui_session_reference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('connecting allows cancel only', () {
    final snapshot = CallV2ProductionPresentationSnapshot.connecting(
      sessionReference: _session(),
      screenState: const CallV2ProductionConnectingScreenState(
        mediaMode: CallV2ProductionMediaMode.audio,
        cancelAvailable: true,
        connectionPhase: CallV2ProductionConnectionPhase.connecting,
      ),
    );

    expect(snapshot.allowedActions, <CallV2ProductionUserAction>{
      CallV2ProductionUserAction.cancelConnecting,
    });
  });

  test('audio allows mute speaker and leave only', () {
    final snapshot = CallV2ProductionPresentationSnapshot.activeAudio(
      sessionReference: _session(),
      screenState: const CallV2ProductionActiveAudioScreenState(
        muted: false,
        speakerEnabled: false,
        leaveEnabled: true,
        connectionPhase: CallV2ProductionConnectionPhase.connected,
        elapsedSeconds: 0,
        reconnecting: false,
      ),
    );

    expect(snapshot.allowedActions, <CallV2ProductionUserAction>{
      CallV2ProductionUserAction.toggleMute,
      CallV2ProductionUserAction.toggleSpeaker,
      CallV2ProductionUserAction.leave,
    });
    expect(
      snapshot.allowedActions,
      isNot(contains(CallV2ProductionUserAction.toggleCamera)),
    );
  });

  test('video allows mute camera switch and leave only', () {
    final snapshot = CallV2ProductionPresentationSnapshot.activeVideo(
      sessionReference: _session(mediaMode: CallV2ProductionMediaMode.video),
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

    expect(snapshot.allowedActions, <CallV2ProductionUserAction>{
      CallV2ProductionUserAction.toggleMute,
      CallV2ProductionUserAction.toggleCamera,
      CallV2ProductionUserAction.switchCamera,
      CallV2ProductionUserAction.leave,
    });
    expect(
      snapshot.allowedActions,
      isNot(contains(CallV2ProductionUserAction.toggleSpeaker)),
    );
  });

  test('failure retry and dismiss follow policies', () {
    final retryOnly = CallV2ProductionPresentationSnapshot.controlledFailure(
      sessionReference: null,
      generation: 1,
      screenState: const CallV2ProductionControlledFailureScreenState(
        errorCode: CallV2ClientErrorCode.rejected,
        retryPolicy: CallV2ProductionFailureRetryPolicy.retryAllowed,
        dismissPolicy: CallV2ProductionFailureDismissPolicy.dismissUnavailable,
      ),
    );
    final dismissOnly = CallV2ProductionPresentationSnapshot.controlledFailure(
      sessionReference: null,
      generation: 2,
      screenState: const CallV2ProductionControlledFailureScreenState(
        errorCode: CallV2ClientErrorCode.unavailable,
        retryPolicy: CallV2ProductionFailureRetryPolicy.retryUnavailable,
        dismissPolicy: CallV2ProductionFailureDismissPolicy.dismissAllowed,
      ),
    );

    expect(retryOnly.allowedActions, <CallV2ProductionUserAction>{
      CallV2ProductionUserAction.retryControlledFailure,
    });
    expect(dismissOnly.allowedActions, <CallV2ProductionUserAction>{
      CallV2ProductionUserAction.dismissControlledFailure,
    });
  });

  test('mapper contains explicit invalid action rejection policy', () {
    final source = File(
      'lib/call_v2/ui/call_v2_production_view_model_mapper.dart',
    ).readAsStringSync();

    expect(source, contains('CallV2ProductionViewModelError.invalidActions'));
    expect(source, contains('callV2ProductionActionsFor('));
    expect(source, contains('_setEquals(snapshot.allowedActions, expected)'));
    expect(const CallV2ProductionViewModelMapper(), isNotNull);
  });

  test('action sets are unmodifiable', () {
    final snapshot = CallV2ProductionPresentationSnapshot.activeAudio(
      sessionReference: _session(),
      screenState: const CallV2ProductionActiveAudioScreenState(
        muted: false,
        speakerEnabled: false,
        leaveEnabled: true,
        connectionPhase: CallV2ProductionConnectionPhase.connected,
        elapsedSeconds: 0,
        reconnecting: false,
      ),
    );

    expect(
      () => snapshot.allowedActions.add(
        CallV2ProductionUserAction.toggleCamera,
      ),
      throwsUnsupportedError,
    );
  });
}

CallV2UiSessionReference _session({
  CallV2ProductionMediaMode mediaMode = CallV2ProductionMediaMode.audio,
}) {
  return CallV2UiSessionReference(
    generation: 1,
    mediaMode: mediaMode,
    localLifecycleStatus: CallV2ProductionLocalLifecycleStatus.active,
    connectionPhase: CallV2ProductionConnectionPhase.connected,
  );
}
