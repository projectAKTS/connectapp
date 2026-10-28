import 'dart:async';

import 'package:connect_app/services/android_incoming_call.dart';
import 'package:connect_app/services/call_invite_signaling.dart';
import 'package:connect_app/services/callkit_id.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingSignaling implements CallInviteSignaling {
  final List<List<Object?>> calls = <List<Object?>>[];

  @override
  Future<Map<String, dynamic>?> transition(
    String action,
    Map<String, Object?> data,
  ) async {
    calls.add(<Object?>[action, data]);
    return <String, dynamic>{'applied': true};
  }
}

void main() {
  final now = DateTime.utc(2026, 10, 27, 12);

  Map<String, dynamic> invite({
    String type = 'call_invite',
    String callId = 'PAXoGiInvite',
    String channel = 'c_channel',
    String isVideo = 'false',
    String fromName = 'Baris',
  }) =>
      <String, dynamic>{
        'type': type,
        'callId': callId,
        'channel': channel,
        'isVideo': isVideo,
        'fromName': fromName,
        'fromUid': 'caller_uid',
        'toUid': 'callee_uid',
      };

  test('a fresh call invite presents the full-screen UI with invite identity',
      () {
    final decision = AndroidIncomingCall.decide(
      invite(),
      sentTime: now.subtract(const Duration(seconds: 2)),
      now: now,
    );
    expect(decision.kind, AndroidIncomingCallDecisionKind.present);
    final expectedId =
        normalizeCallkitId(rawId: 'PAXoGiInvite', fallback: 'c_channel');
    expect(decision.callkitId, expectedId);
    final params = decision.params!;
    expect(params.id, expectedId);
    expect(params.nameCaller, 'Baris');
    expect(params.type, 0);
    expect(params.duration, const Duration(seconds: 43).inMilliseconds);
    expect(params.extra, <String, dynamic>{
      'inviteId': 'PAXoGiInvite',
      'callId': 'PAXoGiInvite',
      'callkitId': expectedId,
      'channel': 'c_channel',
      'fromName': 'Baris',
      'fromUid': 'caller_uid',
      'isVideo': 'false',
    });
    expect(params.android!.isShowFullLockedScreen, isTrue);
    expect(params.missedCallNotification!.showNotification, isFalse);
  });

  test('video invites present as video calls', () {
    final decision =
        AndroidIncomingCall.decide(invite(isVideo: 'true'), now: now);
    expect(decision.params!.type, 1);
    expect(decision.params!.extra!['isVideo'], 'true');
  });

  test('stale pushes are not presented', () {
    for (final age in const [Duration(seconds: 41), Duration(minutes: 5)]) {
      final decision = AndroidIncomingCall.decide(
        invite(),
        sentTime: now.subtract(age),
        now: now,
      );
      expect(decision.kind, AndroidIncomingCallDecisionKind.ignore,
          reason: 'age $age');
      expect(decision.reason, 'stale_push');
    }
  });

  test('clock skew into the future rings for the full timeout', () {
    final decision = AndroidIncomingCall.decide(
      invite(),
      sentTime: now.add(const Duration(seconds: 30)),
      now: now,
    );
    expect(decision.kind, AndroidIncomingCallDecisionKind.present);
    expect(decision.params!.duration,
        AndroidIncomingCall.ringingTimeout.inMilliseconds);
  });

  test('call_end dismisses the same CallKit identity the invite used', () {
    final presented = AndroidIncomingCall.decide(invite(), now: now);
    final ended =
        AndroidIncomingCall.decide(invite(type: 'call_end'), now: now);
    expect(ended.kind, AndroidIncomingCallDecisionKind.end);
    expect(ended.callkitId, presented.callkitId);
  });

  test('malformed and non-call messages are ignored', () {
    expect(
      AndroidIncomingCall.decide(<String, dynamic>{'type': 'chat'}, now: now)
          .kind,
      AndroidIncomingCallDecisionKind.ignore,
    );
    expect(
      AndroidIncomingCall.decide(
        invite(callId: '', channel: ''),
        now: now,
      ).reason,
      'missing_identity',
    );
    expect(
      AndroidIncomingCall.decide(
        <String, dynamic>{'type': 'call_invite', 'callId': 'x'},
        now: now,
      ).reason,
      'missing_channel',
    );
    expect(
      AndroidIncomingCall.decide(invite(type: 'chat_message'), now: now).reason,
      'not_a_call',
    );
  });

  group('relayBackgroundDecline', () {
    CallEvent eventFor(String callkitId, Event kind) =>
        CallEvent(<String, dynamic>{'id': callkitId}, kind);

    test('a decline of this call is reported over HTTPS once', () async {
      final decision = AndroidIncomingCall.decide(invite(), now: now);
      final signaling = _RecordingSignaling();
      final events = StreamController<CallEvent?>();
      final relay = AndroidIncomingCall.relayBackgroundDecline(
        decision,
        events: events.stream,
        signaling: signaling,
      );
      events
        ..add(eventFor('other-call', Event.actionCallDecline))
        ..add(eventFor(decision.callkitId, Event.actionCallIncoming))
        ..add(eventFor(decision.callkitId, Event.actionCallDecline));
      await relay;
      await events.close();
      expect(signaling.calls, <List<Object?>>[
        <Object?>[
          'decline',
          <String, Object?>{
            'inviteId': 'PAXoGiInvite',
            'endReason': 'callkit_decline',
          },
        ],
      ]);
    });

    test('accept, end, or another call never declines', () async {
      for (final kind in const [
        Event.actionCallAccept,
        Event.actionCallEnded,
        Event.actionCallTimeout,
      ]) {
        final decision = AndroidIncomingCall.decide(invite(), now: now);
        final signaling = _RecordingSignaling();
        final events = StreamController<CallEvent?>();
        final relay = AndroidIncomingCall.relayBackgroundDecline(
          decision,
          events: events.stream,
          signaling: signaling,
        );
        events.add(eventFor(decision.callkitId, kind));
        await relay;
        await events.close();
        expect(signaling.calls, isEmpty, reason: '$kind');
      }
    });

    test('non-present decisions return immediately', () async {
      final signaling = _RecordingSignaling();
      await AndroidIncomingCall.relayBackgroundDecline(
        AndroidIncomingCall.decide(invite(type: 'call_end'), now: now),
        events: const Stream<CallEvent?>.empty(),
        signaling: signaling,
      );
      expect(signaling.calls, isEmpty);
    });
  });

  test('answered_elsewhere ends the call UI except on the answering device',
      () {
    final presented = AndroidIncomingCall.decide(invite(), now: now);
    Map<String, dynamic> elsewhere(String answering) => <String, dynamic>{
          ...invite(type: 'call_end'),
          'status': AndroidIncomingCall.answeredElsewhereStatus,
          'acceptedInstallationId': answering,
        };

    final other = AndroidIncomingCall.decide(
      elsewhere('phone_installation_1'),
      now: now,
      ownInstallationId: 'tablet_installation_2',
    );
    expect(other.kind, AndroidIncomingCallDecisionKind.end);
    expect(other.callkitId, presented.callkitId);

    final here = AndroidIncomingCall.decide(
      elsewhere('tablet_installation_2'),
      now: now,
      ownInstallationId: 'tablet_installation_2',
    );
    expect(here.kind, AndroidIncomingCallDecisionKind.ignore);
    expect(here.reason, 'answered_here');

    final terminal = AndroidIncomingCall.decide(
      <String, dynamic>{
        ...invite(type: 'call_end'),
        'status': 'ended',
        'acceptedInstallationId': 'tablet_installation_2',
      },
      now: now,
      ownInstallationId: 'tablet_installation_2',
    );
    expect(terminal.kind, AndroidIncomingCallDecisionKind.end,
        reason: 'real terminal ends always end the call UI');
  });

  test('a missing caller name falls back to Caller', () {
    final decision =
        AndroidIncomingCall.decide(invite(fromName: '  '), now: now);
    expect(decision.params!.nameCaller, 'Caller');
  });
}
