import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app router exposes no public Call V2 routes', () {
    final routerSource =
        File('lib/navigation/app_router.dart').readAsStringSync();

    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    for (final forbidden in <String>[
      '/call-v2',
      'CallV2DevScreen',
      'CallV2DevScreenFactory',
      'resolveCallV2Route',
      'InternalCallV2Runtime',
      'CallV2RuntimeFactory',
    ]) {
      expect(routerSource, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('root app keeps Call V2 route resolver null while rollout false', () {
    final mainSource = File('lib/main.dart').readAsStringSync();

    expect(mainSource, contains('CallV2RolloutPolicy.productionEnabled'));
    expect(mainSource, contains('? resolveCallV2Route(settings)'));
    expect(mainSource, contains(': null'));
    expect(mainSource, isNot(contains('CallV2DevScreen')));
  });
}
