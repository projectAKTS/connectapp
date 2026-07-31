// ignore_for_file: implementation_imports, depend_on_referenced_packages, invalid_use_of_visible_for_testing_member
// lib/call/agora_call_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_rtc_engine/src/impl/agora_rtc_engine_impl.dart'
    as agora_internal;
import 'package:agora_rtc_engine/src/impl/platform/platform_bindings_provider.dart'
    show createPlatformBindingsProvider;
import 'package:connect_app/call_v2/firebase/call_v2_dev_callable_target.dart';
import 'package:connect_app/call_v2/firebase/call_v2_token_provider.dart';
import 'package:connect_app/call_v2/firebase/real_call_v2_token_provider.dart';
import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/real_flow/call_v2_real_call_flow_gate.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_state.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connect_app/services/call_session_manager.dart';
import 'package:connect_app/services/callkit_id.dart';
import 'package:connect_app/services/diagnostic_service.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:iris_method_channel/iris_method_channel.dart'
    show IrisMethodChannel;
import 'package:path_provider/path_provider.dart';

class AgoraJoinAuth {
  final String token;
  final String appId;
  final String channelName;
  final int uid;
  final String userAccount;
  final String tokenVersion;
  final String identityMode;
  const AgoraJoinAuth({
    required this.token,
    required this.appId,
    required this.channelName,
    required this.uid,
    required this.userAccount,
    required this.tokenVersion,
    required this.identityMode,
  });
}

const String _agoraFallbackAppId = 'dac900a04a87460c87c3d18b63cac65d';
const String _agoraFlutterPluginVersion = '6.5.2';
const int _agoraLogFileSizeInKB = 512;
const VideoDimensions _videoCallDimensions =
    VideoDimensions(width: 720, height: 960);
const VideoFormat _videoCallCaptureFormat =
    VideoFormat(width: 720, height: 960, fps: 24);
const int _videoCallFrameRate = 24;
const int _videoCallBitrate = standardBitrate;
const int _videoCallMinBitrate = defaultMinBitrate;
// iOS texture rendering fixed black screens earlier, but it also softens both
// local preview and remote video on real devices. Prefer the native view path.
const bool _preferFlutterTextureRendererOnIOS = false;

/// ---- TOKEN + APPID FETCH ----
Future<AgoraJoinAuth> fetchAgoraToken({
  required String channelName,
  required int uid,
  required String userAccount,
  String identityMode = 'uid',
  bool allowUidZero = false,
}) async {
  final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
      .httpsCallable('getAgoraRtcToken');
  final resp = await callable.call({
    'channelName': channelName,
    'uid': uid,
    'userAccount': userAccount,
    'identityMode': identityMode,
    'allowUidZero': allowUidZero,
    'role': 'publisher',
    'expireSeconds': 3600,
  });
  final data = (resp.data as Map?) ?? const {};
  final token = (data['token'] as String?)?.trim();
  final serverAppId = (data['appId'] as String?)?.trim();
  final serverUidRaw = data['uid'];
  final serverUserAccount = (data['userAccount'] as String?)?.trim();
  final tokenVersion = (data['tokenVersion'] as String?)?.trim() ?? '';
  final tokenIdentityMode =
      (data['tokenIdentityMode'] as String?)?.trim() ?? identityMode;
  final serverUid = serverUidRaw is num ? serverUidRaw.toInt() : uid;
  if (token == null || token.isEmpty) {
    throw Exception('Token service returned empty token');
  }
  final detectedVersion = tokenVersion.isNotEmpty
      ? tokenVersion
      : (token.length >= 3 ? token.substring(0, 3) : token);
  return AgoraJoinAuth(
    token: token,
    appId: (serverAppId == null || serverAppId.isEmpty)
        ? _agoraFallbackAppId
        : serverAppId,
    channelName: channelName,
    uid: serverUid,
    userAccount: (serverUserAccount == null || serverUserAccount.isEmpty)
        ? userAccount
        : serverUserAccount,
    tokenVersion: detectedVersion,
    identityMode: tokenIdentityMode,
  );
}

Future<AgoraJoinAuth> fetchCallV2DevAgoraToken({
  required String callIdentifier,
  required String participantIdentifier,
  required bool isVideo,
  CallV2DevCallableTarget devCallableTarget =
      const FirebaseCallV2DevCallableTarget(),
}) async {
  final transport = await devCallableTarget.createTransport();
  final provider = RealCallV2TokenProvider(
    allowRequests: true,
    transport: transport,
    defaultRequest: CallV2TokenBackendRequest(
      callId: callIdentifier,
      localParticipantUid: participantIdentifier,
    ),
  );
  final result = await provider.resolveToken(
    CallV2TokenRequest(
      mode: isVideo ? CallV2RuntimeCallMode.video : CallV2RuntimeCallMode.audio,
    ),
  );
  return AgoraJoinAuth(
    token: result.token,
    appId: result.appId,
    channelName: result.channelAlias,
    uid: result.rtcUid,
    userAccount: result.rtcUid.toString(),
    tokenVersion: 'v2',
    identityMode: 'uid',
  );
}

class AgoraCallScreen extends StatefulWidget {
  final String channelName;
  final bool isVideo;
  final String otherUserName;
  final String? otherUserId;
  final String? inviteId;
  final bool isCaller;
  final CallV2RealCallConnectionSystem connectionSystem;
  final bool callV2FallbackUsed;
  final String callV2BlockerCode;

  const AgoraCallScreen({
    super.key,
    required this.channelName,
    required this.isVideo,
    required this.otherUserName,
    this.otherUserId,
    this.inviteId,
    this.isCaller = false,
    this.connectionSystem = CallV2RealCallConnectionSystem.legacyV1,
    this.callV2FallbackUsed = false,
    this.callV2BlockerCode = 'none',
  });

  @override
  State<AgoraCallScreen> createState() => _AgoraCallScreenState();
}

class _AgoraCallScreenState extends State<AgoraCallScreen> {
  static const MethodChannel _pushTokenChannel =
      MethodChannel('connectapp/pushTokens');
  static Future<void> _lastEngineShutdown = Future<void>.value();
  static const bool _testMode =
      bool.fromEnvironment('HELPERLY_TEST_MODE', defaultValue: false);
  static const Duration _engineInitializeTimeout = Duration(seconds: 30);
  static const Duration _joinWatchdogTimeout = Duration(seconds: 35);
  RtcEngine? _engine;
  RtcEngineEventHandler? _eventHandler;
  String? _token;
  String? _agoraAppId;
  String? _joinedChannelName;
  int _rtcUid = 0;
  String? _seenTerminalInviteStatus;

  bool _joined = false;
  int? _remoteUid;
  bool _ended = false;
  bool _endingCall = false;
  bool _isLoading = true;
  String? _fatalError;
  String _endedMessage = 'Call ended';

  // Controls
  bool _muted = false;
  bool _speakerOn = true;
  bool _speakerRouteExplicitlyChanged = false;
  bool _frontCamera = true;
  bool _localVideoReady = false;
  bool _remoteVideoReady = false;
  bool _remoteVideoMuted = false;
  bool _loggedLocalVideoQualityWarning = false;
  bool _loggedRemoteVideoQualityWarning = false;

  // Video layout state
  bool _localIsBig = true; // show self first while waiting
  Offset _pipPos = const Offset(12, 120); // PiP top-left corner

  Timer? _ringTimeout;
  Timer? _joinWatchdog;
  Timer? _autoCloseTimer;
  bool _remoteEverJoined = false;
  bool _missedLogged = false;
  bool _callkitMarkedConnected = false;
  bool _nativeAcceptedCallCleared = false;
  bool _callV2CallableAttempted = false;
  bool _callV2CallableReached = false;
  bool _callV2TokenReady = false;
  bool _callV2AppIdReady = false;
  bool _callV2AccessReady = false;
  bool _callV2RtcInitialized = false;
  bool _callV2JoinAttempted = false;
  bool _callV2RtcJoined = false;
  bool _callV2RemoteJoined = false;
  bool _callV2MediaActive = false;
  String _callV2BlockerCode = 'none';
  String _callV2AgoraErrorCode = 'none';
  String _callV2ConnectionState = 'none';
  String _callV2ConnectionReason = 'none';

  bool get _useFlutterTextureRenderer =>
      Platform.isIOS && _preferFlutterTextureRendererOnIOS;

  bool get _callV2Selected {
    return widget.connectionSystem == CallV2RealCallConnectionSystem.callV2Dev;
  }

  bool get _showCallV2SafeStatus {
    return _callV2Selected || widget.callV2FallbackUsed;
  }

  CallV2RealCallFlowConfig get _callV2RealFlowConfig {
    return const CallV2RealCallFlowConfig();
  }

