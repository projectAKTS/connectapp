import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_route_sink.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_route_sink_adapter.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_route_sink_result.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('none to connecting pushes one Call V2 route', () async {
    final adapter = _FakeRouteSinkAdapter();
    final sink = CallV2ProductionRouteSink(adapter: adapter);

    final result = await sink.show(
      descriptor: _descriptor(CallV2ProductionRouteDestination.connecting),
      viewModel: CallV2ConnectingProductionViewModel(_connectingModel()),
    );

    expect(result, isA<CallV2ProductionRouteSinkPushed>());
    expect(adapter.operations, <String>['push']);
    expect(adapter.routes.single.settings.name,
        CallV2ProductionRouteNames.connecting);
    expect(adapter.routes.single.settings.arguments, isNull);
    expect(sink.state.currentDestination,
        CallV2ProductionRouteDestination.connecting);
    expect(sink.state.currentGeneration, 4);
  });

  test('none to audio video and failure push one Call V2 route', () async {
    for (final entry in <_RouteCase>[
      _RouteCase(
        CallV2ProductionRouteDestination.activeAudio,
        CallV2ProductionRouteNames.activeAudio,
        CallV2ActiveAudioProductionViewModel(_audioModel()),
      ),
      _RouteCase(
        CallV2ProductionRouteDestination.activeVideo,
        CallV2ProductionRouteNames.activeVideo,
        CallV2ActiveVideoProductionViewModel(_videoModel()),
      ),
      _RouteCase(
        CallV2ProductionRouteDestination.controlledFailure,
        CallV2ProductionRouteNames.controlledFailure,
        CallV2ControlledFailureProductionViewModel(_failureModel()),
      ),
    ]) {
      final adapter = _FakeRouteSinkAdapter();
      final sink = CallV2ProductionRouteSink(adapter: adapter);

      final result = await sink.show(
        descriptor: _descriptor(entry.destination),
        viewModel: entry.viewModel,
      );

      expect(result, isA<CallV2ProductionRouteSinkPushed>());
      expect(adapter.operations, <String>['push']);
      expect(adapter.routes.single.settings.name, entry.routeName);
      expect(adapter.routes.single.settings.arguments, isNull);
    }
  });

  test('connecting to active and failure destinations replaces', () async {
    for (final entry in <_RouteCase>[
      _RouteCase(
        CallV2ProductionRouteDestination.activeAudio,
        CallV2ProductionRouteNames.activeAudio,
        CallV2ActiveAudioProductionViewModel(_audioModel()),
      ),
      _RouteCase(
        CallV2ProductionRouteDestination.activeVideo,
        CallV2ProductionRouteNames.activeVideo,
        CallV2ActiveVideoProductionViewModel(_videoModel()),
      ),
      _RouteCase(
        CallV2ProductionRouteDestination.controlledFailure,
        CallV2ProductionRouteNames.controlledFailure,
        CallV2ControlledFailureProductionViewModel(_failureModel()),
      ),
    ]) {
      final adapter = _FakeRouteSinkAdapter();
      final sink = CallV2ProductionRouteSink(adapter: adapter);
      await sink.show(
        descriptor: _descriptor(
          CallV2ProductionRouteDestination.connecting,
          generation: 1,
        ),
        viewModel: CallV2ConnectingProductionViewModel(_connectingModel()),
      );

      final result = await sink.show(
        descriptor: _descriptor(entry.destination, generation: 2),
        viewModel: entry.viewModel,
      );

      expect(result, isA<CallV2ProductionRouteSinkReplaced>());
      expect(adapter.operations, <String>['push', 'replace']);
      expect(adapter.routes.last.settings.name, entry.routeName);
    }
  });

  test('audio and video to failure replace', () async {
    for (final entry in <_RouteCase>[
      _RouteCase(
        CallV2ProductionRouteDestination.activeAudio,
        CallV2ProductionRouteNames.activeAudio,
        CallV2ActiveAudioProductionViewModel(_audioModel()),
      ),
      _RouteCase(
        CallV2ProductionRouteDestination.activeVideo,
        CallV2ProductionRouteNames.activeVideo,
        CallV2ActiveVideoProductionViewModel(_videoModel()),
      ),
    ]) {
      final adapter = _FakeRouteSinkAdapter();
      final sink = CallV2ProductionRouteSink(adapter: adapter);
      await sink.show(
        descriptor: _descriptor(entry.destination, generation: 1),
        viewModel: entry.viewModel,
      );

      final result = await sink.show(
        descriptor: _descriptor(
          CallV2ProductionRouteDestination.controlledFailure,
          generation: 2,
        ),
        viewModel: CallV2ControlledFailureProductionViewModel(_failureModel()),
      );

      expect(result, isA<CallV2ProductionRouteSinkReplaced>());
      expect(adapter.operations, <String>['push', 'replace']);
      expect(
        adapter.routes.last.settings.name,
        CallV2ProductionRouteNames.controlledFailure,
      );
    }
  });

  test('duplicate same destination and generation is no-op', () async {
    final adapter = _FakeRouteSinkAdapter();
    final sink = CallV2ProductionRouteSink(adapter: adapter);
    await sink.show(
      descriptor: _descriptor(CallV2ProductionRouteDestination.activeAudio),
      viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
    );

    final result = await sink.show(
      descriptor: _descriptor(CallV2ProductionRouteDestination.activeAudio),
      viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
    );

    expect(result, isA<CallV2ProductionRouteSinkNoOp>());
    expect(adapter.operations, <String>['push']);
  });

  test('older and negative generations are rejected', () async {
    final adapter = _FakeRouteSinkAdapter();
    final sink = CallV2ProductionRouteSink(adapter: adapter);
    await sink.show(
      descriptor: _descriptor(
        CallV2ProductionRouteDestination.activeAudio,
        generation: 4,
      ),
      viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
    );

    expect(
      _rejection(await sink.show(
        descriptor: _descriptor(
          CallV2ProductionRouteDestination.controlledFailure,
          generation: 3,
        ),
        viewModel: CallV2ControlledFailureProductionViewModel(_failureModel()),
      )),
      CallV2ProductionRouteSinkError.staleGeneration,
    );
    expect(
      _rejection(await sink.show(
        descriptor: _FakeDescriptor(
          destination: CallV2ProductionRouteDestination.activeAudio,
          routeName: CallV2ProductionRouteNames.activeAudio,
          generation: -1,
        ),
        viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
      )),
      CallV2ProductionRouteSinkError.invalidInput,
    );
    expect(
      _rejection(await sink.show(
        descriptor: _descriptor(CallV2ProductionRouteDestination.activeAudio),
        viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
        minimumGeneration: -1,
      )),
      CallV2ProductionRouteSinkError.invalidInput,
    );
    expect(adapter.operations, <String>['push']);
  });

  test('newer generation safely replaces current route', () async {
    final adapter = _FakeRouteSinkAdapter();
    final sink = CallV2ProductionRouteSink(adapter: adapter);
    await sink.show(
      descriptor: _descriptor(
        CallV2ProductionRouteDestination.activeAudio,
        generation: 4,
      ),
      viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
    );

    final result = await sink.show(
      descriptor: _descriptor(
        CallV2ProductionRouteDestination.activeAudio,
        generation: 5,
      ),
      viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
    );

    expect(result, isA<CallV2ProductionRouteSinkReplaced>());
    expect(sink.state.currentGeneration, 5);
    expect(adapter.operations, <String>['push', 'replace']);
  });

  test('terminal descriptor closes active route or no-ops if none', () async {
    final adapter = _FakeRouteSinkAdapter();
    final sink = CallV2ProductionRouteSink(adapter: adapter);

    expect(
      await sink.show(
        descriptor: _descriptor(
          CallV2ProductionRouteDestination.activeAudio,
          terminalStatus:
              CallV2ProductionPresentationTerminalStatus.terminalDisposed,
        ),
        viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
      ),
      isA<CallV2ProductionRouteSinkNoOp>(),
    );
    await sink.show(
      descriptor: _descriptor(CallV2ProductionRouteDestination.activeAudio),
      viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
    );

    final result = await sink.show(
      descriptor: _descriptor(
        CallV2ProductionRouteDestination.activeAudio,
        generation: 5,
        terminalStatus:
            CallV2ProductionPresentationTerminalStatus.terminalDisposed,
      ),
      viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
    );

    expect(result, isA<CallV2ProductionRouteSinkPopped>());
    expect(adapter.operations, <String>['push', 'popCallV2Route']);
    expect(sink.state.currentDestination, isNull);
  });

  test('close and dispose are idempotent and prevent further navigation',
      () async {
    final adapter = _FakeRouteSinkAdapter();
    final sink = CallV2ProductionRouteSink(adapter: adapter);
    await sink.show(
      descriptor: _descriptor(CallV2ProductionRouteDestination.activeAudio),
      viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
    );

    expect(await sink.close(), isA<CallV2ProductionRouteSinkPopped>());
    expect(await sink.close(), isA<CallV2ProductionRouteSinkNoOp>());
    expect(sink.dispose(), isA<CallV2ProductionRouteSinkNoOp>());
    expect(sink.dispose(), isA<CallV2ProductionRouteSinkNoOp>());
    expect(
      _rejection(await sink.show(
        descriptor: _descriptor(CallV2ProductionRouteDestination.activeAudio),
        viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
      )),
      CallV2ProductionRouteSinkError.disposed,
    );
    expect(adapter.operations, <String>['push', 'popCallV2Route']);
  });

  test('adapter disposed and adapter failure are controlled rejections',
      () async {
    final disposedAdapter = _FakeRouteSinkAdapter()..disposed = true;
    final disposedSink = CallV2ProductionRouteSink(adapter: disposedAdapter);
    expect(
      _rejection(await disposedSink.show(
        descriptor: _descriptor(CallV2ProductionRouteDestination.activeAudio),
        viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
      )),
      CallV2ProductionRouteSinkError.adapterDisposed,
    );

    final failingAdapter = _FakeRouteSinkAdapter()..failNextOperation = true;
    final failingSink = CallV2ProductionRouteSink(adapter: failingAdapter);
    expect(
      _rejection(await failingSink.show(
        descriptor: _descriptor(CallV2ProductionRouteDestination.activeAudio),
        viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
      )),
      CallV2ProductionRouteSinkError.adapterOperationFailed,
    );
    expect(failingSink.state.currentDestination, isNull);
  });

  test('factory rejection maps to controlled sink rejection', () async {
    final adapter = _FakeRouteSinkAdapter();
    final sink = CallV2ProductionRouteSink(adapter: adapter);

    expect(
      _rejection(await sink.show(
        descriptor: _descriptor(CallV2ProductionRouteDestination.activeAudio),
        viewModel: CallV2ConnectingProductionViewModel(_connectingModel()),
      )),
      CallV2ProductionRouteSinkError.destinationViewModelMismatch,
    );
    expect(
      _rejection(await sink.show(
        descriptor: _FakeDescriptor(
          destination: CallV2ProductionRouteDestination.activeAudio,
          routeName: CallV2ProductionRouteNames.activeVideo,
          generation: 4,
        ),
        viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
      )),
      CallV2ProductionRouteSinkError.routeNameMismatch,
    );
    expect(
      _rejection(await sink.show(
        descriptor: _FakeDescriptor(
          destination: CallV2ProductionRouteDestination.incomingReviewReserved,
          routeName: '/call-v2/ready',
          generation: 4,
        ),
        viewModel: CallV2ConnectingProductionViewModel(_connectingModel()),
      )),
      CallV2ProductionRouteSinkError.reservedDestination,
    );
    expect(adapter.operations, isEmpty);
  });

  test('invalid transition is rejected', () async {
    final adapter = _FakeRouteSinkAdapter();
    final sink = CallV2ProductionRouteSink(adapter: adapter);
    await sink.show(
      descriptor: _descriptor(CallV2ProductionRouteDestination.activeAudio),
      viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
    );

    expect(
      _rejection(await sink.show(
        descriptor: _descriptor(
          CallV2ProductionRouteDestination.activeVideo,
          generation: 5,
        ),
        viewModel: CallV2ActiveVideoProductionViewModel(_videoModel()),
      )),
      CallV2ProductionRouteSinkError.invalidTransition,
    );
    expect(adapter.operations, <String>['push']);
  });

  test('close only invokes scoped Call V2 pop', () async {
    final adapter = _FakeRouteSinkAdapter();
    final sink = CallV2ProductionRouteSink(adapter: adapter);
    await sink.show(
      descriptor: _descriptor(CallV2ProductionRouteDestination.activeAudio),
      viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
    );

    await sink.close();

    expect(adapter.operations, <String>['push', 'popCallV2Route']);
    expect(adapter.operations, isNot(contains('pop')));
    expect(adapter.operations, isNot(contains('popV1Route')));
  });

  testWidgets('callback passes typed action only and null callback disables',
      (tester) async {
    final actions = <CallV2ProductionUserAction>[];
    final adapter = _FakeRouteSinkAdapter();
    final sink = CallV2ProductionRouteSink(adapter: adapter);
    await sink.show(
      descriptor: _descriptor(CallV2ProductionRouteDestination.activeAudio),
      viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
      onAction: actions.add,
    );

    await tester.pumpWidget(_host(_builtWidget(adapter.routes.single)));
    await tester.tap(
      find.byKey(const ValueKey<String>('call-v2.action.toggleMute')),
    );
    expect(actions, <CallV2ProductionUserAction>[
      CallV2ProductionUserAction.toggleMute,
    ]);

    final disabledAdapter = _FakeRouteSinkAdapter();
    final disabledSink = CallV2ProductionRouteSink(adapter: disabledAdapter);
    await disabledSink.show(
      descriptor: _descriptor(CallV2ProductionRouteDestination.activeAudio),
      viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
    );
    await tester.pumpWidget(_host(_builtWidget(disabledAdapter.routes.single)));
    final button = tester.widget<TextButton>(
      find.byKey(const ValueKey<String>('call-v2.action.toggleMute')),
    );
    expect(button.onPressed, isNull);
  });

  test('safe debug output excludes route strings and sensitive identifiers',
      () async {
    final adapter = _FakeRouteSinkAdapter();
    final sink = CallV2ProductionRouteSink(adapter: adapter);
    final result = await sink.show(
      descriptor: _FakeDescriptor(
        destination: CallV2ProductionRouteDestination.activeAudio,
        routeName: '${CallV2ProductionRouteNames.activeAudio}?callId=secret',
        generation: 8,
      ),
      viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
    );

    for (final debug in <String>[result.toString(), sink.state.toString()]) {
      for (final forbidden in <String>[
        '/call-v2',
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
    }
  });
}

final class _RouteCase {
  const _RouteCase(this.destination, this.routeName, this.viewModel);

  final CallV2ProductionRouteDestination destination;
  final String routeName;
  final CallV2ProductionViewModel viewModel;
}

final class _FakeRouteSinkAdapter implements CallV2ProductionRouteSinkAdapter {
  final List<String> operations = <String>[];
  final List<Route<dynamic>> routes = <Route<dynamic>>[];
  bool disposed = false;
  bool failNextOperation = false;

  @override
  bool get isDisposed => disposed;

  @override
  Future<void> push(Route<dynamic> route) async {
    await _record('push', route);
  }

  @override
  Future<void> replace(Route<dynamic> route) async {
    await _record('replace', route);
  }

  @override
  Future<void> popCallV2Route() async {
    if (failNextOperation) {
      failNextOperation = false;
      throw StateError('failed');
    }
    operations.add('popCallV2Route');
  }

  Future<void> _record(String operation, Route<dynamic> route) async {
    if (failNextOperation) {
      failNextOperation = false;
      throw StateError('failed');
    }
    operations.add(operation);
    routes.add(route);
  }
}

Widget _host(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: child);
}

Widget _builtWidget(Route<dynamic> route) {
  expect(route, isA<MaterialPageRoute<dynamic>>());
  return (route as MaterialPageRoute<dynamic>).builder(_FakeBuildContext());
}

CallV2ProductionRouteSinkError _rejection(
  CallV2ProductionRouteSinkResult result,
) {
  expect(result, isA<CallV2ProductionRouteSinkRejected>());
  return (result as CallV2ProductionRouteSinkRejected).error;
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
