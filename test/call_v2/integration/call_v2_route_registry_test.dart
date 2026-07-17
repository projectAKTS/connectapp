import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('registry construction', () {
    test('constructor has no side effects', () {
      const DisabledCallV2RouteRegistry();
    });

    test('registry sources contain no live services or production access', () {
      final source = _registrySource();

      for (final forbidden in <String>[
        'Firebase',
        'FirebaseAuth',
        'FirebaseAppCheck',
        'FirebaseFirestore',
        'FirebaseFunctions',
        'Permission.',
        'requestPermission',
        'RtcEngine',
        'CallV2ProductionComposition',
        'ProductionCallV2StartupBridge',
        'ProductionCallV2UiCoordinator',
        'CallV2Runtime(',
        'Navigator',
        'BuildContext',
        'GlobalKey',
        'static var',
        'static final',
        'static CallV2RouteRegistry',
        'GetIt',
        'Provider<',
        'callback',
        'enable(',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('activation artifact remains developer-only and blocked', () {
      const activation = callV2RouteRegistryActivation;

      expect(activation, isA<CallV2RouteRegistryActivation>());
      expect(
        activation.decision,
        CallV2RouteRegistryActivationDecision.pass,
      );
      expect(activation.passes, isTrue);
      expect(activation.recordsDeveloperOnly, isTrue);
      expect(activation.recordsRolloutFalse, isTrue);
      expect(activation.recordsResolverNullWhileFalse, isTrue);
      expect(activation.recordsRouteNamesKnown, isTrue);
      expect(activation.recordsRouteFactoryBlockedWhileFalse, isTrue);
      expect(activation.recordsRouteSinkBlockedWhileFalse, isTrue);
      expect(activation.recordsNoRouteObjectCreatedWhileFalse, isTrue);
      expect(activation.recordsNoScreenCreatedWhileFalse, isTrue);
      expect(activation.recordsNoRuntimeStart, isTrue);
      expect(activation.recordsNoBackendAccess, isTrue);
      expect(activation.recordsNoRtcPermissionAccess, isTrue);
      expect(activation.recordsNoNavigationAccess, isTrue);
      expect(activation.recordsNoLifecycleRegistration, isTrue);
      expect(activation.recordsNoAsyncHandles, isTrue);
      expect(activation.recordsNoDependencyPlatformConfigChanges, isTrue);
      expect(activation.recordsNoDeployment, isTrue);
      expect(activation.recordsV1Protected, isTrue);
    });

    test('route constants are names only and do not expose identifiers', () {
      expect(CallV2RouteNames.connecting, '/call-v2/connecting');
      expect(CallV2RouteNames.ready, '/call-v2/ready');
      expect(
        callV2DeveloperCanonicalRouteNames,
        <String>{
          '/call-v2/connecting',
          '/call-v2/audio',
          '/call-v2/video',
          '/call-v2/failure',
        },
      );
      expect(
        isCallV2DeveloperCanonicalRouteName('/call-v2/ready'),
        isFalse,
      );

      for (final name in <String>[
        CallV2RouteNames.connecting,
        CallV2RouteNames.ready,
      ]) {
        expect(name, isNot(contains('uid')));
        expect(name, isNot(contains('callId')));
        expect(name, isNot(contains(':')));
      }
    });
  });

  group('disabled behavior', () {
    test('rollout policy remains literal false', () {
      expect(CallV2RolloutPolicy.productionEnabled, isFalse);
      expect(isCallV2DeveloperRouteRegistrationEnabled, isFalse);
      expect(
        _read('lib/call_v2/integration/call_v2_rollout_policy.dart'),
        contains('static const bool productionEnabled = false;'),
      );
    });

    test('canonical Call V2 routes return null while rollout is false', () {
      expect(
        callV2DeveloperCanonicalRouteNames,
        <String>{
          '/call-v2/connecting',
          '/call-v2/audio',
          '/call-v2/video',
          '/call-v2/failure',
        },
      );

      for (final name in <String>[
        CallV2RouteNames.connecting,
        CallV2RouteNames.activeAudio,
        CallV2RouteNames.activeVideo,
        CallV2RouteNames.controlledFailure,
      ]) {
        expect(resolveCallV2Route(RouteSettings(name: name)), isNull);
        expect(
          const DisabledCallV2RouteRegistry()
              .resolve(RouteSettings(name: name)),
          isNull,
        );
      }
    });

    test('excluded and non-Call V2 routes return null while disabled', () {
      for (final name in <String>[
        CallV2RouteNames.ready,
        '/call-v2/connecting/extra',
        '/call-v2/audio?mode=debug',
        '/call-v2/video#camera',
        '/call-v2/incoming',
        '/call-v2/active',
        '/call-v2/anything',
        '/',
        '/home',
        '/login',
        '/chat',
        '/consultation',
        '/profile/user',
        '/post/post',
      ]) {
        expect(resolveCallV2Route(RouteSettings(name: name)), isNull);
      }
    });

    test('malformed, null, and hostile arguments do not throw while disabled',
        () {
      final hostile = _HostileRouteArguments();

      for (final settings in <RouteSettings>[
        const RouteSettings(name: CallV2RouteNames.connecting),
        RouteSettings(name: CallV2RouteNames.ready, arguments: null),
        RouteSettings(name: CallV2RouteNames.connecting, arguments: hostile),
        RouteSettings(name: CallV2RouteNames.ready, arguments: hostile),
        const RouteSettings(
          name: CallV2RouteNames.ready,
          arguments: <Object, Object>{1: 2},
        ),
      ]) {
        expect(() => resolveCallV2Route(settings), returnsNormally);
        expect(resolveCallV2Route(settings), isNull);
      }
      expect(hostile.readCount, 0);
    });

    test('route registry decision is debug safe while disabled', () {
      const activation = callV2RouteRegistryActivation;
      final decision = describeCallV2RouteRegistryDecision(
        const RouteSettings(name: CallV2RouteNames.connecting),
      );

      expect(
        decision.kind,
        CallV2DeveloperRouteRegistryDecisionKind.rolloutDisabled,
      );
      expect(decision.rolloutEnabled, isFalse);
      expect(decision.routeMayResolve, isFalse);
      expect(decision.toSafeDebugMap()['canonicalRouteCount'], 4);
      expect(activation.toSafeDebugMap()['canonicalRouteCount'], 4);

      final debugText = '${decision.toSafeDebugMap()} $decision '
          '${activation.toSafeDebugMap()} $activation';
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

    test('repeated resolution is side-effect free and constructs no route', () {
      const settings = RouteSettings(name: CallV2RouteNames.connecting);

      for (var index = 0; index < 10; index += 1) {
        expect(resolveCallV2Route(settings), isNull);
      }
    });

    test('policy check precedes route setting use and argument processing', () {
      final source = _read(
        'lib/call_v2/integration/call_v2_route_registry.dart',
      );

      final policyIndex =
          source.indexOf('CallV2RolloutPolicy.productionEnabled');
      final registryIndex = source.indexOf('DisabledCallV2RouteRegistry');
      final decisionIndex =
          source.indexOf('describeCallV2RouteRegistryDecision(settings)');

      expect(policyIndex, greaterThanOrEqualTo(0));
      expect(registryIndex, greaterThan(policyIndex));
      expect(decisionIndex, greaterThan(policyIndex));
      for (final forbidden in <String>[
        'settings.arguments',
        'as Map',
        'Uri.parse',
        'Uri.tryParse',
        'callId',
        'callerUid',
        'calleeUid',
        'remoteParticipantUid',
        'debugPrint',
        'print(',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('activation source has no route construction or service hooks', () {
      final source = _registrySource();

      for (final forbidden in <String>[
        'package:firebase',
        'cloud_firestore',
        'cloud_functions',
        'firebase_auth',
        'FirebaseFirestore',
        'FirebaseFunctions',
        'FirebaseAuth',
        'FirebaseAppCheck',
        'agora_rtc_engine',
        'permission_handler',
        'Permission.',
        'RtcEngine',
        'createAgoraRtcEngine',
        'joinChannel',
        'Navigator.',
        'Navigator(',
        'BuildContext',
        'GlobalKey',
        'MaterialApp(',
        'CallV2Runtime(',
        'CallV2ProductionComposition',
        'ProductionCallV2StartupBridge',
        'CallV2ProductionRouteObjectFactory(',
        'CallV2ProductionRouteSink',
        '.createRoute(',
        '.createScreen(',
        '.show(',
        'dart:async',
        'Timer(',
        'StreamController',
        'StreamSubscription',
        'listen(',
        'AppLifecycleListener',
        'WidgetsBindingObserver',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('real app boundary files do not reference route metadata', () {
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
        final source = _read(path);
        expect(
          source,
          isNot(contains('callV2DeveloperCanonicalRouteNames')),
          reason: path,
        );
        expect(
          source,
          isNot(contains('describeCallV2RouteRegistryDecision')),
          reason: path,
        );
        expect(
          source,
          isNot(contains('callV2RouteRegistryActivation')),
          reason: path,
        );
        expect(
          source,
          isNot(contains('CallV2RouteRegistryActivation')),
          reason: path,
        );
      }
    });
  });
}

String _registrySource() {
  return <String>[
    'lib/call_v2/integration/call_v2_route_registry.dart',
    'lib/call_v2/integration/disabled_call_v2_route_registry.dart',
  ].map(_read).join('\n');
}

String _read(String path) => File(path).readAsStringSync();

final class _HostileRouteArguments {
  int readCount = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    readCount += 1;
    throw StateError('arguments were read');
  }
}
