import 'domain/call_v2_models.dart';

class CallV2RequestContext {
  const CallV2RequestContext({
    required this.callId,
    required this.version,
    required this.actorUid,
    required this.participantRole,
  });

  final String callId;
  final int version;
  final String actorUid;
  final CallV2ParticipantRole participantRole;
}

abstract interface class CallableCallV2Api {
  Future<void> startCallV2(Map<String, Object?> request);
  Future<void> acceptCallV2(Map<String, Object?> request);
  Future<void> declineCallV2(Map<String, Object?> request);
  Future<void> cancelCallV2(Map<String, Object?> request);
  Future<void> endCallV2(Map<String, Object?> request);
  Future<void> reportParticipantMediaV2(Map<String, Object?> request);
  Future<void> renewActiveCallLeaseV2(Map<String, Object?> request);
}

class CallV2ClientError implements Exception {
  const CallV2ClientError(this.message);

  final String message;

  @override
  String toString() => 'CallV2ClientError: $message';
}

class CallV2Api {
  const CallV2Api(this._transport);

  final CallableCallV2Api _transport;

  Future<void> startCallV2(CallV2RequestContext context) {
    return _normalize(() => _transport.startCallV2(_baseRequest(context)));
  }

  Future<void> acceptCallV2(CallV2RequestContext context) {
    return _normalize(() => _transport.acceptCallV2(_baseRequest(context)));
  }

  Future<void> declineCallV2(CallV2RequestContext context) {
    return _normalize(() => _transport.declineCallV2(_baseRequest(context)));
  }

  Future<void> cancelCallV2(CallV2RequestContext context) {
    return _normalize(() => _transport.cancelCallV2(_baseRequest(context)));
  }

  Future<void> endCallV2(CallV2RequestContext context) {
    return _normalize(() => _transport.endCallV2(_baseRequest(context)));
  }

  Future<void> reportParticipantMediaV2(
    CallV2RequestContext context, {
    required CallV2ParticipantMediaState mediaState,
    required int mediaVersion,
  }) {
    return _normalize(
      () => _transport.reportParticipantMediaV2({
        ..._baseRequest(context),
        'mediaState': mediaState.name,
        'mediaVersion': mediaVersion,
      }),
    );
  }

  Future<void> renewActiveCallLeaseV2(CallV2RequestContext context) {
    return _normalize(
      () => _transport.renewActiveCallLeaseV2(_baseRequest(context)),
    );
  }

  Map<String, Object?> _baseRequest(CallV2RequestContext context) {
    return <String, Object?>{
      'callId': context.callId,
      'version': context.version,
      'actorUid': context.actorUid,
      'participantRole': context.participantRole.name,
    };
  }

  Future<void> _normalize(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      throw const CallV2ClientError('Call V2 request failed');
    }
  }
}
