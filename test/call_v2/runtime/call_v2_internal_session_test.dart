import 'package:connect_app/call_v2/runtime/call_v2_internal_session.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session keeps raw values internally and exposes opaque debug labels',
      () {
    final session = CallV2InternalSession.outgoing(
      callIdentifier: 'call_ci',
      localIdentifier: 'local_ci',
      remoteIdentifier: 'remote_ci',
      mode: CallV2RuntimeCallMode.video,
    );

    expect(session.callIdentifier, 'call_ci');
    expect(session.localHandle.value, 'local_ci');
    expect(session.remoteHandle.value, 'remote_ci');
    expect(session.localHandle.safeLabel, startsWith('h'));
    expect(session.localHandle.safeLabel, isNot('local_ci'));

    final output =
        '${session.toSafeDebugMap()} ${session.toString()}'.toLowerCase();
    for (final forbidden in <String>[
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
    ]) {
      expect(output, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('session rejects malformed identifiers and self sessions', () {
    for (final value in <String>['', ' has-space', 'path/value']) {
      expect(
        () => CallV2InternalSession.outgoing(
          callIdentifier: value,
          localIdentifier: 'local_ci',
          remoteIdentifier: 'remote_ci',
          mode: CallV2RuntimeCallMode.audio,
        ),
        throwsA(isA<CallV2InternalSessionError>()),
      );
    }

    expect(
      () => CallV2InternalSession.outgoing(
        callIdentifier: 'call_ci',
        localIdentifier: 'same',
        remoteIdentifier: 'same',
        mode: CallV2RuntimeCallMode.audio,
      ),
      throwsA(isA<CallV2InternalSessionError>()),
    );
  });

  test('copy updates phase and readiness without changing handles', () {
    final session = CallV2InternalSession.incoming(
      callIdentifier: 'call_ci',
      localIdentifier: 'local_ci',
      remoteIdentifier: 'remote_ci',
      mode: CallV2RuntimeCallMode.audio,
    );

    final updated = session.copyWith(
      phase: CallV2RuntimePhase.ready,
      accessReady: true,
      rtcReady: true,
    );

    expect(updated.phase, CallV2RuntimePhase.ready);
    expect(updated.accessReady, isTrue);
    expect(updated.rtcReady, isTrue);
    expect(updated.localHandle.safeLabel, session.localHandle.safeLabel);
  });
}
