import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_developer_lifecycle_observer_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_navigator_owner_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_route_registration_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_runtime_startup_owner_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final skeleton = callV2DeveloperRuntimeStartupOwnerSkeleton;

  test('skeleton exists and is developer-only hard-disabled evidence', () {
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
  });

  test('startup action enum contains the approved future action set', () {
    expect(
      skeleton.actions,
      <CallV2DeveloperRuntimeStartupAction>[
        CallV2DeveloperRuntimeStartupAction.prepareDeveloperStartup,
        CallV2DeveloperRuntimeStartupAction.requestStartup,
        CallV2DeveloperRuntimeStartupAction.markStartupReady,
        CallV2DeveloperRuntimeStartupAction.rejectStartup,
        CallV2DeveloperRuntimeStartupAction.stopStartup,
        CallV2DeveloperRuntimeStartupAction.disposeStartup,
      ],
    );
  });

  test('startup ownership rules preserve disabled rollout boundaries', () {
    expect(
      skeleton.ownershipRules,
      <CallV2DeveloperRuntimeStartupOwnershipRule>[
        CallV2DeveloperRuntimeStartupOwnershipRule
            .explicitHumanApprovalRequired,
        CallV2DeveloperRuntimeStartupOwnershipRule
            .developerOnlyAllowlistRequired,
        CallV2DeveloperRuntimeStartupOwnershipRule.rolloutFalseBlocksStartup,
        CallV2DeveloperRuntimeStartupOwnershipRule.noProductionServiceContact,
        CallV2DeveloperRuntimeStartupOwnershipRule.noPublicUserExposure,
        CallV2DeveloperRuntimeStartupOwnershipRule.idempotentStartup,
        CallV2DeveloperRuntimeStartupOwnershipRule.duplicateStartupNoOp,
        CallV2DeveloperRuntimeStartupOwnershipRule.staleGenerationIgnored,
        CallV2DeveloperRuntimeStartupOwnershipRule
            .terminalOrDisposedStartupRejected,
        CallV2DeveloperRuntimeStartupOwnershipRule.controlledFailureOnly,
      ],
    );
  });

  test('every startup action returns disabled inert while rollout false', () {
    for (final action in skeleton.actions) {
      final decision = skeleton.decideWhileDisabled(
        action: action,
        generation: skeleton.actions.indexOf(action) + 1,
      );

      expect(
        decision.status,
        CallV2DeveloperRuntimeStartupDecisionStatus.disabledInert,
      );
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
  });

  test('duplicate startup and stale generation are safe no-ops', () {
    final duplicate = skeleton.decideWhileDisabled(
      action: CallV2DeveloperRuntimeStartupAction.requestStartup,
      generation: 5,
      latestGeneration: 5,
    );
    final stale = skeleton.decideWhileDisabled(
      action: CallV2DeveloperRuntimeStartupAction.requestStartup,
      generation: 4,
      latestGeneration: 5,
    );

    expect(
      duplicate.status,
      CallV2DeveloperRuntimeStartupDecisionStatus.duplicateNoOp,
    );
    expect(
      stale.status,
      CallV2DeveloperRuntimeStartupDecisionStatus.staleIgnored,
    );
    for (final decision in <CallV2DeveloperRuntimeStartupDecision>[
      duplicate,
      stale,
    ]) {
      expect(decision.constructsRuntime, isFalse);
      expect(decision.startsRuntime, isFalse);
      expect(decision.constructsComposition, isFalse);
      expect(decision.accessesServices, isFalse);
      expect(decision.accessesNavigation, isFalse);
      expect(decision.mutatesV1State, isFalse);
    }
  });

  test('startup after dispose terminal and failure are controlled rejections',
      () {
    final disposed = skeleton.decideWhileDisabled(
      action: CallV2DeveloperRuntimeStartupAction.requestStartup,
      generation: 1,
      disposed: true,
    );
    final terminal = skeleton.decideWhileDisabled(
      action: CallV2DeveloperRuntimeStartupAction.requestStartup,
      generation: 2,
      terminal: true,
    );
    final failure = skeleton.decideWhileDisabled(
      action: CallV2DeveloperRuntimeStartupAction.rejectStartup,
      generation: 3,
      controlledFailure: true,
    );

    expect(
        disposed.status, CallV2DeveloperRuntimeStartupDecisionStatus.rejected);
    expect(disposed.rejection, CallV2DeveloperRuntimeStartupRejection.disposed);
    expect(
        terminal.status, CallV2DeveloperRuntimeStartupDecisionStatus.rejected);
    expect(terminal.rejection, CallV2DeveloperRuntimeStartupRejection.terminal);
    expect(
        failure.status, CallV2DeveloperRuntimeStartupDecisionStatus.rejected);
    expect(
      failure.rejection,
      CallV2DeveloperRuntimeStartupRejection.controlledFailure,
    );

    for (final decision in <CallV2DeveloperRuntimeStartupDecision>[
      disposed,
      terminal,
      failure,
    ]) {
      expect(decision.constructsRuntime, isFalse);
      expect(decision.startsRuntime, isFalse);
      expect(decision.constructsComposition, isFalse);
      expect(decision.accessesServices, isFalse);
      expect(decision.mutatesV1State, isFalse);
      expect(decision.controlledFailureOnly, isTrue);
    }
  });

  test('safe debug output exposes counts booleans and no sensitive data', () {
    final debugText = '${skeleton.toSafeDebugMap()} $skeleton '
        '${skeleton.decideWhileDisabled(
      action: CallV2DeveloperRuntimeStartupAction.requestStartup,
      generation: 1,
    )}';

    expect(skeleton.toSafeDebugMap()['actionCount'], 6);
    expect(skeleton.toSafeDebugMap()['hardDisabled'], isTrue);
    for (final forbidden in <String>[
      '/call-v2',
      'uid',
      'user',
      'participant',
      'callId',
      'token',
      'credential',
      'channel',
      'payload',
      'stack',
    ]) {
      expect(debugText, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('rollout route registry disabled registry and owner remain inert',
      () async {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);

    for (final routeName in <String>[
      '/call-v2/connecting',
      '/call-v2/audio',
      '/call-v2/video',
      '/call-v2/failure',
      '/call-v2/ready',
      '/',
      '/home',
      '/chat',
    ]) {
      expect(resolveCallV2Route(RouteSettings(name: routeName)), isNull);
      expect(
        const DisabledCallV2RouteRegistry().resolve(
          RouteSettings(name: routeName),
        ),
        isNull,
      );
    }

    final owner = DisabledCallV2ProductionIntegrationOwner();
    await owner.initialize();

    expect(owner.status.rolloutEnabled, isFalse);
    expect(owner.status.compositionConstructed, isFalse);
    expect(owner.status.runtimeStarted, isFalse);
    expect(owner.status.routesRegistered, isFalse);
    expect(owner.status.screensAvailable, isFalse);
  });

  test('previous developer skeletons remain hard-disabled', () {
    final routeSkeleton = callV2DeveloperRouteRegistrationSkeleton;
    final lifecycleSkeleton = callV2DeveloperLifecycleObserverSkeleton;
    final navigatorSkeleton = callV2DeveloperNavigatorOwnerSkeleton;

    expect(routeSkeleton.isDeveloperOnly, isTrue);
    expect(routeSkeleton.isHardDisabled, isTrue);
    expect(routeSkeleton.isRolloutEnabled, isFalse);
    expect(routeSkeleton.isReachable, isFalse);

    expect(lifecycleSkeleton.isDeveloperOnly, isTrue);
    expect(lifecycleSkeleton.isHardDisabled, isTrue);
    expect(lifecycleSkeleton.isRolloutEnabled, isFalse);
    expect(lifecycleSkeleton.isReachable, isFalse);
    expect(lifecycleSkeleton.registersFrameworkHook, isFalse);
    expect(lifecycleSkeleton.registersBindingHook, isFalse);

    expect(navigatorSkeleton.isDeveloperOnly, isTrue);
    expect(navigatorSkeleton.isHardDisabled, isTrue);
    expect(navigatorSkeleton.isRolloutEnabled, isFalse);
    expect(navigatorSkeleton.isReachable, isFalse);
    expect(navigatorSkeleton.wiresRealNavigation, isFalse);
    expect(navigatorSkeleton.callsNavigation, isFalse);
  });

  test('runtime startup skeleton source has no startup service or async hooks',
      () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_developer_runtime_startup_owner_skeleton.dart',
    );

    for (final forbidden in <String>[
      'package:flutter/',
      'CallV2Runtime(',
      'CallV2ProductionComposition',
      'ProductionCallV2StartupBridge',
      'AppLifecycleListener',
      'WidgetsBindingObserver',
      'Navigator.',
      'Navigator(',
      'GlobalKey',
      'BuildContext',
      'MaterialApp',
      'Firebase',
      'Firestore',
      'Functions',
      'Auth',
      'Permission.',
      'requestPermission',
      'RtcEngine',
      'Agora',
      'Timer(',
      'StreamController',
      'StreamSubscription',
      'listen(',
      'read(',
      'write(',
      'debugPrint',
      'print(',
    ]) {
      expect(source.contains(forbidden), isFalse, reason: forbidden);
    }
  });

  test(
      'main app router startup composition config rules and functions isolated',
      () {
    const forbiddenReference =
        'call_v2_developer_runtime_startup_owner_skeleton';
    for (final path in <String>[
      'lib/main.dart',
      'lib/navigation/app_router.dart',
      'lib/call_v2/startup/production_call_v2_startup_bridge.dart',
      'lib/call_v2/production/call_v2_production_composition.dart',
      'connect_functions/index.js',
      'pubspec.yaml',
      'pubspec.lock',
      'firebase.json',
      'firestore.rules',
    ]) {
      expect(
        _read(path),
        isNot(contains(forbiddenReference)),
        reason: path,
      );
    }
  });

  test('rollback controls preserve disabled owner and V1 protection', () {
    expect(
      skeleton.rollbackRequirements,
      <CallV2DeveloperRuntimeStartupRollback>[
        CallV2DeveloperRuntimeStartupRollback.oneCommitRevert,
        CallV2DeveloperRuntimeStartupRollback.keepRolloutFalse,
        CallV2DeveloperRuntimeStartupRollback.keepRouteRegistryNull,
        CallV2DeveloperRuntimeStartupRollback.keepDisabledOwnerInert,
        CallV2DeveloperRuntimeStartupRollback.noDeploymentRequired,
        CallV2DeveloperRuntimeStartupRollback.v1Unaffected,
      ],
    );
  });
}

String _read(String path) => File(path).readAsStringSync();
