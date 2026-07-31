import 'package:connect_app/call_v2/firebase/call_v2_token_provider.dart';
import 'package:connect_app/call_v2/firebase/fake_call_v2_token_provider.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fake token provider returns safe test credentials', () async {
    final provider = FakeCallV2TokenProvider();

    final result = await provider.resolveToken(
      const CallV2TokenRequest(mode: CallV2RuntimeCallMode.audio),
    );

    expect(result.channelAlias, 'fake-channel');
    expect(result.rtcUid, 42);
    expect(result.token, isNotEmpty);
    expect(provider.resolveCount, 1);
  });

  test('token result safe debug and string hide sensitive words and values',
      () async {
    const token = 'fake-token-not-for-production';
    const channel = 'fake-channel';
    const result = CallV2TokenResult(
      appId: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      channelAlias: channel,
      rtcUid: 42,
      expiresInSeconds: 3600,
      token: token,
    );
    final debug = result.toSafeDebugMap().toString().toLowerCase();
    final string = result.toString().toLowerCase();

    expect(result.toSafeDebugMap(), <String, Object?>{
      'accessReady': true,
      'appIdReady': true,
      'routingReady': true,
      'numericHandleReady': true,
      'expiresInSeconds': 3600,
    });
    for (final output in <String>[debug, string]) {
      for (final forbidden in <String>[
        token,
        channel,
        'token',
        'channel',
        'uid',
        'rtcu',
        'userid',
        'callid',
        'credential',
        'device',
        'secret',
      ]) {
        expect(output, isNot(contains(forbidden)), reason: forbidden);
      }
    }
  });
}
