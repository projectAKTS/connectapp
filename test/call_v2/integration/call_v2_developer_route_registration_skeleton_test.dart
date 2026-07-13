import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_developer_route_registration_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final skeleton = callV2DeveloperRouteRegistrationSkeleton;

  test('skeleton exists and is developer-only hard-disabled wiring', () {
    expect(skeleton.isDeveloperOnly, isTrue);
    expect(skeleton.isHardDisabled, isTrue);
    expect(skeleton.isRolloutEnabled, isFalse);
    expect(skeleton.isReachable, isFalse);
    expect(skeleton.createsRouteObjects, isFalse);
    expect(skeleton.createsScreens, isFalse);
    expect(skeleton.startsRuntime, isFalse);
    expect(skeleton.accessesServices, isFalse);
    expect(skeleton.accessesNavigator, isFalse);
    expect(
      skeleton.status,
      containsAll(<Object>[
        CallV2DeveloperRouteRegistrationSkeletonStatus.developerOnly,
        CallV2DeveloperRouteRegistrationSkeletonStatus.hardDisabled,
        CallV2DeveloperRouteRegistrationSkeletonStatus.rolloutFalse,
        CallV2DeveloperRouteRegistrationSkeletonStatus.callV2Unreachable,
        CallV2DeveloperRouteRegistrationSkeletonStatus
            .routeRegistryStillReturnsNull,
        CallV2DeveloperRouteRegistrationSkeletonStatus.noRouteObjectCreation,
        CallV2DeveloperRouteRegistrationSkeletonStatus.noScreenCreation,
        CallV2DeveloperRouteRegistrationSkeletonStatus.noRuntimeStart,
        CallV2DeveloperRouteRegistrationSkeletonStatus.noServiceAccess,
        CallV2DeveloperRouteRegistrationSkeletonStatus.noNavigationAccess,
        CallV2DeveloperRouteRegistrationSkeletonStatus.v1Protected,
      ]),
    );
  });

  test('skeleton lists only canonical production routes and excludes ready',
      () {
    expect(
      skeleton.allowedRouteNames,
      <String>{
        '/call-v2/connecting',
        '/call-v2/audio',
        '/call-v2/video',
        '/call-v2/failure',
      },
    );
    expect(skeleton.excludedRouteNames, contains('/call-v2/ready'));
    expect(skeleton.allowedRouteNames, isNot(contains('/call-v2/ready')));

    for (final routeName in skeleton.allowedRouteNames) {
      expect(routeName, startsWith('/call-v2/'));
      expect(routeName, isNot(contains(':')));
      expect(routeName, isNot(contains('{')));
      expect(routeName, isNot(contains('?')));
      expect(routeName, isNot(contains('#')));
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

  test('skeleton rejects dynamic query fragment and noncanonical routes', () {
    expect(
      skeleton.validateRoute(routeName: '/call-v2/:callId'),
      CallV2DeveloperRouteRegistrationRejection.routeNameContainsDynamicSegment,
    );
    expect(
      skeleton.validateRoute(routeName: '/call-v2/{callId}'),
      CallV2DeveloperRouteRegistrationRejection.routeNameContainsDynamicSegment,
    );
    expect(
      skeleton.validateRoute(routeName: '/call-v2/audio?debug=true'),
      CallV2DeveloperRouteRegistrationRejection
          .routeNameContainsQueryOrFragment,
    );
    expect(
      skeleton.validateRoute(routeName: '/call-v2/video#fragment'),
      CallV2DeveloperRouteRegistrationRejection
          .routeNameContainsQueryOrFragment,
    );
    expect(
      skeleton.validateRoute(routeName: '/call-v2/ready'),
      CallV2DeveloperRouteRegistrationRejection.routeNameNotCanonical,
    );
    expect(
      skeleton.validateRoute(routeName: '/home'),
      CallV2DeveloperRouteRegistrationRejection.routeNameNotCanonical,
    );
  });

  test('skeleton requires null route arguments', () {
    expect(
      skeleton.validateRoute(
        routeName: '/call-v2/connecting',
        routeArguments: <String, Object?>{},
      ),
      CallV2DeveloperRouteRegistrationRejection.routeArgumentsNotNull,
    );
    expect(
      skeleton.validateRoute(routeName: '/call-v2/connecting'),
      isNull,
    );
  });

  test('disabled resolution returns null-like inert decisions only', () {
    for (final routeName in skeleton.allowedRouteNames) {
      final decision = skeleton.resolveWhileDisabled(routeName: routeName);

      expect(
        decision.status,
        CallV2DeveloperRouteRegistrationDecisionStatus.disabledNull,
      );
      expect(decision.rejection, isNull);
      expect(decision.createsRouteObject, isFalse);
      expect(decision.createsScreen, isFalse);
      expect(decision.startsRuntime, isFalse);
      expect(decision.accessesServices, isFalse);
      expect(decision.accessesNavigator, isFalse);
    }

    final rejected = skeleton.resolveWhileDisabled(routeName: '/call-v2/ready');
    expect(
      rejected.status,
      CallV2DeveloperRouteRegistrationDecisionStatus.rejected,
    );
    expect(
      rejected.rejection,
      CallV2DeveloperRouteRegistrationRejection.routeNameNotCanonical,
    );
  });

  test('safe debug output exposes counts and no route or sensitive data', () {
    final debugText = '${skeleton.toSafeDebugMap()} $skeleton '
        '${const CallV2DeveloperRouteRegistrationDecision.disabledNull()}';

    expect(skeleton.toSafeDebugMap()['allowedRouteCount'], 4);
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

  test('rollout registry disabled registry and non-Call-V2 routes stay inert',
      () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);

    for (final routeName in <String>[
      ...skeleton.allowedRouteNames,
      '/call-v2/ready',
      '/call-v2/anything',
      '/',
      '/home',
      '/login',
      '/chat',
      '/consultation',
    ]) {
      expect(resolveCallV2Route(RouteSettings(name: routeName)), isNull);
      expect(
        const DisabledCallV2RouteRegistry().resolve(
          RouteSettings(name: routeName),
        ),
        isNull,
      );
    }
  });

  test('disabled owner remains inert and production composition is not started',
      () async {
    final owner = DisabledCallV2ProductionIntegrationOwner();

    await owner.initialize();

    expect(owner.status.rolloutEnabled, isFalse);
    expect(owner.status.compositionConstructed, isFalse);
    expect(owner.status.runtimeStarted, isFalse);
    expect(owner.status.routesRegistered, isFalse);
    expect(owner.status.screensAvailable, isFalse);
  });

  test('real app route tables do not register production Call V2 routes', () {
    final appRouter = _read('lib/navigation/app_router.dart');
    final main = _read('lib/main.dart');
    final materialRouteTable =
        main.split('routes: {').last.split('onGenerateRoute:').first;

    expect(appRouter, isNot(contains('/call-v2/')));
    expect(materialRouteTable, isNot(contains('/call-v2/')));
    expect(main, contains('resolveCallV2Route(settings)'));
  });

  test('skeleton source has no runtime service navigation or async wiring', () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_developer_route_registration_skeleton.dart',
    );

    for (final forbidden in <String>[
      'package:flutter/',
      'Firebase',
      'Firestore',
      'Functions',
      'Auth',
      'Permission.',
      'requestPermission',
      'RtcEngine',
      'Agora',
      'CallV2ProductionRouteObjectFactory',
      'CallV2ProductionScreenFactory',
      'CallV2Runtime(',
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

  test('pubspec platform config rules functions and V1 remain untouched', () {
    final forbiddenReference = 'call_v2_developer_route_registration_skeleton';
    for (final path in <String>[
      'pubspec.yaml',
      'pubspec.lock',
      'firebase.json',
      'firestore.rules',
      'connect_functions/index.js',
      'lib/main.dart',
      'lib/navigation/app_router.dart',
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
      <CallV2DeveloperRouteRegistrationRollback>[
        CallV2DeveloperRouteRegistrationRollback.oneCommitRevert,
        CallV2DeveloperRouteRegistrationRollback.keepRolloutFalse,
        CallV2DeveloperRouteRegistrationRollback.keepRouteRegistryNull,
        CallV2DeveloperRouteRegistrationRollback.noDeploymentRequired,
        CallV2DeveloperRouteRegistrationRollback.v1Unaffected,
      ],
    );
  });
}

String _read(String path) => File(path).readAsStringSync();
