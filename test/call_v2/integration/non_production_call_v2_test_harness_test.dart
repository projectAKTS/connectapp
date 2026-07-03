import 'dart:async';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/call_v2_feature_gate.dart';
import 'package:connect_app/call_v2/call_v2_runtime_configuration.dart';
import 'package:connect_app/call_v2/integration/call_v2_presentation_adapter.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_factory.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_sink.dart';
import 'package:connect_app/call_v2/integration/call_v2_test_harness.dart';
import 'package:connect_app/call_v2/integration/non_production_call_v2_presentation_adapter.dart';
import 'package:connect_app/call_v2/integration/non_production_call_v2_route_factory.dart';
import 'package:connect_app/call_v2/integration/non_production_call_v2_test_harness.dart';
import 'package:connect_app/call_v2/startup/call_v2_startup_bridge.dart';
import 'package:connect_app/call_v2/ui/call_v2_route_intent.dart';
import 'package:connect_app/call_v2/ui/call_v2_ui_integration.dart';
import 'package:connect_app/call_v2/ui/production_call_v2_ui_coordinator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('construction', () {
    test('constructor has no side effects and uses injected dependencies', () {
      final coordinator = _RecordingCoordinator();
      final adapter = _RecordingPresentationAdapter();

      final harness = NonProductionCallV2TestHarness(
        coordinator: coordinator,
        presentationAdapter: adapter,
      );

      expect(harness, isA<CallV2TestHarness>());
      expect(harness.state.status, NonProductionCallV2TestHarnessStatus.idle);
      expect(coordinator.listenCount, 0);
      expect(adapter.handled, isEmpty);
      expect(adapter.disposes, 0);
      expect(coordinator.disposes, 0);
    });

    test('ownership flags are explicit', () async {
      final unownedCoordinator = _RecordingCoordinator();
      final unownedAdapter = _RecordingPresentationAdapter();
      await NonProductionCallV2TestHarness(
        coordinator: unownedCoordinator,
        presentationAdapter: unownedAdapter,
      ).dispose();
      expect(unownedCoordinator.disposes, 0);
      expect(unownedAdapter.disposes, 0);

      final ownedCoordinator = _RecordingCoordinator();
      final ownedAdapter = _RecordingPresentationAdapter();
      final owned = NonProductionCallV2TestHarness(
        coordinator: ownedCoordinator,
        presentationAdapter: ownedAdapter,
        ownsCoordinator: true,
        ownsPresentationAdapter: true,
      );
      await owned.dispose();
      await owned.dispose();
      expect(ownedCoordinator.disposes, 1);
      expect(ownedAdapter.disposes, 1);
    });
  });

  group('start and stop', () {
    test('start creates one subscription and repeated start is idempotent',
        () async {
      final coordinator = _RecordingCoordinator();
      final harness = _harness(coordinator: coordinator);

      await harness.start();
      await harness.start();

      expect(coordinator.listenCount, 1);
      expect(coordinator.cancelCount, 0);
      expect(
          harness.state.status, NonProductionCallV2TestHarnessStatus.running);
    });

    test('stop cancels subscription, is idempotent, and blocks forwarding',
        () async {
      final coordinator = _RecordingCoordinator();
      final adapter = _RecordingPresentationAdapter();
      final harness = _harness(coordinator: coordinator, adapter: adapter);

      await harness.start();
      await harness.stop();
      await harness.stop();
      coordinator.emit(const CallV2OpenReadyCallRoute());
      await _pump();

      expect(coordinator.cancelCount, 1);
      expect(adapter.handled, isEmpty);
      expect(
          harness.state.status, NonProductionCallV2TestHarnessStatus.stopped);
    });

    test('restart after stop is deterministic and does not auto-start',
        () async {
      final coordinator = _RecordingCoordinator();
      final adapter = _RecordingPresentationAdapter();
      final harness = _harness(coordinator: coordinator, adapter: adapter);

      coordinator.emit(const CallV2OpenConnectingRoute());
      await _pump();
      expect(adapter.handled, isEmpty);

      await harness.start();
      await harness.stop();
      await harness.start();
      coordinator.emit(const CallV2OpenConnectingRoute());
      await _settle();

      expect(coordinator.listenCount, 2);
      expect(adapter.handled, hasLength(1));
    });
  });

  group('end-to-end intent flow', () {
    test('production coordinator intents reach placeholder routes in order',
        () async {
      final startup = _FakeStartupBridge();
      final coordinator = _productionCoordinator(startup);
      final sink = _RecordingRouteSink();
      final adapter = NonProductionCallV2PresentationAdapter(
        routeFactory: const NonProductionCallV2RouteFactory(),
        routeSink: sink,
      );
      final harness = NonProductionCallV2TestHarness(
        coordinator: coordinator,
        presentationAdapter: adapter,
      );

      await harness.start();
      await coordinator.launch(_request());
      await _settle();
      await coordinator.leave();
      await _settle();

      expect(sink.events, <String>[
        'open:${CallV2RouteFactoryNames.connecting}',
        'open:${CallV2RouteFactoryNames.ready}',
        'close',
      ]);
      expect(startup.starts, 1);
      expect(startup.stops, 1);
    });

    test('controlled failure intent reaches failure placeholder route',
        () async {
      final coordinator = _RecordingCoordinator();
      final sink = _RecordingRouteSink();
      final adapter = NonProductionCallV2PresentationAdapter(
        routeFactory: const NonProductionCallV2RouteFactory(),
        routeSink: sink,
      );
      final harness = _harness(coordinator: coordinator, adapter: adapter);

      await harness.start();
      coordinator.emit(
        const CallV2ShowControlledFailure(
          errorCode: CallV2ClientErrorCode.rejected,
        ),
      );
      await _pump();

      expect(
        sink.openedNames,
        <String>[CallV2RouteFactoryNames.controlledFailure],
      );
      expect(sink.openedNames.single, isNot(contains('uid')));
      expect(sink.openedNames.single, isNot(contains('token')));
    });

    test('harness does not inspect identifiers or route arguments', () async {
      final coordinator = _RecordingCoordinator();
      final adapter = _RecordingPresentationAdapter();
      final harness = _harness(coordinator: coordinator, adapter: adapter);

      await harness.start();
      coordinator.emit(const CallV2OpenConnectingRoute());
      coordinator.emit(const CallV2OpenReadyCallRoute());
      coordinator.emit(const CallV2CloseCallFlow());
      await _pump();

      expect(adapter.handled.map((intent) => intent.runtimeType), <Type>[
        CallV2OpenConnectingRoute,
        CallV2OpenReadyCallRoute,
        CallV2CloseCallFlow,
      ]);
      for (final intent in adapter.handled) {
        expect(intent.toString(), isNot(contains('uid')));
        expect(intent.toString(), isNot(contains('callId')));
        expect(intent.toString(), isNot(contains('arguments')));
      }
    });
  });

  group('backpressure and failure policy', () {
    test('adapter calls never overlap and concurrent stream events keep order',
        () async {
      final first = Completer<void>();
      final coordinator = _RecordingCoordinator();
      final adapter =
          _RecordingPresentationAdapter(completions: <Completer<void>>[
        first,
      ]);
      final harness = _harness(coordinator: coordinator, adapter: adapter);

      await harness.start();
      coordinator.emit(const CallV2OpenConnectingRoute());
      coordinator.emit(const CallV2OpenReadyCallRoute());
      await _pump();

      expect(adapter.handled, hasLength(1));
      expect(adapter.maxConcurrent, 1);
      first.complete();
      await _pump();
      await _pump();

      expect(adapter.handled.map((intent) => intent.runtimeType), <Type>[
        CallV2OpenConnectingRoute,
        CallV2OpenReadyCallRoute,
      ]);
      expect(adapter.maxConcurrent, 1);
    });

    test('stop and dispose invalidate queued intents', () async {
      final stopFirst = Completer<void>();
      final stopCoordinator = _RecordingCoordinator();
      final stopAdapter = _RecordingPresentationAdapter(
        completions: <Completer<void>>[stopFirst],
      );
      final stopHarness = _harness(
        coordinator: stopCoordinator,
        adapter: stopAdapter,
      );

      await stopHarness.start();
      stopCoordinator.emit(const CallV2OpenConnectingRoute());
      stopCoordinator.emit(const CallV2OpenReadyCallRoute());
      await _pump();
      final stopFuture = stopHarness.stop();
      stopFirst.complete();
      await stopFuture;
      await _pump();
      expect(stopAdapter.handled, hasLength(1));

      final disposeFirst = Completer<void>();
      final disposeCoordinator = _RecordingCoordinator();
      final disposeAdapter = _RecordingPresentationAdapter(
        completions: <Completer<void>>[disposeFirst],
      );
      final disposeHarness = _harness(
        coordinator: disposeCoordinator,
        adapter: disposeAdapter,
      );

      await disposeHarness.start();
      disposeCoordinator.emit(const CallV2OpenConnectingRoute());
      disposeCoordinator.emit(const CallV2OpenReadyCallRoute());
      await _pump();
      final disposeFuture = disposeHarness.dispose();
      disposeFirst.complete();
      await disposeFuture;
      await _pump();
      expect(disposeAdapter.handled, hasLength(1));
    });

    test('failure policy stops forwarding and does not retry', () async {
      final coordinator = _RecordingCoordinator();
      final adapter = _RecordingPresentationAdapter(
        errors: <Object>[
          const CallV2ClientError(CallV2ClientErrorCode.invalidRequest),
        ],
      );
      final harness = _harness(coordinator: coordinator, adapter: adapter);

      await harness.start();
      coordinator.emit(const CallV2OpenConnectingRoute());
      coordinator.emit(const CallV2OpenReadyCallRoute());
      await _pump();
      await _pump();

      expect(harness.state.status, NonProductionCallV2TestHarnessStatus.failed);
      expect(harness.state.errorCode, CallV2ClientErrorCode.invalidRequest);
      expect(adapter.handled, hasLength(1));
      expect(coordinator.cancelCount, 1);
      await expectLater(
        harness.start(),
        throwsA(_clientError(CallV2ClientErrorCode.invalidRequest)),
      );
    });

    test('raw adapter and stream errors become unavailable without raw details',
        () async {
      final rawCoordinator = _RecordingCoordinator();
      final rawAdapter = _RecordingPresentationAdapter(
        errors: <Object>[StateError('secret raw adapter detail')],
      );
      final rawHarness = _harness(
        coordinator: rawCoordinator,
        adapter: rawAdapter,
      );
      await rawHarness.start();
      rawCoordinator.emit(const CallV2OpenConnectingRoute());
      await _pump();

      expect(
          rawHarness.state.status, NonProductionCallV2TestHarnessStatus.failed);
      expect(rawHarness.state.errorCode, CallV2ClientErrorCode.unavailable);
      expect(rawHarness.state.toString(), isNot(contains('secret')));
      expect(rawHarness.state.toString(), isNot(contains('StackTrace')));

      final streamCoordinator = _RecordingCoordinator();
      final streamHarness = _harness(coordinator: streamCoordinator);
      await streamHarness.start();
      streamCoordinator.emitError(StateError('secret stream detail'));
      await _pump();

      expect(
        streamHarness.state.errorCode,
        CallV2ClientErrorCode.unavailable,
      );
      expect(streamHarness.state.toString(), isNot(contains('secret')));
    });
  });

  group('dispose cleanup', () {
    test('dispose cancels first and attempts all owned cleanup after failures',
        () async {
      final coordinator = _RecordingCoordinator(
        disposeError: StateError('raw coordinator dispose'),
      );
      final adapter = _RecordingPresentationAdapter(
        disposeError: const CallV2ClientError(CallV2ClientErrorCode.rejected),
      );
      final harness = NonProductionCallV2TestHarness(
        coordinator: coordinator,
        presentationAdapter: adapter,
        ownsCoordinator: true,
        ownsPresentationAdapter: true,
      );

      await harness.start();
      await expectLater(
        harness.dispose(),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
      await harness.dispose();

      expect(coordinator.cancelCount, 1);
      expect(adapter.disposes, 1);
      expect(coordinator.disposes, 1);
      expect(
          harness.state.status, NonProductionCallV2TestHarnessStatus.disposed);
      expect(harness.state.errorCode, CallV2ClientErrorCode.rejected);
    });

    test('no forwarding after dispose', () async {
      final coordinator = _RecordingCoordinator();
      final adapter = _RecordingPresentationAdapter();
      final harness = _harness(coordinator: coordinator, adapter: adapter);

      await harness.start();
      await harness.dispose();
      coordinator.emit(const CallV2OpenConnectingRoute());
      await _pump();

      expect(adapter.handled, isEmpty);
      await expectLater(
        harness.start(),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
    });
  });
}

NonProductionCallV2TestHarness _harness({
  required _RecordingCoordinator coordinator,
  CallV2PresentationAdapter? adapter,
}) {
  return NonProductionCallV2TestHarness(
    coordinator: coordinator,
    presentationAdapter: adapter ?? _RecordingPresentationAdapter(),
  );
}

ProductionCallV2UiCoordinator _productionCoordinator(
  _FakeStartupBridge startup,
) {
  return ProductionCallV2UiCoordinator(
    featureGate: const CallV2FeatureGate(enabled: true),
    startupBridge: startup,
    configuration: const CallV2RuntimeConfiguration(
      enabled: true,
      environment: CallV2Environment.local,
      rtcProvider: CallV2RtcProviderKind.fake,
      rtcAppIdReference: 'localFakeRtc',
      callCollectionName: 'calls',
      participantSubcollectionName: 'participants',
      rtcTokenMaxLifetime: callV2AcceptedRtcTokenMaxLifetime,
      minimumTokenRemainingValidity: Duration(seconds: 60),
    ),
  );
}

CallV2UiLaunchRequest _request() {
  return CallV2UiLaunchRequest(
    callId: 'callA',
    remoteParticipantUid: 'remoteUser',
    localRole: CallV2LocalParticipantRole.caller,
    isVideo: true,
  );
}

Matcher _clientError(CallV2ClientErrorCode code) {
  return isA<CallV2ClientError>().having((error) => error.code, 'code', code);
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);

Future<void> _settle() async {
  await _pump();
  await _pump();
  await _pump();
}

final class _RecordingCoordinator implements CallV2UiCoordinator {
  _RecordingCoordinator({this.disposeError}) {
    _routes = StreamController<CallV2RouteIntent>.broadcast(
      sync: true,
      onListen: () => listenCount += 1,
      onCancel: () => cancelCount += 1,
    );
  }

  final Object? disposeError;
  late final StreamController<CallV2RouteIntent> _routes;
  int listenCount = 0;
  int cancelCount = 0;
  int launches = 0;
  int leaves = 0;
  int disposes = 0;

  @override
  CallV2UiState get state => CallV2UiState.idle;

  @override
  Stream<CallV2UiState> get states => const Stream<CallV2UiState>.empty();

  @override
  Stream<CallV2RouteIntent> get routeIntents => _routes.stream;

  void emit(CallV2RouteIntent intent) {
    if (!_routes.isClosed) _routes.add(intent);
  }

  void emitError(Object error) {
    if (!_routes.isClosed) _routes.addError(error);
  }

  @override
  Future<void> launch(CallV2UiLaunchRequest request) async {
    launches += 1;
  }

  @override
  Future<void> leave() async {
    leaves += 1;
  }

  @override
  Future<void> dispose() async {
    disposes += 1;
    await _routes.close();
    final error = disposeError;
    if (error != null) throw error;
  }
}

final class _RecordingPresentationAdapter implements CallV2PresentationAdapter {
  _RecordingPresentationAdapter({
    List<Completer<void>> completions = const <Completer<void>>[],
    List<Object> errors = const <Object>[],
    this.disposeError,
  })  : _completions = List<Completer<void>>.of(completions),
        _errors = List<Object>.of(errors);

  final List<Completer<void>> _completions;
  final List<Object> _errors;
  final Object? disposeError;
  final List<CallV2RouteIntent> handled = <CallV2RouteIntent>[];
  int active = 0;
  int maxConcurrent = 0;
  int disposes = 0;

  @override
  Future<void> handle(CallV2RouteIntent intent) async {
    active += 1;
    if (active > maxConcurrent) maxConcurrent = active;
    handled.add(intent);
    try {
      if (_completions.isNotEmpty) {
        await _completions.removeAt(0).future;
      }
      if (_errors.isNotEmpty) {
        throw _errors.removeAt(0);
      }
    } finally {
      active -= 1;
    }
  }

  @override
  Future<void> dispose() async {
    disposes += 1;
    final error = disposeError;
    if (error != null) throw error;
  }
}

final class _RecordingRouteSink implements CallV2RouteSink {
  final List<String> events = <String>[];
  final List<String> openedNames = <String>[];
  int closeCount = 0;

  @override
  Future<void> open(Route<dynamic> route) async {
    final name = route.settings.name ?? '<unnamed>';
    openedNames.add(name);
    events.add('open:$name');
  }

  @override
  Future<void> close() async {
    closeCount += 1;
    events.add('close');
  }
}

final class _FakeStartupBridge implements CallV2StartupBridge {
  int starts = 0;
  int stops = 0;
  int disposes = 0;

  @override
  CallV2StartupBridgeState get state => CallV2StartupBridgeState.idle;

  @override
  Future<void> start(CallV2StartupRequest request) async {
    starts += 1;
  }

  @override
  Future<void> stop() async {
    stops += 1;
  }

  @override
  Future<void> dispose() async {
    disposes += 1;
  }
}
