import 'dart:io';

import 'package:connect_app/call_v2/design/call_v2_production_lifecycle_hookup_design.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('current status says lifecycle hookup is not implemented', () {
    final design = callV2ProductionLifecycleHookupDesign;

    expect(
      design.currentStatus,
      containsAll(<Object>[
        CallV2ProductionLifecycleHookupStatus.lifecycleBridgeExists,
        CallV2ProductionLifecycleHookupStatus.runtimeUiBridgeExists,
        CallV2ProductionLifecycleHookupStatus.uiCompositionOwnerExists,
        CallV2ProductionLifecycleHookupStatus.navigatorAdapterBoundaryExists,
        CallV2ProductionLifecycleHookupStatus.routeSinkExists,
        CallV2ProductionLifecycleHookupStatus.realAppHookupNotImplemented,
        CallV2ProductionLifecycleHookupStatus
            .realLifecycleObserverNotRegistered,
        CallV2ProductionLifecycleHookupStatus.routeRegistrationNotImplemented,
        CallV2ProductionLifecycleHookupStatus.rolloutRemainsFalse,
        CallV2ProductionLifecycleHookupStatus.backupBranchProtected,
        CallV2ProductionLifecycleHookupStatus.deploymentNotAuthorized,
      ]),
    );
    expect(design.isRealHookupImplemented, isFalse);
    expect(design.isLifecycleObserverRegistered, isFalse);
    expect(design.isRolloutEnabled, isFalse);
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
  });

  test('future hookup requires explicit human approval and isolated ownership',
      () {
    final design = callV2ProductionLifecycleHookupDesign;

    expect(design.requiresHumanApprovalBeforeHookup, isTrue);
    expect(
      design.allowedFutureHookupLocations,
      <CallV2ProductionLifecycleHookupLocation>[
        CallV2ProductionLifecycleHookupLocation.isolatedIntegrationOwner,
        CallV2ProductionLifecycleHookupLocation.startupBoundaryAfterApproval,
      ],
    );
    expect(
      design.manualApprovalPoints,
      containsAll(<Object>[
        CallV2ProductionLifecycleManualApprovalPoint
            .lifecycleObserverRegistration,
        CallV2ProductionLifecycleManualApprovalPoint.mainFileModification,
        CallV2ProductionLifecycleManualApprovalPoint.appStartupModification,
        CallV2ProductionLifecycleManualApprovalPoint
            .routeRegistrationEnablement,
        CallV2ProductionLifecycleManualApprovalPoint
            .runtimeConstructionEnablement,
        CallV2ProductionLifecycleManualApprovalPoint
            .firebaseBackendRtcPermissionEnablement,
        CallV2ProductionLifecycleManualApprovalPoint.rolloutFlagChange,
        CallV2ProductionLifecycleManualApprovalPoint.deployment,
      ]),
    );
  });

  test('forbidden hookup locations cover app router route registry and V1', () {
    final forbidden =
        callV2ProductionLifecycleHookupDesign.forbiddenHookupLocations;

    expect(
      forbidden,
      containsAll(<Object>[
        CallV2ProductionLifecycleForbiddenHookupLocation.directMainFile,
        CallV2ProductionLifecycleForbiddenHookupLocation.appRouter,
        CallV2ProductionLifecycleForbiddenHookupLocation.routeRegistry,
        CallV2ProductionLifecycleForbiddenHookupLocation.v1Code,
        CallV2ProductionLifecycleForbiddenHookupLocation.runtimeCode,
        CallV2ProductionLifecycleForbiddenHookupLocation.firebaseCode,
        CallV2ProductionLifecycleForbiddenHookupLocation.rtcCode,
        CallV2ProductionLifecycleForbiddenHookupLocation.permissionCode,
        CallV2ProductionLifecycleForbiddenHookupLocation.observabilityCode,
      ]),
    );
  });

  test('required gates preserve rollout and block runtime service access', () {
    final design = callV2ProductionLifecycleHookupDesign;

    expect(
      design.requiredGates,
      containsAll(<Object>[
        CallV2ProductionLifecycleHookupGate.rolloutFalseByDefault,
        CallV2ProductionLifecycleHookupGate
            .developerOnlyOrAllowlistBeforeUserRollout,
        CallV2ProductionLifecycleHookupGate.emergencyKillSwitch,
        CallV2ProductionLifecycleHookupGate.separateRouteRegistrationApproval,
        CallV2ProductionLifecycleHookupGate.separateRuntimeStartApproval,
        CallV2ProductionLifecycleHookupGate.separateFirebaseApproval,
        CallV2ProductionLifecycleHookupGate.separateBackendApproval,
        CallV2ProductionLifecycleHookupGate.separateRtcApproval,
        CallV2ProductionLifecycleHookupGate.separatePermissionApproval,
      ]),
    );
    expect(
      design.dependencyConstraints,
      containsAll(<Object>[
        CallV2ProductionLifecycleHookupDependencyConstraint
            .noFirebaseAccessInThisPhase,
        CallV2ProductionLifecycleHookupDependencyConstraint
            .noBackendAccessInThisPhase,
        CallV2ProductionLifecycleHookupDependencyConstraint
            .noRtcInitializationInThisPhase,
        CallV2ProductionLifecycleHookupDependencyConstraint
            .noPermissionRequestInThisPhase,
        CallV2ProductionLifecycleHookupDependencyConstraint
            .noRuntimeConstructionInThisPhase,
        CallV2ProductionLifecycleHookupDependencyConstraint
            .noRuntimeStartInThisPhase,
      ]),
    );
  });

  test('safety requirements cover route identifiers navigation and cleanup',
      () {
    final requirements =
        callV2ProductionLifecycleHookupDesign.safetyRequirements;

    expect(
      requirements,
      containsAll(<Object>[
        CallV2ProductionLifecycleSafetyRequirement
            .noIdentifierTokenChannelCredentialInRouteName,
        CallV2ProductionLifecycleSafetyRequirement
            .noIdentifierTokenChannelCredentialInRouteArguments,
        CallV2ProductionLifecycleSafetyRequirement
            .noIdentifierTokenChannelCredentialInKeys,
        CallV2ProductionLifecycleSafetyRequirement
            .noIdentifierTokenChannelCredentialInDebugOutput,
        CallV2ProductionLifecycleSafetyRequirement
            .noIdentifierTokenChannelCredentialInLogs,
        CallV2ProductionLifecycleSafetyRequirement.noRawExceptionUserVisible,
        CallV2ProductionLifecycleSafetyRequirement.noStackTraceUserVisible,
        CallV2ProductionLifecycleSafetyRequirement.noUnrelatedV1RoutePop,
        CallV2ProductionLifecycleSafetyRequirement.noDuplicateNavigation,
        CallV2ProductionLifecycleSafetyRequirement.noNavigationAfterDispose,
        CallV2ProductionLifecycleSafetyRequirement.noStaleGenerationMutation,
        CallV2ProductionLifecycleSafetyRequirement.noCleanupLeaks,
        CallV2ProductionLifecycleSafetyRequirement
            .cleanupTimersStreamsSubscriptionsBeforeUse,
        CallV2ProductionLifecycleSafetyRequirement
            .noAppCheckDebugTokenLoggingChanges,
        CallV2ProductionLifecycleSafetyRequirement.noChatRouteLoggingChanges,
      ]),
    );
    _expectSafeDebug(callV2ProductionLifecycleHookupDesign.toString());
  });

  test('event mapping and cleanup policy summarize accepted bridge behavior',
      () {
    final design = callV2ProductionLifecycleHookupDesign;

    expect(
      design.eventMapping,
      containsAll(<Object>[
        CallV2ProductionLifecycleEventMapping.appResumedNoOp,
        CallV2ProductionLifecycleEventMapping
            .appPausedNoOpUnlessExplicitCleanup,
        CallV2ProductionLifecycleEventMapping
            .appInactiveNoOpUnlessExplicitCleanup,
        CallV2ProductionLifecycleEventMapping
            .appHiddenNoOpUnlessExplicitCleanup,
        CallV2ProductionLifecycleEventMapping
            .appDetachedTerminalCloseAndDispose,
        CallV2ProductionLifecycleEventMapping
            .signOutStartedTerminalCloseAndDispose,
        CallV2ProductionLifecycleEventMapping
            .authSignedOutTerminalCloseAndDispose,
        CallV2ProductionLifecycleEventMapping
            .authInvalidTerminalCloseAndDispose,
        CallV2ProductionLifecycleEventMapping
            .explicitCleanupUsesRequestedPolicy,
      ]),
    );
    expect(
      design.cleanupSummary,
      containsAll(<Object>[
        CallV2ProductionLifecycleCleanupSummary
            .noOpDefaultForTransientLifecycleEvents,
        CallV2ProductionLifecycleCleanupSummary.closeOnlyRequiresExplicitPolicy,
        CallV2ProductionLifecycleCleanupSummary
            .closeAndDisposeRequiresExplicitPolicy,
        CallV2ProductionLifecycleCleanupSummary
            .terminalCloseAndDisposeForDetachedSignOutInvalidAuth,
        CallV2ProductionLifecycleCleanupSummary
            .cleanupDelegatesOnlyToInjectedRuntimeUiBridge,
        CallV2ProductionLifecycleCleanupSummary
            .cleanupMustBeScopedToOwnedCallV2State,
      ]),
    );
  });

  test('readiness lists required pre and post hookup validation', () {
    final readiness = callV2ProductionLifecycleHookupDesign.readiness;

    expect(
      readiness.preHookupTests,
      containsAll(<Object>[
        CallV2ProductionLifecycleHookupTest.allCallV2Tests,
        CallV2ProductionLifecycleHookupTest.lifecycleBridgeFocusedTests,
        CallV2ProductionLifecycleHookupTest.runtimeUiBridgeFocusedTests,
        CallV2ProductionLifecycleHookupTest.uiCompositionOwnerFocusedTests,
        CallV2ProductionLifecycleHookupTest.routeSinkTests,
        CallV2ProductionLifecycleHookupTest.navigatorAdapterTests,
        CallV2ProductionLifecycleHookupTest.routeObjectFactoryTests,
        CallV2ProductionLifecycleHookupTest.finalReadinessAudit,
        CallV2ProductionLifecycleHookupTest.backendRulesAndEmulatorChecks,
        CallV2ProductionLifecycleHookupTest.v1RegressionSmokeChecks,
      ]),
    );
    expect(
      readiness.postHookupTests,
      containsAll(<Object>[
        CallV2ProductionLifecycleHookupTest.allCallV2Tests,
        CallV2ProductionLifecycleHookupTest.realObserverLifecycleTests,
        CallV2ProductionLifecycleHookupTest.realAppStartupIsolationTests,
        CallV2ProductionLifecycleHookupTest.routeRegistrationGatingTests,
        CallV2ProductionLifecycleHookupTest.killSwitchRollbackTests,
        CallV2ProductionLifecycleHookupTest.productionServiceNoContactTests,
        CallV2ProductionLifecycleHookupTest.finalReadinessAudit,
        CallV2ProductionLifecycleHookupTest.backendRulesAndEmulatorChecks,
      ]),
    );
  });

  test('rollback plan preserves disabled rollout and backup branch', () {
    expect(
      callV2ProductionLifecycleHookupDesign.rollbackPlan,
      containsAll(<Object>[
        CallV2ProductionLifecycleRollbackStep.rolloutStaysFalse,
        CallV2ProductionLifecycleRollbackStep
            .removeOrBypassLifecycleOwnerWiring,
        CallV2ProductionLifecycleRollbackStep.disableObserverRegistration,
        CallV2ProductionLifecycleRollbackStep.routeRegistryRemainsDisabled,
        CallV2ProductionLifecycleRollbackStep.noProductionServicesStarted,
        CallV2ProductionLifecycleRollbackStep.backupBranchRemainsUnchanged,
      ]),
    );
  });

  test('design model is immutable and not wired', () {
    final design = callV2ProductionLifecycleHookupDesign;

    expect(
      () => design.currentStatus.add(
        CallV2ProductionLifecycleHookupStatus.realAppHookupNotImplemented,
      ),
      throwsUnsupportedError,
    );
    expect(
      design.notWiredProofs,
      containsAll(<Object>[
        CallV2ProductionLifecycleNotWiredProof.mainFileUnmodifiedByPhase,
        CallV2ProductionLifecycleNotWiredProof.appRouterUnmodifiedByPhase,
        CallV2ProductionLifecycleNotWiredProof.routeRegistryStillDisabled,
        CallV2ProductionLifecycleNotWiredProof.disabledOwnerStillInert,
        CallV2ProductionLifecycleNotWiredProof
            .productionCompositionDisconnected,
        CallV2ProductionLifecycleNotWiredProof.noLifecycleObserverRegistration,
        CallV2ProductionLifecycleNotWiredProof
            .noAppLifecycleListenerRegistration,
        CallV2ProductionLifecycleNotWiredProof.noAppNavigationKeyDependency,
        CallV2ProductionLifecycleNotWiredProof.noGlobalNavigationKeyDependency,
        CallV2ProductionLifecycleNotWiredProof.noRouteRegistration,
        CallV2ProductionLifecycleNotWiredProof.noRuntimeConstruction,
        CallV2ProductionLifecycleNotWiredProof.noRuntimeStart,
        CallV2ProductionLifecycleNotWiredProof
            .noFirebaseBackendRtcPermissionAccess,
        CallV2ProductionLifecycleNotWiredProof.noV1Modification,
      ]),
    );
  });

  test('main file remains disconnected from the lifecycle bridge', () {
    final source = _read('lib/main.dart');

    expect(source, isNot(contains('CallV2ProductionLifecycleBridge')));
    expect(source, isNot(contains('CallV2ProductionLifecycleBridgeEvent')));
    expect(source, contains('initializeCallV2AppIntegrationShellSafely'));
    expect(source, contains('resolveCallV2Route(settings)'));
  });

  test('app router remains disconnected from Call V2 lifecycle and routes', () {
    final source = _read('lib/navigation/app_router.dart');

    expect(source, isNot(contains('CallV2')));
    expect(source, isNot(contains('call_v2')));
    expect(source, isNot(contains('resolveCallV2Route')));
    expect(source, isNot(contains('CallV2ProductionLifecycleBridge')));
  });

  test('route registry remains disabled and lifecycle-free', () {
    final source = _read('lib/call_v2/integration/call_v2_route_registry.dart');

    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(resolveCallV2Route(const RouteSettings(name: '/call-v2/connecting')),
        isNull);
    expect(source, contains('if (!CallV2RolloutPolicy.productionEnabled)'));
    expect(source, isNot(contains('CallV2ProductionLifecycleBridge')));
    expect(source, isNot(contains('AppLifecycleListener')));
  });

  test('disabled owner and production composition remain disconnected', () {
    final disabledOwner = _read(
      'lib/call_v2/integration/disabled_call_v2_production_integration_owner.dart',
    );
    final productionComposition = _read(
      'lib/call_v2/production/call_v2_production_composition.dart',
    );

    for (final source in <String>[disabledOwner, productionComposition]) {
      expect(source, isNot(contains('CallV2ProductionLifecycleBridge')));
      expect(source, isNot(contains('AppLifecycleListener')));
      expect(source, isNot(contains('WidgetsBindingObserver')));
      expect(source, isNot(contains('resolveCallV2Route')));
    }
    expect(disabledOwner, contains('runtimeStarted: false'));
    expect(disabledOwner, contains('routesRegistered: false'));
  });

  test('Phase 6N changed files contain no real lifecycle or navigation hook',
      () {
    final sources = _phase6NDesignSources().join('\n');

    for (final forbidden in <String>[
      'WidgetsBindingObserver',
      'WidgetsBinding.instance.addObserver',
      'AppLifecycleListener(',
      'navigatorKey',
      'GlobalKey',
      'BuildContext',
      'Navigator.',
      'runApp',
      'initializeCallV2AppIntegrationShellSafely',
      'resolveCallV2Route(',
      'Firebase.',
      'FirebaseFirestore',
      'FirebaseAuth',
      'FirebaseFunctions',
      'Agora',
      'RtcEngine',
      'Permission.',
      'httpsCallable',
      'initializeApp',
    ]) {
      expect(sources.contains(forbidden), isFalse, reason: forbidden);
    }
  });
}

String _read(String path) => File(path).readAsStringSync();

List<String> _phase6NDesignSources() {
  return <String>[
    _read('lib/call_v2/design/call_v2_production_lifecycle_hookup_design.dart'),
  ];
}

void _expectSafeDebug(String text) {
  for (final forbidden in <String>[
    'uid_',
    'call_',
    'participant_',
    'token=',
    'channel=',
    'credential=',
    'Bearer ',
    'stackTrace',
  ]) {
    expect(text, isNot(contains(forbidden)), reason: forbidden);
  }
}
