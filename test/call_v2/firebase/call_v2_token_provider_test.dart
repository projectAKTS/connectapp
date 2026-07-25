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

  test('token result safe debug and string hide token text', () async {
    const token = 'fake-token-not-for-production';
    const result = CallV2TokenResult(
      channelAlias: 'fake-channel',
      rtcUid: 42,
      expiresInSeconds: 3600,
      token: token,
    );

    expect(result.toSafeDebugMap().toString(), isNot(contains(token)));
    expect(result.toString(), isNot(contains(token)));
  });
}
