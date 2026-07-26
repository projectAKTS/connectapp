import 'package:connect_app/call_v2/runtime/call_v2_manual_session_inputs.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valid inputs build internal real-device runtime config', () {
    final inputs = _inputs();
    final config = inputs.toRuntimeConfig();

    expect(config.useRealAdapters, isTrue);
    expect(config.allowPermissionRequests, isTrue);
    expect(config.allowTokenRequests, isTrue);
    expect(config.allowRtcInitialization, isTrue);
    expect(config.allowRtcJoin, isTrue);
    expect(inputs.toTokenBackendData()['callId'], 'session_a');
    expect(inputs.toTokenBackendData()['participantUid'], 'local_a');
  });

  test('missing app id blocks real setup before initialize', () {
    final inputs = _inputs(app: '');
    final config = inputs.toRuntimeConfig();

    expect(inputs.applicationReady, isFalse);
    expect(config.allowRtcInitialization, isFalse);
    expect(config.allowRtcJoin, isFalse);
  });

  test('invalid identifiers are rejected', () {
    for (final value in <String>['', 'a/b', 'a\\b', 'a' * 129]) {
      expect(() => _inputs(session: value),
          throwsA(isA<CallV2ManualSessionInputError>()));
      expect(() => _inputs(local: value),
          throwsA(isA<CallV2ManualSessionInputError>()));
      expect(() => _inputs(remote: value),
          throwsA(isA<CallV2ManualSessionInputError>()));
    }
    expect(
      () => _inputs(local: 'same', remote: 'same'),
      throwsA(isA<CallV2ManualSessionInputError>()),
    );
  });

  test('safe debug hides raw identifiers and sensitive words', () {
    final debug = _inputs().toString().toLowerCase();

    for (final forbidden in <String>[
      'session_a',
      'local_a',
      'remote_b',
      'app-for-test',
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
    ]) {
      expect(debug, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}

CallV2ManualSessionInputs _inputs({
  String app = 'app-for-test',
  String session = 'session_a',
  String local = 'local_a',
  String remote = 'remote_b',
}) {
  return CallV2ManualSessionInputs(
    rtcApplicationIdentifier: app,
    sessionIdentifier: session,
    localParticipantIdentifier: local,
    remoteParticipantIdentifier: remote,
    mode: CallV2RuntimeCallMode.video,
    useRealAdapters: true,
    allowPermissionRequests: true,
    allowTokenRequests: true,
    allowRtcInitialization: true,
    allowRtcJoin: true,
  );
}
