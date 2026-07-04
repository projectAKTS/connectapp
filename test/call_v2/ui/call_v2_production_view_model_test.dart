import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/ui/call_v2_active_audio_view_model.dart';
import 'package:connect_app/call_v2/ui/call_v2_active_video_view_model.dart';
import 'package:connect_app/call_v2/ui/call_v2_connecting_view_model.dart';
import 'package:connect_app/call_v2/ui/call_v2_controlled_failure_view_model.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_user_action.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_view_state.dart';
import 'package:connect_app/call_v2/ui/call_v2_ui_session_reference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('view models are immutable and copy action sets', () {
    final actions = <CallV2ProductionUserAction>{
      CallV2ProductionUserAction.toggleMute,
      CallV2ProductionUserAction.toggleSpeaker,
      CallV2ProductionUserAction.leave,
    };
    final model = CallV2ActiveAudioViewModel(
      muted: false,
      speakerEnabled: true,
      leaveEnabled: true,
      connectionPhase: CallV2ProductionConnectionPhase.connected,
      elapsedSeconds: 12,
      reconnecting: false,
      allowedActions: actions,
    );

    actions.clear();

    expect(model.allowedActions, hasLength(3));
    expect(
      () => model.allowedActions.add(CallV2ProductionUserAction.toggleCamera),
      throwsUnsupportedError,
    );
  });

  test('connecting audio video and failure expose sanitized data only', () {
    final models = <Object>[
      CallV2ConnectingViewModel(
        mediaMode: CallV2ProductionMediaMode.audio,
        connectionPhase: CallV2ProductionConnectionPhase.connecting,
        cancelEnabled: true,
        allowedActions: const <CallV2ProductionUserAction>{
          CallV2ProductionUserAction.cancelConnecting,
        },
      ),
      CallV2ActiveAudioViewModel(
        muted: true,
        speakerEnabled: false,
        leaveEnabled: true,
        connectionPhase: CallV2ProductionConnectionPhase.connected,
        elapsedSeconds: 30,
        reconnecting: false,
        allowedActions: const <CallV2ProductionUserAction>{
          CallV2ProductionUserAction.toggleMute,
          CallV2ProductionUserAction.toggleSpeaker,
          CallV2ProductionUserAction.leave,
        },
      ),
      CallV2ActiveVideoViewModel(
        microphoneMuted: false,
        localCameraEnabled: true,
        remoteVideoAvailable: true,
        cameraSwitchEnabled: true,
        leaveEnabled: true,
        connectionPhase: CallV2ProductionConnectionPhase.reconnecting,
        renderingState: CallV2ProductionVideoRenderingState.rendering,
        reconnecting: true,
        allowedActions: const <CallV2ProductionUserAction>{
          CallV2ProductionUserAction.toggleMute,
          CallV2ProductionUserAction.toggleCamera,
          CallV2ProductionUserAction.switchCamera,
          CallV2ProductionUserAction.leave,
        },
      ),
      CallV2ControlledFailureViewModel(
        errorCode: CallV2ClientErrorCode.rejected,
        retryEnabled: true,
        dismissEnabled: false,
        allowedActions: const <CallV2ProductionUserAction>{
          CallV2ProductionUserAction.retryControlledFailure,
        },
      ),
    ];

    for (final model in models) {
      final debug = model.toString();
      for (final forbidden in _sensitiveWords) {
        expect(debug, isNot(contains(forbidden)), reason: '$model');
      }
      expect(debug, isNot(contains('/call-v2')));
    }
  });

  test('audio view model rejects negative elapsed seconds', () {
    expect(
      () => CallV2ActiveAudioViewModel(
        muted: false,
        speakerEnabled: false,
        leaveEnabled: true,
        connectionPhase: CallV2ProductionConnectionPhase.connected,
        elapsedSeconds: -1,
        reconnecting: false,
        allowedActions: const <CallV2ProductionUserAction>{},
      ),
      throwsArgumentError,
    );
  });

  test('view model sources contain no Flutter or external services', () {
    final source = _viewModelSources();

    for (final forbidden in <String>[
      'package:flutter',
      'Widget',
      'BuildContext',
      'Navigator',
      'Route<',
      'Firebase',
      'Firestore',
      'Agora',
      'RtcEngine',
      'CallKit',
      'Permission',
      'connect_functions',
      'Future<',
      'async',
      'StreamController',
      'Timer',
      'VoidCallback',
      'Function ',
    ]) {
      expect(source, isNot(contains(forbidden)));
    }
  });
}

String _viewModelSources() {
  return <String>[
    'lib/call_v2/ui/call_v2_connecting_view_model.dart',
    'lib/call_v2/ui/call_v2_active_audio_view_model.dart',
    'lib/call_v2/ui/call_v2_active_video_view_model.dart',
    'lib/call_v2/ui/call_v2_controlled_failure_view_model.dart',
    'lib/call_v2/ui/call_v2_production_view_model_result.dart',
    'lib/call_v2/ui/call_v2_production_view_model_mapper.dart',
  ].map((path) => File(path).readAsStringSync()).join('\n');
}

const _sensitiveWords = <String>[
  'uid',
  'callId',
  'participant',
  'token',
  'channel',
  'credential',
  'Exception',
  'StackTrace',
  'Firebase',
  'provider',
];
