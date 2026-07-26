import 'package:connect_app/call_v2/firebase/call_v2_token_request_mapper.dart';
import 'package:connect_app/call_v2/runtime/call_v2_internal_session.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps internal session to existing access request and backend data', () {
    final session = CallV2InternalSession.outgoing(
      callIdentifier: 'call_ci',
      localIdentifier: 'local_ci',
      remoteIdentifier: 'remote_ci',
      mode: CallV2RuntimeCallMode.video,
    );

    final mapping = const CallV2TokenRequestMapper().map(session);

    expect(mapping.request.mode, CallV2RuntimeCallMode.video);
    expect(mapping.backendData, <String, Object?>{
      'callId': 'call_ci',
      'participantUid': 'local_ci',
      'isVideo': true,
    });
  });

  test('safe debug does not expose identifier or access wording', () {
    final session = CallV2InternalSession.outgoing(
      callIdentifier: 'call_ci',
      localIdentifier: 'local_ci',
      remoteIdentifier: 'remote_ci',
      mode: CallV2RuntimeCallMode.audio,
    );
    final mapping = const CallV2TokenRequestMapper().map(session);

    final output =
        '${mapping.toSafeDebugMap()} ${mapping.toString()}'.toLowerCase();
    for (final forbidden in _forbiddenDebugFragments) {
      expect(output, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}

const _forbiddenDebugFragments = <String>[
  'call_ci',
  'local_ci',
  'remote_ci',
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
