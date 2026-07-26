import 'dart:io';

import 'package:connect_app/call_v2/permissions/call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/permissions/real_call_v2_permission_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real permission adapter construction does not prompt', () async {
    const adapter = RealCallV2PermissionAdapter();

    expect(
        await adapter.checkMicrophone(), CallV2PermissionDecision.unavailable);
    expect(await adapter.checkCamera(), CallV2PermissionDecision.unavailable);
    expect(await adapter.requestMicrophone(), CallV2PermissionDecision.denied);
    expect(await adapter.requestCamera(), CallV2PermissionDecision.denied);
  });

  test('permission adapter gate source does not import platform prompt package',
      () {
    final source = File(
      'lib/call_v2/permissions/real_call_v2_permission_adapter.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('permission_handler')));
    expect(source, isNot(contains('openAppSettings')));
  });
}
