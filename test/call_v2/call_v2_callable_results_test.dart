import 'package:connect_app/call_v2/call_v2_callable_results.dart';
import 'package:connect_app/call_v2/domain/call_lifecycle.dart';
import 'package:connect_app/call_v2/domain/participant_media_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StartCallV2Result', () {
    test('parses valid start result and preserves server callId', () {
      final result = StartCallV2Result.fromCallableResult(_startResult());

      expect(result.callId, 'server_call');
      expect(result.version, 1);
      expect(result.idempotentReplay, isFalse);
      expect(result.ringingDeadlineAt, DateTime.utc(2026, 6, 25, 12, 1));
    });

    test('requires ringing lifecycle, positive version, and replay flag', () {
      expect(
        () => StartCallV2Result.fromCallableResult(
          _startResult(lifecycleState: 'active'),
        ),
        throwsFormatException,
      );
      expect(
        () => StartCallV2Result.fromCallableResult(_startResult(version: 0)),
        throwsFormatException,
      );
      expect(
        () => StartCallV2Result.fromCallableResult(
          _startResult(idempotentReplay: 'false'),
        ),
        throwsFormatException,
      );
    });

    test('rejects missing, malformed, non-map, and private responses', () {
      expect(
        () => StartCallV2Result.fromCallableResult(
            _startResult()..remove('callId')),
        throwsFormatException,
      );
      expect(
        () => StartCallV2Result.fromCallableResult(
          _startResult(ringingDeadlineAt: 'bad'),
        ),
        throwsFormatException,
      );
      expect(
        () => StartCallV2Result.fromCallableResult('not-a-map'),
        throwsFormatException,
      );
      expect(
        () => StartCallV2Result.fromCallableResult(
            _startResult()..['commandId'] = 'private'),
        throwsFormatException,
      );
    });
  });

  group('CallV2LifecycleCommandResult', () {
    test('parses valid accepted and terminal results', () {
      final accepted = CallV2LifecycleCommandResult.fromCallableResult(
        _lifecycleResult(
          lifecycleState: 'accepted',
          acceptedAt: '2026-06-25T12:00:00.000Z',
          acceptedJoinDeadlineAt: '2026-06-25T12:00:30.000Z',
        ),
      );
      final terminal = CallV2LifecycleCommandResult.fromCallableResult(
        _lifecycleResult(
          lifecycleState: 'completed',
          terminal: true,
          endedAt: '2026-06-25T12:05:00.000Z',
          endReason: 'caller_ended',
          failureCode: null,
        ),
      );

      expect(accepted.lifecycle, CallLifecycle.accepted);
      expect(accepted.acceptedAt, DateTime.utc(2026, 6, 25, 12));
      expect(terminal.lifecycle, CallLifecycle.completed);
      expect(terminal.terminal, isTrue);
      expect(terminal.endReason, 'caller_ended');
    });

    test(
        'rejects unknown lifecycle, malformed version, timestamp, terminal, and private fields',
        () {
      for (final raw in <Map<String, Object?>>[
        _lifecycleResult(lifecycleState: 'waiting'),
        _lifecycleResult(version: '1'),
        _lifecycleResult(acceptedAt: 'bad'),
        _lifecycleResult(terminal: 'true'),
        _lifecycleResult()..['lockReleaseResults'] = <String, Object?>{},
        _lifecycleResult(lifecycleState: 'active', terminal: true),
      ]) {
        expect(
          () => CallV2LifecycleCommandResult.fromCallableResult(raw),
          throwsFormatException,
        );
      }
    });
  });

  group('CallV2MediaReportResult', () {
    test('parses every backend media string', () {
      const expected = <String, ParticipantMediaState>{
        'not_joined': ParticipantMediaState.notJoined,
        'preparing': ParticipantMediaState.preparing,
        'joining': ParticipantMediaState.joining,
        'joined': ParticipantMediaState.joined,
        'reconnecting': ParticipantMediaState.reconnecting,
        'disconnected': ParticipantMediaState.disconnected,
        'left': ParticipantMediaState.left,
        'media_failed': ParticipantMediaState.mediaFailed,
      };

      for (final entry in expected.entries) {
        final result = CallV2MediaReportResult.fromCallableResult(
          _mediaResult(mediaState: entry.key),
        );

        expect(result.mediaState, entry.value);
      }
    });

    test('rejects invalid media data', () {
      for (final raw in <Map<String, Object?>>[
        _mediaResult(mediaState: 'muted'),
        _mediaResult(mediaVersion: -1),
        _mediaResult(callVersion: 0),
        _mediaResult(mediaChanged: 'true'),
        _mediaResult(promotedToActive: 'false'),
        _mediaResult()..['taskOutbox'] = <String, Object?>{},
      ]) {
        expect(
          () => CallV2MediaReportResult.fromCallableResult(raw),
          throwsFormatException,
        );
      }
    });
  });

  group('CallV2LeaseRenewalResult', () {
    test('parses valid renewal result', () {
      final result = CallV2LeaseRenewalResult.fromCallableResult(
        _leaseResult(),
      );

      expect(result.callId, 'call_a');
      expect(result.heartbeatVersion, 1);
      expect(result.lifecycle, CallLifecycle.active);
      expect(result.callVersion, 3);
      expect(result.lastHeartbeatAt, DateTime.utc(2026, 6, 25, 12));
      expect(result.leaseExpiresAt, DateTime.utc(2026, 6, 25, 12, 1));
    });

    test(
        'rejects invalid heartbeat, call version, timestamps, and private fields',
        () {
      for (final raw in <Map<String, Object?>>[
        _leaseResult(heartbeatVersion: 0),
        _leaseResult(callVersion: 0),
        _leaseResult(lastHeartbeatAt: 'bad'),
        _leaseResult()..['fencingToken'] = 1,
      ]) {
        expect(
          () => CallV2LeaseRenewalResult.fromCallableResult(raw),
          throwsFormatException,
        );
      }
    });
  });
}

