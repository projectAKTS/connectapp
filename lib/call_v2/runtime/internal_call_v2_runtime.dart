import 'package:flutter/foundation.dart';

import '../call_v2_api.dart';
import '../firebase/call_v2_token_provider.dart';
import '../permissions/call_v2_permission_adapter.dart';
import '../rtc/call_v2_rtc_adapter.dart';
import '../rtc/call_v2_rtc_session_config_mapper.dart';
import 'call_v2_runtime.dart';
import 'call_v2_runtime_config.dart';
import 'call_v2_runtime_mode.dart';
import 'call_v2_runtime_state.dart';

class InternalCallV2Runtime extends ChangeNotifier implements CallV2Runtime {
  InternalCallV2Runtime({
    required this.config,
    required this.permissionAdapter,
    required this.rtcAdapter,
    required this.tokenProvider,
  });

  final CallV2RuntimeConfig config;
  final CallV2PermissionAdapter permissionAdapter;
  final CallV2RtcAdapter rtcAdapter;
  final CallV2TokenProvider tokenProvider;

  CallV2RuntimeState _currentState = CallV2RuntimeState.idle;
  CallV2TokenResult? _resolvedAccess;
  bool _setupReady = false;
  bool _joined = false;
  bool _disposed = false;

  @override
  CallV2RuntimeState get currentState => _currentState;

  bool get hasAccess => _resolvedAccess != null;

  bool get isRtcInitialized => _setupReady;

  bool get isRtcJoined => _joined;

  bool get isDisposed => _disposed;

  @override
  Future<void> startOutgoingCall({
    required CallV2RuntimeCallMode mode,
  }) async {
    _requireUsable();
    _requireInternalMode();
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
    _requireInternalMode();
    _setState(CallV2RuntimeState(
      phase: CallV2RuntimePhase.permissionPreflight,
      mode: mode,
      direction: CallV2RuntimeDirection.incoming,
    ));
  }

  Future<void> requestPermissionsExplicitly() async {
    _requireUsable();
    _requireAllowed(config.allowPermissionRequests);
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

  Future<void> requestTokenExplicitly() async {
    _requireUsable();
    _requireAllowed(config.allowTokenRequests);
    final state = _currentState;
    if (state.phase != CallV2RuntimePhase.connecting || state.mode == null) {
      _fail(CallV2RuntimeErrorCategory.invalidState);
      return;
    }
    try {
      _resolvedAccess = await tokenProvider.resolveToken(
        CallV2TokenRequest(mode: state.mode!),
      );
      _setState(state.copyWith(phase: CallV2RuntimePhase.connecting));
    } catch (_) {
      _fail(CallV2RuntimeErrorCategory.backendUnavailable);
    }
  }

  Future<void> initializeRtcExplicitly() async {
    _requireUsable();
    _requireAllowed(config.allowRtcInitialization);
    final state = _currentState;
    final access = _resolvedAccess;
    if (state.phase != CallV2RuntimePhase.connecting ||
        state.mode == null ||
        access == null) {
      _fail(CallV2RuntimeErrorCategory.invalidState);
      return;
    }
    try {
      final mapping = CallV2RtcSessionConfigMapping(
        config: CallV2RtcSessionConfig(
          callId: 'internal-dev-session',
          channelName: access.channelAlias,
          rtcUid: access.rtcUid,
          isVideo: state.mode == CallV2RuntimeCallMode.video,
          token: access.token,
        ),
      );
      await rtcAdapter.initialize(mapping.config);
      _setupReady = true;
    } catch (_) {
      _fail(CallV2RuntimeErrorCategory.rtcUnavailable);
    }
  }

  Future<void> joinRtcExplicitly() async {
    _requireUsable();
    _requireAllowed(config.allowRtcJoin);
    final state = _currentState;
    if (state.phase != CallV2RuntimePhase.connecting || !_setupReady) {
      _fail(CallV2RuntimeErrorCategory.invalidState);
      return;
    }
    try {
      await rtcAdapter.joinChannel();
      _joined = true;
      _setState(state.copyWith(phase: CallV2RuntimePhase.ready));
    } catch (_) {
      _fail(CallV2RuntimeErrorCategory.rtcUnavailable);
    }
  }

  Future<void> activateCall() async {
    _requireUsable();
    final state = _currentState;
    if (state.phase != CallV2RuntimePhase.ready || !_joined) {
      _fail(CallV2RuntimeErrorCategory.invalidState);
      return;
    }
    _setState(state.copyWith(phase: CallV2RuntimePhase.active));
  }

  @override
  Future<void> endCall() async {
    if (_disposed) return;
    _requireUsable();
    final state = _currentState;
    if (state.phase == CallV2RuntimePhase.idle ||
        state.phase == CallV2RuntimePhase.ended) {
      return;
    }
    _setState(state.copyWith(phase: CallV2RuntimePhase.ending));
    if (_joined) {
      await rtcAdapter.leaveChannel();
    }
    _joined = false;
    _setupReady = false;
    _resolvedAccess = null;
    _setState(state.copyWith(phase: CallV2RuntimePhase.ended));
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
      'config': config.toSafeDebugMap(),
      'accessReady': _resolvedAccess != null,
      'setupReady': _setupReady,
      'joined': _joined,
      'disposed': _disposed,
    };
  }

  void _requireInternalMode() {
    _requireAllowed(config.mode == CallV2RuntimeMode.internalRealDevice);
  }

  void _requireAllowed(bool allowed) {
    if (!allowed || !config.canUseInternalRealDevice) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
  }

  void _requireUsable() {
    if (_disposed) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
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
}