  String get _videoRendererLabel =>
      _useFlutterTextureRenderer ? 'texture' : 'platform_view';

  int _deriveRtcUidFromFirebaseUid(String firebaseUid) {
    if (firebaseUid.isEmpty) return 1;
    var hash = 0x811c9dc5;
    for (final codeUnit in firebaseUid.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    final positive = hash & 0x7FFFFFFF;
    return (positive % 2147483646) + 1;
  }

  String get _callkitId {
    return normalizeCallkitId(
      rawId: widget.inviteId ?? '',
      fallback: widget.channelName,
    );
  }

  Future<void> _markCallkitConnected() async {
    if (_callkitMarkedConnected) return;
    final id = _callkitId;
    if (id.isEmpty) return;
    try {
      await FlutterCallkitIncoming.setCallConnected(id);
      _callkitMarkedConnected = true;
    } catch (_) {}
  }

  Future<void> _markCallkitConnectedForAcceptedCall() async {
    if (widget.isCaller) return;
    try {
      await _markCallkitConnected();
      if (_callkitMarkedConnected) {
        await _diagCall('callkit_connected_marked', meta: {
          'source': 'accepted_call_start',
        });
      }
    } catch (e) {
      await _diagCall('callkit_connected_error', meta: {
        'source': 'accepted_call_start',
        'error': '$e',
      });
    }
  }

  Future<void> _clearStoredAcceptedCallRecovery() async {
    if (_nativeAcceptedCallCleared) return;
    _nativeAcceptedCallCleared = true;
    if (_testMode) return;
    try {
      await _pushTokenChannel.invokeMethod('clearStoredAcceptedCall');
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _callV2BlockerCode = widget.callV2BlockerCode;
    CallSessionManager.instance.terminalSignal
        .addListener(_handleManagerTerminalSignal);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleManagerTerminalSignal();
      unawaited(_begin());
    });
  }

  void _handleManagerTerminalSignal() {
    if (!mounted) return;
    final signal = CallSessionManager.instance.terminalSignal.value;
    if (signal == null) return;
    final inviteId = (widget.inviteId ?? '').trim();
    if (inviteId.isEmpty || signal.inviteId != inviteId) return;
    if (_seenTerminalInviteStatus == signal.status &&
        (_ended || _fatalError != null)) {
      return;
    }
    _seenTerminalInviteStatus = signal.status;
    _ringTimeout?.cancel();
    _joinWatchdog?.cancel();
    setState(() {
      _isLoading = false;
      _ended = true;
      _fatalError = signal.isError ? signal.message : null;
      _endedMessage = signal.message;
      _remoteVideoReady = false;
      _remoteVideoMuted = false;
    });
    _scheduleAutoClose('manager_terminal_${signal.status}');
  }

  Future<void> _diagCall(
    String stage, {
    Map<String, dynamic>? meta,
    int metaLimit = 500,
  }) async {
    final safeMeta = _safeAgoraDiagMeta(<String, dynamic>{
      'callV2Selected': _callV2Selected,
      'isCaller': widget.isCaller,
      ...?meta,
    });
    final metaStr = safeMeta.toString();
    final payload = <String, dynamic>{
      'stage': stage,
      'meta': metaStr.length > metaLimit
          ? metaStr.substring(0, metaLimit)
          : metaStr,
    };
    debugPrint('[DIAG][call] $stage meta=${payload['meta']}');
    final uid = HelperlyTestRuntime.currentUid ??
        FirebaseAuth.instance.currentUser?.uid;
    DiagnosticService.logCall(
      stage,
      uid: uid,
      meta: payload['meta'],
      counters: CallSessionManager.instance.debugResourceCounts(),
    );
  }

  Future<void> _forceVideoAudioState(
    RtcEngine engine, {
    required String source,
  }) async {
    if (!widget.isVideo) return;
    try {
      await engine.enableAudio();
      await engine.enableLocalAudio(true);
      await engine.muteLocalAudioStream(false);
      await _diagCall('video_audio_forced_enabled', meta: {'source': source});

      await engine.muteAllRemoteAudioStreams(false);
      await engine.adjustPlaybackSignalVolume(100);
      await engine.adjustRecordingSignalVolume(100);
      await _diagCall('remote_audio_unmuted', meta: {'source': source});

      if (!_speakerRouteExplicitlyChanged) {
        await engine.setEnableSpeakerphone(true);
        _speakerOn = true;
        if (mounted) {
          setState(() {});
        }
        await _diagCall('speakerphone_forced_on', meta: {'source': source});
      }
    } catch (e) {
      await _diagCall('video_audio_force_error', meta: {
        'source': source,
        'error': '$e',
      });
    }
  }

