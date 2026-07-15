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
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final boundary = callV2RuntimeStartupOwnerBoundary;

  test('runtime startup boundary artifact exists and is disabled', () {
    expect(boundary, isA<CallV2RuntimeStartupOwnerBoundary>());
    expect(boundary.isDeveloperOnly, isTrue);
    expect(boundary.isHardDisabled, isTrue);
    expect(boundary.isRolloutEnabled, isFalse);
    expect(boundary.isReachable, isFalse);
    expect(boundary.constructsRuntime, isFalse);
    expect(boundary.startsRuntime, isFalse);
    expect(boundary.constructsProductionComposition, isFalse);
    expect(boundary.wiresStartupBridge, isFalse);
    expect(boundary.wiresMainDart, isFalse);
    expect(boundary.wiresAppRouter, isFalse);
    expect(boundary.accessesBackend, isFalse);
    expect(boundary.accessesMediaCapabilities, isFalse);
    expect(boundary.accessesNavigation, isFalse);
    expect(boundary.registersLifecycle, isFalse);
    expect(boundary.mutatesRouteRegistry, isFalse);
    expect(boundary.opensAsyncHandles, isFalse);
    expect(boundary.isDeploymentApproved, isFalse);
    expect(boundary.protectsV1, isTrue);
    expect(boundary.statuses, hasLength(18));
  });

  test('runtime actions are exact and default decisions are inert', () {
    expect(
      boundary.actions,
      <CallV2RuntimeStartupOwnerAction>[
        CallV2RuntimeStartupOwnerAction.requestStartup,
        CallV2RuntimeStartupOwnerAction.requestShutdown,
        CallV2RuntimeStartupOwnerAction.markReady,
        CallV2RuntimeStartupOwnerAction.markFailure,
        CallV2RuntimeStartupOwnerAction.retryStartup,
      ],
    );

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

  test('generation terminal and disposed outcomes are controlled', () {
    expect(
      boundary
          .decideWhileDisabled(
            action: CallV2RuntimeStartupOwnerAction.requestStartup,
            generation: 3,
            latestGeneration: 3,
          )
          .status,
      CallV2RuntimeStartupOwnerDecisionStatus.duplicateNoOp,
    );
    expect(
      boundary
          .decideWhileDisabled(
            action: CallV2RuntimeStartupOwnerAction.requestStartup,
            generation: 2,
            latestGeneration: 3,
          )
          .status,
      CallV2RuntimeStartupOwnerDecisionStatus.staleIgnored,
    );
    expect(
      boundary
          .decideWhileDisabled(
            action: CallV2RuntimeStartupOwnerAction.requestStartup,
            generation: 4,
            disposed: true,
          )
          .status,
      CallV2RuntimeStartupOwnerDecisionStatus.rejected,
    );
    expect(
      boundary
          .decideWhileDisabled(
            action: CallV2RuntimeStartupOwnerAction.requestStartup,
            generation: 4,
            terminal: true,
          )
          .status,
      CallV2RuntimeStartupOwnerDecisionStatus.terminalIgnored,
    );
  });

  test('every controlled decision has no side effects', () {
    for (final decision in <CallV2RuntimeStartupOwnerDecision>[
      const CallV2RuntimeStartupOwnerDecision.disabledInert(
        action: CallV2RuntimeStartupOwnerAction.requestStartup,
        generation: 1,
      ),
      const CallV2RuntimeStartupOwnerDecision.duplicateNoOp(
        action: CallV2RuntimeStartupOwnerAction.requestShutdown,
        generation: 2,
      ),
      const CallV2RuntimeStartupOwnerDecision.staleIgnored(
        action: CallV2RuntimeStartupOwnerAction.markReady,
        generation: 3,
      ),
      const CallV2RuntimeStartupOwnerDecision.rejected(
        action: CallV2RuntimeStartupOwnerAction.markFailure,
        generation: 4,
      ),
      const CallV2RuntimeStartupOwnerDecision.terminalIgnored(
        action: CallV2RuntimeStartupOwnerAction.retryStartup,
        generation: 5,
      ),
    ]) {
      _expectNoDecisionSideEffects(decision);
    }
  });

  test('safe debug output exposes only enums counts and booleans', () {
    final debugMap = boundary.toSafeDebugMap();
    final debugText = '$debugMap $boundary '
        '${boundary.decideWhileDisabled(
      action: CallV2RuntimeStartupOwnerAction.requestStartup,
      generation: 1,
    )}';

    expect(debugMap['statusCount'], 18);
    expect(debugMap['actionCount'], 5);
    expect(debugMap['rollbackCount'], 7);
    expect(debugMap['rolloutEnabled'], isFalse);
    expect(debugMap['startsRuntime'], isFalse);
    expect(debugMap['rollbackPreserved'], isTrue);

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

  test('boundary source contains no real app service or platform hooks', () {
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

  test('rollout routes disabled owner and audits remain closed', () async {
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
      callV2DeveloperNavigationOwnerApprovalScope.isRolloutEnabled,
      isFalse,
    );
    expect(
      callV2DeveloperRouteRegistrationApprovalScope.isRolloutEnabled,
      isFalse,
    );
    expect(
      callV2DeveloperLifecycleObserverApprovalScope.isRolloutEnabled,
      isFalse,
    );
    expect(
      callV2DeveloperSkeletonCompositionAudit.decision,
      CallV2DeveloperSkeletonCompositionDecision.pass,
    );
    expect(
      callV2DeveloperPreWiringSafetyGate.decision,
      CallV2DeveloperPreWiringGateDecision.blockedNoScopeSelected,
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

  test('real app and configuration files do not reference the boundary', () {
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
        isNot(contains('call_v2_runtime_startup_owner')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2RuntimeStartupOwnerBoundary')),
        reason: path,
      );
    }
  });

  test('rollback model preserves one commit disabled V1-safe boundary', () {
    expect(boundary.rollbackPreserved, isTrue);
    expect(
      boundary.rollback,
      <CallV2RuntimeStartupOwnerRollback>[
        CallV2RuntimeStartupOwnerRollback.oneCommitRevert,
        CallV2RuntimeStartupOwnerRollback.keepRolloutFalse,
        CallV2RuntimeStartupOwnerRollback.keepRouteRegistryNull,
        CallV2RuntimeStartupOwnerRollback.keepDisabledOwnerInert,
        CallV2RuntimeStartupOwnerRollback.noDeploymentRequired,
        CallV2RuntimeStartupOwnerRollback.noConfigChanges,
        CallV2RuntimeStartupOwnerRollback.v1Unaffected,
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
