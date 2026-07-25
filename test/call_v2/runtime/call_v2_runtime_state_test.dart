import 'package:connect_app/call_v2/runtime/call_v2_runtime_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('state exposes the required phases', () {
    expect(
      CallV2RuntimePhase.values.map((phase) => phase.name),
      <String>[
        'idle',
        'preparing',
        'permissionPreflight',
        'requestingPermission',
        'connecting',
        'ringing',
        'ready',
        'active',
        'ending',
        'ended',
        'failed',
      ],
    );
  });

  test('copyWith keeps immutable call shape and can clear it', () {
    const state = CallV2RuntimeState(
      phase: CallV2RuntimePhase.connecting,
      mode: CallV2RuntimeCallMode.video,
      direction: CallV2RuntimeDirection.outgoing,
      errorCategory: CallV2RuntimeErrorCategory.rtcUnavailable,
    );

    final active = state.copyWith(
      phase: CallV2RuntimePhase.active,
      clearError: true,
    );
    final idle = active.copyWith(
      phase: CallV2RuntimePhase.idle,
      clearCallShape: true,
    );

    expect(state.phase, CallV2RuntimePhase.connecting);
    expect(active.phase, CallV2RuntimePhase.active);
    expect(active.errorCategory, CallV2RuntimeErrorCategory.none);
    expect(idle.mode, isNull);
    expect(idle.direction, isNull);
  });

  test('safe debug output hides identifiers and credentials', () {
    const state = CallV2RuntimeState(
      phase: CallV2RuntimePhase.failed,
      mode: CallV2RuntimeCallMode.audio,
      direction: CallV2RuntimeDirection.incoming,
      errorCategory: CallV2RuntimeErrorCategory.permissionDenied,
    );

    final debugText = state.toSafeDebugMap().toString() + state.toString();

    for (final forbidden in <String>[
      'uid',
      'token',
      'channel',
      'device',
      'secret',
      'call_',
    ]) {
      expect(debugText.toLowerCase(), isNot(contains(forbidden)));
    }
  });
}
