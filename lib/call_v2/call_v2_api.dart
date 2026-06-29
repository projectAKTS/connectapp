import 'domain/participant_media_state.dart';

class CallV2RequestContext {
  const CallV2RequestContext({
    required this.callId,
    required this.version,
  });

  final String callId;
  final int version;
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

enum CallV2ClientErrorCode {
  unavailable,
  rejected,
  unauthorized,
  invalidRequest,
}

class CallV2ClientError implements Exception {
  const CallV2ClientError(this.code);

  final CallV2ClientErrorCode code;

  @override
  String toString() => 'CallV2ClientError(code: $code)';
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
    required ParticipantMediaState mediaState,
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
    };
  }

  Future<void> _normalize(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
  }
}
