import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/call_v2_feature_gate.dart';
import 'package:connect_app/call_v2/call_v2_production_capabilities.dart';
import 'package:connect_app/call_v2/firebase/call_v2_callable_transport.dart';
import 'package:connect_app/call_v2/firebase/firebase_callable_call_v2_api.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('construction and isolation', () {
    test('constructor has no side effects and invokes no callable', () {
      final transport = _FakeTransport();

      FirebaseCallableCallV2Api(
        featureGate: const CallV2FeatureGate(enabled: true),
        transport: transport,
      );

      expect(transport.calls, isEmpty);
      expect(Firebase.apps, isEmpty);
    });

    test('source contains no singleton, startup, runtime, UI, or registration',
        () {
      final sources = _phase4Sources();

      for (final forbidden in <String>[
        'FirebaseFunctions.instance',
        'FirebaseFunctions.instanceFor',
        'FirebaseAuth.instance',
        'FirebaseAppCheck.instance',
        'FirebaseFirestore.instance',
        'CallV2Runtime(',
        'CallV2Harness(',
        'Navigator',
        'MaterialPageRoute',
        'runApp',
        'register',
        'serviceLocator',
        'getIt',
      ]) {
        expect(sources.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('production capability declaration remains false', () {
      expect(
          callV2NoProductionCapabilities.callableApiAdapterAvailable, isFalse);
    });
  });

  group('feature gate', () {
    test(
        'every callable method rejects while disabled with zero transport calls',
        () async {
      final transport = _FakeTransport();
      final api = FirebaseCallableCallV2Api(
        featureGate: const CallV2FeatureGate(enabled: false),
        transport: transport,
      );
      final request = <String, Object?>{
        'idempotencyKey': 'raw-secret-idempotency',
        'invalid': Object(),
      };

      for (final invoke in _allInvocations(api, request)) {
        await expectLater(
          invoke(),
          throwsA(isA<CallV2ClientError>().having(
            (error) => error.code,
            'code',
            CallV2ClientErrorCode.rejected,
          )),
        );
      }

      expect(transport.calls, isEmpty);
    });
  });

  group('callable routing', () {
    test('routes every method to the exact exported callable name', () async {
      final transport = _FakeTransport();
      final api = _enabledApi(transport);
      final request = _baseRequest();

      await api.startCallV2(request);
      await api.acceptCallV2(request);
      await api.declineCallV2(request);
      await api.cancelCallV2(request);
      await api.endCallV2(request);
      await api.reportParticipantMediaV2(request);
      await api.renewActiveCallLeaseV2(request);

      expect(transport.calls.map((call) => call.callableName), <String>[
        'startCallV2',
        'acceptCallV2',
        'declineCallV2',
        'cancelCallV2',
        'endCallV2',
        'reportParticipantMediaV2',
        'renewActiveCallLeaseV2',
      ]);
    });

    test('no arbitrary callable name can be supplied', () async {
      final transport = _FakeTransport();
      final api = _enabledApi(transport);

      await api.startCallV2(<String, Object?>{'callableName': 'deleteUsers'});

      expect(transport.calls.single.callableName, 'startCallV2');
      expect(transport.calls.single.request['callableName'], 'deleteUsers');
    });
  });

  group('request safety', () {
    test('caller map is not mutated and transport receives a defensive copy',
        () async {
      final transport = _FakeTransport();
      final api = _enabledApi(transport);
      final nested = <String, Object?>{'value': 'one'};
      final list = <Object?>[
        'a',
        <String, Object?>{'b': true}
      ];
      final request = <String, Object?>{
        'callId': 'call_a',
        'idempotencyKey': 'same-key',
        'nested': nested,
        'list': list,
      };

      await api.acceptCallV2(request);
      transport.calls.single.request['added'] = true;
      (transport.calls.single.request['nested']!
          as Map<String, Object?>)['value'] = 'changed';
      ((transport.calls.single.request['list']! as List<Object?>)[1]!
          as Map<String, Object?>)['b'] = false;

      expect(request, <String, Object?>{
        'callId': 'call_a',
        'idempotencyKey': 'same-key',
        'nested': <String, Object?>{'value': 'one'},
        'list': <Object?>[
          'a',
          <String, Object?>{'b': true},
        ],
      });
      expect(transport.calls.single.request['idempotencyKey'], 'same-key');
    });

    test('adapter adds no auth, App Check, lifecycle authority, or secrets',
        () async {
      final transport = _FakeTransport();
      final api = _enabledApi(transport);

      await api.reportParticipantMediaV2(<String, Object?>{
        'callId': 'call_a',
        'mediaState': 'joined',
        'idempotencyKey': 'media_key',
      });

      for (final key in <String>[
        'actorUid',
        'authenticatedUid',
        'uid',
        'authToken',
        'appCheckToken',
        'secret',
        'token',
        'lifecycleState',
        'version',
        'fencingToken',
        'commandId',
        'taskId',
      ]) {
        expect(transport.calls.single.request.containsKey(key), isFalse,
            reason: key);
      }
    });

    test('non JSON-compatible request values are rejected before transport',
        () async {
      final transport = _FakeTransport();
      final api = _enabledApi(transport);

      await expectLater(
        api.acceptCallV2(<String, Object?>{'bad': Object()}),
        throwsA(isA<CallV2ClientError>().having(
          (error) => error.code,
          'code',
          CallV2ClientErrorCode.invalidRequest,
        )),
      );
      await expectLater(
        api.acceptCallV2(<String, Object?>{
          'badMap': <Object?, Object?>{1: 'value'},
        }),
        throwsA(isA<CallV2ClientError>().having(
          (error) => error.code,
          'code',
          CallV2ClientErrorCode.invalidRequest,
        )),
      );
      expect(transport.calls, isEmpty);
    });
  });

  group('response normalization', () {
    test('string-key and object-typed string-key maps are returned safely',
        () async {
      final stringMap = <String, Object?>{'callId': 'call_a'};
      final objectMap = <Object?, Object?>{'callId': 'call_b'};

      expect(
          await _enabledApi(_FakeTransport(response: stringMap)).endCallV2(
            _baseRequest(),
          ),
          <String, Object?>{'callId': 'call_a'});
      expect(
          await _enabledApi(_FakeTransport(response: objectMap)).endCallV2(
            _baseRequest(),
          ),
          <String, Object?>{'callId': 'call_b'});
    });

    test('invalid keys, metadata, null, and non-map responses are unavailable',
        () async {
      for (final response in <Object?>[
        <Object?, Object?>{1: 'bad'},
        <String, Object?>{'metadata': 'provider-details'},
        null,
        'not-a-map',
      ]) {
        final api = _enabledApi(_FakeTransport(response: response));

        await expectLater(
          api.endCallV2(_baseRequest()),
          throwsA(isA<CallV2ClientError>().having(
            (error) => error.code,
            'code',
            CallV2ClientErrorCode.unavailable,
          )),
        );
      }
    });

    test('returned response copy does not mutate original response', () async {
      final raw = <String, Object?>{'callId': 'call_a'};
      final result = await _enabledApi(
        _FakeTransport(response: raw),
      ).endCallV2(_baseRequest()) as Map<String, Object?>;

      result['callId'] = 'changed';

      expect(raw, <String, Object?>{'callId': 'call_a'});
    });
  });

  group('error normalization', () {
    test('Firebase codes map to the controlled Call V2 client codes', () async {
      const expected = <String, CallV2ClientErrorCode>{
        'unauthenticated': CallV2ClientErrorCode.unauthorized,
        'permission-denied': CallV2ClientErrorCode.unauthorized,
        'failed-precondition': CallV2ClientErrorCode.rejected,
        'invalid-argument': CallV2ClientErrorCode.invalidRequest,
        'not-found': CallV2ClientErrorCode.rejected,
        'resource-exhausted': CallV2ClientErrorCode.unavailable,
        'unavailable': CallV2ClientErrorCode.unavailable,
        'deadline-exceeded': CallV2ClientErrorCode.unavailable,
        'internal': CallV2ClientErrorCode.unavailable,
        'unknown': CallV2ClientErrorCode.unavailable,
      };

      for (final entry in expected.entries) {
        final api = _enabledApi(_FakeTransport(
          error: _TestFirebaseFunctionsException(entry.key),
        ));

        await expectLater(
          api.cancelCallV2(_baseRequest()),
          throwsA(isA<CallV2ClientError>().having(
            (error) => error.code,
            'code',
            entry.value,
          )),
          reason: entry.key,
        );
      }
    });

    test('non-Firebase error maps to unavailable', () async {
      final api = _enabledApi(_FakeTransport(
        error: StateError('raw transport message'),
      ));

      await expectLater(
        api.cancelCallV2(_baseRequest()),
        throwsA(isA<CallV2ClientError>().having(
          (error) => error.code,
          'code',
          CallV2ClientErrorCode.unavailable,
        )),
      );
    });

    test('raw messages, details, request payloads, and secrets are absent',
        () async {
      final api = _enabledApi(_FakeTransport(
        error: _TestFirebaseFunctionsException(
          'internal',
          message: 'raw-secret-message',
          details: <String, Object?>{'token': 'secret-token'},
        ),
      ));

      Object? caught;
      try {
        await api.cancelCallV2(<String, Object?>{
          'idempotencyKey': 'secret-request-key',
        });
      } catch (error) {
        caught = error;
      }

      expect(caught, isA<CallV2ClientError>());
      final text = caught.toString();
      for (final forbidden in <String>[
        'raw-secret-message',
        'secret-token',
        'secret-request-key',
        'details',
        'stack',
      ]) {
        expect(text.contains(forbidden), isFalse, reason: forbidden);
      }
    });
  });

  group('retry and counts', () {
    test('success and failure each perform one transport invocation', () async {
      final successTransport = _FakeTransport();
      await _enabledApi(successTransport).startCallV2(_baseRequest());
      expect(successTransport.calls, hasLength(1));

      final failureTransport = _FakeTransport(
        error: _TestFirebaseFunctionsException('unavailable'),
      );
      await expectLater(
        _enabledApi(failureTransport).startCallV2(_baseRequest()),
        throwsA(isA<CallV2ClientError>()),
      );
      expect(failureTransport.calls, hasLength(1));
    });

    test('duplicate explicit calls preserve count and idempotency keys',
        () async {
      final transport = _FakeTransport();
      final api = _enabledApi(transport);

      await api.acceptCallV2(<String, Object?>{
        'callId': 'call_a',
        'idempotencyKey': 'first_key',
      });
      await api.acceptCallV2(<String, Object?>{
        'callId': 'call_a',
        'idempotencyKey': 'second_key',
      });

      expect(transport.calls, hasLength(2));
      expect(transport.calls[0].request['idempotencyKey'], 'first_key');
      expect(transport.calls[1].request['idempotencyKey'], 'second_key');
    });

    test('concurrent calls are not shared by the transport adapter', () async {
      final transport = _FakeTransport()..hold();
      final api = _enabledApi(transport);

      final first = api.acceptCallV2(<String, Object?>{
        'callId': 'call_a',
        'idempotencyKey': 'first_key',
      });
      final second = api.acceptCallV2(<String, Object?>{
        'callId': 'call_a',
        'idempotencyKey': 'second_key',
      });
      await Future<void>.delayed(Duration.zero);

      expect(transport.calls, hasLength(2));
      transport.release();
      await Future.wait(<Future<Object?>>[first, second]);
    });
  });

  group('production transport source boundary', () {
    test('uses injected FirebaseFunctions and contains no live access hooks',
        () {
      final source = File(
        'lib/call_v2/firebase/firebase_functions_call_v2_transport.dart',
      ).readAsStringSync();

      expect(source.contains('required FirebaseFunctions functions'), isTrue);
      expect(source.contains('_functions.httpsCallable'), isTrue);
      expect(source.contains('call<Object?>'), isTrue);
      expect(source.contains('result.data'), isTrue);

      for (final forbidden in <String>[
        'FirebaseFunctions.instance',
        'FirebaseFunctions.instanceFor',
        'FirebaseAuth',
        'FirebaseAppCheck',
        'print(',
        'debugPrint',
        'developer.log',
        'credential',
        'secret',
        'token',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });
  });
}

FirebaseCallableCallV2Api _enabledApi(_FakeTransport transport) {
  return FirebaseCallableCallV2Api(
    featureGate: const CallV2FeatureGate(enabled: true),
    transport: transport,
  );
}

Map<String, Object?> _baseRequest() {
  return <String, Object?>{
    'callId': 'call_a',
    'idempotencyKey': 'command_key',
  };
}

List<Future<Object?> Function()> _allInvocations(
  FirebaseCallableCallV2Api api,
  Map<String, Object?> request,
) {
  return <Future<Object?> Function()>[
    () => api.startCallV2(request),
    () => api.acceptCallV2(request),
    () => api.declineCallV2(request),
    () => api.cancelCallV2(request),
    () => api.endCallV2(request),
    () => api.reportParticipantMediaV2(request),
    () => api.renewActiveCallLeaseV2(request),
  ];
}

String _phase4Sources() {
  return <String>[
    'lib/call_v2/firebase/call_v2_callable_transport.dart',
    'lib/call_v2/firebase/firebase_callable_call_v2_api.dart',
    'lib/call_v2/firebase/firebase_functions_call_v2_transport.dart',
  ].map((path) => File(path).readAsStringSync()).join('\n');
}

class _FakeTransport implements CallV2CallableTransport {
  _FakeTransport({
    this.response = const <String, Object?>{'ok': true},
    this.error,
  });

  final Object? response;
  final Object? error;
  final calls = <_TransportCall>[];
  Completer<void>? _hold;

  void hold() {
    _hold = Completer<void>();
  }

  void release() {
    _hold?.complete();
  }

  @override
  Future<Object?> call(
    String callableName,
    Map<String, Object?> request,
  ) async {
    calls.add(_TransportCall(callableName, request));
    await _hold?.future;
    final error = this.error;
    if (error != null) throw error;
    return response;
  }
}

class _TransportCall {
  const _TransportCall(this.callableName, this.request);

  final String callableName;
  final Map<String, Object?> request;
}

class _TestFirebaseFunctionsException extends FirebaseFunctionsException {
  _TestFirebaseFunctionsException(
    String code, {
    String message = 'redacted-message',
    Object? details,
  }) : super(message: message, code: code, details: details);
}
