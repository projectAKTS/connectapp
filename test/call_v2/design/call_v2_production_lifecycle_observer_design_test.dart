import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/design/call_v2_production_human_approval_package.dart';
import 'package:connect_app/call_v2/design/call_v2_production_lifecycle_hookup_design.dart';
import 'package:connect_app/call_v2/design/call_v2_production_lifecycle_observer_design.dart';
import 'package:connect_app/call_v2/design/call_v2_production_pre_rollout_readiness_audit.dart';
import 'package:connect_app/call_v2/design/call_v2_production_route_registration_design.dart';
import 'package:connect_app/call_v2/design/call_v2_production_security_privacy_audit.dart';
import 'package:connect_app/call_v2/design/call_v2_production_staged_rollout_design.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_integration_status.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('design records current lifecycle observer status as disabled', () {
    final design = callV2ProductionLifecycleObserverDesign;

    expect(design.isLifecycleObserverImplemented, isFalse);
    expect(design.isAppLifecycleListenerRegistered, isFalse);
    expect(design.isWidgetsBindingObserverRegistered, isFalse);
    expect(design.isRolloutEnabled, isFalse);
    expect(design.isCallV2Reachable, isFalse);
    expect(design.isDeploymentAuthorized, isFalse);
    expect(
      design.currentStatus,
      containsAll(<Object>[
        CallV2ProductionLifecycleObserverStatus
            .noRealLifecycleObserverImplemented,
        CallV2ProductionLifecycleObserverStatus
            .noAppLifecycleListenerRegistered,
        CallV2ProductionLifecycleObserverStatus
            .noWidgetsBindingObserverRegistered,
        CallV2ProductionLifecycleObserverStatus.rolloutFalse,
        CallV2ProductionLifecycleObserverStatus.mainDartDisconnected,
        CallV2ProductionLifecycleObserverStatus.startupDisconnected,
        CallV2ProductionLifecycleObserverStatus.routeRegistryDisabled,
        CallV2ProductionLifecycleObserverStatus.lifecycleBridgeIsolated,
        CallV2ProductionLifecycleObserverStatus.callV2Unreachable,
        CallV2ProductionLifecycleObserverStatus.deploymentNotAuthorized,
      ]),
    );
  });

  test('design lists allowed future locations only after approval', () {
    expect(
      callV2ProductionLifecycleObserverDesign.allowedFutureLocations,
      equals(<CallV2ProductionLifecycleObserverAllowedLocation>[
        CallV2ProductionLifecycleObserverAllowedLocation
            .isolatedCallV2LifecycleObserverOwner,
        CallV2ProductionLifecycleObserverAllowedLocation
            .isolatedAppStartupBoundaryOnlyIfApproved,
        CallV2ProductionLifecycleObserverAllowedLocation
            .developerOnlyLifecycleObserverPrOnly,
      ]),
    );
  });

  test('design forbids main app router and V1 observer locations', () {
    expect(
      callV2ProductionLifecycleObserverDesign.forbiddenLocations,
      containsAll(<Object>[
        CallV2ProductionLifecycleObserverForbiddenLocation
            .mainDartDirectObserverLogic,
        CallV2ProductionLifecycleObserverForbiddenLocation.appRouter,
        CallV2ProductionLifecycleObserverForbiddenLocation.v1RouteFiles,
        CallV2ProductionLifecycleObserverForbiddenLocation.v1CallFiles,
        CallV2ProductionLifecycleObserverForbiddenLocation
            .productionCompositionFromStartup,
      ]),
    );
  });

  test('design forbids unsafe lifecycle observer actions', () {
    expect(
      callV2ProductionLifecycleObserverDesign.forbiddenActions,
      containsAll(<Object>[
        CallV2ProductionLifecycleObserverForbiddenAction.modifyMainDart,
        CallV2ProductionLifecycleObserverForbiddenAction.modifyStartup,
        CallV2ProductionLifecycleObserverForbiddenAction
            .addAppLifecycleListener,
        CallV2ProductionLifecycleObserverForbiddenAction
            .addWidgetsBindingObserver,
        CallV2ProductionLifecycleObserverForbiddenAction.changeRolloutFlag,
        CallV2ProductionLifecycleObserverForbiddenAction.registerRoutes,
        CallV2ProductionLifecycleObserverForbiddenAction.startRuntime,
        CallV2ProductionLifecycleObserverForbiddenAction
            .constructProductionCompositionFromStartup,
        CallV2ProductionLifecycleObserverForbiddenAction
            .contactBackendServicesRtcPermissions,
        CallV2ProductionLifecycleObserverForbiddenAction
            .useNavigationKeyOrWidgetContextStorage,
        CallV2ProductionLifecycleObserverForbiddenAction
            .createAsyncHandlesWithoutCleanup,
        CallV2ProductionLifecycleObserverForbiddenAction.deploy,
      ]),
    );
  });

  test('design maps lifecycle events conservatively', () {
    expect(
      callV2ProductionLifecycleObserverDesign.eventMappings,
      containsAll(<Object>[
        CallV2ProductionLifecycleObserverEventMapping.resumedNoOpByDefault,
        CallV2ProductionLifecycleObserverEventMapping
            .pausedNoDestructiveCleanupByDefault,
        CallV2ProductionLifecycleObserverEventMapping
            .inactiveNoDestructiveCleanupByDefault,
        CallV2ProductionLifecycleObserverEventMapping
            .hiddenNoDestructiveCleanupByDefault,
        CallV2ProductionLifecycleObserverEventMapping
            .detachedTerminalCloseAndDisposeOnlyAfterExplicitPolicy,
        CallV2ProductionLifecycleObserverEventMapping
            .signOutStartedTerminalCloseAndDisposeOnlyAfterExplicitPolicy,
        CallV2ProductionLifecycleObserverEventMapping
            .authInvalidSignedOutTerminalCloseAndDisposeOnlyAfterExplicitPolicy,
        CallV2ProductionLifecycleObserverEventMapping
            .duplicateLifecycleEventsIdempotent,
        CallV2ProductionLifecycleObserverEventMapping
            .eventsAfterDisposeNoOpOrReject,
        CallV2ProductionLifecycleObserverEventMapping
            .eventsAfterTerminalNoOpOrReject,
      ]),
    );
  });

  test('design lists cleanup safety rules', () {
    expect(
      callV2ProductionLifecycleObserverDesign.cleanupRules,
      containsAll(<Object>[
        CallV2ProductionLifecycleObserverCleanupRule.noUnrelatedV1RoutePop,
        CallV2ProductionLifecycleObserverCleanupRule.noNavigationAfterDispose,
        CallV2ProductionLifecycleObserverCleanupRule.noStaleGenerationMutation,
        CallV2ProductionLifecycleObserverCleanupRule
            .noRuntimeStartFromLifecycleEvent,
        CallV2ProductionLifecycleObserverCleanupRule
            .noBackendRtcPermissionAccessFromLifecycleEvent,
        CallV2ProductionLifecycleObserverCleanupRule.allCleanupIdempotent,
        CallV2ProductionLifecycleObserverCleanupRule.allCleanupRollbackSafe,
        CallV2ProductionLifecycleObserverCleanupRule.noRawAuthUserCallIdsStored,
        CallV2ProductionLifecycleObserverCleanupRule.noRawExceptionStackLogging,
      ]),
    );
  });

  test('design requires developer gates allowlist kill switch and V1 plan', () {
    expect(
      callV2ProductionLifecycleObserverDesign.gates,
      containsAll(<Object>[
        CallV2ProductionLifecycleObserverGate.explicitHumanApproval,
        CallV2ProductionLifecycleObserverGate.developerOnlyGate,
        CallV2ProductionLifecycleObserverGate.allowlistBeforeUsers,
        CallV2ProductionLifecycleObserverGate.emergencyKillSwitch,
        CallV2ProductionLifecycleObserverGate.rolloutFalseUntilApproved,
        CallV2ProductionLifecycleObserverGate.noProductionServiceContact,
        CallV2ProductionLifecycleObserverGate.allTests,
        CallV2ProductionLifecycleObserverGate.securityPrivacyAudit,
        CallV2ProductionLifecycleObserverGate.stagedRolloutDesignAccepted,
        CallV2ProductionLifecycleObserverGate.routeRegistrationDesignAccepted,
        CallV2ProductionLifecycleObserverGate.v1SmokePlan,
      ]),
    );
  });

  test('design lists rollback controls and V1 protections', () {
    final design = callV2ProductionLifecycleObserverDesign;

    expect(
      design.rollbackControls,
      containsAll(<Object>[
        CallV2ProductionLifecycleObserverRollback.oneCommit,
        CallV2ProductionLifecycleObserverRollback
            .removeObserverOwnerRegistration,
        CallV2ProductionLifecycleObserverRollback.rolloutFalse,
        CallV2ProductionLifecycleObserverRollback
            .lifecycleBridgeRemainsIsolated,
        CallV2ProductionLifecycleObserverRollback.routeRegistryDisabledNull,
        CallV2ProductionLifecycleObserverRollback.noDeploymentWithoutApproval,
        CallV2ProductionLifecycleObserverRollback.backupBranchProtected,
      ]),
    );
    expect(
      design.v1Protections,
      containsAll(<Object>[
        CallV2ProductionLifecycleObserverV1Protection.noV1RouteFileChanges,
        CallV2ProductionLifecycleObserverV1Protection.noV1CallFileChanges,
        CallV2ProductionLifecycleObserverV1Protection.noV1RouteBehaviorChanges,
        CallV2ProductionLifecycleObserverV1Protection.noV1CallFlowChanges,
        CallV2ProductionLifecycleObserverV1Protection.noUnrelatedV1RoutePop,
        CallV2ProductionLifecycleObserverV1Protection
            .v1SmokeBeforeAndAfterAnyObserverRegistration,
        CallV2ProductionLifecycleObserverV1Protection
            .immediateRollbackOnV1Regression,
      ]),
    );
  });

  test('design aligns with accepted rollout route and lifecycle artifacts', () {
    final observer = callV2ProductionLifecycleObserverDesign;
    final route = callV2ProductionRouteRegistrationDesign;
    final staged = callV2ProductionStagedRolloutDesign;
    final approval = callV2ProductionHumanApprovalPackage;
    final readiness = callV2ProductionPreRolloutReadinessAudit;
    final security = callV2ProductionSecurityPrivacyAudit;
    final lifecycle = callV2ProductionLifecycleHookupDesign;

    expect(observer.allowsAutomaticWiring, isFalse);
    expect(route.allowsAutomaticWiring, isFalse);
    expect(staged.allowsAutomaticWiring, isFalse);
    expect(approval.allowsAutomaticRealAppWiring, isFalse);
    expect(readiness.canWireRealAppWithoutApproval, isFalse);
    expect(lifecycle.isRealHookupImplemented, isFalse);
    expect(lifecycle.isLifecycleObserverRegistered, isFalse);
    expect(
      security.isolationConstraints,
      contains(CallV2ProductionIsolationConstraint.rolloutDisabled),
    );
  });

  test('design lists required validation coverage', () {
    expect(
      callV2ProductionLifecycleObserverDesign.testRequirements,
      containsAll(<Object>[
        CallV2ProductionLifecycleObserverTestRequirement.phase6VTests,
        CallV2ProductionLifecycleObserverTestRequirement.allCallV2DesignTests,
        CallV2ProductionLifecycleObserverTestRequirement
            .allCallV2IntegrationTests,
        CallV2ProductionLifecycleObserverTestRequirement.allCallV2UiTests,
        CallV2ProductionLifecycleObserverTestRequirement
            .preIntegrationVerification,
        CallV2ProductionLifecycleObserverTestRequirement
            .productionCompositionTests,
        CallV2ProductionLifecycleObserverTestRequirement.finalReadinessTests,
        CallV2ProductionLifecycleObserverTestRequirement.allCallV2FlutterTests,
        CallV2ProductionLifecycleObserverTestRequirement.backendCheck,
        CallV2ProductionLifecycleObserverTestRequirement.deploymentValidation,
        CallV2ProductionLifecycleObserverTestRequirement.firestoreRulesTests,
        CallV2ProductionLifecycleObserverTestRequirement.emulatorTests,
        CallV2ProductionLifecycleObserverTestRequirement.fullFlutterAnalyze,
        CallV2ProductionLifecycleObserverTestRequirement.diffCheck,
      ]),
    );
  });

  test('design model is immutable and safe to debug', () {
    final design = callV2ProductionLifecycleObserverDesign;

    expect(
      () => design.currentStatus.add(
        CallV2ProductionLifecycleObserverStatus.rolloutFalse,
      ),
      throwsUnsupportedError,
    );
    expect(
      () => design.eventMappings.add(
        CallV2ProductionLifecycleObserverEventMapping.resumedNoOpByDefault,
      ),
      throwsUnsupportedError,
    );

    final text = design.toString();
    expect(text, contains('eventMappingCount'));
    for (final forbidden in <String>[
      '/call-v2/',
      'uid',
      'callId',
      'participantId',
      'token',
      'credential',
      'channel',
      'payload',
      'StackTrace',
      'Exception',
      design.protectedBackupBranch,
      design.protectedBackupSha,
    ]) {
      expect(text, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('rollout policy and route registries remain closed', () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(
      resolveCallV2Route(const RouteSettings(name: '/call-v2/audio')),
      isNull,
    );
    expect(
      const DisabledCallV2RouteRegistry().resolve(
        const RouteSettings(name: '/call-v2/audio'),
      ),
      isNull,
    );
  });

  test('disabled owner remains inert', () async {
    final owner = DisabledCallV2ProductionIntegrationOwner();

    await owner.initialize();

    expect(
      owner.status.lifecycle,
      CallV2ProductionIntegrationLifecycle.disabled,
    );
    expect(owner.status.rolloutEnabled, isFalse);
    expect(owner.status.routesRegistered, isFalse);
    expect(owner.status.runtimeStarted, isFalse);
    expect(owner.status.compositionConstructed, isFalse);
    await expectLater(
      owner.start(),
      throwsA(isA<CallV2ClientError>().having(
        (error) => error.code,
        'code',
        CallV2ClientErrorCode.rejected,
      )),
    );
  });

  test('real app files remain disconnected from lifecycle observer design', () {
    final sources = <String, String>{
      'main.dart': _read('lib/main.dart'),
      'app_router.dart': _read('lib/navigation/app_router.dart'),
      'route registry': _read(
        'lib/call_v2/integration/call_v2_route_registry.dart',
      ),
      'production composition': _read(
        'lib/call_v2/production/call_v2_production_composition.dart',
      ),
    };

    for (final entry in sources.entries) {
      expect(
        entry.value,
        isNot(contains('call_v2_production_lifecycle_observer_design')),
        reason: entry.key,
      );
      expect(
        entry.value,
        isNot(contains('CallV2ProductionLifecycleObserverDesign')),
        reason: entry.key,
      );
    }
  });

  test('app router remains disconnected from Call V2 production routes', () {
    final appRouter = _read('lib/navigation/app_router.dart');

    expect(appRouter, isNot(contains('/call-v2/')));
    expect(appRouter, isNot(contains('CallV2RouteNames')));
    expect(appRouter, isNot(contains('resolveCallV2Route')));
  });

  test('route registry does not reference the new design package', () {
    final routeRegistry = _read(
      'lib/call_v2/integration/call_v2_route_registry.dart',
    );

    expect(
      routeRegistry,
      isNot(contains('call_v2_production_lifecycle_observer_design')),
    );
    expect(routeRegistry, isNot(contains('CallV2ProductionLifecycleObserver')));
    expect(routeRegistry, contains('productionEnabled'));
    expect(routeRegistry, contains('return null'));
  });

  test('production composition does not construct lifecycle observer', () {
    final composition = _read(
      'lib/call_v2/production/call_v2_production_composition.dart',
    );

    expect(composition, isNot(contains('AppLifecycleListener')));
    expect(composition, isNot(contains('WidgetsBindingObserver')));
    expect(composition, isNot(contains('CallV2ProductionLifecycleObserver')));
  });

  test('new design introduces no lifecycle observer runtime or service wiring',
      () {
    final source = _read(
      'lib/call_v2/design/call_v2_production_lifecycle_observer_design.dart',
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
      'Navigator.',
      'Navigator(',
      'navigatorKey',
      'RouteSettings(',
      'GlobalKey<',
      'GlobalKey(',
      'BuildContext ',
      'Timer(',
      'Timer.',
      'StreamController',
      'StreamSubscription',
      '.listen(',
      'AppLifecycleListener(',
      'WidgetsBindingObserver(',
      'MaterialApp(',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('dependency platform and config files remain unrelated to Phase 6V', () {
    final sources = <String, String>{
      'pubspec.yaml': _read('pubspec.yaml'),
      'firebase.json': _read('firebase.json'),
      'index.js': _read('connect_functions/index.js'),
    };

    for (final entry in sources.entries) {
      expect(
        entry.value,
        isNot(contains('call_v2_production_lifecycle_observer_design')),
        reason: entry.key,
      );
      expect(
        entry.value,
        isNot(contains('CallV2ProductionLifecycleObserverDesign')),
        reason: entry.key,
      );
    }
  });
}

String _read(String path) => File(path).readAsStringSync();
