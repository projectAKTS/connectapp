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

    test('route constants are names only and do not expose identifiers', () {
      expect(CallV2RouteNames.connecting, '/call-v2/connecting');
      expect(CallV2RouteNames.ready, '/call-v2/ready');

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
      expect(
        _read('lib/call_v2/integration/call_v2_rollout_policy.dart'),
        contains('static const bool productionEnabled = false;'),
      );
    });

    test('any proposed Call V2 route returns null', () {
      for (final name in <String>[
        CallV2RouteNames.connecting,
        CallV2RouteNames.ready,
        '/call-v2/incoming',
        '/call-v2/active',
        '/call-v2/anything',
      ]) {
        expect(resolveCallV2Route(RouteSettings(name: name)), isNull);
      }
    });

    test('existing route names return null from Call V2 registry', () {
      for (final name in <String>[
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

      expect(policyIndex, greaterThanOrEqualTo(0));
      expect(registryIndex, greaterThan(policyIndex));
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
