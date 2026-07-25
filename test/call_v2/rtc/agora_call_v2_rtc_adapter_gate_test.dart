import 'dart:io';

import 'package:connect_app/call_v2/call_v2_feature_gate.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/rtc/agora_call_v2_rtc_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real RTC adapter skeleton remains explicitly disabled', () {
    const gate = AgoraCallV2RtcAdapterGate(
      featureGate: CallV2FeatureGate(enabled: false),
    );

    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(gate.allowsConstruction, isFalse);
    expect(gate.productionJoinDisabled, isTrue);
  });

  test('skeleton source does not import Agora or perform RTC work', () {
    final source = File('lib/call_v2/rtc/agora_call_v2_rtc_adapter.dart')
        .readAsStringSync();

    for (final forbidden in <String>[
      'agora_rtc_engine',
      'createAgoraRtcEngine',
      'joinChannel(',
      'initialize(',
      'Firebase',
      'Navigator',
      'permission_handler',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}
