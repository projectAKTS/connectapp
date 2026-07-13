import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_developer_lifecycle_observer_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_navigator_owner_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_route_registration_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final skeleton = callV2DeveloperNavigatorOwnerSkeleton;

  test('skeleton exists and is developer-only hard-disabled evidence', () {
    expect(skeleton.isDeveloperOnly, isTrue);
    expect(skeleton.isHardDisabled, isTrue);
    expect(skeleton.isRolloutEnabled, isFalse);
    expect(skeleton.isReachable, isFalse);
    expect(skeleton.wiresRealNavigation, isFalse);
    expect(skeleton.usesAppNavigationKey, isFalse);
    expect(skeleton.usesGlobalAppKey, isFalse);
    expect(skeleton.storesWidgetContext, isFalse);
    expect(skeleton.callsNavigation, isFalse);
    expect(skeleton.wiresMaterialRouteTable, isFalse);
    expect(skeleton.wiresAppRouter, isFalse);
    expect(skeleton.pushesRoutes, isFalse);
    expect(skeleton.popsRoutes, isFalse);
    expect(skeleton.replacesRoutes, isFalse);
    expect(skeleton.createsRouteObjects, isFalse);
    expect(skeleton.createsScreens, isFalse);
    expect(skeleton.startsRuntime, isFalse);
    expect(skeleton.accessesServices, isFalse);
    expect(skeleton.accessesMedia, isFalse);
    expect(skeleton.promptsForCapabilities, isFalse);
    expect(skeleton.protectsV1, isTrue);
  });

  test('navigation action enum contains the approved future action set', () {
    expect(
      skeleton.actions,
      <CallV2DeveloperNavigatorAction>[
        CallV2DeveloperNavigatorAction.showConnecting,
        CallV2DeveloperNavigatorAction.showAudio,
        CallV2DeveloperNavigatorAction.showVideo,
        CallV2DeveloperNavigatorAction.showFailure,
        CallV2DeveloperNavigatorAction.closeCallV2Route,
        CallV2DeveloperNavigatorAction.dismissFailure,
      ],
    );
  });

  test('every navigation action returns disabled inert while rollout false',
      () {
    for (final action in skeleton.actions) {
      final ownedRoute = action == CallV2DeveloperNavigatorAction.dismissFailure
          ? '/call-v2/failure'
          : '/call-v2/audio';
      final decision = skeleton.decideWhileDisabled(
        action: action,
        generation: skeleton.actions.indexOf(action) + 1,
        ownedRouteName: ownedRoute,
        currentRouteName: ownedRoute,
      );

      expect(
        decision.status,
        CallV2DeveloperNavigatorDecisionStatus.disabledInert,
      );
      expect(decision.createsRouteObject, isFalse);
      expect(decision.createsScreen, isFalse);
      expect(decision.startsRuntime, isFalse);
      expect(decision.accessesServices, isFalse);
      expect(decision.accessesMedia, isFalse);
      expect(decision.promptsForCapabilities, isFalse);
      expect(decision.accessesNavigation, isFalse);
      expect(decision.pushesRoute, isFalse);
      expect(decision.popsRoute, isFalse);
      expect(decision.replacesRoute, isFalse);
      expect(decision.accessesContext, isFalse);
      expect(decision.usesAppKey, isFalse);
      expect(decision.mutatesV1Route, isFalse);
      expect(decision.opensAsyncHandles, isFalse);
    }
  });

  test('route ownership allows only canonical production routes', () {
    expect(
      skeleton.ownedRouteNames,
      <String>{
        '/call-v2/connecting',
        '/call-v2/audio',
        '/call-v2/video',
        '/call-v2/failure',
      },
    );
    expect(skeleton.excludedRouteNames, contains('/call-v2/ready'));
    expect(skeleton.ownsRouteName('/call-v2/ready'), isFalse);

    for (final routeName in skeleton.ownedRouteNames) {
      expect(skeleton.ownsRouteName(routeName), isTrue);
      expect(skeleton.validateRouteOwnership(routeName: routeName), isNull);
      for (final forbidden in <String>[
        'uid',
        'user',
        'participant',
        'callId',
        'token',
        'credential',
        'channel',
      ]) {
        expect(routeName, isNot(contains(forbidden)), reason: forbidden);
      }
    }
  });

  test('V1 unknown ready dynamic query and fragment routes are never owned',
      () {
    for (final routeName in <String>[
      '/call-v2/ready',
      '/home',
      '/login',
      '/chat',
      '/consultation',
      '/profile/someone',
      '/post/abc',
      '/call-v2/unknown',
    ]) {
      expect(skeleton.ownsRouteName(routeName), isFalse, reason: routeName);
    }
    expect(skeleton.ownsRouteName(null), isFalse);
    expect(skeleton.ownsRouteName(''), isFalse);

    expect(
      skeleton.validateRouteOwnership(routeName: '/call-v2/:callId'),
      CallV2DeveloperNavigatorRejection.routeNameContainsDynamicSegment,
    );
    expect(
      skeleton.validateRouteOwnership(routeName: '/call-v2/{callId}'),
      CallV2DeveloperNavigatorRejection.routeNameContainsDynamicSegment,
    );
    expect(
      skeleton.validateRouteOwnership(routeName: '/call-v2/audio?debug=true'),
      CallV2DeveloperNavigatorRejection.routeNameContainsQueryOrFragment,
    );
    expect(
      skeleton.validateRouteOwnership(routeName: '/call-v2/video#fragment'),
      CallV2DeveloperNavigatorRejection.routeNameContainsQueryOrFragment,
    );
    expect(
      skeleton.validateRouteOwnership(
          routeName: '/call-v2/audio', routeArguments: <String, Object?>{}),
      CallV2DeveloperNavigatorRejection.routeArgumentsNotNull,
    );
  });

  test('future close requires owned current route match before pop', () {
    expect(
      skeleton.validateFutureClose(
        ownedRouteName: '/call-v2/audio',
        currentRouteName: '/call-v2/audio',
      ),
      isNull,
    );
    expect(
      skeleton.validateFutureClose(
        ownedRouteName: '/call-v2/audio',
        currentRouteName: '/chat',
      ),
      CallV2DeveloperNavigatorRejection.currentRouteMismatch,
    );
    expect(
      skeleton.validateFutureClose(
        ownedRouteName: '/chat',
        currentRouteName: '/chat',
      ),
      CallV2DeveloperNavigatorRejection.routeNotOwned,
    );
  });

  test('duplicate navigation and stale generation are safe no-ops', () {
    final duplicate = skeleton.decideWhileDisabled(
      action: CallV2DeveloperNavigatorAction.showAudio,
      generation: 9,
      latestGeneration: 9,
    );
    final stale = skeleton.decideWhileDisabled(
      action: CallV2DeveloperNavigatorAction.showAudio,
      generation: 8,
      latestGeneration: 9,
    );

    expect(
      duplicate.status,
      CallV2DeveloperNavigatorDecisionStatus.duplicateNoOp,
    );
    expect(stale.status, CallV2DeveloperNavigatorDecisionStatus.staleIgnored);
    for (final decision in <CallV2DeveloperNavigatorDecision>[
      duplicate,
      stale,
    ]) {
      expect(decision.startsRuntime, isFalse);
      expect(decision.accessesNavigation, isFalse);
      expect(decision.pushesRoute, isFalse);
      expect(decision.popsRoute, isFalse);
      expect(decision.replacesRoute, isFalse);
      expect(decision.mutatesV1Route, isFalse);
    }
  });

  test('terminal and closed actions do not start runtime', () {
    for (final action in <CallV2DeveloperNavigatorAction>[
      CallV2DeveloperNavigatorAction.closeCallV2Route,
      CallV2DeveloperNavigatorAction.dismissFailure,
    ]) {
      final decision = skeleton.decideWhileDisabled(
        action: action,
        generation: 10,
        ownedRouteName: '/call-v2/failure',
        currentRouteName: '/call-v2/failure',
      );

      expect(decision.status,
          CallV2DeveloperNavigatorDecisionStatus.disabledInert);
      expect(decision.startsRuntime, isFalse);
      expect(decision.popsRoute, isFalse);
      expect(decision.mutatesV1Route, isFalse);
    }
  });

  test('safe debug output exposes counts booleans and no sensitive data', () {
    final debugText = '${skeleton.toSafeDebugMap()} $skeleton '
        '${skeleton.decideWhileDisabled(
      action: CallV2DeveloperNavigatorAction.showAudio,
      generation: 1,
    )}';

    expect(skeleton.toSafeDebugMap()['ownedRouteCount'], 4);
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
      ...skeleton.ownedRouteNames,
      '/call-v2/ready',
      '/call-v2/anything',
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

  test('route and lifecycle developer skeletons remain hard-disabled', () {
    final routeSkeleton = callV2DeveloperRouteRegistrationSkeleton;
    final lifecycleSkeleton = callV2DeveloperLifecycleObserverSkeleton;

    expect(routeSkeleton.isDeveloperOnly, isTrue);
    expect(routeSkeleton.isHardDisabled, isTrue);
    expect(routeSkeleton.isRolloutEnabled, isFalse);
    expect(routeSkeleton.isReachable, isFalse);
    expect(routeSkeleton.createsRouteObjects, isFalse);
    expect(routeSkeleton.createsScreens, isFalse);

    expect(lifecycleSkeleton.isDeveloperOnly, isTrue);
    expect(lifecycleSkeleton.isHardDisabled, isTrue);
    expect(lifecycleSkeleton.isRolloutEnabled, isFalse);
    expect(lifecycleSkeleton.isReachable, isFalse);
    expect(lifecycleSkeleton.registersFrameworkHook, isFalse);
    expect(lifecycleSkeleton.registersBindingHook, isFalse);
    expect(lifecycleSkeleton.startsRuntime, isFalse);
  });

  test('navigator owner skeleton source has no app navigation or service hooks',
      () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_developer_navigator_owner_skeleton.dart',
    );

    for (final forbidden in <String>[
      'package:flutter/',
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
    const forbiddenReference = 'call_v2_developer_navigator_owner_skeleton';
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

  test('rollback controls preserve false rollout and V1 protection', () {
    expect(
      skeleton.rollbackRequirements,
      <CallV2DeveloperNavigatorRollback>[
        CallV2DeveloperNavigatorRollback.oneCommitRevert,
        CallV2DeveloperNavigatorRollback.keepRolloutFalse,
        CallV2DeveloperNavigatorRollback.keepRouteRegistryNull,
        CallV2DeveloperNavigatorRollback.noDeploymentRequired,
        CallV2DeveloperNavigatorRollback.v1Unaffected,
      ],
    );
  });
}

String _read(String path) => File(path).readAsStringSync();
