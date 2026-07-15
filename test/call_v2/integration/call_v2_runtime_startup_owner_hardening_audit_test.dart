import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_developer_lifecycle_observer_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_navigator_owner_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_pre_wiring_safety_gate.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_route_registration_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_runtime_startup_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_runtime_startup_owner_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_skeleton_composition_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_lifecycle_observer_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_navigator_owner_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_integration_status.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_runtime_startup_owner.dart';
import 'package:connect_app/call_v2/integration/call_v2_runtime_startup_owner_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final audit = callV2RuntimeStartupOwnerHardeningAudit;
  final boundary = callV2RuntimeStartupOwnerBoundary;

  test('audit artifact exists and passes', () {
    expect(audit, isA<CallV2RuntimeStartupOwnerHardeningAudit>());
    expect(
      audit.decision,
      CallV2RuntimeStartupOwnerHardeningAuditDecision.pass,
    );
    expect(audit.passes, isTrue);
    expect(audit.statuses, hasLength(28));
    expect(audit.rollback, hasLength(7));
  });

  test('audit records disabled runtime startup boundary statuses', () {
    expect(audit.recordsDeveloperOnly, isTrue);
    expect(audit.recordsHardDisabled, isTrue);
    expect(audit.recordsRolloutFalse, isTrue);
    expect(audit.recordsUnreachable, isTrue);
    expect(audit.recordsNoRuntimeConstruction, isTrue);
    expect(audit.recordsNoRuntimeStart, isTrue);
    expect(audit.recordsNoProductionCompositionConstruction, isTrue);
    expect(audit.recordsNoStartupBridgeWiring, isTrue);
    expect(audit.recordsNoMainDartWiring, isTrue);
    expect(audit.recordsNoAppRouterWiring, isTrue);
    expect(audit.recordsNoBackendFirebaseAccess, isTrue);
    expect(audit.recordsNoRtcPermissionAccess, isTrue);
    expect(audit.recordsNoNavigatorAccess, isTrue);
    expect(audit.recordsNoLifecycleRegistration, isTrue);
    expect(audit.recordsNoRouteRegistryMutation, isTrue);
    expect(audit.recordsNoAsyncHandles, isTrue);
    expect(audit.recordsNoDeployment, isTrue);
    expect(audit.protectsV1, isTrue);
  });

  test('runtime actions are exact and default decisions are inert', () {
    expect(
      CallV2RuntimeStartupOwnerHardeningAudit.expectedActions,
      <CallV2RuntimeStartupOwnerAction>[
        CallV2RuntimeStartupOwnerAction.requestStartup,
        CallV2RuntimeStartupOwnerAction.requestShutdown,
        CallV2RuntimeStartupOwnerAction.markReady,
        CallV2RuntimeStartupOwnerAction.markFailure,
        CallV2RuntimeStartupOwnerAction.retryStartup,
      ],
    );
    expect(audit.actionsAreExact, isTrue);
    expect(audit.defaultDecisionsAreInert, isTrue);

    for (final action in boundary.actions) {
      final decision = boundary.decideWhileDisabled(
        action: action,
        generation: boundary.actions.indexOf(action) + 1,
      );
      expect(
        decision.status,
        CallV2RuntimeStartupOwnerDecisionStatus.disabledInert,
        reason: action.name,
      );
      _expectNoDecisionSideEffects(decision);
    }
  });

  test('duplicate stale disposed and terminal decisions are safe', () {
    expect(audit.duplicateDecisionIsNoOp, isTrue);
    expect(audit.staleDecisionIsIgnored, isTrue);
    expect(audit.disposedDecisionIsRejected, isTrue);
    expect(audit.terminalDecisionIsIgnored, isTrue);

    for (final decision in <CallV2RuntimeStartupOwnerDecision>[
      boundary.decideWhileDisabled(
        action: CallV2RuntimeStartupOwnerAction.requestStartup,
        generation: 2,
        latestGeneration: 2,
      ),
      boundary.decideWhileDisabled(
        action: CallV2RuntimeStartupOwnerAction.requestStartup,
        generation: 1,
        latestGeneration: 2,
      ),
      boundary.decideWhileDisabled(
        action: CallV2RuntimeStartupOwnerAction.requestShutdown,
        generation: 3,
        disposed: true,
      ),
      boundary.decideWhileDisabled(
        action: CallV2RuntimeStartupOwnerAction.markReady,
        generation: 4,
        terminal: true,
      ),
    ]) {
      _expectNoDecisionSideEffects(decision);
    }
  });

  test('safe debug output contains no sensitive data or route strings', () {
    final debugText = '${audit.toSafeDebugMap()} $audit '
        '${boundary.toSafeDebugMap()} $boundary';

    expect(audit.toSafeDebugMap()['decision'], 'pass');
    expect(audit.toSafeDebugMap()['statusCount'], 28);
    expect(audit.toSafeDebugMap()['actionCount'], 5);
    expect(audit.toSafeDebugMap()['rollbackCount'], 7);

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

  test('route registry disabled owner and related audits remain closed',
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
    expect(audit.recordsRouteRegistryNullWhileFalse, isTrue);
    expect(audit.recordsDisabledOwnerInert, isTrue);
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
      callV2DeveloperRuntimeStartupApprovalScope.evaluatedGate.decision,
      CallV2DeveloperPreWiringGateDecision
          .allowedForExplicitFutureDeveloperOnlyPhase,
    );
    expect(
      callV2DeveloperPreWiringSafetyGate.decision,
      CallV2DeveloperPreWiringGateDecision.blockedNoScopeSelected,
    );
    expect(
      callV2DeveloperSkeletonCompositionAudit.decision,
      CallV2DeveloperSkeletonCompositionDecision.pass,
    );
    expect(
      callV2DeveloperNavigationOwnerApprovalScope.isRolloutEnabled,
      isFalse,
    );
    expect(
      callV2DeveloperLifecycleObserverApprovalScope.isRolloutEnabled,
      isFalse,
    );
    expect(
      callV2DeveloperRouteRegistrationApprovalScope.isRolloutEnabled,
      isFalse,
    );
    expect(callV2DeveloperRuntimeStartupOwnerSkeleton.startsRuntime, isFalse);

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

  test('runtime startup boundary source remains isolated', () {
    final source = _boundarySource();

    for (final forbidden in <String>[
      "import 'package:",
      'package:flutter/',
      'package:firebase',
      'cloud_firestore',
      'cloud_functions',
      'firebase_auth',
      'agora_rtc_engine',
      'permission_handler',
      'package:camera',
      'package:microphone',
      'dart:async',
      'dart:io',
      'dart:ui',
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
      'FirebaseFirestore',
      'FirebaseFunctions',
      'FirebaseAuth',
      'FirebaseAppCheck',
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

  test('hardening audit source has no forbidden imports or executable hooks',
      () {
    final source = _auditSource();

    for (final forbidden in <String>[
      "import 'package:",
      'package:flutter/',
      'package:firebase',
      'cloud_firestore',
      'cloud_functions',
      'firebase_auth',
      'agora_rtc_engine',
      'permission_handler',
      'package:camera',
      'package:microphone',
      'dart:async',
      'dart:io',
      'dart:ui',
      'MethodChannel',
      'EventChannel',
      'Timer(',
      'StreamController',
      'StreamSubscription',
      'listen(',
      'AppLifecycleListener',
      'WidgetsBindingObserver',
      'GlobalKey',
      'BuildContext',
      'MaterialApp',
      'ProductionCallV2StartupBridge',
      'FirebaseFirestore',
      'FirebaseFunctions',
      'FirebaseAuth',
      'FirebaseAppCheck',
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

  test('real app and config files do not reference hardening audit', () {
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
        isNot(contains('call_v2_runtime_startup_owner_hardening_audit')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2RuntimeStartupOwnerHardeningAudit')),
        reason: path,
      );
    }
  });

  test('rollback model preserves one commit disabled V1-safe boundary', () {
    expect(audit.rollbackPreserved, isTrue);
    expect(
      audit.rollback,
      <CallV2RuntimeStartupOwnerHardeningRollback>[
        CallV2RuntimeStartupOwnerHardeningRollback.oneCommitRevert,
        CallV2RuntimeStartupOwnerHardeningRollback.keepRolloutFalse,
        CallV2RuntimeStartupOwnerHardeningRollback.keepRouteRegistryNull,
        CallV2RuntimeStartupOwnerHardeningRollback.keepDisabledOwnerInert,
        CallV2RuntimeStartupOwnerHardeningRollback.noDeploymentRequired,
        CallV2RuntimeStartupOwnerHardeningRollback.noConfigChanges,
        CallV2RuntimeStartupOwnerHardeningRollback.v1Unaffected,
      ],
    );
  });
}

void _expectNoDecisionSideEffects(
  CallV2RuntimeStartupOwnerDecision decision,
) {
  expect(decision.constructsRuntime, isFalse);
  expect(decision.startsRuntime, isFalse);
  expect(decision.constructsProductionComposition, isFalse);
  expect(decision.wiresStartupBridge, isFalse);
  expect(decision.accessesBackend, isFalse);
  expect(decision.accessesMediaCapabilities, isFalse);
  expect(decision.accessesNavigation, isFalse);
  expect(decision.registersLifecycle, isFalse);
  expect(decision.mutatesRouteRegistry, isFalse);
  expect(decision.opensAsyncHandles, isFalse);
  expect(decision.mutatesV1State, isFalse);
  expect(decision.exposesPublicUsers, isFalse);
  expect(decision.contactsProductionServices, isFalse);
}

String _boundarySource() {
  return File(
    'lib/call_v2/integration/call_v2_runtime_startup_owner.dart',
  ).readAsStringSync();
}

String _auditSource() {
  return File(
    'lib/call_v2/integration/'
    'call_v2_runtime_startup_owner_hardening_audit.dart',
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
