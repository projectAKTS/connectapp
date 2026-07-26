import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_config.dart';
import 'package:connect_app/call_v2/ui/call_v2_dev_screen_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rollout false keeps app startup and routing away from internal path',
      () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final routerSource =
        File('lib/navigation/app_router.dart').readAsStringSync();

    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(routerSource, isNot(contains('/call-v2/dev')));
    for (final forbidden in <String>[
      'InternalCallV2Runtime',
      'CallV2RuntimeFactory',
      'RealCallV2PermissionAdapter',
      'RealCallV2TokenProvider',
      'InternalCallV2RtcAdapterGate',
      'requestPermissionsExplicitly',
      'requestTokenExplicitly',
      'initializeRtcExplicitly',
      'joinRtcExplicitly',
      'CallV2DevScreenFactory',
      'CallV2DevScreen(',
    ]) {
      expect(mainSource, isNot(contains(forbidden)), reason: forbidden);
      expect(routerSource, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('developer factory debug output avoids unsafe identifier wording', () {
    const factory = CallV2DevScreenFactory();
    const config = CallV2RuntimeConfig.internalRealDevice(
      allowPermissionRequests: true,
      allowTokenRequests: true,
      allowRtcInitialization: true,
      allowRtcJoin: true,
      exposeDevUi: true,
    );

    final output = factory.describe(config: config).toString().toLowerCase();

    for (final forbidden in _forbiddenDebugFragments) {
      expect(output, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}

const _forbiddenDebugFragments = <String>[
  'token',
  'channel',
  'uid',
  'user',
  'participant',
  'callid',
  'device',
  'credential',
  'secret',
  'raw',
  'payload',
  'stack',
];
