import 'dart:io';

import 'package:connect_app/call_v2/design/call_v2_production_lifecycle_observer_design.dart';
import 'package:connect_app/call_v2/design/call_v2_production_navigator_wiring_design.dart';
import 'package:connect_app/call_v2/design/call_v2_production_route_registration_design.dart';
import 'package:connect_app/call_v2/design/call_v2_production_runtime_startup_design.dart';
import 'package:connect_app/call_v2/design/call_v2_production_staged_rollout_design.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final design = callV2ProductionRuntimeStartupDesign;

  test('design records current runtime startup status as disabled', () {
    expect(design.isRuntimeStartupImplemented, isFalse);
    expect(design.isRuntimeStarted, isFalse);
    expect(design.isRolloutEnabled, isFalse);
    expect(design.isCallV2Reachable, isFalse);
    expect(design.isDeploymentAuthorized, isFalse);
    expect(design.allowsAutomaticWiring, isFalse);
    expect(
      design.currentStatus,
      containsAll(<Object>[
        CallV2ProductionRuntimeStartupStatus.noRealRuntimeStartupImplemented,
        CallV2ProductionRuntimeStartupStatus
            .runtimeNotConstructedFromAppStartup,
        CallV2ProductionRuntimeStartupStatus.runtimeNotStarted,
        CallV2ProductionRuntimeStartupStatus
            .productionCompositionNotConstructedFromStartup,
        CallV2ProductionRuntimeStartupStatus.rolloutFalse,
        CallV2ProductionRuntimeStartupStatus.routeRegistryDisabled,
        CallV2ProductionRuntimeStartupStatus.callV2Unreachable,
        CallV2ProductionRuntimeStartupStatus.backendFirebaseDisconnected,
        CallV2ProductionRuntimeStartupStatus.rtcDisconnected,
        CallV2ProductionRuntimeStartupStatus.permissionsDisconnected,
        CallV2ProductionRuntimeStartupStatus.deploymentNotAuthorized,
      ]),
    );
  });

  test('design lists allowed future locations only after approval', () {
    expect(
      design.allowedFutureLocations,
      <CallV2ProductionRuntimeStartupAllowedLocation>[
        CallV2ProductionRuntimeStartupAllowedLocation
            .isolatedCallV2ProductionIntegrationOwner,
        CallV2ProductionRuntimeStartupAllowedLocation
            .isolatedAppStartupBoundaryOnlyIfApproved,
        CallV2ProductionRuntimeStartupAllowedLocation
            .developerOnlyRuntimeStartupPrOnly,
      ],
    );
  });

  test('design forbids unsafe startup locations', () {
    expect(
      design.forbiddenLocations,
      containsAll(<Object>[
        CallV2ProductionRuntimeStartupForbiddenLocation
            .mainDartDirectRuntimeConstruction,
        CallV2ProductionRuntimeStartupForbiddenLocation.appRouter,
        CallV2ProductionRuntimeStartupForbiddenLocation.routeRegistry,
        CallV2ProductionRuntimeStartupForbiddenLocation
            .lifecycleEventHandlerAlone,
        CallV2ProductionRuntimeStartupForbiddenLocation.v1Files,
      ]),
    );
  });

  test('design forbids runtime service and wiring actions', () {
    expect(
      design.forbiddenActions,
      containsAll(<Object>[
        CallV2ProductionRuntimeStartupForbiddenAction.modifyMainDart,
        CallV2ProductionRuntimeStartupForbiddenAction.modifyAppStartup,
        CallV2ProductionRuntimeStartupForbiddenAction.modifyAppRouter,
        CallV2ProductionRuntimeStartupForbiddenAction
            .modifyRouteRegistryToStartRuntime,
        CallV2ProductionRuntimeStartupForbiddenAction
            .constructProductionCompositionFromStartup,
        CallV2ProductionRuntimeStartupForbiddenAction.startRuntime,
        CallV2ProductionRuntimeStartupForbiddenAction.startRtc,
        CallV2ProductionRuntimeStartupForbiddenAction.requestPermissions,
        CallV2ProductionRuntimeStartupForbiddenAction
            .openBackendFirebaseListeners,
        CallV2ProductionRuntimeStartupForbiddenAction.changeRolloutFlag,
        CallV2ProductionRuntimeStartupForbiddenAction.registerRoutes,
        CallV2ProductionRuntimeStartupForbiddenAction.addNavigationWiring,
        CallV2ProductionRuntimeStartupForbiddenAction.deploy,
      ]),
    );
  });

  test('design lists runtime startup safety rules', () {
    expect(
      design.safetyRules,
      containsAll(<Object>[
        CallV2ProductionRuntimeStartupSafetyRule.explicitHumanApprovalRequired,
        CallV2ProductionRuntimeStartupSafetyRule.developerOnlyGateRequired,
        CallV2ProductionRuntimeStartupSafetyRule.allowlistBeforeAnyUserExposure,
        CallV2ProductionRuntimeStartupSafetyRule.emergencyKillSwitchRequired,
        CallV2ProductionRuntimeStartupSafetyRule.rolloutFalseUntilApproved,
        CallV2ProductionRuntimeStartupSafetyRule.startupIdempotent,
        CallV2ProductionRuntimeStartupSafetyRule.duplicateStartupNoOp,
        CallV2ProductionRuntimeStartupSafetyRule.startupAfterDisposeRejected,
        CallV2ProductionRuntimeStartupSafetyRule.startupAfterTerminalRejected,
        CallV2ProductionRuntimeStartupSafetyRule
            .staleGenerationMutationRejected,
        CallV2ProductionRuntimeStartupSafetyRule.controlledStartupFailureOnly,
        CallV2ProductionRuntimeStartupSafetyRule.noRawExceptionStackExposure,
        CallV2ProductionRuntimeStartupSafetyRule
            .noSensitiveIdsTokensChannelsCredentialsInDebugLogs,
        CallV2ProductionRuntimeStartupSafetyRule
            .noProductionServiceContactWithoutSeparateApproval,
      ]),
    );
  });

  test('design lists dependency gates before runtime startup', () {
    expect(
      design.dependencyGates,
      containsAll(<Object>[
        CallV2ProductionRuntimeStartupDependencyGate
            .routeRegistrationDesignAccepted,
        CallV2ProductionRuntimeStartupDependencyGate
            .lifecycleObserverDesignAccepted,
        CallV2ProductionRuntimeStartupDependencyGate
            .navigatorWiringDesignAccepted,
        CallV2ProductionRuntimeStartupDependencyGate
            .backendFirebaseDesignAcceptedBeforeServiceContact,
        CallV2ProductionRuntimeStartupDependencyGate
            .rtcPermissionDesignAcceptedBeforeMediaStartup,
        CallV2ProductionRuntimeStartupDependencyGate
            .securityPrivacyAuditAccepted,
        CallV2ProductionRuntimeStartupDependencyGate
            .preRolloutReadinessAccepted,
        CallV2ProductionRuntimeStartupDependencyGate
            .stagedRolloutDesignAccepted,
        CallV2ProductionRuntimeStartupDependencyGate.allTestsPassed,
        CallV2ProductionRuntimeStartupDependencyGate.v1SmokePlanAccepted,
      ]),
    );
  });

  test('design keeps lifecycle events from starting runtime by themselves', () {
    expect(
      design.lifecycleRules,
      containsAll(<Object>[
        CallV2ProductionRuntimeStartupLifecycleRule
            .resumeDoesNotStartRuntimeByItself,
        CallV2ProductionRuntimeStartupLifecycleRule
            .pauseInactiveHiddenDoNotStartRuntime,
        CallV2ProductionRuntimeStartupLifecycleRule
            .detachedSignOutAuthInvalidCleanupOnlyByExplicitPolicy,
        CallV2ProductionRuntimeStartupLifecycleRule
            .lifecycleEventNeedsSeparateApprovedActionBeforeStartup,
        CallV2ProductionRuntimeStartupLifecycleRule
            .runtimeStartupIsolatedFromAppBackgrounding,
      ]),
    );
  });

  test('design lists rollback controls and V1 protections', () {
    expect(
      design.rollbackControls,
      containsAll(<Object>[
        CallV2ProductionRuntimeStartupRollback.oneCommit,
        CallV2ProductionRuntimeStartupRollback.removeStartupOwnerWiring,
        CallV2ProductionRuntimeStartupRollback.rolloutFalse,
        CallV2ProductionRuntimeStartupRollback.routeRegistryDisabledNull,
        CallV2ProductionRuntimeStartupRollback.lifecycleBridgeRemainsIsolated,
        CallV2ProductionRuntimeStartupRollback.navigatorAdapterRemainsIsolated,
        CallV2ProductionRuntimeStartupRollback
            .noBackendFirebaseRtcPermissionCleanupLeaks,
        CallV2ProductionRuntimeStartupRollback.noDeploymentWithoutApproval,
        CallV2ProductionRuntimeStartupRollback.backupBranchProtected,
      ]),
    );
    expect(
      design.v1Protections,
      containsAll(<Object>[
        CallV2ProductionRuntimeStartupV1Protection.noV1RouteChanges,
        CallV2ProductionRuntimeStartupV1Protection.noV1CallBehaviorChanges,
        CallV2ProductionRuntimeStartupV1Protection.noV1ChatBehaviorChanges,
        CallV2ProductionRuntimeStartupV1Protection.noAppStartupRegression,
        CallV2ProductionRuntimeStartupV1Protection
            .v1SmokeBeforeAndAfterAnyStartupWiring,
        CallV2ProductionRuntimeStartupV1Protection
            .immediateRollbackOnV1Regression,
      ]),
    );
  });

  test('design aligns with accepted prerequisite design packages', () {
    expect(callV2ProductionRouteRegistrationDesign.isRolloutEnabled, isFalse);
    expect(
      callV2ProductionLifecycleObserverDesign.isLifecycleObserverImplemented,
      isFalse,
    );
    expect(
      callV2ProductionNavigatorWiringDesign.isNavigatorWiringImplemented,
      isFalse,
    );
    expect(callV2ProductionStagedRolloutDesign.isRolloutEnabled, isFalse);
    expect(
      design.dependencyGates,
      containsAll(<Object>[
        CallV2ProductionRuntimeStartupDependencyGate
            .routeRegistrationDesignAccepted,
        CallV2ProductionRuntimeStartupDependencyGate
            .lifecycleObserverDesignAccepted,
        CallV2ProductionRuntimeStartupDependencyGate
            .navigatorWiringDesignAccepted,
        CallV2ProductionRuntimeStartupDependencyGate
            .stagedRolloutDesignAccepted,
      ]),
    );
  });

  test('design lists required validation coverage', () {
    expect(
      design.testRequirements,
      containsAll(<Object>[
        CallV2ProductionRuntimeStartupTestRequirement.phase6XTests,
        CallV2ProductionRuntimeStartupTestRequirement.phase6WTests,
        CallV2ProductionRuntimeStartupTestRequirement.phase6VTests,
        CallV2ProductionRuntimeStartupTestRequirement.phase6UTests,
        CallV2ProductionRuntimeStartupTestRequirement.phase6TTests,
        CallV2ProductionRuntimeStartupTestRequirement.allCallV2DesignTests,
        CallV2ProductionRuntimeStartupTestRequirement.allCallV2IntegrationTests,
        CallV2ProductionRuntimeStartupTestRequirement.allCallV2UiTests,
        CallV2ProductionRuntimeStartupTestRequirement
            .preIntegrationVerification,
        CallV2ProductionRuntimeStartupTestRequirement
            .productionCompositionTests,
        CallV2ProductionRuntimeStartupTestRequirement.finalReadinessTests,
        CallV2ProductionRuntimeStartupTestRequirement.allCallV2FlutterTests,
        CallV2ProductionRuntimeStartupTestRequirement.backendCheck,
        CallV2ProductionRuntimeStartupTestRequirement.deploymentValidation,
        CallV2ProductionRuntimeStartupTestRequirement.firestoreRulesTests,
        CallV2ProductionRuntimeStartupTestRequirement.emulatorTests,
        CallV2ProductionRuntimeStartupTestRequirement.fullFlutterAnalyze,
        CallV2ProductionRuntimeStartupTestRequirement.diffCheck,
      ]),
    );
  });

  test('design model is immutable and safe to debug', () {
    expect(
      () => design.currentStatus.add(
        CallV2ProductionRuntimeStartupStatus.callV2Unreachable,
      ),
      throwsUnsupportedError,
    );
    expect(
      () => design.dependencyGates.add(
        CallV2ProductionRuntimeStartupDependencyGate.allTestsPassed,
      ),
      throwsUnsupportedError,
    );
    final debugMap = design.toSafeDebugMap();
    expect(debugMap['currentStatusCount'], design.currentStatus.length);
    expect(debugMap['dependencyGateCount'], design.dependencyGates.length);
    expect(debugMap.values.whereType<String>(), isEmpty);
    _expectSafeDebug(design.toString());
  });

  test('rollout policy and route registries remain closed', () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(
      resolveCallV2Route(
        const RouteSettings(name: CallV2RouteNames.connecting),
      ),
      isNull,
    );
    expect(
      const DisabledCallV2RouteRegistry().resolve(
        const RouteSettings(name: CallV2RouteNames.connecting),
      ),
      isNull,
    );
  });

  test('disabled owner remains inert and does not start runtime', () async {
    final owner = DisabledCallV2ProductionIntegrationOwner();

    expect(owner.status.runtimeStarted, isFalse);
    await expectLater(owner.start(), throwsA(isA<Object>()));
    expect(owner.status.runtimeStarted, isFalse);
    await owner.stop();
    await owner.dispose();
    expect(owner.status.runtimeStarted, isFalse);
  });

  test('real app files remain disconnected from runtime startup design', () {
    final sources = <String, String>{
      'main': _read('lib/main.dart'),
      'appRouter': _read('lib/navigation/app_router.dart'),
      'routeRegistry': _read(
        'lib/call_v2/integration/call_v2_route_registry.dart',
      ),
    };

    for (final entry in sources.entries) {
      expect(
        entry.value,
        isNot(contains('call_v2_production_runtime_startup_design')),
        reason: entry.key,
      );
      expect(
        entry.value,
        isNot(contains('CallV2ProductionRuntimeStartup')),
        reason: entry.key,
      );
    }
    expect(sources['appRouter'], isNot(contains('/call-v2/')));
    expect(sources['appRouter'], isNot(contains('CallV2RouteNames')));
    expect(sources['appRouter'], isNot(contains('resolveCallV2Route')));
  });

  test('production composition does not construct startup runtime', () {
    final composition = _read(
      'lib/call_v2/production/call_v2_production_composition.dart',
    );

    expect(composition, isNot(contains('CallV2ProductionRuntimeStartup')));
    expect(composition, isNot(contains('startRuntime')));
    expect(composition,
        isNot(contains('constructProductionCompositionFromStartup')));
  });

  test('new design introduces no runtime or service wiring', () {
    final source = _read(
      'lib/call_v2/design/call_v2_production_runtime_startup_design.dart',
    );

    for (final forbidden in <String>[
      'package:flutter/',
      'dart:async',
      'package:firebase_',
      'package:cloud_',
      'package:agora_',
      'package:permission_',
      'FirebaseFirestore',
      'FirebaseFunctions',
      'FirebaseAuth',
      'FirebaseAppCheck',
      'AgoraRtcEngine',
      'PermissionStatus',
      'NavigatorState',
      'RouteSettings(',
      'GlobalKey',
      'BuildContext',
      'Timer(',
      'Timer.',
      'StreamController',
      'StreamSubscription',
      '.listen(',
      'AppLifecycleListener',
      'WidgetsBindingObserver',
      'MaterialApp(',
      'VoidCallback',
      'Function()',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('dependency platform and config files remain unrelated to Phase 6X', () {
    final sources = <String, String>{
      'pubspec.yaml': _read('pubspec.yaml'),
      'pubspec.lock': _read('pubspec.lock'),
      'firebase.json': _read('firebase.json'),
      'index.js': _read('connect_functions/index.js'),
    };

    for (final entry in sources.entries) {
      expect(
        entry.value,
        isNot(contains('call_v2_production_runtime_startup_design')),
        reason: entry.key,
      );
      expect(
        entry.value,
        isNot(contains('CallV2ProductionRuntimeStartup')),
        reason: entry.key,
      );
    }
  });
}

String _read(String path) => File(path).readAsStringSync();

void _expectSafeDebug(String text) {
  for (final forbidden in <String>[
    '/call-v2/',
    'uid_',
    'call_',
    'participant_',
    'token=',
    'credential',
    'channel=',
    'payload',
    'stackTrace',
  ]) {
    expect(text.contains(forbidden), isFalse, reason: forbidden);
  }
}
