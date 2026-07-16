import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_backend_firebase_owner_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_backend_firebase_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_lifecycle_observer_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_navigator_owner_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_pre_wiring_safety_gate.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_route_registration_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_rtc_permission_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_rtc_permission_owner_skeleton.dart'
    as skeleton;
import 'package:connect_app/call_v2/integration/call_v2_developer_runtime_startup_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_skeleton_composition_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_lifecycle_observer_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_navigator_owner_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_integration_status.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_rtc_permission_owner.dart';
import 'package:connect_app/call_v2/integration/call_v2_rtc_permission_owner_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_runtime_startup_owner_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final audit = callV2RtcPermissionOwnerHardeningAudit;

  test('hardening audit artifact passes for disabled RTC permission owner', () {
    expect(audit, isA<CallV2RtcPermissionOwnerHardeningAudit>());
    expect(
      audit.decision,
      CallV2RtcPermissionOwnerHardeningAuditDecision.pass,
    );
    expect(audit.passes, isTrue);
    expect(audit.recordsDeveloperOnly, isTrue);
    expect(audit.recordsHardDisabled, isTrue);
    expect(audit.recordsRolloutFalse, isTrue);
    expect(audit.recordsUnreachable, isTrue);
    expect(audit.recordsNoRtcPermissionImports, isTrue);
    expect(audit.recordsNoRtcEngineCreation, isTrue);
    expect(audit.recordsNoRtcChannelJoin, isTrue);
    expect(audit.recordsNoRtcTokenChannelConsumption, isTrue);
    expect(audit.recordsNoPermissionRequest, isTrue);
    expect(audit.recordsNoMicrophoneCameraPrompt, isTrue);
    expect(audit.recordsNoDeviceEnumeration, isTrue);
    expect(audit.recordsNoMediaCapture, isTrue);
    expect(audit.recordsNoCameraPreview, isTrue);
    expect(audit.recordsNoAudioVideoPublish, isTrue);
    expect(audit.recordsNoRtcCallbacksListenersSubscriptions, isTrue);
    expect(audit.recordsNoRuntimeConstruction, isTrue);
    expect(audit.recordsNoRuntimeStart, isTrue);
    expect(audit.recordsNoBackendFirebaseAccess, isTrue);
    expect(audit.recordsNoNavigationAccess, isTrue);
    expect(audit.recordsNoLifecycleRegistration, isTrue);
    expect(audit.recordsNoRouteRegistryMutation, isTrue);
    expect(audit.recordsNoAsyncHandles, isTrue);
    expect(audit.recordsNoPubspecPlatformConfigChanges, isTrue);
    expect(audit.recordsNoDeployment, isTrue);
    expect(audit.protectsV1, isTrue);
  });

  test('actions permission results and RTC events are exact', () {
    expect(
      audit.boundary.actions,
      <CallV2RtcPermissionOwnerAction>[
        CallV2RtcPermissionOwnerAction.prepareRtcPermissionOwner,
        CallV2RtcPermissionOwnerAction.requestMicrophone,
        CallV2RtcPermissionOwnerAction.requestCamera,
        CallV2RtcPermissionOwnerAction.prepareRtcEngine,
        CallV2RtcPermissionOwnerAction.joinRtcChannel,
        CallV2RtcPermissionOwnerAction.publishAudio,
        CallV2RtcPermissionOwnerAction.publishVideo,
        CallV2RtcPermissionOwnerAction.enumerateDevices,
        CallV2RtcPermissionOwnerAction.disposeRtc,
      ],
    );
    expect(
      audit.boundary.permissionResults,
      <CallV2SanitizedPermissionResult>[
        CallV2SanitizedPermissionResult.microphoneGranted,
        CallV2SanitizedPermissionResult.cameraGranted,
        CallV2SanitizedPermissionResult.microphoneDenied,
        CallV2SanitizedPermissionResult.cameraDenied,
        CallV2SanitizedPermissionResult.permissionUnknown,
      ],
    );
    expect(
      audit.boundary.rtcEvents,
      <CallV2SanitizedRtcEvent>[
        CallV2SanitizedRtcEvent.rtcPrepared,
        CallV2SanitizedRtcEvent.rtcJoined,
        CallV2SanitizedRtcEvent.rtcPublishing,
        CallV2SanitizedRtcEvent.rtcEnded,
        CallV2SanitizedRtcEvent.rtcFailed,
        CallV2SanitizedRtcEvent.rtcUnknown,
      ],
    );
    expect(audit.actionsAreExact, isTrue);
    expect(audit.permissionResultsAreExact, isTrue);
    expect(audit.rtcEventsAreExact, isTrue);
  });

  test('decision behavior is exact and side-effect free', () {
    expect(audit.defaultDecisionsAreInert, isTrue);
    expect(audit.duplicateDecisionIsNoOp, isTrue);
    expect(audit.staleDecisionIsIgnored, isTrue);
    expect(audit.permissionDeniedIsRejected, isTrue);
    expect(audit.unsafeTransitionIsRejected, isTrue);
    expect(audit.ownershipMismatchIsRejected, isTrue);
    expect(audit.rawDeviceIsRejected, isTrue);
    expect(audit.terminalDecisionIsIgnored, isTrue);

    for (final action in audit.boundary.actions) {
      _expectNoDecisionSideEffects(
        audit.boundary.decideWhileDisabled(
          action: action,
          generation: audit.boundary.actions.indexOf(action) + 1,
        ),
      );
    }

    for (final decision in <CallV2RtcPermissionOwnerDecision>[
      audit.boundary.decideWhileDisabled(
        action: CallV2RtcPermissionOwnerAction.prepareRtcPermissionOwner,
        generation: 2,
        latestGeneration: 2,
      ),
      audit.boundary.decideWhileDisabled(
        action: CallV2RtcPermissionOwnerAction.prepareRtcPermissionOwner,
        generation: 1,
        latestGeneration: 2,
      ),
      audit.boundary.decideWhileDisabled(
        action: CallV2RtcPermissionOwnerAction.requestMicrophone,
        generation: 3,
        permissionResult: CallV2SanitizedPermissionResult.microphoneDenied,
      ),
      audit.boundary.decideWhileDisabled(
        action: CallV2RtcPermissionOwnerAction.requestCamera,
        generation: 4,
        permissionResult: CallV2SanitizedPermissionResult.cameraDenied,
      ),
      audit.boundary.decideWhileDisabled(
        action: CallV2RtcPermissionOwnerAction.prepareRtcEngine,
        generation: 5,
        previousRtcEvent: CallV2SanitizedRtcEvent.rtcPublishing,
        rtcEvent: CallV2SanitizedRtcEvent.rtcPrepared,
      ),
      audit.boundary.decideWhileDisabled(
        action: CallV2RtcPermissionOwnerAction.joinRtcChannel,
        generation: 6,
        ownershipMatches: false,
      ),
      audit.boundary.decideWhileDisabled(
        action: CallV2RtcPermissionOwnerAction.enumerateDevices,
        generation: 7,
        rawDeviceProvided: true,
      ),
      audit.boundary.decideWhileDisabled(
        action: CallV2RtcPermissionOwnerAction.disposeRtc,
        generation: 8,
        terminal: true,
      ),
    ]) {
      _expectNoDecisionSideEffects(decision);
    }
  });

  test('safe debug output contains no sensitive data', () {
    final debugText = '${audit.toSafeDebugMap()} $audit '
        '${audit.boundary.toSafeDebugMap()} ${audit.boundary} '
        '${audit.boundary.decideWhileDisabled(
      action: CallV2RtcPermissionOwnerAction.joinRtcChannel,
      generation: 1,
      rtcEvent: CallV2SanitizedRtcEvent.rtcJoined,
    )}';

    expect(audit.toSafeDebugMap()['statusCount'], 40);
    expect(audit.toSafeDebugMap()['rollbackCount'], 7);
    expect(audit.toSafeDebugMap()['actionCount'], 9);
    expect(audit.toSafeDebugMap()['permissionResultCount'], 5);
    expect(audit.toSafeDebugMap()['rtcEventCount'], 6);

    for (final forbidden in _forbiddenDebugTerms) {
      expect(debugText, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('rollout route registry disabled owner and prior audits remain closed',
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
    expect(audit.recordsRouteRegistryNullWhileFalse, isTrue);
    expect(audit.recordsDisabledOwnerInert, isTrue);

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
  });

  test('approval scopes and skeleton audit remain closed', () {
    expect(callV2DeveloperRtcPermissionApprovalScope.isStrictlyClosed, isTrue);
    expect(
      callV2DeveloperPreWiringSafetyGate.decision,
      CallV2DeveloperPreWiringGateDecision.blockedNoScopeSelected,
    );
    expect(
      callV2DeveloperSkeletonCompositionAudit.decision,
      CallV2DeveloperSkeletonCompositionDecision.pass,
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
      callV2DeveloperLifecycleObserverApprovalScope.rollbackPreserved,
      isTrue,
    );
    expect(
      callV2DeveloperRouteRegistrationApprovalScope.rollbackPreserved,
      isTrue,
    );
    expect(
      skeleton.callV2DeveloperRtcPermissionOwnerSkeleton.isHardDisabled,
      isTrue,
    );
  });

  test('boundary source has no imports services or executable hooks', () {
    final source = _read(
      'lib/call_v2/integration/call_v2_rtc_permission_owner.dart',
    );

    expect(source, isNot(contains('import ')));
    for (final forbidden in <String>[
      ..._forbiddenServiceTerms,
      ..._forbiddenAsyncTerms,
      ..._forbiddenRtcPermissionExecutableTerms,
      ..._forbiddenFirestoreExecutableTerms,
      'Navigator',
      'GlobalKey',
      'BuildContext',
      'MaterialApp',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('hardening audit source has no forbidden imports or hooks', () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_rtc_permission_owner_hardening_audit.dart',
    );

    for (final forbidden in <String>[
      "import 'package:flutter",
      "import 'dart:",
      ..._forbiddenServiceTerms,
      ..._forbiddenAsyncTerms,
      ..._forbiddenRtcPermissionExecutableTerms,
      ..._forbiddenFirestoreExecutableTerms,
      'Navigator',
      'GlobalKey',
      'BuildContext',
      'MaterialApp',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('real app platform backend and config files do not reference audit', () {
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
        isNot(contains('call_v2_rtc_permission_owner_hardening_audit')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2RtcPermissionOwnerHardeningAudit')),
        reason: path,
      );
    }
  });

  test('rollback model preserves one commit no-deploy V1-safe recovery', () {
    expect(audit.rollbackPreserved, isTrue);
    expect(
      audit.rollback,
      <CallV2RtcPermissionOwnerHardeningRollback>[
        CallV2RtcPermissionOwnerHardeningRollback.oneCommitRevert,
        CallV2RtcPermissionOwnerHardeningRollback.keepRolloutFalse,
        CallV2RtcPermissionOwnerHardeningRollback.keepRouteRegistryNull,
        CallV2RtcPermissionOwnerHardeningRollback.keepDisabledOwnerInert,
        CallV2RtcPermissionOwnerHardeningRollback.noDeploymentRequired,
        CallV2RtcPermissionOwnerHardeningRollback.noConfigChanges,
        CallV2RtcPermissionOwnerHardeningRollback.v1Unaffected,
      ],
    );
  });
}

void _expectNoDecisionSideEffects(CallV2RtcPermissionOwnerDecision decision) {
  expect(decision.importsRtcPermissionPackages, isFalse);
  expect(decision.createsRtcEngine, isFalse);
  expect(decision.joinsRtcChannel, isFalse);
  expect(decision.consumesRtcTokenChannel, isFalse);
  expect(decision.requestsPermission, isFalse);
  expect(decision.promptsMicrophoneCamera, isFalse);
  expect(decision.enumeratesDevices, isFalse);
  expect(decision.capturesMedia, isFalse);
  expect(decision.startsCameraPreview, isFalse);
  expect(decision.publishesAudioVideo, isFalse);
  expect(decision.opensRtcCallbacksListenersSubscriptions, isFalse);
  expect(decision.constructsRuntime, isFalse);
  expect(decision.startsRuntime, isFalse);
  expect(decision.accessesBackendFirebase, isFalse);
  expect(decision.accessesNavigation, isFalse);
  expect(decision.registersLifecycleObserver, isFalse);
  expect(decision.mutatesRouteRegistry, isFalse);
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
  "import 'package:flutter",
  'package:firebase',
  'package:agora',
  'package:permission',
  'cloud_firestore',
  'cloud_functions',
  'firebase_auth',
  'firebase_app_check',
  'FirebaseFirestore',
  'FirebaseFunctions',
  'FirebaseAuth',
  'FirebaseAppCheck',
  'Firebase.initializeApp',
  'CallV2Runtime(',
  'ProductionCallV2StartupBridge',
  'CallV2ProductionComposition',
  'CallV2ProductionRouteSink',
  'CallV2ProductionRouteObjectFactory(',
  'MethodChannel',
  'EventChannel',
];

const _forbiddenAsyncTerms = <String>[
  'Timer(',
  'StreamController',
  'StreamSubscription',
  'listen(',
  'addListener',
  'removeListener',
];

const _forbiddenRtcPermissionExecutableTerms = <String>[
  'agora_rtc_engine',
  'permission_handler',
  'Permission.',
  '.request()',
  'RtcEngine(',
  'createAgoraRtcEngine',
  'joinChannel(',
  'leaveChannel(',
  'renewToken(',
  'enableAudio(',
  'enableVideo(',
  'startPreview(',
  'stopPreview(',
  'publishAudio(',
  'publishVideo(',
  'enumerateDevices(',
  'availableCameras(',
  'openCamera(',
  'openMicrophone(',
  'getUserMedia(',
  'setEventHandler(',
  'registerEventHandler(',
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
    throw StateError('composition must remain unconstructed while disabled');
  }
}
