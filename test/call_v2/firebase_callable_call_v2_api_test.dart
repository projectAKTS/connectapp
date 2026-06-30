import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/call_v2_feature_gate.dart';
import 'package:connect_app/call_v2/call_v2_harness.dart';
import 'package:connect_app/call_v2/domain/call_snapshot.dart';
import 'package:connect_app/call_v2/domain/participant_media_state.dart';
import 'package:connect_app/call_v2/firebase_callable_call_v2_api.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('constructor performs no invocation', () {
    final recorder = _InvocationRecorder();

    FirebaseCallableCallV2Api(invoke: recorder.invoke);

    expect(recorder.calls, isEmpty);
  });

  test('routes every command to the exact callable name', () async {
    final recorder = _InvocationRecorder();
    final api = CallV2Api(FirebaseCallableCallV2Api(invoke: recorder.invoke));

    await api.startCallV2(_startRequest());
    await api.acceptCallV2(_lifecycleRequest());
    await api.declineCallV2(_lifecycleRequest());
    await api.cancelCallV2(_lifecycleRequest());
    await api.endCallV2(_lifecycleRequest());
    await api.reportParticipantMediaV2(_mediaRequest());
    await api.renewActiveCallLeaseV2(_leaseRequest());

    expect(recorder.calls.map((call) => call.functionName), <String>[
      'startCallV2',
      'acceptCallV2',
      'declineCallV2',
      'cancelCallV2',
      'endCallV2',
      'reportParticipantMediaV2',
      'renewActiveCallLeaseV2',
    ]);
  });

  test('serializes exact authoritative payload shapes', () async {
    final recorder = _InvocationRecorder();
    final api = CallV2Api(FirebaseCallableCallV2Api(invoke: recorder.invoke));

    await api.startCallV2(_startRequest());
    await api.acceptCallV2(_lifecycleRequest());
    await api.reportParticipantMediaV2(_mediaRequest());
    await api.renewActiveCallLeaseV2(_leaseRequest());

    expect(recorder.calls[0].data, <String, Object?>{
      'calleeUid': 'callee',
      'isVideo': true,
      'idempotencyKey': 'start_key',
    });
    expect(recorder.calls[1].data, <String, Object?>{
      'callId': 'call_a',
      'idempotencyKey': 'command_key',
    });
    expect(recorder.calls[2].data, <String, Object?>{
      'callId': 'call_a',
      'mediaState': 'joined',
      'idempotencyKey': 'media_key',
    });
    expect(recorder.calls[3].data, <String, Object?>{
      'callId': 'call_a',
      'heartbeatVersion': 2,
      'idempotencyKey': 'lease_key',
    });
  });

  test('command payloads exclude client identity and private fields', () async {
    final recorder = _InvocationRecorder();
    final api = CallV2Api(FirebaseCallableCallV2Api(invoke: recorder.invoke));

    await api.startCallV2(_startRequest());
    await api.acceptCallV2(_lifecycleRequest());
    await api.reportParticipantMediaV2(_mediaRequest());
    await api.renewActiveCallLeaseV2(_leaseRequest());

    for (final call in recorder.calls) {
      for (final key in _forbiddenPayloadKeys) {
        expect(call.data.containsKey(key), isFalse, reason: '$key in $call');
      }
      if (call.functionName != 'startCallV2') {
        expect(call.data.containsKey('calleeUid'), isFalse);
      }
      if (call.functionName != 'renewActiveCallLeaseV2') {
        expect(call.data.containsKey('heartbeatVersion'), isFalse);
      }
    }
  });

  test('maps every participant media enum to the backend string', () async {
    const expected = <ParticipantMediaState, String>{
      ParticipantMediaState.notJoined: 'not_joined',
      ParticipantMediaState.preparing: 'preparing',
      ParticipantMediaState.joining: 'joining',
      ParticipantMediaState.joined: 'joined',
      ParticipantMediaState.reconnecting: 'reconnecting',
      ParticipantMediaState.disconnected: 'disconnected',
      ParticipantMediaState.left: 'left',
      ParticipantMediaState.mediaFailed: 'media_failed',
    };

    for (final entry in expected.entries) {
      final recorder = _InvocationRecorder();
      final api = CallV2Api(FirebaseCallableCallV2Api(
        invoke: recorder.invoke,
      ));

      await api.reportParticipantMediaV2(CallV2MediaReportRequest(
        callId: 'call_a',
        mediaState: entry.key,
        idempotencyKey: 'media_key',
      ));

      expect(recorder.calls.single.data['mediaState'], entry.value);
    }
  });

  test('normalizes Firebase callable errors to the small client contract',
      () async {
    const expected = <String, CallV2ClientErrorCode>{
      'unauthenticated': CallV2ClientErrorCode.unauthorized,
      'permission-denied': CallV2ClientErrorCode.unauthorized,
      'invalid-argument': CallV2ClientErrorCode.invalidRequest,
      'failed-precondition': CallV2ClientErrorCode.rejected,
      'not-found': CallV2ClientErrorCode.rejected,
      'already-exists': CallV2ClientErrorCode.rejected,
      'aborted': CallV2ClientErrorCode.rejected,
      'out-of-range': CallV2ClientErrorCode.rejected,
      'deadline-exceeded': CallV2ClientErrorCode.unavailable,
      'unavailable': CallV2ClientErrorCode.unavailable,
      'internal': CallV2ClientErrorCode.unavailable,
      'unknown': CallV2ClientErrorCode.unavailable,
      'resource-exhausted': CallV2ClientErrorCode.unavailable,
      'data-loss': CallV2ClientErrorCode.unavailable,
    };

    for (final entry in expected.entries) {
      final api = CallV2Api(FirebaseCallableCallV2Api(
        invoke: (_, __) => throw _TestFirebaseFunctionsException(entry.key),
      ));

      await expectLater(
        api.acceptCallV2(_lifecycleRequest()),
        throwsA(isA<CallV2ClientError>().having(
          (error) => error.code,
          'code',
          entry.value,
        )),
        reason: entry.key,
      );
    }
  });

  test('normalizes unknown exceptions and preserves controlled errors',
      () async {
    final unknownApi = CallV2Api(FirebaseCallableCallV2Api(
      invoke: (_, __) => throw StateError('provider details'),
    ));

    await expectLater(
      unknownApi.acceptCallV2(_lifecycleRequest()),
      throwsA(isA<CallV2ClientError>().having(
        (error) => error.code,
        'code',
        CallV2ClientErrorCode.unavailable,
      )),
    );

    final controlledApi = CallV2Api(_ControlledErrorTransport());
    await expectLater(
      controlledApi.acceptCallV2(_lifecycleRequest()),
      throwsA(isA<CallV2ClientError>().having(
        (error) => error.code,
        'code',
        CallV2ClientErrorCode.rejected,
      )),
    );
  });

  test('rejects invalid local request values before invocation', () async {
    final recorder = _InvocationRecorder();
    final api = CallV2Api(FirebaseCallableCallV2Api(invoke: recorder.invoke));

    await expectLater(
      api.acceptCallV2(const CallV2LifecycleCommandRequest(
        callId: ' call_a',
        idempotencyKey: 'command_key',
      )),
      throwsA(isA<CallV2ClientError>().having(
        (error) => error.code,
        'code',
        CallV2ClientErrorCode.invalidRequest,
      )),
    );
    await expectLater(
      api.acceptCallV2(const CallV2LifecycleCommandRequest(
        callId: 'calls/call_a',
        idempotencyKey: 'command_key',
      )),
      throwsA(isA<CallV2ClientError>().having(
        (error) => error.code,
        'code',
        CallV2ClientErrorCode.invalidRequest,
      )),
    );
    await expectLater(
      api.renewActiveCallLeaseV2(const CallV2LeaseRenewalRequest(
        callId: 'call_a',
        heartbeatVersion: 0,
        idempotencyKey: 'lease_key',
      )),
      throwsA(isA<CallV2ClientError>().having(
        (error) => error.code,
        'code',
        CallV2ClientErrorCode.invalidRequest,
      )),
    );
    await expectLater(
      api.startCallV2(StartCallV2Request(
        calleeUid: 'c' * 161,
        isVideo: true,
        idempotencyKey: 'start_key',
      )),
      throwsA(isA<CallV2ClientError>().having(
        (error) => error.code,
        'code',
        CallV2ClientErrorCode.invalidRequest,
      )),
    );

    expect(recorder.calls, isEmpty);
  });

  test('disabled feature gate produces no callable invocation', () async {
    final recorder = _InvocationRecorder();
    final harness = CallV2Harness(
      featureGate: const CallV2FeatureGate(enabled: false),
      api: CallV2Api(FirebaseCallableCallV2Api(invoke: recorder.invoke)),
      localParticipantRole: () => CallParticipantRole.callee,
    );

    await harness.startCall(_startRequest());
    await harness.acceptCall(_lifecycleRequest());
    await harness.reportMedia(_mediaRequest());
    await harness.renewLease(_leaseRequest());

    expect(recorder.calls, isEmpty);
  });

  test('duplicate in-flight harness taps keep one stable idempotency key',
      () async {
    final recorder = _InvocationRecorder();
    final api = CallV2Api(FirebaseCallableCallV2Api(invoke: recorder.invoke));
    final harness = CallV2Harness(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: api,
      localParticipantRole: () => CallParticipantRole.callee,
    );
    recorder.hold('acceptCallV2');

    final first = harness.acceptCall(const CallV2LifecycleCommandRequest(
      callId: 'call_a',
      idempotencyKey: 'first_key',
    ));
    final second = harness.acceptCall(const CallV2LifecycleCommandRequest(
      callId: 'call_a',
      idempotencyKey: 'second_key',
    ));
    await Future<void>.delayed(Duration.zero);

    expect(recorder.calls, hasLength(1));
    expect(recorder.calls.single.data, <String, Object?>{
      'callId': 'call_a',
      'idempotencyKey': 'first_key',
    });

    recorder.release('acceptCallV2');
    await Future.wait(<Future<void>>[first, second]);
  });

  test('uses injected fake callable only and initializes no Firebase app', () {
    final source = File(
      'lib/call_v2/firebase_callable_call_v2_api.dart',
    ).readAsStringSync();

    for (final forbidden in <String>[
      'FirebaseFunctions.instance',
      'FirebaseFunctions.instanceFor',
      'FirebaseAuth.instance',
      'FirebaseAppCheck.instance',
      'FirebaseFirestore.instance',
      '.collection(',
      '.snapshots(',
      '.get(',
      '.set(',
      '.update(',
      '.delete(',
      'callOps',
      'activeCallLocks',
      'taskOutbox',
      'commands',
    ]) {
      expect(source.contains(forbidden), isFalse, reason: forbidden);
    }
    expect(Firebase.apps, isEmpty);
  });
}

