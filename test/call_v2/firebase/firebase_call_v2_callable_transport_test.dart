import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/firebase/firebase_call_v2_callable_transport.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('constructor performs no backend call', () {
    final client = _FakeCallableClient();
    FirebaseCallV2CallableTransport(client: client);

    expect(client.calls, 0);
  });

  test('explicit call forwards copied data and normalizes response', () async {
    final nested = <String, Object?>{'ready': true};
    final client = _FakeCallableClient(response: <Object?, Object?>{
      'status': 'ok',
      'result': nested,
    });
    final transport = FirebaseCallV2CallableTransport(client: client);

    final result = await transport.call('callV2RtcToken', <String, Object?>{
      'callId': 'call_a',
      'participantUid': 'local_a',
      'isVideo': false,
    });
    nested['ready'] = false;

    expect(client.calls, 1);
    expect(client.names, <String>['callV2RtcToken']);
    expect(result['status'], 'ok');
    expect((result['result']! as Map<String, Object?>)['ready'], true);
  });

  test('rejects malformed request and response values safely', () async {
    final transport = FirebaseCallV2CallableTransport(
      client: _FakeCallableClient(response: <Object?, Object?>{1: 'bad'}),
    );

    expect(
      () => transport.call('x', <String, Object?>{'bad': Object()}),
      throwsA(_clientError(CallV2ClientErrorCode.invalidRequest)),
    );
    await expectLater(
      transport.call('x', const <String, Object?>{}),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );
  });

  test('client failure is normalized without raw details', () async {
    final transport = FirebaseCallV2CallableTransport(
      client: _FakeCallableClient(fail: true),
    );

    await expectLater(
      transport.call('x', const <String, Object?>{}),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );
  });

  test('Firebase callable failures map to stable client errors', () async {
    final cases = <String, CallV2ClientErrorCode>{
      'unauthenticated': CallV2ClientErrorCode.unauthorized,
      'permission-denied': CallV2ClientErrorCode.unauthorized,
      'invalid-argument': CallV2ClientErrorCode.invalidRequest,
      'failed-precondition': CallV2ClientErrorCode.rejected,
      'unavailable': CallV2ClientErrorCode.unavailable,
    };

    for (final entry in cases.entries) {
      final transport = FirebaseCallV2CallableTransport(
        client: _FirebaseFailureClient(entry.key),
      );

      await expectLater(
        transport.call('callV2RtcToken', const <String, Object?>{}),
        throwsA(_clientError(entry.value)),
        reason: entry.key,
      );
    }
  });
}

Matcher _clientError(CallV2ClientErrorCode code) {
  return isA<CallV2ClientError>().having((error) => error.code, 'code', code);
}

class _FakeCallableClient implements FirebaseCallV2CallableClient {
  _FakeCallableClient({
    this.response = const <String, Object?>{'ok': true},
    this.fail = false,
  });

  final Object? response;
  final bool fail;
  final names = <String>[];
  int calls = 0;

  @override
  Future<Object?> call(String name, Map<String, Object?> data) async {
    calls += 1;
    names.add(name);
    if (fail) throw StateError('unsafe details');
    return response;
  }
}

class _FirebaseFailureClient implements FirebaseCallV2CallableClient {
  const _FirebaseFailureClient(this.code);

  final String code;

  @override
  Future<Object?> call(String name, Map<String, Object?> data) async {
    throw FirebaseFunctionsException(code: code, message: 'unsafe details');
  }
}
