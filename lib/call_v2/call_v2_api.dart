import 'call_v2_callable_results.dart';
import 'domain/participant_media_state.dart';

class StartCallV2Request {
  const StartCallV2Request({
    required this.calleeUid,
    required this.isVideo,
    required this.idempotencyKey,
  });

  final String calleeUid;
  final bool isVideo;
  final String idempotencyKey;
}

class CallV2LifecycleCommandRequest {
  const CallV2LifecycleCommandRequest({
    required this.callId,
    required this.idempotencyKey,
  });

  final String callId;
  final String idempotencyKey;
}

class CallV2MediaReportRequest {
  const CallV2MediaReportRequest({
    required this.callId,
    required this.mediaState,
    required this.idempotencyKey,
  });

  final String callId;
  final ParticipantMediaState mediaState;
  final String idempotencyKey;
}

class CallV2LeaseRenewalRequest {
  const CallV2LeaseRenewalRequest({
    required this.callId,
    required this.heartbeatVersion,
    required this.idempotencyKey,
  });

  final String callId;
  final int heartbeatVersion;
  final String idempotencyKey;
}

abstract interface class CallableCallV2Api {
  Future<Object?> startCallV2(Map<String, Object?> request);
  Future<Object?> acceptCallV2(Map<String, Object?> request);
  Future<Object?> declineCallV2(Map<String, Object?> request);
  Future<Object?> cancelCallV2(Map<String, Object?> request);
  Future<Object?> endCallV2(Map<String, Object?> request);
  Future<Object?> reportParticipantMediaV2(Map<String, Object?> request);
  Future<Object?> renewActiveCallLeaseV2(Map<String, Object?> request);
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

  Future<StartCallV2Result> startCallV2(StartCallV2Request request) {
    return _invokeAndParse(
      () => _transport.startCallV2(_startRequest(request)),
      StartCallV2Result.fromCallableResult,
    );
  }

  Future<CallV2LifecycleCommandResult> acceptCallV2(
    CallV2LifecycleCommandRequest request,
  ) {
    return _invokeAndParse(
      () => _transport.acceptCallV2(_lifecycleRequest(request)),
      CallV2LifecycleCommandResult.fromCallableResult,
    );
  }

  Future<CallV2LifecycleCommandResult> declineCallV2(
    CallV2LifecycleCommandRequest request,
  ) {
    return _invokeAndParse(
      () => _transport.declineCallV2(_lifecycleRequest(request)),
      CallV2LifecycleCommandResult.fromCallableResult,
    );
  }

  Future<CallV2LifecycleCommandResult> cancelCallV2(
    CallV2LifecycleCommandRequest request,
  ) {
    return _invokeAndParse(
      () => _transport.cancelCallV2(_lifecycleRequest(request)),
      CallV2LifecycleCommandResult.fromCallableResult,
    );
  }

  Future<CallV2LifecycleCommandResult> endCallV2(
    CallV2LifecycleCommandRequest request,
  ) {
    return _invokeAndParse(
      () => _transport.endCallV2(_lifecycleRequest(request)),
      CallV2LifecycleCommandResult.fromCallableResult,
    );
  }

  Future<CallV2MediaReportResult> reportParticipantMediaV2(
    CallV2MediaReportRequest request,
  ) {
    return _invokeAndParse(
      () => _transport.reportParticipantMediaV2({
        'callId': _validatedIdentifier(request.callId),
        'mediaState': _backendMediaStateName(request.mediaState),
        'idempotencyKey': _validatedIdentifier(
          request.idempotencyKey,
        ),
      }),
      CallV2MediaReportResult.fromCallableResult,
    );
  }

  Future<CallV2LeaseRenewalResult> renewActiveCallLeaseV2(
    CallV2LeaseRenewalRequest request,
  ) {
    return _invokeAndParse(
      () => _transport.renewActiveCallLeaseV2({
        'callId': _validatedIdentifier(request.callId),
        'heartbeatVersion': _validatedHeartbeatVersion(
          request.heartbeatVersion,
        ),
        'idempotencyKey': _validatedIdentifier(
          request.idempotencyKey,
        ),
      }),
      CallV2LeaseRenewalResult.fromCallableResult,
    );
  }

  Map<String, Object?> _startRequest(StartCallV2Request request) {
    return <String, Object?>{
      'calleeUid': _validatedIdentifier(request.calleeUid),
      'isVideo': request.isVideo,
      'idempotencyKey': _validatedIdentifier(
        request.idempotencyKey,
      ),
    };
  }

  Map<String, Object?> _lifecycleRequest(
    CallV2LifecycleCommandRequest request,
  ) {
    return <String, Object?>{
      'callId': _validatedIdentifier(request.callId),
      'idempotencyKey': _validatedIdentifier(
        request.idempotencyKey,
      ),
    };
  }

  Future<T> _invokeAndParse<T>(
    Future<Object?> Function() action,
    T Function(Object? raw) parse,
  ) async {
    final Object? raw;
    try {
      raw = await action();
    } on CallV2ClientError {
      rethrow;
    } catch (_) {
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
    try {
      return parse(raw);
    } catch (_) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
  }

  String _validatedIdentifier(String value) {
    if (value.isEmpty ||
        value.trim() != value ||
        value.length > callV2MaxCallableIdentifierLength ||
        value.contains('/')) {
      throw CallV2ClientError(CallV2ClientErrorCode.invalidRequest);
    }
    return value;
  }

  int _validatedHeartbeatVersion(int value) {
    if (value <= 0 || value > callV2MaxSafeInteger) {
      throw const CallV2ClientError(CallV2ClientErrorCode.invalidRequest);
    }
    return value;
  }

  String _backendMediaStateName(ParticipantMediaState state) {
    switch (state) {
      case ParticipantMediaState.notJoined:
        return 'not_joined';
      case ParticipantMediaState.preparing:
        return 'preparing';
      case ParticipantMediaState.joining:
        return 'joining';
      case ParticipantMediaState.joined:
        return 'joined';
      case ParticipantMediaState.reconnecting:
        return 'reconnecting';
      case ParticipantMediaState.disconnected:
        return 'disconnected';
      case ParticipantMediaState.left:
        return 'left';
      case ParticipantMediaState.mediaFailed:
        return 'media_failed';
    }
  }
}
