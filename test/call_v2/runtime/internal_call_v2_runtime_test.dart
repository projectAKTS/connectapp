import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/firebase/fake_call_v2_token_provider.dart';
import 'package:connect_app/call_v2/permissions/fake_call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/rtc/fake_call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_config.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_state.dart';
import 'package:connect_app/call_v2/runtime/internal_call_v2_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('constructor has no permission access token or RTC side effects', () {
    final permissions = FakeCallV2PermissionAdapter();
    final access = FakeCallV2TokenProvider();
    final rtc = FakeCallV2RtcAdapter();
    final runtime = InternalCallV2Runtime(
      config: _internalConfig,
      permissionAdapter: permissions,
      rtcAdapter: rtc,
      tokenProvider: access,
    );
    addTearDown(runtime.dispose);

    expect(permissions.requestMicrophoneCount, 0);
    expect(permissions.requestCameraCount, 0);
    expect(access.resolveCount, 0);
    expect(rtc.initializeCount, 0);
    expect(rtc.joinCount, 0);
    expect(runtime.currentState.phase, CallV2RuntimePhase.idle);
  });

  test('internal flow advances only through explicit steps', () async {
    final permissions = FakeCallV2PermissionAdapter();
    final access = FakeCallV2TokenProvider();
    final rtc = FakeCallV2RtcAdapter();
    final runtime = InternalCallV2Runtime(
      config: _internalConfig,
      permissionAdapter: permissions,
      rtcAdapter: rtc,
      tokenProvider: access,
    );
    addTearDown(runtime.dispose);

    await runtime.startOutgoingCall(mode: CallV2RuntimeCallMode.video);
    expect(runtime.currentState.phase, CallV2RuntimePhase.permissionPreflight);
    expect(permissions.requestMicrophoneCount, 0);
    expect(access.resolveCount, 0);
    expect(rtc.initializeCount, 0);

    await runtime.requestPermissionsExplicitly();
    expect(runtime.currentState.phase, CallV2RuntimePhase.connecting);
    expect(permissions.requestMicrophoneCount, 1);
    expect(permissions.requestCameraCount, 1);
    expect(access.resolveCount, 0);

    await runtime.requestTokenExplicitly();
    expect(access.resolveCount, 1);
    expect(rtc.initializeCount, 0);

    await runtime.initializeRtcExplicitly();
    expect(rtc.initializeCount, 1);
    expect(rtc.joinCount, 0);

    await runtime.joinRtcExplicitly();
    expect(rtc.joinCount, 1);
    expect(runtime.currentState.phase, CallV2RuntimePhase.ready);

    await runtime.activateCall();
    expect(runtime.currentState.phase, CallV2RuntimePhase.active);

    await runtime.endCall();
    expect(rtc.leaveCount, 1);
    expect(runtime.currentState.phase, CallV2RuntimePhase.ended);
  });

  test('internal steps are blocked unless explicitly allowed', () async {
    final runtime = InternalCallV2Runtime(
      config: const CallV2RuntimeConfig.internalRealDevice(),
      permissionAdapter: FakeCallV2PermissionAdapter(),
      rtcAdapter: FakeCallV2RtcAdapter(),
      tokenProvider: FakeCallV2TokenProvider(),
    );
    addTearDown(runtime.dispose);

    await runtime.startOutgoingCall(mode: CallV2RuntimeCallMode.audio);
    await expectLater(
      runtime.requestPermissionsExplicitly(),
      throwsA(isA<CallV2ClientError>()),
    );
    expect(runtime.currentState.phase, CallV2RuntimePhase.permissionPreflight);
  });

  test('safe debug contains no sensitive wording', () {
    final runtime = InternalCallV2Runtime(
      config: _internalConfig,
      permissionAdapter: FakeCallV2PermissionAdapter(),
      rtcAdapter: FakeCallV2RtcAdapter(),
      tokenProvider: FakeCallV2TokenProvider(),
    );
    addTearDown(runtime.dispose);

    final debug = runtime.toSafeDebugMap().toString().toLowerCase();
    for (final forbidden in _forbiddenDebugFragments) {
      expect(debug, isNot(contains(forbidden)));
    }
  });
}

const _internalConfig = CallV2RuntimeConfig.internalRealDevice(
  allowPermissionRequests: true,
  allowTokenRequests: true,
  allowRtcInitialization: true,
  allowRtcJoin: true,
  exposeDevUi: true,
);

const _forbiddenDebugFragments = <String>[
  'token',
  'channel',
  'uid',
  'user',
  'callid',
  'device',
  'credential',
  'secret',
  'raw',
  'payload',
  'stack',
];
