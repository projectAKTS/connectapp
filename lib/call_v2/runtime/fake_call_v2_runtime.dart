import 'package:flutter/foundation.dart';

import '../call_v2_api.dart';
import '../firebase/call_v2_token_provider.dart';
import '../firebase/fake_call_v2_token_provider.dart';
import '../permissions/call_v2_permission_adapter.dart';
import '../permissions/fake_call_v2_permission_adapter.dart';
import '../rtc/call_v2_rtc_adapter.dart';
import '../rtc/fake_call_v2_rtc_adapter.dart';
import 'call_v2_runtime.dart';
import 'call_v2_runtime_state.dart';

class FakeCallV2Runtime extends ChangeNotifier implements CallV2Runtime {
  FakeCallV2Runtime({
    FakeCallV2PermissionAdapter? permissionAdapter,
    FakeCallV2RtcAdapter? rtcAdapter,
    FakeCallV2TokenProvider? tokenProvider,
  })  : permissionAdapter = permissionAdapter ?? FakeCallV2PermissionAdapter(),
        rtcAdapter = rtcAdapter ?? FakeCallV2RtcAdapter(),
        tokenProvider = tokenProvider ?? FakeCallV2TokenProvider();

  final FakeCallV2PermissionAdapter permissionAdapter;
  final FakeCallV2RtcAdapter rtcAdapter;
  final FakeCallV2TokenProvider tokenProvider;

  CallV2RuntimeState _currentState = CallV2RuntimeState.idle;
  bool _disposed = false;

  @override
  CallV2RuntimeState get currentState => _currentState;

  @override
  Future<void> startOutgoingCall({
    required CallV2RuntimeCallMode mode,
  }) async {
    _requireUsable();
    if (_currentState.phase != CallV2RuntimePhase.idle &&
        _currentState.phase != CallV2RuntimePhase.ended &&
        _currentState.phase != CallV2RuntimePhase.failed) {
      _fail(CallV2RuntimeErrorCategory.invalidState);
      return;
    }
    _setState(CallV2RuntimeState(
      phase: CallV2RuntimePhase.permissionPreflight,
      mode: mode,
      direction: CallV2RuntimeDirection.outgoing,
    ));
  }

  @override
  Future<void> acceptIncomingCall({
    required CallV2RuntimeCallMode mode,
  }) async {
    _requireUsable();
    _setState(CallV2RuntimeState(
      phase: CallV2RuntimePhase.permissionPreflight,
      mode: mode,
      direction: CallV2RuntimeDirection.incoming,
    ));
  }

  Future<void> requestRequiredPermissions() async {
    _requireUsable();
    final state = _currentState;
    if (state.phase != CallV2RuntimePhase.permissionPreflight) {
      _fail(CallV2RuntimeErrorCategory.invalidState);
      return;
    }
    _setState(state.copyWith(phase: CallV2RuntimePhase.requestingPermission));
    final microphone = await permissionAdapter.requestMicrophone();
    final camera = state.mode == CallV2RuntimeCallMode.video
        ? await permissionAdapter.requestCamera()
        : CallV2PermissionDecision.granted;
    if (microphone != CallV2PermissionDecision.granted ||
        camera != CallV2PermissionDecision.granted) {
      _fail(CallV2RuntimeErrorCategory.permissionDenied);
      return;
    }
    _setState(state.copyWith(phase: CallV2RuntimePhase.connecting));
  }

  Future<void> connectFakeRtc() async {
    _requireUsable();
    final state = _currentState;
    if (state.phase != CallV2RuntimePhase.connecting || state.mode == null) {
      _fail(CallV2RuntimeErrorCategory.invalidState);
      return;
    }
    try {
      final token = await tokenProvider.resolveToken(
        CallV2TokenRequest(mode: state.mode!),
      );
      await rtcAdapter.initialize(CallV2RtcSessionConfig(
        callId: 'fake-call',
        channelName: token.channelAlias,
        rtcUid: token.rtcUid,
        isVideo: state.mode == CallV2RuntimeCallMode.video,
        token: token.token,
      ));
      await rtcAdapter.joinChannel();
      _setState(state.copyWith(phase: CallV2RuntimePhase.ready));
    } catch (_) {
      _fail(CallV2RuntimeErrorCategory.rtcUnavailable);
    }
  }

  Future<void> activateCall() async {
    _requireUsable();
    final state = _currentState;
    if (state.phase != CallV2RuntimePhase.ready) {
      _fail(CallV2RuntimeErrorCategory.invalidState);
      return;
    }
    rtcAdapter.markActive();
    _setState(state.copyWith(phase: CallV2RuntimePhase.active));
  }

  @override
  Future<void> endCall() async {
    _requireUsable();
    final state = _currentState;
    if (state.phase == CallV2RuntimePhase.idle ||
        state.phase == CallV2RuntimePhase.ended) {
      return;
    }
    _setState(state.copyWith(phase: CallV2RuntimePhase.ending));
    await rtcAdapter.leaveChannel();
    _setState(state.copyWith(phase: CallV2RuntimePhase.ended));
  }

  void fail(CallV2RuntimeErrorCategory category) {
    _requireUsable();
    _fail(category);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await rtcAdapter.dispose();
    super.dispose();
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'state': _currentState.toSafeDebugMap(),
      'disposed': _disposed,
      'permission': permissionAdapter.toSafeDebugMap(),
      'rtc': rtcAdapter.toSafeDebugMap(),
      'accessResolveCount': tokenProvider.resolveCount,
    };
  }

  void _fail(CallV2RuntimeErrorCategory category) {
    _setState(_currentState.copyWith(
      phase: CallV2RuntimePhase.failed,
      errorCategory: category,
    ));
  }

  void _setState(CallV2RuntimeState state) {
    _currentState = state;
    notifyListeners();
  }

  void _requireUsable() {
    if (_disposed) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
  }
}
