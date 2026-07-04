import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_destination.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_view_state.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_user_action.dart';
import 'package:connect_app/call_v2/ui/call_v2_ui_session_reference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session reference is immutable, sanitized, and debug safe', () {
    const reference = CallV2UiSessionReference(
      generation: 7,
      mediaMode: CallV2ProductionMediaMode.video,
      localLifecycleStatus: CallV2ProductionLocalLifecycleStatus.active,
      connectionPhase: CallV2ProductionConnectionPhase.connected,
    );

    expect(reference.generation, 7);
    final debug = reference.toString();
    for (final forbidden in _sensitiveWords) {
      expect(debug, isNot(contains(forbidden)));
    }
  });

  test('screen states are typed and expose safe debug data', () {
    const connecting = CallV2ProductionConnectingScreenState(
      mediaMode: CallV2ProductionMediaMode.audio,
      cancelAvailable: true,
      connectionPhase: CallV2ProductionConnectionPhase.connecting,
    );
    const audio = CallV2ProductionActiveAudioScreenState(
      muted: false,
      speakerEnabled: true,
      leaveEnabled: true,
      connectionPhase: CallV2ProductionConnectionPhase.connected,
      elapsedSeconds: 12,
      reconnecting: false,
    );
    const video = CallV2ProductionActiveVideoScreenState(
      microphoneMuted: false,
      localCameraEnabled: true,
      remoteVideoAvailable: true,
      cameraSwitchAvailable: true,
      leaveEnabled: true,
      connectionPhase: CallV2ProductionConnectionPhase.connected,
      renderingState: CallV2ProductionVideoRenderingState.rendering,
      reconnecting: false,
    );
    const failure = CallV2ProductionControlledFailureScreenState(
      errorCode: CallV2ClientErrorCode.rejected,
      retryPolicy: CallV2ProductionFailureRetryPolicy.retryAllowed,
      dismissPolicy: CallV2ProductionFailureDismissPolicy.dismissAllowed,
    );

    expect(connecting.toSafeDebugMap()['screen'], 'connecting');
    expect(audio.toSafeDebugMap()['screen'], 'activeAudio');
    expect(video.toSafeDebugMap()['screen'], 'activeVideo');
    expect(failure.toSafeDebugMap()['errorCode'], 'rejected');
    for (final state in <CallV2ProductionScreenState>[
      connecting,
      audio,
      video,
      failure,
    ]) {
      final debug = state.toString();
      for (final forbidden in _sensitiveWords) {
        expect(debug, isNot(contains(forbidden)));
      }
    }
  });

  test('actions are typed and contain no payload identifiers', () {
    expect(
      CallV2ProductionUserAction.values,
      containsAll(<CallV2ProductionUserAction>[
        CallV2ProductionUserAction.cancelConnecting,
        CallV2ProductionUserAction.toggleMute,
        CallV2ProductionUserAction.toggleSpeaker,
        CallV2ProductionUserAction.toggleCamera,
        CallV2ProductionUserAction.switchCamera,
        CallV2ProductionUserAction.leave,
        CallV2ProductionUserAction.retryControlledFailure,
        CallV2ProductionUserAction.dismissControlledFailure,
      ]),
    );
    for (final action in CallV2ProductionUserAction.values) {
      expect(action.name, isNot(contains('uid')));
      expect(action.name, isNot(contains('callId')));
      expect(action.name, isNot(contains('token')));
      expect(action.name, isNot(contains('channel')));
    }
  });

  test('capability rules match destination-specific policies', () {
    const connecting = CallV2ProductionConnectingScreenState(
      mediaMode: CallV2ProductionMediaMode.audio,
      cancelAvailable: true,
      connectionPhase: CallV2ProductionConnectionPhase.connecting,
    );
    expect(
      callV2ProductionActionsFor(
        destination: CallV2ProductionRouteDestination.connecting,
        state: connecting,
      ),
      <CallV2ProductionUserAction>{CallV2ProductionUserAction.cancelConnecting},
    );

    const audio = CallV2ProductionActiveAudioScreenState(
      muted: false,
      speakerEnabled: false,
      leaveEnabled: true,
      connectionPhase: CallV2ProductionConnectionPhase.connected,
      elapsedSeconds: 0,
      reconnecting: false,
    );
    expect(
      callV2ProductionActionsFor(
        destination: CallV2ProductionRouteDestination.activeAudio,
        state: audio,
      ),
      <CallV2ProductionUserAction>{
        CallV2ProductionUserAction.toggleMute,
        CallV2ProductionUserAction.toggleSpeaker,
        CallV2ProductionUserAction.leave,
      },
    );

    const video = CallV2ProductionActiveVideoScreenState(
      microphoneMuted: false,
      localCameraEnabled: true,
      remoteVideoAvailable: true,
      cameraSwitchAvailable: false,
      leaveEnabled: true,
      connectionPhase: CallV2ProductionConnectionPhase.connected,
      renderingState: CallV2ProductionVideoRenderingState.rendering,
      reconnecting: false,
    );
    expect(
      callV2ProductionActionsFor(
        destination: CallV2ProductionRouteDestination.activeVideo,
        state: video,
      ),
      isNot(contains(CallV2ProductionUserAction.switchCamera)),
    );

    const failure = CallV2ProductionControlledFailureScreenState(
      errorCode: CallV2ClientErrorCode.rejected,
      retryPolicy: CallV2ProductionFailureRetryPolicy.retryAllowed,
      dismissPolicy: CallV2ProductionFailureDismissPolicy.dismissUnavailable,
    );
    expect(
      callV2ProductionActionsFor(
        destination: CallV2ProductionRouteDestination.controlledFailure,
        state: failure,
      ),
      <CallV2ProductionUserAction>{
        CallV2ProductionUserAction.retryControlledFailure,
      },
    );
    expect(
      callV2ProductionActionsFor(
        destination: CallV2ProductionRouteDestination.incomingReviewReserved,
        state: null,
      ),
      isEmpty,
    );
  });

  test('contract sources contain no callbacks or external service instances',
      () {
    final sources = <String>[
      'lib/call_v2/ui/call_v2_ui_session_reference.dart',
      'lib/call_v2/ui/call_v2_production_view_state.dart',
      'lib/call_v2/ui/call_v2_production_user_action.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    for (final forbidden in <String>[
      'Function ',
      'VoidCallback',
      'callback',
      'Firebase',
      'Agora',
      'RtcEngine',
      'Navigator',
      'BuildContext',
      'Widget',
      'Route<',
      'Timer',
      'StreamController',
    ]) {
      expect(sources, isNot(contains(forbidden)));
    }
  });
}

const _sensitiveWords = <String>[
  'uid',
  'callId',
  'participant',
  'token',
  'channel',
  'credential',
  'path',
  'Exception',
  'StackTrace',
];
