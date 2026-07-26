import '../firebase/call_v2_token_provider.dart';
import '../firebase/fake_call_v2_token_provider.dart';
import '../permissions/call_v2_permission_adapter.dart';
import '../permissions/fake_call_v2_permission_adapter.dart';
import '../rtc/call_v2_rtc_adapter.dart';
import '../rtc/fake_call_v2_rtc_adapter.dart';
import 'call_v2_runtime.dart';
import 'call_v2_runtime_config.dart';
import 'call_v2_runtime_mode.dart';
import 'disabled_call_v2_runtime.dart';
import 'fake_call_v2_runtime.dart';
import 'internal_call_v2_runtime.dart';

class CallV2RuntimeFactory {
  const CallV2RuntimeFactory({
    this.permissionAdapter,
    this.rtcAdapter,
    this.tokenProvider,
  });

  final CallV2PermissionAdapter? permissionAdapter;
  final CallV2RtcAdapter? rtcAdapter;
  final CallV2TokenProvider? tokenProvider;

  CallV2Runtime create(CallV2RuntimeConfig config) {
    switch (config.mode) {
      case CallV2RuntimeMode.fake:
        return FakeCallV2Runtime(
          permissionAdapter: permissionAdapter is FakeCallV2PermissionAdapter
              ? permissionAdapter! as FakeCallV2PermissionAdapter
              : null,
          rtcAdapter: rtcAdapter is FakeCallV2RtcAdapter
              ? rtcAdapter! as FakeCallV2RtcAdapter
              : null,
          tokenProvider: tokenProvider is FakeCallV2TokenProvider
              ? tokenProvider! as FakeCallV2TokenProvider
              : null,
        );
      case CallV2RuntimeMode.internalRealDevice:
        return InternalCallV2Runtime(
          config: config,
          permissionAdapter: permissionAdapter ?? FakeCallV2PermissionAdapter(),
          rtcAdapter: rtcAdapter ?? FakeCallV2RtcAdapter(),
          tokenProvider: tokenProvider ?? FakeCallV2TokenProvider(),
        );
      case CallV2RuntimeMode.productionDisabled:
        return DisabledCallV2Runtime();
    }
  }
}
