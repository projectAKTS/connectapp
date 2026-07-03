import 'dart:io';

import 'package:connect_app/call_v2/call_v2_contract_manifest.dart';
import 'package:connect_app/call_v2/call_v2_production_capabilities.dart';
import 'package:connect_app/call_v2/call_v2_production_readiness.dart';
import 'package:connect_app/call_v2/call_v2_runtime_configuration.dart';
import 'package:connect_app/call_v2/observability/call_v2_observability_capabilities.dart';
import 'package:connect_app/call_v2/production/call_v2_controlled_integration_plan.dart';
import 'package:connect_app/call_v2/production/call_v2_final_readiness_audit.dart';
import 'package:connect_app/call_v2/production/call_v2_production_composition.dart';
import 'package:connect_app/call_v2/startup/production_call_v2_startup_bridge.dart';
import 'package:connect_app/call_v2/ui/call_v2_ui_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('construction and purity', () {
    test('audit constructor and execution have no side effects', () {
      const auditor = CallV2FinalReadinessAuditor();

      final result = auditor.audit(configuration: _productionConfig());
      final gate = auditor.evaluateRolloutGate(
        configuration: _productionConfig(),
      );

      expect(result.readyForAdapterImplementation, isTrue);
      expect(gate.status, CallV2RolloutGateStatus.closed);
    });

    test('final audit sources access no Firebase, RTC, routes, or telemetry',
        () {
      final source = _finalAuditSource();

      for (final forbidden in <String>[
        "package:firebase",
        'FirebaseFirestore',
        'FirebaseAuth',
        'FirebaseAppCheck',
        'Permission.',
        'requestPermission',
        'RtcEngine',
        'RtcAdapter',
        'runtime.start',
        'Navigator',
        'BuildContext',
        'FirebaseAnalytics',
        'FirebaseCrashlytics',
        'Sentry',
        'Platform.environment',
        'String.fromEnvironment',
        'Secret',
        'secret',
        'File(',
        'HttpClient',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });
  });

  group('readiness levels', () {
    test('adapter implementation and production enablement are ready', () {
      final result = _audit(configuration: _productionConfig());

      expect(result.readyForAdapterImplementation, isTrue);
      expect(result.readyForProductionEnablement, isTrue);
      expect(result.readyForActualRollout, isFalse);
    });

    test('actual rollout does not become true merely because auditor passes',
        () {
      final readiness = const CallV2ProductionReadinessAuditor().audit(
        manifest: callV2Phase3ContractManifest,
        configuration: _productionConfig(),
        capabilities: callV2IsolatedObservabilityCapabilities,
      );
      final result = _audit(configuration: _productionConfig());

      expect(readiness.readyForProductionEnablement, isTrue);
      expect(result.readyForActualRollout, isFalse);
    });

    test('disabled config remains not production-enabled', () {
      final result = _audit(configuration: callV2DefaultRuntimeConfiguration);

      expect(result.readyForAdapterImplementation, isTrue);
      expect(result.readyForProductionEnablement, isFalse);
      expect(result.readyForActualRollout, isFalse);
    });

    test('invalid config remains rejected', () {
      final result = _audit(
        configuration: _productionConfig(callCollectionName: ''),
      );

      expect(result.readyForAdapterImplementation, isFalse);
      expect(result.readyForProductionEnablement, isFalse);
    });

    test('fake and none RTC providers remain rejected for production', () {
      for (final provider in <CallV2RtcProviderKind>[
        CallV2RtcProviderKind.fake,
        CallV2RtcProviderKind.none,
      ]) {
        final result = _audit(
          configuration: _productionConfig(
            rtcProvider: provider,
            rtcAppIdReference: '',
          ),
        );

        expect(result.readyForProductionEnablement, isFalse);
      }
    });

    test('frozen manifest remains authoritative', () {
      final result = _audit(
        configuration: _productionConfig(),
        manifest: _manifest(version: CallV2ContractVersion.unsupported),
      );

      expect(result.contractManifestAccepted, isFalse);
      expect(result.readyForAdapterImplementation, isFalse);
    });
  });

  group('capability audit', () {
    test('accepted Phase 4 capabilities are all present except native calls',
        () {
      final result = _audit(configuration: _productionConfig());

      expect(result.callableAdapterAvailable, isTrue);
      expect(result.firestoreSourceAvailable, isTrue);
      expect(result.rtcCredentialProviderAvailable, isTrue);
      expect(result.rtcAdapterAvailable, isTrue);
      expect(result.authIdentityAvailable, isTrue);
      expect(result.appCheckAvailable, isTrue);
      expect(result.permissionGatewayAvailable, isTrue);
      expect(result.startupBridgeAvailable, isTrue);
      expect(result.uiRouteContractAvailable, isTrue);
      expect(result.observabilityAvailable, isTrue);
      expect(result.nativeCallIntegrationAvailable, isFalse);
    });

    test(
        'existing capability constants and global no-capabilities are unchanged',
        () {
      expect(
        callV2IsolatedStartupBridgeCapabilities.uiRouteIntegrationAvailable,
        isFalse,
      );
      expect(
        callV2IsolatedStartupBridgeCapabilities.observabilityAvailable,
        isFalse,
      );
      expect(
        callV2IsolatedUiRouteIntegrationCapabilities.observabilityAvailable,
        isFalse,
      );
      expect(
        callV2IsolatedProductionCompositionCapabilities
            .runtimeStartupBridgeAvailable,
        isFalse,
      );
      expect(
        callV2IsolatedProductionCompositionCapabilities
            .uiRouteIntegrationAvailable,
        isFalse,
      );
      expect(
        callV2IsolatedProductionCompositionCapabilities.observabilityAvailable,
        isFalse,
      );
      expect(
        callV2NoProductionCapabilities.toSafeDebugMap().values,
        everyElement(false),
      );
    });
  });

  group('real wiring absence', () {
    test('main, routes, screens, and services remain unwired', () {
      _expectFileDoesNotContain('lib/main.dart', <String>[
        'call_v2/production',
        'call_v2/startup',
        'CallV2ProductionComposition',
        'ProductionCallV2StartupBridge',
      ]);
      _expectOptionalFileDoesNotContain(
          'lib/navigation/app_router.dart', <String>[
        'call_v2',
        'CallV2',
      ]);
      _expectDirectoryDoesNotContain('lib/screens', <String>[
        'call_v2/production',
        'call_v2/startup',
        'CallV2ProductionComposition',
        'ProductionCallV2StartupBridge',
      ]);
      _expectDirectoryDoesNotContain('lib/services', <String>[
        'call_v2/production',
        'call_v2/startup',
        'CallV2ProductionComposition',
        'ProductionCallV2StartupBridge',
      ]);
    });

    test(
        'external telemetry, production screens, startup, and deployment absent',
        () {
      final result = _audit(configuration: _productionConfig());

      expect(result.appStartupWired, isFalse);
      expect(result.realRoutesWired, isFalse);
      expect(result.realScreensWired, isFalse);
      expect(result.productionTelemetryWired, isFalse);
      expect(result.deploymentPerformed, isFalse);
      expect(result.defaultRolloutEnabled, isFalse);
      for (final forbidden in <String>[
        'FirebaseAnalytics',
        'FirebaseCrashlytics',
        'Sentry',
      ]) {
        expect(_finalAuditSource().contains(forbidden), isFalse);
      }
    });
  });

  group('integration plan', () {
    test('plan contains all required typed steps exactly once', () {
      expect(
        callV2ControlledIntegrationPlan.items.map((item) => item.step).toSet(),
        CallV2IntegrationStep.values.toSet(),
      );
      expect(
        callV2ControlledIntegrationPlan.items,
        hasLength(CallV2IntegrationStep.values.length),
      );
    });

    test('real wiring, release, and rollout steps are not completed', () {
      for (final step in <CallV2IntegrationStep>[
        CallV2IntegrationStep.wireCompositionAtStartup,
        CallV2IntegrationStep.registerCallRoutes,
        CallV2IntegrationStep.addCallScreens,
        CallV2IntegrationStep.connectSafeObservabilitySink,
        CallV2IntegrationStep.obtainReleaseApproval,
        CallV2IntegrationStep.enableLimitedRollout,
      ]) {
        expect(
          callV2ControlledIntegrationPlan.statusFor(step),
          isNot(CallV2IntegrationStepStatus.completed),
        );
      }
    });

    test('plan debug representation is safe and enum-derived', () {
      final debug = callV2ControlledIntegrationPlan.toSafeDebugMap();
      final text = debug.toString();

      expect(text, contains('wireCompositionAtStartup'));
      _expectNoSensitiveContent(text);
    });

    test('plan does not accept arbitrary string step names', () {
      final source = File(
        'lib/call_v2/production/call_v2_controlled_integration_plan.dart',
      ).readAsStringSync();

      expect(source.contains('final String'), isFalse);
      expect(source.contains('Map<String, dynamic>'), isFalse);
    });
  });

  group('rollout gate', () {
    test('gate remains closed and cannot enable rollout or mutate config', () {
      const auditor = CallV2FinalReadinessAuditor();
      final config = _productionConfig();

      final gate = auditor.evaluateRolloutGate(configuration: config);

      expect(gate.status, CallV2RolloutGateStatus.closed);
      expect(gate.isOpen, isFalse);
      expect(config.enabled, isTrue);
      expect(_audit(configuration: config).defaultRolloutEnabled, isFalse);
    });

    test('missing rollout prerequisites block gate independently', () {
      final baseline = const CallV2ActualRolloutPrerequisites(
        appStartupWired: true,
        realRoutesWired: true,
        realScreensWired: true,
        productionTelemetryWired: true,
        releaseConfigurationReviewed: true,
        rolloutOwnerApproved: true,
        rollbackPlanApproved: true,
        productionSmokeTestPlanApproved: true,
        deploymentApproved: true,
        platformPermissionDeclarationsConfirmed: true,
        backendDeploymentConfirmed: true,
        appCheckEnforcementConfirmed: true,
      );

      expect(_gate(baseline).status, CallV2RolloutGateStatus.open);
      expect(
        _gate(const CallV2ActualRolloutPrerequisites()).status,
        CallV2RolloutGateStatus.closed,
      );
      expect(
        _gate(const CallV2ActualRolloutPrerequisites(
          realRoutesWired: true,
          realScreensWired: true,
          productionTelemetryWired: true,
          releaseConfigurationReviewed: true,
          rolloutOwnerApproved: true,
          rollbackPlanApproved: true,
          productionSmokeTestPlanApproved: true,
          deploymentApproved: true,
          platformPermissionDeclarationsConfirmed: true,
          backendDeploymentConfirmed: true,
          appCheckEnforcementConfirmed: true,
        )).startupIntegrationConfirmed,
        isFalse,
      );
      expect(
        _gate(const CallV2ActualRolloutPrerequisites(
          appStartupWired: true,
          realScreensWired: true,
          productionTelemetryWired: true,
          releaseConfigurationReviewed: true,
          rolloutOwnerApproved: true,
          rollbackPlanApproved: true,
          productionSmokeTestPlanApproved: true,
          deploymentApproved: true,
          platformPermissionDeclarationsConfirmed: true,
          backendDeploymentConfirmed: true,
          appCheckEnforcementConfirmed: true,
        )).routeIntegrationConfirmed,
        isFalse,
      );
      expect(
        _gate(const CallV2ActualRolloutPrerequisites(
          appStartupWired: true,
          realRoutesWired: true,
          productionTelemetryWired: true,
          releaseConfigurationReviewed: true,
          rolloutOwnerApproved: true,
          rollbackPlanApproved: true,
          productionSmokeTestPlanApproved: true,
          deploymentApproved: true,
          platformPermissionDeclarationsConfirmed: true,
          backendDeploymentConfirmed: true,
          appCheckEnforcementConfirmed: true,
        )).screenIntegrationConfirmed,
        isFalse,
      );
      expect(
        _gate(const CallV2ActualRolloutPrerequisites(
          appStartupWired: true,
          realRoutesWired: true,
          realScreensWired: true,
          releaseConfigurationReviewed: true,
          rolloutOwnerApproved: true,
          rollbackPlanApproved: true,
          productionSmokeTestPlanApproved: true,
          deploymentApproved: true,
          platformPermissionDeclarationsConfirmed: true,
          backendDeploymentConfirmed: true,
          appCheckEnforcementConfirmed: true,
        )).productionObservabilitySinkConfirmed,
        isFalse,
      );
      expect(
        _gate(const CallV2ActualRolloutPrerequisites(
          appStartupWired: true,
          realRoutesWired: true,
          realScreensWired: true,
          productionTelemetryWired: true,
          rollbackPlanApproved: true,
          productionSmokeTestPlanApproved: true,
          platformPermissionDeclarationsConfirmed: true,
          backendDeploymentConfirmed: true,
          appCheckEnforcementConfirmed: true,
        )).releaseApprovalConfirmed,
        isFalse,
      );
    });

    test('gate debug representation contains booleans and enums only', () {
      final debug = const CallV2FinalReadinessAuditor()
          .evaluateRolloutGate(configuration: _productionConfig())
          .toSafeDebugMap();

      expect(
        debug.values,
        everyElement(anyOf(isA<bool>(), isA<String>())),
      );
      _expectNoSensitiveContent(debug.toString());
    });
  });

  group('rollback plan', () {
    test('rollback plan is declarative and preserves V1 fallback', () {
      const plan = CallV2RollbackPlan();

      expect(plan.featureGateDisableAvailable, isTrue);
      expect(plan.startupBridgeRemovalAvailable, isTrue);
      expect(plan.routeRemovalAvailable, isTrue);
      expect(plan.v1FallbackPreserved, isTrue);
      expect(plan.backendCompatibilityPreserved, isTrue);
      expect(plan.dataMigrationRequired, isFalse);
      expect(plan.destructiveRollbackRequired, isFalse);
      _expectNoSensitiveContent(plan.toString());
    });

    test('rollback plan does not execute actions', () {
      final source = File(
        'lib/call_v2/production/call_v2_final_readiness_audit.dart',
      ).readAsStringSync();

      for (final forbidden in <String>[
        'delete',
        'removeRoute',
        'Firebase',
        'Navigator',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });
  });
}

CallV2FinalReadinessAuditResult _audit({
  required CallV2RuntimeConfiguration configuration,
  CallV2ContractManifest manifest = callV2Phase3ContractManifest,
  CallV2ProductionCapabilities capabilities =
      callV2IsolatedObservabilityCapabilities,
}) {
  return const CallV2FinalReadinessAuditor().audit(
    manifest: manifest,
    configuration: configuration,
    capabilities: capabilities,
  );
}

CallV2RolloutGateResult _gate(CallV2ActualRolloutPrerequisites prerequisites) {
  return const CallV2FinalReadinessAuditor().evaluateRolloutGate(
    configuration: _productionConfig(),
    actualRolloutPrerequisites: prerequisites,
  );
}

CallV2RuntimeConfiguration _productionConfig({
  CallV2RtcProviderKind rtcProvider = CallV2RtcProviderKind.agora,
  String rtcAppIdReference = 'CALL_V2_AGORA_APP_ID_REFERENCE',
  String callCollectionName = 'calls',
}) {
  return CallV2RuntimeConfiguration(
    enabled: true,
    environment: CallV2Environment.production,
    rtcProvider: rtcProvider,
    rtcAppIdReference: rtcAppIdReference,
    callCollectionName: callCollectionName,
    participantSubcollectionName: 'participants',
    rtcTokenMaxLifetime: callV2AcceptedRtcTokenMaxLifetime,
    minimumTokenRemainingValidity: const Duration(seconds: 60),
  );
}

CallV2ContractManifest _manifest({
  CallV2ContractVersion version = CallV2ContractVersion.v2Phase3,
}) {
  return CallV2ContractManifest(
    version: version,
    featureGateDefaultsDisabled: true,
    runtimeConstructionSideEffectFree: true,
    runtimeStartDoesNotStartMedia: true,
    lifecycleSnapshotAuthoritative: true,
    subscriptionCoordinatorOwnsFirestoreSubscriptionFlow: true,
    runtimeOwnsTopLevelStartStopSequencing: true,
    orchestratorOwnsSnapshotToMediaSequencing: true,
    resolverOwnsConfigResolution: true,
    mediaControllerOwnsRtcAdapterCalls: true,
    terminalSnapshotOwnsMediaCleanup: true,
    duplicateOperationsShareInFlightWork: true,
    generationAndOperationIdentityProtectStaleCompletion: true,
    rawCredentialsNeverAppearInPublicState: true,
    productionAdaptersAbsent: true,
    startupUiRoutesNativeWiringAbsent: true,
    allowedDependencyEdges: callV2AllowedDependencyEdges,
    forbiddenDependencyEdges: callV2ForbiddenDependencyEdges,
  );
}

String _finalAuditSource() {
  return <String>[
    File('lib/call_v2/production/call_v2_final_readiness_audit.dart')
        .readAsStringSync(),
    File('lib/call_v2/production/call_v2_controlled_integration_plan.dart')
        .readAsStringSync(),
  ].join('\n');
}

void _expectFileDoesNotContain(String path, List<String> forbiddenValues) {
  final source = File(path).readAsStringSync();
  for (final forbidden in forbiddenValues) {
    expect(source.contains(forbidden), isFalse, reason: '$path $forbidden');
  }
}

void _expectOptionalFileDoesNotContain(
  String path,
  List<String> forbiddenValues,
) {
  final file = File(path);
  if (!file.existsSync()) return;
  _expectFileDoesNotContain(path, forbiddenValues);
}

void _expectDirectoryDoesNotContain(
  String path,
  List<String> forbiddenValues,
) {
  final directory = Directory(path);
  if (!directory.existsSync()) return;
  final source = directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.readAsStringSync())
      .join('\n');
  for (final forbidden in forbiddenValues) {
    expect(source.contains(forbidden), isFalse, reason: '$path $forbidden');
  }
}

void _expectNoSensitiveContent(String text) {
  for (final forbidden in <String>[
    'uid',
    'callId',
    'token',
    'project',
    'secret',
    'calls/',
    'FirebaseException',
    'StackTrace',
  ]) {
    expect(text, isNot(contains(forbidden)), reason: forbidden);
  }
}
