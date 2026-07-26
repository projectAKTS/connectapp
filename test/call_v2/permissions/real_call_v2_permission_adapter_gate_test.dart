import 'dart:io';

import 'package:connect_app/call_v2/permissions/call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/permissions/real_call_v2_permission_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real permission adapter construction does not prompt', () async {
    final client = _FakePermissionClient();
    final adapter = RealCallV2PermissionAdapter(client: client);

    expect(await adapter.checkMicrophone(), CallV2PermissionDecision.granted);
    expect(await adapter.checkCamera(), CallV2PermissionDecision.granted);
    expect(await adapter.requestMicrophone(), CallV2PermissionDecision.denied);
    expect(await adapter.requestCamera(), CallV2PermissionDecision.denied);
    expect(client.checkCount, 2);
    expect(client.requestCount, 0);
  });

  test('permission requests are explicit and gated', () async {
    final client = _FakePermissionClient();
    final adapter = RealCallV2PermissionAdapter(
      allowRequests: true,
      client: client,
    );

    expect(await adapter.requestMicrophone(), CallV2PermissionDecision.granted);
    expect(await adapter.requestCamera(), CallV2PermissionDecision.granted);
    expect(client.requestCount, 2);
  });

  test('permission adapter gate source uses plugin but not settings or startup',
      () {
    final source = File(
      'lib/call_v2/permissions/real_call_v2_permission_adapter.dart',
    ).readAsStringSync();

    expect(source, contains('permission_handler'));
    expect(source, isNot(contains('openAppSettings')));
  });

  test('safe debug output contains no unsafe wording', () {
    const adapter = RealCallV2PermissionAdapter(allowRequests: true);
    final output = adapter.toSafeDebugMap().toString().toLowerCase();

    for (final forbidden in _forbiddenDebugFragments) {
      expect(output, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}

class _FakePermissionClient implements RealCallV2PermissionClient {
  int checkCount = 0;
  int requestCount = 0;

  @override
  Future<CallV2PermissionDecision> check(
    CallV2PermissionKind permission,
  ) async {
    checkCount += 1;
    return CallV2PermissionDecision.granted;
  }

  @override
  Future<CallV2PermissionDecision> request(
    CallV2PermissionKind permission,
  ) async {
    requestCount += 1;
    return CallV2PermissionDecision.granted;
  }
}

const _forbiddenDebugFragments = <String>[
  'token',
  'channel',
  'uid',
  'user',
  'participant',
  'callid',
  'device',
  'credential',
  'secret',
  'raw',
  'payload',
  'stack',
];
