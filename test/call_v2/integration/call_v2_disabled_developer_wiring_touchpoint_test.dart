import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('disabled developer-only Call V2 app wiring touchpoint', () {
    test('main.dart routes through the disabled rollout gate first', () {
      expect(CallV2RolloutPolicy.productionEnabled, isFalse);

      final source = _read('lib/main.dart');
      final onGenerateRoute = _onGenerateRouteSource(source);
      final rolloutCheck =
          onGenerateRoute.indexOf('CallV2RolloutPolicy.productionEnabled');
      final resolverCall = onGenerateRoute.indexOf('resolveCallV2Route');

      expect(
        source,
        contains("import 'call_v2/integration/call_v2_rollout_policy.dart';"),
      );
      expect(rolloutCheck, greaterThanOrEqualTo(0));
      expect(resolverCall, greaterThan(rolloutCheck));
      expect(
        onGenerateRoute,
        contains(
          'final callV2Route = CallV2RolloutPolicy.productionEnabled\n'
          '            ? resolveCallV2Route(settings)\n'
          '            : null;',
        ),
      );
    });

    test('the touchpoint does not register public Call V2 routes', () {
      final source = _read('lib/main.dart');

      for (final forbidden in <String>[
        "'/call-v2/connecting'",
        "'/call-v2/audio'",
        "'/call-v2/video'",
        "'/call-v2/failure'",
        "'/call-v2/ready'",
        'CallV2Screen',
        'IncomingCallV2',
        'ActiveCallV2',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('shared app router remains free of Call V2 route reachability', () {
      final source = _read('lib/navigation/app_router.dart');

      for (final forbidden in <String>[
        'call_v2',
        'CallV2',
        'resolveCallV2Route',
        '/call-v2',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test(
        'touchpoint does not construct runtime backend RTC or navigation owners',
        () {
      final source = _read('lib/main.dart');

      for (final forbidden in <String>[
        'CallV2Runtime(',
        'CallV2ProductionComposition(',
        'ProductionCallV2StartupBridge',
        'call_v2/firebase',
        'call_v2/rtc',
        'call_v2/permissions',
        'createAgoraRtcEngine',
        'joinChannel',
        'requestPermissions',
        'CallV2NavigatorOwner',
        'CallV2LifecycleObserver',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });
}

String _onGenerateRouteSource(String source) {
  final start = source.indexOf('onGenerateRoute: (settings) {');
  final end = source.indexOf('onUnknownRoute: (settings)');

  expect(start, greaterThanOrEqualTo(0));
  expect(end, greaterThan(start));

  return source.substring(start, end);
}

String _read(String path) => File(path).readAsStringSync();
