import 'dart:async';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/call_v2_feature_gate.dart';
import 'package:connect_app/call_v2/call_v2_runtime_configuration.dart';
import 'package:connect_app/call_v2/integration/non_production/non_production_call_v2_navigator_route_sink.dart';
import 'package:connect_app/call_v2/integration/non_production_call_v2_presentation_adapter.dart';
import 'package:connect_app/call_v2/integration/non_production_call_v2_route_factory.dart';
import 'package:connect_app/call_v2/integration/non_production_call_v2_test_harness.dart';
import 'package:connect_app/call_v2/startup/call_v2_startup_bridge.dart';
import 'package:connect_app/call_v2/ui/call_v2_route_intent.dart';
import 'package:connect_app/call_v2/ui/call_v2_ui_integration.dart';
import 'package:connect_app/call_v2/ui/production_call_v2_ui_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('successful launch flow', () {
    testWidgets('connecting and ready placeholders appear without identifiers',
        (tester) async {
      final setup = await _startHarness(tester);

      final launch = setup.coordinator.launch(_request());
      await tester.pumpAndSettle();

      expect(find.text('Call V2 connecting placeholder'), findsOneWidget);
      expect(find.text('Call V2 ready placeholder'), findsNothing);

      setup.startup.completeStart();
      await launch;
      await tester.pumpAndSettle();

      expect(find.text('Call V2 ready placeholder'), findsOneWidget);
      expect(find.text('Call V2 connecting placeholder'), findsNothing);
      _expectNoForbiddenWidgetText();
      expect(setup.startup.starts, 1);
      expect(setup.startup.runtimeStarts, 0);
      expect(setup.observer.pushedNames, <String>[
        '/call-v2/connecting',
        '/call-v2/ready',
      ]);
    });

    testWidgets('leave closes owned placeholder flow and preserves host',
        (tester) async {
      final setup = await _startHarness(tester);

      final launch = setup.coordinator.launch(_request());
      await tester.pumpAndSettle();
      setup.startup.completeStart();
      await launch;
      await tester.pumpAndSettle();

      await setup.coordinator.leave();
      await tester.pumpAndSettle();
      await setup.coordinator.leave();
      await tester.pumpAndSettle();

      expect(find.text(_hostText), findsOneWidget);
      expect(find.text('Call V2 connecting placeholder'), findsNothing);
      expect(find.text('Call V2 ready placeholder'), findsNothing);
      expect(setup.startup.stops, 1);
      expect(setup.sink.ownedRouteCount, 0);
    });
  });

  group('controlled failure flow', () {
    testWidgets('controlled failure opens generic unavailable placeholder',
        (tester) async {
      final setup = await _startHarness(tester);

      final launch = setup.coordinator.launch(_request());
      await tester.pumpAndSettle();
      setup.startup.completeStartWithError(
        const CallV2ClientError(CallV2ClientErrorCode.invalidRequest),
      );
      await expectLater(
        launch,
        throwsA(_clientError(CallV2ClientErrorCode.invalidRequest)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Call V2 unavailable'), findsOneWidget);
      expect(find.textContaining('invalidRequest'), findsNothing);
      expect(find.textContaining('invalid_request'), findsNothing);
      _expectNoForbiddenWidgetText();
    });

    testWidgets('raw startup failure is normalized and not rendered',
        (tester) async {
      final setup = await _startHarness(tester);

      final launch = setup.coordinator.launch(_request());
      await tester.pumpAndSettle();
      setup.startup.completeStartWithError(
        StateError('secret raw startup failure'),
      );
      await expectLater(
        launch,
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Call V2 unavailable'), findsOneWidget);
      expect(find.textContaining('secret raw startup failure'), findsNothing);
      expect(find.textContaining('StateError'), findsNothing);
      expect(find.textContaining('StackTrace'), findsNothing);
    });
  });

  group('ordering and lifecycle boundaries', () {
    testWidgets('intent order is preserved exactly once through the harness',
        (tester) async {
      final setup = await _startHarness(tester);

      final launch = setup.coordinator.launch(_request());
      await tester.pumpAndSettle();
      setup.startup.completeStart();
      await launch;
      await tester.pumpAndSettle();
      await setup.coordinator.leave();
      await tester.pumpAndSettle();

      expect(setup.observer.events, <String>[
        'push:/call-v2/connecting',
        'push:/call-v2/ready',
        'remove:/call-v2/ready',
        'remove:/call-v2/connecting',
      ]);
    });

    testWidgets('harness stop prevents later widget navigation',
        (tester) async {
      final setup = await _startManualHarness(tester);

      unawaited(setup.harness.stop());
      await tester.pump();
      setup.coordinator.emit(const CallV2OpenConnectingRoute());
      await tester.pump();
      await tester.pump();

      expect(find.text(_manualHostText), findsOneWidget);
      expect(find.text('Call V2 connecting placeholder'), findsNothing);
      expect(setup.observer.pushedNames, isEmpty);
    });

    testWidgets(
        'dispose prevents later widget navigation and raw errors escape',
        (tester) async {
      final setup = await _startManualHarness(tester);

      unawaited(setup.harness.dispose());
      await tester.pump();
      setup.coordinator.emit(const CallV2OpenReadyCallRoute());
      await tester.pump();
      await tester.pump();

      expect(find.text(_manualHostText), findsOneWidget);
      expect(find.text('Call V2 ready placeholder'), findsNothing);
      expect(setup.observer.pushedNames, isEmpty);
    });
  });
}

const _hostText = 'Call V2 widget host';
const _manualHostText = 'Call V2 manual widget host';

Future<_HarnessSetup> _startHarness(WidgetTester tester) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  final observer = _RecordingNavigatorObserver();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: <NavigatorObserver>[observer],
      home: const Scaffold(body: Center(child: Text(_hostText))),
    ),
  );
  await tester.pumpAndSettle();

  final startup = _FakeStartupBridge();
  final coordinator = _coordinator(startup);
  final sink = NonProductionCallV2NavigatorRouteSink.fromNavigatorKey(
    navigatorKey: navigatorKey,
  );
  final adapter = NonProductionCallV2PresentationAdapter(
    routeFactory: const NonProductionCallV2RouteFactory(),
    routeSink: sink,
    ownsRouteSink: true,
  );
  final harness = NonProductionCallV2TestHarness(
    coordinator: coordinator,
    presentationAdapter: adapter,
    ownsCoordinator: true,
    ownsPresentationAdapter: true,
  );
  await harness.start();

  return _HarnessSetup(
    startup: startup,
    coordinator: coordinator,
    sink: sink,
    harness: harness,
    observer: observer,
  );
}

