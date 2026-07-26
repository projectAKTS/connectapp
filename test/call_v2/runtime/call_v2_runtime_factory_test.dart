import 'package:connect_app/call_v2/firebase/fake_call_v2_token_provider.dart';
import 'package:connect_app/call_v2/firebase/real_call_v2_token_provider.dart';
import 'package:connect_app/call_v2/permissions/fake_call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/permissions/real_call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/rtc/agora_call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/rtc/fake_call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_config.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_factory.dart';
import 'package:connect_app/call_v2/runtime/disabled_call_v2_runtime.dart';
import 'package:connect_app/call_v2/runtime/fake_call_v2_runtime.dart';
import 'package:connect_app/call_v2/runtime/internal_call_v2_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('factory creates fake runtime for fake mode', () {
    final runtime = const CallV2RuntimeFactory().create(
      const CallV2RuntimeConfig.fake(),
    );
    addTearDown(runtime.dispose);

    expect(runtime, isA<FakeCallV2Runtime>());
  });

  test('factory creates disabled runtime for production disabled mode', () {
    final runtime = const CallV2RuntimeFactory().create(
      const CallV2RuntimeConfig.productionDisabled(),
    );
    addTearDown(runtime.dispose);

    expect(runtime, isA<DisabledCallV2Runtime>());
  });

  test('factory creates internal shell without side effects', () {
    final permissions = FakeCallV2PermissionAdapter();
    final rtc = FakeCallV2RtcAdapter();
    final access = FakeCallV2TokenProvider();
    final runtime = CallV2RuntimeFactory(
      permissionAdapter: permissions,
      rtcAdapter: rtc,
      tokenProvider: access,
    ).create(
      const CallV2RuntimeConfig.internalRealDevice(
        allowPermissionRequests: true,
        allowTokenRequests: true,
        allowRtcInitialization: true,
        allowRtcJoin: true,
      ),
    );
    addTearDown(runtime.dispose);

    expect(runtime, isA<InternalCallV2Runtime>());
    expect(permissions.requestMicrophoneCount, 0);
    expect(access.resolveCount, 0);
    expect(rtc.initializeCount, 0);
    expect(rtc.joinCount, 0);
  });

  test('factory creates real internal adapter path only when explicit', () {
    final runtime = const CallV2RuntimeFactory().create(
      const CallV2RuntimeConfig.internalRealDevice(
        allowPermissionRequests: true,
        allowTokenRequests: true,
        allowRtcInitialization: true,
        allowRtcJoin: true,
        useRealAdapters: true,
        rtcApplicationIdentifier: 'app-for-test',
      ),
    );
    addTearDown(runtime.dispose);

    expect(runtime, isA<InternalCallV2Runtime>());
    final internal = runtime as InternalCallV2Runtime;
    expect(internal.permissionAdapter, isA<RealCallV2PermissionAdapter>());
    expect(internal.tokenProvider, isA<RealCallV2TokenProvider>());
    expect(internal.rtcAdapter, isA<AgoraCallV2RtcAdapter>());
    expect(internal.currentState.phase.name, 'idle');
    expect(internal.hasAccess, isFalse);
    expect(internal.isRtcInitialized, isFalse);
    expect(internal.isRtcJoined, isFalse);
  });

  test('real adapter config safe debug exposes booleans only', () {
    const config = CallV2RuntimeConfig.internalRealDevice(
      allowPermissionRequests: true,
      allowTokenRequests: true,
      allowRtcInitialization: true,
      allowRtcJoin: true,
      useRealAdapters: true,
      rtcApplicationIdentifier: 'unsafe-app-id',
    );

    final debug = config.toSafeDebugMap().toString().toLowerCase();

    expect(debug, isNot(contains('unsafe-app-id')));
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
    ]) {
      expect(debug, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}
