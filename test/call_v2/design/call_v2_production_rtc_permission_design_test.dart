import 'dart:io';

import 'package:connect_app/call_v2/design/call_v2_production_backend_firebase_design.dart';
import 'package:connect_app/call_v2/design/call_v2_production_rtc_permission_design.dart';
import 'package:connect_app/call_v2/design/call_v2_production_runtime_startup_design.dart';
import 'package:connect_app/call_v2/design/call_v2_production_security_privacy_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final design = callV2ProductionRtcPermissionDesign;

  test('design records current RTC permission status as disconnected', () {
    expect(design.isRtcIntegrationImplemented, isFalse);
    expect(design.isRtcEngineInitialized, isFalse);
    expect(design.hasRtcProviderApiCalls, isFalse);
    expect(design.hasPermissionRequests, isFalse);
    expect(design.hasDeviceEnumerationOrSwitching, isFalse);
    expect(design.hasBackendFirebaseContact, isFalse);
    expect(design.isRuntimeStarted, isFalse);
    expect(design.isRolloutEnabled, isFalse);
    expect(design.isCallV2Reachable, isFalse);
    expect(design.hasDependencyOrPlatformChanges, isFalse);
    expect(design.isDeploymentAuthorized, isFalse);
    expect(design.allowsAutomaticWiring, isFalse);
    expect(
      design.currentStatus,
      containsAll(<Object>[
        CallV2ProductionRtcPermissionStatus.noRealRtcIntegrationImplemented,
        CallV2ProductionRtcPermissionStatus.noRtcEngineInitialized,
        CallV2ProductionRtcPermissionStatus.noRtcProviderApisCalled,
        CallV2ProductionRtcPermissionStatus.noMicrophonePermissionRequested,
        CallV2ProductionRtcPermissionStatus.noCameraPermissionRequested,
        CallV2ProductionRtcPermissionStatus.noDeviceEnumeration,
        CallV2ProductionRtcPermissionStatus.noDeviceSwitching,
        CallV2ProductionRtcPermissionStatus.noBackendFirebaseContact,
        CallV2ProductionRtcPermissionStatus.runtimeNotStarted,
        CallV2ProductionRtcPermissionStatus.rolloutFalse,
        CallV2ProductionRtcPermissionStatus.callV2Unreachable,
        CallV2ProductionRtcPermissionStatus.noPubspecDependencyChanges,
        CallV2ProductionRtcPermissionStatus.noPlatformPermissionConfigChanges,
        CallV2ProductionRtcPermissionStatus.deploymentNotAuthorized,
      ]),
    );
  });

  test('design lists allowed future locations only after approval', () {
    expect(
      design.allowedFutureLocations,
      <CallV2ProductionRtcPermissionAllowedLocation>[
        CallV2ProductionRtcPermissionAllowedLocation
            .isolatedCallV2RtcPermissionOwner,
        CallV2ProductionRtcPermissionAllowedLocation
            .isolatedProductionIntegrationOwnerOnlyIfApproved,
        CallV2ProductionRtcPermissionAllowedLocation
            .developerOnlyRtcPermissionPrOnly,
      ],
    );
  });

  test('design forbids main startup app router route registry and V1 changes',
      () {
    expect(
      design.forbiddenLocations,
      containsAll(<Object>[
        CallV2ProductionRtcPermissionForbiddenLocation.mainDart,
        CallV2ProductionRtcPermissionForbiddenLocation.appStartup,
        CallV2ProductionRtcPermissionForbiddenLocation.appRouter,
        CallV2ProductionRtcPermissionForbiddenLocation.routeRegistry,
        CallV2ProductionRtcPermissionForbiddenLocation
            .lifecycleEventHandlerAlone,
        CallV2ProductionRtcPermissionForbiddenLocation.v1Files,
      ]),
    );
  });

  test('design forbids RTC permission backend navigation and deploy actions',
      () {
    expect(
      design.forbiddenActions,
      containsAll(<Object>[
        CallV2ProductionRtcPermissionForbiddenAction.modifyMainDart,
        CallV2ProductionRtcPermissionForbiddenAction.modifyAppStartup,
        CallV2ProductionRtcPermissionForbiddenAction.modifyAppRouter,
        CallV2ProductionRtcPermissionForbiddenAction.modifyRouteRegistry,
        CallV2ProductionRtcPermissionForbiddenAction.changeRolloutFlag,
        CallV2ProductionRtcPermissionForbiddenAction.addRtcDependency,
        CallV2ProductionRtcPermissionForbiddenAction
            .modifyPlatformPermissionsConfig,
        CallV2ProductionRtcPermissionForbiddenAction.initializeRtcEngine,
        CallV2ProductionRtcPermissionForbiddenAction.joinRtcChannel,
        CallV2ProductionRtcPermissionForbiddenAction.publishAudio,
        CallV2ProductionRtcPermissionForbiddenAction.publishVideo,
        CallV2ProductionRtcPermissionForbiddenAction
            .requestMicrophonePermission,
        CallV2ProductionRtcPermissionForbiddenAction.requestCameraPermission,
        CallV2ProductionRtcPermissionForbiddenAction.enumerateDevices,
        CallV2ProductionRtcPermissionForbiddenAction.switchDevices,
        CallV2ProductionRtcPermissionForbiddenAction.startRuntime,
        CallV2ProductionRtcPermissionForbiddenAction
            .openBackendFirebaseListeners,
        CallV2ProductionRtcPermissionForbiddenAction.addRouteOrNavigatorWiring,
        CallV2ProductionRtcPermissionForbiddenAction.deploy,
      ]),
    );
  });

  test('design defines permission safety boundaries', () {
    expect(
      design.permissionSafetyRules,
      containsAll(<Object>[
        CallV2ProductionPermissionSafetyRule
            .noPermissionRequestBeforeExplicitUserDeveloperAction,
        CallV2ProductionPermissionSafetyRule
            .noPermissionRequestWhileRolloutFalse,
        CallV2ProductionPermissionSafetyRule.noRepeatedPermissionPromptLoop,
        CallV2ProductionPermissionSafetyRule
            .deniedPermissionMapsToControlledFailure,
        CallV2ProductionPermissionSafetyRule
            .permanentlyDeniedPermissionRetryBlockedUntilUserAction,
        CallV2ProductionPermissionSafetyRule
            .permissionStatusStoredAsSafeEnumOnly,
        CallV2ProductionPermissionSafetyRule.noRawNativePermissionResultStored,
        CallV2ProductionPermissionSafetyRule
            .noPermissionPromptFromLifecycleEventAlone,
      ]),
    );
  });

  test('design defines RTC safety boundaries', () {
    expect(
      design.rtcSafetyRules,
      containsAll(<Object>[
        CallV2ProductionRtcSafetyRule.noRtcEngineBeforeExplicitStartupApproval,
        CallV2ProductionRtcSafetyRule
            .noRtcJoinWithoutSanitizedCredentialTokenGate,
        CallV2ProductionRtcSafetyRule.noRawRtcTokenChannelInLogsDebugUiRoutes,
        CallV2ProductionRtcSafetyRule.noRawRtcNativeCallbackPayloadStored,
        CallV2ProductionRtcSafetyRule.duplicateJoinRejectedOrNoOp,
        CallV2ProductionRtcSafetyRule.staleGenerationIgnored,
        CallV2ProductionRtcSafetyRule.terminalStateLeavesChannel,
        CallV2ProductionRtcSafetyRule.signOutLeavesChannel,
        CallV2ProductionRtcSafetyRule.authInvalidLeavesChannel,
        CallV2ProductionRtcSafetyRule.backgroundCleanupDoesNotStartRtc,
        CallV2ProductionRtcSafetyRule.rtcFailureMapsToControlledFailure,
      ]),
    );
  });

  test('design defines device and media lifecycle safety', () {
    expect(
      design.deviceSafetyRules,
      containsAll(<Object>[
        CallV2ProductionDeviceSafetyRule.deviceAvailabilityStoredAsSafeEnumOnly,
        CallV2ProductionDeviceSafetyRule.noRawDeviceIdsOrLabelsExposed,
        CallV2ProductionDeviceSafetyRule.speakerSwitchFailureControlledNoOp,
        CallV2ProductionDeviceSafetyRule.cameraSwitchFailureControlledNoOp,
        CallV2ProductionDeviceSafetyRule.cameraToggleIdempotent,
        CallV2ProductionDeviceSafetyRule.micToggleIdempotent,
        CallV2ProductionDeviceSafetyRule
            .deviceUnavailableMapsToControlledFailure,
        CallV2ProductionDeviceSafetyRule.deviceCleanupCoveredByRollback,
      ]),
    );
    expect(
      design.mediaLifecycleRules,
      containsAll(<Object>[
        CallV2ProductionMediaLifecycleRule
            .noCameraMicActiveBeforePermissionAndStartupApproval,
        CallV2ProductionMediaLifecycleRule.pausedInactiveHiddenDoNotStartMedia,
        CallV2ProductionMediaLifecycleRule
            .detachedSignOutAuthInvalidCleanupByExplicitPolicyOnly,
        CallV2ProductionMediaLifecycleRule.terminalStateStopsMedia,
        CallV2ProductionMediaLifecycleRule.disposeStopsMediaIdempotently,
        CallV2ProductionMediaLifecycleRule
            .retryAfterPermissionDenialRequiresExplicitUserAction,
      ]),
    );
  });

  test('design requires platform config privacy provider and token gates', () {
    expect(
      design.gates,
      containsAll(<Object>[
        CallV2ProductionRtcPermissionGate.pubspecDependencyReview,
        CallV2ProductionRtcPermissionGate.iosPermissionStringsReview,
        CallV2ProductionRtcPermissionGate.androidPermissionManifestReview,
        CallV2ProductionRtcPermissionGate
            .appStorePlayStorePrivacyDisclosureReview,
        CallV2ProductionRtcPermissionGate.rtcProviderConfigurationReview,
        CallV2ProductionRtcPermissionGate.tokenCredentialHandlingReview,
        CallV2ProductionRtcPermissionGate.securityPrivacyAuditAccepted,
        CallV2ProductionRtcPermissionGate.backendFirebaseDesignAccepted,
        CallV2ProductionRtcPermissionGate.runtimeStartupDesignAccepted,
        CallV2ProductionRtcPermissionGate.explicitHumanApprovalRequired,
        CallV2ProductionRtcPermissionGate.developerOnlyAllowlistRequired,
        CallV2ProductionRtcPermissionGate.allTestsPassed,
      ]),
    );
  });

  test('design lists rollback controls and V1 protections', () {
    expect(
      design.rollbackControls,
      containsAll(<Object>[
        CallV2ProductionRtcPermissionRollback.oneCommit,
        CallV2ProductionRtcPermissionRollback.removeRtcPermissionOwnerWiring,
        CallV2ProductionRtcPermissionRollback.leaveRtcChannel,
        CallV2ProductionRtcPermissionRollback.stopLocalMedia,
        CallV2ProductionRtcPermissionRollback.rolloutFalse,
        CallV2ProductionRtcPermissionRollback.runtimeRemainsNotStarted,
        CallV2ProductionRtcPermissionRollback.routeRegistryDisabledNull,
        CallV2ProductionRtcPermissionRollback.noDeploymentWithoutApproval,
        CallV2ProductionRtcPermissionRollback.backupBranchProtected,
      ]),
    );
    expect(
      design.v1Protections,
      containsAll(<Object>[
        CallV2ProductionRtcPermissionV1Protection.noV1CallMediaBehaviorChanges,
        CallV2ProductionRtcPermissionV1Protection.noV1RouteBehaviorChanges,
        CallV2ProductionRtcPermissionV1Protection.noV1ChatBehaviorChanges,
        CallV2ProductionRtcPermissionV1Protection.noAppStartupRegression,
        CallV2ProductionRtcPermissionV1Protection.noPlatformConfigRegression,
        CallV2ProductionRtcPermissionV1Protection
            .v1SmokeBeforeAndAfterRtcPermissionWiring,
        CallV2ProductionRtcPermissionV1Protection
            .immediateRollbackOnV1Regression,
      ]),
    );
  });

  test('design aligns with prerequisite backend runtime and privacy packages',
      () {
    expect(
      callV2ProductionBackendFirebaseDesign
          .isBackendFirebaseIntegrationImplemented,
      isFalse,
    );
    expect(callV2ProductionRuntimeStartupDesign.isRuntimeStarted, isFalse);
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
        CallV2ProductionRtcPermissionTestRequirement.phase6ZTests,
        CallV2ProductionRtcPermissionTestRequirement.phase6YTests,
        CallV2ProductionRtcPermissionTestRequirement.phase6XTests,
        CallV2ProductionRtcPermissionTestRequirement.phase6WTests,
        CallV2ProductionRtcPermissionTestRequirement.phase6VTests,
        CallV2ProductionRtcPermissionTestRequirement.allCallV2DesignTests,
        CallV2ProductionRtcPermissionTestRequirement.allCallV2IntegrationTests,
        CallV2ProductionRtcPermissionTestRequirement.allCallV2UiTests,
        CallV2ProductionRtcPermissionTestRequirement.preIntegrationVerification,
        CallV2ProductionRtcPermissionTestRequirement.productionCompositionTests,
        CallV2ProductionRtcPermissionTestRequirement.finalReadinessTests,
        CallV2ProductionRtcPermissionTestRequirement.allCallV2FlutterTests,
        CallV2ProductionRtcPermissionTestRequirement.backendCheck,
        CallV2ProductionRtcPermissionTestRequirement.deploymentValidation,
        CallV2ProductionRtcPermissionTestRequirement.firestoreRulesTests,
        CallV2ProductionRtcPermissionTestRequirement.emulatorTests,
        CallV2ProductionRtcPermissionTestRequirement.fullFlutterAnalyze,
        CallV2ProductionRtcPermissionTestRequirement.diffCheck,
      ]),
    );
  });

  test('design model is immutable and safe to debug', () {
    expect(
      () => design.currentStatus.add(
        CallV2ProductionRtcPermissionStatus.callV2Unreachable,
      ),
      throwsUnsupportedError,
    );
    expect(
      () => design.rtcSafetyRules.add(
        CallV2ProductionRtcSafetyRule.backgroundCleanupDoesNotStartRtc,
      ),
      throwsUnsupportedError,
    );
    final debugMap = design.toSafeDebugMap();
    expect(debugMap['currentStatusCount'], design.currentStatus.length);
    expect(
      debugMap['permissionSafetyRuleCount'],
      design.permissionSafetyRules.length,
    );
    expect(debugMap['rtcSafetyRuleCount'], design.rtcSafetyRules.length);
    expect(debugMap['deviceSafetyRuleCount'], design.deviceSafetyRules.length);
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

  test('real app files remain disconnected from RTC permission design', () {
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
      'pubspec.yaml': _read('pubspec.yaml'),
      'pubspec.lock': _read('pubspec.lock'),
      'androidManifest': _read('android/app/src/main/AndroidManifest.xml'),
      'iosInfo': _read('ios/Runner/Info.plist'),
    };

    for (final entry in sources.entries) {
      expect(
        entry.value,
        isNot(contains('call_v2_production_rtc_permission_design')),
        reason: entry.key,
      );
      expect(
        entry.value,
        isNot(contains('CallV2ProductionRtcPermissionDesign')),
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
      'new design introduces no backend RTC permission platform or async wiring',
      () {
    final source = _read(
      'lib/call_v2/design/call_v2_production_rtc_permission_design.dart',
    );

    for (final forbidden in <String>[
      'package:flutter/',
      'dart:async',
      'package:firebase_',
      'package:cloud_',
      'package:agora_',
      'package:permission_',
      'package:camera',
      'import ',
      'AgoraRtcEngine',
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
      'androidManifest': _read('android/app/src/main/AndroidManifest.xml'),
      'iosInfo': _read('ios/Runner/Info.plist'),
    };

    for (final entry in sources.entries) {
      expect(
        entry.value,
        isNot(contains('call_v2_production_rtc_permission_design')),
        reason: entry.key,
      );
      expect(
        entry.value,
        isNot(contains('CallV2ProductionRtcPermission')),
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
    'device=',
    'payload',
    'stackTrace',
  ]) {
    expect(text.contains(forbidden), isFalse, reason: forbidden);
  }
}
