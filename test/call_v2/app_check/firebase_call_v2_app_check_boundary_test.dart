import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/call_v2_feature_gate.dart';
import 'package:connect_app/call_v2/call_v2_production_capabilities.dart';
import 'package:connect_app/call_v2/firebase/call_v2_app_check_transport.dart';
import 'package:connect_app/call_v2/firebase/firebase_call_v2_app_check_boundary.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('construction and isolation', () {
    test('constructor has no side effects and performs no App Check call', () {
      final transport = _FakeAppCheckTransport(token: 'app_check_token');

      FirebaseCallV2AppCheckBoundary(
        featureGate: const CallV2FeatureGate(enabled: true),
        transport: transport,
      );

      expect(transport.calls, 0);
      expect(Firebase.apps, isEmpty);
    });

    test('source has no singleton, token retention, startup, UI, or writes',
        () {
      final source = _source();
      for (final forbidden in <String>[
        'FirebaseAppCheck.instance',
        'FirebaseAuth.instance',
        'CallV2Runtime(',
        'CallV2Harness(',
        'Navigator',
        'MaterialPageRoute',
        'runApp',
        '.set(',
        '.update(',
        '.delete(',
        'Platform.environment',
        'String.fromEnvironment',
        'dotenv',
        'print(',
        'debugPrint',
        'developer.log',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('default App Check capability remains false', () {
      expect(callV2NoProductionCapabilities.appCheckAvailable, isFalse);
    });
  });

  group('behavior', () {
    test('disabled gate rejects before transport access', () async {
      final transport = _FakeAppCheckTransport(token: 'raw_token');
      final boundary = _boundary(enabled: false, transport: transport);

      await expectLater(
        boundary.assertAvailable(),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );

      expect(transport.calls, 0);
    });

    test('available assertion succeeds without returning or retaining token',
        () async {
      final transport = _FakeAppCheckTransport(token: 'raw_app_check_token');
      final boundary = _boundary(transport: transport);

      await boundary.assertAvailable();

      expect(transport.calls, 1);
      expect(boundary.toString(), isNot(contains('raw_app_check_token')));
    });

    test('missing assertion token fails unavailable', () async {
      for (final token in <String?>[null, '']) {
        await expectLater(
          _boundary(
            transport: _FakeAppCheckTransport(token: token),
          ).assertAvailable(),
          throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
        );
      }
    });

    test('Firebase errors normalize without raw token or details', () async {
      for (final entry in <String, CallV2ClientErrorCode>{
        'unauthenticated': CallV2ClientErrorCode.unauthorized,
        'permission-denied': CallV2ClientErrorCode.unauthorized,
        'unavailable': CallV2ClientErrorCode.unavailable,
        'internal': CallV2ClientErrorCode.unavailable,
      }.entries) {
        Object? caught;
        try {
          await _boundary(
            transport: _FakeAppCheckTransport(
              error: FirebaseException(
                plugin: 'firebase_app_check',
                code: entry.key,
                message: 'raw app check token secret details',
              ),
            ),
          ).assertAvailable();
        } catch (error) {
          caught = error;
        }

        expect(caught, isA<CallV2ClientError>());
        expect((caught! as CallV2ClientError).code, entry.value);
        expect(caught.toString(), isNot(contains('raw app check token')));
        expect(caught.toString(), isNot(contains('secret details')));
      }
    });

    test('one assertion performs one transport call with no retry', () async {
      final transport = _FakeAppCheckTransport(token: 'raw_token');
      final boundary = _boundary(transport: transport);

      await boundary.assertAvailable();

      expect(transport.calls, 1);

      final failingTransport = _FakeAppCheckTransport(
        error: FirebaseException(plugin: 'firebase_app_check', code: 'unknown'),
      );
      await expectLater(
        _boundary(transport: failingTransport).assertAvailable(),
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );
      expect(failingTransport.calls, 1);
    });

    test('concurrent explicit assertions remain separate', () async {
      final transport = _FakeAppCheckTransport(token: 'raw_token');
      final boundary = _boundary(transport: transport);

      await Future.wait(<Future<void>>[
        boundary.assertAvailable(),
        boundary.assertAvailable(),
      ]);

      expect(transport.calls, 2);
    });
  });
}

FirebaseCallV2AppCheckBoundary _boundary({
  bool enabled = true,
  required CallV2AppCheckTransport transport,
}) {
  return FirebaseCallV2AppCheckBoundary(
    featureGate: CallV2FeatureGate(enabled: enabled),
    transport: transport,
  );
}

Matcher _clientError(CallV2ClientErrorCode code) {
  return isA<CallV2ClientError>().having(
    (error) => error.code,
    'code',
    code,
  );
}

String _source() {
  return <String>[
    'lib/call_v2/app_check/call_v2_app_check_boundary.dart',
    'lib/call_v2/firebase/call_v2_app_check_transport.dart',
    'lib/call_v2/firebase/firebase_call_v2_app_check_boundary.dart',
  ].map((path) => File(path).readAsStringSync()).join('\n');
}

class _FakeAppCheckTransport implements CallV2AppCheckTransport {
  _FakeAppCheckTransport({
    this.token,
    this.error,
  });

  final String? token;
  final Object? error;
  int calls = 0;

  @override
  Future<String?> getToken() async {
    calls += 1;
    final thrown = error;
    if (thrown != null) throw thrown;
    return token;
  }
}
