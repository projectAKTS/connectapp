import 'dart:io';

import 'package:connect_app/call_v2/call_v2_runtime_configuration.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/production/call_v2_final_readiness_audit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('source isolation', () {
    test('adapter sources have no real navigation or live services', () {
      final source = _adapterSource();

      for (final forbidden in <String>[
        'Navigator',
        'NavigatorState',
        'BuildContext',
        'navigatorKey',
        'GlobalKey',
        'GetIt',
        'Provider<',
        'Firebase',
        'Permission',
        'Rtc',
        'Agora',
        'CallV2ProductionComposition',
        'ProductionCallV2StartupBridge',
        'ProductionCallV2UiCoordinator',
        'CallV2Runtime(',
        'StreamSubscription',
        '.listen(',
        'Timer(',
        'debugPrint',
        'print(',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('adapter consumes intents and abstract factory/sink only', () {
      final source = _adapterSource();

      expect(source, contains('CallV2RouteIntent'));
      expect(source, contains('CallV2RouteFactory'));
      expect(source, contains('CallV2RouteSink'));
      expect(source, contains('CallV2RouteDestination.connecting'));
      expect(source, contains('CallV2RouteDestination.ready'));
      expect(source, contains('CallV2RouteDestination.controlledFailure'));

      for (final forbidden in <String>[
        'CallV2UiLaunchRequest',
        'CallV2StartupRequest',
        'callId',
        'uid',
        'participant',
        'settings.arguments',
        'as Map',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });
  });

  group('real app isolation', () {
    test('real app files do not import adapter, sink, factory, or placeholders',
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
        for (final forbidden in <String>[
          'call_v2_presentation_adapter',
          'call_v2_route_sink',
          'call_v2_route_factory',
          'non_production_call_v2',
          'NonProductionCallV2',
        ]) {
          expect(
            entry.value.contains(forbidden),
            isFalse,
            reason: '${entry.key}: $forbidden',
          );
        }
      }
    });

    test('UI coordinator keeps abstract-intent dependency direction', () {
      final source =
          _read('lib/call_v2/ui/production_call_v2_ui_coordinator.dart');

      expect(source, contains('CallV2RouteIntent'));
      for (final forbidden in <String>[
        'Route<dynamic>',
        'MaterialPageRoute',
        'CallV2RouteFactory',
        'CallV2PresentationAdapter',
        'CallV2RouteSink',
        'Navigator',
        'BuildContext',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('MaterialApp route wiring remains unchanged and unreachable', () {
      final main = _read('lib/main.dart');

      for (final forbidden in <String>[
        "'/call-v2/connecting'",
        "'/call-v2/ready'",
        "'/call-v2/unavailable'",
        'CallV2PresentationAdapter',
        'CallV2RouteSink',
        'NonProductionCallV2PresentationAdapter',
        'NonProductionCallV2',
      ]) {
        expect(main.contains(forbidden), isFalse, reason: forbidden);
      }
    });
  });

  group('readiness regression', () {
    test(
        'rollout remains disabled and production readiness gate remains closed',
        () {
      expect(CallV2RolloutPolicy.productionEnabled, isFalse);
      expect(
        _read('lib/call_v2/integration/call_v2_rollout_policy.dart'),
        contains('static const bool productionEnabled = false;'),
      );

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
  });
}

String _adapterSource() {
  return <String>[
    'lib/call_v2/integration/call_v2_route_sink.dart',
    'lib/call_v2/integration/call_v2_presentation_adapter.dart',
    'lib/call_v2/integration/non_production_call_v2_presentation_adapter.dart',
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
