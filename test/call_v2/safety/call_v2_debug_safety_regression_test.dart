import 'package:connect_app/call_v2/firebase/call_v2_token_provider.dart';
import 'package:connect_app/call_v2/firebase/real_call_v2_token_provider.dart';
import 'package:connect_app/call_v2/permissions/real_call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/rtc/internal_call_v2_rtc_adapter_gate.dart';
import 'package:connect_app/call_v2/runtime/call_v2_internal_call_coordinator.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_config.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_state.dart';
import 'package:connect_app/call_v2/runtime/disabled_call_v2_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new runtime and adapter debug output avoids sensitive wording', () {
    final outputs = <String>[
      const CallV2RuntimeConfig.internalRealDevice(
        allowPermissionRequests: true,
        allowTokenRequests: true,
        allowRtcInitialization: true,
        allowRtcJoin: true,
      ).toSafeDebugMap().toString(),
      DisabledCallV2Runtime().toSafeDebugMap().toString(),
      const RealCallV2PermissionAdapter().toSafeDebugMap().toString(),
      const RealCallV2TokenProvider().toSafeDebugMap().toString(),
      const InternalCallV2RtcAdapterGate(
        allowAdapterConstruction: true,
        allowInitialization: true,
        allowJoin: true,
      ).toSafeDebugMap().toString(),
      CallV2InternalCallCoordinator(
        config: const CallV2RuntimeConfig.fake(),
      ).toSafeDebugMap().toString(),
      const CallV2TokenResult(
        channelAlias: 'unsafe-channel-value',
        rtcUid: 42,
        expiresInSeconds: 3600,
        token: 'unsafe-token-value',
      ).toSafeDebugMap().toString(),
    ].map((value) => value.toLowerCase()).toList();

    for (final output in outputs) {
      for (final forbidden in _forbiddenDebugFragments) {
        expect(output, isNot(contains(forbidden)), reason: forbidden);
      }
    }
  });

  test('state-only debug remains generic for an internal runtime type', () {
    expect(
      const CallV2RuntimeState(
        phase: CallV2RuntimePhase.permissionPreflight,
        mode: CallV2RuntimeCallMode.audio,
        direction: CallV2RuntimeDirection.outgoing,
      ).toSafeDebugMap().toString().toLowerCase(),
      isNot(contains('token')),
    );
  });
}

const _forbiddenDebugFragments = <String>[
  'unsafe-token-value',
  'unsafe-channel-value',
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
