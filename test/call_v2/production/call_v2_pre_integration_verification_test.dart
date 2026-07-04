import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/call_v2_runtime_configuration.dart';
import 'package:connect_app/call_v2/production/call_v2_final_readiness_audit.dart';
import 'package:connect_app/call_v2/production/call_v2_pre_integration_gate.dart';
import 'package:connect_app/call_v2/production/call_v2_production_integration_approval.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pre-integration gate current state', () {
    test('default gate is structurally ready but approval blocked', () {
      final result = const CallV2PreIntegrationGate().evaluate();

      expect(result.phase3ContractAccepted, isTrue);
      expect(result.productionAdaptersReady, isTrue);
      expect(result.startupBoundaryReady, isTrue);
      expect(result.uiBoundaryReady, isTrue);
      expect(result.observabilityBoundaryReady, isTrue);
      expect(result.hardDisabledStartupShellPresent, isTrue);
      expect(result.hardDisabledRouteRegistryPresent, isTrue);
      expect(result.isolatedRouteFactoryVerified, isTrue);
      expect(result.isolatedPresentationAdapterVerified, isTrue);
      expect(result.isolatedIntegrationHarnessVerified, isTrue);
      expect(result.isolatedWidgetHarnessVerified, isTrue);
      expect(result.structurallyReady, isTrue);
      expect(result.approvalsComplete, isFalse);
      expect(result.status, CallV2ProductionIntegrationGateStatus.blocked);
    });

    test('default gate keeps actual integration and rollout unauthorized', () {
      final result = const CallV2PreIntegrationGate().evaluate();

      expect(result.rolloutFlagDisabled, isTrue);
      expect(result.realStartupIntegrationAbsent, isTrue);
      expect(result.realRouteDestinationAbsent, isTrue);
      expect(result.productionScreenAbsent, isTrue);
      expect(result.productionRouteSinkAbsent, isTrue);
      expect(result.runtimeStartupAbsent, isTrue);
      expect(result.actualIntegrationAuthorized, isFalse);
      expect(result.rolloutAuthorized, isFalse);
    });

    test('default blockers are fixed enum values only', () {
      final result = const CallV2PreIntegrationGate().evaluate();

      expect(
        result.blockers,
        containsAll(<CallV2ProductionIntegrationGateBlocker>[
          CallV2ProductionIntegrationGateBlocker.architectureReviewMissing,
          CallV2ProductionIntegrationGateBlocker.securityReviewMissing,
          CallV2ProductionIntegrationGateBlocker.privacyReviewMissing,
          CallV2ProductionIntegrationGateBlocker.backendDeploymentMissing,
          CallV2ProductionIntegrationGateBlocker
              .firestoreRulesDeploymentMissing,
          CallV2ProductionIntegrationGateBlocker.callableDeploymentMissing,
          CallV2ProductionIntegrationGateBlocker.appCheckEnforcementMissing,
          CallV2ProductionIntegrationGateBlocker
              .rtcProductionConfigurationMissing,
          CallV2ProductionIntegrationGateBlocker.iosPermissionsMissing,
          CallV2ProductionIntegrationGateBlocker.androidPermissionsMissing,
          CallV2ProductionIntegrationGateBlocker.productionObservabilityMissing,
          CallV2ProductionIntegrationGateBlocker.smokePlanMissing,
          CallV2ProductionIntegrationGateBlocker.rollbackDrillMissing,
          CallV2ProductionIntegrationGateBlocker.productApprovalMissing,
          CallV2ProductionIntegrationGateBlocker.engineeringApprovalMissing,
          CallV2ProductionIntegrationGateBlocker.releaseApprovalMissing,
          CallV2ProductionIntegrationGateBlocker.limitedRolloutApprovalMissing,
        ]),
      );
      expect(
        result.blockers.length,
        17,
      );
    });
  });

  group('full approval simulation', () {
    test('can approve pre-integration without changing runtime reachability',
        () {
      final beforeFlag = CallV2RolloutPolicy.productionEnabled;

      final result = const CallV2PreIntegrationGate().evaluate(
        approval: const CallV2ProductionIntegrationApproval.fullyApproved(),
      );

      expect(result.status, CallV2ProductionIntegrationGateStatus.approved);
      expect(result.approvalsComplete, isTrue);
      expect(result.blockers, isEmpty);
      expect(CallV2RolloutPolicy.productionEnabled, beforeFlag);
      expect(CallV2RolloutPolicy.productionEnabled, isFalse);
      expect(result.actualIntegrationAuthorized, isFalse);
      expect(result.rolloutAuthorized, isFalse);
      expect(result.realStartupIntegrationAbsent, isTrue);
      expect(result.realRouteDestinationAbsent, isTrue);
      expect(result.productionScreenAbsent, isTrue);
      expect(result.productionRouteSinkAbsent, isTrue);
      expect(result.runtimeStartupAbsent, isTrue);
    });

    test('final rollout auditor remains closed after approval simulation', () {
      final gate = const CallV2PreIntegrationGate().evaluate(
        approval: const CallV2ProductionIntegrationApproval.fullyApproved(),
      );
      final rolloutGate =
          const CallV2FinalReadinessAuditor().evaluateRolloutGate(
        configuration: _productionConfig(),
      );
      final audit = const CallV2FinalReadinessAuditor().audit(
        configuration: _productionConfig(),
      );

      expect(gate.status, CallV2ProductionIntegrationGateStatus.approved);
      expect(rolloutGate.status, CallV2RolloutGateStatus.closed);
      expect(audit.readyForActualRollout, isFalse);
      expect(audit.appStartupWired, isFalse);
      expect(audit.realRoutesWired, isFalse);
      expect(audit.realScreensWired, isFalse);
      expect(audit.productionTelemetryWired, isFalse);
      expect(audit.deploymentPerformed, isFalse);
    });
  });

  group('production integration absence', () {
    test(
        'main references disabled shell and null-returning route registry only',
        () {
      final main = _read('lib/main.dart');
      final appIntegration = _read(
        'lib/call_v2/integration/call_v2_app_integration.dart',
      );
      final routeRegistry = _read(
        'lib/call_v2/integration/call_v2_route_registry.dart',
      );

      expect(
        main,
        contains('unawaited(initializeCallV2AppIntegrationShellSafely());'),
      );
      expect(main, contains('resolveCallV2Route(settings)'));
      expect(
        appIntegration,
        contains('if (!CallV2RolloutPolicy.productionEnabled) return;'),
      );
      expect(
        routeRegistry,
        contains('if (!CallV2RolloutPolicy.productionEnabled) return null;'),
      );
      expect(main.contains('runtime.start'), isFalse);
      expect(main.contains('CallV2ProductionComposition'), isFalse);
      expect(main.contains('ProductionCallV2StartupBridge'), isFalse);
    });

    test('no production route factory, adapter, sink, or screen is registered',
        () {
      final productionSources = _productionSources();
      final main = _read('lib/main.dart');

      for (final forbidden in <String>[
        'ProductionCallV2RouteFactory',
        'ProductionCallV2PresentationAdapter',
        'ProductionCallV2NavigatorRouteSink',
        'CallV2Screen',
        'IncomingCallV2',
        'ActiveCallV2',
      ]) {
        expect(main.contains(forbidden), isFalse, reason: forbidden);
        expect(productionSources.contains(forbidden), isFalse,
            reason: forbidden);
      }
    });

    test('non-production placeholders remain isolated test-only support', () {
      final routeFactory = _read(
        'lib/call_v2/integration/non_production_call_v2_route_factory.dart',
      );
      final main = _read('lib/main.dart');
      final registry = _read(
        'lib/call_v2/integration/call_v2_route_registry.dart',
      );

      expect(routeFactory, contains('NonProductionCallV2'));
      expect(main.contains('NonProductionCallV2'), isFalse);
      expect(registry.contains('NonProductionCallV2'), isFalse);
    });
  });

  group('purity and side-effect boundaries', () {
    test('gate source has no service, route, widget, or platform access', () {
      final source = _read(
        'lib/call_v2/production/call_v2_pre_integration_gate.dart',
      );

      for (final forbidden in <String>[
        'Firebase',
        'Firestore',
        "package:firebase_auth",
        'AppCheck',
        'Permission.',
        "package:permission",
        'RtcEngine',
        'Navigator.',
        'Navigator(',
        'Route(',
        ' Widget ',
        'StatelessWidget',
        'StatefulWidget',
        'BuildContext',
        'Platform.environment',
        'String.fromEnvironment',
        'RemoteConfig',
        'Analytics',
        'Crashlytics',
        'Sentry',
        'File(',
        'HttpClient',
        'DateTime.now',
        'print(',
        'debugPrint',
        'runtime.start',
        'deploy',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('gate result exposes only booleans, enums, and enum blocker names',
        () {
      final result = const CallV2PreIntegrationGate().evaluate();
      final debug = result.toSafeDebugMap();

      expect(
        debug.values,
        everyElement(anyOf(isA<bool>(), isA<String>(), isA<List<String>>())),
      );
      for (final forbidden in <String>[
        '@',
        'http://',
        'https://',
        'secret',
        'token',
        'credential',
        'uid',
      ]) {
        expect(debug.toString().toLowerCase().contains(forbidden), isFalse);
      }
    });

    test('new production gate files do not import Flutter or Firebase packages',
        () {
      final source = <String>[
        _read('lib/call_v2/production/call_v2_pre_integration_gate.dart'),
        _read(
          'lib/call_v2/production/'
          'call_v2_production_integration_approval.dart',
        ),
        _read(
          'lib/call_v2/production/call_v2_production_integration_plan.dart',
        ),
      ].join('\n');

      for (final forbidden in <String>[
        "package:flutter",
        "package:firebase",
        "package:cloud_",
        "package:permission",
        "package:agora",
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });
  });
}

String _read(String path) => File(path).readAsStringSync();

String _productionSources() {
  final directory = Directory('lib/call_v2/production');
  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .map((file) => file.readAsStringSync())
      .join('\n');
}

CallV2RuntimeConfiguration _productionConfig() {
  return const CallV2RuntimeConfiguration(
    enabled: true,
    environment: CallV2Environment.production,
    rtcProvider: CallV2RtcProviderKind.agora,
    rtcAppIdReference: 'CALL_V2_AGORA_APP_ID_REFERENCE',
    callCollectionName: 'calls',
    participantSubcollectionName: 'participants',
    rtcTokenMaxLifetime: callV2AcceptedRtcTokenMaxLifetime,
    minimumTokenRemainingValidity: Duration(seconds: 60),
  );
}
