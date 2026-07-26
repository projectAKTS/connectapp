import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_config.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fake is the development default and rollout remains false', () {
    const config = CallV2RuntimeConfig.defaultDevelopment;

    expect(config.mode, CallV2RuntimeMode.fake);
    expect(config.allowPermissionRequests, isTrue);
    expect(config.allowTokenRequests, isTrue);
    expect(config.allowRtcInitialization, isTrue);
    expect(config.allowRtcJoin, isTrue);
    expect(config.exposeDevUi, isTrue);
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
  });

  test('production path defaults to hard disabled', () {
    const config = CallV2RuntimeConfig.defaultProduction;

    expect(config.mode, CallV2RuntimeMode.productionDisabled);
    expect(config.allowPermissionRequests, isFalse);
    expect(config.allowTokenRequests, isFalse);
    expect(config.allowRtcInitialization, isFalse);
    expect(config.allowRtcJoin, isFalse);
    expect(config.exposeDevUi, isFalse);
  });

  test('internal real device mode is explicit and safe debug is generic', () {
    const config = CallV2RuntimeConfig.internalRealDevice(
      allowPermissionRequests: true,
      allowTokenRequests: true,
      allowRtcInitialization: true,
      allowRtcJoin: true,
      exposeDevUi: true,
    );

    expect(config.mode, CallV2RuntimeMode.internalRealDevice);
    expect(config.canUseInternalRealDevice, isTrue);

    final debug = config.toSafeDebugMap().toString().toLowerCase();
    for (final forbidden in _forbiddenDebugFragments) {
      expect(debug, isNot(contains(forbidden)));
    }
  });
}

const _forbiddenDebugFragments = <String>[
  'token',
  'channel',
  'uid',
  'user',
  'callid',
  'device',
  'credential',
  'secret',
  'raw',
  'payload',
  'stack',
];
