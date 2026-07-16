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
import 'package:connect_app/call_v2/integration/call_v2_runtime_startup_owner_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final boundary = callV2RtcPermissionOwnerBoundary;

  test('RTC permission boundary artifact records hard-disabled status', () {
    expect(boundary, isA<CallV2RtcPermissionOwnerBoundary>());
    expect(boundary.isDeveloperOnly, isTrue);
    expect(boundary.isHardDisabled, isTrue);
    expect(boundary.isRolloutEnabled, isFalse);
    expect(boundary.isReachable, isFalse);
    expect(boundary.importsRtcPermissionPackages, isFalse);
    expect(boundary.createsRtcEngine, isFalse);
    expect(boundary.joinsRtcChannel, isFalse);
    expect(boundary.consumesRtcTokenChannel, isFalse);
    expect(boundary.requestsPermission, isFalse);
    expect(boundary.promptsMicrophoneCamera, isFalse);
    expect(boundary.enumeratesDevices, isFalse);
    expect(boundary.capturesMedia, isFalse);
    expect(boundary.startsCameraPreview, isFalse);
    expect(boundary.publishesAudioVideo, isFalse);
    expect(boundary.opensRtcCallbacksListenersSubscriptions, isFalse);
    expect(boundary.constructsRuntime, isFalse);
    expect(boundary.startsRuntime, isFalse);
    expect(boundary.accessesBackendFirebase, isFalse);
    expect(boundary.accessesNavigation, isFalse);
    expect(boundary.registersLifecycleObserver, isFalse);
    expect(boundary.mutatesRouteRegistry, isFalse);
    expect(boundary.opensAsyncHandles, isFalse);
    expect(boundary.changesPubspecPlatformConfig, isFalse);
    expect(boundary.isDeploymentApproved, isFalse);
    expect(boundary.protectsV1, isTrue);
    expect(boundary.isStrictlyClosed, isTrue);
    expect(boundary.statuses, hasLength(25));
  });

  test('RTC permission enums contain the approved developer-only vocabulary',
      () {
    expect(
      boundary.actions,
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
      boundary.permissionResults,
      <CallV2SanitizedPermissionResult>[
        CallV2SanitizedPermissionResult.microphoneGranted,
        CallV2SanitizedPermissionResult.cameraGranted,
        CallV2SanitizedPermissionResult.microphoneDenied,
        CallV2SanitizedPermissionResult.cameraDenied,
        CallV2SanitizedPermissionResult.permissionUnknown,
      ],
    );
    expect(
      boundary.rtcEvents,
      <CallV2SanitizedRtcEvent>[
        CallV2SanitizedRtcEvent.rtcPrepared,
        CallV2SanitizedRtcEvent.rtcJoined,
        CallV2SanitizedRtcEvent.rtcPublishing,
        CallV2SanitizedRtcEvent.rtcEnded,
        CallV2SanitizedRtcEvent.rtcFailed,
        CallV2SanitizedRtcEvent.rtcUnknown,
      ],
    );
  });

  test('every RTC permission action is disabled inert by default', () {
    for (final action in boundary.actions) {
      final decision = boundary.decideWhileDisabled(
        action: action,
        generation: boundary.actions.indexOf(action) + 1,
        permissionResult: CallV2SanitizedPermissionResult.microphoneGranted,
        rtcEvent: CallV2SanitizedRtcEvent.rtcPrepared,
      );

      expect(
        decision.kind,
        CallV2RtcPermissionOwnerDecisionKind.disabledInert,
        reason: action.name,
      );
      _expectNoDecisionSideEffects(decision);
    }
  });

  test('generation permission event ownership and terminal decisions are safe',
      () {
    final duplicate = boundary.decideWhileDisabled(
      action: CallV2RtcPermissionOwnerAction.prepareRtcPermissionOwner,
      generation: 3,
      latestGeneration: 3,
    );
    final stale = boundary.decideWhileDisabled(
      action: CallV2RtcPermissionOwnerAction.prepareRtcPermissionOwner,
      generation: 2,
      latestGeneration: 3,
    );
    final microphoneDenied = boundary.decideWhileDisabled(
      action: CallV2RtcPermissionOwnerAction.requestMicrophone,
      generation: 4,
      permissionResult: CallV2SanitizedPermissionResult.microphoneDenied,
    );
    final cameraDenied = boundary.decideWhileDisabled(
      action: CallV2RtcPermissionOwnerAction.requestCamera,
      generation: 5,
      permissionResult: CallV2SanitizedPermissionResult.cameraDenied,
    );
    final unsafe = boundary.decideWhileDisabled(
      action: CallV2RtcPermissionOwnerAction.prepareRtcEngine,
      generation: 6,
      previousRtcEvent: CallV2SanitizedRtcEvent.rtcPublishing,
      rtcEvent: CallV2SanitizedRtcEvent.rtcPrepared,
    );
    final ownership = boundary.decideWhileDisabled(
      action: CallV2RtcPermissionOwnerAction.joinRtcChannel,
      generation: 7,
      ownershipMatches: false,
    );
    final rawDevice = boundary.decideWhileDisabled(
      action: CallV2RtcPermissionOwnerAction.enumerateDevices,
      generation: 8,
      rawDeviceProvided: true,
    );
    final terminal = boundary.decideWhileDisabled(
      action: CallV2RtcPermissionOwnerAction.disposeRtc,
      generation: 9,
      terminal: true,
      rtcEvent: CallV2SanitizedRtcEvent.rtcEnded,
    );

    expect(
      duplicate.kind,
      CallV2RtcPermissionOwnerDecisionKind.duplicateNoOp,
    );
    expect(stale.kind, CallV2RtcPermissionOwnerDecisionKind.staleIgnored);
    expect(
      microphoneDenied.kind,
      CallV2RtcPermissionOwnerDecisionKind.permissionDeniedRejected,
    );
    expect(
      cameraDenied.kind,
      CallV2RtcPermissionOwnerDecisionKind.permissionDeniedRejected,
    );
    expect(
      unsafe.kind,
      CallV2RtcPermissionOwnerDecisionKind.unsafeTransitionRejected,
    );
    expect(
      ownership.kind,
      CallV2RtcPermissionOwnerDecisionKind.ownershipRejected,
    );
    expect(
      rawDevice.kind,
      CallV2RtcPermissionOwnerDecisionKind.rawDeviceRejected,
    );
    expect(
      terminal.kind,
      CallV2RtcPermissionOwnerDecisionKind.terminalIgnored,
    );

    for (final decision in <CallV2RtcPermissionOwnerDecision>[
      duplicate,
      stale,
      microphoneDenied,
      cameraDenied,
      unsafe,
      ownership,
      rawDevice,
      terminal,
    ]) {
      _expectNoDecisionSideEffects(decision);
    }
  });

  test('safe debug output contains no sensitive material', () {
    final decision = boundary.decideWhileDisabled(
      action: CallV2RtcPermissionOwnerAction.joinRtcChannel,
      generation: 1,
      permissionResult: CallV2SanitizedPermissionResult.cameraGranted,
      rtcEvent: CallV2SanitizedRtcEvent.rtcJoined,
    );
    final debugText = '${boundary.toSafeDebugMap()} $boundary '
        '${decision.toSafeDebugMap()} $decision';

    expect(boundary.toSafeDebugMap()['actionCount'], 9);
    expect(boundary.toSafeDebugMap()['permissionResultCount'], 5);
    expect(boundary.toSafeDebugMap()['rtcEventCount'], 6);
    expect(boundary.toSafeDebugMap()['hardDisabled'], isTrue);
    for (final forbidden in _forbiddenDebugTerms) {
      expect(debugText, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('boundary source has no imports or executable service hooks', () {
    final source = _read(
      'lib/call_v2/integration/call_v2_rtc_permission_owner.dart',
    );

    expect(source, isNot(contains('import ')));
    for (final forbidden in <String>[
      ..._forbiddenImportsAndServices,
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
  });

  test('approval scope pre-wiring and skeleton composition remain closed', () {
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

  test('real app platform backend and config files do not reference boundary',
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
        isNot(contains('call_v2_rtc_permission_owner')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2RtcPermissionOwnerBoundary')),
        reason: path,
      );
    }
  });

  test('rollback remains one commit no-deploy and V1-safe', () {
    expect(boundary.rollbackPreserved, isTrue);
    expect(
      boundary.rollback,
      <CallV2RtcPermissionOwnerRollback>[
        CallV2RtcPermissionOwnerRollback.oneCommitRevert,
        CallV2RtcPermissionOwnerRollback.keepRolloutFalse,
        CallV2RtcPermissionOwnerRollback.keepRouteRegistryNull,
        CallV2RtcPermissionOwnerRollback.keepDisabledOwnerInert,
        CallV2RtcPermissionOwnerRollback.noDeploymentRequired,
        CallV2RtcPermissionOwnerRollback.noConfigChanges,
        CallV2RtcPermissionOwnerRollback.v1Unaffected,
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

const _forbiddenImportsAndServices = <String>[
  "import 'package:flutter",
  "import 'dart:",
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
