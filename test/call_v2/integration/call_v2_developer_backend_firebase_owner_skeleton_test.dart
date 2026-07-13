import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_developer_backend_firebase_owner_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_lifecycle_observer_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_navigator_owner_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_route_registration_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_runtime_startup_owner_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final skeleton = callV2DeveloperBackendOwnerSkeleton;

  test('skeleton exists and is developer-only hard-disabled evidence', () {
    expect(skeleton.isDeveloperOnly, isTrue);
    expect(skeleton.isHardDisabled, isTrue);
    expect(skeleton.isRolloutEnabled, isFalse);
    expect(skeleton.isReachable, isFalse);
    expect(skeleton.attachesBackend, isFalse);
    expect(skeleton.importsServices, isFalse);
    expect(skeleton.opensDocumentListeners, isFalse);
    expect(skeleton.readsOrWritesDocuments, isFalse);
    expect(skeleton.callsIdentityOrCallable, isFalse);
    expect(skeleton.handlesAppCheckDebugToken, isFalse);
    expect(skeleton.storesRawSnapshot, isFalse);
    expect(skeleton.constructsRuntime, isFalse);
    expect(skeleton.startsRuntime, isFalse);
    expect(skeleton.constructsComposition, isFalse);
    expect(skeleton.wiresStartupBridge, isFalse);
    expect(skeleton.mutatesRouteRegistry, isFalse);
    expect(skeleton.accessesNavigation, isFalse);
    expect(skeleton.accessesMedia, isFalse);
    expect(skeleton.promptsForCapabilities, isFalse);
    expect(skeleton.opensAsyncHandles, isFalse);
    expect(skeleton.changesServerRulesConfig, isFalse);
    expect(skeleton.isDeploymentApproved, isFalse);
    expect(skeleton.protectsV1, isTrue);
  });

  test('backend action enum contains the approved future action set', () {
    expect(
      skeleton.actions,
      <CallV2DeveloperBackendAction>[
        CallV2DeveloperBackendAction.prepareBackendOwner,
        CallV2DeveloperBackendAction.requestBackendAttach,
        CallV2DeveloperBackendAction.receiveSanitizedSnapshot,
        CallV2DeveloperBackendAction.rejectSnapshot,
        CallV2DeveloperBackendAction.detachBackendOwner,
        CallV2DeveloperBackendAction.disposeBackendOwner,
      ],
    );
  });

  test('sanitized backend event enum contains the approved future events', () {
    expect(
      skeleton.sanitizedEvents,
      <CallV2DeveloperSanitizedBackendEvent>[
        CallV2DeveloperSanitizedBackendEvent.sanitizedConnecting,
        CallV2DeveloperSanitizedBackendEvent.sanitizedRinging,
        CallV2DeveloperSanitizedBackendEvent.sanitizedActive,
        CallV2DeveloperSanitizedBackendEvent.sanitizedEnding,
        CallV2DeveloperSanitizedBackendEvent.sanitizedEnded,
        CallV2DeveloperSanitizedBackendEvent.sanitizedFailure,
        CallV2DeveloperSanitizedBackendEvent.sanitizedTimeout,
        CallV2DeveloperSanitizedBackendEvent.sanitizedRemoteDisconnect,
      ],
    );
  });

  test('ownership rules preserve disabled backend boundaries', () {
    expect(
      skeleton.ownershipRules,
      <CallV2DeveloperBackendOwnershipRule>[
        CallV2DeveloperBackendOwnershipRule.explicitHumanApprovalRequired,
        CallV2DeveloperBackendOwnershipRule.developerOnlyAllowlistRequired,
        CallV2DeveloperBackendOwnershipRule.rolloutFalseBlocksBackendAttach,
        CallV2DeveloperBackendOwnershipRule.noServiceImports,
        CallV2DeveloperBackendOwnershipRule.noDocumentListeners,
        CallV2DeveloperBackendOwnershipRule.noDocumentReadsWrites,
        CallV2DeveloperBackendOwnershipRule.noIdentityCallableCalls,
        CallV2DeveloperBackendOwnershipRule.noRawSnapshotStorage,
        CallV2DeveloperBackendOwnershipRule.noRawIdentityStorage,
        CallV2DeveloperBackendOwnershipRule.noRawCallableResultStorage,
        CallV2DeveloperBackendOwnershipRule.sanitizedEnumBooleanGenerationOnly,
        CallV2DeveloperBackendOwnershipRule.duplicateSnapshotNoOp,
        CallV2DeveloperBackendOwnershipRule.staleSnapshotIgnored,
        CallV2DeveloperBackendOwnershipRule.outOfOrderSnapshotRejected,
        CallV2DeveloperBackendOwnershipRule.ownershipMismatchRejected,
        CallV2DeveloperBackendOwnershipRule.terminalSnapshotDetaches,
        CallV2DeveloperBackendOwnershipRule.signOutIdentityInvalidDetaches,
        CallV2DeveloperBackendOwnershipRule.controlledFailureOnly,
      ],
    );
  });

  test('every backend action returns disabled inert while rollout false', () {
    for (final action in skeleton.actions) {
      final decision = skeleton.decideWhileDisabled(
        action: action,
        generation: skeleton.actions.indexOf(action) + 1,
        event: CallV2DeveloperSanitizedBackendEvent.sanitizedActive,
      );

      expect(
        decision.status,
        CallV2DeveloperBackendDecisionStatus.disabledInert,
      );
      expect(decision.attachesBackend, isFalse);
      expect(decision.importsServices, isFalse);
      expect(decision.opensDocumentListener, isFalse);
      expect(decision.readsOrWritesDocuments, isFalse);
      expect(decision.callsIdentityOrCallable, isFalse);
      expect(decision.handlesAppCheckDebugToken, isFalse);
      expect(decision.storesRawSnapshot, isFalse);
      expect(decision.constructsRuntime, isFalse);
      expect(decision.startsRuntime, isFalse);
      expect(decision.constructsComposition, isFalse);
      expect(decision.wiresStartupBridge, isFalse);
      expect(decision.mutatesRouteRegistry, isFalse);
      expect(decision.accessesNavigation, isFalse);
      expect(decision.accessesMedia, isFalse);
      expect(decision.promptsForCapabilities, isFalse);
      expect(decision.mutatesV1State, isFalse);
      expect(decision.opensAsyncHandles, isFalse);
      expect(decision.changesServerRulesConfig, isFalse);
      expect(decision.controlledFailureOnly, isTrue);
    }
  });

  test('duplicate stale out-of-order and ownership mismatch are controlled',
      () {
    final duplicate = skeleton.decideWhileDisabled(
      action: CallV2DeveloperBackendAction.receiveSanitizedSnapshot,
      generation: 7,
      latestGeneration: 7,
    );
    final stale = skeleton.decideWhileDisabled(
      action: CallV2DeveloperBackendAction.receiveSanitizedSnapshot,
      generation: 6,
      latestGeneration: 7,
    );
    final outOfOrder = skeleton.decideWhileDisabled(
      action: CallV2DeveloperBackendAction.receiveSanitizedSnapshot,
      generation: 8,
      event: CallV2DeveloperSanitizedBackendEvent.sanitizedRinging,
      previousEvent: CallV2DeveloperSanitizedBackendEvent.sanitizedActive,
    );
    final mismatch = skeleton.decideWhileDisabled(
      action: CallV2DeveloperBackendAction.receiveSanitizedSnapshot,
      generation: 9,
      ownershipMatches: false,
    );

    expect(
        duplicate.status, CallV2DeveloperBackendDecisionStatus.duplicateNoOp);
    expect(duplicate.rejection,
        CallV2DeveloperBackendRejection.duplicateGeneration);
    expect(stale.status, CallV2DeveloperBackendDecisionStatus.staleIgnored);
    expect(stale.rejection, CallV2DeveloperBackendRejection.staleGeneration);
    expect(outOfOrder.status, CallV2DeveloperBackendDecisionStatus.rejected);
    expect(
        outOfOrder.rejection, CallV2DeveloperBackendRejection.outOfOrderState);
    expect(mismatch.status, CallV2DeveloperBackendDecisionStatus.rejected);
    expect(
        mismatch.rejection, CallV2DeveloperBackendRejection.ownershipMismatch);

    for (final decision in <CallV2DeveloperBackendDecision>[
      duplicate,
      stale,
      outOfOrder,
      mismatch,
    ]) {
      expect(decision.opensDocumentListener, isFalse);
      expect(decision.readsOrWritesDocuments, isFalse);
      expect(decision.callsIdentityOrCallable, isFalse);
      expect(decision.startsRuntime, isFalse);
      expect(decision.accessesNavigation, isFalse);
      expect(decision.mutatesV1State, isFalse);
    }
  });

  test('terminal sign-out invalid identity raw payload and failure are safe',
      () {
    final terminal = skeleton.decideWhileDisabled(
      action: CallV2DeveloperBackendAction.receiveSanitizedSnapshot,
      generation: 1,
      event: CallV2DeveloperSanitizedBackendEvent.sanitizedEnded,
    );
    final signOut = skeleton.decideWhileDisabled(
      action: CallV2DeveloperBackendAction.detachBackendOwner,
      generation: 2,
      signOutOrIdentityInvalid: true,
    );
    final rawPayload = skeleton.decideWhileDisabled(
      action: CallV2DeveloperBackendAction.receiveSanitizedSnapshot,
      generation: 3,
      rawPayloadProvided: true,
    );
    final failure = skeleton.decideWhileDisabled(
      action: CallV2DeveloperBackendAction.rejectSnapshot,
      generation: 4,
      controlledFailure: true,
    );

    expect(terminal.status, CallV2DeveloperBackendDecisionStatus.detached);
    expect(signOut.status, CallV2DeveloperBackendDecisionStatus.detached);
    expect(rawPayload.status, CallV2DeveloperBackendDecisionStatus.rejected);
    expect(rawPayload.rejection,
        CallV2DeveloperBackendRejection.rawPayloadRejected);
    expect(failure.status, CallV2DeveloperBackendDecisionStatus.rejected);
    expect(
        failure.rejection, CallV2DeveloperBackendRejection.controlledFailure);

    for (final decision in <CallV2DeveloperBackendDecision>[
      terminal,
      signOut,
      rawPayload,
      failure,
    ]) {
      expect(decision.attachesBackend, isFalse);
      expect(decision.opensDocumentListener, isFalse);
      expect(decision.readsOrWritesDocuments, isFalse);
      expect(decision.callsIdentityOrCallable, isFalse);
      expect(decision.storesRawSnapshot, isFalse);
      expect(decision.startsRuntime, isFalse);
      expect(decision.mutatesRouteRegistry, isFalse);
      expect(decision.mutatesV1State, isFalse);
      expect(decision.controlledFailureOnly, isTrue);
    }
  });

  test('safe debug output exposes counts booleans and no sensitive data', () {
    final debugText = '${skeleton.toSafeDebugMap()} $skeleton '
        '${skeleton.decideWhileDisabled(
      action: CallV2DeveloperBackendAction.requestBackendAttach,
      generation: 1,
      event: CallV2DeveloperSanitizedBackendEvent.sanitizedActive,
    )}';

    expect(skeleton.toSafeDebugMap()['actionCount'], 6);
    expect(skeleton.toSafeDebugMap()['sanitizedEventCount'], 8);
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
  });

  test('backend owner skeleton source has no service imports or async hooks',
      () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_developer_backend_firebase_owner_skeleton.dart',
    );

    for (final forbidden in <String>[
      "import 'package:",
      'package:flutter/',
      'cloud_firestore',
      'firebase_auth',
      'firebase_functions',
      'firebase_app_check',
      'Firebase',
      'Firestore',
      'Functions',
      'Auth',
      'FirebaseAppCheck',
      'AppLifecycleListener',
      'WidgetsBindingObserver',
      'Navigator.',
      'Navigator(',
      'GlobalKey',
      'BuildContext',
      'MaterialApp',
      'Permission.',
      'requestPermission',
      'RtcEngine',
      'Agora',
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

  test('real app config rules functions and startup remain isolated', () {
    const forbiddenReference =
        'call_v2_developer_backend_firebase_owner_skeleton';
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
    ]) {
      expect(
        _read(path),
        isNot(contains(forbiddenReference)),
        reason: path,
      );
    }
  });

  test('rollback controls preserve disabled owner and V1 protection', () {
    expect(
      skeleton.rollbackRequirements,
      <CallV2DeveloperBackendRollback>[
        CallV2DeveloperBackendRollback.oneCommitRevert,
        CallV2DeveloperBackendRollback.keepRolloutFalse,
        CallV2DeveloperBackendRollback.keepRouteRegistryNull,
        CallV2DeveloperBackendRollback.keepDisabledOwnerInert,
        CallV2DeveloperBackendRollback.noDeploymentRequired,
        CallV2DeveloperBackendRollback.noServerRulesConfigChanges,
        CallV2DeveloperBackendRollback.v1Unaffected,
      ],
    );
  });
}

String _read(String path) => File(path).readAsStringSync();
