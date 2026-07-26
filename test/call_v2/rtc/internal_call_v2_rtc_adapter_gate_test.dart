import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/rtc/internal_call_v2_rtc_adapter_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('internal RTC gate is blocked by default while rollout remains false',
      () {
    const gate = InternalCallV2RtcAdapterGate();

    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(gate.canConstructAdapter, isFalse);
    expect(gate.canInitialize, isFalse);
    expect(gate.canJoin, isFalse);
  });

  test('internal RTC gate requires explicit construction initialize and join',
      () {
    const gate = InternalCallV2RtcAdapterGate(
      allowAdapterConstruction: true,
      allowInitialization: true,
      allowJoin: true,
    );

    expect(gate.canConstructAdapter, isTrue);
    expect(gate.canInitialize, isTrue);
    expect(gate.canJoin, isTrue);
  });

  test('safe debug is generic', () {
    const gate = InternalCallV2RtcAdapterGate(
      allowAdapterConstruction: true,
      allowInitialization: true,
      allowJoin: true,
    );

    final debug = gate.toSafeDebugMap().toString().toLowerCase();
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
