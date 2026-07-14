import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_developer_lifecycle_observer_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_pre_wiring_safety_gate.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_route_registration_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_skeleton_composition_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_lifecycle_observer.dart';
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
  final boundary = callV2LifecycleObserverBoundary;

  test('lifecycle boundary artifact records disabled developer-only status',
      () {
    expect(boundary, isA<CallV2LifecycleObserverBoundary>());
    expect(boundary.isDeveloperOnly, isTrue);
    expect(boundary.isHardDisabled, isTrue);
    expect(boundary.isRolloutEnabled, isFalse);
    expect(boundary.isReachable, isFalse);
    expect(boundary.registersFrameworkLifecycleObserver, isFalse);
    expect(boundary.registersBindingLifecycleObserver, isFalse);
    expect(boundary.registersObserver, isFalse);
    expect(boundary.startsRuntime, isFalse);
    expect(boundary.accessesBackendFirebase, isFalse);
    expect(boundary.accessesRtcPermissions, isFalse);
    expect(boundary.accessesNavigator, isFalse);
    expect(boundary.mutatesRouteRegistry, isFalse);
    expect(boundary.opensAsyncHandles, isFalse);
    expect(boundary.protectsV1, isTrue);
  });

  test('lifecycle event enum is scoped to app lifecycle shape only', () {
    expect(
      boundary.events,
      <CallV2LifecycleObserverEvent>[
        CallV2LifecycleObserverEvent.resumed,
        CallV2LifecycleObserverEvent.inactive,
        CallV2LifecycleObserverEvent.paused,
        CallV2LifecycleObserverEvent.hidden,
        CallV2LifecycleObserverEvent.detached,
      ],
    );
  });

  test('disabled decisions are inert for every event', () {
    for (final event in CallV2LifecycleObserverEvent.values) {
      final decision = boundary.decideWhileDisabled(
        event: event,
        generation: 1,
      );
      expect(
        decision.status,
        CallV2LifecycleObserverDecisionStatus.disabledInert,
        reason: event.name,
      );
      _expectNoDecisionSideEffects(decision);
    }
  });

  test('duplicate stale and terminal decisions remain side-effect free', () {
    final duplicate = boundary.decideWhileDisabled(
      event: CallV2LifecycleObserverEvent.paused,
      generation: 2,
      latestGeneration: 2,
    );
    final stale = boundary.decideWhileDisabled(
      event: CallV2LifecycleObserverEvent.paused,
      generation: 1,
      latestGeneration: 2,
    );
    final terminal = boundary.decideWhileDisabled(
      event: CallV2LifecycleObserverEvent.detached,
      generation: 3,
      latestGeneration: 3,
      terminal: true,
    );

    expect(
      duplicate.status,
      CallV2LifecycleObserverDecisionStatus.duplicateNoOp,
    );
    expect(stale.status, CallV2LifecycleObserverDecisionStatus.staleIgnored);
    expect(
      terminal.status,
      CallV2LifecycleObserverDecisionStatus.terminalIgnored,
    );
    _expectNoDecisionSideEffects(duplicate);
    _expectNoDecisionSideEffects(stale);
    _expectNoDecisionSideEffects(terminal);
  });

  test('safe debug output contains no sensitive data or route strings', () {
    final debugText = '${boundary.toSafeDebugMap()} $boundary '
        '${boundary.decideWhileDisabled(
      event: CallV2LifecycleObserverEvent.resumed,
      generation: 1,
    )}';
    expect(boundary.toSafeDebugMap()['statusCount'], 14);
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

  test('boundary source contains no framework lifecycle or service hooks', () {
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
      'dart:async',
      'dart:io',
      'Timer(',
      'StreamController',
      'StreamSubscription',
      'listen(',
      'AppLifecycleListener',
      'WidgetsBindingObserver',
      'Navigator.',
      'Navigator(',
      'GlobalKey',
      'BuildContext',
      'MaterialApp',
      'ProductionCallV2StartupBridge',
      'FirebaseFirestore',
      'FirebaseFunctions',
      'FirebaseAuth',
      'FirebaseAppCheck',
      'RtcEngine(',
      'createAgoraRtcEngine',
      'joinChannel',
      'Permission.',
      '.request()',
      'enumerateDevices',
      'startPreview',
      'publishAudio',
      'publishVideo',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('rollout routes owner and audits remain closed', () async {
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

  test('real app boundary files do not reference lifecycle boundary', () {
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
        isNot(contains('call_v2_lifecycle_observer')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2LifecycleObserverBoundary')),
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

String _boundarySource() {
  return File(
    'lib/call_v2/integration/call_v2_lifecycle_observer.dart',
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
