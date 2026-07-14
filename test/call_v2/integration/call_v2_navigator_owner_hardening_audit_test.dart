import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_developer_navigator_owner_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_pre_wiring_safety_gate.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_skeleton_composition_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_lifecycle_observer_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_navigator_owner.dart';
import 'package:connect_app/call_v2/integration/call_v2_navigator_owner_hardening_audit.dart';
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
  final audit = callV2NavigatorOwnerHardeningAudit;
  final boundary = callV2NavigationOwnerBoundary;

  test('hardening audit artifact passes with disabled navigation boundary', () {
    expect(audit, isA<CallV2NavigatorOwnerHardeningAudit>());
    expect(audit.decision, CallV2NavigatorOwnerHardeningAuditDecision.pass);
    expect(audit.passes, isTrue);
    expect(audit.recordsDeveloperOnly, isTrue);
    expect(audit.recordsHardDisabled, isTrue);
    expect(audit.recordsRolloutFalse, isTrue);
    expect(audit.recordsUnreachable, isTrue);
    expect(audit.protectsV1, isTrue);
  });

  test('audit records every no navigation and no service status', () {
    expect(audit.wiresRealNavigator, isFalse);
    expect(audit.callsNavigator, isFalse);
    expect(audit.usesAppNavigatorKey, isFalse);
    expect(audit.usesGlobalKey, isFalse);
    expect(audit.storesBuildContext, isFalse);
    expect(audit.wiresMaterialApp, isFalse);
    expect(audit.createsRouteObject, isFalse);
    expect(audit.usesRouteSink, isFalse);
    expect(audit.createsScreen, isFalse);
    expect(audit.startsRuntime, isFalse);
    expect(audit.accessesBackendFirebase, isFalse);
    expect(audit.accessesRtcPermissions, isFalse);
    expect(audit.registersLifecycle, isFalse);
    expect(audit.mutatesRouteRegistry, isFalse);
    expect(audit.opensAsyncHandles, isFalse);
  });

  test('navigation actions are exactly the approved six actions', () {
    expect(
      CallV2NavigatorOwnerHardeningAudit.expectedActions,
      <CallV2NavigationOwnerAction>[
        CallV2NavigationOwnerAction.showConnecting,
        CallV2NavigationOwnerAction.showAudio,
        CallV2NavigationOwnerAction.showVideo,
        CallV2NavigationOwnerAction.showFailure,
        CallV2NavigationOwnerAction.dismissFailure,
        CallV2NavigationOwnerAction.returnToPrevious,
      ],
    );
    expect(
        boundary.actions, CallV2NavigatorOwnerHardeningAudit.expectedActions);
    expect(audit.actionsAreExact, isTrue);
  });

  test('disabled default decisions are inert for every action', () {
    expect(audit.defaultDecisionsAreInert, isTrue);

    for (final action in CallV2NavigationOwnerAction.values) {
      final decision = boundary.decideWhileDisabled(
        action: action,
        generation: CallV2NavigationOwnerAction.values.indexOf(action) + 1,
      );

      expect(
        decision.status,
        CallV2NavigationOwnerDecisionStatus.disabledInert,
        reason: action.name,
      );
      _expectNoDecisionSideEffects(decision);
    }
  });

  test('duplicate stale route mismatch and terminal decisions are safe', () {
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
      ownedRouteName: 'owned',
      currentRouteName: 'current',
    );
    final terminal = boundary.decideWhileDisabled(
      action: CallV2NavigationOwnerAction.dismissFailure,
      generation: 4,
      terminal: true,
    );

    expect(audit.duplicateDecisionIsNoOp, isTrue);
    expect(audit.staleDecisionIsIgnored, isTrue);
    expect(audit.routeMismatchDecisionIsIgnored, isTrue);
    expect(audit.terminalDecisionIsIgnored, isTrue);
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

  test('safe debug output contains no sensitive or route data', () {
    final debugText = '${audit.toSafeDebugMap()} $audit '
        '${boundary.toSafeDebugMap()} $boundary '
        '${boundary.decideWhileDisabled(
      action: CallV2NavigationOwnerAction.showConnecting,
      generation: 1,
    )}';

    expect(audit.toSafeDebugMap()['statusCount'], 30);
    expect(audit.toSafeDebugMap()['actionCount'], 6);
    expect(audit.recordsSafeDebugOnly, isTrue);

    for (final forbidden in _forbiddenDebugTerms) {
      expect(debugText, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('rollout route registry and disabled owner remain closed', () async {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(audit.recordsRouteRegistryNullWhileFalse, isTrue);
    expect(audit.recordsDisabledOwnerInert, isTrue);
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

  test('related hardening and approval audits remain closed or passing', () {
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
  });

  test('rollback model requires one commit and no deployment or config changes',
      () {
    expect(audit.rollbackPreserved, isTrue);
    expect(
      audit.rollback,
      <CallV2NavigatorOwnerHardeningRollback>[
        CallV2NavigatorOwnerHardeningRollback.oneCommitRevert,
        CallV2NavigatorOwnerHardeningRollback.keepRolloutFalse,
        CallV2NavigatorOwnerHardeningRollback.keepRouteRegistryNull,
        CallV2NavigatorOwnerHardeningRollback.keepDisabledOwnerInert,
        CallV2NavigatorOwnerHardeningRollback.noDeploymentRequired,
        CallV2NavigatorOwnerHardeningRollback.noConfigChanges,
        CallV2NavigatorOwnerHardeningRollback.v1Unaffected,
      ],
    );
  });

  test('navigator owner boundary source remains service and UI hook free', () {
    final source =
        _read('lib/call_v2/integration/call_v2_navigator_owner.dart');

    for (final forbidden in <String>[
      "import 'package:",
      ..._forbiddenBoundaryTerms,
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('hardening audit source has no forbidden imports or hooks', () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_navigator_owner_hardening_audit.dart',
    );

    for (final forbidden in <String>[
      "import 'package:flutter",
      "import 'dart:async",
      "import 'dart:io",
      'package:firebase',
      'cloud_firestore',
      'cloud_functions',
      'firebase_auth',
      'agora_rtc_engine',
      'permission_handler',
      'FirebaseFirestore',
      'FirebaseFunctions',
      'FirebaseAuth',
      'FirebaseAppCheck',
      'RtcEngine',
      'createAgoraRtcEngine',
      'joinChannel',
      'Permission.',
      '.request()',
      'AppLifecycleListener',
      'WidgetsBindingObserver',
      'Navigator.',
      'Navigator(',
      'GlobalKey(',
      'BuildContext context',
      'BuildContext? context',
      'MaterialApp(',
      'Timer(',
      'StreamController',
      'StreamSubscription',
      'listen(',
      'CallV2ProductionComposition',
      'ProductionCallV2StartupBridge',
      'CallV2Runtime(',
      'resolveCallV2Route(',
      'DisabledCallV2RouteRegistry(',
      'DisabledCallV2ProductionIntegrationOwner(',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('real app and config boundaries do not reference hardening audit', () {
    for (final path in _realAppAndConfigPaths) {
      final source = _read(path);
      expect(
        source,
        isNot(contains('call_v2_navigator_owner_hardening_audit')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2NavigatorOwnerHardeningAudit')),
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

String _read(String path) => File(path).readAsStringSync();

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

const _forbiddenBoundaryTerms = <String>[
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
];

const _realAppAndConfigPaths = <String>[
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
];

final class _ThrowingCompositionFactory
    implements CallV2ProductionIntegrationCompositionFactory {
  _ThrowingCompositionFactory({required this.onConstruct});

  final void Function() onConstruct;

  @override
  Object createProductionComposition() {
    onConstruct();
    throw StateError('composition must not be constructed while disabled');
  }
}
