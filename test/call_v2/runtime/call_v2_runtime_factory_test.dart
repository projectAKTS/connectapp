import 'package:connect_app/call_v2/firebase/fake_call_v2_token_provider.dart';
import 'package:connect_app/call_v2/permissions/fake_call_v2_permission_adapter.dart';
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
}
