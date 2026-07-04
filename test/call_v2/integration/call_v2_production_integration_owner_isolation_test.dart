import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_production_integration_status.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/production/call_v2_pre_integration_gate.dart';
import 'package:connect_app/call_v2/production/call_v2_production_integration_approval.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('status model exposes only controlled non-identifying fields', () {
    final status = CallV2ProductionIntegrationStatus.uninitialized;

    expect(status.toSafeDebugMap().keys, <String>{
      'lifecycle',
      'rolloutEnabled',
      'compositionConstructed',
      'runtimeStarted',
      'routesRegistered',
      'screensAvailable',
    });
    final text = status.toString();
    for (final forbidden in <String>[
      'uid',
      'callId',
      'participant',
      'token',
      'channel',
      'Exception',
      'StackTrace',
      'message',
    ]) {
      expect(text.contains(forbidden), isFalse, reason: forbidden);
    }
  });

  test('rollout false keeps owner and route registry inert', () async {
    final owner = DisabledCallV2ProductionIntegrationOwner();

    await owner.initialize();

    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(
        owner.status.lifecycle, CallV2ProductionIntegrationLifecycle.disabled);
    expect(
        resolveCallV2Route(
          const RouteSettings(name: '/call-v2/connecting'),
        ),
        isNull);
    expect(
        resolveCallV2Route(
          const RouteSettings(name: '/call-v2/active-audio'),
        ),
        isNull);
  });

  test('approval and structural readiness do not authorize actual integration',
      () async {
    final defaultGate = const CallV2PreIntegrationGate().evaluate();
    final approvedGate = const CallV2PreIntegrationGate().evaluate(
      approval: const CallV2ProductionIntegrationApproval.fullyApproved(),
    );
    final owner = DisabledCallV2ProductionIntegrationOwner(
      approval: const CallV2ProductionIntegrationApproval.fullyApproved(),
    );

    await owner.initialize();

    expect(defaultGate.status, CallV2ProductionIntegrationGateStatus.blocked);
    expect(defaultGate.approvalsComplete, isFalse);
    expect(defaultGate.actualIntegrationAuthorized, isFalse);
    expect(defaultGate.rolloutAuthorized, isFalse);
    expect(approvedGate.structurallyReady, isTrue);
    expect(approvedGate.actualIntegrationAuthorized, isFalse);
    expect(approvedGate.rolloutAuthorized, isFalse);
    expect(
        owner.status.lifecycle, CallV2ProductionIntegrationLifecycle.disabled);
    expect(owner.status.compositionConstructed, isFalse);
  });

  test('main and router remain isolated from real production integration', () {
    final main = _read('lib/main.dart');
    final appRouter = _read('lib/navigation/app_router.dart');
    final routeRegistry =
        _read('lib/call_v2/integration/call_v2_route_registry.dart');

    expect(main, contains('initializeCallV2AppIntegrationShellSafely()'));
    expect(main.contains('ProductionCallV2StartupBridge'), isFalse);
    expect(main.contains('ProductionCallV2UiCoordinator'), isFalse);
    expect(main.contains('CallV2ProductionComposition('), isFalse);
    expect(main.contains('.start('), isFalse);
    expect(appRouter.contains('CallV2Production'), isFalse);
    expect(appRouter.contains('/call-v2'), isFalse);
    expect(
      routeRegistry,
      contains('if (!CallV2RolloutPolicy.productionEnabled) return null;'),
    );
  });

  test(
      'no production screens, Navigator sink, backend, RTC, or permissions added',
      () {
    final paths = Directory('lib/call_v2')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.path)
        .toList(growable: false);
    final integrationSource = _integrationOwnerSource();

    expect(paths.where((path) => path.contains('production_call_v2_screen')),
        isEmpty);
    expect(
        paths.where((path) => path.contains('production_call_v2_route_sink')),
        isEmpty);
    for (final forbidden in <String>[
      'FirebaseAuth.instance',
      'FirebaseFirestore.instance',
      'FirebaseFunctions.instance',
      'FirebaseAppCheck.instance',
      'Permission.',
      'requestPermission',
      'RtcEngine',
      'Navigator.',
      'GlobalKey',
      'MaterialPageRoute',
      'CupertinoPageRoute',
      'httpsCallable',
      'snapshots()',
    ]) {
      expect(integrationSource.contains(forbidden), isFalse, reason: forbidden);
    }
  });

  test('backup branch is not referenced or modified by source', () {
    final source = _integrationOwnerSource();

    expect(
      source.contains('backup/call-v2-pre-phase6b-2026-07-04'),
      isFalse,
    );
  });
}

String _integrationOwnerSource() {
  return <String>[
    'lib/call_v2/integration/call_v2_app_integration.dart',
    'lib/call_v2/integration/disabled_call_v2_app_integration.dart',
    'lib/call_v2/integration/call_v2_production_integration_owner.dart',
    'lib/call_v2/integration/call_v2_production_integration_status.dart',
    'lib/call_v2/integration/disabled_call_v2_production_integration_owner.dart',
  ].map(_read).join('\n');
}

String _read(String path) => File(path).readAsStringSync();