const _forbiddenPayloadKeys = <String>{
  'actorUid',
  'authenticatedUid',
  'uid',
  'callerUid',
  'version',
  'mediaVersion',
  'staff',
  'rolloutMode',
  'percentage',
  'salt',
  'allowlist',
  'cohort',
  'fencingToken',
  'lockClaim',
  'taskId',
  'commandId',
};

StartCallV2Request _startRequest() {
  return const StartCallV2Request(
    calleeUid: 'callee',
    isVideo: true,
    idempotencyKey: 'start_key',
  );
}

CallV2LifecycleCommandRequest _lifecycleRequest() {
  return const CallV2LifecycleCommandRequest(
    callId: 'call_a',
    idempotencyKey: 'command_key',
  );
}

CallV2MediaReportRequest _mediaRequest() {
  return const CallV2MediaReportRequest(
    callId: 'call_a',
    mediaState: ParticipantMediaState.joined,
    idempotencyKey: 'media_key',
  );
}

CallV2LeaseRenewalRequest _leaseRequest() {
  return const CallV2LeaseRenewalRequest(
    callId: 'call_a',
    heartbeatVersion: 2,
    idempotencyKey: 'lease_key',
  );
}

class _InvocationRecorder {
  final calls = <_InvocationCall>[];
  final _held = <String, Completer<void>>{};

