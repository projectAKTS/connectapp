import 'package:connect_app/call_v2/firebase/call_v2_token_provider.dart';
import 'package:connect_app/call_v2/rtc/call_v2_rtc_session_config_mapper.dart';
import 'package:connect_app/call_v2/runtime/call_v2_internal_session.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps internal session and access result to RTC config', () {
    final session = CallV2InternalSession.outgoing(
      callIdentifier: 'call_ci',
      localIdentifier: 'local_ci',
      remoteIdentifier: 'remote_ci',
      mode: CallV2RuntimeCallMode.video,
    );
    const access = CallV2TokenResult(
      channelAlias: 'unsafe-channel',
      rtcUid: 42,
      expiresInSeconds: 3600,
      token: 'unsafe-token',
    );

    final mapping = const CallV2RtcSessionConfigMapper().map(
      session: session,
      access: access,
    );

    expect(mapping.config.callId, 'call_ci');
    expect(mapping.config.channelName, 'unsafe-channel');
    expect(mapping.config.rtcUid, 42);
    expect(mapping.config.isVideo, isTrue);
    expect(mapping.config.token, 'unsafe-token');
  });

  test('safe debug does not expose RTC identifiers or access values', () {
    final session = CallV2InternalSession.outgoing(
      callIdentifier: 'call_ci',
      localIdentifier: 'local_ci',
      remoteIdentifier: 'remote_ci',
      mode: CallV2RuntimeCallMode.audio,
    );
    const access = CallV2TokenResult(
      channelAlias: 'unsafe-channel',
      rtcUid: 42,
      expiresInSeconds: 3600,
      token: 'unsafe-token',
    );

    final mapping = const CallV2RtcSessionConfigMapper().map(
      session: session,
      access: access,
    );
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
  'unsafe-token',
  'unsafe-channel',
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
