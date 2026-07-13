import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_developer_lifecycle_observer_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_route_registration_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final skeleton = callV2DeveloperLifecycleObserverSkeleton;

  test('skeleton exists and is developer-only hard-disabled evidence', () {
    expect(skeleton.isDeveloperOnly, isTrue);
    expect(skeleton.isHardDisabled, isTrue);
    expect(skeleton.isRolloutEnabled, isFalse);
    expect(skeleton.isReachable, isFalse);
    expect(skeleton.registersFrameworkHook, isFalse);
    expect(skeleton.registersBindingHook, isFalse);
    expect(skeleton.startsRuntime, isFalse);
    expect(skeleton.accessesServices, isFalse);
    expect(skeleton.accessesMedia, isFalse);
    expect(skeleton.promptsForCapabilities, isFalse);
    expect(skeleton.accessesNavigation, isFalse);
    expect(skeleton.popsRoutes, isFalse);
    expect(skeleton.accessesContext, isFalse);
    expect(skeleton.opensAsyncHandles, isFalse);
    expect(skeleton.protectsV1, isTrue);
    expect(
      skeleton.status,
      containsAll(<Object>[
        CallV2DeveloperLifecycleObserverSkeletonStatus.developerOnly,
        CallV2DeveloperLifecycleObserverSkeletonStatus.hardDisabled,
        CallV2DeveloperLifecycleObserverSkeletonStatus.rolloutFalse,
        CallV2DeveloperLifecycleObserverSkeletonStatus.callV2Unreachable,
        CallV2DeveloperLifecycleObserverSkeletonStatus.noFrameworkLifecycleHook,
        CallV2DeveloperLifecycleObserverSkeletonStatus.noBindingLifecycleHook,
        CallV2DeveloperLifecycleObserverSkeletonStatus.noRuntimeStart,
        CallV2DeveloperLifecycleObserverSkeletonStatus.noServiceAccess,
        CallV2DeveloperLifecycleObserverSkeletonStatus.noMediaAccess,
        CallV2DeveloperLifecycleObserverSkeletonStatus.noCapabilityPrompt,
        CallV2DeveloperLifecycleObserverSkeletonStatus.noNavigationAccess,
        CallV2DeveloperLifecycleObserverSkeletonStatus.noRoutePop,
        CallV2DeveloperLifecycleObserverSkeletonStatus.noContextAccess,
        CallV2DeveloperLifecycleObserverSkeletonStatus.noAsyncHandles,
        CallV2DeveloperLifecycleObserverSkeletonStatus.v1Protected,
      ]),
    );
  });

  test('lifecycle event enum contains the future approved event set', () {
    expect(
      skeleton.lifecycleEvents,
      <CallV2DeveloperLifecycleEvent>[
        CallV2DeveloperLifecycleEvent.resumed,
        CallV2DeveloperLifecycleEvent.inactive,
        CallV2DeveloperLifecycleEvent.paused,
        CallV2DeveloperLifecycleEvent.hidden,
        CallV2DeveloperLifecycleEvent.detached,
        CallV2DeveloperLifecycleEvent.signOut,
        CallV2DeveloperLifecycleEvent.authInvalid,
        CallV2DeveloperLifecycleEvent.dispose,
      ],
    );
  });

  test('every lifecycle event returns an inert disabled decision', () {
    for (final event in skeleton.lifecycleEvents) {
      final decision = skeleton.decideWhileDisabled(
        event: event,
        generation: skeleton.lifecycleEvents.indexOf(event) + 1,
      );

      expect(
        decision.status,
        CallV2DeveloperLifecycleDecisionStatus.disabledInert,
      );
      expect(decision.startsRuntime, isFalse);
      expect(decision.accessesServices, isFalse);
      expect(decision.accessesMedia, isFalse);
      expect(decision.promptsForCapabilities, isFalse);
      expect(decision.accessesNavigation, isFalse);
      expect(decision.popsRoutes, isFalse);
      expect(decision.accessesContext, isFalse);
      expect(decision.registersFrameworkHook, isFalse);
      expect(decision.registersBindingHook, isFalse);
      expect(decision.mutatesV1State, isFalse);
      expect(decision.opensAsyncHandles, isFalse);
      expect(decision.changesRouteRegistry, isFalse);
      expect(decision.scopedToCallV2, isTrue);
    }
  });

  test('duplicate lifecycle events are idempotent no-ops', () {
    final decision = skeleton.decideWhileDisabled(
      event: CallV2DeveloperLifecycleEvent.paused,
      generation: 7,
      latestGeneration: 7,
    );

    expect(
        decision.status, CallV2DeveloperLifecycleDecisionStatus.duplicateNoOp);
    expect(decision.startsRuntime, isFalse);
    expect(decision.accessesServices, isFalse);
    expect(decision.accessesNavigation, isFalse);
    expect(decision.popsRoutes, isFalse);
    expect(decision.mutatesV1State, isFalse);
    expect(decision.opensAsyncHandles, isFalse);
  });

  test('stale lifecycle generation is ignored without side effects', () {
    final decision = skeleton.decideWhileDisabled(
      event: CallV2DeveloperLifecycleEvent.resumed,
      generation: 4,
      latestGeneration: 5,
    );

    expect(
        decision.status, CallV2DeveloperLifecycleDecisionStatus.staleIgnored);
    expect(decision.startsRuntime, isFalse);
    expect(decision.accessesServices, isFalse);
    expect(decision.accessesNavigation, isFalse);
    expect(decision.popsRoutes, isFalse);
    expect(decision.mutatesV1State, isFalse);
    expect(decision.opensAsyncHandles, isFalse);
  });

  test('terminal events require future approval and never start runtime', () {
    final terminalEvents = <CallV2DeveloperLifecycleEvent>[
      CallV2DeveloperLifecycleEvent.detached,
      CallV2DeveloperLifecycleEvent.signOut,
      CallV2DeveloperLifecycleEvent.authInvalid,
      CallV2DeveloperLifecycleEvent.dispose,
    ];

    for (final event in terminalEvents) {
      expect(skeleton.isTerminalEvent(event), isTrue);
      final decision = skeleton.decideWhileDisabled(
        event: event,
        generation: 20,
      );
      expect(decision.terminalEvent, isTrue);
      expect(decision.requiresFutureApprovalForCleanup, isTrue);
      expect(decision.scopedToCallV2, isTrue);
      expect(decision.startsRuntime, isFalse);
      expect(decision.popsRoutes, isFalse);
      expect(decision.mutatesV1State, isFalse);
    }

    for (final event in <CallV2DeveloperLifecycleEvent>[
      CallV2DeveloperLifecycleEvent.resumed,
      CallV2DeveloperLifecycleEvent.inactive,
      CallV2DeveloperLifecycleEvent.paused,
      CallV2DeveloperLifecycleEvent.hidden,
    ]) {
      expect(skeleton.isTerminalEvent(event), isFalse);
    }
  });

  test('cleanup policy is scoped future-only and rollback is one-commit', () {
    expect(
      skeleton.cleanupPolicies,
      <CallV2DeveloperLifecycleCleanupPolicy>[
        CallV2DeveloperLifecycleCleanupPolicy.noCleanupWhileDisabled,
        CallV2DeveloperLifecycleCleanupPolicy.futureApprovalRequired,
        CallV2DeveloperLifecycleCleanupPolicy.callV2ScopedOnly,
        CallV2DeveloperLifecycleCleanupPolicy.duplicateEventsNoOp,
        CallV2DeveloperLifecycleCleanupPolicy.staleGenerationIgnored,
        CallV2DeveloperLifecycleCleanupPolicy.terminalEventsDoNotStartRuntime,
      ],
    );
    expect(
      skeleton.rollbackRequirements,
      <CallV2DeveloperLifecycleRollback>[
        CallV2DeveloperLifecycleRollback.oneCommitRevert,
        CallV2DeveloperLifecycleRollback.keepRolloutFalse,
        CallV2DeveloperLifecycleRollback.keepRouteRegistryNull,
        CallV2DeveloperLifecycleRollback.noDeploymentRequired,
        CallV2DeveloperLifecycleRollback.v1Unaffected,
      ],
    );
  });

  test('safe debug output exposes counts booleans and no sensitive data', () {
    final debugText = '${skeleton.toSafeDebugMap()} $skeleton '
        '${skeleton.decideWhileDisabled(
      event: CallV2DeveloperLifecycleEvent.dispose,
      generation: 1,
    )}';

    expect(skeleton.toSafeDebugMap()['eventCount'], 8);
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

  test('route registration skeleton remains hard-disabled and unreachable', () {
    final routeSkeleton = callV2DeveloperRouteRegistrationSkeleton;

    expect(routeSkeleton.isDeveloperOnly, isTrue);
    expect(routeSkeleton.isHardDisabled, isTrue);
    expect(routeSkeleton.isRolloutEnabled, isFalse);
    expect(routeSkeleton.isReachable, isFalse);
    expect(routeSkeleton.createsRouteObjects, isFalse);
    expect(routeSkeleton.createsScreens, isFalse);
    expect(routeSkeleton.startsRuntime, isFalse);
    expect(routeSkeleton.accessesServices, isFalse);
    expect(routeSkeleton.accessesNavigator, isFalse);
  });

  test('skeleton source has no app framework service navigation or async hooks',
      () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_developer_lifecycle_observer_skeleton.dart',
    );

    for (final forbidden in <String>[
      'package:flutter/',
      'AppLifecycleListener',
      'WidgetsBindingObserver',
      'Firebase',
      'Firestore',
      'Functions',
      'Auth',
      'Permission.',
      'requestPermission',
      'RtcEngine',
      'Agora',
      'Navigator.',
      'Navigator(',
      'BuildContext',
      'GlobalKey',
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

  test('main app router startup and composition do not construct skeleton', () {
    const forbiddenReference = 'call_v2_developer_lifecycle_observer_skeleton';
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

    final appRouter = _read('lib/navigation/app_router.dart');
    expect(appRouter, isNot(contains('call_v2_developer_lifecycle')));
  });
}

String _read(String path) => File(path).readAsStringSync();
