import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_developer_lifecycle_observer_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_pre_wiring_safety_gate.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_route_registration_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_skeleton_composition_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_lifecycle_observer.dart';
import 'package:connect_app/call_v2/integration/call_v2_lifecycle_observer_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_integration_status.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final audit = callV2LifecycleObserverHardeningAudit;

  test('hardening audit artifact passes for disabled lifecycle boundary', () {
    expect(audit, isA<CallV2LifecycleObserverHardeningAudit>());
    expect(
      audit.decision,
      CallV2LifecycleObserverHardeningAuditDecision.pass,
    );
    expect(audit.passes, isTrue);
    expect(audit.recordsDeveloperOnly, isTrue);
    expect(audit.recordsHardDisabled, isTrue);
    expect(audit.recordsRolloutFalse, isTrue);
    expect(audit.recordsUnreachable, isTrue);
    expect(audit.recordsNoFrameworkLifecycleObserver, isTrue);
    expect(audit.recordsNoBindingLifecycleObserver, isTrue);
    expect(audit.recordsNoObserverRegistration, isTrue);
    expect(audit.recordsNoRuntimeStart, isTrue);
    expect(audit.recordsNoBackendFirebaseAccess, isTrue);
    expect(audit.recordsNoRtcPermissionAccess, isTrue);
    expect(audit.recordsNoNavigatorAccess, isTrue);
    expect(audit.recordsNoRouteRegistryMutation, isTrue);
    expect(audit.recordsNoAsyncHandles, isTrue);
    expect(audit.protectsV1, isTrue);
  });

  test('lifecycle events and decisions are exact and side-effect free', () {
    expect(
      audit.boundary.events,
      <CallV2LifecycleObserverEvent>[
        CallV2LifecycleObserverEvent.resumed,
        CallV2LifecycleObserverEvent.inactive,
        CallV2LifecycleObserverEvent.paused,
        CallV2LifecycleObserverEvent.hidden,
        CallV2LifecycleObserverEvent.detached,
      ],
    );
    expect(audit.lifecycleEventsAreExact, isTrue);
    expect(audit.defaultDecisionsAreInert, isTrue);
    expect(audit.duplicateDecisionIsNoOp, isTrue);
    expect(audit.staleDecisionIsIgnored, isTrue);
    expect(audit.terminalDecisionIsIgnored, isTrue);

    for (final event in CallV2LifecycleObserverEvent.values) {
      _expectNoDecisionSideEffects(
        audit.boundary.decideWhileDisabled(event: event, generation: 1),
      );
    }
    _expectNoDecisionSideEffects(
      audit.boundary.decideWhileDisabled(
        event: CallV2LifecycleObserverEvent.paused,
        generation: 2,
        latestGeneration: 2,
      ),
    );
    _expectNoDecisionSideEffects(
      audit.boundary.decideWhileDisabled(
        event: CallV2LifecycleObserverEvent.paused,
        generation: 1,
        latestGeneration: 2,
      ),
    );
    _expectNoDecisionSideEffects(
      audit.boundary.decideWhileDisabled(
        event: CallV2LifecycleObserverEvent.detached,
        generation: 3,
        terminal: true,
      ),
    );
  });

  test('safe debug output contains no sensitive data or route strings', () {
    final debugText = '${audit.toSafeDebugMap()} $audit '
        '${audit.boundary.toSafeDebugMap()} ${audit.boundary}';
    expect(audit.toSafeDebugMap()['statusCount'], 23);
    expect(audit.toSafeDebugMap()['rollbackCount'], 7);
    expect(audit.toSafeDebugMap()['eventCount'], 5);

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

  test('route rollout owner approval and prior audits remain closed', () async {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(
      resolveCallV2Route(const RouteSettings(name: '/call-v2/connecting')),
      isNull,
    );
    expect(
      const DisabledCallV2RouteRegistry().resolve(
        const RouteSettings(name: '/call-v2/connecting'),
      ),
      isNull,
    );
    expect(
      callV2RouteRegistryHardeningAudit.decision,
      CallV2RouteRegistryHardeningAuditDecision.pass,
    );
    expect(
      callV2DeveloperLifecycleObserverApprovalScope.isLifecycleObserverOnly,
      isTrue,
    );
    expect(
      callV2DeveloperRouteRegistrationApprovalScope.isRolloutEnabled,
      isFalse,
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
    expect(compositionConstructed, isFalse);
  });

  test('rollback model preserves one commit disabled lifecycle safety', () {
    expect(audit.rollbackPreserved, isTrue);
    expect(
      audit.rollback,
      <CallV2LifecycleObserverHardeningRollback>[
        CallV2LifecycleObserverHardeningRollback.oneCommitRevert,
        CallV2LifecycleObserverHardeningRollback.keepRolloutFalse,
        CallV2LifecycleObserverHardeningRollback.keepRouteRegistryNull,
        CallV2LifecycleObserverHardeningRollback.keepDisabledOwnerInert,
        CallV2LifecycleObserverHardeningRollback.noDeploymentRequired,
        CallV2LifecycleObserverHardeningRollback.noConfigChanges,
        CallV2LifecycleObserverHardeningRollback.v1Unaffected,
      ],
    );
  });

  test('boundary source has no forbidden imports hooks or async handles', () {
    final source = _read(
      'lib/call_v2/integration/call_v2_lifecycle_observer.dart',
    );

    for (final forbidden in _forbiddenSourceTerms) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('hardening audit source has no forbidden imports or hooks', () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_lifecycle_observer_hardening_audit.dart',
    );

    for (final forbidden in _forbiddenSourceTerms) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('real app and config boundaries do not reference hardening audit', () {
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
      final source = _read(path);
      expect(
        source,
        isNot(contains('call_v2_lifecycle_observer_hardening_audit')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2LifecycleObserverHardeningAudit')),
        reason: path,
      );
    }
  });
}

void _expectNoDecisionSideEffects(CallV2LifecycleObserverDecision decision) {
  expect(decision.registersObserver, isFalse);
  expect(decision.startsRuntime, isFalse);
  expect(decision.accessesBackendFirebase, isFalse);
  expect(decision.accessesRtcPermissions, isFalse);
  expect(decision.accessesNavigator, isFalse);
  expect(decision.mutatesRouteRegistry, isFalse);
  expect(decision.opensAsyncHandles, isFalse);
  expect(decision.mutatesV1State, isFalse);
}

String _read(String path) => File(path).readAsStringSync();

const _forbiddenSourceTerms = <String>[
  "import 'package:flutter",
  "import 'dart:async",
  "import 'dart:io",
  'package:firebase',
  'cloud_firestore',
  'cloud_functions',
  'firebase_auth',
  'FirebaseFirestore',
  'FirebaseFunctions',
  'FirebaseAuth',
  'FirebaseAppCheck',
  'agora_rtc_engine',
  'permission_handler',
  'Permission.',
  'RtcEngine',
  'createAgoraRtcEngine',
  'joinChannel',
  'CallV2ProductionComposition',
  'ProductionCallV2StartupBridge',
  'CallV2Runtime(',
  'Navigator.',
  'Navigator(',
  'BuildContext',
  'GlobalKey',
  'Timer(',
  'StreamController',
  'StreamSubscription',
  'listen(',
  'AppLifecycleListener',
  'WidgetsBindingObserver',
  'CallV2ProductionRouteObjectFactory(',
  'CallV2ProductionRouteSink',
  '.createRoute(',
  '.createScreen(',
  '.show(',
  'startPreview',
  'publishAudio',
  'publishVideo',
  'enumerateDevices',
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
