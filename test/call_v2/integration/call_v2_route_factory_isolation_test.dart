import 'dart:io';

import 'package:connect_app/call_v2/call_v2_runtime_configuration.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/production/call_v2_final_readiness_audit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('real app isolation', () {
    test(
        'real app files do not import isolated route factories or placeholders',
        () {
      final checked = <String, String>{
        'main.dart': _read('lib/main.dart'),
        'app_router.dart': _read('lib/navigation/app_router.dart'),
        'real registry': _read(
          'lib/call_v2/integration/call_v2_route_registry.dart',
        ),
        'disabled registry': _read(
          'lib/call_v2/integration/disabled_call_v2_route_registry.dart',
        ),
        'startup shell': _read(
          'lib/call_v2/integration/call_v2_app_integration.dart',
        ),
      };

      for (final entry in checked.entries) {
        expect(
          entry.value.contains('call_v2_route_factory'),
          isFalse,
          reason: entry.key,
        );
        expect(
          entry.value.contains('non_production_call_v2_route_factory'),
          isFalse,
          reason: entry.key,
        );
        expect(
          entry.value.contains('NonProductionCallV2'),
          isFalse,
          reason: entry.key,
        );
      }
    });

    test('main route table and onGenerateRoute do not expose placeholders', () {
      final main = _read('lib/main.dart');

      for (final forbidden in <String>[
        "'/call-v2/connecting'",
        "'/call-v2/ready'",
        "'/call-v2/unavailable'",
        'NonProductionCallV2',
        'CallV2RouteFactory',
        'CallV2RouteDestination',
      ]) {
        expect(main.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('hard-disabled registry remains null-returning and factory-free', () {
      final registry = _read(
        'lib/call_v2/integration/call_v2_route_registry.dart',
      );

      expect(registry, contains('if (!CallV2RolloutPolicy.productionEnabled)'));
      expect(registry, contains('return null;'));
      expect(registry.contains('CallV2RouteFactory'), isFalse);
      expect(registry.contains('NonProductionCallV2RouteFactory'), isFalse);
      expect(registry.contains('CallV2RouteDestination'), isFalse);
    });

    test('rollout flag remains false and startup shell remains hard-disabled',
        () {
      expect(CallV2RolloutPolicy.productionEnabled, isFalse);
      expect(
        _read('lib/call_v2/integration/call_v2_rollout_policy.dart'),
        contains('static const bool productionEnabled = false;'),
      );

      final appIntegration = _read(
        'lib/call_v2/integration/call_v2_app_integration.dart',
      );
      expect(appIntegration.contains('CallV2ProductionComposition'), isFalse);
      expect(appIntegration.contains('ProductionCallV2StartupBridge'), isFalse);
      expect(appIntegration.contains('ProductionCallV2UiCoordinator'), isFalse);
      expect(appIntegration.contains('CallV2Runtime('), isFalse);
    });

    test('no production composition or runtime path is introduced', () {
      final source = _isolatedRouteAndWiringSource();

      for (final forbidden in <String>[
        'NonProductionCallV2RouteFactory().create',
        'resolveCallV2Route(settings).create',
        'ProductionCallV2UiCoordinator(',
        'ProductionCallV2StartupBridge(',
        'CallV2ProductionComposition(',
        'CallV2Runtime(',
        'Permission.',
        'requestPermission',
        'FirebaseFirestore.instance',
        'RtcEngine',
        'RemoteConfig',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });
  });

  group('readiness regression', () {
    test('production enablement remains ready but actual rollout stays closed',
        () {
      final result = const CallV2FinalReadinessAuditor().audit(
        configuration: _productionConfig(),
      );
      final gate = const CallV2FinalReadinessAuditor().evaluateRolloutGate(
        configuration: _productionConfig(),
      );

      expect(result.readyForAdapterImplementation, isTrue);
      expect(result.readyForProductionEnablement, isTrue);
      expect(result.readyForActualRollout, isFalse);
      expect(result.realRoutesWired, isFalse);
      expect(result.realScreensWired, isFalse);
      expect(gate.status, CallV2RolloutGateStatus.closed);
    });

    test('non-production placeholders do not count as real screens', () {
      final audit = _read(
        'lib/call_v2/production/call_v2_final_readiness_audit.dart',
      );

      expect(audit.contains('NonProductionCallV2'), isFalse);
      expect(audit.contains('call_v2/integration/non_production'), isFalse);
    });
  });
}

String _isolatedRouteAndWiringSource() {
  return <String>[
    'lib/call_v2/integration/call_v2_route_registry.dart',
    'lib/call_v2/integration/disabled_call_v2_route_registry.dart',
    'lib/call_v2/integration/call_v2_app_integration.dart',
    'lib/call_v2/integration/call_v2_route_factory.dart',
    'lib/call_v2/integration/non_production_call_v2_route_factory.dart',
  ].map(_read).join('\n');
}

String _read(String path) => File(path).readAsStringSync();

CallV2RuntimeConfiguration _productionConfig() {
  return CallV2RuntimeConfiguration(
    enabled: true,
    environment: CallV2Environment.production,
    rtcProvider: CallV2RtcProviderKind.agora,
    rtcAppIdReference: 'CALL_V2_AGORA_APP_ID_REFERENCE',
    callCollectionName: 'calls',
    participantSubcollectionName: 'participants',
    rtcTokenMaxLifetime: callV2AcceptedRtcTokenMaxLifetime,
    minimumTokenRemainingValidity: const Duration(seconds: 60),
  );
}
