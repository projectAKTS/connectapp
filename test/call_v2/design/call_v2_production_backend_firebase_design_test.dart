import 'dart:io';

import 'package:connect_app/call_v2/design/call_v2_production_backend_firebase_design.dart';
import 'package:connect_app/call_v2/design/call_v2_production_runtime_startup_design.dart';
import 'package:connect_app/call_v2/design/call_v2_production_security_privacy_audit.dart';
import 'package:connect_app/call_v2/design/call_v2_production_staged_rollout_design.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final design = callV2ProductionBackendFirebaseDesign;

  test('design records current backend Firebase status as disconnected', () {
    expect(design.isBackendFirebaseIntegrationImplemented, isFalse);
    expect(design.hasOpenFirestoreListeners, isFalse);
    expect(design.hasAuthProviderCalls, isFalse);
    expect(design.hasCallableBackendCalls, isFalse);
    expect(design.hasFirestoreReadsOrWrites, isFalse);
    expect(design.isRuntimeStarted, isFalse);
    expect(design.isRolloutEnabled, isFalse);
    expect(design.isCallV2Reachable, isFalse);
    expect(design.isDeploymentAuthorized, isFalse);
    expect(design.allowsAutomaticWiring, isFalse);
    expect(
      design.currentStatus,
      containsAll(<Object>[
        CallV2ProductionBackendFirebaseStatus
            .noRealBackendFirebaseIntegrationImplemented,
        CallV2ProductionBackendFirebaseStatus.noFirestoreListenersOpened,
        CallV2ProductionBackendFirebaseStatus.noAuthProviderCalls,
        CallV2ProductionBackendFirebaseStatus.noCallableBackendCalls,
        CallV2ProductionBackendFirebaseStatus.noFirestoreReads,
        CallV2ProductionBackendFirebaseStatus.noFirestoreWrites,
        CallV2ProductionBackendFirebaseStatus.noSecurityRulesModified,
        CallV2ProductionBackendFirebaseStatus.noFunctionsModified,
        CallV2ProductionBackendFirebaseStatus.runtimeNotStarted,
        CallV2ProductionBackendFirebaseStatus.rolloutFalse,
        CallV2ProductionBackendFirebaseStatus.callV2Unreachable,
        CallV2ProductionBackendFirebaseStatus.deploymentNotAuthorized,
      ]),
    );
  });

  test('design lists allowed future locations only after approval', () {
    expect(
      design.allowedFutureLocations,
      <CallV2ProductionBackendFirebaseAllowedLocation>[
        CallV2ProductionBackendFirebaseAllowedLocation
            .isolatedCallV2BackendFirebaseOwner,
        CallV2ProductionBackendFirebaseAllowedLocation
            .isolatedProductionIntegrationOwnerOnlyIfApproved,
        CallV2ProductionBackendFirebaseAllowedLocation
            .developerOnlyBackendFirebasePrOnly,
      ],
    );
  });

  test('design forbids main app router route registry and V1 locations', () {
    expect(
      design.forbiddenLocations,
      containsAll(<Object>[
        CallV2ProductionBackendFirebaseForbiddenLocation.mainDart,
        CallV2ProductionBackendFirebaseForbiddenLocation.appStartup,
        CallV2ProductionBackendFirebaseForbiddenLocation.appRouter,
        CallV2ProductionBackendFirebaseForbiddenLocation.routeRegistry,
        CallV2ProductionBackendFirebaseForbiddenLocation.v1Files,
      ]),
    );
  });

  test('design forbids backend Firebase and deployment actions', () {
    expect(
      design.forbiddenActions,
      containsAll(<Object>[
        CallV2ProductionBackendFirebaseForbiddenAction.modifyMainDart,
        CallV2ProductionBackendFirebaseForbiddenAction.modifyAppStartup,
        CallV2ProductionBackendFirebaseForbiddenAction.modifyAppRouter,
        CallV2ProductionBackendFirebaseForbiddenAction.modifyRouteRegistry,
        CallV2ProductionBackendFirebaseForbiddenAction.changeRolloutFlag,
        CallV2ProductionBackendFirebaseForbiddenAction.openFirestoreListeners,
        CallV2ProductionBackendFirebaseForbiddenAction.readFirestore,
        CallV2ProductionBackendFirebaseForbiddenAction.writeFirestore,
        CallV2ProductionBackendFirebaseForbiddenAction.callAuthProvider,
        CallV2ProductionBackendFirebaseForbiddenAction.callCallableBackend,
        CallV2ProductionBackendFirebaseForbiddenAction.modifyConnectFunctions,
        CallV2ProductionBackendFirebaseForbiddenAction.modifyFirestoreRules,
        CallV2ProductionBackendFirebaseForbiddenAction.modifyFirebaseJson,
        CallV2ProductionBackendFirebaseForbiddenAction.deployRulesOrFunctions,
        CallV2ProductionBackendFirebaseForbiddenAction.startRuntime,
        CallV2ProductionBackendFirebaseForbiddenAction.startRtc,
        CallV2ProductionBackendFirebaseForbiddenAction.requestPermissions,
        CallV2ProductionBackendFirebaseForbiddenAction
            .addRouteOrNavigatorWiring,
      ]),
    );
  });

  test('design requires data sanitization and safe models', () {
    expect(
      design.dataSafetyRules,
      containsAll(<Object>[
        CallV2ProductionBackendDataSafetyRule
            .sanitizeBackendSnapshotsBeforeBridgeRuntimeUi,
        CallV2ProductionBackendDataSafetyRule.noRawFirestoreSnapshotStored,
        CallV2ProductionBackendDataSafetyRule.noRawAuthUserStored,
        CallV2ProductionBackendDataSafetyRule.noRawCallableResultStored,
        CallV2ProductionBackendDataSafetyRule
            .noIdsTokensChannelsCredentialsInLogsDebugUiRoutes,
        CallV2ProductionBackendDataSafetyRule.noRawBackendPayloadInErrors,
        CallV2ProductionBackendDataSafetyRule.noRawExceptionStackExposure,
        CallV2ProductionBackendDataSafetyRule.noRouteArguments,
        CallV2ProductionBackendDataSafetyRule
            .noCredentialRefreshWithoutSeparateApproval,
        CallV2ProductionBackendDataSafetyRule
            .safeEnumBooleanGenerationModelsOnly,
      ]),
    );
  });

  test('design keeps listeners gated disposable stale-safe and rollback-safe',
      () {
    expect(
      design.listenerSafetyRules,
      containsAll(<Object>[
        CallV2ProductionBackendListenerSafetyRule
            .noListenerBeforeExplicitStartupApproval,
        CallV2ProductionBackendListenerSafetyRule.noListenerWhileRolloutFalse,
        CallV2ProductionBackendListenerSafetyRule.listenerOwnerDisposable,
        CallV2ProductionBackendListenerSafetyRule
            .duplicateListenersRejectedOrNoOp,
        CallV2ProductionBackendListenerSafetyRule.staleGenerationIgnored,
        CallV2ProductionBackendListenerSafetyRule.terminalStateUnsubscribes,
        CallV2ProductionBackendListenerSafetyRule.signOutUnsubscribes,
        CallV2ProductionBackendListenerSafetyRule.authInvalidUnsubscribes,
        CallV2ProductionBackendListenerSafetyRule
            .backgroundLifecycleCleanupDoesNotStartListeners,
        CallV2ProductionBackendListenerSafetyRule.listenersCoveredByRollback,
      ]),
    );
  });

  test(
      'design requires auth rules functions App Check and least privilege gates',
      () {
    expect(
      design.gates,
      containsAll(<Object>[
        CallV2ProductionBackendFirebaseGate.authGateApproved,
        CallV2ProductionBackendFirebaseGate.firestoreRulesReviewed,
        CallV2ProductionBackendFirebaseGate.emulatorRulesTestsPassed,
        CallV2ProductionBackendFirebaseGate.functionsDeploymentValidationPassed,
        CallV2ProductionBackendFirebaseGate.appCheckBehaviorReviewed,
        CallV2ProductionBackendFirebaseGate.noDebugTokenLeakage,
        CallV2ProductionBackendFirebaseGate
            .leastPrivilegeReadWriteShapeReviewed,
        CallV2ProductionBackendFirebaseGate.backendIndexesReviewedIfNeeded,
        CallV2ProductionBackendFirebaseGate.explicitHumanApprovalRequired,
        CallV2ProductionBackendFirebaseGate.developerOnlyAllowlistRequired,
      ]),
    );
  });

  test('design defines backend call-state consistency handling', () {
    expect(
      design.callStateConsistencyRules,
      containsAll(<Object>[
        CallV2ProductionBackendCallStateConsistencyRule.staleSnapshotIgnored,
        CallV2ProductionBackendCallStateConsistencyRule.duplicateSnapshotNoOp,
        CallV2ProductionBackendCallStateConsistencyRule
            .outOfOrderStateRejectedOrNoOp,
        CallV2ProductionBackendCallStateConsistencyRule
            .ownershipMismatchRejected,
        CallV2ProductionBackendCallStateConsistencyRule
            .terminalMismatchControlledClose,
        CallV2ProductionBackendCallStateConsistencyRule
            .credentialExpiryControlledFailureNoRefreshUnlessApproved,
        CallV2ProductionBackendCallStateConsistencyRule
            .remoteDisconnectReconnectSanitized,
        CallV2ProductionBackendCallStateConsistencyRule
            .backendTimeoutMapsToControlledFailure,
      ]),
    );
  });

  test('design lists rollback controls and V1 protections', () {
    expect(
      design.rollbackControls,
      containsAll(<Object>[
        CallV2ProductionBackendFirebaseRollback.oneCommit,
        CallV2ProductionBackendFirebaseRollback
            .removeBackendFirebaseOwnerWiring,
        CallV2ProductionBackendFirebaseRollback.removeListeners,
        CallV2ProductionBackendFirebaseRollback.rolloutFalse,
        CallV2ProductionBackendFirebaseRollback.runtimeRemainsNotStarted,
        CallV2ProductionBackendFirebaseRollback.routeRegistryDisabledNull,
        CallV2ProductionBackendFirebaseRollback.noDeploymentWithoutApproval,
        CallV2ProductionBackendFirebaseRollback.backupBranchProtected,
      ]),
    );
    expect(
      design.v1Protections,
      containsAll(<Object>[
        CallV2ProductionBackendFirebaseV1Protection.noV1DataModelChanges,
        CallV2ProductionBackendFirebaseV1Protection.noV1RouteBehaviorChanges,
        CallV2ProductionBackendFirebaseV1Protection.noV1ChatBehaviorChanges,
        CallV2ProductionBackendFirebaseV1Protection.noV1CallBehaviorChanges,
        CallV2ProductionBackendFirebaseV1Protection
            .noExistingFirestoreRulesRegression,
        CallV2ProductionBackendFirebaseV1Protection
            .v1SmokeBeforeAndAfterBackendWiring,
        CallV2ProductionBackendFirebaseV1Protection
            .immediateRollbackOnV1Regression,
      ]),
    );
  });

  test('design aligns with prerequisite rollout runtime and privacy packages',
      () {
    expect(callV2ProductionRuntimeStartupDesign.isRuntimeStarted, isFalse);
    expect(
      callV2ProductionRuntimeStartupDesign.currentStatus,
      contains(
        CallV2ProductionRuntimeStartupStatus.backendFirebaseDisconnected,
      ),
    );
    expect(callV2ProductionStagedRolloutDesign.isRolloutEnabled, isFalse);
    expect(
      callV2ProductionSecurityPrivacyAudit.isolationConstraints,
      contains(
        CallV2ProductionIsolationConstraint
            .noFirebaseBackendRtcPermissionAccess,
      ),
    );
  });

  test('design lists required validation coverage', () {
    expect(
      design.testRequirements,
      containsAll(<Object>[
        CallV2ProductionBackendFirebaseTestRequirement.phase6YTests,
        CallV2ProductionBackendFirebaseTestRequirement.phase6XTests,
        CallV2ProductionBackendFirebaseTestRequirement.phase6WTests,
        CallV2ProductionBackendFirebaseTestRequirement.phase6VTests,
        CallV2ProductionBackendFirebaseTestRequirement.phase6UTests,
        CallV2ProductionBackendFirebaseTestRequirement.allCallV2DesignTests,
        CallV2ProductionBackendFirebaseTestRequirement
            .allCallV2IntegrationTests,
        CallV2ProductionBackendFirebaseTestRequirement.allCallV2UiTests,
        CallV2ProductionBackendFirebaseTestRequirement
            .preIntegrationVerification,
        CallV2ProductionBackendFirebaseTestRequirement
            .productionCompositionTests,
        CallV2ProductionBackendFirebaseTestRequirement.finalReadinessTests,
        CallV2ProductionBackendFirebaseTestRequirement.allCallV2FlutterTests,
        CallV2ProductionBackendFirebaseTestRequirement.backendCheck,
        CallV2ProductionBackendFirebaseTestRequirement.deploymentValidation,
        CallV2ProductionBackendFirebaseTestRequirement.firestoreRulesTests,
        CallV2ProductionBackendFirebaseTestRequirement.emulatorTests,
        CallV2ProductionBackendFirebaseTestRequirement.fullFlutterAnalyze,
        CallV2ProductionBackendFirebaseTestRequirement.diffCheck,
      ]),
    );
  });

  test('design model is immutable and safe to debug', () {
    expect(
      () => design.currentStatus.add(
        CallV2ProductionBackendFirebaseStatus.callV2Unreachable,
      ),
      throwsUnsupportedError,
    );
    expect(
      () => design.gates.add(
        CallV2ProductionBackendFirebaseGate.authGateApproved,
      ),
      throwsUnsupportedError,
    );
    final debugMap = design.toSafeDebugMap();
    expect(debugMap['currentStatusCount'], design.currentStatus.length);
    expect(debugMap['dataSafetyRuleCount'], design.dataSafetyRules.length);
    expect(
        debugMap['listenerSafetyRuleCount'], design.listenerSafetyRules.length);
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

  test('real app files remain disconnected from backend Firebase design', () {
    final sources = <String, String>{
      'main': _read('lib/main.dart'),
      'appRouter': _read('lib/navigation/app_router.dart'),
      'routeRegistry': _read(
        'lib/call_v2/integration/call_v2_route_registry.dart',
      ),
      'disabledRouteRegistry': _read(
        'lib/call_v2/integration/disabled_call_v2_route_registry.dart',
      ),
      'composition': _read(
        'lib/call_v2/production/call_v2_production_composition.dart',
      ),
      'index': _read('connect_functions/index.js'),
      'rules': _read('firestore.rules'),
      'firebaseJson': _read('firebase.json'),
    };

    for (final entry in sources.entries) {
      expect(
        entry.value,
        isNot(contains('call_v2_production_backend_firebase_design')),
        reason: entry.key,
      );
      expect(
        entry.value,
        isNot(contains('CallV2ProductionBackendFirebase')),
        reason: entry.key,
      );
    }
    expect(sources['appRouter'], isNot(contains('/call-v2/')));
    expect(sources['appRouter'], isNot(contains('CallV2RouteNames')));
    expect(sources['appRouter'], isNot(contains('resolveCallV2Route')));
    expect(sources['routeRegistry'], contains('return null;'));
    expect(sources['disabledRouteRegistry'], contains('return null;'));
  });

  test(
      'new design introduces no backend runtime RTC permission or async wiring',
      () {
    final source = _read(
      'lib/call_v2/design/call_v2_production_backend_firebase_design.dart',
    );

    for (final forbidden in <String>[
      'package:flutter/',
      'dart:async',
      'package:firebase_',
      'package:cloud_',
      'package:agora_',
      'package:permission_',
      'import ',
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
      '.snapshots(',
      '.collection(',
      '.doc(',
      '.get(',
      '.set(',
      '.update(',
      '.delete(',
      '.httpsCallable(',
      '.authStateChanges(',
      'AppLifecycleListener',
      'WidgetsBindingObserver',
      'MaterialApp(',
      'VoidCallback',
      'Function()',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('dependency platform config rules and functions remain unrelated', () {
    final sources = <String, String>{
      'pubspec.yaml': _read('pubspec.yaml'),
      'pubspec.lock': _read('pubspec.lock'),
      'firebase.json': _read('firebase.json'),
      'index.js': _read('connect_functions/index.js'),
      'rules': _read('firestore.rules'),
    };

    for (final entry in sources.entries) {
      expect(
        entry.value,
        isNot(contains('call_v2_production_backend_firebase_design')),
        reason: entry.key,
      );
      expect(
        entry.value,
        isNot(contains('CallV2ProductionBackendFirebase')),
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
