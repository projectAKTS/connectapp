import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup and router do not instantiate real Call V2 adapters', () {
    final main = File('lib/main.dart').readAsStringSync();
    final router = File('lib/navigation/app_router.dart').readAsStringSync();

    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    for (final source in <String>[main, router]) {
      for (final forbidden in <String>[
        'RealCallV2PermissionAdapter',
        'RealCallV2TokenProvider',
        'AgoraCallV2RtcAdapter',
        'AgoraSdkCallV2RtcEngineClient',
        'CallV2ManualDevEntry',
        'requestPermissionsExplicitly',
        'requestTokenExplicitly',
        'initializeRtcExplicitly',
        'joinRtcExplicitly',
        'createAgoraRtcEngine',
        'Permission.microphone',
        'FirebaseFunctions.instance',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    }
  });

  test('real adapter safe debug avoids unsafe identifier wording', () {
    final sources = <String>[
      File('lib/call_v2/permissions/real_call_v2_permission_adapter.dart')
          .readAsStringSync(),
      File('lib/call_v2/firebase/real_call_v2_token_provider.dart')
          .readAsStringSync(),
      File('lib/call_v2/rtc/agora_call_v2_rtc_adapter.dart').readAsStringSync(),
    ].join('\n');

    expect(sources, isNot(contains('print(')));
    expect(sources, isNot(contains('debugPrint(')));
    expect(sources, isNot(contains('log(')));
  });
}
