import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_backend_firebase_owner.dart';
import 'package:connect_app/call_v2/integration/call_v2_backend_firebase_owner_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_backend_firebase_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_lifecycle_observer_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_navigator_owner_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_pre_wiring_safety_gate.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_route_registration_approval_scope.dart';
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
  final audit = callV2BackendFirebaseOwnerHardeningAudit;
  final boundary = callV2BackendFirebaseOwnerBoundary;

  test('hardening audit artifact exists and passes', () {
    expect(audit, isA<CallV2BackendFirebaseOwnerHardeningAudit>());
    expect(
      audit.decision,
      CallV2BackendFirebaseOwnerHardeningAuditDecision.pass,
    );
    expect(audit.passes, isTrue);
  });

  test('audit records every backend Firebase owner status as closed', () {
    expect(audit.recordsDeveloperOnly, isTrue);
    expect(audit.recordsHardDisabled, isTrue);
    expect(audit.recordsRolloutFalse, isTrue);
    expect(audit.recordsUnreachable, isTrue);
    expect(audit.recordsNoFirebaseImports, isTrue);
    expect(audit.recordsNoFirestoreListeners, isTrue);
    expect(audit.recordsNoFirestoreReads, isTrue);
    expect(audit.recordsNoFirestoreWrites, isTrue);
    expect(audit.recordsNoFirebaseAuthCalls, isTrue);
    expect(audit.recordsNoFirebaseFunctionsCalls, isTrue);
    expect(audit.recordsNoFirebaseAppCheckCalls, isTrue);
    expect(audit.recordsNoProductionServiceContact, isTrue);
    expect(audit.recordsNoRuntimeConstruction, isTrue);
    expect(audit.recordsNoRuntimeStart, isTrue);
    expect(audit.recordsNoNavigationAccess, isTrue);
    expect(audit.recordsNoRtcPermissionAccess, isTrue);
    expect(audit.recordsNoLifecycleRegistration, isTrue);
    expect(audit.recordsNoRouteRegistryMutation, isTrue);
    expect(audit.recordsNoAsyncHandles, isTrue);
    expect(audit.recordsNoRulesFunctionsConfigChanges, isTrue);
    expect(audit.recordsNoDeployment, isTrue);
    expect(audit.protectsV1, isTrue);
    expect(audit.statuses, hasLength(35));
  });

  test('backend actions and sanitized backend events remain exact', () {
    expect(audit.backendActionsExact, isTrue);
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

    expect(audit.sanitizedEventsExact, isTrue);
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

  test('default and exceptional backend decisions remain side-effect-free', () {
    expect(audit.defaultDecisionsInert, isTrue);
    expect(audit.duplicateDecisionNoOp, isTrue);
    expect(audit.staleDecisionIgnored, isTrue);
    expect(audit.backwardsTransitionRejected, isTrue);
    expect(audit.ownershipMismatchRejected, isTrue);
    expect(audit.rawPayloadRejected, isTrue);
    expect(audit.terminalDecisionIgnored, isTrue);

    final decisions = <CallV2BackendFirebaseOwnerDecision>[
      for (final action in boundary.actions)
        boundary.decideWhileDisabled(
          action: action,
          generation: boundary.actions.indexOf(action) + 1,
        ),
      boundary.decideWhileDisabled(
        action: CallV2BackendFirebaseOwnerAction.receiveSnapshot,
        generation: 4,
        latestGeneration: 4,
      ),
      boundary.decideWhileDisabled(
        action: CallV2BackendFirebaseOwnerAction.receiveSnapshot,
        generation: 3,
        latestGeneration: 4,
      ),
      boundary.decideWhileDisabled(
        action: CallV2BackendFirebaseOwnerAction.receiveSnapshot,
        generation: 5,
        event: CallV2BackendFirebaseOwnerEvent.sanitizedRinging,
        previousEvent: CallV2BackendFirebaseOwnerEvent.sanitizedActive,
      ),
      boundary.decideWhileDisabled(
        action: CallV2BackendFirebaseOwnerAction.receiveSnapshot,
        generation: 6,
        ownershipMatches: false,
      ),
      boundary.decideWhileDisabled(
        action: CallV2BackendFirebaseOwnerAction.receiveSnapshot,
        generation: 7,
        rawPayloadProvided: true,
      ),
      boundary.decideWhileDisabled(
        action: CallV2BackendFirebaseOwnerAction.receiveSnapshot,
        generation: 8,
        event: CallV2BackendFirebaseOwnerEvent.sanitizedEnded,
      ),
    ];

    for (final decision in decisions) {
      _expectNoDecisionSideEffects(decision);
    }
  });

  test('safe debug output contains no sensitive material', () {
    final decision = boundary.decideWhileDisabled(
      action: CallV2BackendFirebaseOwnerAction.receiveSnapshot,
      generation: 1,
      event: CallV2BackendFirebaseOwnerEvent.sanitizedActive,
    );
    final debugText = '${audit.toSafeDebugMap()} $audit '
        '${boundary.toSafeDebugMap()} $boundary '
        '${decision.toSafeDebugMap()} $decision';

    expect(audit.recordsSafeDebugOnly, isTrue);
    for (final forbidden in _forbiddenDebugTerms) {
      expect(debugText, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('rollout route resolver and disabled route registry remain closed', () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(audit.recordsRouteRegistryNullWhileFalse, isTrue);
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
  });

  test('disabled owner remains inert and does not construct composition',
      () async {
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

  test('existing hardening audits and approval scopes remain closed', () {
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
    expect(callV2DeveloperRuntimeStartupApprovalScope.startsRuntime, isFalse);
    expect(
      callV2DeveloperRuntimeStartupApprovalScope.accessesBackendFirebase,
      isFalse,
    );
    expect(
      callV2DeveloperRuntimeStartupApprovalScope.rollbackPreserved,
      isTrue,
    );
    expect(callV2DeveloperNavigationOwnerApprovalScope.startsRuntime, isFalse);
    expect(
      callV2DeveloperNavigationOwnerApprovalScope.accessesBackendFirebase,
      isFalse,
    );
    expect(
      callV2DeveloperNavigationOwnerApprovalScope.wiresRealNavigation,
      isFalse,
    );
    expect(
      callV2DeveloperNavigationOwnerApprovalScope.rollbackPreserved,
      isTrue,
    );
    expect(
      callV2DeveloperLifecycleObserverApprovalScope.startsRuntime,
      isFalse,
    );
    expect(
      callV2DeveloperLifecycleObserverApprovalScope.accessesBackendFirebase,
      isFalse,
    );
    expect(
      callV2DeveloperLifecycleObserverApprovalScope
          .registersFrameworkLifecycleHook,
      isFalse,
    );
    expect(
      callV2DeveloperLifecycleObserverApprovalScope.rollbackPreserved,
      isTrue,
    );
    expect(
      callV2DeveloperRouteRegistrationApprovalScope.startsRuntime,
      isFalse,
    );
    expect(
      callV2DeveloperRouteRegistrationApprovalScope.accessesBackendFirebase,
      isFalse,
    );
    expect(
      callV2DeveloperRouteRegistrationApprovalScope.resolverStillNullWhileFalse,
      isTrue,
    );
    expect(
      callV2DeveloperRouteRegistrationApprovalScope.rollbackPreserved,
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

  test('backend Firebase boundary source has no imports or executable hooks',
      () {
    final source = _read(
      'lib/call_v2/integration/call_v2_backend_firebase_owner.dart',
    );

    expect(source, isNot(contains('import ')));
    for (final forbidden in <String>[
      ..._forbiddenServiceTerms,
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

  test('backend Firebase hardening audit source has no forbidden hooks', () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_backend_firebase_owner_hardening_audit.dart',
    );

    for (final forbidden in <String>[
      "import 'package:flutter",
      "import 'dart:async",
      "import 'dart:io",
      'package:firebase',
      ..._forbiddenServiceTerms,
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
        isNot(contains('call_v2_backend_firebase_owner_hardening_audit')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2BackendFirebaseOwnerHardeningAudit')),
        reason: path,
      );
    }
  });

  test('rollback controls preserve one-commit no-deploy recovery and V1 safety',
      () {
    expect(audit.rollbackPreserved, isTrue);
    expect(
      audit.rollback,
      <CallV2BackendFirebaseOwnerHardeningRollback>[
        CallV2BackendFirebaseOwnerHardeningRollback.oneCommitRevert,
        CallV2BackendFirebaseOwnerHardeningRollback.keepRolloutFalse,
        CallV2BackendFirebaseOwnerHardeningRollback.keepRouteRegistryNull,
        CallV2BackendFirebaseOwnerHardeningRollback.keepDisabledOwnerInert,
        CallV2BackendFirebaseOwnerHardeningRollback.noDeploymentRequired,
        CallV2BackendFirebaseOwnerHardeningRollback.noConfigChanges,
        CallV2BackendFirebaseOwnerHardeningRollback.v1Unaffected,
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
  'package:firebase',
  'cloud_firestore',
  'cloud_functions',
  'firebase_auth',
  'firebase_app_check',
  'agora_rtc_engine',
  'permission_handler',
  'Permission.',
  'RtcEngine',
  'createAgoraRtcEngine',
  'joinChannel',
  'Firebase.initializeApp',
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
