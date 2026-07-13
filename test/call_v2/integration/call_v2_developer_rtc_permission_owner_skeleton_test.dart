import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_developer_backend_firebase_owner_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_lifecycle_observer_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_navigator_owner_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_route_registration_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_rtc_permission_owner_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_runtime_startup_owner_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final skeleton = callV2DeveloperRtcPermissionOwnerSkeleton;

  test('skeleton exists and is developer-only hard-disabled evidence', () {
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
    expect(skeleton.constructsComposition, isFalse);
    expect(skeleton.wiresStartupBridge, isFalse);
    expect(skeleton.mutatesRouteRegistry, isFalse);
    expect(skeleton.accessesNavigation, isFalse);
    expect(skeleton.opensAsyncHandles, isFalse);
    expect(skeleton.changesPubspecPlatformConfig, isFalse);
    expect(skeleton.isDeploymentApproved, isFalse);
    expect(skeleton.protectsV1, isTrue);
  });

  test('RTC permission action enum contains the approved future action set',
      () {
    expect(
      skeleton.actions,
      <CallV2DeveloperRtcPermissionAction>[
        CallV2DeveloperRtcPermissionAction.prepareRtcPermissionOwner,
        CallV2DeveloperRtcPermissionAction.requestPermissionGate,
        CallV2DeveloperRtcPermissionAction.receiveSanitizedPermissionResult,
        CallV2DeveloperRtcPermissionAction.requestRtcAttach,
        CallV2DeveloperRtcPermissionAction.receiveSanitizedRtcEvent,
        CallV2DeveloperRtcPermissionAction.detachRtcOwner,
        CallV2DeveloperRtcPermissionAction.disposeRtcOwner,
      ],
    );
  });

  test('sanitized permission result enum contains approved variants', () {
    expect(
      skeleton.sanitizedPermissionResults,
      <CallV2DeveloperSanitizedPermissionResult>[
        CallV2DeveloperSanitizedPermissionResult.microphoneGranted,
        CallV2DeveloperSanitizedPermissionResult.microphoneDenied,
        CallV2DeveloperSanitizedPermissionResult.microphonePermanentlyDenied,
        CallV2DeveloperSanitizedPermissionResult.cameraGranted,
        CallV2DeveloperSanitizedPermissionResult.cameraDenied,
        CallV2DeveloperSanitizedPermissionResult.cameraPermanentlyDenied,
        CallV2DeveloperSanitizedPermissionResult.permissionUnavailable,
      ],
    );
  });

  test('sanitized RTC event enum contains approved future events', () {
    expect(
      skeleton.sanitizedRtcEvents,
      <CallV2DeveloperSanitizedRtcEvent>[
        CallV2DeveloperSanitizedRtcEvent.rtcPrepared,
        CallV2DeveloperSanitizedRtcEvent.rtcConnecting,
        CallV2DeveloperSanitizedRtcEvent.rtcJoined,
        CallV2DeveloperSanitizedRtcEvent.rtcReconnecting,
        CallV2DeveloperSanitizedRtcEvent.rtcRemoteJoined,
        CallV2DeveloperSanitizedRtcEvent.rtcRemoteLeft,
        CallV2DeveloperSanitizedRtcEvent.rtcLeaving,
        CallV2DeveloperSanitizedRtcEvent.rtcLeft,
        CallV2DeveloperSanitizedRtcEvent.rtcFailure,
        CallV2DeveloperSanitizedRtcEvent.rtcTimeout,
      ],
    );
  });

  test('ownership rules preserve disabled RTC permission boundaries', () {
    expect(
      skeleton.ownershipRules,
      <CallV2DeveloperRtcPermissionOwnershipRule>[
        CallV2DeveloperRtcPermissionOwnershipRule.explicitHumanApprovalRequired,
        CallV2DeveloperRtcPermissionOwnershipRule
            .developerOnlyAllowlistRequired,
        CallV2DeveloperRtcPermissionOwnershipRule
            .rolloutFalseBlocksRtcPermissionAttach,
        CallV2DeveloperRtcPermissionOwnershipRule.noRtcPermissionImports,
        CallV2DeveloperRtcPermissionOwnershipRule.noRtcEngineInitialization,
        CallV2DeveloperRtcPermissionOwnershipRule.noRtcChannelJoin,
        CallV2DeveloperRtcPermissionOwnershipRule.noRtcTokenChannelConsumption,
        CallV2DeveloperRtcPermissionOwnershipRule.noPermissionPrompt,
        CallV2DeveloperRtcPermissionOwnershipRule.noDeviceEnumeration,
        CallV2DeveloperRtcPermissionOwnershipRule.noMediaCapture,
        CallV2DeveloperRtcPermissionOwnershipRule.noAudioVideoPublish,
        CallV2DeveloperRtcPermissionOwnershipRule.noRtcCallbacksOrSubscriptions,
        CallV2DeveloperRtcPermissionOwnershipRule
            .sanitizedEnumBooleanGenerationOnly,
        CallV2DeveloperRtcPermissionOwnershipRule.duplicateRtcEventNoOp,
        CallV2DeveloperRtcPermissionOwnershipRule.staleRtcEventIgnored,
        CallV2DeveloperRtcPermissionOwnershipRule
            .permissionDeniedControlledFailure,
        CallV2DeveloperRtcPermissionOwnershipRule
            .permanentlyDeniedRequiresUserAction,
        CallV2DeveloperRtcPermissionOwnershipRule.missingCredentialRejected,
        CallV2DeveloperRtcPermissionOwnershipRule.terminalRtcEventDetaches,
        CallV2DeveloperRtcPermissionOwnershipRule.mediaFailureControlledOnly,
      ],
    );
  });

  test('every RTC permission action returns disabled inert while rollout false',
      () {
    for (final action in skeleton.actions) {
      final decision = skeleton.decideWhileDisabled(
        action: action,
        generation: skeleton.actions.indexOf(action) + 1,
        permissionResult:
            CallV2DeveloperSanitizedPermissionResult.microphoneGranted,
        rtcEvent: CallV2DeveloperSanitizedRtcEvent.rtcJoined,
      );

      expect(
        decision.status,
        CallV2DeveloperRtcPermissionDecisionStatus.disabledInert,
      );
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
      expect(decision.mutatesV1State, isFalse);
      expect(decision.opensAsyncHandles, isFalse);
      expect(decision.changesPubspecPlatformConfig, isFalse);
      expect(decision.controlledFailureOnly, isTrue);
    }
  });

  test('duplicate and stale RTC events are safe no-ops', () {
    final duplicate = skeleton.decideWhileDisabled(
      action: CallV2DeveloperRtcPermissionAction.receiveSanitizedRtcEvent,
      generation: 11,
      latestGeneration: 11,
      rtcEvent: CallV2DeveloperSanitizedRtcEvent.rtcReconnecting,
    );
    final stale = skeleton.decideWhileDisabled(
      action: CallV2DeveloperRtcPermissionAction.receiveSanitizedRtcEvent,
      generation: 10,
      latestGeneration: 11,
      rtcEvent: CallV2DeveloperSanitizedRtcEvent.rtcRemoteJoined,
    );

    expect(
      duplicate.status,
      CallV2DeveloperRtcPermissionDecisionStatus.duplicateNoOp,
    );
    expect(
      duplicate.rejection,
      CallV2DeveloperRtcPermissionRejection.duplicateGeneration,
    );
    expect(
      stale.status,
      CallV2DeveloperRtcPermissionDecisionStatus.staleIgnored,
    );
    expect(
        stale.rejection, CallV2DeveloperRtcPermissionRejection.staleGeneration);

    for (final decision in <CallV2DeveloperRtcPermissionDecision>[
      duplicate,
      stale,
    ]) {
      expect(decision.initializesRtcEngine, isFalse);
      expect(decision.joinsRtcChannel, isFalse);
      expect(decision.promptsForPermissions, isFalse);
      expect(decision.opensRtcCallbacksOrSubscriptions, isFalse);
      expect(decision.startsRuntime, isFalse);
      expect(decision.accessesNavigation, isFalse);
      expect(decision.mutatesV1State, isFalse);
    }
  });

  test('denied missing terminal media failure and raw payload are controlled',
      () {
    final denied = skeleton.decideWhileDisabled(
      action:
          CallV2DeveloperRtcPermissionAction.receiveSanitizedPermissionResult,
      generation: 1,
      permissionResult:
          CallV2DeveloperSanitizedPermissionResult.microphoneDenied,
    );
    final permanentlyDenied = skeleton.decideWhileDisabled(
      action:
          CallV2DeveloperRtcPermissionAction.receiveSanitizedPermissionResult,
      generation: 2,
      permissionResult:
          CallV2DeveloperSanitizedPermissionResult.cameraPermanentlyDenied,
    );
    final missingCredential = skeleton.decideWhileDisabled(
      action: CallV2DeveloperRtcPermissionAction.requestRtcAttach,
      generation: 3,
      missingCredential: true,
    );
    final terminal = skeleton.decideWhileDisabled(
      action: CallV2DeveloperRtcPermissionAction.receiveSanitizedRtcEvent,
      generation: 4,
      rtcEvent: CallV2DeveloperSanitizedRtcEvent.rtcLeft,
    );
    final mediaUnavailable = skeleton.decideWhileDisabled(
      action:
          CallV2DeveloperRtcPermissionAction.receiveSanitizedPermissionResult,
      generation: 5,
      permissionResult:
          CallV2DeveloperSanitizedPermissionResult.permissionUnavailable,
    );
    final rtcFailure = skeleton.decideWhileDisabled(
      action: CallV2DeveloperRtcPermissionAction.receiveSanitizedRtcEvent,
      generation: 6,
      rtcEvent: CallV2DeveloperSanitizedRtcEvent.rtcFailure,
    );
    final rawPayload = skeleton.decideWhileDisabled(
      action: CallV2DeveloperRtcPermissionAction.receiveSanitizedRtcEvent,
      generation: 7,
      rawPayloadProvided: true,
    );
    final controlledFailure = skeleton.decideWhileDisabled(
      action: CallV2DeveloperRtcPermissionAction.receiveSanitizedRtcEvent,
      generation: 8,
      controlledFailure: true,
    );

    expect(denied.status, CallV2DeveloperRtcPermissionDecisionStatus.rejected);
    expect(
      denied.rejection,
      CallV2DeveloperRtcPermissionRejection.permissionDenied,
    );
    expect(
      permanentlyDenied.rejection,
      CallV2DeveloperRtcPermissionRejection.permissionPermanentlyDenied,
    );
    expect(
      missingCredential.rejection,
      CallV2DeveloperRtcPermissionRejection.missingCredential,
    );
    expect(
        terminal.status, CallV2DeveloperRtcPermissionDecisionStatus.detached);
    expect(
      mediaUnavailable.rejection,
      CallV2DeveloperRtcPermissionRejection.mediaUnavailable,
    );
    expect(
      rtcFailure.rejection,
      CallV2DeveloperRtcPermissionRejection.rtcFailure,
    );
    expect(
      rawPayload.rejection,
      CallV2DeveloperRtcPermissionRejection.rawPayloadRejected,
    );
    expect(
      controlledFailure.rejection,
      CallV2DeveloperRtcPermissionRejection.controlledFailure,
    );

    for (final decision in <CallV2DeveloperRtcPermissionDecision>[
      denied,
      permanentlyDenied,
      missingCredential,
      terminal,
      mediaUnavailable,
      rtcFailure,
      rawPayload,
      controlledFailure,
    ]) {
      expect(decision.initializesRtcEngine, isFalse);
      expect(decision.joinsRtcChannel, isFalse);
      expect(decision.consumesRtcCredentialMaterial, isFalse);
      expect(decision.promptsForPermissions, isFalse);
      expect(decision.enumeratesDevices, isFalse);
      expect(decision.capturesMedia, isFalse);
      expect(decision.publishesAudioVideo, isFalse);
      expect(decision.opensRtcCallbacksOrSubscriptions, isFalse);
      expect(decision.startsRuntime, isFalse);
      expect(decision.mutatesRouteRegistry, isFalse);
      expect(decision.mutatesV1State, isFalse);
      expect(decision.controlledFailureOnly, isTrue);
    }
  });

  test('safe debug output exposes counts booleans and no sensitive data', () {
    final debugText = '${skeleton.toSafeDebugMap()} $skeleton '
        '${skeleton.decideWhileDisabled(
      action: CallV2DeveloperRtcPermissionAction.requestRtcAttach,
      generation: 1,
      permissionResult:
          CallV2DeveloperSanitizedPermissionResult.microphoneGranted,
      rtcEvent: CallV2DeveloperSanitizedRtcEvent.rtcJoined,
    )}';

    expect(skeleton.toSafeDebugMap()['actionCount'], 7);
    expect(skeleton.toSafeDebugMap()['permissionResultCount'], 7);
    expect(skeleton.toSafeDebugMap()['rtcEventCount'], 10);
    expect(skeleton.toSafeDebugMap()['hardDisabled'], isTrue);
    for (final forbidden in <String>[
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
    ]) {
      expect(debugText, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('rollout route registry disabled registry and owner remain inert',
      () async {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);

    for (final routeName in <String>[
      '/call-v2/connecting',
      '/call-v2/audio',
      '/call-v2/video',
      '/call-v2/failure',
      '/call-v2/ready',
      '/',
      '/home',
      '/chat',
    ]) {
      expect(resolveCallV2Route(RouteSettings(name: routeName)), isNull);
      expect(
        const DisabledCallV2RouteRegistry().resolve(
          RouteSettings(name: routeName),
        ),
        isNull,
      );
    }

    final owner = DisabledCallV2ProductionIntegrationOwner();
    await owner.initialize();

    expect(owner.status.rolloutEnabled, isFalse);
    expect(owner.status.compositionConstructed, isFalse);
    expect(owner.status.runtimeStarted, isFalse);
    expect(owner.status.routesRegistered, isFalse);
    expect(owner.status.screensAvailable, isFalse);
  });

  test('previous developer skeletons remain hard-disabled', () {
    expect(callV2DeveloperRouteRegistrationSkeleton.isHardDisabled, isTrue);
    expect(callV2DeveloperRouteRegistrationSkeleton.isReachable, isFalse);

    expect(callV2DeveloperLifecycleObserverSkeleton.isHardDisabled, isTrue);
    expect(callV2DeveloperLifecycleObserverSkeleton.isReachable, isFalse);
    expect(
      callV2DeveloperLifecycleObserverSkeleton.registersFrameworkHook,
      isFalse,
    );
    expect(
      callV2DeveloperLifecycleObserverSkeleton.registersBindingHook,
      isFalse,
    );

    expect(callV2DeveloperNavigatorOwnerSkeleton.isHardDisabled, isTrue);
    expect(callV2DeveloperNavigatorOwnerSkeleton.isReachable, isFalse);
    expect(callV2DeveloperNavigatorOwnerSkeleton.wiresRealNavigation, isFalse);

    expect(callV2DeveloperRuntimeStartupOwnerSkeleton.isHardDisabled, isTrue);
    expect(callV2DeveloperRuntimeStartupOwnerSkeleton.isReachable, isFalse);
    expect(callV2DeveloperRuntimeStartupOwnerSkeleton.startsRuntime, isFalse);

    expect(callV2DeveloperBackendOwnerSkeleton.isHardDisabled, isTrue);
    expect(callV2DeveloperBackendOwnerSkeleton.isReachable, isFalse);
    expect(callV2DeveloperBackendOwnerSkeleton.attachesBackend, isFalse);
  });

  test('RTC permission owner source has no RTC permission or async hooks', () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_developer_rtc_permission_owner_skeleton.dart',
    );

    for (final forbidden in <String>[
      "import 'package:",
      'package:flutter/',
      'agora_rtc_engine',
      'permission_handler',
      'package:camera',
      'package:microphone',
      'MethodChannel',
      'EventChannel',
      'RtcEngine(',
      'Agora',
      'WebRTC',
      'createAgoraRtcEngine',
      'initialize(',
      'joinChannel',
      'leaveChannel',
      'startPreview',
      'publishAudio',
      'publishVideo',
      'publishMicrophoneTrack',
      'publishCameraTrack',
      'enumerateDevices',
      'Permission.',
      '.request()',
      '.requestPermissions(',
      'Firebase',
      'Firestore',
      'Functions',
      'Auth',
      'Navigator.',
      'Navigator(',
      'GlobalKey',
      'BuildContext',
      'MaterialApp',
      'AppLifecycleListener',
      'WidgetsBindingObserver',
      'Timer(',
      'StreamController',
      'StreamSubscription',
      'listen(',
      'read(',
      'write(',
      'debugPrint',
      'print(',
    ]) {
      expect(source.contains(forbidden), isFalse, reason: forbidden);
    }
  });

  test('real app platform pubspec rules functions and startup remain isolated',
      () {
    const forbiddenReference =
        'call_v2_developer_rtc_permission_owner_skeleton';
    for (final path in <String>[
      'lib/main.dart',
      'lib/navigation/app_router.dart',
      'lib/call_v2/startup/production_call_v2_startup_bridge.dart',
      'lib/call_v2/production/call_v2_production_composition.dart',
      'lib/call_v2/integration/call_v2_route_registry.dart',
      'lib/call_v2/integration/disabled_call_v2_route_registry.dart',
      'lib/call_v2/integration/disabled_call_v2_production_integration_owner.dart',
      'connect_functions/index.js',
      'pubspec.yaml',
      'pubspec.lock',
      'firebase.json',
      'firestore.rules',
      'android/app/src/main/AndroidManifest.xml',
      'ios/Runner/Info.plist',
    ]) {
      expect(
        _read(path),
        isNot(contains(forbiddenReference)),
        reason: path,
      );
    }
  });

  test('rollback controls preserve disabled owner platform and V1 protection',
      () {
    expect(
      skeleton.rollbackRequirements,
      <CallV2DeveloperRtcPermissionRollback>[
        CallV2DeveloperRtcPermissionRollback.oneCommitRevert,
        CallV2DeveloperRtcPermissionRollback.keepRolloutFalse,
        CallV2DeveloperRtcPermissionRollback.keepRouteRegistryNull,
        CallV2DeveloperRtcPermissionRollback.keepDisabledOwnerInert,
        CallV2DeveloperRtcPermissionRollback.noDeploymentRequired,
        CallV2DeveloperRtcPermissionRollback.noPubspecPlatformConfigChanges,
        CallV2DeveloperRtcPermissionRollback.v1Unaffected,
      ],
    );
  });
}

String _read(String path) => File(path).readAsStringSync();
