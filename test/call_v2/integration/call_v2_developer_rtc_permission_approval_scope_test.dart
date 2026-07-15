import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_backend_firebase_owner_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_backend_firebase_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_lifecycle_observer_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_navigator_owner_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_pre_wiring_safety_gate.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_route_registration_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_rtc_permission_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_rtc_permission_owner_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_runtime_startup_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_skeleton_composition_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_lifecycle_observer_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_navigator_owner_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_integration_status.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_runtime_startup_owner_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final scope = callV2DeveloperRtcPermissionApprovalScope;
  final skeleton = callV2DeveloperRtcPermissionOwnerSkeleton;

  test('approval scope artifact records exact Phase 7Y approval', () {
    expect(scope, isA<CallV2DeveloperRtcPermissionApprovalScope>());
    expect(scope.hasHumanApproval, isTrue);
    expect(scope.isRtcPermissionOwnerOnly, isTrue);
    expect(scope.isDeveloperOnly, isTrue);
    expect(scope.isRolloutEnabled, isFalse);
    expect(scope.constructsRuntime, isFalse);
    expect(scope.startsRuntime, isFalse);
    expect(scope.accessesBackendFirebase, isFalse);
    expect(scope.wiresNavigation, isFalse);
    expect(scope.registersLifecycleObserver, isFalse);
    expect(scope.mutatesRouteRegistry, isFalse);
    expect(scope.createsProviderMediaEngine, isFalse);
    expect(scope.joinsRtcChannel, isFalse);
    expect(scope.consumesRtcTokenChannel, isFalse);
    expect(scope.requestsPermission, isFalse);
    expect(scope.promptsMicrophoneCamera, isFalse);
    expect(scope.enumeratesDevices, isFalse);
    expect(scope.capturesMedia, isFalse);
    expect(scope.startsCameraPreview, isFalse);
    expect(scope.publishesAudioVideo, isFalse);
    expect(scope.opensRtcCallbacksListenersSubscriptions, isFalse);
    expect(scope.contactsProductionServices, isFalse);
    expect(scope.wiresStartupMainRouter, isFalse);
    expect(scope.changesPubspecPlatformConfig, isFalse);
    expect(scope.changesRulesFunctionsConfig, isFalse);
    expect(scope.isDeploymentApproved, isFalse);
    expect(scope.protectsV1, isTrue);
    expect(scope.isStrictlyClosed, isTrue);
    expect(scope.evidence, hasLength(26));
  });

  test('pre-wiring gate remains blocked by default and approved for 7Y only',
      () {
    expect(
      callV2DeveloperPreWiringSafetyGate.decision,
      CallV2DeveloperPreWiringGateDecision.blockedNoScopeSelected,
    );
    expect(
      scope.evaluatedGate.selectedScope,
      CallV2DeveloperPreWiringScope.rtcPermissionOwnerOnly,
    );
    expect(
      scope.evaluatedGate.decision,
      CallV2DeveloperPreWiringGateDecision
          .allowedForExplicitFutureDeveloperOnlyPhase,
    );
    expect(scope.evaluatedGate.canWireRoutes, isFalse);
    expect(scope.evaluatedGate.canStartRuntime, isFalse);
    expect(scope.evaluatedGate.canRegisterLifecycleObserver, isFalse);
    expect(scope.evaluatedGate.canWireNavigator, isFalse);
    expect(scope.evaluatedGate.canAccessBackendFirebase, isFalse);
    expect(scope.evaluatedGate.canInitializeRtc, isFalse);
    expect(scope.evaluatedGate.canRequestPermissions, isFalse);
    expect(scope.evaluatedGate.canModifyPubspecPlatform, isFalse);
    expect(scope.evaluatedGate.canModifyRulesFunctionsConfig, isFalse);
  });

  test('allowed and forbidden files are scoped to RTC permission owner only',
      () {
    expect(
      scope.allowedFutureFiles,
      <String>[
        'lib/call_v2/integration/call_v2_rtc_permission_owner.dart',
        'test/call_v2/integration/call_v2_rtc_permission_owner_test.dart',
      ],
    );
    expect(scope.allowedFutureFilesAreRtcPermissionOwnerOnly, isTrue);
    expect(scope.forbidsOutOfScopeFutureFiles, isTrue);
    expect(
      scope.forbiddenFutureFiles,
      containsAll(<String>[
        'lib/main.dart',
        'lib/navigation/app_router.dart',
        'lib/call_v2/startup/**',
        'lib/call_v2/runtime/**',
        'lib/call_v2/firebase/**',
        'lib/call_v2/integration/call_v2_route_registry.dart',
        'lib/call_v2/integration/call_v2_lifecycle_observer.dart',
        'lib/call_v2/integration/call_v2_navigator_owner.dart',
        'lib/call_v2/integration/call_v2_backend_firebase_owner.dart',
        'lib/call_v2/production/call_v2_production_composition.dart',
        'lib/call_v2/rtc/**',
        'lib/call_v2/permissions/**',
        'pubspec.yaml',
        'pubspec.lock',
        'android/**',
        'ios/**',
        'macos/**',
        'web/**',
        'firestore.rules',
        'firebase.json',
        'connect_functions/**',
      ]),
    );
  });

  test('RTC permission skeleton remains hard-disabled unreachable and inert',
      () {
    expect(skeleton.isDeveloperOnly, isTrue);
    expect(skeleton.isHardDisabled, isTrue);
    expect(skeleton.isRolloutEnabled, isFalse);
    expect(skeleton.isReachable, isFalse);
    expect(skeleton.attachesRtcPermission, isFalse);
    expect(skeleton.importsRtcPermissionPackages, isFalse);
    expect(skeleton.initializesRtcEngine, isFalse);
    expect(skeleton.joinsRtcChannel, isFalse);
    expect(skeleton.consumesRtcCredentialMaterial, isFalse);
    expect(skeleton.promptsForPermissions, isFalse);
    expect(skeleton.enumeratesDevices, isFalse);
    expect(skeleton.capturesMedia, isFalse);
    expect(skeleton.publishesAudioVideo, isFalse);
    expect(skeleton.opensRtcCallbacksOrSubscriptions, isFalse);
    expect(skeleton.constructsRuntime, isFalse);
    expect(skeleton.startsRuntime, isFalse);
    expect(skeleton.accessesBackendServices, isFalse);
    expect(skeleton.mutatesRouteRegistry, isFalse);
    expect(skeleton.accessesNavigation, isFalse);
    expect(skeleton.opensAsyncHandles, isFalse);
    expect(skeleton.changesPubspecPlatformConfig, isFalse);
    expect(skeleton.isDeploymentApproved, isFalse);
    expect(skeleton.protectsV1, isTrue);
  });

  test('RTC permission skeleton disabled decisions remain side-effect-free',
      () {
    for (final action in skeleton.actions) {
      final decision = skeleton.decideWhileDisabled(
        action: action,
        generation: skeleton.actions.indexOf(action) + 1,
        permissionResult:
            CallV2DeveloperSanitizedPermissionResult.microphoneGranted,
        rtcEvent: CallV2DeveloperSanitizedRtcEvent.rtcPrepared,
      );

      expect(
        decision.status,
        CallV2DeveloperRtcPermissionDecisionStatus.disabledInert,
        reason: action.name,
      );
      _expectNoRtcDecisionSideEffects(decision);
    }
  });

  test('safe debug output contains no sensitive material', () {
    final decision = skeleton.decideWhileDisabled(
      action: CallV2DeveloperRtcPermissionAction.prepareRtcPermissionOwner,
      generation: 1,
      permissionResult:
          CallV2DeveloperSanitizedPermissionResult.microphoneGranted,
      rtcEvent: CallV2DeveloperSanitizedRtcEvent.rtcPrepared,
    );
    final debugText = '${scope.toSafeDebugMap()} $scope '
        '${skeleton.toSafeDebugMap()} $skeleton '
        '${decision.toSafeDebugMap()} $decision';

    for (final forbidden in _forbiddenDebugTerms) {
      expect(debugText, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('approval source has no service imports or executable hooks', () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_developer_rtc_permission_approval_scope.dart',
    );

    for (final forbidden in <String>[
      "import 'package:flutter",
      "import 'dart:async",
      "import 'dart:io",
      'package:firebase',
      'package:agora',
      'package:permission',
      ..._forbiddenServiceTerms,
      ..._forbiddenRtcPermissionExecutableTerms,
      ..._forbiddenUiRuntimeTerms,
      ..._forbiddenAsyncTerms,
      ..._forbiddenFirestoreExecutableTerms,
      'Navigator',
      'GlobalKey',
      'BuildContext',
      'MaterialApp',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('rollout route registry disabled owner and audits remain closed',
      () async {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(
      resolveCallV2Route(const RouteSettings(name: '/call-v2/audio')),
      isNull,
    );
    expect(
      const DisabledCallV2RouteRegistry().resolve(
        const RouteSettings(name: '/call-v2/video'),
      ),
      isNull,
    );

    var compositionConstructed = false;
    final owner = DisabledCallV2ProductionIntegrationOwner(
      rolloutEnabled: () => false,
      compositionFactory: _ThrowingCompositionFactory(
        onConstruct: () => compositionConstructed = true,
      ),
    );

    await owner.initialize();

    expect(
      owner.status.lifecycle,
      CallV2ProductionIntegrationLifecycle.disabled,
    );
    expect(owner.status.compositionConstructed, isFalse);
    expect(owner.status.runtimeStarted, isFalse);
    expect(owner.status.routesRegistered, isFalse);
    expect(owner.status.screensAvailable, isFalse);
    expect(compositionConstructed, isFalse);
    expect(
      callV2BackendFirebaseOwnerHardeningAudit.decision,
      CallV2BackendFirebaseOwnerHardeningAuditDecision.pass,
    );
    expect(
      callV2RuntimeStartupOwnerHardeningAudit.decision,
      CallV2RuntimeStartupOwnerHardeningAuditDecision.pass,
    );
    expect(
      callV2NavigatorOwnerHardeningAudit.decision,
      CallV2NavigatorOwnerHardeningAuditDecision.pass,
    );
    expect(
      callV2LifecycleObserverHardeningAudit.decision,
      CallV2LifecycleObserverHardeningAuditDecision.pass,
    );
    expect(
      callV2RouteRegistryHardeningAudit.decision,
      CallV2RouteRegistryHardeningAuditDecision.pass,
    );
    expect(
      callV2DeveloperBackendFirebaseApprovalScope.isStrictlyClosed,
      isTrue,
    );
    expect(
      callV2DeveloperRuntimeStartupApprovalScope.rollbackPreserved,
      isTrue,
    );
    expect(
      callV2DeveloperNavigationOwnerApprovalScope.rollbackPreserved,
      isTrue,
    );
    expect(
      callV2DeveloperRouteRegistrationApprovalScope.rollbackPreserved,
      isTrue,
    );
    expect(
      callV2DeveloperLifecycleObserverApprovalScope.rollbackPreserved,
      isTrue,
    );
    expect(
      callV2DeveloperPreWiringSafetyGate.decision,
      CallV2DeveloperPreWiringGateDecision.blockedNoScopeSelected,
    );
    expect(
      callV2DeveloperSkeletonCompositionAudit.decision,
      CallV2DeveloperSkeletonCompositionDecision.pass,
    );
  });

  test('real app platform backend and config files do not reference approval',
      () {
    for (final path in <String>[
      'lib/main.dart',
      'lib/navigation/app_router.dart',
      'lib/call_v2/startup/production_call_v2_startup_bridge.dart',
      'lib/call_v2/production/call_v2_production_composition.dart',
      'pubspec.yaml',
      'pubspec.lock',
      'android/app/src/main/AndroidManifest.xml',
      'ios/Runner/Info.plist',
      'macos/Runner/Info.plist',
      'web/index.html',
      'firebase.json',
      'firestore.rules',
      'connect_functions/index.js',
    ]) {
      final source = _readIfExists(path);
      expect(
        source,
        isNot(contains('call_v2_developer_rtc_permission_approval_scope')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2DeveloperRtcPermissionApprovalScope')),
        reason: path,
      );
    }
  });

  test('rollback preserves one commit no-deploy recovery and V1 safety', () {
    expect(scope.rollbackPreserved, isTrue);
    expect(
      scope.rollback,
      <CallV2DeveloperRtcPermissionApprovalRollback>[
        CallV2DeveloperRtcPermissionApprovalRollback.oneCommitRevert,
        CallV2DeveloperRtcPermissionApprovalRollback.keepRolloutFalse,
        CallV2DeveloperRtcPermissionApprovalRollback.keepRouteRegistryNull,
        CallV2DeveloperRtcPermissionApprovalRollback.keepDisabledOwnerInert,
        CallV2DeveloperRtcPermissionApprovalRollback.noDeploymentRequired,
        CallV2DeveloperRtcPermissionApprovalRollback.noConfigChanges,
        CallV2DeveloperRtcPermissionApprovalRollback.v1Unaffected,
      ],
    );
  });
}

void _expectNoRtcDecisionSideEffects(
  CallV2DeveloperRtcPermissionDecision decision,
) {
  expect(decision.attachesRtcPermission, isFalse);
  expect(decision.importsRtcPermissionPackages, isFalse);
  expect(decision.initializesRtcEngine, isFalse);
  expect(decision.joinsRtcChannel, isFalse);
  expect(decision.consumesRtcCredentialMaterial, isFalse);
  expect(decision.promptsForPermissions, isFalse);
  expect(decision.enumeratesDevices, isFalse);
  expect(decision.capturesMedia, isFalse);
  expect(decision.publishesAudioVideo, isFalse);
  expect(decision.opensRtcCallbacksOrSubscriptions, isFalse);
  expect(decision.constructsRuntime, isFalse);
  expect(decision.startsRuntime, isFalse);
  expect(decision.accessesBackendServices, isFalse);
  expect(decision.constructsComposition, isFalse);
  expect(decision.wiresStartupBridge, isFalse);
  expect(decision.mutatesRouteRegistry, isFalse);
  expect(decision.accessesNavigation, isFalse);
  expect(decision.opensAsyncHandles, isFalse);
  expect(decision.changesPubspecPlatformConfig, isFalse);
  expect(decision.mutatesV1State, isFalse);
}

String _read(String path) => File(path).readAsStringSync();

String _readIfExists(String path) {
  final file = File(path);
  return file.existsSync() ? file.readAsStringSync() : '';
}

const _forbiddenDebugTerms = <String>[
  '/call-v2',
  'uid',
  'user',
  'participant',
  'callId',
  'token',
  'credential',
  'channel',
  'deviceLabel',
  'deviceId',
  'payload',
  'stack',
  'raw',
];

const _forbiddenServiceTerms = <String>[
  'cloud_firestore',
  'cloud_functions',
  'firebase_auth',
  'firebase_app_check',
  'FirebaseFirestore',
  'FirebaseFunctions',
  'FirebaseAuth',
  'FirebaseAppCheck',
  'Firebase.initializeApp',
];

const _forbiddenRtcPermissionExecutableTerms = <String>[
  'agora_rtc_engine',
  'permission_handler',
  'Permission.',
  '.request()',
  'RtcEngine',
  'createAgoraRtcEngine',
  'joinChannel',
  'leaveChannel',
  'renewToken',
  'enableAudio',
  'enableVideo',
  'startPreview',
  'stopPreview',
  'publishAudio',
  'publishVideo',
  'enumerateDevices',
  'availableCameras',
  'openCamera',
  'openMicrophone',
  'getUserMedia',
  'setEventHandler',
];

const _forbiddenUiRuntimeTerms = <String>[
  'ProductionCallV2StartupBridge',
  'CallV2ProductionComposition',
  'CallV2Runtime(',
  'startRuntime(',
  '.start()',
  'AppLifecycleListener',
  'WidgetsBindingObserver',
  'CallV2ProductionRouteObjectFactory(',
  'CallV2ProductionRouteSink',
  '.createRoute(',
  '.createScreen(',
  '.show(',
  'MethodChannel',
  'EventChannel',
];

const _forbiddenAsyncTerms = <String>[
  'dart:async',
  'dart:io',
  'Timer(',
  'StreamController',
  'StreamSubscription',
  'listen(',
];

const _forbiddenFirestoreExecutableTerms = <String>[
  '.collection(',
  '.doc(',
  '.snapshots(',
  '.get(',
  '.set(',
  '.update(',
  '.delete(',
  '.httpsCallable(',
  '.signIn',
  '.signOut',
  'addSnapshotListener',
  'onSnapshot',
  'runTransaction',
  'writeBatch',
];

final class _ThrowingCompositionFactory
    implements CallV2ProductionIntegrationCompositionFactory {
  const _ThrowingCompositionFactory({required this.onConstruct});

  final void Function() onConstruct;

  @override
  Object createProductionComposition() {
    onConstruct();
    throw StateError('must not construct composition');
  }
}
