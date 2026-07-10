import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/ui/call_v2_active_audio_view_model.dart';
import 'package:connect_app/call_v2/ui/call_v2_active_video_view_model.dart';
import 'package:connect_app/call_v2/ui/call_v2_connecting_view_model.dart';
import 'package:connect_app/call_v2/ui/call_v2_controlled_failure_view_model.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_presentation_snapshot.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_descriptor.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_destination.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_user_action.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_view_model_mapper.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_view_state.dart';
import 'package:connect_app/call_v2/ui/call_v2_ui_session_reference.dart';
import 'package:connect_app/call_v2/ui/shells/call_v2_active_audio_shell.dart';
import 'package:connect_app/call_v2/ui/shells/call_v2_active_video_shell.dart';
import 'package:connect_app/call_v2/ui/shells/call_v2_connecting_shell.dart';
import 'package:connect_app/call_v2/ui/shells/call_v2_controlled_failure_shell.dart';
import 'package:connect_app/call_v2/ui/shells/call_v2_production_shell_factory.dart';
import 'package:connect_app/call_v2/ui/shells/call_v2_production_shell_factory_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const factory = CallV2ProductionScreenFactory();

  test('connecting descriptor maps to CallV2ConnectingScreen', () {
    final result = factory.createScreen(
      descriptor: _descriptor(CallV2ProductionRouteDestination.connecting),
      viewModel: CallV2ConnectingProductionViewModel(_connectingModel()),
    );

    final widget = _rendered(result);
    expect(widget, isA<CallV2ConnectingScreen>());
  });

  test('audio descriptor maps to CallV2ActiveAudioScreen', () {
    final result = factory.createScreen(
      descriptor: _descriptor(CallV2ProductionRouteDestination.activeAudio),
      viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
    );

    final widget = _rendered(result);
    expect(widget, isA<CallV2ActiveAudioScreen>());
  });

  test('video descriptor maps to CallV2ActiveVideoScreen', () {
    final result = factory.createScreen(
      descriptor: _descriptor(CallV2ProductionRouteDestination.activeVideo),
      viewModel: CallV2ActiveVideoProductionViewModel(_videoModel()),
    );

    final widget = _rendered(result);
    expect(widget, isA<CallV2ActiveVideoScreen>());
  });

  test('failure descriptor maps to CallV2ControlledFailureScreen', () {
    final result = factory.createScreen(
      descriptor:
          _descriptor(CallV2ProductionRouteDestination.controlledFailure),
      viewModel: CallV2ControlledFailureProductionViewModel(_failureModel()),
    );

    final widget = _rendered(result);
    expect(widget, isA<CallV2ControlledFailureScreen>());
  });

  test('destination view model mismatch is rejected', () {
    final result = factory.createScreen(
      descriptor: _descriptor(CallV2ProductionRouteDestination.activeAudio),
      viewModel: CallV2ConnectingProductionViewModel(_connectingModel()),
    );

    expect(_rejection(result),
        CallV2ProductionScreenFactoryError.destinationViewModelMismatch);
  });

  test('wrong fixed, query, fragment, whitespace, and arbitrary routes reject',
      () {
    final candidates = <String>[
      CallV2ProductionRouteNames.activeVideo,
      '${CallV2ProductionRouteNames.activeAudio}?uid=abc',
      '${CallV2ProductionRouteNames.activeAudio}#token',
      '${CallV2ProductionRouteNames.activeAudio} ',
      '/not-call-v2/audio',
      '/call-v2/ready',
    ];

    for (final candidate in candidates) {
      final result = factory.createScreen(
        descriptor: _FakeDescriptor(
          destination: CallV2ProductionRouteDestination.activeAudio,
          routeName: candidate,
          generation: 4,
        ),
        viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
      );

      expect(_rejection(result),
          CallV2ProductionScreenFactoryError.routeNameMismatch);
      expect(result.toString(), isNot(contains(candidate)));
      expect(result.toSafeDebugMap().values, isNot(contains(candidate)));
    }
  });

  test('reserved destination is rejected before route use', () {
    final result = factory.createScreen(
      descriptor: _FakeDescriptor(
        destination: CallV2ProductionRouteDestination.incomingReviewReserved,
        routeName: '/call-v2/ready',
        generation: 1,
      ),
      viewModel: CallV2ConnectingProductionViewModel(_connectingModel()),
    );

    expect(_rejection(result),
        CallV2ProductionScreenFactoryError.reservedDestination);
    expect(result.toString(), isNot(contains('/call-v2/ready')));
  });

  test('negative descriptor and minimum generation are rejected', () {
    expect(
      _rejection(
        factory.createScreen(
          descriptor: _FakeDescriptor(
            destination: CallV2ProductionRouteDestination.activeAudio,
            routeName: CallV2ProductionRouteNames.activeAudio,
            generation: -1,
          ),
          viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
        ),
      ),
      CallV2ProductionScreenFactoryError.invalidInput,
    );
    expect(
      _rejection(
        factory.createScreen(
          descriptor: _descriptor(CallV2ProductionRouteDestination.activeAudio),
          viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
          minimumGeneration: -1,
        ),
      ),
      CallV2ProductionScreenFactoryError.invalidInput,
    );
  });

  test('stale generation is rejected', () {
    final result = factory.createScreen(
      descriptor: _descriptor(
        CallV2ProductionRouteDestination.activeAudio,
        generation: 3,
      ),
      viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
      minimumGeneration: 4,
    );

    expect(
        _rejection(result), CallV2ProductionScreenFactoryError.staleGeneration);
  });

  test('terminal descriptor produces no screen', () {
    final result = factory.createScreen(
      descriptor: _descriptor(
        CallV2ProductionRouteDestination.activeAudio,
        terminalStatus:
            CallV2ProductionPresentationTerminalStatus.terminalDisposed,
      ),
      viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
    );

    expect(result, isA<CallV2ProductionScreenFactoryNoScreen>());
  });

  testWidgets('optional callback passes typed actions only', (tester) async {
    final actions = <CallV2ProductionUserAction>[];
    final result = factory.createScreen(
      descriptor: _descriptor(CallV2ProductionRouteDestination.activeAudio),
      viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
      onAction: actions.add,
    );

    await tester.pumpWidget(_host(_rendered(result)));
    await tester.tap(find.byKey(const ValueKey<String>(
      'call-v2.action.toggleMute',
    )));

    expect(actions, <CallV2ProductionUserAction>[
      CallV2ProductionUserAction.toggleMute,
    ]);
  });

  testWidgets('null callback disables controls', (tester) async {
    final result = factory.createScreen(
      descriptor: _descriptor(CallV2ProductionRouteDestination.activeAudio),
      viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
    );

    await tester.pumpWidget(_host(_rendered(result)));
    final button = tester.widget<TextButton>(
      find.byKey(const ValueKey<String>('call-v2.action.toggleMute')),
    );

    expect(button.onPressed, isNull);
  });

  test('factory does not mutate descriptor or view model', () {
    final descriptor =
        _descriptor(CallV2ProductionRouteDestination.activeVideo);
    final viewModel = CallV2ActiveVideoProductionViewModel(_videoModel());
    final descriptorBefore = descriptor.toString();
    final viewModelBefore = viewModel.toString();

    final result = factory.createScreen(
      descriptor: descriptor,
      viewModel: viewModel,
    );

    expect(result, isA<CallV2ProductionScreenFactoryRendered>());
    expect(descriptor.toString(), descriptorBefore);
    expect(viewModel.toString(), viewModelBefore);
  });

  test('result debug output is safe', () {
    final result = factory.createScreen(
      descriptor: _FakeDescriptor(
        destination: CallV2ProductionRouteDestination.activeAudio,
        routeName: '${CallV2ProductionRouteNames.activeAudio}?callId=secret',
        generation: 9,
      ),
      viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
    );
    final debug = result.toString();

    for (final forbidden in <String>[
      '/call-v2/audio',
      'callId',
      'uid',
      'participant',
      'token',
      'channel',
      'credential',
      'Exception',
      'StackTrace',
    ]) {
      expect(debug, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}

Widget _host(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: child);
}

Widget _rendered(CallV2ProductionScreenFactoryResult<Widget> result) {
  expect(result, isA<CallV2ProductionScreenFactoryRendered<Widget>>());
  return (result as CallV2ProductionScreenFactoryRendered<Widget>).value;
}

CallV2ProductionScreenFactoryError _rejection(
  CallV2ProductionScreenFactoryResult<Widget> result,
) {
  expect(result, isA<CallV2ProductionScreenFactoryRejected<Widget>>());
  return (result as CallV2ProductionScreenFactoryRejected<Widget>).error;
}

CallV2ProductionRouteDescriptor _descriptor(
  CallV2ProductionRouteDestination destination, {
  int generation = 4,
  CallV2ProductionPresentationTerminalStatus terminalStatus =
      CallV2ProductionPresentationTerminalStatus.nonterminal,
}) {
  return CallV2ProductionRouteDescriptor.forDestination(
    destination: destination,
    sessionReference: _session(generation),
    generation: generation,
    terminalStatus: terminalStatus,
  );
}

CallV2ConnectingViewModel _connectingModel() {
  return CallV2ConnectingViewModel(
    mediaMode: CallV2ProductionMediaMode.audio,
    connectionPhase: CallV2ProductionConnectionPhase.connecting,
    cancelEnabled: true,
    allowedActions: const <CallV2ProductionUserAction>{
      CallV2ProductionUserAction.cancelConnecting,
    },
  );
}

CallV2ActiveAudioViewModel _audioModel() {
  return CallV2ActiveAudioViewModel(
    muted: false,
    speakerEnabled: true,
    leaveEnabled: true,
    connectionPhase: CallV2ProductionConnectionPhase.connected,
    elapsedSeconds: 12,
    reconnecting: false,
    allowedActions: const <CallV2ProductionUserAction>{
      CallV2ProductionUserAction.toggleMute,
      CallV2ProductionUserAction.toggleSpeaker,
      CallV2ProductionUserAction.leave,
    },
  );
}

CallV2ActiveVideoViewModel _videoModel() {
  return CallV2ActiveVideoViewModel(
    microphoneMuted: false,
    localCameraEnabled: true,
    remoteVideoAvailable: false,
    cameraSwitchEnabled: true,
    leaveEnabled: true,
    connectionPhase: CallV2ProductionConnectionPhase.connected,
    renderingState: CallV2ProductionVideoRenderingState.waiting,
    reconnecting: false,
    allowedActions: const <CallV2ProductionUserAction>{
      CallV2ProductionUserAction.toggleMute,
      CallV2ProductionUserAction.toggleCamera,
      CallV2ProductionUserAction.switchCamera,
      CallV2ProductionUserAction.leave,
    },
  );
}

CallV2ControlledFailureViewModel _failureModel() {
  return CallV2ControlledFailureViewModel(
    errorCode: CallV2ClientErrorCode.rejected,
    retryEnabled: true,
    dismissEnabled: false,
    allowedActions: const <CallV2ProductionUserAction>{
      CallV2ProductionUserAction.retryControlledFailure,
    },
  );
}

CallV2UiSessionReference _session(int generation) {
  return CallV2UiSessionReference(
    generation: generation,
    mediaMode: CallV2ProductionMediaMode.audio,
    localLifecycleStatus: CallV2ProductionLocalLifecycleStatus.active,
    connectionPhase: CallV2ProductionConnectionPhase.connected,
  );
}

final class _FakeDescriptor implements CallV2ProductionRouteDescriptor {
  const _FakeDescriptor({
    required this.destination,
    required this.routeName,
    required this.generation,
  });

  @override
  final CallV2ProductionRouteDestination destination;

  @override
  final String routeName;

  @override
  final int generation;

  @override
  CallV2ProductionPresentationTerminalStatus get terminalStatus =>
      CallV2ProductionPresentationTerminalStatus.nonterminal;

  @override
  CallV2UiSessionReference? get sessionReference => null;

  @override
  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'destination': destination.name,
      'generation': generation,
      'terminalStatus': terminalStatus.name,
    };
  }
}
