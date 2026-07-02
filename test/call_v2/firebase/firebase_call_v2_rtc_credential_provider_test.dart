import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/call_v2_feature_gate.dart';
import 'package:connect_app/call_v2/call_v2_production_capabilities.dart';
import 'package:connect_app/call_v2/firebase/call_v2_callable_transport.dart';
import 'package:connect_app/call_v2/firebase/firebase_call_v2_rtc_credential_provider.dart';
import 'package:connect_app/call_v2/rtc/call_v2_rtc_config_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('construction and isolation', () {
    test('constructor has no side effects and invokes no callable', () {
      final transport = _FakeTransport();

      FirebaseCallV2RtcCredentialProvider(
        featureGate: const CallV2FeatureGate(enabled: true),
        transport: transport,
      );

      expect(transport.calls, isEmpty);
      expect(Firebase.apps, isEmpty);
    });

    test(
        'source contains no singleton, startup, runtime, UI, RTC SDK, or writes',
        () {
      final sources = _phase4Sources();

      for (final forbidden in <String>[
        'FirebaseFunctions.instance',
        'FirebaseFunctions.instanceFor',
        'FirebaseFirestore.instance',
        'FirebaseAuth.instance',
        'FirebaseAppCheck.instance',
        'Agora',
        'RtcEngine',
        'CallV2Runtime(',
        'CallV2Harness(',
        'Navigator',
        'MaterialPageRoute',
        'runApp',
        'register',
        'serviceLocator',
        'getIt',
        '.set(',
        '.update(',
        '.delete(',
        '.add(',
        'Platform.environment',
        'String.fromEnvironment',
        'dotenv',
        'print(',
        'debugPrint',
        'developer.log',
      ]) {
        expect(sources.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('production capability declaration remains false', () {
      expect(
        callV2NoProductionCapabilities.rtcConfigProviderAvailable,
        isFalse,
      );
    });
  });

  group('feature gate', () {
    test('disabled provider rejects before request inspection or transport',
        () async {
      final transport = _FakeTransport();
      final provider = _provider(
        enabled: false,
        transport: transport,
      );

      await expectLater(
        provider.resolveRtcConfig(const CallV2RtcConfigRequest(
          callId: 'calls/call_a',
          localParticipantUid: ' users/caller',
          isVideo: true,
          idempotencyKey: ' bad',
        )),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );

      expect(transport.calls, isEmpty);
    });
  });

  group('request routing and validation', () {
    test('routes to exact RTC credential callable with public request only',
        () async {
      final transport = _FakeTransport();
      final provider = _provider(transport: transport);

      await provider.resolveRtcConfig(_request());

      expect(transport.calls, hasLength(1));
      expect(transport.calls.single.callableName, 'resolveRtcConfigV2');
      expect(transport.calls.single.request, <String, Object?>{
        'callId': 'call_a',
        'localParticipantUid': 'caller',
        'isVideo': true,
        'idempotencyKey': 'resolve_key',
      });
    });

    test('invalid identifiers reject before transport without raw values',
        () async {
      for (final request in <CallV2RtcConfigRequest>[
        _request(callId: ''),
        _request(callId: ' call_a'),
        _request(callId: 'call_a '),
        _request(callId: 'calls/call_a'),
        _request(callId: 'x' * 129),
        _request(localParticipantUid: ''),
        _request(localParticipantUid: ' caller'),
        _request(localParticipantUid: 'caller '),
        _request(localParticipantUid: 'users/caller'),
        _request(localParticipantUid: 'x' * 129),
        _request(idempotencyKey: ''),
        _request(idempotencyKey: ' key'),
        _request(idempotencyKey: 'key '),
        _request(idempotencyKey: 'keys/resolve'),
        _request(idempotencyKey: 'x' * 129),
      ]) {
        final transport = _FakeTransport();
        final provider = _provider(transport: transport);
        Object? caught;

        try {
          await provider.resolveRtcConfig(request);
        } catch (error) {
          caught = error;
        }

        expect(caught, isA<CallV2ClientError>());
        expect((caught! as CallV2ClientError).code,
            CallV2ClientErrorCode.invalidRequest);
        for (final rawIdentifier in <String>[
          request.callId,
          request.localParticipantUid,
          request.idempotencyKey,
        ]) {
          if (rawIdentifier.isNotEmpty) {
            expect(caught.toString().contains(rawIdentifier), isFalse);
          }
        }
        expect(transport.calls, isEmpty);
      }
    });

    test('request is defensively copied before transport receives it',
        () async {
      final transport = _FakeTransport();
      final provider = _provider(transport: transport);
      final request = _request(idempotencyKey: 'same_key');

      await provider.resolveRtcConfig(request);
      transport.calls.single.request['callId'] = 'changed';

      expect(request.callId, 'call_a');
      expect(request.idempotencyKey, 'same_key');
    });
  });

  group('response normalization', () {
    test('returns a defensive copy of the credential response', () async {
      final raw = _validResponse();
      final provider = _provider(transport: _FakeTransport(response: raw));

      final result =
          await provider.resolveRtcConfig(_request()) as Map<String, Object?>;
      result['token'] = 'changed';

      expect(raw['token'], 'credential_token');
      expect(identical(result, raw), isFalse);
    });

    test('rejects malformed, private, unsupported, and metadata responses',
        () async {
      for (final response in <Object?>[
        'not-a-map',
        <Object?, Object?>{1: 'bad'},
        <String, Object?>{..._validResponse(), 'extra': true},
        <String, Object?>{..._validResponse(), 'secret': 'raw-secret'},
        <String, Object?>{..._validResponse(), 'metadata': 'provider-meta'},
        <String, Object?>{..._validResponse(), 'token': Object()},
        <String, Object?>{
          ..._validResponse(),
          'token': <String, Object?>{'secret': 'raw-secret'},
        },
      ]) {
        final provider = _provider(
          transport: _FakeTransport(response: response),
        );

        await expectLater(
          provider.resolveRtcConfig(_request()),
          throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
        );
      }
    });
  });

  group('error normalization', () {
    test('Firebase callable errors map to controlled Call V2 errors', () async {
      const expected = <String, CallV2ClientErrorCode>{
        'unauthenticated': CallV2ClientErrorCode.unauthorized,
        'permission-denied': CallV2ClientErrorCode.unauthorized,
        'invalid-argument': CallV2ClientErrorCode.invalidRequest,
        'failed-precondition': CallV2ClientErrorCode.rejected,
        'not-found': CallV2ClientErrorCode.rejected,
        'already-exists': CallV2ClientErrorCode.rejected,
        'resource-exhausted': CallV2ClientErrorCode.unavailable,
        'unavailable': CallV2ClientErrorCode.unavailable,
        'deadline-exceeded': CallV2ClientErrorCode.unavailable,
        'internal': CallV2ClientErrorCode.unavailable,
        'unknown': CallV2ClientErrorCode.unavailable,
      };

      for (final entry in expected.entries) {
        final provider = _provider(
          transport: _FakeTransport(
            error: _TestFirebaseFunctionsException(entry.key),
          ),
        );

        await expectLater(
          provider.resolveRtcConfig(_request()),
          throwsA(_clientError(entry.value)),
          reason: entry.key,
        );
      }
    });

    test('raw messages, details, tokens, and request values are not exposed',
        () async {
      final provider = _provider(
        transport: _FakeTransport(
          error: _TestFirebaseFunctionsException(
            'internal',
            message: 'raw-secret-message',
            details: <String, Object?>{'token': 'credential-token'},
          ),
        ),
      );

      Object? caught;
      try {
        await provider.resolveRtcConfig(_request(
          idempotencyKey: 'secret-request-key',
        ));
      } catch (error) {
        caught = error;
      }

      expect(caught, isA<CallV2ClientError>());
      final text = caught.toString();
      for (final forbidden in <String>[
        'raw-secret-message',
        'credential-token',
        'secret-request-key',
        'details',
        'stack',
      ]) {
        expect(text.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('success and failure each invoke transport once with no retry',
        () async {
      final successTransport = _FakeTransport();
      await _provider(transport: successTransport).resolveRtcConfig(_request());
      expect(successTransport.calls, hasLength(1));

      final failureTransport = _FakeTransport(
        error: _TestFirebaseFunctionsException('unavailable'),
      );
      await expectLater(
        _provider(transport: failureTransport).resolveRtcConfig(_request()),
        throwsA(isA<CallV2ClientError>()),
      );
      expect(failureTransport.calls, hasLength(1));
    });

    test('concurrent calls are not shared by the credential provider',
        () async {
      final transport = _FakeTransport()..hold();
      final provider = _provider(transport: transport);

      final first = provider.resolveRtcConfig(
        _request(idempotencyKey: 'first_key'),
      );
      final second = provider.resolveRtcConfig(
        _request(idempotencyKey: 'second_key'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(transport.calls, hasLength(2));
      transport.release();
      await Future.wait(<Future<Object?>>[first, second]);
    });
  });
}

FirebaseCallV2RtcCredentialProvider _provider({
  bool enabled = true,
  _FakeTransport? transport,
}) {
  return FirebaseCallV2RtcCredentialProvider(
    featureGate: CallV2FeatureGate(enabled: enabled),
    transport: transport ?? _FakeTransport(),
  );
}

CallV2RtcConfigRequest _request({
  String callId = 'call_a',
  String localParticipantUid = 'caller',
  bool isVideo = true,
  String idempotencyKey = 'resolve_key',
}) {
  return CallV2RtcConfigRequest(
    callId: callId,
    localParticipantUid: localParticipantUid,
    isVideo: isVideo,
    idempotencyKey: idempotencyKey,
  );
}

Map<String, Object?> _validResponse() {
  return <String, Object?>{
    'callId': 'call_a',
    'localParticipantUid': 'caller',
    'channelName': 'channel_a',
    'rtcUid': 123,
    'token': 'credential_token',
    'isVideo': true,
    'issuedAt': DateTime.utc(2026, 1, 1, 12).toIso8601String(),
    'expiresAt': DateTime.utc(2026, 1, 1, 12, 10).toIso8601String(),
    'idempotentReplay': false,
  };
}

Matcher _clientError(CallV2ClientErrorCode code) {
  return isA<CallV2ClientError>().having(
    (error) => error.code,
    'code',
    code,
  );
}

String _phase4Sources() {
  return <String>[
    'lib/call_v2/firebase/firebase_call_v2_rtc_credential_provider.dart',
    'lib/call_v2/firebase/call_v2_callable_transport.dart',
  ].map((path) => File(path).readAsStringSync()).join('\n');
}

class _FakeTransport implements CallV2CallableTransport {
  _FakeTransport({
    Object? response,
    this.error,
  }) : response = response ?? _validResponse();

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
