import 'dart:io';

import 'package:connect_app/call_v2/call_v2_runtime_configuration.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/production/call_v2_final_readiness_audit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('harness sources stay isolated from production and platform services',
      () {
    final source = _readAll(<String>[
      'lib/call_v2/integration/call_v2_test_harness.dart',
      'lib/call_v2/integration/non_production_call_v2_test_harness.dart',
    ]);

    for (final forbidden in <String>[
      'Firebase',
      'Firestore',
      'FirebaseAuth',
      'FirebaseAppCheck',
      'RtcAdapter',
      'RtcEngine',
      'Permission',
      'Navigator',
      'BuildContext',
      'MaterialApp',
      'onGenerateRoute',
      'runApp',
      'main(',
      'Platform.environment',
      'String.fromEnvironment',
      'RemoteConfig',
      'debugPrint',
      'print(',
      'CallV2StartupBridge',
      'CallV2RouteFactory',
      'CallV2RouteSink',
      'routeSink',
      '.create(',
      '.launch(',
      '.leave(',
    ]) {
      expect(source.contains(forbidden), isFalse, reason: forbidden);
    }

    expect(source.contains('CallV2UiCoordinator'), isTrue);
    expect(source.contains('CallV2PresentationAdapter'), isTrue);
    expect(source.contains('routeIntents'), isTrue);
  });

  test('harness does not inspect identifiers, startup requests, or route args',
      () {
    final source = _readAll(<String>[
      'lib/call_v2/integration/non_production_call_v2_test_harness.dart',
    ]);

    for (final forbidden in <String>[
      'CallV2UiLaunchRequest',
      'CallV2StartupRequest',
      'callId',
      'uid',
      'Uid',
      'participant',
      'settings.arguments',
      'arguments',
      'as Map',
      'RouteSettings',
    ]) {
      expect(source.contains(forbidden), isFalse, reason: forbidden);
    }
  });

  test('real app files do not import or reference the harness', () {
    for (final path in <String>[
      'lib/main.dart',
      'lib/navigation/app_router.dart',
      'lib/call_v2/integration/call_v2_app_integration.dart',
      'lib/call_v2/integration/disabled_call_v2_app_integration.dart',
      'lib/call_v2/integration/call_v2_route_registry.dart',
      'lib/call_v2/integration/disabled_call_v2_route_registry.dart',
      'lib/call_v2/production/call_v2_production_composition.dart',
      'lib/call_v2/startup/production_call_v2_startup_bridge.dart',
    ]) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final source = file.readAsStringSync();
      expect(source.contains('call_v2_test_harness'), isFalse, reason: path);
      expect(source.contains('NonProductionCallV2TestHarness'), isFalse,
          reason: path);
      expect(source.contains('CallV2TestHarness'), isFalse, reason: path);
    }
  });

  test('main router remains without Call V2 route wiring', () {
    for (final path in <String>[
      'lib/main.dart',
      'lib/navigation/app_router.dart',
    ]) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final source = file.readAsStringSync();
      expect(source.contains('/call-v2/'), isFalse, reason: path);
      expect(source.contains('NonProductionCallV2'), isFalse, reason: path);
    }
  });

  test('rollout remains hard-disabled and readiness remains closed', () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);

    final result = const CallV2FinalReadinessAuditor().audit(
      configuration: _productionConfig(),
    );
    final gate = const CallV2FinalReadinessAuditor().evaluateRolloutGate(
      configuration: _productionConfig(),
    );

    expect(result.readyForProductionEnablement, isTrue);
    expect(result.readyForActualRollout, isFalse);
    expect(result.realRoutesWired, isFalse);
    expect(result.realScreensWired, isFalse);
    expect(gate.status, CallV2RolloutGateStatus.closed);
  });
}

String _readAll(List<String> paths) {
  return paths.map((path) => File(path).readAsStringSync()).join('\n');
}

CallV2RuntimeConfiguration _productionConfig() {
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