  void hold(String functionName) {
    _held[functionName] = Completer<void>();
  }

  void release(String functionName) {
    _held.remove(functionName)?.complete();
  }

  Future<Object?> invoke(String functionName, Map<String, Object?> data) async {
    calls.add(_InvocationCall(functionName, Map<String, Object?>.of(data)));
    await _held[functionName]?.future;
    return null;
  }
}

class _InvocationCall {
  const _InvocationCall(this.functionName, this.data);

  final String functionName;
  final Map<String, Object?> data;

  @override
  String toString() => '$functionName $data';
}

class _ControlledErrorTransport implements CallableCallV2Api {
  @override
  Future<void> acceptCallV2(Map<String, Object?> request) {
    throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
  }

  @override
  Future<void> cancelCallV2(Map<String, Object?> request) async {}

  @override
  Future<void> declineCallV2(Map<String, Object?> request) async {}

  @override
  Future<void> endCallV2(Map<String, Object?> request) async {}

  @override
  Future<void> renewActiveCallLeaseV2(Map<String, Object?> request) async {}

  @override
  Future<void> reportParticipantMediaV2(Map<String, Object?> request) async {}

  @override
  Future<void> startCallV2(Map<String, Object?> request) async {}
}

class _TestFirebaseFunctionsException extends FirebaseFunctionsException {
  _TestFirebaseFunctionsException(String code)
      : super(message: 'redacted', code: code);
}
