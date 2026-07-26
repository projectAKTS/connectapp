import 'package:connect_app/call_v2/runtime/call_v2_manual_smoke_diagnostics.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('diagnostics expose only safe step booleans and category', () {
    const diagnostics = CallV2ManualSmokeDiagnostics(
      permissionReady: true,
      permissionDone: true,
      accessReady: true,
      accessDone: false,
      setupReady: false,
      setupDone: false,
      joinReady: false,
      joinDone: false,
      phase: CallV2RuntimePhase.failed,
      failureCategory: CallV2RuntimeErrorCategory.backendUnavailable,
    );

    final debug = diagnostics.toString().toLowerCase();
    expect(debug, contains('backendunavailable'));
    for (final forbidden in <String>[
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
      'app id',
    ]) {
      expect(debug, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}
