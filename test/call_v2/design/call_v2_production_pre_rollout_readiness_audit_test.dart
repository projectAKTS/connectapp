import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
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
  test('audit says production Call V2 is not ready for rollout or wiring', () {
    final audit = callV2ProductionPreRolloutReadinessAudit;

    expect(audit.isReadyForUserRollout, isFalse);
    expect(audit.canWireRealAppWithoutApproval, isFalse);
    expect(
      audit.statuses,
      containsAll(<Object>[
        CallV2ProductionPreRolloutReadinessStatus.notReadyForUserRollout,
        CallV2ProductionPreRolloutReadinessStatus
            .notReadyForRealAppWiringWithoutApproval,
      ]),
    );
    expect(
      audit.nextPhaseRecommendation,
      containsAll(<Object>[
        CallV2ProductionPreRolloutNextPhaseRecommendation
            .humanApprovalPackageOrStagedRolloutDesignOnly,
        CallV2ProductionPreRolloutNextPhaseRecommendation
            .noAutomaticRealAppWiring,
      ]),
    );
  });

  test('audit includes accepted boundary inventory', () {
    expect(
      callV2ProductionPreRolloutReadinessAudit.acceptedBoundaryInventory,
      containsAll(<Object>[
        CallV2ProductionPreRolloutBoundaryInventory
            .disabledProductionIntegrationOwnerExists,
        CallV2ProductionPreRolloutBoundaryInventory.productionUiContractsExist,
        CallV2ProductionPreRolloutBoundaryInventory
            .productionPresentationMappingExists,
        CallV2ProductionPreRolloutBoundaryInventory.productionViewModelsExist,
        CallV2ProductionPreRolloutBoundaryInventory.isolatedScreenShellsExist,
        CallV2ProductionPreRolloutBoundaryInventory
            .productionScreenFactoryExists,
        CallV2ProductionPreRolloutBoundaryInventory
            .productionRouteObjectFactoryExists,
        CallV2ProductionPreRolloutBoundaryInventory.productionRouteSinkExists,
        CallV2ProductionPreRolloutBoundaryInventory
            .typedNavigatorAdapterBoundaryExists,
        CallV2ProductionPreRolloutBoundaryInventory.uiCompositionOwnerExists,
        CallV2ProductionPreRolloutBoundaryInventory.runtimeUiBridgeExists,
        CallV2ProductionPreRolloutBoundaryInventory.lifecycleBridgeExists,
        CallV2ProductionPreRolloutBoundaryInventory.lifecycleHookupDesignExists,
        CallV2ProductionPreRolloutBoundaryInventory
            .permissionDeviceBridgeExists,
        CallV2ProductionPreRolloutBoundaryInventory.callStateBridgeExists,
        CallV2ProductionPreRolloutBoundaryInventory.securityPrivacyAuditExists,
      ]),
    );
  });

  test('audit records current disabled state and no deployment', () {
    expect(
      callV2ProductionPreRolloutReadinessAudit.disabledState,
      containsAll(<Object>[
        CallV2ProductionPreRolloutDisabledState.rolloutFalse,
        CallV2ProductionPreRolloutDisabledState.routeRegistryDisabled,
        CallV2ProductionPreRolloutDisabledState
            .disabledRouteRegistryReturnsNull,
        CallV2ProductionPreRolloutDisabledState
            .appStartupIntegrationDisabledAndInert,
        CallV2ProductionPreRolloutDisabledState.noRealRouteRegistration,
        CallV2ProductionPreRolloutDisabledState.noProductionRuntimeStart,
        CallV2ProductionPreRolloutDisabledState.noProductionUiReachability,
        CallV2ProductionPreRolloutDisabledState
            .noBackendFirebaseRtcPermissionAccess,
        CallV2ProductionPreRolloutDisabledState.noDeployment,
      ]),
    );
  });

  test('audit lists manual approval gates blockers and test groups', () {
    final audit = callV2ProductionPreRolloutReadinessAudit;

    expect(
      audit.approvalGates,
      containsAll(<Object>[
        CallV2ProductionPreRolloutApprovalGate.lifecycleObserverRegistration,
        CallV2ProductionPreRolloutApprovalGate.startupMainChange,
        CallV2ProductionPreRolloutApprovalGate.routeRegistryEnablement,
        CallV2ProductionPreRolloutApprovalGate.navigatorAdapterWiringToRealApp,
        CallV2ProductionPreRolloutApprovalGate
            .productionUiCompositionConstruction,
        CallV2ProductionPreRolloutApprovalGate.runtimeConstruction,
        CallV2ProductionPreRolloutApprovalGate.backendFirebaseIntegration,
        CallV2ProductionPreRolloutApprovalGate.rtcIntegration,
        CallV2ProductionPreRolloutApprovalGate.permissionRequestIntegration,
        CallV2ProductionPreRolloutApprovalGate.rolloutFlagChange,
        CallV2ProductionPreRolloutApprovalGate.deployment,
      ]),
    );
    expect(
      audit.blockers,
      containsAll(<Object>[
        CallV2ProductionPreRolloutReadinessBlocker.noRealLifecycleObserverYet,
        CallV2ProductionPreRolloutReadinessBlocker.noRealRouteRegistrationYet,
        CallV2ProductionPreRolloutReadinessBlocker.noRuntimeWiringYet,
        CallV2ProductionPreRolloutReadinessBlocker
            .noBackendFirebaseConnectionYet,
        CallV2ProductionPreRolloutReadinessBlocker.noRtcConnectionYet,
        CallV2ProductionPreRolloutReadinessBlocker
            .noPermissionFlowConnectionYet,
        CallV2ProductionPreRolloutReadinessBlocker
            .appCheckDebugTokenLoggingBacklogOutsideCallV2,
        CallV2ProductionPreRolloutReadinessBlocker
            .chatRouteArgumentLoggingBacklogOutsideCallV2,
        CallV2ProductionPreRolloutReadinessBlocker
            .noStagedRolloutPlanImplementedYet,
      ]),
    );
    expect(
      audit.requiredTestGroups,
      containsAll(<Object>[
        CallV2ProductionPreRolloutRequiredTestGroup.allCallV2FlutterTests,
        CallV2ProductionPreRolloutRequiredTestGroup.allCallV2DesignTests,
        CallV2ProductionPreRolloutRequiredTestGroup.allCallV2IntegrationTests,
        CallV2ProductionPreRolloutRequiredTestGroup.allCallV2UiTests,
        CallV2ProductionPreRolloutRequiredTestGroup.finalReadinessAudit,
        CallV2ProductionPreRolloutRequiredTestGroup.backendCallV2Check,
        CallV2ProductionPreRolloutRequiredTestGroup.backendDeploymentValidation,
        CallV2ProductionPreRolloutRequiredTestGroup.firestoreRulesTests,
        CallV2ProductionPreRolloutRequiredTestGroup.emulatorTests,
        CallV2ProductionPreRolloutRequiredTestGroup.fullFlutterAnalyze,
        CallV2ProductionPreRolloutRequiredTestGroup
            .v1SmokeRegressionChecksIfAvailable,
      ]),
    );
  });

  test('audit records rollback controls backup protection and backlog findings',
      () {
    final audit = callV2ProductionPreRolloutReadinessAudit;

    expect(
      audit.rollbackControls,
      containsAll(<Object>[
        CallV2ProductionPreRolloutRollbackControl.backupBranchUnchanged,
        CallV2ProductionPreRolloutRollbackControl.rolloutFalse,
        CallV2ProductionPreRolloutRollbackControl
            .routeRegistryReturnsNullWhileFalse,
        CallV2ProductionPreRolloutRollbackControl
            .disabledOwnerInertUntilApproved,
        CallV2ProductionPreRolloutRollbackControl
            .emergencyKillSwitchRequiredBeforeUserRollout,
        CallV2ProductionPreRolloutRollbackControl
            .eachWiringPhaseOneCommitAndReversible,
        CallV2ProductionPreRolloutRollbackControl
            .noDeploymentWithoutExplicitApproval,
      ]),
    );
    expect(
      audit.protectedBackupBranch,
      'backup/call-v2-pre-phase6b-2026-07-04',
    );
    expect(
      audit.protectedBackupSha,
      '2a1ea8d6864ab0098d17c52bdf5ec70f66979e4d',
    );
    expect(
      audit.backlogFindings,
      equals(<CallV2ProductionPreRolloutBacklogFinding>[
        CallV2ProductionPreRolloutBacklogFinding
            .appCheckDebugTokenLoggingOutsideCallV2,
        CallV2ProductionPreRolloutBacklogFinding
            .chatRouteArgumentLoggingOutsideCallV2,
      ]),
    );
  });

  test('audit model is immutable and safe to debug', () {
    final audit = callV2ProductionPreRolloutReadinessAudit;

    expect(
      () => audit.statuses.add(
        CallV2ProductionPreRolloutReadinessStatus.notReadyForUserRollout,
      ),
      throwsUnsupportedError,
    );

    final text = audit.toString();
    expect(text, contains('acceptedBoundaryInventoryCount'));
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
      audit.protectedBackupBranch,
      audit.protectedBackupSha,
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

  test('disabled integration owner remains inert', () async {
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
    expect(owner.status.runtimeStarted, isFalse);
    expect(owner.status.routesRegistered, isFalse);
  });

  test('real app entry points remain disconnected from Call V2 bridges', () {
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

  test('isolated route registry does not reference new bridges', () {
    final source = File(
      'lib/call_v2/integration/call_v2_route_registry.dart',
    ).readAsStringSync();

    for (final forbidden in <String>[
      'CallV2ProductionLifecycleBridge',
      'CallV2ProductionPermissionDeviceBridge',
      'CallV2ProductionCallStateBridge',
      'CallV2ProductionRuntimeUiBridge',
      'CallV2ProductionUiCompositionOwner',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('no navigator key context timer subscription or service imports added',
      () {
    final bridgeSources = _readFiles(_isolatedBridgeFiles);

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
    ]) {
      expect(bridgeSources, isNot(contains(pattern)),
          reason: pattern.toString());
    }
  });

  test('security audit and lifecycle hookup design remain in force', () {
    expect(
      callV2ProductionSecurityPrivacyAudit.allowedRouteNames,
      equals(CallV2RouteNames.production),
    );
    expect(
      callV2ProductionSecurityPrivacyAudit.routePayloadRules,
      containsAll(<Object>[
        CallV2ProductionRoutePayloadRule.fixedCanonicalRouteNamesOnly,
        CallV2ProductionRoutePayloadRule.routeSettingsArgumentsNull,
      ]),
    );
    expect(
      callV2ProductionSecurityPrivacyAudit.backlogFindings,
      containsAll(<Object>[
        CallV2ProductionBacklogFinding.appCheckDebugTokenLoggingOutsideCallV2,
        CallV2ProductionBacklogFinding.chatRouteArgumentLoggingOutsideCallV2,
      ]),
    );

    final lifecycleDesign = callV2ProductionLifecycleHookupDesign;
    expect(lifecycleDesign.isRealHookupImplemented, isFalse);
    expect(lifecycleDesign.isLifecycleObserverRegistered, isFalse);
    expect(lifecycleDesign.isRolloutEnabled, isFalse);
    expect(
      lifecycleDesign.notWiredProofs,
      containsAll(<Object>[
        CallV2ProductionLifecycleNotWiredProof.noLifecycleObserverRegistration,
        CallV2ProductionLifecycleNotWiredProof.noRuntimeStart,
        CallV2ProductionLifecycleNotWiredProof
            .noFirebaseBackendRtcPermissionAccess,
      ]),
    );
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
