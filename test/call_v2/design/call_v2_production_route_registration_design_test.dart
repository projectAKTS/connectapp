import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/design/call_v2_production_human_approval_package.dart';
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
  test('design records current route registration status as disabled', () {
    final design = callV2ProductionRouteRegistrationDesign;

    expect(design.isRouteRegistrationImplemented, isFalse);
    expect(design.isRolloutEnabled, isFalse);
    expect(design.isCallV2Reachable, isFalse);
    expect(design.isDeploymentAuthorized, isFalse);
    expect(
      design.currentStatus,
      containsAll(<Object>[
        CallV2ProductionRouteRegistrationStatus
            .noRealRouteRegistrationImplemented,
        CallV2ProductionRouteRegistrationStatus.routeRegistryDisabled,
        CallV2ProductionRouteRegistrationStatus.rolloutFalse,
        CallV2ProductionRouteRegistrationStatus.appRouterDisconnected,
        CallV2ProductionRouteRegistrationStatus.mainStartupDisconnected,
        CallV2ProductionRouteRegistrationStatus
            .disabledRouteRegistryReturnsNull,
        CallV2ProductionRouteRegistrationStatus.callV2Unreachable,
        CallV2ProductionRouteRegistrationStatus.deploymentNotAuthorized,
      ]),
    );
  });

  test('design lists allowed future locations only after approval', () {
    expect(
      callV2ProductionRouteRegistrationDesign.allowedFutureLocations,
      equals(<CallV2ProductionRouteRegistrationAllowedLocation>[
        CallV2ProductionRouteRegistrationAllowedLocation
            .isolatedCallV2RouteRegistryImplementation,
        CallV2ProductionRouteRegistrationAllowedLocation
            .isolatedAppStartupBoundaryOnlyIfApproved,
        CallV2ProductionRouteRegistrationAllowedLocation
            .developerOnlyRouteRegistrationPrOnly,
      ]),
    );
  });

  test('design forbids app router direct registration and V1 route files', () {
    expect(
      callV2ProductionRouteRegistrationDesign.forbiddenLocations,
      containsAll(<Object>[
        CallV2ProductionRouteRegistrationForbiddenLocation
            .appRouterDirectRegistration,
        CallV2ProductionRouteRegistrationForbiddenLocation.mainDart,
        CallV2ProductionRouteRegistrationForbiddenLocation.startup,
        CallV2ProductionRouteRegistrationForbiddenLocation.v1RouteFiles,
        CallV2ProductionRouteRegistrationForbiddenLocation
            .materialAppRouteTable,
      ]),
    );
  });

  test('design forbids unsafe route registration actions', () {
    expect(
      callV2ProductionRouteRegistrationDesign.forbiddenActions,
      containsAll(<Object>[
        CallV2ProductionRouteRegistrationForbiddenAction.changeRolloutFlag,
        CallV2ProductionRouteRegistrationForbiddenAction
            .registerMaterialAppRoutes,
        CallV2ProductionRouteRegistrationForbiddenAction.addDynamicRouteNames,
        CallV2ProductionRouteRegistrationForbiddenAction.addRouteArguments,
        CallV2ProductionRouteRegistrationForbiddenAction
            .addRouteIdsTokensChannelsCredentials,
        CallV2ProductionRouteRegistrationForbiddenAction.constructRuntime,
        CallV2ProductionRouteRegistrationForbiddenAction
            .contactBackendFirebaseRtcPermissions,
        CallV2ProductionRouteRegistrationForbiddenAction.deploy,
      ]),
    );
  });

  test('design lists fixed canonical production route safety only', () {
    final rules = callV2ProductionRouteRegistrationDesign.routeSafetyRules;

    expect(
      rules,
      containsAll(<Object>[
        CallV2ProductionRouteRegistrationRouteSafetyRule
            .fixedCanonicalRoutesOnly,
        CallV2ProductionRouteRegistrationRouteSafetyRule.connectingRoute,
        CallV2ProductionRouteRegistrationRouteSafetyRule.audioRoute,
        CallV2ProductionRouteRegistrationRouteSafetyRule.videoRoute,
        CallV2ProductionRouteRegistrationRouteSafetyRule.failureRoute,
        CallV2ProductionRouteRegistrationRouteSafetyRule
            .readyRouteIsNotProduction,
        CallV2ProductionRouteRegistrationRouteSafetyRule
            .routeSettingsArgumentsNullOnly,
        CallV2ProductionRouteRegistrationRouteSafetyRule.noQuery,
        CallV2ProductionRouteRegistrationRouteSafetyRule.noFragment,
        CallV2ProductionRouteRegistrationRouteSafetyRule.noDynamicPathSegments,
        CallV2ProductionRouteRegistrationRouteSafetyRule
            .noIdsTokensChannelsCredentials,
        CallV2ProductionRouteRegistrationRouteSafetyRule.noUnrelatedV1RoutePop,
        CallV2ProductionRouteRegistrationRouteSafetyRule
            .routeRegistryReturnsNullWhileRolloutFalse,
      ]),
    );
    expect(CallV2RouteNames.production, hasLength(4));
    expect(
      CallV2RouteNames.production,
      equals(<String>{
        '/call-v2/connecting',
        '/call-v2/audio',
        '/call-v2/video',
        '/call-v2/failure',
      }),
    );
    expect(CallV2RouteNames.production, isNot(contains('/call-v2/ready')));
  });

  test('design requires developer gates allowlist kill switch and V1 plan', () {
    expect(
      callV2ProductionRouteRegistrationDesign.gates,
      containsAll(<Object>[
        CallV2ProductionRouteRegistrationGate.explicitHumanApproval,
        CallV2ProductionRouteRegistrationGate.developerOnlyGate,
        CallV2ProductionRouteRegistrationGate.allowlistGateBeforeAnyUser,
        CallV2ProductionRouteRegistrationGate.emergencyKillSwitch,
        CallV2ProductionRouteRegistrationGate.rolloutFalseUntilApproved,
        CallV2ProductionRouteRegistrationGate.noProductionServiceContact,
        CallV2ProductionRouteRegistrationGate.allTests,
        CallV2ProductionRouteRegistrationGate.securityPrivacyAudit,
        CallV2ProductionRouteRegistrationGate.stagedRolloutDesignAccepted,
        CallV2ProductionRouteRegistrationGate.v1SmokePlan,
      ]),
    );
  });

  test('design lists rollback controls and V1 protections', () {
    final design = callV2ProductionRouteRegistrationDesign;

    expect(
      design.rollbackControls,
      containsAll(<Object>[
        CallV2ProductionRouteRegistrationRollback.oneCommit,
        CallV2ProductionRouteRegistrationRollback.routeRegistryDisabledNull,
        CallV2ProductionRouteRegistrationRollback.rolloutFalse,
        CallV2ProductionRouteRegistrationRollback.removeNewRegistrationOwner,
        CallV2ProductionRouteRegistrationRollback
            .appRouterRemainsUnchangedIfPossible,
        CallV2ProductionRouteRegistrationRollback.noDeploymentWithoutApproval,
        CallV2ProductionRouteRegistrationRollback.backupBranchProtected,
      ]),
    );
    expect(
      design.v1Protections,
      containsAll(<Object>[
        CallV2ProductionRouteRegistrationV1Protection.noV1RouteFileChanges,
        CallV2ProductionRouteRegistrationV1Protection.noV1RouteBehaviorChanges,
        CallV2ProductionRouteRegistrationV1Protection.noV1CallFlowChanges,
        CallV2ProductionRouteRegistrationV1Protection
            .noChatRouteBehaviorChanges,
        CallV2ProductionRouteRegistrationV1Protection
            .v1SmokeBeforeAndAfterAnyRouteRegistration,
        CallV2ProductionRouteRegistrationV1Protection
            .immediateRollbackOnV1Regression,
      ]),
    );
  });

  test('design aligns with staged rollout approval readiness and privacy data',
      () {
    final route = callV2ProductionRouteRegistrationDesign;
    final staged = callV2ProductionStagedRolloutDesign;
    final approval = callV2ProductionHumanApprovalPackage;
    final readiness = callV2ProductionPreRolloutReadinessAudit;
    final security = callV2ProductionSecurityPrivacyAudit;

    expect(route.allowsAutomaticWiring, isFalse);
    expect(staged.allowsAutomaticWiring, isFalse);
    expect(staged.isRolloutEnabled, isFalse);
    expect(approval.allowsAutomaticRealAppWiring, isFalse);
    expect(readiness.canWireRealAppWithoutApproval, isFalse);
    expect(
      security.routePayloadRules,
      containsAll(<Object>[
        CallV2ProductionRoutePayloadRule.fixedCanonicalRouteNamesOnly,
        CallV2ProductionRoutePayloadRule.routeSettingsArgumentsNull,
        CallV2ProductionRoutePayloadRule.noDynamicIdentifierSegments,
        CallV2ProductionRoutePayloadRule.noQueryOrFragment,
        CallV2ProductionRoutePayloadRule.noCredentialOrTokenMaterial,
      ]),
    );
  });

  test('design lists required validation coverage', () {
    expect(
      callV2ProductionRouteRegistrationDesign.testRequirements,
      containsAll(<Object>[
        CallV2ProductionRouteRegistrationTestRequirement.phase6UTests,
        CallV2ProductionRouteRegistrationTestRequirement.allCallV2DesignTests,
        CallV2ProductionRouteRegistrationTestRequirement
            .allCallV2IntegrationTests,
        CallV2ProductionRouteRegistrationTestRequirement.allCallV2UiTests,
        CallV2ProductionRouteRegistrationTestRequirement
            .preIntegrationVerification,
        CallV2ProductionRouteRegistrationTestRequirement
            .productionCompositionTests,
        CallV2ProductionRouteRegistrationTestRequirement.finalReadinessTests,
        CallV2ProductionRouteRegistrationTestRequirement.allCallV2FlutterTests,
        CallV2ProductionRouteRegistrationTestRequirement.backendCheck,
        CallV2ProductionRouteRegistrationTestRequirement.deploymentValidation,
        CallV2ProductionRouteRegistrationTestRequirement.firestoreRulesTests,
        CallV2ProductionRouteRegistrationTestRequirement.emulatorTests,
        CallV2ProductionRouteRegistrationTestRequirement.fullFlutterAnalyze,
        CallV2ProductionRouteRegistrationTestRequirement.diffCheck,
      ]),
    );
  });

  test('design model is immutable and safe to debug', () {
    final design = callV2ProductionRouteRegistrationDesign;

    expect(
      () => design.currentStatus.add(
        CallV2ProductionRouteRegistrationStatus.routeRegistryDisabled,
      ),
      throwsUnsupportedError,
    );
    expect(
      () => design.routeSafetyRules.add(
        CallV2ProductionRouteRegistrationRouteSafetyRule
            .fixedCanonicalRoutesOnly,
      ),
      throwsUnsupportedError,
    );

    final text = design.toString();
    expect(text, contains('routeSafetyRuleCount'));
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

  test('real app files remain disconnected from route registration design', () {
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
        isNot(contains('call_v2_production_route_registration_design')),
        reason: entry.key,
      );
      expect(
        entry.value,
        isNot(contains('CallV2ProductionRouteRegistrationDesign')),
        reason: entry.key,
      );
    }
  });

  test('app router and main remain disconnected from production route names',
      () {
    final appRouter = _read('lib/navigation/app_router.dart');
    final main = _read('lib/main.dart');

    expect(appRouter, isNot(contains('/call-v2/')));
    expect(appRouter, isNot(contains('CallV2RouteNames')));
    expect(appRouter, isNot(contains('resolveCallV2Route')));
    expect(main, isNot(contains('CallV2RouteNames')));
    expect(main, isNot(contains('CallV2ProductionRouteRegistrationDesign')));
  });

  test('route registry does not reference the new design package', () {
    final routeRegistry = _read(
      'lib/call_v2/integration/call_v2_route_registry.dart',
    );

    expect(
      routeRegistry,
      isNot(contains('call_v2_production_route_registration_design')),
    );
    expect(routeRegistry, isNot(contains('CallV2ProductionRouteRegistration')));
    expect(routeRegistry, contains('productionEnabled'));
    expect(routeRegistry, contains('return null'));
  });

  test('production composition does not construct route registration', () {
    final composition = _read(
      'lib/call_v2/production/call_v2_production_composition.dart',
    );

    expect(composition, isNot(contains('CallV2RouteRegistry')));
    expect(composition, isNot(contains('resolveCallV2Route')));
    expect(composition, isNot(contains('CallV2ProductionRouteRegistration')));
  });

  test('new design introduces no navigation runtime or service wiring', () {
    final source = _read(
      'lib/call_v2/design/call_v2_production_route_registration_design.dart',
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
      'MaterialApp(',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('dependency platform and config files remain unrelated to Phase 6U', () {
    final sources = <String, String>{
      'pubspec.yaml': _read('pubspec.yaml'),
      'firebase.json': _read('firebase.json'),
      'index.js': _read('connect_functions/index.js'),
    };

    for (final entry in sources.entries) {
      expect(
        entry.value,
        isNot(contains('call_v2_production_route_registration_design')),
        reason: entry.key,
      );
      expect(
        entry.value,
        isNot(contains('CallV2ProductionRouteRegistrationDesign')),
        reason: entry.key,
      );
    }
  });
}

String _read(String path) => File(path).readAsStringSync();
