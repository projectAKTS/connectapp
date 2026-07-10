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
import 'package:connect_app/call_v2/integration/call_v2_production_route_object_factory.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_route_object_factory_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const factory = CallV2ProductionRouteObjectFactory();

  test('connecting descriptor and model create a canonical Route object', () {
    final route = _route(
      factory.createRoute(
        descriptor: _descriptor(CallV2ProductionRouteDestination.connecting),
        viewModel: CallV2ConnectingProductionViewModel(_connectingModel()),
      ),
    );

    expect(route.settings.name, CallV2ProductionRouteNames.connecting);
    expect(route.settings.arguments, isNull);
    expect(_builtWidget(route), isA<CallV2ConnectingScreen>());
  });

  test('audio descriptor and model create a canonical Route object', () {
    final route = _route(
      factory.createRoute(
        descriptor: _descriptor(CallV2ProductionRouteDestination.activeAudio),
        viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
      ),
    );

    expect(route.settings.name, CallV2ProductionRouteNames.activeAudio);
    expect(route.settings.arguments, isNull);
    expect(_builtWidget(route), isA<CallV2ActiveAudioScreen>());
  });

  test('video descriptor and model create a canonical Route object', () {
    final route = _route(
      factory.createRoute(
        descriptor: _descriptor(CallV2ProductionRouteDestination.activeVideo),
        viewModel: CallV2ActiveVideoProductionViewModel(_videoModel()),
      ),
    );

    expect(route.settings.name, CallV2ProductionRouteNames.activeVideo);
    expect(route.settings.arguments, isNull);
    expect(_builtWidget(route), isA<CallV2ActiveVideoScreen>());
  });

  test('failure descriptor and model create a canonical Route object', () {
    final route = _route(
      factory.createRoute(
        descriptor:
            _descriptor(CallV2ProductionRouteDestination.controlledFailure),
        viewModel: CallV2ControlledFailureProductionViewModel(_failureModel()),
      ),
    );

    expect(route.settings.name, CallV2ProductionRouteNames.controlledFailure);
    expect(route.settings.arguments, isNull);
    expect(_builtWidget(route), isA<CallV2ControlledFailureScreen>());
  });

  test('terminal descriptor maps screen factory noScreen to noRoute', () {
    final result = factory.createRoute(
      descriptor: _descriptor(
        CallV2ProductionRouteDestination.activeAudio,
        terminalStatus:
            CallV2ProductionPresentationTerminalStatus.terminalDisposed,
      ),
      viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
    );

    expect(result, isA<CallV2ProductionRouteObjectFactoryNoRoute>());
  });

  test('destination and view model mismatch is rejected', () {
    final result = factory.createRoute(
      descriptor: _descriptor(CallV2ProductionRouteDestination.activeAudio),
      viewModel: CallV2ConnectingProductionViewModel(_connectingModel()),
    );

    expect(
      _rejection(result),
      CallV2ProductionRouteObjectFactoryError.destinationViewModelMismatch,
    );
  });

  test(
      'wrong, query, fragment, whitespace, dynamic, arbitrary, and ready reject',
      () {
    final candidates = <String>[
      CallV2ProductionRouteNames.activeVideo,
      '${CallV2ProductionRouteNames.activeAudio}?uid=abc',
      '${CallV2ProductionRouteNames.activeAudio}#token',
      '${CallV2ProductionRouteNames.activeAudio} ',
      '${CallV2ProductionRouteNames.activeAudio}/extra',
      '/not-call-v2/audio',
      '/call-v2/ready',
    ];

    for (final candidate in candidates) {
      final result = factory.createRoute(
        descriptor: _FakeDescriptor(
          destination: CallV2ProductionRouteDestination.activeAudio,
          routeName: candidate,
          generation: 4,
        ),
        viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
      );

      expect(
        _rejection(result),
        CallV2ProductionRouteObjectFactoryError.routeNameMismatch,
      );
      expect(result.toString(), isNot(contains(candidate)));
      expect(result.toSafeDebugMap().values, isNot(contains(candidate)));
    }
  });

  test('reserved destination is rejected', () {
    final result = factory.createRoute(
      descriptor: _FakeDescriptor(
        destination: CallV2ProductionRouteDestination.incomingReviewReserved,
        routeName: '/call-v2/ready',
        generation: 1,
      ),
      viewModel: CallV2ConnectingProductionViewModel(_connectingModel()),
    );

    expect(
      _rejection(result),
      CallV2ProductionRouteObjectFactoryError.reservedDestination,
    );
  });

  test('negative descriptor and minimum generation are rejected', () {
    expect(
      _rejection(
        factory.createRoute(
          descriptor: _FakeDescriptor(
            destination: CallV2ProductionRouteDestination.activeAudio,
            routeName: CallV2ProductionRouteNames.activeAudio,
            generation: -1,
          ),
          viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
        ),
      ),
      CallV2ProductionRouteObjectFactoryError.invalidInput,
    );
    expect(
      _rejection(
        factory.createRoute(
          descriptor: _descriptor(CallV2ProductionRouteDestination.activeAudio),
          viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
          minimumGeneration: -1,
        ),
      ),
      CallV2ProductionRouteObjectFactoryError.invalidInput,
    );
  });

  test('stale generation is rejected', () {
    final result = factory.createRoute(
      descriptor: _descriptor(
        CallV2ProductionRouteDestination.activeAudio,
        generation: 3,
      ),
      viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
      minimumGeneration: 4,
    );

    expect(
      _rejection(result),
      CallV2ProductionRouteObjectFactoryError.staleGeneration,
    );
  });

  testWidgets('optional callback passes typed actions through route screen',
      (tester) async {
    final actions = <CallV2ProductionUserAction>[];
    final route = _route(
      factory.createRoute(
        descriptor: _descriptor(CallV2ProductionRouteDestination.activeAudio),
        viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
        onAction: actions.add,
      ),
    );

    await tester.pumpWidget(_host(_builtWidget(route)));
    await tester.tap(find.byKey(
      const ValueKey<String>('call-v2.action.toggleMute'),
    ));

    expect(actions, <CallV2ProductionUserAction>[
      CallV2ProductionUserAction.toggleMute,
    ]);
  });

  testWidgets('null callback disables controls through route screen',
      (tester) async {
    final route = _route(
      factory.createRoute(
        descriptor: _descriptor(CallV2ProductionRouteDestination.activeAudio),
        viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
      ),
    );

    await tester.pumpWidget(_host(_builtWidget(route)));
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

    final result = factory.createRoute(
      descriptor: descriptor,
      viewModel: viewModel,
    );

    expect(result, isA<CallV2ProductionRouteObjectFactoryRoute>());
    expect(descriptor.toString(), descriptorBefore);
    expect(viewModel.toString(), viewModelBefore);
  });

  test('result debug output does not expose rejected route strings', () {
    final result = factory.createRoute(
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

Route<dynamic> _route(
  CallV2ProductionRouteObjectFactoryResult<dynamic> result,
) {
  expect(result, isA<CallV2ProductionRouteObjectFactoryRoute<dynamic>>());
  return (result as CallV2ProductionRouteObjectFactoryRoute<dynamic>).value;
}

Widget _builtWidget(Route<dynamic> route) {
  expect(route, isA<MaterialPageRoute<dynamic>>());
  return (route as MaterialPageRoute<dynamic>).builder(_FakeBuildContext());
}

CallV2ProductionRouteObjectFactoryError _rejection(
  CallV2ProductionRouteObjectFactoryResult<dynamic> result,
) {
  expect(result, isA<CallV2ProductionRouteObjectFactoryRejected<dynamic>>());
  return (result as CallV2ProductionRouteObjectFactoryRejected<dynamic>).error;
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

final class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
