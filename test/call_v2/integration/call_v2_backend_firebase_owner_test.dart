import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_backend_firebase_owner.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_backend_firebase_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_pre_wiring_safety_gate.dart';
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
  final boundary = callV2BackendFirebaseOwnerBoundary;

  test('backend Firebase boundary artifact records disabled statuses', () {
    expect(boundary, isA<CallV2BackendFirebaseOwnerBoundary>());
    expect(boundary.isDeveloperOnly, isTrue);
    expect(boundary.isHardDisabled, isTrue);
    expect(boundary.isRolloutEnabled, isFalse);
    expect(boundary.isReachable, isFalse);
    expect(boundary.importsFirebase, isFalse);
    expect(boundary.opensFirestoreListeners, isFalse);
    expect(boundary.readsFirestore, isFalse);
    expect(boundary.writesFirestore, isFalse);
    expect(boundary.callsFirebaseAuth, isFalse);
    expect(boundary.callsFirebaseFunctions, isFalse);
    expect(boundary.callsFirebaseAppCheck, isFalse);
    expect(boundary.contactsProductionServices, isFalse);
    expect(boundary.constructsRuntime, isFalse);
    expect(boundary.startsRuntime, isFalse);
    expect(boundary.accessesNavigation, isFalse);
    expect(boundary.accessesRtcPermissions, isFalse);
    expect(boundary.registersLifecycle, isFalse);
    expect(boundary.mutatesRouteRegistry, isFalse);
    expect(boundary.opensAsyncHandles, isFalse);
    expect(boundary.changesRulesFunctionsConfig, isFalse);
    expect(boundary.isDeploymentApproved, isFalse);
    expect(boundary.protectsV1, isTrue);
    expect(boundary.statuses, hasLength(22));
  });

  test('backend action and event enums contain the approved values only', () {
    expect(
      boundary.actions,
      <CallV2BackendFirebaseOwnerAction>[
        CallV2BackendFirebaseOwnerAction.attachBackend,
        CallV2BackendFirebaseOwnerAction.detachBackend,
        CallV2BackendFirebaseOwnerAction.receiveSnapshot,
        CallV2BackendFirebaseOwnerAction.sendMutation,
        CallV2BackendFirebaseOwnerAction.callFunction,
        CallV2BackendFirebaseOwnerAction.refreshAuth,
        CallV2BackendFirebaseOwnerAction.verifyAppCheck,
      ],
    );
    expect(
      boundary.events,
      <CallV2BackendFirebaseOwnerEvent>[
        CallV2BackendFirebaseOwnerEvent.sanitizedRinging,
        CallV2BackendFirebaseOwnerEvent.sanitizedActive,
        CallV2BackendFirebaseOwnerEvent.sanitizedEnded,
        CallV2BackendFirebaseOwnerEvent.sanitizedFailure,
        CallV2BackendFirebaseOwnerEvent.sanitizedUnknown,
      ],
    );
  });

  test('every backend action is disabled inert by default', () {
    for (final action in boundary.actions) {
      final decision = boundary.decideWhileDisabled(
        action: action,
        generation: boundary.actions.indexOf(action) + 1,
      );

      expect(
        decision.status,
        CallV2BackendFirebaseOwnerDecisionStatus.disabledInert,
        reason: action.name,
      );
      _expectNoDecisionSideEffects(decision);
    }
  });

  test('duplicate stale transition ownership raw and terminal decisions match',
      () {
    final duplicate = boundary.decideWhileDisabled(
      action: CallV2BackendFirebaseOwnerAction.receiveSnapshot,
      generation: 3,
      latestGeneration: 3,
    );
    final stale = boundary.decideWhileDisabled(
      action: CallV2BackendFirebaseOwnerAction.receiveSnapshot,
      generation: 2,
      latestGeneration: 3,
    );
    final backwards = boundary.decideWhileDisabled(
      action: CallV2BackendFirebaseOwnerAction.receiveSnapshot,
      generation: 4,
      event: CallV2BackendFirebaseOwnerEvent.sanitizedRinging,
      previousEvent: CallV2BackendFirebaseOwnerEvent.sanitizedActive,
    );
    final ownership = boundary.decideWhileDisabled(
      action: CallV2BackendFirebaseOwnerAction.receiveSnapshot,
      generation: 5,
      ownershipMatches: false,
    );
    final raw = boundary.decideWhileDisabled(
      action: CallV2BackendFirebaseOwnerAction.receiveSnapshot,
      generation: 6,
      rawPayloadProvided: true,
    );
    final terminal = boundary.decideWhileDisabled(
      action: CallV2BackendFirebaseOwnerAction.receiveSnapshot,
      generation: 7,
      event: CallV2BackendFirebaseOwnerEvent.sanitizedEnded,
    );

    expect(
      duplicate.status,
      CallV2BackendFirebaseOwnerDecisionStatus.duplicateNoOp,
    );
    expect(
      stale.status,
      CallV2BackendFirebaseOwnerDecisionStatus.staleIgnored,
    );
    expect(
      backwards.status,
      CallV2BackendFirebaseOwnerDecisionStatus.transitionRejected,
    );
    expect(
      ownership.status,
      CallV2BackendFirebaseOwnerDecisionStatus.ownershipRejected,
    );
    expect(
      raw.status,
      CallV2BackendFirebaseOwnerDecisionStatus.rawPayloadRejected,
    );
    expect(
      terminal.status,
      CallV2BackendFirebaseOwnerDecisionStatus.terminalIgnored,
    );

    for (final decision in <CallV2BackendFirebaseOwnerDecision>[
      duplicate,
      stale,
      backwards,
      ownership,
      raw,
      terminal,
    ]) {
      _expectNoDecisionSideEffects(decision);
    }
  });

  test('safe debug output contains no sensitive data or route strings', () {
    final decision = boundary.decideWhileDisabled(
      action: CallV2BackendFirebaseOwnerAction.attachBackend,
      generation: 1,
      event: CallV2BackendFirebaseOwnerEvent.sanitizedActive,
    );
    final debugText = '${boundary.toSafeDebugMap()} $boundary '
        '${decision.toSafeDebugMap()} $decision';

    expect(boundary.toSafeDebugMap()['statusCount'], 22);
    expect(boundary.toSafeDebugMap()['actionCount'], 7);
    expect(boundary.toSafeDebugMap()['eventCount'], 5);

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

  test('source contains no imports service calls or executable hooks', () {
    final source = _boundarySource();

    for (final forbidden in <String>[
      'import ',
      "import 'package:",
      'package:flutter/',
      'package:firebase',
      'cloud_firestore',
      'cloud_functions',
      'firebase_auth',
      'firebase_app_check',
      'agora_rtc_engine',
      'permission_handler',
      'package:camera',
      'package:microphone',
      'dart:async',
      'dart:io',
      'MethodChannel',
      'EventChannel',
      'Timer(',
      'StreamController',
      'StreamSubscription',
      'listen(',
      'AppLifecycleListener',
      'WidgetsBindingObserver',
      'Navigator',
      'GlobalKey',
      'BuildContext',
      'MaterialApp',
      'ProductionCallV2StartupBridge',
      'FirebaseFirestore.instance',
      'FirebaseFunctions.instance',
      'FirebaseAuth.instance',
      'FirebaseAppCheck.instance',
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
      'RtcEngine',
      'createAgoraRtcEngine',
      'joinChannel',
      'Permission.',
      '.request()',
      'enumerateDevices',
      'startPreview',
      'publishAudio',
      'publishVideo',
      'CallV2Runtime(',
      'startRuntime(',
      '.start()',
      'createProductionComposition(',
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
        const RouteSettings(name: '/call-v2/audio'),
      ),
      isNull,
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
      callV2DeveloperPreWiringSafetyGate.decision,
      CallV2DeveloperPreWiringGateDecision.blockedNoScopeSelected,
    );
    expect(
      callV2DeveloperSkeletonCompositionAudit.decision,
      CallV2DeveloperSkeletonCompositionDecision.pass,
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
  });

  test('real app and config files do not reference backend Firebase boundary',
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
      'firebase.json',
      'firestore.rules',
      'connect_functions/index.js',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains('call_v2_backend_firebase_owner')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2BackendFirebaseOwnerBoundary')),
        reason: path,
      );
    }
  });

  test('rollback controls preserve disabled owner and V1 protection', () {
    expect(boundary.rollbackPreserved, isTrue);
    expect(
      boundary.rollback,
      <CallV2BackendFirebaseOwnerRollback>[
        CallV2BackendFirebaseOwnerRollback.oneCommitRevert,
        CallV2BackendFirebaseOwnerRollback.keepRolloutFalse,
        CallV2BackendFirebaseOwnerRollback.keepRouteRegistryNull,
        CallV2BackendFirebaseOwnerRollback.keepDisabledOwnerInert,
        CallV2BackendFirebaseOwnerRollback.noDeploymentRequired,
        CallV2BackendFirebaseOwnerRollback.noConfigChanges,
        CallV2BackendFirebaseOwnerRollback.v1Unaffected,
      ],
    );
  });
}

void _expectNoDecisionSideEffects(CallV2BackendFirebaseOwnerDecision decision) {
  expect(decision.importsFirebase, isFalse);
  expect(decision.opensFirestoreListener, isFalse);
  expect(decision.readsFirestore, isFalse);
  expect(decision.writesFirestore, isFalse);
  expect(decision.callsAuth, isFalse);
  expect(decision.callsFunctions, isFalse);
  expect(decision.callsAppCheck, isFalse);
  expect(decision.contactsProductionServices, isFalse);
  expect(decision.constructsRuntime, isFalse);
  expect(decision.startsRuntime, isFalse);
  expect(decision.accessesNavigation, isFalse);
  expect(decision.accessesRtcPermissions, isFalse);
  expect(decision.registersLifecycle, isFalse);
  expect(decision.mutatesRouteRegistry, isFalse);
  expect(decision.opensAsyncHandles, isFalse);
  expect(decision.changesRulesFunctionsConfig, isFalse);
  expect(decision.mutatesV1State, isFalse);
}

String _boundarySource() {
  return File(
    'lib/call_v2/integration/call_v2_backend_firebase_owner.dart',
  ).readAsStringSync();
}

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
