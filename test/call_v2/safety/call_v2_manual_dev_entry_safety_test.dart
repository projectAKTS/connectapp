import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual developer entry is not visible from normal navigation', () {
    final main = File('lib/main.dart').readAsStringSync();
    final router = File('lib/navigation/app_router.dart').readAsStringSync();

    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(main, isNot(contains('CallV2ManualDevEntry')));
    expect(router, isNot(contains('CallV2ManualDevEntry')));
    expect(router, isNot(contains('/call-v2')));
  });
}
