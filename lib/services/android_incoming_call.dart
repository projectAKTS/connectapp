import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import 'call_invite_signaling.dart';
import 'callkit_id.dart';

/// Android incoming-call UI for FCM call messages that arrive while the app
/// is not in the foreground.
///
/// iOS presents CallKit natively from PushKit. Android has no such path, so a
/// data-only `call_invite` push presents the `flutter_callkit_incoming`
/// full-screen ringing UI here, and a `call_end` push dismisses it. Accept
/// and decline then flow through the existing plugin-event handling in
/// NotificationService.
class AndroidIncomingCall {
  AndroidIncomingCall._();

  /// Matches the caller-side ringing timeout in CallSessionManager.
  static const Duration ringingTimeout = Duration(seconds: 45);

  /// Pushes older than this are not presented. The invite has very likely
  /// been answered, cancelled, or timed out, and the server TTL is 40 s.
  static const Duration maxPushAge = Duration(seconds: 40);

  /// Shortest ring worth presenting.
  static const Duration minRing = Duration(seconds: 5);

  static AndroidIncomingCallDecision decide(
    Map<String, dynamic> data, {
    DateTime? sentTime,
    required DateTime now,
  }) {
    final type = '${data['type'] ?? data['action'] ?? ''}'.trim();
    final channel = '${data['channel'] ?? ''}'.trim();
    final inviteId = '${data['callId'] ?? data['inviteId'] ?? channel}'.trim();
    if (inviteId.isEmpty && channel.isEmpty) {
      return const AndroidIncomingCallDecision.ignore('missing_identity');
    }
    final callkitId = normalizeCallkitId(rawId: inviteId, fallback: channel);

    if (type == 'call_end') {
      return AndroidIncomingCallDecision.end(callkitId: callkitId);
    }
    if (type != 'call_invite' && type != 'incoming_call') {
      return const AndroidIncomingCallDecision.ignore('not_a_call');
    }
    if (channel.isEmpty) {
      return const AndroidIncomingCallDecision.ignore('missing_channel');
    }

    final age = sentTime == null ? Duration.zero : now.difference(sentTime);
    if (age > maxPushAge) {
      return const AndroidIncomingCallDecision.ignore('stale_push');
    }
    // A negative age means device clock skew; ring for the full timeout.
    final ring = ringingTimeout - (age.isNegative ? Duration.zero : age);
    if (ring < minRing) {
      return const AndroidIncomingCallDecision.ignore('stale_push');
    }

    final isVideo = '${data['isVideo'] ?? ''}'.trim().toLowerCase() == 'true';
    final rawName = '${data['fromName'] ?? ''}'.trim();
    final fromName = rawName.isEmpty ? 'Caller' : rawName;
    return AndroidIncomingCallDecision.present(
      callkitId: callkitId,
      params: CallKitParams(
        id: callkitId,
        nameCaller: fromName,
        appName: 'Helperly',
        handle: isVideo ? 'Video call' : 'Audio call',
        type: isVideo ? 1 : 0,
        duration: ring.inMilliseconds,
        textAccept: 'Accept',
        textDecline: 'Decline',
        missedCallNotification: const NotificationParams(
          showNotification: false,
        ),
        extra: <String, dynamic>{
          'inviteId': inviteId,
          'callId': inviteId,
          'callkitId': callkitId,
          'channel': channel,
          'fromName': fromName,
          'fromUid': '${data['fromUid'] ?? ''}'.trim(),
          'isVideo': '$isVideo',
        },
        android: const AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          ringtonePath: 'system_ringtone_default',
          backgroundColor: '#0E4A42',
          actionColor: '#4CAF50',
          textColor: '#ffffff',
          incomingCallNotificationChannelName: 'Incoming calls',
          isShowFullLockedScreen: true,
          isImportant: true,
        ),
      ),
    );
  }

  /// Background isolate only. When the app is not running, the plugin sends
  /// a Decline tap to this background engine, where no NotificationService
  /// listens, so the caller would ring until timeout. While this call rings,
  /// report its decline over HTTPS. Accept is left to the app, which the
  /// plugin launches and which resumes the accept from `activeCalls()`.
  ///
  /// Callers must not await this: it outlives the push handler by design.
  static Future<void> relayBackgroundDecline(
    AndroidIncomingCallDecision decision, {
    Stream<CallEvent?>? events,
    CallInviteSignaling? signaling,
  }) async {
    final params = decision.params;
    if (decision.kind != AndroidIncomingCallDecisionKind.present ||
        params == null) {
      return;
    }
    final inviteId = '${params.extra?['inviteId'] ?? ''}'.trim();
    if (inviteId.isEmpty) return;
    final window = Duration(milliseconds: params.duration ?? 0) +
        const Duration(seconds: 5);
    try {
      final outcome = await (events ?? FlutterCallkitIncoming.onEvent)
          .where((event) => _eventCallkitId(event) == decision.callkitId)
          .map((event) => event!.event)
          .firstWhere(
            (event) =>
                event == Event.actionCallDecline ||
                event == Event.actionCallAccept ||
                event == Event.actionCallEnded ||
                event == Event.actionCallTimeout,
          )
          .timeout(window);
      if (outcome != Event.actionCallDecline) return;
      await (signaling ?? FirebaseCallInviteSignaling())
          .transition('decline', <String, Object?>{
        'inviteId': inviteId,
        'endReason': 'callkit_decline',
      });
    } catch (_) {
      // Timeout or stream end: the caller-side timeout still applies.
    }
  }

  static String _eventCallkitId(CallEvent? event) {
    final body = event?.body;
    if (body is! Map) return '';
    return '${body['id'] ?? ''}'.trim().toLowerCase();
  }

  /// Applies a decision. It never throws: a background isolate must not
  /// crash on a malformed push.
  static Future<void> apply(AndroidIncomingCallDecision decision) async {
    try {
      switch (decision.kind) {
        case AndroidIncomingCallDecisionKind.present:
          await FlutterCallkitIncoming.showCallkitIncoming(decision.params!);
        case AndroidIncomingCallDecisionKind.end:
          await FlutterCallkitIncoming.endCall(decision.callkitId);
        case AndroidIncomingCallDecisionKind.ignore:
          break;
      }
    } catch (e) {
      debugPrint('[DIAG][android_call] apply_failed kind=${decision.kind.name} '
          'error=$e');
    }
  }
}

enum AndroidIncomingCallDecisionKind { present, end, ignore }

@immutable
class AndroidIncomingCallDecision {
  const AndroidIncomingCallDecision.present({
    required this.callkitId,
    required CallKitParams this.params,
  })  : kind = AndroidIncomingCallDecisionKind.present,
        reason = '';

  const AndroidIncomingCallDecision.end({required this.callkitId})
      : kind = AndroidIncomingCallDecisionKind.end,
        params = null,
        reason = '';

  const AndroidIncomingCallDecision.ignore(this.reason)
      : kind = AndroidIncomingCallDecisionKind.ignore,
        callkitId = '',
        params = null;

  final AndroidIncomingCallDecisionKind kind;
  final String callkitId;
  final CallKitParams? params;
  final String reason;
}
