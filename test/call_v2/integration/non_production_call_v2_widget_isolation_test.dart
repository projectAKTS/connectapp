import 'dart:io';

import 'package:connect_app/call_v2/call_v2_runtime_configuration.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/production/call_v2_final_readiness_audit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real app files do not import the non-production navigator sink', () {
    for (final path in <String>[
      'lib/main.dart',
      'lib/navigation/app_router.dart',
      'lib/call_v2/integration/call_v2_app_integration.dart',
      'lib/call_v2/integration/disabled_call_v2_app_integration.dart',
      'lib/call_v2/integration/call_v2_route_registry.dart',
      'lib/call_v2/integration/disabled_call_v2_route_registry.dart',
      'lib/call_v2/production/call_v2_production_composition.dart',
      'lib/call_v2/startup/production_call_v2_startup_bridge.dart',
      'lib/call_v2/ui/production_call_v2_ui_coordinator.dart',
    ]) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final source = file.readAsStringSync();
      expect(
        source.contains('non_production_call_v2_navigator_route_sink'),
        isFalse,
        reason: path,
      );
      expect(
        source.contains('NonProductionCallV2NavigatorRouteSink'),
        isFalse,
        reason: path,
      );
    }
  });

  test('main router and app entry remain without Call V2 real route wiring',
      () {
    final sources = _readExisting(<String>[
      'lib/main.dart',
      'lib/navigation/app_router.dart',
    ]);

    expect(sources.contains('/call-v2/connecting'), isFalse);
    expect(sources.contains('/call-v2/ready'), isFalse);
    expect(sources.contains('/call-v2/unavailable'), isFalse);
    expect(sources.contains('NonProductionCallV2'), isFalse);
    expect(sources.contains('CallV2Runtime('), isFalse);
  });

  test('startup shell registry and production composition do not use sink', () {
    final sources = _readExisting(<String>[
      'lib/call_v2/integration/call_v2_app_integration.dart',
      'lib/call_v2/integration/disabled_call_v2_app_integration.dart',
      'lib/call_v2/integration/call_v2_route_registry.dart',
      'lib/call_v2/integration/disabled_call_v2_route_registry.dart',
      'lib/call_v2/production/call_v2_production_composition.dart',
    ]);

    expect(sources.contains('NonProductionCallV2NavigatorRouteSink'), isFalse);
    expect(sources.contains('navigatorKey'), isFalse);
    expect(sources.contains('MaterialApp('), isFalse);
    expect(sources.contains('onGenerateRoute'), isFalse);
  });

  test('rollout remains hard-disabled and actual readiness remains closed', () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);

    final auditor = const CallV2FinalReadinessAuditor();
    final result = auditor.audit(configuration: _productionConfig());
    final gate =
        auditor.evaluateRolloutGate(configuration: _productionConfig());

    expect(result.readyForProductionEnablement, isTrue);
    expect(result.readyForActualRollout, isFalse);
    expect(result.realRoutesWired, isFalse);
    expect(result.realScreensWired, isFalse);
    expect(gate.status, CallV2RolloutGateStatus.closed);
  });

  test('new widget harness tests do not import real app or production services',
      () {
    final sources = _readExisting(<String>[
      'test/call_v2/integration/non_production_call_v2_navigator_sink_test.dart',
      'test/call_v2/integration/non_production_call_v2_widget_harness_test.dart',
    ]);

    for (final forbidden in <String>[
      'package:connect_app/main.dart',
      'package:connect_app/navigation/app_router.dart',
      'firebase_core',
      'cloud_firestore',
      'firebase_auth',
      'permission_handler',
      'agora',
    ]) {
      expect(sources.contains(forbidden), isFalse, reason: forbidden);
    }
  });
}

String _readExisting(List<String> paths) {
  return paths
      .where((path) => File(path).existsSync())
      .map((path) => File(path).readAsStringSync())
      .join('\n');
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
