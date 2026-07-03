import 'dart:async';
import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/call_v2_contract_manifest.dart';
import 'package:connect_app/call_v2/call_v2_feature_gate.dart';
import 'package:connect_app/call_v2/call_v2_production_capabilities.dart';
import 'package:connect_app/call_v2/call_v2_production_readiness.dart';
import 'package:connect_app/call_v2/call_v2_runtime_configuration.dart';
import 'package:connect_app/call_v2/production/call_v2_production_composition.dart';
import 'package:connect_app/call_v2/startup/call_v2_startup_bridge.dart';
import 'package:connect_app/call_v2/startup/production_call_v2_startup_bridge.dart';
import 'package:connect_app/call_v2/ui/call_v2_route_intent.dart';
import 'package:connect_app/call_v2/ui/call_v2_ui_capabilities.dart';
import 'package:connect_app/call_v2/ui/call_v2_ui_integration.dart';
import 'package:connect_app/call_v2/ui/production_call_v2_ui_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('construction and isolation', () {
    test('constructor has no side effects and touches no startup bridge', () {
      final bridge = _FakeStartupBridge();

      final coordinator = _coordinator(bridge: bridge);

      expect(coordinator.state.status, CallV2UiStatus.idle);
      expect(bridge.starts, 0);
      expect(bridge.stops, 0);
      expect(bridge.disposes, 0);
    });

    test(
        'source has no Firebase, RTC, Navigator, route, main, or screen wiring',
        () {
      final source = Directory('lib/call_v2/ui')
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.readAsStringSync())
          .join('\n');

      for (final forbidden in <String>[
        'Firebase',
        'Firestore',
        'FirebaseAuth',
        'FirebaseAppCheck',
        'RtcAdapter',
        'RtcEngine',
        'Navigator',
        'BuildContext',
        'MaterialPageRoute',
        'GoRouter',
        'routes:',
        'onGenerateRoute',
        'main(',
        'runApp',
        'lib/main.dart',
        'lib/screens/',
        'lib/services/',
        '.instance',
        'Platform.environment',
        'String.fromEnvironment',
        'Secret',
        'secret',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('main.dart and existing route files do not import isolated UI module',
        () {
      for (final path in <String>[
        'lib/main.dart',
        'lib/navigation/app_router.dart',
      ]) {
        final file = File(path);
        if (!file.existsSync()) continue;
        final source = file.readAsStringSync();
        expect(source.contains('call_v2/ui'), isFalse, reason: path);
        expect(source.contains('ProductionCallV2UiCoordinator'), isFalse,
            reason: path);
      }
    });

    test('existing screens do not import isolated UI module', () {
      final screenSources = Directory('lib/screens')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');

      expect(screenSources.contains('call_v2/ui'), isFalse);
      expect(screenSources.contains('ProductionCallV2UiCoordinator'), isFalse);
    });
  });

  group('request and route safety', () {
    test(
        'launch request exposes one remote participant and no caller/local UID',
        () {
      final request = _request(remoteParticipantUid: 'remoteUser');

      expect(request.callId, 'callA');
      expect(request.remoteParticipantUid, 'remoteUser');
      expect(request.localRole, CallV2LocalParticipantRole.caller);
      expect(request.toStartupRequest().remoteParticipantUid, 'remoteUser');
      expect(request.toString(), isNot(contains('remoteUser')));
      expect(request.toString(), isNot(contains('callA')));
      expect(request.toString(), isNot(contains('callerUid')));
      expect(request.toString(), isNot(contains('localUid')));
      expect(request.toString(), isNot(contains('authenticatedUid')));
    });

    test('invalid identifiers and full paths are rejected', () {
      for (final value in <String>['', ' callA', 'callA ', 'calls/callA']) {
        expect(
          () => _request(callId: value),
          throwsA(_clientError(CallV2ClientErrorCode.invalidRequest)),
        );
        expect(
          () => _request(remoteParticipantUid: value),
          throwsA(_clientError(CallV2ClientErrorCode.invalidRequest)),
        );
      }
    });

    test('route intents hide identifiers and only expose controlled error code',
        () {
      expect(const CallV2OpenConnectingRoute().toString(),
          isNot(contains('callA')));
      expect(
          const CallV2OpenReadyCallRoute().toString(), isNot(contains('uid')));
      expect(const CallV2CloseCallFlow().toString(), isNot(contains('token')));
      expect(
        const CallV2ShowControlledFailure(
          errorCode: CallV2ClientErrorCode.rejected,
        ).toString(),
        allOf(
          contains('rejected'),
          isNot(contains('callA')),
          isNot(contains('remoteUser')),
        ),
      );
    });
  });

  group('disabled behavior', () {
    test('disabled launch rejects without state, route, or bridge call',
        () async {
      final bridge = _FakeStartupBridge();
      final coordinator = _coordinator(
        bridge: bridge,
        enabled: false,
      );
      final states = <CallV2UiState>[];
      final routes = <CallV2RouteIntent>[];
      coordinator.states.listen(states.add);
      coordinator.routeIntents.listen(routes.add);

      await expectLater(
        coordinator.launch(_request()),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );

      expect(coordinator.state.status, CallV2UiStatus.idle);
      expect(states, isEmpty);
      expect(routes, isEmpty);
      expect(bridge.starts, 0);
    });
  });

  group('successful launch', () {
    test('emits connecting before bridge start and ready after success',
        () async {
      final bridge = _FakeStartupBridge();
      final coordinator = _coordinator(bridge: bridge);
      final events = <String>[];
      coordinator.states.listen((state) => events.add('state:${state.status}'));
      coordinator.routeIntents.listen((intent) => events.add('route:$intent'));

      await coordinator.launch(_request(isVideo: true));

      expect(events, <String>[
        'state:CallV2UiStatus.connecting',
        'route:CallV2OpenConnectingRoute()',
        'state:CallV2UiStatus.ready',
        'route:CallV2OpenReadyCallRoute()',
      ]);
      expect(bridge.starts, 1);
      expect(bridge.requests.single.callId, 'callA');
      expect(bridge.requests.single.remoteParticipantUid, 'remoteUser');
      expect(
          bridge.requests.single.localRole, CallV2LocalParticipantRole.caller);
      expect(bridge.requests.single.isVideo, isTrue);
    });

    test('duplicate same launch shares future and route intents once',
        () async {
      final bridge = _FakeStartupBridge()..heldStart = Completer<void>();
      final coordinator = _coordinator(bridge: bridge);
      final routes = <CallV2RouteIntent>[];
      coordinator.routeIntents.listen(routes.add);

      final first = coordinator.launch(_request());
      final second = coordinator.launch(_request());

      expect(identical(first, second), isTrue);
      expect(bridge.starts, 1);
      expect(routes.whereType<CallV2OpenConnectingRoute>(), hasLength(1));
      bridge.heldStart!.complete();
      await Future.wait(<Future<void>>[first, second]);
      expect(routes.whereType<CallV2OpenReadyCallRoute>(), hasLength(1));
    });

    test('same launch while ready is idempotent without duplicate routes',
        () async {
      final bridge = _FakeStartupBridge();
      final coordinator = _coordinator(bridge: bridge);
      final routes = <CallV2RouteIntent>[];
      coordinator.routeIntents.listen(routes.add);

      await coordinator.launch(_request());
      await coordinator.launch(_request());

      expect(bridge.starts, 1);
      expect(routes.whereType<CallV2OpenConnectingRoute>(), hasLength(1));
      expect(routes.whereType<CallV2OpenReadyCallRoute>(), hasLength(1));
    });

    test('ready is UI flow readiness, not an authoritative lifecycle claim',
        () async {
      final coordinator = _coordinator(bridge: _FakeStartupBridge());

      await coordinator.launch(_request());

      expect(coordinator.state.status, CallV2UiStatus.ready);
      expect(coordinator.state.toString(), isNot(contains('active')));
      expect(coordinator.state.toString(), isNot(contains('accepted')));
    });
  });

  group('failure', () {
    test('controlled bridge failure emits failed state and failure route only',
        () async {
      final bridge = _FakeStartupBridge()
        ..startError =
            const CallV2ClientError(CallV2ClientErrorCode.unavailable);
      final coordinator = _coordinator(bridge: bridge);
      final routes = <CallV2RouteIntent>[];
      coordinator.routeIntents.listen(routes.add);

      await expectLater(
        coordinator.launch(_request()),
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );

      expect(coordinator.state.status, CallV2UiStatus.failed);
      expect(coordinator.state.errorCode, CallV2ClientErrorCode.unavailable);
      expect(routes.whereType<CallV2OpenReadyCallRoute>(), isEmpty);
      expect(routes.whereType<CallV2ShowControlledFailure>(), hasLength(1));
      expect(
          routes
              .singleWhere((intent) => intent is CallV2ShowControlledFailure)
              .toString(),
          isNot(contains('raw')));
      expect(bridge.starts, 1);
    });

    test('raw bridge failure is sanitized and not retried', () async {
      final bridge = _FakeStartupBridge()..throwRawStart = true;
      final coordinator = _coordinator(bridge: bridge);

      await expectLater(
        coordinator.launch(_request()),
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );

      expect(coordinator.state.errorCode, CallV2ClientErrorCode.unavailable);
      expect(coordinator.state.toString(), isNot(contains('raw start')));
      expect(bridge.starts, 1);
    });
  });

  group('concurrency', () {
    test('conflicting launch fields reject', () async {
      final bridge = _FakeStartupBridge()..heldStart = Completer<void>();
      final coordinator = _coordinator(bridge: bridge);
      final first = coordinator.launch(_request());

      for (final request in <CallV2UiLaunchRequest>[
        _request(callId: 'callB'),
        _request(remoteParticipantUid: 'otherUser'),
        _request(localRole: CallV2LocalParticipantRole.callee),
        _request(isVideo: true),
      ]) {
        await expectLater(
          coordinator.launch(request),
          throwsA(_clientError(CallV2ClientErrorCode.rejected)),
        );
      }

      bridge.heldStart!.complete();
      await first;
      expect(bridge.starts, 1);
    });

    test('launch while leaving rejects', () async {
      final bridge = _FakeStartupBridge()..heldStop = Completer<void>();
      final coordinator = _coordinator(bridge: bridge);

      await coordinator.launch(_request());
      final leave = coordinator.leave();
      await expectLater(
        coordinator.launch(_request()),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
      bridge.heldStop!.complete();
      await leave;
    });
  });

  group('races', () {
    test('held bridge start then leave cannot emit ready route', () async {
      final bridge = _FakeStartupBridge()..heldStart = Completer<void>();
      final coordinator = _coordinator(bridge: bridge);
      final routes = <CallV2RouteIntent>[];
      coordinator.routeIntents.listen(routes.add);

      final launch = coordinator.launch(_request());
      await _pump();
      await coordinator.leave();
      bridge.heldStart!.complete();
      await expectLater(
        launch,
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );

      expect(routes.whereType<CallV2OpenReadyCallRoute>(), isEmpty);
      expect(routes.whereType<CallV2CloseCallFlow>(), hasLength(1));
      expect(coordinator.state.status, CallV2UiStatus.closed);
    });

    test(
        'held bridge start then dispose cannot emit ready or late failure route',
        () async {
      final bridge = _FakeStartupBridge()..heldStart = Completer<void>();
      final coordinator = _coordinator(bridge: bridge);
      final routes = <CallV2RouteIntent>[];
      coordinator.routeIntents.listen(routes.add);

      final launch = coordinator.launch(_request());
      await _pump();
      await coordinator.dispose();
      bridge.heldStart!.completeError(StateError('raw late failure'));
      await expectLater(
        launch,
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );

      expect(routes.whereType<CallV2OpenReadyCallRoute>(), isEmpty);
      expect(routes.whereType<CallV2ShowControlledFailure>(), isEmpty);
      expect(coordinator.state.status, CallV2UiStatus.disposed);
    });
  });

  group('leave and dispose', () {
    test('leave while idle is safe and emits close once', () async {
      final bridge = _FakeStartupBridge();
      final coordinator = _coordinator(bridge: bridge);
      final routes = <CallV2RouteIntent>[];
      coordinator.routeIntents.listen(routes.add);

      await coordinator.leave();
      await coordinator.leave();

      expect(bridge.stops, 1);
      expect(coordinator.state.status, CallV2UiStatus.closed);
      expect(routes.whereType<CallV2CloseCallFlow>(), hasLength(1));
    });

    test('duplicate leave coalesces and leaving precedes stop completion',
        () async {
      final bridge = _FakeStartupBridge()..heldStop = Completer<void>();
      final coordinator = _coordinator(bridge: bridge);
      final states = <CallV2UiState>[];
      coordinator.states.listen(states.add);
      await coordinator.launch(_request());

      final first = coordinator.leave();
      final second = coordinator.leave();

      expect(identical(first, second), isTrue);
      expect(states.last.status, CallV2UiStatus.leaving);
      expect(bridge.stops, 1);
      bridge.heldStop!.complete();
      await Future.wait(<Future<void>>[first, second]);
      expect(states.last.status, CallV2UiStatus.closed);
    });

    test('leave works while gate disabled and cleanup errors are sanitized',
        () async {
      final bridge = _FakeStartupBridge()
        ..stopError =
            const CallV2ClientError(CallV2ClientErrorCode.unavailable);
      final coordinator = _coordinator(
        bridge: bridge,
        enabled: false,
      );

      await expectLater(
        coordinator.leave(),
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );

      expect(bridge.stops, 1);
      expect(coordinator.state.status, CallV2UiStatus.closed);
      expect(coordinator.state.toString(), isNot(contains('raw stop')));
    });

    test('dispose is idempotent, closes streams, and owns bridge explicitly',
        () async {
      final bridge = _FakeStartupBridge();
      final coordinator = _coordinator(
        bridge: bridge,
        ownsStartupBridge: true,
      );
      var statesDone = false;
      var routesDone = false;
      coordinator.states.listen((_) {}, onDone: () => statesDone = true);
      coordinator.routeIntents.listen((_) {}, onDone: () => routesDone = true);

      await coordinator.dispose();
      await coordinator.dispose();
      await _pump();

      expect(bridge.stops, 1);
      expect(bridge.disposes, 1);
      expect(coordinator.state.status, CallV2UiStatus.disposed);
      expect(statesDone, isTrue);
      expect(routesDone, isTrue);
    });

    test('dispose attempts stop and dispose after cleanup failures', () async {
      final bridge = _FakeStartupBridge()
        ..throwRawStop = true
        ..throwRawDispose = true;
      final coordinator = _coordinator(
        bridge: bridge,
        ownsStartupBridge: true,
      );

      await expectLater(
        coordinator.dispose(),
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );

      expect(bridge.stops, 1);
      expect(bridge.disposes, 1);
      expect(coordinator.state.status, CallV2UiStatus.disposed);
      expect(coordinator.state.toString(), isNot(contains('raw')));
    });

    test('non-owned bridge is not disposed', () async {
      final bridge = _FakeStartupBridge();
      final coordinator = _coordinator(bridge: bridge);

      await coordinator.dispose();

      expect(bridge.stops, 1);
      expect(bridge.disposes, 0);
    });
  });

  group('capabilities and readiness', () {
    test('isolated UI capabilities enable startup and UI route only', () {
      expect(
          callV2IsolatedUiRouteIntegrationCapabilities
              .runtimeStartupBridgeAvailable,
          isTrue);
      expect(
          callV2IsolatedUiRouteIntegrationCapabilities
              .uiRouteIntegrationAvailable,
          isTrue);
      expect(
          callV2IsolatedUiRouteIntegrationCapabilities
              .nativeCallIntegrationAvailable,
          isFalse);
      expect(
          callV2IsolatedUiRouteIntegrationCapabilities.observabilityAvailable,
          isFalse);
      expect(
          callV2IsolatedStartupBridgeCapabilities.uiRouteIntegrationAvailable,
          isFalse);
      expect(
          callV2IsolatedProductionCompositionCapabilities
              .runtimeStartupBridgeAvailable,
          isFalse);
      expect(callV2NoProductionCapabilities.toSafeDebugMap().values,
          everyElement(isFalse));
    });

    test('readiness remains production-blocked by missing observability', () {
      final readiness = const CallV2ProductionReadinessAuditor().audit(
        manifest: callV2Phase3ContractManifest,
        configuration: _enabledProductionConfig(),
        capabilities: callV2IsolatedUiRouteIntegrationCapabilities,
      );

      expect(readiness.readyForAdapterImplementation, isTrue);
      expect(readiness.readyForProductionEnablement, isFalse);
      expect(
        readiness.issues.map((issue) => issue.code),
        contains(CallV2ProductionReadinessIssueCode.missingObservability),
      );
      expect(
        readiness.issues.map((issue) => issue.code),
        isNot(contains(
          CallV2ProductionReadinessIssueCode.missingUiRouteIntegration,
        )),
      );
    });

    test('coordinator does not bypass production readiness', () async {
      final bridge = _FakeStartupBridge();
      final coordinator = _coordinator(
        bridge: bridge,
        configuration: _enabledProductionConfig(),
      );

      await expectLater(
        coordinator.launch(_request()),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
      expect(bridge.starts, 0);
    });
  });
}

ProductionCallV2UiCoordinator _coordinator({
  required _FakeStartupBridge bridge,
  bool enabled = true,
  bool ownsStartupBridge = false,
  CallV2RuntimeConfiguration? configuration,
}) {
  return ProductionCallV2UiCoordinator(
    featureGate: CallV2FeatureGate(enabled: enabled),
    startupBridge: bridge,
    configuration: configuration ?? _enabledLocalConfig(),
    ownsStartupBridge: ownsStartupBridge,
  );
}

CallV2UiLaunchRequest _request({
  String callId = 'callA',
  String remoteParticipantUid = 'remoteUser',
  CallV2LocalParticipantRole localRole = CallV2LocalParticipantRole.caller,
  bool isVideo = false,
}) {
  return CallV2UiLaunchRequest(
    callId: callId,
    remoteParticipantUid: remoteParticipantUid,
    localRole: localRole,
    isVideo: isVideo,
  );
}

CallV2RuntimeConfiguration _enabledLocalConfig() {
  return const CallV2RuntimeConfiguration(
    enabled: true,
    environment: CallV2Environment.local,
    rtcProvider: CallV2RtcProviderKind.fake,
    rtcAppIdReference: 'localFakeRtc',
    callCollectionName: 'calls',
    participantSubcollectionName: 'participants',
    rtcTokenMaxLifetime: callV2AcceptedRtcTokenMaxLifetime,
    minimumTokenRemainingValidity: Duration(seconds: 60),
  );
}

CallV2RuntimeConfiguration _enabledProductionConfig() {
  return const CallV2RuntimeConfiguration(
    enabled: true,
    environment: CallV2Environment.production,
    rtcProvider: CallV2RtcProviderKind.agora,
    rtcAppIdReference: 'CALL_V2_AGORA_APP_ID',
    callCollectionName: 'calls',
    participantSubcollectionName: 'participants',
    rtcTokenMaxLifetime: callV2AcceptedRtcTokenMaxLifetime,
    minimumTokenRemainingValidity: Duration(seconds: 60),
  );
}

Matcher _clientError(CallV2ClientErrorCode code) {
  return isA<CallV2ClientError>().having(
    (error) => error.code,
    'code',
    code,
  );
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);

class _FakeStartupBridge implements CallV2StartupBridge {
  int starts = 0;
  int stops = 0;
  int disposes = 0;
  final requests = <CallV2StartupRequest>[];
  Completer<void>? heldStart;
  Completer<void>? heldStop;
  CallV2ClientError? startError;
  CallV2ClientError? stopError;
  bool throwRawStart = false;
  bool throwRawStop = false;
  bool throwRawDispose = false;

  CallV2StartupBridgeState _state = CallV2StartupBridgeState.idle;

  @override
  CallV2StartupBridgeState get state => _state;

  @override
  Future<void> start(CallV2StartupRequest request) async {
    starts += 1;
    requests.add(request);
    _state = const CallV2StartupBridgeState(
      status: CallV2StartupBridgeStatus.starting,
    );
    final held = heldStart;
    if (held != null) await held.future;
    if (throwRawStart) throw StateError('raw start failure');
    final error = startError;
    if (error != null) throw error;
    _state = const CallV2StartupBridgeState(
      status: CallV2StartupBridgeStatus.running,
    );
  }

  @override
  Future<void> stop() async {
    stops += 1;
    _state = const CallV2StartupBridgeState(
      status: CallV2StartupBridgeStatus.stopping,
    );
    final held = heldStop;
    if (held != null) await held.future;
    _state = const CallV2StartupBridgeState(
      status: CallV2StartupBridgeStatus.stopped,
    );
    if (throwRawStop) throw StateError('raw stop failure');
    final error = stopError;
    if (error != null) throw error;
  }

  @override
  Future<void> dispose() async {
    disposes += 1;
    _state = const CallV2StartupBridgeState(
      status: CallV2StartupBridgeStatus.disposed,
    );
    if (throwRawDispose) throw StateError('raw dispose failure');
  }
}
