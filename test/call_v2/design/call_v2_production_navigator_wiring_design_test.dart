import 'dart:io';

import 'package:connect_app/call_v2/design/call_v2_production_lifecycle_observer_design.dart';
import 'package:connect_app/call_v2/design/call_v2_production_navigator_wiring_design.dart';
import 'package:connect_app/call_v2/design/call_v2_production_route_registration_design.dart';
import 'package:connect_app/call_v2/design/call_v2_production_staged_rollout_design.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final design = callV2ProductionNavigatorWiringDesign;

  test('design records current navigator wiring status as disabled', () {
    expect(design.isNavigatorWiringImplemented, isFalse);
    expect(design.isRolloutEnabled, isFalse);
    expect(design.isCallV2Reachable, isFalse);
    expect(design.isDeploymentAuthorized, isFalse);
    expect(design.allowsAutomaticWiring, isFalse);
    expect(
      design.currentStatus,
      containsAll(<Object>[
        CallV2ProductionNavigatorWiringStatus.noRealNavigatorWiringImplemented,
        CallV2ProductionNavigatorWiringStatus.noAppNavKeyIntroduced,
        CallV2ProductionNavigatorWiringStatus.noGlobalAppKeyIntroduced,
        CallV2ProductionNavigatorWiringStatus.noWidgetContextStored,
        CallV2ProductionNavigatorWiringStatus.noMaterialAppWiring,
        CallV2ProductionNavigatorWiringStatus.noAppRouterWiring,
        CallV2ProductionNavigatorWiringStatus.routeRegistryDisabled,
        CallV2ProductionNavigatorWiringStatus.rolloutFalse,
        CallV2ProductionNavigatorWiringStatus.callV2Unreachable,
        CallV2ProductionNavigatorWiringStatus.typedNavAdapterIsolated,
        CallV2ProductionNavigatorWiringStatus.deploymentNotAuthorized,
      ]),
    );
  });

  test('design lists allowed future locations only after approval', () {
    expect(
      design.allowedFutureLocations,
      <CallV2ProductionNavigatorWiringAllowedLocation>[
        CallV2ProductionNavigatorWiringAllowedLocation
            .isolatedCallV2NavigatorOwner,
        CallV2ProductionNavigatorWiringAllowedLocation
            .isolatedAppStartupBoundaryOnlyIfApproved,
        CallV2ProductionNavigatorWiringAllowedLocation
            .developerOnlyNavigatorWiringPrOnly,
      ],
    );
  });

  test('design forbids app router main startup and V1 wiring locations', () {
    expect(
      design.forbiddenLocations,
      containsAll(<Object>[
        CallV2ProductionNavigatorWiringForbiddenLocation.appRouterDirectWiring,
        CallV2ProductionNavigatorWiringForbiddenLocation
            .mainDartDirectNavigationLogic,
        CallV2ProductionNavigatorWiringForbiddenLocation.startup,
        CallV2ProductionNavigatorWiringForbiddenLocation.v1RouteFiles,
        CallV2ProductionNavigatorWiringForbiddenLocation.v1CallFiles,
        CallV2ProductionNavigatorWiringForbiddenLocation.v1ChatFiles,
      ]),
    );
  });

  test('design forbids unsafe navigation wiring actions', () {
    expect(
      design.forbiddenActions,
      containsAll(<Object>[
        CallV2ProductionNavigatorWiringForbiddenAction.modifyAppRouter,
        CallV2ProductionNavigatorWiringForbiddenAction.modifyMainDart,
        CallV2ProductionNavigatorWiringForbiddenAction.modifyStartup,
        CallV2ProductionNavigatorWiringForbiddenAction.changeRolloutFlag,
        CallV2ProductionNavigatorWiringForbiddenAction.registerRoutes,
        CallV2ProductionNavigatorWiringForbiddenAction.addAppNavKey,
        CallV2ProductionNavigatorWiringForbiddenAction.addGlobalAppKey,
        CallV2ProductionNavigatorWiringForbiddenAction.storeWidgetContext,
        CallV2ProductionNavigatorWiringForbiddenAction
            .useDirectNavigationOutsideTypedBoundary,
        CallV2ProductionNavigatorWiringForbiddenAction.passRouteArguments,
        CallV2ProductionNavigatorWiringForbiddenAction.addDynamicRouteNames,
        CallV2ProductionNavigatorWiringForbiddenAction
            .addIdsTokensChannelsCredentialsToNavigation,
        CallV2ProductionNavigatorWiringForbiddenAction.popUnrelatedV1Routes,
        CallV2ProductionNavigatorWiringForbiddenAction.startRuntime,
        CallV2ProductionNavigatorWiringForbiddenAction
            .contactBackendServicesRtcPermissions,
        CallV2ProductionNavigatorWiringForbiddenAction.deploy,
      ]),
    );
  });

  test('design lists navigation safety rules', () {
    expect(
      design.safetyRules,
      containsAll(<Object>[
        CallV2ProductionNavigatorWiringSafetyRule.typedNavPortOnly,
        CallV2ProductionNavigatorWiringSafetyRule.callV2OwnedRoutePopOnly,
        CallV2ProductionNavigatorWiringSafetyRule
            .noGenericPopOfUnrelatedAppRoutes,
        CallV2ProductionNavigatorWiringSafetyRule
            .routeSettingsArgumentsNullOnly,
        CallV2ProductionNavigatorWiringSafetyRule.fixedCanonicalRouteNamesOnly,
        CallV2ProductionNavigatorWiringSafetyRule.noQuery,
        CallV2ProductionNavigatorWiringSafetyRule.noFragment,
        CallV2ProductionNavigatorWiringSafetyRule.noDynamicSegments,
        CallV2ProductionNavigatorWiringSafetyRule
            .noIdsTokensChannelsCredentials,
        CallV2ProductionNavigatorWiringSafetyRule
            .navigationAfterDisposeRejected,
        CallV2ProductionNavigatorWiringSafetyRule
            .staleGenerationMutationRejected,
        CallV2ProductionNavigatorWiringSafetyRule
            .duplicateNavigationIdempotentNoOp,
        CallV2ProductionNavigatorWiringSafetyRule
            .adapterFailuresControlledSanitized,
      ]),
    );
  });

  test('design lists route ownership rules', () {
    expect(
      design.routeOwnershipRules,
      containsAll(<Object>[
        CallV2ProductionNavigatorWiringRouteOwnershipRule
            .ownedRouteNameMustBeCanonical,
        CallV2ProductionNavigatorWiringRouteOwnershipRule
            .currentRouteMustMatchOwnedRouteBeforePop,
        CallV2ProductionNavigatorWiringRouteOwnershipRule
            .readyRouteIsNotProduction,
        CallV2ProductionNavigatorWiringRouteOwnershipRule
            .v1RoutesNeverOwnedByCallV2,
        CallV2ProductionNavigatorWiringRouteOwnershipRule
            .unknownRoutesNeverPoppedByCallV2,
      ]),
    );
  });

  test('design requires developer gates allowlist kill switch and V1 plan', () {
    expect(
      design.gates,
      containsAll(<Object>[
        CallV2ProductionNavigatorWiringGate.explicitHumanApproval,
        CallV2ProductionNavigatorWiringGate.developerOnlyGate,
        CallV2ProductionNavigatorWiringGate.allowlistBeforeUsers,
        CallV2ProductionNavigatorWiringGate.emergencyKillSwitch,
        CallV2ProductionNavigatorWiringGate.rolloutFalseUntilApproved,
        CallV2ProductionNavigatorWiringGate.routeRegistrationDesignAccepted,
        CallV2ProductionNavigatorWiringGate.lifecycleObserverDesignAccepted,
        CallV2ProductionNavigatorWiringGate.securityPrivacyAudit,
        CallV2ProductionNavigatorWiringGate.allTests,
        CallV2ProductionNavigatorWiringGate.v1SmokePlan,
      ]),
    );
  });

  test('design lists rollback controls and V1 protections', () {
    expect(
      design.rollbackControls,
      containsAll(<Object>[
        CallV2ProductionNavigatorWiringRollback.oneCommit,
        CallV2ProductionNavigatorWiringRollback.removeNavigatorOwnerWiring,
        CallV2ProductionNavigatorWiringRollback.rolloutFalse,
        CallV2ProductionNavigatorWiringRollback.routeRegistryDisabledNull,
        CallV2ProductionNavigatorWiringRollback.appRouterUnchangedIfPossible,
        CallV2ProductionNavigatorWiringRollback.mainDartUnchangedIfPossible,
        CallV2ProductionNavigatorWiringRollback.typedNavAdapterRemainsIsolated,
        CallV2ProductionNavigatorWiringRollback.noDeploymentWithoutApproval,
        CallV2ProductionNavigatorWiringRollback.backupBranchProtected,
      ]),
    );
    expect(
      design.v1Protections,
      containsAll(<Object>[
        CallV2ProductionNavigatorWiringV1Protection.noV1RouteFileChanges,
        CallV2ProductionNavigatorWiringV1Protection.noV1CallFileChanges,
        CallV2ProductionNavigatorWiringV1Protection.noV1ChatFileChanges,
        CallV2ProductionNavigatorWiringV1Protection.noV1RouteBehaviorChanges,
        CallV2ProductionNavigatorWiringV1Protection.noV1CallFlowChanges,
        CallV2ProductionNavigatorWiringV1Protection.noUnrelatedV1RoutePop,
        CallV2ProductionNavigatorWiringV1Protection
            .v1SmokeBeforeAndAfterAnyNavigatorWiring,
        CallV2ProductionNavigatorWiringV1Protection
            .immediateRollbackOnV1Regression,
      ]),
    );
  });

  test('design aligns with accepted rollout route and lifecycle artifacts', () {
    expect(
      callV2ProductionRouteRegistrationDesign.currentStatus,
      contains(CallV2ProductionRouteRegistrationStatus.routeRegistryDisabled),
    );
    expect(
      callV2ProductionStagedRolloutDesign.isRolloutEnabled,
      isFalse,
    );
    expect(
      callV2ProductionLifecycleObserverDesign.isLifecycleObserverImplemented,
      isFalse,
    );
    expect(
      design.gates,
      containsAll(<Object>[
        CallV2ProductionNavigatorWiringGate.routeRegistrationDesignAccepted,
        CallV2ProductionNavigatorWiringGate.lifecycleObserverDesignAccepted,
      ]),
    );
  });

  test('design lists required validation coverage', () {
    expect(
      design.testRequirements,
      containsAll(<Object>[
        CallV2ProductionNavigatorWiringTestRequirement.phase6WTests,
        CallV2ProductionNavigatorWiringTestRequirement.phase6VTests,
        CallV2ProductionNavigatorWiringTestRequirement.phase6UTests,
        CallV2ProductionNavigatorWiringTestRequirement.phase6TTests,
        CallV2ProductionNavigatorWiringTestRequirement.phase6STests,
        CallV2ProductionNavigatorWiringTestRequirement.allCallV2DesignTests,
        CallV2ProductionNavigatorWiringTestRequirement
            .allCallV2IntegrationTests,
        CallV2ProductionNavigatorWiringTestRequirement.allCallV2UiTests,
        CallV2ProductionNavigatorWiringTestRequirement
            .preIntegrationVerification,
        CallV2ProductionNavigatorWiringTestRequirement
            .productionCompositionTests,
        CallV2ProductionNavigatorWiringTestRequirement.finalReadinessTests,
        CallV2ProductionNavigatorWiringTestRequirement.allCallV2FlutterTests,
        CallV2ProductionNavigatorWiringTestRequirement.backendCheck,
        CallV2ProductionNavigatorWiringTestRequirement.deploymentValidation,
        CallV2ProductionNavigatorWiringTestRequirement.firestoreRulesTests,
        CallV2ProductionNavigatorWiringTestRequirement.emulatorTests,
        CallV2ProductionNavigatorWiringTestRequirement.fullFlutterAnalyze,
        CallV2ProductionNavigatorWiringTestRequirement.diffCheck,
      ]),
    );
  });

  test('design model is immutable and safe to debug', () {
    expect(
      () => design.currentStatus.add(
        CallV2ProductionNavigatorWiringStatus.callV2Unreachable,
      ),
      throwsUnsupportedError,
    );
    expect(
      () => design.safetyRules.add(
        CallV2ProductionNavigatorWiringSafetyRule.noQuery,
      ),
      throwsUnsupportedError,
    );
    final debugMap = design.toSafeDebugMap();
    expect(debugMap['currentStatusCount'], design.currentStatus.length);
    expect(debugMap['safetyRuleCount'], design.safetyRules.length);
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

  test('disabled owner remains inert', () async {
    final owner = DisabledCallV2ProductionIntegrationOwner();

    expect(owner.status.runtimeStarted, isFalse);
    await expectLater(owner.start(), throwsA(isA<Object>()));
    expect(owner.status.runtimeStarted, isFalse);
    await owner.stop();
    await owner.dispose();
    expect(owner.status.runtimeStarted, isFalse);
  });

  test('real app files remain disconnected from navigator wiring design', () {
    final sources = <String, String>{
      'main': _read('lib/main.dart'),
      'appRouter': _read('lib/navigation/app_router.dart'),
    };

    for (final entry in sources.entries) {
      expect(
        entry.value,
        isNot(contains('call_v2_production_navigator_wiring_design')),
        reason: entry.key,
      );
      expect(
        entry.value,
        isNot(contains('CallV2ProductionNavigatorWiring')),
        reason: entry.key,
      );
    }
    expect(sources['appRouter'], isNot(contains('/call-v2/')));
    expect(sources['appRouter'], isNot(contains('CallV2RouteNames')));
    expect(sources['appRouter'], isNot(contains('resolveCallV2Route')));
  });

  test('route registry does not reference the new design package', () {
    final routeRegistry = _read(
      'lib/call_v2/integration/call_v2_route_registry.dart',
    );

    expect(
      routeRegistry,
      isNot(contains('call_v2_production_navigator_wiring_design')),
    );
    expect(
      routeRegistry,
      isNot(contains('CallV2ProductionNavigatorWiring')),
    );
    expect(routeRegistry, contains('productionEnabled'));
    expect(routeRegistry, contains('return null'));
  });

  test('production composition does not construct navigator wiring', () {
    final composition = _read(
      'lib/call_v2/production/call_v2_production_composition.dart',
    );

    expect(composition, isNot(contains('CallV2ProductionNavigatorWiring')));
    expect(composition, isNot(contains('CallV2ProductionNavigatorAdapter(')));
    expect(composition, isNot(contains('CallV2ProductionNavigatorPort')));
  });

  test('new design introduces no navigation runtime or service wiring', () {
    final source = _read(
      'lib/call_v2/design/call_v2_production_navigator_wiring_design.dart',
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

  test('dependency platform and config files remain unrelated to Phase 6W', () {
    final sources = <String, String>{
      'pubspec.yaml': _read('pubspec.yaml'),
      'pubspec.lock': _read('pubspec.lock'),
      'firebase.json': _read('firebase.json'),
      'index.js': _read('connect_functions/index.js'),
    };

    for (final entry in sources.entries) {
      expect(
        entry.value,
        isNot(contains('call_v2_production_navigator_wiring_design')),
        reason: entry.key,
      );
      expect(
        entry.value,
        isNot(contains('CallV2ProductionNavigatorWiring')),
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
