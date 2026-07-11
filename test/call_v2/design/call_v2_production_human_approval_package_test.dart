import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/design/call_v2_production_human_approval_package.dart';
import 'package:connect_app/call_v2/design/call_v2_production_lifecycle_hookup_design.dart';
import 'package:connect_app/call_v2/design/call_v2_production_pre_rollout_readiness_audit.dart';
import 'package:connect_app/call_v2/design/call_v2_production_security_privacy_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_integration_status.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('package records no automatic wiring and closed rollout state', () {
    final package = callV2ProductionHumanApprovalPackage;

    expect(package.allowsAutomaticRealAppWiring, isFalse);
    expect(package.isRolloutEnabled, isFalse);
    expect(package.isDeploymentAuthorized, isFalse);
    expect(
      package.currentStatus,
      containsAll(<Object>[
        CallV2ProductionHumanApprovalStatus.noAutomaticRealAppWiring,
        CallV2ProductionHumanApprovalStatus.rolloutFalse,
        CallV2ProductionHumanApprovalStatus.deploymentNotAuthorized,
        CallV2ProductionHumanApprovalStatus.backupBranchProtected,
        CallV2ProductionHumanApprovalStatus.preRolloutNotReadyForUserRollout,
        CallV2ProductionHumanApprovalStatus.securityPrivacyAuditActive,
        CallV2ProductionHumanApprovalStatus.lifecycleHookupDesignOnly,
        CallV2ProductionHumanApprovalStatus.realAppWiringNotImplemented,
        CallV2ProductionHumanApprovalStatus.runtimeNotStarted,
        CallV2ProductionHumanApprovalStatus
            .backendFirebaseRtcPermissionsDisconnected,
      ]),
    );
  });

  test('package aligns with pre-rollout security and lifecycle audits', () {
    final preRollout = callV2ProductionPreRolloutReadinessAudit;
    final lifecycle = callV2ProductionLifecycleHookupDesign;
    final security = callV2ProductionSecurityPrivacyAudit;

    expect(preRollout.isReadyForUserRollout, isFalse);
    expect(preRollout.canWireRealAppWithoutApproval, isFalse);
    expect(lifecycle.isRealHookupImplemented, isFalse);
    expect(lifecycle.isLifecycleObserverRegistered, isFalse);
    expect(lifecycle.isRolloutEnabled, isFalse);
    expect(
      security.isolationConstraints,
      containsAll(<Object>[
        CallV2ProductionIsolationConstraint.rolloutDisabled,
        CallV2ProductionIsolationConstraint.noMainWiring,
        CallV2ProductionIsolationConstraint.noAppRouterWiring,
        CallV2ProductionIsolationConstraint.noRouteRegistryEnablement,
        CallV2ProductionIsolationConstraint
            .noFirebaseBackendRtcPermissionAccess,
      ]),
    );
  });

  test('package includes every human decision option and recommendation', () {
    final package = callV2ProductionHumanApprovalPackage;

    expect(
      package.decisionOptions,
      equals(<CallV2ProductionHumanDecisionOption>[
        CallV2ProductionHumanDecisionOption.keepIsolated,
        CallV2ProductionHumanDecisionOption.createStagedRolloutDesignOnly,
        CallV2ProductionHumanDecisionOption
            .prepareDeveloperOnlyLifecycleObserverDesign,
        CallV2ProductionHumanDecisionOption
            .prepareDeveloperOnlyRouteRegistrationDesign,
        CallV2ProductionHumanDecisionOption
            .prepareFirstRealWiringPrAfterExplicitApproval,
      ]),
    );
    expect(
      package.recommendedOptions,
      containsAll(<Object>[
        CallV2ProductionHumanApprovalRecommendation.stagedRolloutDesignOnly,
        CallV2ProductionHumanApprovalRecommendation
            .developerOnlyDesignPackageFirst,
        CallV2ProductionHumanApprovalRecommendation.noAutomaticRealAppWiring,
      ]),
    );
  });

  test('package blocks all real wiring actions without approval', () {
    expect(
      callV2ProductionHumanApprovalPackage.blockedActions,
      containsAll(<Object>[
        CallV2ProductionHumanApprovalBlockedAction.changeRolloutFlag,
        CallV2ProductionHumanApprovalBlockedAction.modifyMainDart,
        CallV2ProductionHumanApprovalBlockedAction.modifyAppStartup,
        CallV2ProductionHumanApprovalBlockedAction.modifyAppRouter,
        CallV2ProductionHumanApprovalBlockedAction.enableRouteRegistry,
        CallV2ProductionHumanApprovalBlockedAction
            .wireNavigatorAdapterToRealApp,
        CallV2ProductionHumanApprovalBlockedAction
            .constructProductionUiCompositionFromAppStartup,
        CallV2ProductionHumanApprovalBlockedAction.startRuntime,
        CallV2ProductionHumanApprovalBlockedAction.openBackendFirebaseListeners,
        CallV2ProductionHumanApprovalBlockedAction.initializeRtc,
        CallV2ProductionHumanApprovalBlockedAction.requestPermissions,
        CallV2ProductionHumanApprovalBlockedAction.deploy,
      ]),
    );
  });

  test(
      'package includes approval pre-wiring post-wiring and rollback checklists',
      () {
    final package = callV2ProductionHumanApprovalPackage;

    expect(
      package.approvalChecklist,
      containsAll(<Object>[
        CallV2ProductionHumanApprovalRequirement.humanApprovalRecorded,
        CallV2ProductionHumanApprovalRequirement.exactWiringScopeChosen,
        CallV2ProductionHumanApprovalRequirement.rollbackPathConfirmed,
        CallV2ProductionHumanApprovalRequirement.emergencyKillSwitchConfirmed,
        CallV2ProductionHumanApprovalRequirement
            .developerOnlyOrAllowlistStrategyDefined,
        CallV2ProductionHumanApprovalRequirement.noPublicUserRollout,
        CallV2ProductionHumanApprovalRequirement
            .noProductionServiceContactWithoutSeparateApproval,
        CallV2ProductionHumanApprovalRequirement.testPlanAccepted,
        CallV2ProductionHumanApprovalRequirement.backupBranchVerifiedUnchanged,
      ]),
    );
    expect(
      package.preWiringTests,
      containsAll(<Object>[
        CallV2ProductionHumanApprovalPreWiringTest.allCallV2FlutterTests,
        CallV2ProductionHumanApprovalPreWiringTest.allCallV2DesignTests,
        CallV2ProductionHumanApprovalPreWiringTest.allCallV2IntegrationTests,
        CallV2ProductionHumanApprovalPreWiringTest.allCallV2UiTests,
        CallV2ProductionHumanApprovalPreWiringTest.finalReadinessAudit,
        CallV2ProductionHumanApprovalPreWiringTest.securityPrivacyAudit,
        CallV2ProductionHumanApprovalPreWiringTest.backendRulesEmulatorChecks,
        CallV2ProductionHumanApprovalPreWiringTest.fullFlutterAnalyze,
        CallV2ProductionHumanApprovalPreWiringTest.v1SmokeChecksIfAvailable,
      ]),
    );
    expect(
      package.postWiringTests,
      containsAll(<Object>[
        CallV2ProductionHumanApprovalPostWiringTest.allPreWiringTestsAgain,
        CallV2ProductionHumanApprovalPostWiringTest
            .realObserverLifecycleTestsIfLifecycleChosen,
        CallV2ProductionHumanApprovalPostWiringTest
            .routeGatingTestsIfRouteChosen,
        CallV2ProductionHumanApprovalPostWiringTest.killSwitchRollbackTests,
        CallV2ProductionHumanApprovalPostWiringTest
            .noProductionServiceContactTests,
        CallV2ProductionHumanApprovalPostWiringTest.startupIsolationTests,
        CallV2ProductionHumanApprovalPostWiringTest.v1RegressionChecks,
      ]),
    );
    expect(
      package.rollbackChecklist,
      containsAll(<Object>[
        CallV2ProductionHumanApprovalRollbackItem.keepRolloutFalse,
        CallV2ProductionHumanApprovalRollbackItem
            .routeRegistryReturnsNullWhileFalse,
        CallV2ProductionHumanApprovalRollbackItem
            .disableOrRemoveNewWiringInOneCommit,
        CallV2ProductionHumanApprovalRollbackItem
            .keepDisabledOwnerInertUnlessApproved,
        CallV2ProductionHumanApprovalRollbackItem.noDeploymentWithoutApproval,
        CallV2ProductionHumanApprovalRollbackItem.backupBranchRemainsUnchanged,
      ]),
    );
  });

  test('package model is immutable and safe to debug', () {
    final package = callV2ProductionHumanApprovalPackage;

    expect(
      () => package.currentStatus.add(
        CallV2ProductionHumanApprovalStatus.noAutomaticRealAppWiring,
      ),
      throwsUnsupportedError,
    );

    final text = package.toString();
    expect(text, contains('currentStatusCount'));
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
      package.protectedBackupBranch,
      package.protectedBackupSha,
    ]) {
      expect(text, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('rollout and route registry remain disabled', () {
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

  test('real app entry points do not import approval package or bridges', () {
    final sources = <String, String>{
      'main.dart': File('lib/main.dart').readAsStringSync(),
      'app_router.dart':
          File('lib/navigation/app_router.dart').readAsStringSync(),
      'route registry': File(
        'lib/call_v2/integration/call_v2_route_registry.dart',
      ).readAsStringSync(),
      'production composition': File(
        'lib/call_v2/production/call_v2_production_composition.dart',
      ).readAsStringSync(),
    };

    for (final entry in sources.entries) {
      expect(
        entry.value,
        isNot(contains('call_v2_production_human_approval_package')),
        reason: entry.key,
      );
      expect(
        entry.value,
        isNot(contains('CallV2ProductionLifecycleBridge')),
        reason: entry.key,
      );
      expect(
        entry.value,
        isNot(contains('CallV2ProductionPermissionDeviceBridge')),
        reason: entry.key,
      );
      expect(
        entry.value,
        isNot(contains('CallV2ProductionCallStateBridge')),
        reason: entry.key,
      );
    }
  });

  test('app router remains disconnected from production Call V2 routes', () {
    final routerSource =
        File('lib/navigation/app_router.dart').readAsStringSync();

    for (final route in CallV2RouteNames.production) {
      expect(routerSource, isNot(contains(route)), reason: route);
    }
    expect(routerSource, isNot(contains('resolveCallV2Route')));
    expect(routerSource, isNot(contains('CallV2RouteNames')));
  });

  test('approval package and isolated bridges add no runtime dependencies', () {
    final source = _readFiles(<String>[
      'lib/call_v2/design/call_v2_production_human_approval_package.dart',
      ..._isolatedBridgeFiles,
    ]);

    for (final pattern in <Pattern>[
      RegExp(r'\bnavigatorKey\b'),
      RegExp(r'\bGlobalKey\s*[<(]'),
      RegExp(r'\bNavigatorState\s+_'),
      RegExp(r'\bBuildContext\s+_'),
      RegExp(r'\bTimer\s+_'),
      RegExp(r'\bStreamSubscription\b'),
      RegExp(r'\bStreamController\b'),
      RegExp(r"import\s+'package:firebase", caseSensitive: false),
      RegExp(r"import\s+'package:cloud_firestore", caseSensitive: false),
      RegExp(r"import\s+'package:cloud_functions", caseSensitive: false),
      RegExp(r"import\s+'.*agora", caseSensitive: false),
      RegExp(r"import\s+'.*rtc/", caseSensitive: false),
      RegExp(r"import\s+'.*permissions/", caseSensitive: false),
      RegExp(r"import\s+'package:permission_handler", caseSensitive: false),
      RegExp(r'connect_functions/'),
      RegExp(r'pubspec\\.'),
      RegExp(r'android/|ios/|macos/|windows/|linux/|web/'),
    ]) {
      expect(source, isNot(contains(pattern)), reason: pattern.toString());
    }
  });
}

const _isolatedBridgeFiles = <String>[
  'lib/call_v2/integration/call_v2_production_lifecycle_bridge.dart',
  'lib/call_v2/integration/call_v2_production_lifecycle_bridge_event.dart',
  'lib/call_v2/integration/call_v2_production_lifecycle_bridge_result.dart',
  'lib/call_v2/integration/call_v2_production_lifecycle_bridge_status.dart',
  'lib/call_v2/integration/call_v2_production_permission_device_bridge.dart',
  'lib/call_v2/integration/call_v2_production_permission_device_bridge_event.dart',
  'lib/call_v2/integration/call_v2_production_permission_device_bridge_result.dart',
  'lib/call_v2/integration/call_v2_production_permission_device_bridge_status.dart',
  'lib/call_v2/integration/call_v2_production_call_state_bridge.dart',
  'lib/call_v2/integration/call_v2_production_call_state_bridge_event.dart',
  'lib/call_v2/integration/call_v2_production_call_state_bridge_result.dart',
  'lib/call_v2/integration/call_v2_production_call_state_bridge_status.dart',
];

String _readFiles(Iterable<String> paths) {
  return paths.map((path) => File(path).readAsStringSync()).join('\n');
}
