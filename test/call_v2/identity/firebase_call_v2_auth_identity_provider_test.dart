import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/call_v2_feature_gate.dart';
import 'package:connect_app/call_v2/call_v2_production_capabilities.dart';
import 'package:connect_app/call_v2/firebase/firebase_call_v2_auth_identity_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('construction and isolation', () {
    test('constructor has no side effects and performs no auth lookup', () {
      final auth = _FakeFirebaseAuth(uid: 'caller');

      FirebaseCallV2AuthIdentityProvider(
        featureGate: const CallV2FeatureGate(enabled: true),
        auth: auth,
      );

      expect(auth.currentUserReads, 0);
      expect(auth.idTokenReads, 0);
      expect(auth.listenerRegistrations, 0);
      expect(Firebase.apps, isEmpty);
    });

    test('source has no singleton, listener, token, startup, UI, or writes',
        () {
      final source = _source();
      for (final forbidden in <String>[
        'FirebaseAuth.instance',
        'authStateChanges',
        'idTokenChanges',
        'userChanges',
        'getIdToken',
        'getIdTokenResult',
        'email',
        'displayName',
        'providerData',
        'refreshToken',
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

    test('default auth identity capability remains false', () {
      expect(
        callV2NoProductionCapabilities.authIdentitySourceAvailable,
        isFalse,
      );
    });
  });

  group('feature gate and behavior', () {
    test('disabled gate rejects before auth inspection', () async {
      final auth = _FakeFirebaseAuth(uid: 'raw_uid');
      final provider = _provider(enabled: false, auth: auth);

      await expectLater(
        provider.requireAuthenticatedIdentity(),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );

      expect(auth.currentUserReads, 0);
    });

    test('valid current UID is returned and redacted from debug output',
        () async {
      final provider = _provider(auth: _FakeFirebaseAuth(uid: 'caller_uid'));

      final identity = await provider.requireAuthenticatedIdentity();

      expect(identity.uid, 'caller_uid');
      expect(identity.toString(), isNot(contains('caller_uid')));
    });

    test('identity value exposes immutable UID only', () async {
      final identity = await _provider(
        auth: _FakeFirebaseAuth(uid: 'caller_uid'),
      ).requireAuthenticatedIdentity();

      expect(identity.uid, 'caller_uid');
      expect(identity.toString(), contains('hasUid: true'));
      expect(identity.toString(), isNot(contains('email')));
      expect(identity.toString(), isNot(contains('token')));
    });

    test('null and malformed users are unauthorized without raw UID exposure',
        () async {
      for (final uid in <String?>[
        null,
        '',
        ' caller',
        'caller ',
        'users/caller',
        'x' * 161,
      ]) {
        Object? caught;
        try {
          await _provider(auth: _FakeFirebaseAuth(uid: uid))
              .requireAuthenticatedIdentity();
        } catch (error) {
          caught = error;
        }

        expect(caught, isA<CallV2ClientError>());
        expect(
          (caught! as CallV2ClientError).code,
          CallV2ClientErrorCode.unauthorized,
        );
        if (uid != null && uid.isNotEmpty) {
          expect(caught.toString(), isNot(contains(uid)));
        }
      }
    });

    test('auth exceptions normalize without raw messages', () async {
      for (final entry in <String, CallV2ClientErrorCode>{
        'permission-denied': CallV2ClientErrorCode.unauthorized,
        'unauthenticated': CallV2ClientErrorCode.unauthorized,
        'network-request-failed': CallV2ClientErrorCode.unavailable,
        'internal-error': CallV2ClientErrorCode.unavailable,
      }.entries) {
        final provider = _provider(
          auth: _FakeFirebaseAuth(
            error: FirebaseAuthException(
              code: entry.key,
              message: 'raw uid secret token',
            ),
          ),
        );
        Object? caught;

        try {
          await provider.requireAuthenticatedIdentity();
        } catch (error) {
          caught = error;
        }

        expect(caught, isA<CallV2ClientError>());
        expect((caught! as CallV2ClientError).code, entry.value);
        expect(caught.toString(), isNot(contains('raw uid secret token')));
      }
    });

    test('one request performs one auth read and no retry', () async {
      final auth = _FakeFirebaseAuth(uid: 'caller');
      final provider = _provider(auth: auth);

      await provider.requireAuthenticatedIdentity();

      expect(auth.currentUserReads, 1);
      expect(auth.idTokenReads, 0);

      final failingAuth = _FakeFirebaseAuth(
        error: FirebaseAuthException(code: 'internal-error'),
      );
      await expectLater(
        _provider(auth: failingAuth).requireAuthenticatedIdentity(),
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );
      expect(failingAuth.currentUserReads, 1);
    });
  });
}

FirebaseCallV2AuthIdentityProvider _provider({
  bool enabled = true,
  required _FakeFirebaseAuth auth,
}) {
  return FirebaseCallV2AuthIdentityProvider(
    featureGate: CallV2FeatureGate(enabled: enabled),
    auth: auth,
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
  return File(
    'lib/call_v2/firebase/firebase_call_v2_auth_identity_provider.dart',
  ).readAsStringSync();
}

class _FakeFirebaseAuth implements FirebaseAuth {
  _FakeFirebaseAuth({
    String? uid,
    FirebaseAuthException? error,
  })  : _uid = uid,
        _error = error;

  final String? _uid;
  final FirebaseAuthException? _error;
  int currentUserReads = 0;
  int idTokenReads = 0;
  int listenerRegistrations = 0;

  @override
  User? get currentUser {
    currentUserReads += 1;
    final error = _error;
    if (error != null) throw error;
    final uid = _uid;
    return uid == null ? null : _FakeUser(uid, this);
  }

  @override
  Stream<User?> authStateChanges() {
    listenerRegistrations += 1;
    return const Stream<User?>.empty();
  }

  @override
  Stream<User?> idTokenChanges() {
    listenerRegistrations += 1;
    return const Stream<User?>.empty();
  }

  @override
  Stream<User?> userChanges() {
    listenerRegistrations += 1;
    return const Stream<User?>.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  _FakeUser(this.uid, this.auth);

  @override
  final String uid;

  final _FakeFirebaseAuth auth;

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async {
    auth.idTokenReads += 1;
    return 'raw_token';
  }

  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) {
    auth.idTokenReads += 1;
    throw UnimplementedError();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