  Future<List<String>> _activeCallkitIds() async {
    try {
      final activeCalls = await FlutterCallkitIncoming.activeCalls();
      if (activeCalls is! List) return const <String>[];
      final ids = <String>[];
      for (final raw in activeCalls) {
        if (raw is! Map) continue;
        final body = Map<String, dynamic>.from(raw);
        final extraRaw = body['extra'];
        final extra = extraRaw is Map
            ? Map<String, dynamic>.from(extraRaw)
            : const <String, dynamic>{};
        final rawId = [
          extra['id'],
          extra['callkitId'],
          body['id'],
          body['callkitId'],
          body['uuid'],
          body['channel'],
        ]
            .whereType<String>()
            .map((v) => v.trim())
            .firstWhere((v) => v.isNotEmpty, orElse: () => '');
        if (rawId.isEmpty) continue;
        ids.add(normalizeCallkitId(rawId: rawId, fallback: widget.channelName));
      }
      return ids.toSet().where((id) => id.isNotEmpty).toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _cleanupCallkitUi({required String reason}) async {
    if (_testMode) {
      await _diagCall('callkit_cleanup_start', meta: {
        'reason': reason,
        'testMode': true,
      });
      await _diagCall('callkit_active_before', meta: {
        'reason': reason,
        'count': 0,
        'ids': '',
        'testMode': true,
      });
      await _diagCall('callkit_end_all_done', meta: {
        'reason': reason,
        'testMode': true,
      });
      await _diagCall('callkit_active_after', meta: {
        'reason': reason,
        'count': 0,
        'ids': '',
        'testMode': true,
      });
      return;
    }
    await _diagCall('callkit_cleanup_start', meta: {'reason': reason});
    final before = await _activeCallkitIds();
    await _diagCall('callkit_active_before', meta: {
      'reason': reason,
      'count': before.length,
      'ids': before.join(','),
    });

    final callkitId = _callkitId;
    if (callkitId.isNotEmpty) {
      try {
        await FlutterCallkitIncoming.endCall(callkitId);
      } catch (_) {}
    }
    try {
      await FlutterCallkitIncoming.endAllCalls();
      await _diagCall('callkit_end_all_done', meta: {'reason': reason});
    } catch (e) {
      await _diagCall('callkit_end_all_error', meta: {
        'reason': reason,
        'error': '$e',
      });
    }

    await Future<void>.delayed(const Duration(milliseconds: 400));
    final remaining = await _activeCallkitIds();
    for (final id in remaining) {
      try {
        await FlutterCallkitIncoming.endCall(id);
      } catch (_) {}
    }
    if (remaining.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    final after = await _activeCallkitIds();
    await _diagCall('callkit_active_after', meta: {
      'reason': reason,
      'count': after.length,
      'ids': after.join(','),
    });
  }

  Future<void> _begin() async {
    final channel = widget.channelName;
    try {
      await _diagCall('begin_start', meta: {'isVideo': widget.isVideo});
      if (_testMode) {
        await _beginInTestMode();
        return;
      }
      await _lastEngineShutdown;
      await _diagCall('engine_wait_previous_shutdown');
      await _diagCall('engine_precleanup_done');

      await _ensurePermission(Permission.microphone, 'Microphone');
      await _diagCall('mic_permission_ok');
      if (widget.isVideo) {
        await _ensurePermission(Permission.camera, 'Camera');
        await _diagCall('camera_permission_ok');
      }

      final inviteId = (widget.inviteId ?? '').trim();
      if (inviteId.isNotEmpty) {
        await CallSessionManager.instance.reportCallScreenBegan(
          inviteId: inviteId,
          isCaller: widget.isCaller,
        );
      }
      await _markCallkitConnectedForAcceptedCall();

      final currentUserUid = HelperlyTestRuntime.currentUid ??
          FirebaseAuth.instance.currentUser?.uid;
      final requestedUid = _deriveRtcUidFromFirebaseUid(currentUserUid ?? '');
      final requestedUserAccount = requestedUid.toString();

      late final AgoraJoinAuth auth;
      if (_callV2Selected) {
        if (mounted) {
          setState(() {
            _callV2CallableAttempted = true;
          });
        } else {
          _callV2CallableAttempted = true;
        }
        try {
          auth = await fetchCallV2DevAgoraToken(
            callIdentifier: inviteId.isNotEmpty ? inviteId : channel,
            participantIdentifier: currentUserUid ?? requestedUserAccount,
            isVideo: widget.isVideo,
          );
        } on CallV2ClientError catch (error) {
          _setCallV2BlockerCode('callable_${error.code.name}');
          rethrow;
        } catch (_) {
          _setCallV2BlockerCode('callable_unavailable');
          rethrow;
        }
      } else {
        auth = await fetchAgoraToken(
          channelName: channel,
          uid: requestedUid,
          userAccount: requestedUserAccount,
          identityMode: 'uid',
        );
      }
      _token = auth.token;
      _agoraAppId = auth.appId;
      _joinedChannelName = auth.channelName;
      _rtcUid = auth.uid > 0 ? auth.uid : requestedUid;
      if (_callV2Selected) {
        _callV2CallableReached = true;
        _callV2TokenReady = auth.token.isNotEmpty;
        _callV2AppIdReady = isCallV2AgoraAppId(auth.appId);
        _callV2AccessReady = true;
        _callV2BlockerCode = 'none';
      }
      await _diagCall('token_ok', meta: {
        'callV2Selected': _callV2Selected,
        'accessReady': _callV2Selected ? _callV2AccessReady : true,
        'appIdReady': _callV2Selected ? _callV2AppIdReady : true,
        'tokenIdentityMode': auth.identityMode,
        'tokenVersion': auth.tokenVersion,
        'appIdSource': auth.appId.toLowerCase() == _agoraFallbackAppId
            ? 'server_matches_fallback'
            : (_callV2Selected ? 'call_v2_dev_config' : 'server'),
        'serverAppIdLen': auth.appId.length,
        'serverAppIdMatchesFallback':
            auth.appId.toLowerCase() == _agoraFallbackAppId,
      });

      final engine = await _createAndInitializeEngine();
      if (_callV2Selected) {
        _callV2RtcInitialized = true;
      }
      await _diagCall('engine_initialized');

      await engine.enableAudio();
      await engine.enableLocalAudio(true);
      await engine.muteLocalAudioStream(false);
      await engine.setAudioProfile(
        profile: AudioProfileType.audioProfileDefault,
        scenario: AudioScenarioType.audioScenarioDefault,
      );
      await _diagCall('audio_enabled');

      if (widget.isVideo) {
        await engine.enableVideo();
        await engine.enableLocalVideo(true);
        await engine.muteLocalVideoStream(false);
        await _configureVideoPipeline(engine);
        await _diagCall('video_enabled');
      } else {
        await engine.disableVideo();
      }

      await engine.setChannelProfile(
        ChannelProfileType.channelProfileCommunication,
      );
      await engine.setClientRole(
        role: ClientRoleType.clientRoleBroadcaster,
      );
      await engine.setDefaultAudioRouteToSpeakerphone(true);
      if (widget.isVideo) {
        await _forceVideoAudioState(engine, source: 'begin');
      }
      await _diagCall('channel_profile_set', meta: {
        'profile': 'communication',
        'source': 'engine_and_join_options',
      });

      final handler = RtcEngineEventHandler(
        onError: (ErrorCodeType err, String msg) {
          _diagCall('agora_error', meta: {'code': '$err', 'msg': msg});
          if (_callV2Selected && mounted) {
            setState(() {
              _callV2AgoraErrorCode = _safeAgoraDiagString('$err');
              _callV2BlockerCode = 'agora_error';
            });
          } else if (_callV2Selected) {
            _callV2AgoraErrorCode = _safeAgoraDiagString('$err');
            _callV2BlockerCode = 'agora_error';
          }
          if (!_joined && mounted && !_ended) {
            setState(() {
              _fatalError = 'Call connection failed. Please try again.';
            });
          }
        },
        onConnectionLost: (RtcConnection connection) {
          _diagCall('conn_lost', meta: {
            'channel': connection.channelId ?? '',
            'localUid': connection.localUid ?? -1,
          });
        },
        onConnectionStateChanged: (
          RtcConnection connection,
          ConnectionStateType state,
          ConnectionChangedReasonType reason,
        ) {
          _diagCall('conn_state_changed', meta: {
            'channel': connection.channelId ?? '',
            'localUid': connection.localUid ?? -1,
            'state': '$state',
            'reason': '$reason',
          });
          if (_callV2Selected && mounted) {
            setState(() {
              _callV2ConnectionState = _safeAgoraDiagString('$state');
              _callV2ConnectionReason = _safeAgoraDiagString('$reason');
              if (state == ConnectionStateType.connectionStateFailed) {
                _callV2BlockerCode = 'connection_failed';
              }
            });
          } else if (_callV2Selected) {
            _callV2ConnectionState = _safeAgoraDiagString('$state');
            _callV2ConnectionReason = _safeAgoraDiagString('$reason');
            if (state == ConnectionStateType.connectionStateFailed) {
              _callV2BlockerCode = 'connection_failed';
            }
          }
          if (!_joined &&
              !_ended &&
              mounted &&
              state == ConnectionStateType.connectionStateFailed) {
            setState(() {
              _fatalError = 'Call network failed. Please try again.';
            });
          }
        },
        onNetworkTypeChanged: (RtcConnection connection, NetworkType type) {
          _diagCall('network_type_changed', meta: {
            'channel': connection.channelId ?? '',
            'localUid': connection.localUid ?? -1,
            'type': '$type',
          });
        },
        onProxyConnected: (
          String channel,
          int uid,
          ProxyType proxyType,
          String localProxyIp,
          int elapsed,
        ) {
          _diagCall('proxy_connected', meta: {
            'channel': channel,
            'uid': uid,
            'proxyType': '$proxyType',
            'localProxyIp': localProxyIp,
            'elapsedMs': elapsed,
          });
        },
        onRequestToken: (RtcConnection connection) {
          _diagCall('token_requested', meta: {
            'channel': connection.channelId ?? '',
            'localUid': connection.localUid ?? -1,
          });
        },
        onLocalUserRegistered: (int uid, String userAccount) {
          _diagCall('local_user_registered', meta: {
            'uid': uid,
            'userAccount': userAccount,
          });
        },
        onUserInfoUpdated: (int uid, UserInfo info) {
          _diagCall('user_info_updated', meta: {
            'uid': uid,
            'infoUid': info.uid,
            'userAccount': info.userAccount,
          });
        },
        onUserAccountUpdated: (
          RtcConnection connection,
          int remoteUid,
          String remoteUserAccount,
        ) {
          _diagCall('user_account_updated', meta: {
            'channel': connection.channelId ?? '',
            'localUid': connection.localUid ?? -1,
            'remoteUid': remoteUid,
            'remoteUserAccount': remoteUserAccount,
          });
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          _diagCall('token_will_expire', meta: {
            'channel': connection.channelId ?? '',
            'localUid': connection.localUid ?? -1,
            'tokenVersion': token.length >= 3 ? token.substring(0, 3) : token,
          });
        },
        onUserMuteAudio: (RtcConnection connection, int remoteUid, bool muted) {
          _diagCall('user_mute_audio', meta: {
            'remoteUid': remoteUid,
            'muted': muted,
          });
        },
        onRemoteAudioStateChanged: (
          RtcConnection connection,
          int remoteUid,
          RemoteAudioState state,
          RemoteAudioStateReason reason,
          int elapsed,
        ) {
          final mediaActive =
              state == RemoteAudioState.remoteAudioStateDecoding;
          if (_callV2Selected && mounted) {
            setState(() {
              _callV2MediaActive = mediaActive;
              if (state == RemoteAudioState.remoteAudioStateFailed) {
                _callV2BlockerCode = 'remote_audio_failed';
              }
            });
          } else if (_callV2Selected) {
            _callV2MediaActive = mediaActive;
            if (state == RemoteAudioState.remoteAudioStateFailed) {
              _callV2BlockerCode = 'remote_audio_failed';
            }
          }
          _diagCall('remote_audio_state', meta: {
            'remoteUid': remoteUid,
            'state': '$state',
            'reason': '$reason',
            'elapsedMs': elapsed,
          });
        },
        onAudioRoutingChanged: (int routing) {
          _diagCall('audio_routing_changed', meta: {
            'routing': routing,
          });
        },
        onLocalAudioStateChanged: (
          RtcConnection connection,
          LocalAudioStreamState state,
          LocalAudioStreamReason reason,
        ) {
          _diagCall('local_audio_state', meta: {
            'state': '$state',
            'reason': '$reason',
          });
        },
        onLocalVideoStateChanged: (
          VideoSourceType source,
          LocalVideoStreamState state,
          LocalVideoStreamReason reason,
        ) {
          final ready =
              state == LocalVideoStreamState.localVideoStreamStateCapturing ||
                  state == LocalVideoStreamState.localVideoStreamStateEncoding;
          if (mounted) {
            setState(() {
              _localVideoReady = ready;
            });
          }
          _diagCall('local_video_state', meta: {
            'source': '$source',
            'state': '$state',
            'reason': '$reason',
          });
        },
        onLocalVideoStats: (RtcConnection connection, LocalVideoStats stats) {
          final adapt = stats.qualityAdaptIndication;
          final txPacketLossRate = stats.txPacketLossRate ?? 0;
          final encodedWidth = stats.encodedFrameWidth ?? 0;
          final encodedHeight = stats.encodedFrameHeight ?? 0;
          final shouldWarn =
              adapt == QualityAdaptIndication.adaptDownBandwidth ||
                  txPacketLossRate >= 6 ||
                  (encodedWidth > 0 &&
                      encodedHeight > 0 &&
                      (encodedWidth < 480 || encodedHeight < 480));
          if (_loggedLocalVideoQualityWarning || !shouldWarn) return;
          _loggedLocalVideoQualityWarning = true;
          _diagCall('video_quality_warning_local', meta: {
            'localUid': connection.localUid ?? -1,
            'sentBitrateKbps': stats.sentBitrate ?? -1,
            'sentFrameRate': stats.sentFrameRate ?? -1,
            'targetBitrateKbps': stats.targetBitrate ?? -1,
            'targetFrameRate': stats.targetFrameRate ?? -1,
            'encodedWidth': encodedWidth,
            'encodedHeight': encodedHeight,
            'txPacketLossRate': txPacketLossRate,
            'qualityAdapt': '$adapt',
            'hwEncoderAccelerating': stats.hwEncoderAccelerating ?? -1,
          });
        },
        onFirstLocalVideoFrame: (
          VideoSourceType source,
          int width,
          int height,
          int elapsed,
        ) {
          if (mounted) {
            setState(() {
              _localVideoReady = true;
            });
          }
          _diagCall('first_local_video_frame', meta: {
            'source': '$source',
            'width': width,
            'height': height,
            'elapsedMs': elapsed,
          });
        },
        onFirstLocalVideoFramePublished: (
          RtcConnection connection,
          int elapsed,
        ) {
          _diagCall('first_local_video_frame_published', meta: {
            'localUid': connection.localUid ?? -1,
            'elapsedMs': elapsed,
          });
        },
        onRemoteVideoStateChanged: (
          RtcConnection connection,
          int remoteUid,
          RemoteVideoState state,
          RemoteVideoStateReason reason,
          int elapsed,
        ) {
          final ready = state == RemoteVideoState.remoteVideoStateDecoding;
          if (mounted && _remoteUid == remoteUid) {
            setState(() {
              _remoteVideoReady = ready;
            });
          }
          _diagCall('remote_video_state', meta: {
            'remoteUid': remoteUid,
            'state': '$state',
            'reason': '$reason',
            'elapsedMs': elapsed,
          });
        },
        onRemoteVideoStats: (RtcConnection connection, RemoteVideoStats stats) {
          final packetLossRate = stats.packetLossRate ?? 0;
          final frozenRate = stats.frozenRate ?? 0;
          final width = stats.width ?? 0;
          final height = stats.height ?? 0;
          final shouldWarn = packetLossRate >= 6 ||
              frozenRate >= 8 ||
              (width > 0 && height > 0 && (width < 480 || height < 480));
          if (_loggedRemoteVideoQualityWarning || !shouldWarn) return;
          _loggedRemoteVideoQualityWarning = true;
          _diagCall('video_quality_warning_remote', meta: {
            'remoteUid': stats.uid ?? -1,
            'receivedBitrateKbps': stats.receivedBitrate ?? -1,
            'decoderOutputFrameRate': stats.decoderOutputFrameRate ?? -1,
            'rendererOutputFrameRate': stats.rendererOutputFrameRate ?? -1,
            'width': width,
            'height': height,
            'packetLossRate': packetLossRate,
            'frozenRate': frozenRate,
            'streamType': '${stats.rxStreamType}',
            'e2eDelayMs': stats.e2eDelay ?? -1,
          });
        },
        onFirstRemoteVideoFrame: (
          RtcConnection connection,
          int remoteUid,
          int width,
          int height,
          int elapsed,
        ) {
          if (mounted && _remoteUid == remoteUid) {
            setState(() {
              _remoteVideoReady = true;
              if (_localIsBig) _localIsBig = false;
            });
          }
          _diagCall('first_remote_video_frame', meta: {
            'remoteUid': remoteUid,
            'width': width,
            'height': height,
            'elapsedMs': elapsed,
          });
        },
        onFirstRemoteVideoDecoded: (
          RtcConnection connection,
          int remoteUid,
          int width,
          int height,
          int elapsed,
        ) {
          if (mounted && _remoteUid == remoteUid) {
            setState(() {
              _remoteVideoReady = true;
              if (_localIsBig) _localIsBig = false;
            });
          }
          _diagCall('first_remote_video_decoded', meta: {
            'remoteUid': remoteUid,
            'width': width,
            'height': height,
            'elapsedMs': elapsed,
          });
        },
        onUserMuteVideo: (
          RtcConnection connection,
          int remoteUid,
          bool muted,
        ) {
          if (mounted && _remoteUid == remoteUid) {
            setState(() {
              _remoteVideoMuted = muted;
              if (muted) _remoteVideoReady = false;
            });
          }
          _diagCall('user_mute_video', meta: {
            'remoteUid': remoteUid,
            'muted': muted,
          });
        },
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) async {
          _joinWatchdog?.cancel();
          _diagCall('join_success', meta: {
            'callV2Selected': _callV2Selected,
            'elapsedMs': elapsed,
          });
          unawaited(_markCallkitConnected());
          final inviteId = (widget.inviteId ?? '').trim();
          if (inviteId.isNotEmpty) {
            unawaited(CallSessionManager.instance.reportAgoraJoinSuccess(
              inviteId: inviteId,
              isCaller: widget.isCaller,
            ));
          }
          if (widget.isVideo) {
            await _forceVideoAudioState(engine, source: 'join_success');
          }
          if (mounted) {
            setState(() {
              _joined = true;
              if (_callV2Selected) {
                _callV2RtcJoined = true;
              }
            });
          }
        },
        onUserJoined: (RtcConnection connection, int uid, int elapsed) async {
          await _diagCall('remote_joined', meta: {
            'callV2Selected': _callV2Selected,
            'elapsedMs': elapsed,
          });
          _ringTimeout?.cancel();
          _remoteEverJoined = true;
          if (mounted) {
            setState(() {
              _remoteUid = uid;
              _remoteVideoReady = false;
              _remoteVideoMuted = false;
              if (_callV2Selected) {
                _callV2RemoteJoined = true;
              }
            });
          }
          if (widget.isVideo) {
            try {
              await engine.setRemoteVideoStreamType(
                uid: uid,
                streamType: VideoStreamType.videoStreamHigh,
              );
              await _diagCall('remote_video_stream_high_requested', meta: {
                'remoteUid': uid,
              });
            } catch (e) {
              await _diagCall('agora_error', meta: {
                'code': 'remote_video_stream_high_request_failed',
                'msg': '$e',
              });
            }
          }

          if (widget.isVideo) {
            await _forceVideoAudioState(engine, source: 'remote_joined');
          }

          final inviteId = (widget.inviteId ?? '').trim();
          if (inviteId.isNotEmpty) {
            await CallSessionManager.instance.reportRemoteJoined(
              inviteId: inviteId,
              isCaller: widget.isCaller,
            );
          }
        },
        onUserOffline:
            (RtcConnection connection, int uid, UserOfflineReasonType r) {
          _diagCall('remote_offline', meta: {'remoteUid': uid, 'reason': '$r'});
          final remoteEndedConnectedCall = _remoteEverJoined || _joined;
          if (!remoteEndedConnectedCall) {
            _recordMissedCall(reason: 'declined_or_unavailable');
          }
          if (mounted) {
            setState(() {
              _remoteUid = null;
              _remoteVideoReady = false;
              _remoteVideoMuted = false;
              if (remoteEndedConnectedCall) {
                _ended = true;
                _fatalError = null;
                _endedMessage = 'Call ended';
              } else {
                _fatalError = 'User declined or unavailable';
              }
            });
          }
          final inviteId = (widget.inviteId ?? '').trim();
          if (inviteId.isNotEmpty) {
            unawaited(CallSessionManager.instance.reportRemoteOffline(
              inviteId: inviteId,
              wasConnected: remoteEndedConnectedCall,
              isCaller: widget.isCaller,
              reason: '$r',
            ));
          }
          if (remoteEndedConnectedCall) {
            _scheduleAutoClose('remote_offline');
          }
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          _joinWatchdog?.cancel();
          _diagCall('leave_channel');
          if (mounted) {
            setState(() {
              _remoteUid = null;
              _ended = true;
              _remoteVideoReady = false;
              _remoteVideoMuted = false;
              if (_callV2Selected) {
                _callV2MediaActive = false;
              }
            });
          }
        },
      );
      _eventHandler = handler;
      engine.registerEventHandler(handler);
      await _diagCall('handler_registered');

      if (widget.isVideo) {
        await engine.startPreview();
        await _diagCall('preview_started');
      }

      final joinOptions = ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        publishCameraTrack: widget.isVideo,
        autoSubscribeAudio: true,
        autoSubscribeVideo: widget.isVideo,
        enableAudioRecordingOrPlayout: true,
      );

      await _diagCall('join_attempt', meta: {
        'callV2Selected': _callV2Selected,
        'joinMode': 'uid',
        'tokenIdentityMode': auth.identityMode,
        'tokenMode': 'provided',
        'joinOptionsMode': widget.isVideo
            ? 'video_baseline_2117d05'
            : 'audio_baseline_2117d05',
        'publishMicrophoneTrack': true,
        'publishCameraTrack': widget.isVideo,
        'autoSubscribeAudio': true,
        'autoSubscribeVideo': widget.isVideo,
      });
      if (_callV2Selected && mounted) {
        setState(() {
          _callV2JoinAttempted = true;
        });
      } else if (_callV2Selected) {
        _callV2JoinAttempted = true;
      }
      await engine.joinChannel(
        token: _token ?? '',
        channelId: auth.channelName,
        uid: _rtcUid,
        options: joinOptions,
      );
      await _diagCall('join_returned', meta: {
        'callV2Selected': _callV2Selected,
        'joinMode': 'uid',
        'tokenIdentityMode': auth.identityMode,
      });
      await _pollConnectionState('join_returned');
      _scheduleConnectionStatePolls();
      _startJoinWatchdog(auth.channelName);
      await _diagCall('begin_done');
    } catch (e) {
      if (_engine != null) {
        _lastEngineShutdown = _cleanupEngine();
        await _lastEngineShutdown;
      }
      await _diagCall('begin_error', meta: {'error': '$e'});
      if (_callV2Selected) {
        final blocker = _safeBlockerCodeForError(e);
        if (!_callV2BlockerCode.startsWith('callable_')) {
          if (mounted) {
            setState(() {
              _callV2BlockerCode = blocker;
            });
          } else {
            _callV2BlockerCode = blocker;
          }
        }
      }
      final inviteId = (widget.inviteId ?? '').trim();
      if (inviteId.isNotEmpty) {
        await CallSessionManager.instance.reportCallFailure(
          inviteId: inviteId,
          isCaller: widget.isCaller,
          message: e is TimeoutException
              ? 'Call connection timed out. Please try again.'
              : 'Call setup failed. Please try again.',
          error: '$e',
        );
      }
      if (mounted) {
        setState(() {
          _fatalError = '$e';
        });
      }
      _scheduleAutoClose('begin_error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _beginInTestMode() async {
    await _diagCall('engine_wait_previous_shutdown', meta: {'testMode': true});
    await _diagCall('engine_precleanup_done', meta: {'testMode': true});
    await _diagCall('mic_permission_ok', meta: {'testMode': true});
    if (widget.isVideo) {
      await _diagCall('camera_permission_ok', meta: {'testMode': true});
    }

    final inviteId = (widget.inviteId ?? '').trim();
    if (inviteId.isNotEmpty) {
      await CallSessionManager.instance.reportCallScreenBegan(
        inviteId: inviteId,
        isCaller: widget.isCaller,
      );
    }

    if (widget.isVideo) {
      await _diagCall('video_audio_forced_enabled', meta: {'source': 'test'});
      await _diagCall('remote_audio_unmuted', meta: {'source': 'test'});
      await _diagCall('speakerphone_forced_on', meta: {'source': 'test'});
    }

    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (mounted) {
      setState(() {
        _joined = true;
        _isLoading = false;
        _localVideoReady = widget.isVideo;
        _speakerOn = true;
        if (_callV2Selected) {
          _callV2CallableReached = true;
          _callV2TokenReady = true;
          _callV2AppIdReady = true;
          _callV2AccessReady = true;
          _callV2RtcInitialized = true;
          _callV2JoinAttempted = true;
          _callV2RtcJoined = true;
          _callV2RemoteJoined = true;
          _callV2MediaActive = true;
          _callV2BlockerCode = 'none';
        }
      });
    }
    await _diagCall('join_success', meta: {
      'localUid': 1,
      'elapsedMs': 1,
      'testMode': true,
    });
    if (inviteId.isNotEmpty) {
      await CallSessionManager.instance.reportAgoraJoinSuccess(
        inviteId: inviteId,
        isCaller: widget.isCaller,
      );
    }
    await _diagCall('begin_done', meta: {'testMode': true});
  }

  Future<RtcEngine> _createAndInitializeEngine() async {
    return _createAndInitializeEngineAttempt(attempt: 1);
  }

  String _sanitizeAgoraLogSegment(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return cleaned.isEmpty ? 'call' : cleaned;
  }

  Map<String, dynamic> _safeAgoraDiagMeta(Map<String, dynamic> meta) {
    if (meta.isEmpty) return const <String, dynamic>{};
    final safe = <String, dynamic>{};
    for (final entry in meta.entries) {
      final key = entry.key;
      final lower = key.toLowerCase();
      if (lower.contains('uid') ||
          lower.contains('user') ||
          lower.contains('channel') ||
          lower.contains('invite') ||
          lower.contains('callid') ||
          lower.contains('token') ||
          lower.contains('device')) {
        safe['identifierFieldPresent'] =
            entry.value.toString().trim().isNotEmpty;
        continue;
      }
      if (lower.contains('error') || lower == 'msg') {
        safe['errorCategory'] = _safeAgoraErrorCategory(entry.value);
        continue;
      }
      final value = entry.value;
      if (value == null || value is bool || value is num) {
        safe[key] = value;
      } else if (value is String) {
        safe[key] = _safeAgoraDiagString(value);
      } else if (value is Map || value is Iterable) {
        safe[key] = 'structured';
      } else {
        safe[key] = value.runtimeType.toString();
      }
    }
    return safe;
  }

  String _safeAgoraDiagString(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    const allowed = <String>{
      'none',
      'disabled',
      'dev_callable_disabled',
      'call_v2_dev_config',
      'server',
      'server_matches_fallback',
      'provided',
      'communication',
      'engine_and_join_options',
      'join_returned',
      'begin',
      'test',
    };
    if (trimmed == 'uid') return 'numeric';
    if (allowed.contains(trimmed)) return trimmed;
    if (trimmed.startsWith('ConnectionStateType.') ||
        trimmed.startsWith('ConnectionChangedReasonType.') ||
        trimmed.startsWith('NetworkType.') ||
        trimmed.startsWith('ErrorCodeType.') ||
        trimmed.startsWith('RemoteAudioState') ||
        trimmed.startsWith('RemoteVideoState') ||
        trimmed.startsWith('LocalAudioStream') ||
        trimmed.startsWith('LocalVideoStream') ||
        trimmed.startsWith('UserOfflineReasonType.') ||
        trimmed.startsWith('VideoSourceType.') ||
        trimmed.startsWith('VideoStreamType.') ||
        trimmed.startsWith('QualityAdaptIndication.')) {
      return trimmed;
    }
    return trimmed.length > 64 ? 'text' : trimmed;
  }

  String _safeBlockerCodeForError(Object error) {
    if (error is TimeoutException) return 'timeout';
    if (error is CallV2ClientError) return error.code.name;
    return 'setup_failed';
  }

  void _setCallV2BlockerCode(String value) {
    final safe = _safeCallV2BlockerCode(value);
    if (mounted) {
      setState(() {
        _callV2BlockerCode = safe;
      });
    } else {
      _callV2BlockerCode = safe;
    }
  }

  String _safeCallV2BlockerCode(String value) {
    const allowed = <String>{
      'none',
      'timeout',
      'setup_failed',
      'unavailable',
      'rejected',
      'unauthorized',
      'invalidRequest',
      'callable_unavailable',
      'callable_rejected',
      'callable_unauthorized',
      'callable_invalidRequest',
      'agora_error',
      'connection_failed',
      'remote_audio_failed',
    };
    return allowed.contains(value) ? value : 'setup_failed';
  }

  String _safeAgoraErrorCategory(Object? value) {
    final text = (value ?? '').toString().toLowerCase();
    if (text.contains('timeout')) return 'timeout';
    if (text.contains('permission')) return 'permission';
    if (text.contains('token')) return 'access';
    if (text.contains('network') || text.contains('unavailable')) {
      return 'network';
    }
    if (text.trim().isEmpty) return 'none';
    return 'error';
  }

  Future<String?> _prepareAgoraLogPath({required int attempt}) async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final agoraDir = Directory('${supportDir.path}/agora_logs');
      await agoraDir.create(recursive: true);
      final callId = _sanitizeAgoraLogSegment(
        _callV2Selected ? 'call_v2' : 'call',
      );
      final file = File('${agoraDir.path}/${callId}_attempt_$attempt.log');
      if (await file.exists()) {
        await file.writeAsString('');
      }
      return file.path;
    } catch (e) {
      await _diagCall('engine_log_read_error', meta: {
        'attempt': attempt,
        'stage': 'prepare_path',
        'error': '$e',
      });
      return null;
    }
  }

  Future<void> _persistAgoraLogTail(
    String? logPath, {
    required int attempt,
    required String reason,
  }) async {
    if (logPath == null || logPath.isEmpty) {
      await _diagCall('engine_log_read_error', meta: {
        'attempt': attempt,
        'stage': 'missing_path',
        'reason': reason,
      });
      return;
    }
    RandomAccessFile? raf;
    try {
      final file = File(logPath);
      final exists = await file.exists();
      if (!exists) {
        await _diagCall('engine_log_tail', meta: {
          'attempt': attempt,
          'reason': reason,
          'path': logPath,
          'exists': false,
        });
        return;
      }
      raf = await file.open();
      final length = await raf.length();
      final start = length > 1400 ? length - 1400 : 0;
      await raf.setPosition(start);
      final bytes = await raf.read(length - start);
      final tail =
          utf8.decode(bytes, allowMalformed: true).replaceAll('\r', '');
      await _diagCall(
        'engine_log_tail',
        meta: {
          'attempt': attempt,
          'reason': reason,
          'path': logPath,
          'exists': true,
          'bytes': length,
          'tail': tail.isEmpty ? '(empty)' : tail,
        },
        metaLimit: 1800,
      );
    } catch (e) {
      await _diagCall(
        'engine_log_read_error',
        meta: {
          'attempt': attempt,
          'stage': 'read_tail',
          'reason': reason,
          'path': logPath,
          'error': '$e',
        },
        metaLimit: 1200,
      );
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
    }
  }

  RtcEngine _createFreshAgoraEngine() {
    return agora_internal.RtcEngineImpl.createForTesting(
      irisMethodChannel: IrisMethodChannel(createPlatformBindingsProvider()),
    );
  }

  Future<void> _forceDisposeFailedInitialize(
    RtcEngine engine, {
    required String reason,
    Object? error,
  }) async {
    await _diagCall('engine_force_dispose_start', meta: {
      'reason': reason,
      if (error != null) 'error': '$error',
    });
    try {
      await agora_internal.RtcEngineExt(engine)
          .irisMethodChannel
          .dispose()
          .timeout(const Duration(seconds: 3));
      await _diagCall('engine_force_dispose_done', meta: {
        'reason': reason,
      });
    } catch (disposeError) {
      await _diagCall('engine_force_dispose_error', meta: {
        'reason': reason,
        'error': '$disposeError',
      });
    }
  }

  Future<RtcEngine> _createAndInitializeEngineAttempt({
    required int attempt,
  }) async {
    final agoraLogPath = await _prepareAgoraLogPath(attempt: attempt);
    await _diagCall('engine_create_start', meta: {
      'attempt': attempt,
    });
    final engine = _createFreshAgoraEngine();
    _engine = engine;
    await _diagCall('engine_factory_selected', meta: {
      'attempt': attempt,
      'factory': 'create_for_testing_fresh_instance',
    });
    await _diagCall('engine_create_done', meta: {
      'attempt': attempt,
    });
    await _diagCall('engine_initialize_start', meta: {
      'attempt': attempt,
      'appIdSuffix': _agoraAppId!.length >= 6
          ? _agoraAppId!.substring(_agoraAppId!.length - 6)
          : _agoraAppId!,
    });

    var initialized = false;
    final slowLog = Timer(const Duration(seconds: 20), () {
      if (!initialized) {
        unawaited(_diagCall('engine_initialize_slow', meta: {
          'attempt': attempt,
          'elapsedSeconds': 20,
          'note': 'still_waiting_for_native_initialize',
        }));
      }
    });
    try {
      await _diagCall('engine_initialize_context', meta: {
        'attempt': attempt,
        'agoraFlutterPluginVersion': _agoraFlutterPluginVersion,
        'channelProfile': 'communication',
        'audioScenario': 'default',
        'autoRegisterAgoraExtensions': false,
        'logLevel': 'info',
        'logPath': agoraLogPath ?? '',
        'logFileSizeInKB': _agoraLogFileSizeInKB,
      });
      if (agoraLogPath != null) {
        await _diagCall('engine_log_configured', meta: {
          'attempt': attempt,
          'path': agoraLogPath,
          'fileSizeInKB': _agoraLogFileSizeInKB,
        });
      }
      await engine
          .initialize(RtcEngineContext(
        appId: _agoraAppId!,
        channelProfile: ChannelProfileType.channelProfileCommunication,
        audioScenario: AudioScenarioType.audioScenarioDefault,
        autoRegisterAgoraExtensions: false,
        logConfig: LogConfig(
          filePath: agoraLogPath,
          fileSizeInKB: _agoraLogFileSizeInKB,
          level: LogLevel.logLevelInfo,
        ),
      ))
          .timeout(_engineInitializeTimeout, onTimeout: () async {
        await _diagCall('engine_initialize_timeout', meta: {
          'attempt': attempt,
          'timeoutSeconds': _engineInitializeTimeout.inSeconds,
          'note': 'native_initialize_future_did_not_complete',
        });
        throw TimeoutException(
          'Agora engine did not start. Fully close and reopen the app, then try again.',
          _engineInitializeTimeout,
        );
      });
      initialized = true;
      return engine;
    } on TimeoutException catch (e) {
      await _forceDisposeFailedInitialize(
        engine,
        reason: 'initialize_timeout',
        error: e,
      );
      await _persistAgoraLogTail(
        agoraLogPath,
        attempt: attempt,
        reason: 'initialize_timeout',
      );
      if (identical(_engine, engine)) {
        _engine = null;
      }
      if (attempt < 2) {
        await _diagCall('engine_initialize_retry', meta: {
          'attempt': attempt + 1,
          'reason': 'timeout_after_force_dispose',
        });
        await Future<void>.delayed(const Duration(milliseconds: 600));
        return _createAndInitializeEngineAttempt(attempt: attempt + 1);
      }
      await _diagCall('engine_initialize_error', meta: {
        'attempt': attempt,
        'error': '$e',
      });
      rethrow;
    } catch (e) {
      if (!initialized) {
        await _forceDisposeFailedInitialize(
          engine,
          reason: 'initialize_error',
          error: e,
        );
        await _persistAgoraLogTail(
          agoraLogPath,
          attempt: attempt,
          reason: 'initialize_error',
        );
        if (identical(_engine, engine)) {
          _engine = null;
        }
      }
      await _diagCall('engine_initialize_error', meta: {
        'attempt': attempt,
        'error': '$e',
      });
      rethrow;
    } finally {
      initialized = true;
      slowLog.cancel();
    }
  }

  Future<void> _configureVideoPipeline(RtcEngine engine) async {
    await engine.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        codecType: VideoCodecType.videoCodecH264,
        dimensions: _videoCallDimensions,
        frameRate: _videoCallFrameRate,
        bitrate: _videoCallBitrate,
        minBitrate: _videoCallMinBitrate,
        orientationMode: OrientationMode.orientationModeAdaptive,
        degradationPreference: DegradationPreference.maintainBalanced,
        mirrorMode: VideoMirrorModeType.videoMirrorModeAuto,
      ),
    );
    await engine.setCameraCapturerConfiguration(
      const CameraCapturerConfiguration(
        cameraDirection: CameraDirection.cameraFront,
        followEncodeDimensionRatio: true,
        format: _videoCallCaptureFormat,
      ),
    );
    await engine.setRemoteDefaultVideoStreamType(
      VideoStreamType.videoStreamHigh,
    );
    await _diagCall('video_profile_configured', meta: {
      'codec': 'h264',
      'width': _videoCallDimensions.width ?? 0,
      'height': _videoCallDimensions.height ?? 0,
      'frameRate': _videoCallFrameRate,
      'captureWidth': _videoCallCaptureFormat.width ?? 0,
      'captureHeight': _videoCallCaptureFormat.height ?? 0,
      'captureFps': _videoCallCaptureFormat.fps ?? 0,
      'bitrateMode': 'standard_auto',
      'minBitrateMode': 'sdk_default',
      'orientationMode': 'adaptive',
      'degradationPreference': 'balanced',
      'cameraDirection': 'front',
      'followEncodeDimensionRatio': true,
    });
    await _diagCall('remote_video_stream_high_default_set', meta: {
      'streamType': 'high',
    });
  }

  Future<void> _pollConnectionState(String source) async {
    final engine = _engine;
    if (engine == null) return;
    try {
      final state = await engine.getConnectionState();
      await _diagCall('conn_state_polled', meta: {
        'source': source,
        'state': '$state',
      });
    } catch (e) {
      await _diagCall('conn_state_polled', meta: {
        'source': source,
        'error': '$e',
      });
    }
  }

  void _scheduleConnectionStatePolls() {
    for (final seconds in const <int>[1, 5, 15]) {
      unawaited(Future<void>.delayed(Duration(seconds: seconds), () async {
        if (!mounted || _ended || _joined) return;
        await _pollConnectionState('after_${seconds}s');
      }));
    }
  }

  void _startJoinWatchdog(String channel) {
    _joinWatchdog?.cancel();
    _joinWatchdog = Timer(_joinWatchdogTimeout, () async {
      if (!mounted || _ended || _joined) return;
      await _diagCall('join_watchdog_timeout', meta: {
        'channel': channel,
        'uid': _rtcUid,
      });
      final inviteId = (widget.inviteId ?? '').trim();
      if (inviteId.isNotEmpty) {
        await CallSessionManager.instance.reportJoinTimeout(
          inviteId: inviteId,
          isCaller: widget.isCaller,
        );
      }
      if (mounted && !_ended) {
        setState(() {
          _ended = true;
          _fatalError = 'Call connection timed out. Please try again.';
        });
      }
      _scheduleAutoClose('join_watchdog_timeout');
    });
  }

  String _chatIdFor(String a, String b) {
    final ids = [a, b]..sort();
    return ids.join('_');
  }

  Future<void> _recordMissedCall({required String reason}) async {
    if (_missedLogged || !widget.isCaller) return;
    final other = (widget.otherUserId ?? '').trim();
    final me = HelperlyTestRuntime.currentUid ??
        FirebaseAuth.instance.currentUser?.uid;
    if (me == null || other.isEmpty || me == other) return;

    _missedLogged = true;
    final now = Timestamp.now();
    final chatId = _chatIdFor(me, other);
    final chatRef =
        HelperlyTestRuntime.firestore.collection('chats').doc(chatId);
    final callText = widget.isVideo ? 'Missed video call' : 'Missed audio call';

    try {
      await chatRef.set({
        'users': FieldValue.arrayUnion([me, other]),
        'participants': FieldValue.arrayUnion([me, other]),
        'updatedAt': now,
        'lastMessageAt': now,
        'lastMessageAuthorId': me,
        'lastMessageType': 'missed_call',
        'lastMessageText': callText,
        'unreadBy.$me': 0,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await chatRef.collection('messages').add({
        'authorId': me,
        'createdAt': now,
        'type': 'text',
        'text': callText,
        'system': true,
        'callStatus': 'missed',
        'callReason': reason,
        'channel': widget.channelName,
      });
    } catch (_) {}
  }

  Future<void> _ensurePermission(Permission permission, String label) async {
    final status = await permission.status;
    if (status.isGranted) return;
    final result = await permission.request();
    if (!result.isGranted) {
      throw Exception('$label permission not granted ($result)');
    }
  }

  Future<void> _cleanupEngine({bool release = true}) async {
    _joinWatchdog?.cancel();
    final engine = _engine;
    final handler = _eventHandler;
    await _diagCall('cleanup_start', meta: {
      'release': release,
      'hasEngine': engine != null,
      'hasHandler': handler != null,
    });
    if (engine == null) {
      await _diagCall('cleanup_done',
          meta: {'release': release, 'hadEngine': false});
      return;
    }

    _engine = null;
    _eventHandler = null;
    try {
      if (handler != null) {
        engine.unregisterEventHandler(handler);
      }
      await _diagCall('unregister_handler_done',
          meta: {'hadHandler': handler != null});
    } catch (e) {
      await _diagCall('unregister_handler_error', meta: {'error': '$e'});
    }
    try {
      await engine.leaveChannel().timeout(const Duration(seconds: 2));
      await _diagCall('leave_channel_done');
    } catch (e) {
      await _diagCall('leave_channel_error', meta: {'error': '$e'});
    }
    if (widget.isVideo) {
      try {
        await engine.stopPreview().timeout(const Duration(seconds: 1));
        await _diagCall('stop_preview_done');
      } catch (e) {
        await _diagCall('stop_preview_error', meta: {'error': '$e'});
      }
    }
    if (release) {
      try {
        await engine.release(sync: true).timeout(const Duration(seconds: 2));
        await _diagCall('release_done');
      } catch (e) {
        await _diagCall('release_error', meta: {'error': '$e'});
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await _diagCall('cleanup_done',
        meta: {'release': release, 'hadEngine': true});
  }

  void _returnToAppAfterCall() {
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    nav.pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _closeScreenAfterTerminalState(String reason) async {
    if (_endingCall) return;
    _endingCall = true;
    _autoCloseTimer?.cancel();
    await _diagCall('screen_auto_close', meta: {'reason': reason});
    try {
      await _cleanupEngine();
      await _clearStoredAcceptedCallRecovery();
      await _cleanupCallkitUi(reason: 'screen_terminal_hard_reset');
      await CallSessionManager.instance.hardResetForNewCall(
        reason: 'screen_terminal_hard_reset',
      );
      _returnToAppAfterCall();
    } finally {
      _endingCall = false;
    }
  }

  void _scheduleAutoClose(
    String reason, {
    Duration delay = const Duration(seconds: 1),
  }) {
    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(delay, () {
      unawaited(_closeScreenAfterTerminalState(reason));
    });
  }

  @override
  void dispose() {
    CallSessionManager.instance.terminalSignal
        .removeListener(_handleManagerTerminalSignal);
    _ringTimeout?.cancel();
    _joinWatchdog?.cancel();
    _autoCloseTimer?.cancel();
    _lastEngineShutdown = _cleanupEngine();
    super.dispose();
  }

  Future<void> _toggleMute() async {
    _muted = !_muted;
    await _engine?.muteLocalAudioStream(_muted);
    setState(() {});
  }

  Future<void> _toggleSpeaker() async {
    _speakerRouteExplicitlyChanged = true;
    _speakerOn = !_speakerOn;
    await _engine?.setEnableSpeakerphone(_speakerOn);
    setState(() {});
  }

  Future<void> _switchCamera() async {
    _frontCamera = !_frontCamera;
    await _engine?.switchCamera();
    setState(() {});
  }

  Future<void> _endCall() async {
    if (_endingCall) return;
    _endingCall = true;
    try {
      await _diagCall('end_pressed');
      _joinWatchdog?.cancel();
      final id = (widget.inviteId ?? '').trim();
      if (id.isNotEmpty) {
        await CallSessionManager.instance.endCallFromLocalUser(
          inviteId: id,
          source: 'end_button',
        );
      }
      await _cleanupEngine();
      await _clearStoredAcceptedCallRecovery();
      await _cleanupCallkitUi(reason: 'manual_end_hard_reset');
      await CallSessionManager.instance.hardResetForNewCall(
        reason: 'manual_end_hard_reset',
      );
      _returnToAppAfterCall();
    } finally {
      _endingCall = false;
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final title = widget.isVideo ? 'Video Call' : 'Audio Call';

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Connecting...')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              _callV2SafeStatusPanel(),
            ],
          ),
        ),
      );
    }

    if (_fatalError != null) {
      return _ErrorScreen(
        title: title,
        message: _fatalError!,
        onClose: () => _endCall(),
        footer: _callV2SafeStatusPanel(),
      );
    }

    if (_ended) {
      return _EndedScreen(
        title: title,
        message: _endedMessage,
        onClose: () => _endCall(),
        footer: _callV2SafeStatusPanel(),
      );
    }

    if (widget.isVideo) return _videoLayout();
    return _audioLayout();
  }

  Widget _audioLayout() {
    final status = (_remoteUid != null)
        ? 'Connected'
        : (_joined ? 'Calling…' : 'Connecting…');
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        title: const Text('Audio call'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.avatarBg,
              child: const Icon(Icons.call, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text(
              widget.otherUserName,
              style:
                  textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              status,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            _callV2SafeStatusPanel(),
          ],
        ),
      ),
      bottomNavigationBar: _controlsBar(),
    );
  }

  Widget _videoLayout() {
    if (_testMode || _engine == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: Text(
                  _ended
                      ? _endedMessage
                      : (_joined
                          ? 'Simulated video call connected'
                          : 'Simulated video call connecting'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 6,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _statusPill(
                          icon: Icons.videocam_rounded,
                          label: widget.otherUserName,
                        ),
                        const SizedBox(width: 8),
                        _statusPill(
                          icon: _joined
                              ? Icons.wifi_tethering
                              : Icons.access_time_rounded,
                          label: _joined ? 'Connected' : 'Calling…',
                        ),
                      ],
                    ),
                    _callV2SafeStatusPanel(dark: true),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _controlsBar(),
      );
    }

    final remotePlaceholder = _remoteUid == null
        ? 'Waiting for the other user to join…'
        : (_remoteVideoMuted
            ? 'Remote camera is off'
            : 'Waiting for remote video…');
    final remote = (_remoteUid != null)
        ? AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _engine!,
              canvas: VideoCanvas(
                uid: _remoteUid,
                renderMode: RenderModeType.renderModeFit,
              ),
              connection: RtcConnection(
                channelId: _joinedChannelName ?? widget.channelName,
              ),
              useFlutterTexture: _useFlutterTextureRenderer,
            ),
            onAgoraVideoViewCreated: (viewId) {
              unawaited(_diagCall('remote_video_view_created', meta: {
                'remoteUid': _remoteUid ?? -1,
                'viewId': viewId,
                'useFlutterTexture': _useFlutterTextureRenderer,
                'renderer': _videoRendererLabel,
                'renderMode': 'fit',
              }));
            },
          )
        : const SizedBox.shrink();

    final local = AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine!,
        canvas: const VideoCanvas(
          uid: 0,
          renderMode: RenderModeType.renderModeFit,
        ),
        useFlutterTexture: _useFlutterTextureRenderer,
      ),
      onAgoraVideoViewCreated: (viewId) {
        unawaited(_diagCall('local_video_view_created', meta: {
          'viewId': viewId,
          'useFlutterTexture': _useFlutterTextureRenderer,
          'renderer': _videoRendererLabel,
          'renderMode': 'fit',
        }));
        if (widget.isVideo) {
          unawaited(_engine?.startPreview());
        }
      },
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final pipW = 120.0;
          final pipH = 180.0;
          final bottomBarH = 88.0; // space for control bar

          Offset clamp(Offset p) {
            final maxX = constraints.maxWidth - pipW - 12;
            final maxY = constraints.maxHeight - pipH - bottomBarH;
            final x = p.dx.clamp(12.0, maxX);
            final y = p.dy.clamp(12.0, maxY);
            return Offset(x, y);
          }

          return Stack(
            children: [
              // Big view
              Positioned.fill(
                child: ClipRect(
                  child: _buildVideoSurface(
                    child: _localIsBig ? local : remote,
                    ready: _localIsBig ? _localVideoReady : _remoteVideoReady,
                    placeholder:
                        _localIsBig ? 'Starting camera…' : remotePlaceholder,
                  ),
                ),
              ),
              if (_localIsBig && _remoteUid == null)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 110,
                  child: Center(
                    child: Text(
                      'Waiting for the other user to join…',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

              Positioned(
                left: 12,
                right: 12,
                top: 6,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _statusPill(
                            icon: Icons.videocam_rounded,
                            label: widget.otherUserName,
                          ),
                          const SizedBox(width: 8),
                          _statusPill(
                            icon: _remoteUid != null
                                ? Icons.wifi_tethering
                                : Icons.access_time_rounded,
                            label:
                                _remoteUid != null ? 'Connected' : 'Calling…',
                          ),
                        ],
                      ),
                      _callV2SafeStatusPanel(dark: true),
                    ],
                  ),
                ),
              ),

              // Draggable PiP — smooth & free drag, clamped on screen
              Positioned(
                left: _pipPos.dx,
                top: _pipPos.dy,
                child: GestureDetector(
                  onPanUpdate: (d) {
                    setState(() => _pipPos = clamp(_pipPos + d.delta));
                  },
                  onTap: () => setState(() => _localIsBig = !_localIsBig),
                  child: Container(
                    width: pipW,
                    height: pipH,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white70, width: 1.6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.38),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: _buildVideoSurface(
                              child: _localIsBig ? remote : local,
                              ready: _localIsBig
                                  ? _remoteVideoReady
                                  : _localVideoReady,
                              placeholder: _localIsBig
                                  ? remotePlaceholder
                                  : 'Starting camera…',
                              compact: true,
                            ),
                          ),
                          Positioned(
                            left: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Text(
                                'Tap to swap',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _controlsBar(video: true),
    );
  }

  Widget _buildVideoSurface({
    required Widget child,
    required bool ready,
    required String placeholder,
    bool compact = false,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),
        child,
        if (!ready)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                placeholder,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: compact ? 12 : 18,
                  height: 1.25,
                  fontWeight: compact ? FontWeight.w500 : FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: compact ? 3 : 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }

  Widget _callV2SafeStatusPanel({bool dark = false}) {
    if (!_showCallV2SafeStatus) return const SizedBox.shrink();
    final config = _callV2RealFlowConfig;
    final text = 'buildCommitPresent=${config.buildCommitPresent} '
        'realFlowEnabled=${config.enabled} '
        'devCallableEnabled=${config.devCallableEnabled} '
        'callV2Selected=$_callV2Selected '
        'callableAttempted=$_callV2CallableAttempted '
        'callableReached=$_callV2CallableReached '
        'tokenReady=$_callV2TokenReady '
        'appIdReady=$_callV2AppIdReady '
        'accessReady=$_callV2AccessReady '
        'rtcInitialized=$_callV2RtcInitialized '
        'joinAttempted=$_callV2JoinAttempted '
        'rtcJoined=$_callV2RtcJoined '
        'remoteJoined=$_callV2RemoteJoined '
        'mediaActive=$_callV2MediaActive '
        'fallbackUsed=${widget.callV2FallbackUsed} '
        'blockerCode=$_callV2BlockerCode '
        'agoraErrorCode=$_callV2AgoraErrorCode '
        'connectionState=$_callV2ConnectionState '
        'connectionReason=$_callV2ConnectionReason';
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark
              ? Colors.black.withValues(alpha: 0.55)
              : AppColors.card.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: dark ? Colors.white24 : AppColors.border,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            text,
            key: const ValueKey<String>('call-v2-real-flow-safe-status'),
            style: TextStyle(
              color: dark ? Colors.white : AppColors.text,
              fontSize: 12,
              height: 1.25,
            ),
          ),
        ),
      ),
    );
  }

  Widget _controlsBar({bool video = false}) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        color: video ? Colors.black.withValues(alpha: 0.35) : AppColors.canvas,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _roundButton(
              icon: _muted ? Icons.mic_off : Icons.mic,
              onTap: _toggleMute,
              isActive: !_muted,
              dark: video,
            ),
            if (video)
              _roundButton(
                icon: Icons.cameraswitch,
                onTap: _switchCamera,
                isActive: _frontCamera,
                dark: video,
              ),
            _hangupButton(), // big red centered button
            _roundButton(
              icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
              onTap: _toggleSpeaker,
              isActive: _speakerOn,
              dark: video,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = true,
    bool dark = false,
  }) {
    final bg = dark
        ? (isActive ? Colors.white : Colors.white24)
        : (isActive ? AppColors.button : AppColors.border);
    final fg = dark
        ? (isActive ? Colors.black : Colors.white70)
        : (isActive ? AppColors.text : AppColors.muted);
    return InkResponse(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.12), blurRadius: 8)
          ],
        ),
        child: Icon(icon, color: fg),
      ),
    );
  }

  Widget _hangupButton() {
    return InkResponse(
      onTap: () => _endCall(),
      child: Container(
        width: 76,
        height: 76,
        decoration: const BoxDecoration(
          color: AppColors.danger,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.call_end, color: Colors.white, size: 32),
      ),
    );
  }
}

// ------- End/Errors -------

class _EndedScreen extends StatelessWidget {
  const _EndedScreen({
    required this.title,
    required this.message,
    required this.onClose,
    this.footer = const SizedBox.shrink(),
  });
  final String title;
  final String message;
  final VoidCallback onClose;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.canvas,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 56, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            footer,
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onClose, child: const Text('Close')),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({
    required this.title,
    required this.message,
    required this.onClose,
    this.footer = const SizedBox.shrink(),
  });

  final String title;
  final String message;
  final VoidCallback onClose;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final isPermissionError =
        message.toLowerCase().contains('permission not granted');
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.canvas,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.danger, size: 64),
              const SizedBox(height: 12),
              const Text('Something went wrong.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              footer,
              const SizedBox(height: 16),
              if (isPermissionError) ...[
                OutlinedButton(
                  onPressed: openAppSettings,
                  child: const Text('Open Settings'),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton(onPressed: onClose, child: const Text('Close')),
            ],
          ),
        ),
      ),
    );
  }
}