Map<String, Object?> _startResult({
  String callId = 'server_call',
  String lifecycleState = 'ringing',
  Object? version = 1,
  Object? ringingDeadlineAt = '2026-06-25T12:01:00.000Z',
  Object? idempotentReplay = false,
}) {
  return <String, Object?>{
    'callId': callId,
    'lifecycleState': lifecycleState,
    'version': version,
    'ringingDeadlineAt': ringingDeadlineAt,
    'callerRtcUid': 1,
    'calleeRtcUid': 2,
    'idempotentReplay': idempotentReplay,
  };
}

Map<String, Object?> _lifecycleResult({
  String callId = 'call_a',
  String lifecycleState = 'accepted',
  Object? version = 2,
  Object? terminal,
  Object? acceptedAt,
  Object? acceptedJoinDeadlineAt,
  Object? endedAt,
  Object? endReason,
  Object? failureCode,
  Object? idempotentReplay = false,
}) {
  return <String, Object?>{
    'callId': callId,
    'lifecycleState': lifecycleState,
    'version': version,
    if (terminal != null) 'terminal': terminal,
    'acceptedAt': acceptedAt,
    'acceptedJoinDeadlineAt': acceptedJoinDeadlineAt,
    'endedAt': endedAt,
    'endReason': endReason,
    'failureCode': failureCode,
    'idempotentReplay': idempotentReplay,
  };
}

Map<String, Object?> _mediaResult({
  String callId = 'call_a',
  Object? participantUid = 'caller',
  Object? mediaState = 'joined',
  Object? mediaVersion = 1,
  Object? mediaChanged = true,
  Object? lifecycleState = 'active',
  Object? callVersion = 3,
  Object? promotedToActive = true,
  Object? activeAt,
  Object? reconnectDeadlineAt,
  Object? idempotentReplay = false,
}) {
  return <String, Object?>{
    'callId': callId,
    'participantUid': participantUid,
    'mediaState': mediaState,
    'mediaVersion': mediaVersion,
    'mediaChanged': mediaChanged,
    'lifecycleState': lifecycleState,
    'callVersion': callVersion,
    'promotedToActive': promotedToActive,
    'activeAt': activeAt,
    'reconnectDeadlineAt': reconnectDeadlineAt,
    'idempotentReplay': idempotentReplay,
  };
}

Map<String, Object?> _leaseResult({
  String callId = 'call_a',
  Object? participantUid = 'caller',
  Object? heartbeatVersion = 1,
  Object? lastHeartbeatAt = '2026-06-25T12:00:00.000Z',
  Object? leaseExpiresAt = '2026-06-25T12:01:00.000Z',
  Object? lifecycleState = 'active',
  Object? callVersion = 3,
  Object? idempotentReplay = false,
}) {
  return <String, Object?>{
    'callId': callId,
    'participantUid': participantUid,
    'heartbeatVersion': heartbeatVersion,
    'lastHeartbeatAt': lastHeartbeatAt,
    'leaseExpiresAt': leaseExpiresAt,
    'lifecycleState': lifecycleState,
    'callVersion': callVersion,
    'idempotentReplay': idempotentReplay,
  };
}
