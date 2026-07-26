import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main does not construct internal real-device Call V2 runtime path', () {
    final mainSource = File('lib/main.dart').readAsStringSync();

    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
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
    }
  });

  test('startup contains no Call V2 real-device package wiring', () {
    final mainSource = File('lib/main.dart').readAsStringSync();

    for (final forbidden in <String>[
      "package:permission_handler",
      "package:cloud_functions",
      "package:agora",
      "package:connect_app/call_v2/firebase/real_call_v2_token_provider.dart",
      "package:connect_app/call_v2/permissions/real_call_v2_permission_adapter.dart",
      "package:connect_app/call_v2/runtime/internal_call_v2_runtime.dart",
    ]) {
      expect(mainSource, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}
