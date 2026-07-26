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
    expect(runtime.hasAccess, isTrue);

    await runtime.initializeRtcExplicitly();
    expect(rtc.initializeCount, 1);
    expect(runtime.isRtcInitialized, isTrue);
    expect(rtc.joinCount, 0);

    await runtime.joinRtcExplicitly();
    expect(rtc.joinCount, 1);
    expect(runtime.isRtcJoined, isTrue);
    expect(runtime.currentState.phase, CallV2RuntimePhase.ready);

    await runtime.activateCall();
    expect(runtime.currentState.phase, CallV2RuntimePhase.active);

    await runtime.endCall();
    expect(rtc.leaveCount, 1);
    expect(runtime.hasAccess, isFalse);
    expect(runtime.isRtcInitialized, isFalse);
    expect(runtime.isRtcJoined, isFalse);
    expect(runtime.currentState.phase, CallV2RuntimePhase.ended);
  });

  test('token permission RTC init and join failures are controlled', () async {
    final tokenFailure = InternalCallV2Runtime(
      config: _internalConfig,
      permissionAdapter: FakeCallV2PermissionAdapter(),
      rtcAdapter: FakeCallV2RtcAdapter(),
      tokenProvider: FakeCallV2TokenProvider(fail: true),
    );
    final initFailure = InternalCallV2Runtime(
      config: _internalConfig,
      permissionAdapter: FakeCallV2PermissionAdapter(),
      rtcAdapter: FakeCallV2RtcAdapter(failInitialize: true),
      tokenProvider: FakeCallV2TokenProvider(),
    );
    final joinFailure = InternalCallV2Runtime(
      config: _internalConfig,
      permissionAdapter: FakeCallV2PermissionAdapter(),
      rtcAdapter: FakeCallV2RtcAdapter(failJoin: true),
      tokenProvider: FakeCallV2TokenProvider(),
    );
    addTearDown(tokenFailure.dispose);
    addTearDown(initFailure.dispose);
    addTearDown(joinFailure.dispose);

    await tokenFailure.startOutgoingCall(mode: CallV2RuntimeCallMode.audio);
    await tokenFailure.requestPermissionsExplicitly();
    await tokenFailure.requestTokenExplicitly();
    expect(tokenFailure.currentState.errorCategory,
        CallV2RuntimeErrorCategory.backendUnavailable);

    await initFailure.startOutgoingCall(mode: CallV2RuntimeCallMode.audio);
    await initFailure.requestPermissionsExplicitly();
    await initFailure.requestTokenExplicitly();
    await initFailure.initializeRtcExplicitly();
    expect(initFailure.currentState.errorCategory,
        CallV2RuntimeErrorCategory.rtcUnavailable);

    await joinFailure.startOutgoingCall(mode: CallV2RuntimeCallMode.audio);
    await joinFailure.requestPermissionsExplicitly();
    await joinFailure.requestTokenExplicitly();
    await joinFailure.initializeRtcExplicitly();
    await joinFailure.joinRtcExplicitly();
    expect(joinFailure.currentState.errorCategory,
        CallV2RuntimeErrorCategory.rtcUnavailable);
  });

  test('dispose and end are idempotent', () async {
    final rtc = FakeCallV2RtcAdapter();
    final runtime = InternalCallV2Runtime(
      config: _internalConfig,
      permissionAdapter: FakeCallV2PermissionAdapter(),
      rtcAdapter: rtc,
      tokenProvider: FakeCallV2TokenProvider(),
    );

    await runtime.dispose();
    await runtime.dispose();
    await runtime.endCall();

    expect(runtime.isDisposed, isTrue);
    expect(rtc.disposeCount, 1);
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
  'participant',
  'callid',
  'device',
  'credential',
  'secret',
  'raw',
  'payload',
  'stack',
];
