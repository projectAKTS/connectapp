import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('route sink source uses no real Navigator or global routing APIs', () {
    final combined = _readAll(<String>[
      'lib/call_v2/integration/call_v2_production_route_sink.dart',
      'lib/call_v2/integration/call_v2_production_route_sink_adapter.dart',
      'lib/call_v2/integration/call_v2_production_route_sink_result.dart',
      'lib/call_v2/integration/call_v2_production_route_sink_state.dart',
    ]);

    for (final forbidden in <String>[
      'Navigator.',
      'NavigatorState',
      'GlobalKey',
      'BuildContext',
      'Navigator.push',
      'Navigator.pop',
      'pushReplacement',
      'pushAndRemoveUntil',
      'replaceRoute',
      'register',
      'RouteRegistry',
      'Firebase',
      'Firestore',
      'Agora',
      'Rtc',
      'Permission',
      'backend',
      'Timer',
      'Stream',
      'Subscription',
    ]) {
      expect(combined, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('real app files remain isolated and rollout remains false', () {
    final main = File('lib/main.dart').readAsStringSync();
    final router = File('lib/navigation/app_router.dart').readAsStringSync();

    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(main, isNot(contains('CallV2ProductionRouteSink')));
    expect(router, isNot(contains('CallV2ProductionRouteSink')));
    expect(main, isNot(contains('CallV2ProductionRouteSinkAdapter')));
    expect(router, isNot(contains('CallV2ProductionRouteSinkAdapter')));
  });

  test('disabled owner remains inert and composition remains unconstructed',
      () {
    final disabledOwner = File(
      'lib/call_v2/integration/disabled_call_v2_app_integration.dart',
    ).readAsStringSync();
    final composition = File(
      'lib/call_v2/production/call_v2_production_composition.dart',
    ).readAsStringSync();

    expect(disabledOwner, isNot(contains('CallV2ProductionRouteSink')));
    expect(
      disabledOwner,
      isNot(contains('CallV2ProductionRouteObjectFactory')),
    );
    expect(composition, isNot(contains('CallV2ProductionRouteSink')));
    expect(composition, contains('uiRouteIntegrationAvailable: false'));
    expect(composition, contains('runtimeStartupBridgeAvailable: false'));
  });

  test('V1 and platform scopes remain untouched by the route sink', () {
    final combined = _readAll(<String>[
      'lib/call_v2/integration/call_v2_production_route_sink.dart',
      'lib/call_v2/integration/call_v2_production_route_sink_adapter.dart',
      'lib/call_v2/integration/call_v2_production_route_sink_result.dart',
      'lib/call_v2/integration/call_v2_production_route_sink_state.dart',
    ]);

    for (final forbidden in <String>[
      'call_v1',
      'legacy',
      'connect_functions',
      'firebase.json',
      'firestore.rules',
      'android/',
      'ios/',
      'macos/',
      'windows/',
      'linux/',
      'web/',
    ]) {
      expect(combined, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}

String _readAll(List<String> paths) {
  return paths.map((path) => File(path).readAsStringSync()).join('\n');
}
