import 'call_v2_token_provider.dart';

class FakeCallV2TokenProvider implements CallV2TokenProvider {
  FakeCallV2TokenProvider({
    this.fail = false,
  });

  bool fail;
  int resolveCount = 0;

  @override
  Future<CallV2TokenResult> resolveToken(CallV2TokenRequest request) async {
    resolveCount += 1;
    if (fail) {
      throw const FakeCallV2TokenProviderFailure();
    }
    return const CallV2TokenResult(
      channelAlias: 'fake-channel',
      rtcUid: 42,
      expiresInSeconds: 3600,
      token: 'fake-token-not-for-production',
    );
  }
}

class FakeCallV2TokenProviderFailure implements Exception {
  const FakeCallV2TokenProviderFailure();
}
