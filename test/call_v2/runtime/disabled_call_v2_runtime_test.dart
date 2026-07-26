import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_state.dart';
import 'package:connect_app/call_v2/runtime/disabled_call_v2_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disabled runtime starts in controlled failed state', () {
    final runtime = DisabledCallV2Runtime();
    addTearDown(runtime.dispose);

    expect(runtime.currentState.phase, CallV2RuntimePhase.failed);
    expect(
      runtime.currentState.errorCategory,
      CallV2RuntimeErrorCategory.invalidState,
    );
  });

  test('disabled runtime rejects start and accept without side effects',
      () async {
    final runtime = DisabledCallV2Runtime();
    addTearDown(runtime.dispose);

    await expectLater(
      runtime.startOutgoingCall(mode: CallV2RuntimeCallMode.audio),
      throwsA(isA<CallV2ClientError>()),
    );
    await expectLater(
      runtime.acceptIncomingCall(mode: CallV2RuntimeCallMode.video),
      throwsA(isA<CallV2ClientError>()),
    );
    expect(runtime.currentState.phase, CallV2RuntimePhase.failed);
  });

  test('disabled runtime safe debug contains no sensitive wording', () {
    final runtime = DisabledCallV2Runtime();
    addTearDown(runtime.dispose);

    final debug = runtime.toSafeDebugMap().toString().toLowerCase();
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
