import 'dart:io';

import 'package:connect_app/call_v2/design/call_v2_production_first_wiring_approval_checkpoint.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final checkpoint = callV2ProductionFirstWiringApprovalCheckpoint;

  test('checkpoint records current Phase 7A blocked status', () {
    expect(checkpoint.isPhase6DesignWallAccepted, isTrue);
    expect(checkpoint.isRolloutEnabled, isFalse);
    expect(checkpoint.isCallV2Reachable, isFalse);
    expect(checkpoint.isRouteRegistryEnabled, isFalse);
    expect(checkpoint.isDisabledOwnerActive, isFalse);
    expect(checkpoint.isRuntimeStarted, isFalse);
    expect(checkpoint.hasBackendFirebaseConnection, isFalse);
    expect(checkpoint.hasRtcPermissionConnection, isFalse);
    expect(checkpoint.hasAppRouterConnection, isFalse);
    expect(checkpoint.hasMainStartupConnection, isFalse);
    expect(checkpoint.isDeploymentAuthorized, isFalse);
    expect(checkpoint.isBackupProtected, isTrue);
    expect(checkpoint.isFirstRealWiringApproved, isFalse);
    expect(checkpoint.blocksAutomaticWiring, isTrue);
    expect(
      checkpoint.currentStatus,
      containsAll(<Object>[
        CallV2ProductionFirstWiringCheckpointStatus.phase6DesignWallAccepted,
        CallV2ProductionFirstWiringCheckpointStatus.rolloutFalse,
        CallV2ProductionFirstWiringCheckpointStatus.callV2Unreachable,
        CallV2ProductionFirstWiringCheckpointStatus.routeRegistryDisabled,
        CallV2ProductionFirstWiringCheckpointStatus.disabledOwnerInert,
        CallV2ProductionFirstWiringCheckpointStatus.runtimeNotStarted,
        CallV2ProductionFirstWiringCheckpointStatus.backendFirebaseDisconnected,
        CallV2ProductionFirstWiringCheckpointStatus.rtcPermissionDisconnected,
        CallV2ProductionFirstWiringCheckpointStatus.appRouterDisconnected,
        CallV2ProductionFirstWiringCheckpointStatus.mainStartupDisconnected,
        CallV2ProductionFirstWiringCheckpointStatus.noDeploymentAuthorized,
        CallV2ProductionFirstWiringCheckpointStatus.backupProtected,
        CallV2ProductionFirstWiringCheckpointStatus
            .firstRealWiringNotApprovedYet,
      ]),
    );
  });

  test('checkpoint lists all accepted Phase 6 design packages', () {
    expect(
      checkpoint.acceptedDesignPackages,
      <CallV2ProductionAcceptedDesignPackage>[
        CallV2ProductionAcceptedDesignPackage.humanApprovalPackage,
        CallV2ProductionAcceptedDesignPackage.preRolloutReadinessAudit,
        CallV2ProductionAcceptedDesignPackage.securityPrivacyAudit,
        CallV2ProductionAcceptedDesignPackage.stagedRolloutDesign,
        CallV2ProductionAcceptedDesignPackage.routeRegistrationDesign,
        CallV2ProductionAcceptedDesignPackage.lifecycleObserverDesign,
        CallV2ProductionAcceptedDesignPackage.navigatorWiringDesign,
        CallV2ProductionAcceptedDesignPackage.runtimeStartupDesign,
        CallV2ProductionAcceptedDesignPackage.backendFirebaseDesign,
        CallV2ProductionAcceptedDesignPackage.rtcPermissionDesign,
      ],
    );
  });

  test('checkpoint lists all first wiring options and recommendations', () {
    expect(
      checkpoint.firstWiringOptions,
      <CallV2ProductionFirstWiringOption>[
        CallV2ProductionFirstWiringOption.noWiringKeepIsolated,
        CallV2ProductionFirstWiringOption
            .developerOnlyRouteRegistrationSkeleton,
        CallV2ProductionFirstWiringOption
            .developerOnlyLifecycleObserverSkeleton,
        CallV2ProductionFirstWiringOption.developerOnlyNavigatorOwnerSkeleton,
        CallV2ProductionFirstWiringOption
            .developerOnlyRuntimeStartupOwnerSkeleton,
        CallV2ProductionFirstWiringOption
            .developerOnlyBackendFirebaseOwnerSkeleton,
        CallV2ProductionFirstWiringOption
            .developerOnlyRtcPermissionOwnerSkeleton,
      ],
    );
    expect(
      checkpoint.recommendedFirstWiringOptions,
      <CallV2ProductionFirstWiringOption>[
        CallV2ProductionFirstWiringOption
            .developerOnlyRouteRegistrationSkeleton,
        CallV2ProductionFirstWiringOption.noWiringKeepIsolated,
      ],
    );
    expect(checkpoint.requiresExplicitHumanChoice, isTrue);
  });

  test('checkpoint blocks unsafe actions without separate approval', () {
    expect(
      checkpoint.blockedActions,
      containsAll(<Object>[
        CallV2ProductionFirstWiringBlockedAction.enableRollout,
        CallV2ProductionFirstWiringBlockedAction.exposePublicUsers,
        CallV2ProductionFirstWiringBlockedAction.contactProductionServices,
        CallV2ProductionFirstWiringBlockedAction.deploy,
        CallV2ProductionFirstWiringBlockedAction.makeRoutesReachable,
        CallV2ProductionFirstWiringBlockedAction.directAppRouterRegistration,
        CallV2ProductionFirstWiringBlockedAction.directMainDartWiring,
        CallV2ProductionFirstWiringBlockedAction.constructStartupRuntime,
        CallV2ProductionFirstWiringBlockedAction.registerLifecycleObserver,
        CallV2ProductionFirstWiringBlockedAction.wireNavigatorOrAppKey,
        CallV2ProductionFirstWiringBlockedAction.openBackendFirebaseListeners,
        CallV2ProductionFirstWiringBlockedAction.initializeRtcEngine,
        CallV2ProductionFirstWiringBlockedAction.promptPermissions,
        CallV2ProductionFirstWiringBlockedAction.changePlatformOrPubspec,
      ]),
    );
  });

  test('checkpoint requires approval rollback kill-switch and validation gates',
      () {
    expect(
      checkpoint.approvalRequirements,
      containsAll(<Object>[
        CallV2ProductionFirstWiringApprovalRequirement
            .exactFirstWiringOptionSelectedByHuman,
        CallV2ProductionFirstWiringApprovalRequirement.exactAllowedFilesListed,
        CallV2ProductionFirstWiringApprovalRequirement
            .exactRollbackCommandOrRevertPlanListed,
        CallV2ProductionFirstWiringApprovalRequirement
            .killSwitchBehaviorDefined,
        CallV2ProductionFirstWiringApprovalRequirement
            .developerOnlyAllowlistBehaviorDefined,
        CallV2ProductionFirstWiringApprovalRequirement
            .noProductionServiceContact,
        CallV2ProductionFirstWiringApprovalRequirement.noPublicUserExposure,
        CallV2ProductionFirstWiringApprovalRequirement.noSensitiveLogs,
        CallV2ProductionFirstWiringApprovalRequirement.v1SmokePlanAccepted,
        CallV2ProductionFirstWiringApprovalRequirement
            .acceptedBackendEmulatorFlakeRecorded,
        CallV2ProductionFirstWiringApprovalRequirement.oneCommitOnly,
        CallV2ProductionFirstWiringApprovalRequirement
            .backupBranchVerifiedUnchanged,
      ]),
    );
    expect(
      checkpoint.killSwitchRequirements,
      containsAll(<Object>[
        CallV2ProductionFirstWiringKillSwitchRequirement.rolloutFalseByDefault,
        CallV2ProductionFirstWiringKillSwitchRequirement
            .routeRegistryNullWhileFalse,
        CallV2ProductionFirstWiringKillSwitchRequirement
            .disabledOwnerInertWhileFalse,
        CallV2ProductionFirstWiringKillSwitchRequirement
            .noRuntimeStartWhileFalse,
        CallV2ProductionFirstWiringKillSwitchRequirement
            .noBackendFirebaseRtcPermissionAccessWhileFalse,
        CallV2ProductionFirstWiringKillSwitchRequirement.oneCommitRollback,
        CallV2ProductionFirstWiringKillSwitchRequirement
            .emergencyDisablePathDocumented,
      ]),
    );
    expect(
      checkpoint.rollbackRequirements,
      containsAll(<Object>[
        CallV2ProductionFirstWiringRollbackRequirement.oneCommitRevert,
        CallV2ProductionFirstWiringRollbackRequirement.preserveRolloutFalse,
        CallV2ProductionFirstWiringRollbackRequirement
            .preserveRouteRegistryDisabledNull,
        CallV2ProductionFirstWiringRollbackRequirement
            .preserveDisabledOwnerInert,
        CallV2ProductionFirstWiringRollbackRequirement
            .removeSelectedDeveloperOnlyWiring,
        CallV2ProductionFirstWiringRollbackRequirement
            .verifyBackupBranchUnchanged,
        CallV2ProductionFirstWiringRollbackRequirement
            .noDeploymentRequiredForRollback,
      ]),
    );
    expect(
      checkpoint.validationRequirements,
      containsAll(<Object>[
        CallV2ProductionFirstWiringValidationRequirement
            .focusedTestsForSelectedWiring,
        CallV2ProductionFirstWiringValidationRequirement.allCallV2DesignTests,
        CallV2ProductionFirstWiringValidationRequirement
            .allCallV2IntegrationTests,
        CallV2ProductionFirstWiringValidationRequirement.allCallV2UiTests,
        CallV2ProductionFirstWiringValidationRequirement
            .productionCompositionTests,
        CallV2ProductionFirstWiringValidationRequirement.finalReadinessTests,
        CallV2ProductionFirstWiringValidationRequirement.allCallV2Tests,
        CallV2ProductionFirstWiringValidationRequirement.backendCheck,
        CallV2ProductionFirstWiringValidationRequirement.deploymentValidation,
        CallV2ProductionFirstWiringValidationRequirement.rulesTests,
        CallV2ProductionFirstWiringValidationRequirement
            .focusedAcceptedEmulatorRaceTest,
        CallV2ProductionFirstWiringValidationRequirement
            .fullEmulatorSuitePassesOrAcceptedFlakeRecorded,
        CallV2ProductionFirstWiringValidationRequirement.fullFlutterAnalyze,
        CallV2ProductionFirstWiringValidationRequirement.gitDiffCheck,
      ]),
    );
  });

  test('checkpoint records accepted emulator flake details', () {
    expect(
      checkpoint.acceptedFlakes,
      <CallV2ProductionFirstWiringAcceptedFlake>[
        CallV2ProductionFirstWiringAcceptedFlake
            .fullBackendEmulatorSuiteRaceAcceptedByHumanForPhase6Z,
        CallV2ProductionFirstWiringAcceptedFlake
            .timeoutLifecycleRacesProduceOneAuthoritativeOutcome,
        CallV2ProductionFirstWiringAcceptedFlake.focusedIsolatedRaceTestPassed,
        CallV2ProductionFirstWiringAcceptedFlake
            .noBackendRulesFunctionsConfigDiff,
        CallV2ProductionFirstWiringAcceptedFlake
            .noPhase6ZBackendRuntimeReferences,
        CallV2ProductionFirstWiringAcceptedFlake
            .retryFullEmulatorInFutureRealWiringPhases,
      ],
    );
  });

  test('safe debug output exposes counts and no sensitive operational data',
      () {
    final debug = checkpoint.toSafeDebugMap();
    final debugText = '${checkpoint.toString()} $debug';

    expect(debug['currentStatusCount'], checkpoint.currentStatus.length);
    expect(debug['acceptedDesignPackageCount'],
        checkpoint.acceptedDesignPackages.length);
    expect(debug['firstRealWiringApproved'], isFalse);
    for (final forbidden in <String>[
      '/call-v2',
      'callId',
      'uid',
      'token',
      'credential',
      'channel',
      'device',
      'payload',
      'stack',
      'Firebase',
      'Rtc',
      'Navigator',
      'GlobalKey',
    ]) {
      expect(debugText.contains(forbidden), isFalse, reason: forbidden);
    }
  });

  test('real route and owner boundaries remain disabled and inert', () async {
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

    final owner = DisabledCallV2ProductionIntegrationOwner();
    await owner.initialize();

    expect(owner.status.rolloutEnabled, isFalse);
    expect(owner.status.compositionConstructed, isFalse);
    expect(owner.status.runtimeStarted, isFalse);
    expect(owner.status.routesRegistered, isFalse);
    expect(owner.status.screensAvailable, isFalse);
  });

  test('real app and production sources do not reference checkpoint', () {
    for (final path in <String>[
      'lib/main.dart',
      'lib/navigation/app_router.dart',
      'lib/call_v2/integration/call_v2_route_registry.dart',
      'lib/call_v2/integration/disabled_call_v2_route_registry.dart',
      'lib/call_v2/integration/disabled_call_v2_production_integration_owner.dart',
      'lib/call_v2/production/call_v2_production_composition.dart',
      'pubspec.yaml',
      'pubspec.lock',
      'firebase.json',
      'firestore.rules',
      'connect_functions/index.js',
    ]) {
      expect(
        _read(path),
        isNot(contains('call_v2_production_first_wiring_approval_checkpoint')),
        reason: path,
      );
    }
  });

  test('checkpoint source imports no runtime services and starts no async work',
      () {
    final source = _read(
      'lib/call_v2/design/'
      'call_v2_production_first_wiring_approval_checkpoint.dart',
    );

    for (final forbidden in <String>[
      'import ',
      'requestPermission',
      'Agora',
      'Navigator.',
      'GlobalKey(',
      'BuildContext ',
      'RouteSettings(',
      'Timer(',
      'StreamController',
      'StreamSubscription',
      'read(',
      'write(',
      'listen(',
    ]) {
      expect(source.contains(forbidden), isFalse, reason: forbidden);
    }
  });
}

String _read(String path) => File(path).readAsStringSync();
