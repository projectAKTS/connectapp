import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_developer_navigator_owner_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_pre_wiring_safety_gate.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_skeleton_composition_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_lifecycle_observer_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_navigator_owner.dart';
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
  final boundary = callV2NavigationOwnerBoundary;

  test('navigation boundary artifact records disabled developer-only status',
      () {
    expect(boundary, isA<CallV2NavigationOwnerBoundary>());
    expect(boundary.isDeveloperOnly, isTrue);
    expect(boundary.isHardDisabled, isTrue);
    expect(boundary.isRolloutEnabled, isFalse);
    expect(boundary.isReachable, isFalse);
    expect(boundary.wiresRealNavigation, isFalse);
    expect(boundary.callsNavigation, isFalse);
    expect(boundary.usesAppNavigationKey, isFalse);
    expect(boundary.usesGlobalAppKey, isFalse);
    expect(boundary.storesWidgetContext, isFalse);
    expect(boundary.wiresMaterialRouteTable, isFalse);
    expect(boundary.createsRouteObject, isFalse);
    expect(boundary.usesRouteSink, isFalse);
    expect(boundary.createsScreen, isFalse);
    expect(boundary.startsRuntime, isFalse);
    expect(boundary.accessesBackendFirebase, isFalse);
    expect(boundary.accessesRtcPermissions, isFalse);
    expect(boundary.registersLifecycle, isFalse);
    expect(boundary.mutatesRouteRegistry, isFalse);
    expect(boundary.opensAsyncHandles, isFalse);
    expect(boundary.protectsV1, isTrue);
  });

  test('navigation action enum contains the approved future action set', () {
    expect(
      boundary.actions,
      <CallV2NavigationOwnerAction>[
        CallV2NavigationOwnerAction.showConnecting,
        CallV2NavigationOwnerAction.showAudio,
        CallV2NavigationOwnerAction.showVideo,
        CallV2NavigationOwnerAction.showFailure,
        CallV2NavigationOwnerAction.dismissFailure,
        CallV2NavigationOwnerAction.returnToPrevious,
      ],
    );
  });

  test('disabled decisions are inert for every action', () {
    for (final action in CallV2NavigationOwnerAction.values) {
      final decision = boundary.decideWhileDisabled(
        action: action,
        generation: boundary.actions.indexOf(action) + 1,
      );

      expect(
        decision.status,
        CallV2NavigationOwnerDecisionStatus.disabledInert,
        reason: action.name,
      );
      _expectNoDecisionSideEffects(decision);
    }
  });

  test('duplicate stale mismatch and terminal decisions are side-effect free',
      () {
    final duplicate = boundary.decideWhileDisabled(
      action: CallV2NavigationOwnerAction.showAudio,
      generation: 2,
      latestGeneration: 2,
    );
    final stale = boundary.decideWhileDisabled(
      action: CallV2NavigationOwnerAction.showAudio,
      generation: 1,
      latestGeneration: 2,
    );
    final mismatch = boundary.decideWhileDisabled(
      action: CallV2NavigationOwnerAction.returnToPrevious,
      generation: 3,
      ownedRouteName: '/call-v2/audio',
      currentRouteName: '/home',
    );
    final terminal = boundary.decideWhileDisabled(
      action: CallV2NavigationOwnerAction.dismissFailure,
      generation: 4,
      terminal: true,
    );

    expect(
      duplicate.status,
      CallV2NavigationOwnerDecisionStatus.duplicateNoOp,
    );
    expect(stale.status, CallV2NavigationOwnerDecisionStatus.staleIgnored);
    expect(
      mismatch.status,
      CallV2NavigationOwnerDecisionStatus.routeMismatchIgnored,
    );
    expect(
      terminal.status,
      CallV2NavigationOwnerDecisionStatus.terminalIgnored,
    );

    for (final decision in <CallV2NavigationOwnerDecision>[
      duplicate,
      stale,
      mismatch,
      terminal,
    ]) {
      _expectNoDecisionSideEffects(decision);
    }
  });

  test('safe debug output contains no sensitive data or route strings', () {
    final debugText = '${boundary.toSafeDebugMap()} $boundary '
        '${boundary.decideWhileDisabled(
      action: CallV2NavigationOwnerAction.showConnecting,
      generation: 1,
    )}';
    expect(boundary.toSafeDebugMap()['statusCount'], 20);
    expect(boundary.toSafeDebugMap()['actionCount'], 6);

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

  test('boundary source contains no real app service or UI hooks', () {
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
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('rollout routes owner and audits remain closed', () async {
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
      callV2LifecycleObserverHardeningAudit.decision,
      CallV2LifecycleObserverHardeningAuditDecision.pass,
    );
    expect(
      callV2RouteRegistryHardeningAudit.decision,
      CallV2RouteRegistryHardeningAuditDecision.pass,
    );
    expect(
      callV2DeveloperNavigationOwnerApprovalScope.isNavigationOwnerOnly,
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

  test('real app boundary files do not reference navigation boundary', () {
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
        isNot(contains('call_v2_navigator_owner')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2NavigationOwnerBoundary')),
        reason: path,
      );
    }
  });
}

void _expectNoDecisionSideEffects(CallV2NavigationOwnerDecision decision) {
  expect(decision.callsNavigation, isFalse);
  expect(decision.createsRouteObject, isFalse);
  expect(decision.createsScreen, isFalse);
  expect(decision.usesRouteSink, isFalse);
  expect(decision.startsRuntime, isFalse);
  expect(decision.accessesBackendFirebase, isFalse);
  expect(decision.accessesRtcPermissions, isFalse);
  expect(decision.registersLifecycle, isFalse);
  expect(decision.mutatesRouteRegistry, isFalse);
  expect(decision.opensAsyncHandles, isFalse);
  expect(decision.mutatesV1State, isFalse);
}

String _boundarySource() {
  return File(
    'lib/call_v2/integration/call_v2_navigator_owner.dart',
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
