import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/firebase/call_v2_token_provider.dart';
import 'package:connect_app/call_v2/firebase/real_call_v2_token_provider.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'real token provider is gated and does not call Firebase on construction',
      () async {
    const provider = RealCallV2TokenProvider();

    await expectLater(
      provider.resolveToken(
        const CallV2TokenRequest(mode: CallV2RuntimeCallMode.audio),
      ),
      throwsA(isA<CallV2ClientError>()),
    );
  });

  test('real token provider source has no direct Firebase import', () {
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
  'callid',
  'device',
  'credential',
  'secret',
  'raw',
  'payload',
  'stack',
];
