import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/design/call_v2_production_human_approval_package.dart';
import 'package:connect_app/call_v2/design/call_v2_production_lifecycle_hookup_design.dart';
import 'package:connect_app/call_v2/design/call_v2_production_pre_rollout_readiness_audit.dart';
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
  test('design records the current closed rollout state', () {
    final design = callV2ProductionStagedRolloutDesign;

    expect(design.isRolloutEnabled, isFalse);
    expect(design.isCallV2Reachable, isFalse);
    expect(design.isDeploymentAuthorized, isFalse);
    expect(design.hasPublicRolloutApproval, isFalse);
    expect(
      design.currentStatus,
      containsAll(<Object>[
        CallV2ProductionStagedRolloutStatus.rolloutFlagFalse,
        CallV2ProductionStagedRolloutStatus.callV2Unreachable,
        CallV2ProductionStagedRolloutStatus.routeRegistryDisabled,
        CallV2ProductionStagedRolloutStatus.disabledOwnerInert,
        CallV2ProductionStagedRolloutStatus.runtimeNotStarted,
        CallV2ProductionStagedRolloutStatus
            .backendFirebaseRtcPermissionsDisconnected,
        CallV2ProductionStagedRolloutStatus.deploymentNotAuthorized,
        CallV2ProductionStagedRolloutStatus.noPublicRolloutApproved,
      ]),
    );
  });

  test('design lists every staged rollout stage as design-only', () {
    final design = callV2ProductionStagedRolloutDesign;

    expect(design.stagesAreDesignOnly, isTrue);
    expect(design.allowsAutomaticWiring, isFalse);
    expect(
      design.rolloutStages,
      equals(<CallV2ProductionStagedRolloutStage>[
        CallV2ProductionStagedRolloutStage.keepIsolatedNoRollout,
        CallV2ProductionStagedRolloutStage.developerOnlyDesignReview,
        CallV2ProductionStagedRolloutStage
            .developerOnlyRealWiringPrAfterExplicitApproval,
        CallV2ProductionStagedRolloutStage.developerOnlyLocalInternalTestGate,
        CallV2ProductionStagedRolloutStage.smallInternalAllowlistGate,
        CallV2ProductionStagedRolloutStage.audioOnlyLimitedCohortGate,
        CallV2ProductionStagedRolloutStage.videoLimitedCohortGate,
        CallV2ProductionStagedRolloutStage.percentageRolloutGate,
        CallV2ProductionStagedRolloutStage.broaderRolloutGate,
        CallV2ProductionStagedRolloutStage.postRolloutMonitoringGate,
      ]),
    );
  });

  test('design lists required gates before any stage beyond design', () {
    expect(
      callV2ProductionStagedRolloutDesign.gatesBeforeAnyWiring,
      containsAll(<Object>[
        CallV2ProductionStagedRolloutGate.explicitHumanApproval,
        CallV2ProductionStagedRolloutGate.exactScopeSelected,
        CallV2ProductionStagedRolloutGate.emergencyKillSwitchDefined,
        CallV2ProductionStagedRolloutGate.rollbackPlanAccepted,
        CallV2ProductionStagedRolloutGate.backupVerifiedUnchanged,
        CallV2ProductionStagedRolloutGate.rolloutRemainsFalseUntilApproved,
        CallV2ProductionStagedRolloutGate
            .noProductionServiceContactWithoutApproval,
        CallV2ProductionStagedRolloutGate.allCallV2TestsPassed,
        CallV2ProductionStagedRolloutGate.backendRulesEmulatorChecksPassed,
        CallV2ProductionStagedRolloutGate.securityPrivacyAuditPassed,
        CallV2ProductionStagedRolloutGate.preRolloutReadinessAccepted,
        CallV2ProductionStagedRolloutGate.v1SmokeRegressionPlanAccepted,
      ]),
    );
  });

  test('design lists required rollout blockers and known backlog', () {
    expect(
      callV2ProductionStagedRolloutDesign.blockers,
      containsAll(<Object>[
        CallV2ProductionStagedRolloutBlocker.noRealLifecycleObserverYet,
        CallV2ProductionStagedRolloutBlocker.noRouteRegistrationYet,
        CallV2ProductionStagedRolloutBlocker.noRuntimeWiringYet,
        CallV2ProductionStagedRolloutBlocker.noBackendFirebaseConnectionYet,
        CallV2ProductionStagedRolloutBlocker.noRtcConnectionYet,
        CallV2ProductionStagedRolloutBlocker.noPermissionFlowConnectionYet,
        CallV2ProductionStagedRolloutBlocker.noKillSwitchImplementationYet,
        CallV2ProductionStagedRolloutBlocker.noAllowlistImplementationYet,
        CallV2ProductionStagedRolloutBlocker.noProductionMonitoringPlanYet,
        CallV2ProductionStagedRolloutBlocker
            .appCheckDebugTokenLoggingBacklogOutsideCallV2,
        CallV2ProductionStagedRolloutBlocker
            .chatRouteLoggingBacklogOutsideCallV2,
      ]),
    );
  });

  test('design lists rollback controls', () {
    expect(
      callV2ProductionStagedRolloutDesign.rollbackControls,
      containsAll(<Object>[
        CallV2ProductionStagedRolloutRollbackControl.oneCommitPerWiringPhase,
        CallV2ProductionStagedRolloutRollbackControl.rolloutFalseByDefault,
        CallV2ProductionStagedRolloutRollbackControl
            .routeRegistryReturnsNullWhileFalse,
        CallV2ProductionStagedRolloutRollbackControl
            .killSwitchCanDisableImmediately,
        CallV2ProductionStagedRolloutRollbackControl
            .disableOrRemoveNewWiringInOneCommit,
        CallV2ProductionStagedRolloutRollbackControl
            .noDeploymentWithoutApproval,
        CallV2ProductionStagedRolloutRollbackControl.backupBranchProtected,
        CallV2ProductionStagedRolloutRollbackControl.v1Unaffected,
      ]),
    );
  });

  test('design lists monitoring and privacy requirements', () {
    expect(
      callV2ProductionStagedRolloutDesign.monitoringRequirements,
      containsAll(<Object>[
        CallV2ProductionStagedRolloutMonitoringRequirement
            .noSensitiveIdsTokensChannelsCredentialsInLogs,
        CallV2ProductionStagedRolloutMonitoringRequirement
            .controlledEventCountersOnly,
        CallV2ProductionStagedRolloutMonitoringRequirement.crashErrorRateWatch,
        CallV2ProductionStagedRolloutMonitoringRequirement
            .callStartConnectEndFailureAggregateCountersOnly,
        CallV2ProductionStagedRolloutMonitoringRequirement.noRawBackendPayloads,
        CallV2ProductionStagedRolloutMonitoringRequirement
            .noRouteArgumentLogging,
        CallV2ProductionStagedRolloutMonitoringRequirement.noDebugTokenLeakage,
        CallV2ProductionStagedRolloutMonitoringRequirement
            .manualReviewBeforeAnalyticsOrLogging,
      ]),
    );
  });

  test('design lists V1 protection requirements', () {
    expect(
      callV2ProductionStagedRolloutDesign.v1Protections,
      containsAll(<Object>[
        CallV2ProductionStagedRolloutV1Protection.noV1RouteChanges,
        CallV2ProductionStagedRolloutV1Protection.noV1CallFlowChanges,
        CallV2ProductionStagedRolloutV1Protection
            .noChatRouteBehaviorChangesInRolloutDesign,
        CallV2ProductionStagedRolloutV1Protection
            .v1SmokeTestsBeforeAndAfterWiring,
        CallV2ProductionStagedRolloutV1Protection
            .immediateRollbackIfV1RegressionDetected,
      ]),
    );
  });

  test('design requires explicit approval kill switch and allowlist', () {
    expect(
      callV2ProductionStagedRolloutDesign.approvalRequirements,
      containsAll(<Object>[
        CallV2ProductionStagedRolloutApprovalRequirement
            .realWiringRequiresSeparateExplicitHumanApproval,
        CallV2ProductionStagedRolloutApprovalRequirement
            .publicUserRolloutRequiresDeveloperAndAllowlistSuccess,
        CallV2ProductionStagedRolloutApprovalRequirement
            .productionServiceContactRequiresSeparateApproval,
        CallV2ProductionStagedRolloutApprovalRequirement
            .emergencyKillSwitchRequiredBeforeUserExposure,
        CallV2ProductionStagedRolloutApprovalRequirement
            .allowlistRequiredBeforeUserExposure,
        CallV2ProductionStagedRolloutApprovalRequirement
            .everyFutureStageOneCommitAndReversible,
      ]),
    );
  });

  test(
      'design aligns with existing approval readiness security and lifecycle data',
      () {
    final design = callV2ProductionStagedRolloutDesign;
    final approval = callV2ProductionHumanApprovalPackage;
    final readiness = callV2ProductionPreRolloutReadinessAudit;
    final security = callV2ProductionSecurityPrivacyAudit;
    final lifecycle = callV2ProductionLifecycleHookupDesign;

    expect(approval.allowsAutomaticRealAppWiring, isFalse);
    expect(approval.isRolloutEnabled, isFalse);
    expect(readiness.isReadyForUserRollout, isFalse);
    expect(readiness.canWireRealAppWithoutApproval, isFalse);
    expect(lifecycle.isRealHookupImplemented, isFalse);
    expect(lifecycle.isLifecycleObserverRegistered, isFalse);
    expect(lifecycle.isRolloutEnabled, isFalse);
    expect(
      security.isolationConstraints,
      contains(CallV2ProductionIsolationConstraint.rolloutDisabled),
    );
    expect(
      design.recommendedNextSteps,
      containsAll(<Object>[
        CallV2ProductionStagedRolloutRecommendation.noRealWiringYet,
        CallV2ProductionStagedRolloutRecommendation
            .prepareExplicitHumanDecisionForOneDesignOnlyPackage,
        CallV2ProductionStagedRolloutRecommendation
            .prepareDeveloperOnlyWiringPrOnlyAfterApproval,
      ]),
    );
  });

  test('design model is immutable and safe to debug', () {
    final design = callV2ProductionStagedRolloutDesign;

    expect(
      () => design.currentStatus.add(
        CallV2ProductionStagedRolloutStatus.rolloutFlagFalse,
      ),
      throwsUnsupportedError,
    );
    expect(
      () => design.rolloutStages.add(
        CallV2ProductionStagedRolloutStage.keepIsolatedNoRollout,
      ),
      throwsUnsupportedError,
    );

    final text = design.toString();
    expect(text, contains('rolloutStageCount'));
    expect(text, contains('stagesAreDesignOnly'));
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
    expect(owner.status.compositionConstructed, isFalse);
    expect(owner.status.runtimeStarted, isFalse);
    expect(owner.status.routesRegistered, isFalse);
    expect(owner.status.screensAvailable, isFalse);
    await expectLater(
      owner.start(),
      throwsA(isA<CallV2ClientError>().having(
        (error) => error.code,
        'code',
        CallV2ClientErrorCode.rejected,
      )),
    );
  });

  test('real app files remain disconnected from staged rollout design', () {
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
        isNot(contains('call_v2_production_staged_rollout_design')),
        reason: entry.key,
      );
      expect(
        entry.value,
        isNot(contains('CallV2ProductionStagedRolloutDesign')),
        reason: entry.key,
      );
      expect(
        entry.value,
        isNot(contains('CallV2ProductionLifecycleBridge')),
        reason: entry.key,
      );
    }
  });

  test('app router remains disconnected from production Call V2 routes', () {
    final appRouter = _read('lib/navigation/app_router.dart');

    expect(appRouter, isNot(contains('/call-v2/')));
    expect(appRouter, isNot(contains('CallV2RouteNames')));
    expect(appRouter, isNot(contains('resolveCallV2Route')));
  });

  test('new design introduces no navigation runtime or service wiring', () {
    final source = _read(
      'lib/call_v2/design/call_v2_production_staged_rollout_design.dart',
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
      'Navigator',
      'RouteSettings',
      'GlobalKey',
      'BuildContext',
      'Timer',
      'Stream',
      'Subscription',
      'AppLifecycleListener',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('dependency platform and config files remain unrelated to Phase 6T', () {
    final sources = <String, String>{
      'pubspec.yaml': _read('pubspec.yaml'),
      'firebase.json': _read('firebase.json'),
      'index.js': _read('connect_functions/index.js'),
    };

    for (final entry in sources.entries) {
      expect(
        entry.value,
        isNot(contains('call_v2_production_staged_rollout_design')),
        reason: entry.key,
      );
      expect(
        entry.value,
        isNot(contains('CallV2ProductionStagedRolloutDesign')),
        reason: entry.key,
      );
    }
  });
}

String _read(String path) => File(path).readAsStringSync();
