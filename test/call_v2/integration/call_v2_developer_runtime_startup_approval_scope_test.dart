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
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final scope = callV2DeveloperRuntimeStartupApprovalScope;

  test('approval scope artifact records exact Phase 7S approval', () {
    expect(scope, isA<CallV2DeveloperRuntimeStartupApprovalScope>());
    expect(scope.hasHumanApproval, isTrue);
    expect(scope.isRuntimeStartupOwnerOnly, isTrue);
    expect(scope.isDeveloperOnly, isTrue);
    expect(scope.isRolloutEnabled, isFalse);
    expect(scope.accessesBackendFirebase, isFalse);
    expect(scope.accessesRtcPermissions, isFalse);
    expect(scope.wiresNavigation, isFalse);
    expect(scope.registersLifecycleObserver, isFalse);
    expect(scope.mutatesRouteRegistry, isFalse);
    expect(scope.constructsProductionComposition, isFalse);
    expect(scope.startsRuntime, isFalse);
    expect(scope.wiresStartupMainRouter, isFalse);
    expect(scope.changesPubspecPlatformConfig, isFalse);
    expect(scope.changesRulesFunctionsConfig, isFalse);
    expect(scope.isDeploymentApproved, isFalse);
    expect(scope.protectsV1, isTrue);
    expect(scope.evidence, hasLength(16));
  });

  test('pre-wiring gate default remains blocked but approved scope evaluates',
      () {
    expect(
      callV2DeveloperPreWiringSafetyGate.decision,
      CallV2DeveloperPreWiringGateDecision.blockedNoScopeSelected,
    );
    expect(
      scope.evaluatedGate.selectedScope,
      CallV2DeveloperPreWiringScope.runtimeStartupOwnerOnly,
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

  test('allowed and forbidden files are scoped to future owner only', () {
    expect(
      scope.allowedFutureFiles,
      <String>[
        'lib/call_v2/integration/call_v2_runtime_startup_owner.dart',
        'test/call_v2/integration/call_v2_runtime_startup_owner_test.dart',
      ],
    );
    expect(scope.allowedFutureFilesAreRuntimeStartupOwnerOnly, isTrue);
    expect(scope.forbidsOutOfScopeFutureFiles, isTrue);
    expect(scope.forbiddenFutureFiles, hasLength(18));
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
        'lib/call_v2/integration/call_v2_lifecycle_observer.dart',
        'lib/call_v2/integration/call_v2_navigator_owner.dart',
        'lib/call_v2/production/call_v2_production_composition.dart',
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

  test('runtime startup skeleton remains hard-disabled unreachable and inert',
      () {
    final skeleton = callV2DeveloperRuntimeStartupOwnerSkeleton;

    expect(skeleton.isDeveloperOnly, isTrue);
    expect(skeleton.isHardDisabled, isTrue);
    expect(skeleton.isRolloutEnabled, isFalse);
    expect(skeleton.isReachable, isFalse);
    expect(skeleton.constructsRuntime, isFalse);
    expect(skeleton.startsRuntime, isFalse);
    expect(skeleton.constructsComposition, isFalse);
    expect(skeleton.wiresStartupBridge, isFalse);
    expect(skeleton.wiresMainDart, isFalse);
    expect(skeleton.wiresAppRouter, isFalse);
    expect(skeleton.mutatesRouteRegistry, isFalse);
    expect(skeleton.registersLifecycleHook, isFalse);
    expect(skeleton.accessesNavigation, isFalse);
    expect(skeleton.accessesServices, isFalse);
    expect(skeleton.accessesMedia, isFalse);
    expect(skeleton.promptsForCapabilities, isFalse);
    expect(skeleton.opensAsyncHandles, isFalse);
    expect(skeleton.isDeploymentApproved, isFalse);
    expect(skeleton.protectsV1, isTrue);

    for (final action in skeleton.actions) {
      final generation = skeleton.actions.indexOf(action) + 1;
      final decision = skeleton.decideWhileDisabled(
        action: action,
        generation: generation,
      );

      expect(
        decision.status,
        CallV2DeveloperRuntimeStartupDecisionStatus.disabledInert,
        reason: action.name,
      );
      _expectNoRuntimeDecisionSideEffects(decision);
    }

    _expectNoRuntimeDecisionSideEffects(
      skeleton.decideWhileDisabled(
        action: CallV2DeveloperRuntimeStartupAction.requestStartup,
        generation: 2,
        latestGeneration: 2,
      ),
    );
    expect(
      skeleton
          .decideWhileDisabled(
            action: CallV2DeveloperRuntimeStartupAction.requestStartup,
            generation: 1,
            latestGeneration: 2,
          )
          .status,
      CallV2DeveloperRuntimeStartupDecisionStatus.staleIgnored,
    );
    expect(
      skeleton
          .decideWhileDisabled(
            action: CallV2DeveloperRuntimeStartupAction.requestStartup,
            generation: 2,
            disposed: true,
          )
          .status,
      CallV2DeveloperRuntimeStartupDecisionStatus.rejected,
    );
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

  test('safe debug output contains no sensitive data or route strings', () {
    final debugMap = scope.toSafeDebugMap();
    final debugText = '$debugMap $scope';

    expect(debugMap['evidenceCount'], 16);
    expect(debugMap['allowedFutureFileCount'], 2);
    expect(debugMap['forbiddenFutureFileCount'], 18);
    expect(
      debugMap['gateDecision'],
      'allowedForExplicitFutureDeveloperOnlyPhase',
    );

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

  test('approval source contains no real app runtime or service hooks', () {
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

  test('real app boundary files do not reference approval scope', () {
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
        isNot(
          contains('call_v2_developer_runtime_startup_approval_scope'),
        ),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2DeveloperRuntimeStartupApprovalScope')),
        reason: path,
      );
    }
  });

  test('rollback preserves one commit disabled routing and V1 protection', () {
    expect(scope.rollbackPreserved, isTrue);
    expect(
      scope.rollback,
      <CallV2DeveloperRuntimeStartupApprovalRollback>[
        CallV2DeveloperRuntimeStartupApprovalRollback.oneCommitRevert,
        CallV2DeveloperRuntimeStartupApprovalRollback.keepRolloutFalse,
        CallV2DeveloperRuntimeStartupApprovalRollback.keepRouteRegistryNull,
        CallV2DeveloperRuntimeStartupApprovalRollback.keepDisabledOwnerInert,
        CallV2DeveloperRuntimeStartupApprovalRollback.noDeploymentRequired,
        CallV2DeveloperRuntimeStartupApprovalRollback.noConfigChanges,
        CallV2DeveloperRuntimeStartupApprovalRollback.v1Unaffected,
      ],
    );
  });
}

void _expectNoRuntimeDecisionSideEffects(
  CallV2DeveloperRuntimeStartupDecision decision,
) {
  expect(decision.constructsRuntime, isFalse);
  expect(decision.startsRuntime, isFalse);
  expect(decision.constructsComposition, isFalse);
  expect(decision.wiresStartupBridge, isFalse);
  expect(decision.accessesServices, isFalse);
  expect(decision.accessesMedia, isFalse);
  expect(decision.promptsForCapabilities, isFalse);
  expect(decision.accessesNavigation, isFalse);
  expect(decision.mutatesRouteRegistry, isFalse);
  expect(decision.registersLifecycleHook, isFalse);
  expect(decision.mutatesV1State, isFalse);
  expect(decision.opensAsyncHandles, isFalse);
  expect(decision.exposesPublicUsers, isFalse);
  expect(decision.contactsProductionServices, isFalse);
  expect(decision.controlledFailureOnly, isTrue);
}

String _approvalSource() {
  return File(
    'lib/call_v2/integration/'
    'call_v2_developer_runtime_startup_approval_scope.dart',
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