Future<_ManualHarnessSetup> _startManualHarness(WidgetTester tester) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  final observer = _RecordingNavigatorObserver();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: <NavigatorObserver>[observer],
      home: const Scaffold(body: Center(child: Text(_manualHostText))),
    ),
  );
  await tester.pump();

  final coordinator = _ManualCoordinator();
  final sink = NonProductionCallV2NavigatorRouteSink.fromNavigatorKey(
    navigatorKey: navigatorKey,
  );
  final adapter = NonProductionCallV2PresentationAdapter(
    routeFactory: const NonProductionCallV2RouteFactory(),
    routeSink: sink,
    ownsRouteSink: true,
  );
  final harness = NonProductionCallV2TestHarness(
    coordinator: coordinator,
    presentationAdapter: adapter,
    ownsPresentationAdapter: true,
  );
  await harness.start();

  return _ManualHarnessSetup(
    coordinator: coordinator,
    harness: harness,
    observer: observer,
  );
}

ProductionCallV2UiCoordinator _coordinator(_FakeStartupBridge startup) {
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

void _expectNoForbiddenWidgetText() {
  for (final forbidden in <String>[
    'callA',
    'remoteUser',
    'uid',
    'participant',
    'token',
    'channel',
    'Firebase',
    'StackTrace',
    'microphone',
    'camera',
    'controls',
  ]) {
    expect(find.textContaining(forbidden, findRichText: true), findsNothing);
  }
}

final class _HarnessSetup {
  const _HarnessSetup({
    required this.startup,
    required this.coordinator,
    required this.sink,
    required this.harness,
    required this.observer,
  });

  final _FakeStartupBridge startup;
  final ProductionCallV2UiCoordinator coordinator;
  final NonProductionCallV2NavigatorRouteSink sink;
  final NonProductionCallV2TestHarness harness;
  final _RecordingNavigatorObserver observer;
}

final class _ManualHarnessSetup {
  const _ManualHarnessSetup({
    required this.coordinator,
    required this.harness,
    required this.observer,
  });

  final _ManualCoordinator coordinator;
  final NonProductionCallV2TestHarness harness;
  final _RecordingNavigatorObserver observer;
}

final class _ManualCoordinator implements CallV2UiCoordinator {
  _ManualCoordinator() {
    _routes = StreamController<CallV2RouteIntent>.broadcast(
      sync: true,
      onListen: () {},
      onCancel: () {},
    );
  }

  late final StreamController<CallV2RouteIntent> _routes;

  @override
  CallV2UiState get state => CallV2UiState.idle;

  @override
  Stream<CallV2UiState> get states => const Stream<CallV2UiState>.empty();

  @override
  Stream<CallV2RouteIntent> get routeIntents => _routes.stream;

  void emit(CallV2RouteIntent intent) {
    if (!_routes.isClosed) _routes.add(intent);
  }

  @override
  Future<void> launch(CallV2UiLaunchRequest request) async {}

  @override
  Future<void> leave() async {}

  @override
  Future<void> dispose() => _routes.close();
}

final class _FakeStartupBridge implements CallV2StartupBridge {
  Completer<void>? _startCompleter;
  int starts = 0;
  int stops = 0;
  int disposes = 0;
  int runtimeStarts = 0;

  @override
  CallV2StartupBridgeState get state => CallV2StartupBridgeState.idle;

  @override
  Future<void> start(CallV2StartupRequest request) {
    starts += 1;
    final completer = Completer<void>();
    _startCompleter = completer;
    return completer.future;
  }

  void completeStart() {
    _startCompleter?.complete();
  }

  void completeStartWithError(Object error) {
    _startCompleter?.completeError(error);
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

final class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<String> events = <String>[];
  final List<String?> pushedNames = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != '/') {
      pushedNames.add(name);
      events.add('push:$name');
    }
    super.didPush(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    events.add('remove:${route.settings.name}');
    super.didRemove(route, previousRoute);
  }
}
