import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/firebase/call_v2_callable_transport.dart';
import 'package:connect_app/call_v2/firebase/call_v2_token_provider.dart';
import 'package:connect_app/call_v2/firebase/real_call_v2_token_provider.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'real token provider is gated and does not call Firebase on construction',
      () async {
    final transport = _FakeCallableTransport();
    final provider = RealCallV2TokenProvider(transport: transport);

    await expectLater(
      provider.resolveToken(
        const CallV2TokenRequest(mode: CallV2RuntimeCallMode.audio),
      ),
      throwsA(isA<CallV2ClientError>()),
    );
    expect(transport.callCount, 0);
  });

  test('enabled real token provider calls injected transport explicitly',
      () async {
    final transport = _FakeCallableTransport();
    final provider = RealCallV2TokenProvider(
      allowRequests: true,
      transport: transport,
      defaultRequest: const CallV2TokenBackendRequest(
        callId: 'call_a',
        localParticipantUid: 'local_a',
      ),
    );

    final result = await provider.resolveToken(
      const CallV2TokenRequest(mode: CallV2RuntimeCallMode.video),
    );

    expect(transport.callCount, 1);
    expect(transport.lastCallableName, callV2RtcTokenCallableName);
    expect(result.rtcUid, 7);
    expect(result.expiresInSeconds, 3600);
  });

  test('real token provider source uses injected transport only', () {
    final source = File(
      'lib/call_v2/firebase/real_call_v2_token_provider.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('cloud_functions')));
    expect(source, isNot(contains('firebase_auth')));
    expect(source, isNot(contains('firebase_app_check')));
  });

  test('real token provider debug output is generic', () {
    const provider = RealCallV2TokenProvider();
    final debug = provider.toSafeDebugMap().toString().toLowerCase();

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
  'participant',
  'callid',
  'device',
  'credential',
  'secret',
  'raw',
  'payload',
  'stack',
];

class _FakeCallableTransport implements CallV2CallableTransport {
  int callCount = 0;
  String? lastCallableName;

  @override
  Future<Object?> call(
      String callableName, Map<String, Object?> request) async {
    callCount += 1;
    lastCallableName = callableName;
    return <String, Object?>{
      'status': 'ok',
      'result': <String, Object?>{
        'channelAlias': 'safe-channel',
        'rtcUid': 7,
        'token': 'safe-token',
        'expiresInSeconds': 3600,
      },
    };
  }
}
