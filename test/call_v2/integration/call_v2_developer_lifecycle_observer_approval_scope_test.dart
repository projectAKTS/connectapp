import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_developer_lifecycle_observer_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_lifecycle_observer_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_pre_wiring_safety_gate.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_route_registration_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_skeleton_composition_audit.dart';
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
  final scope = callV2DeveloperLifecycleObserverApprovalScope;

  test('approval scope artifact records exact Phase 7M approval', () {
    expect(scope, isA<CallV2DeveloperLifecycleObserverApprovalScope>());
    expect(scope.hasHumanApproval, isTrue);
    expect(scope.isLifecycleObserverOnly, isTrue);
    expect(scope.isDeveloperOnly, isTrue);
    expect(scope.isRolloutEnabled, isFalse);
    expect(scope.startsRuntime, isFalse);
    expect(scope.accessesBackendFirebase, isFalse);
    expect(scope.accessesRtcPermissions, isFalse);
    expect(scope.wiresNavigator, isFalse);
    expect(scope.mutatesRouteRegistry, isFalse);
    expect(scope.registersFrameworkLifecycleHook, isFalse);
    expect(scope.registersBindingLifecycleHook, isFalse);
    expect(scope.wiresStartupMainRouter, isFalse);
    expect(scope.changesPubspecPlatformConfig, isFalse);
    expect(scope.changesRulesFunctionsConfig, isFalse);
    expect(scope.isDeploymentApproved, isFalse);
    expect(scope.protectsV1, isTrue);
  });

  test(
      'pre-wiring gate default remains blocked but approved lifecycle scope is allowed',
      () {
    expect(
      callV2DeveloperPreWiringSafetyGate.decision,
      CallV2DeveloperPreWiringGateDecision.blockedNoScopeSelected,
    );
    expect(
      scope.evaluatedGate.selectedScope,
      CallV2DeveloperPreWiringScope.lifecycleObserverOnly,
    );
    expect(
      scope.evaluatedGate.decision,
      CallV2DeveloperPreWiringGateDecision
          .allowedForExplicitFutureDeveloperOnlyPhase,
    );
    expect(scope.evaluatedGate.canWireRoutes, isFalse);
    expect(scope.evaluatedGate.canStartRuntime, isFalse);
    expect(scope.evaluatedGate.canRegisterLifecycleObserver, isFalse);
    expect(scope.evaluatedGate.canWireNavigator, isFalse);
    expect(scope.evaluatedGate.canAccessBackendFirebase, isFalse);
    expect(scope.evaluatedGate.canInitializeRtc, isFalse);
    expect(scope.evaluatedGate.canRequestPermissions, isFalse);
    expect(scope.evaluatedGate.canModifyPubspecPlatform, isFalse);
    expect(scope.evaluatedGate.canModifyRulesFunctionsConfig, isFalse);
  });

  test('allowed and forbidden files are scoped to lifecycle observer only', () {
    expect(
      scope.allowedFutureFiles,
      <String>[
        'lib/call_v2/integration/call_v2_lifecycle_observer.dart',
        'test/call_v2/integration/call_v2_lifecycle_observer_test.dart',
      ],
    );
    expect(scope.allowedFutureFilesAreLifecycleObserverOnly, isTrue);
    expect(scope.forbidsOutOfScopeFutureFiles, isTrue);
    expect(
      scope.forbiddenFutureFiles,
      containsAll(<String>[
        'lib/main.dart',
        'lib/navigation/app_router.dart',
        'lib/call_v2/startup/**',
        'lib/call_v2/runtime/**',
        'lib/call_v2/firebase/**',
        'lib/call_v2/rtc/**',
        'lib/call_v2/permissions/**',
        'lib/call_v2/integration/call_v2_route_registry.dart',
        'lib/call_v2/integration/navigator/**',
        'pubspec.yaml',
        'pubspec.lock',
        'android/**',
        'ios/**',
        'firestore.rules',
        'firebase.json',
        'connect_functions/**',
      ]),
    );
  });

  test('lifecycle skeleton remains hard-disabled unreachable and inert', () {
    final skeleton = callV2DeveloperLifecycleObserverSkeleton;

    expect(scope.lifecycleSkeletonIsDisabled, isTrue);
    expect(skeleton.isHardDisabled, isTrue);
    expect(skeleton.isReachable, isFalse);
    expect(skeleton.isRolloutEnabled, isFalse);
    expect(skeleton.registersFrameworkHook, isFalse);
    expect(skeleton.registersBindingHook, isFalse);
    expect(skeleton.opensAsyncHandles, isFalse);

    for (final event in CallV2DeveloperLifecycleEvent.values) {
      final decision = skeleton.decideWhileDisabled(
        event: event,
        generation: 1,
      );
      expect(
        decision.status,
        CallV2DeveloperLifecycleDecisionStatus.disabledInert,
        reason: event.name,
      );
      expect(decision.startsRuntime, isFalse);
      expect(decision.accessesServices, isFalse);
      expect(decision.accessesMedia, isFalse);
      expect(decision.accessesNavigation, isFalse);
      expect(decision.registersFrameworkHook, isFalse);
      expect(decision.registersBindingHook, isFalse);
      expect(decision.opensAsyncHandles, isFalse);
      expect(decision.changesRouteRegistry, isFalse);
    }

    expect(
      skeleton
          .decideWhileDisabled(
            event: CallV2DeveloperLifecycleEvent.paused,
            generation: 1,
            latestGeneration: 1,
          )
          .status,
      CallV2DeveloperLifecycleDecisionStatus.duplicateNoOp,
    );
    expect(
      skeleton
          .decideWhileDisabled(
            event: CallV2DeveloperLifecycleEvent.paused,
            generation: 1,
            latestGeneration: 2,
          )
          .status,
      CallV2DeveloperLifecycleDecisionStatus.staleIgnored,
    );
  });

  test('route registry rollout disabled owner and audits remain closed',
      () async {
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
    expect(callV2DeveloperRouteRegistrationApprovalScope.isRolloutEnabled,
        isFalse);
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

  test('safe debug output contains no sensitive data or route strings', () {
    final debugText = '${scope.toSafeDebugMap()} $scope';
    expect(scope.toSafeDebugMap()['evidenceCount'], 16);
    expect(scope.toSafeDebugMap()['allowedFutureFileCount'], 2);
    expect(scope.toSafeDebugMap()['forbiddenFutureFileCount'], 16);
    expect(scope.toSafeDebugMap()['gateDecision'],
        'allowedForExplicitFutureDeveloperOnlyPhase');

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

  test('approval source contains no framework lifecycle or service hooks', () {
    final source = _approvalSource();

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

  test('real app boundary files do not reference lifecycle approval scope', () {
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
        isNot(contains('call_v2_developer_lifecycle_observer_approval_scope')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2DeveloperLifecycleObserverApprovalScope')),
        reason: path,
      );
    }
  });

  test('rollback preserves one commit disabled routing and V1 protection', () {
    expect(scope.rollbackPreserved, isTrue);
    expect(
      scope.rollback,
      <CallV2DeveloperLifecycleObserverApprovalRollback>[
        CallV2DeveloperLifecycleObserverApprovalRollback.oneCommitRevert,
        CallV2DeveloperLifecycleObserverApprovalRollback.keepRolloutFalse,
        CallV2DeveloperLifecycleObserverApprovalRollback.keepRouteRegistryNull,
        CallV2DeveloperLifecycleObserverApprovalRollback.keepDisabledOwnerInert,
        CallV2DeveloperLifecycleObserverApprovalRollback.noDeploymentRequired,
        CallV2DeveloperLifecycleObserverApprovalRollback.noConfigChanges,
        CallV2DeveloperLifecycleObserverApprovalRollback.v1Unaffected,
      ],
    );
  });
}

String _approvalSource() {
  return File(
    'lib/call_v2/integration/'
    'call_v2_developer_lifecycle_observer_approval_scope.dart',
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
