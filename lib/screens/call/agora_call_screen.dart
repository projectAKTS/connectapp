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
import 'package:connect_app/theme/tokens.dart';
import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connect_app/services/callkit_id.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:iris_method_channel/iris_method_channel.dart'
    show IrisMethodChannel;
import 'package:path_provider/path_provider.dart';

class AgoraJoinAuth {
  final String token;
  final String appId;
  final int uid;
  final String userAccount;
  final String tokenVersion;
  final String identityMode;
  const AgoraJoinAuth({
    required this.token,
    required this.appId,
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
    uid: serverUid,
    userAccount: (serverUserAccount == null || serverUserAccount.isEmpty)
        ? userAccount
        : serverUserAccount,
    tokenVersion: detectedVersion,
    identityMode: tokenIdentityMode,
  );
}

class AgoraCallScreen extends StatefulWidget {
  final String channelName;
  final bool isVideo;
  final String otherUserName;
  final String? otherUserId;
  final String? inviteId;
  final bool isCaller;

  const AgoraCallScreen({
    Key? key,
    required this.channelName,
    required this.isVideo,
    required this.otherUserName,
    this.otherUserId,
    this.inviteId,
    this.isCaller = false,
  }) : super(key: key);

  @override
  State<AgoraCallScreen> createState() => _AgoraCallScreenState();
}

class _AgoraCallScreenState extends State<AgoraCallScreen> {
  static const MethodChannel _pushTokenChannel =
      MethodChannel('connectapp/pushTokens');
  static Future<void> _lastEngineShutdown = Future<void>.value();
  static const bool _diagEnabled =
      bool.fromEnvironment('ENABLE_RUNTIME_DIAG', defaultValue: false);
  static const Duration _engineInitializeTimeout = Duration(seconds: 30);
  static const Duration _joinWatchdogTimeout = Duration(seconds: 35);
  static const Set<String> _persistedUserDiagStages = <String>{
    'begin_start',
    'begin_done',
    'engine_wait_previous_shutdown',
    'engine_precleanup_done',
    'mic_permission_ok',
    'camera_permission_ok',
    'invite_marked_accepted',
    'token_ok',
    'engine_create_start',
    'engine_create_done',
    'engine_factory_selected',
    'engine_initialize_start',
    'engine_initialize_context',
    'engine_log_configured',
    'engine_log_tail',
    'engine_log_read_error',
    'engine_initialize_slow',
    'engine_initialize_timeout',
    'engine_initialize_error',
    'engine_force_dispose_start',
    'engine_force_dispose_done',
    'engine_force_dispose_error',
    'engine_initialize_retry',
    'engine_initialized',
    'audio_enabled',
    'video_enabled',
    'video_profile_configured',
    'channel_profile_set',
    'handler_registered',
    'preview_started',
    'callkit_connected_marked',
    'callkit_connected_error',
    'join_attempt',
    'join_returned',
    'join_success',
    'join_watchdog_timeout',
    'first_local_video_frame',
    'first_local_video_frame_published',
    'first_remote_video_frame',
    'first_remote_video_decoded',
    'local_user_registered',
    'remote_joined',
    'user_info_updated',
    'user_account_updated',
    'remote_offline',
    'conn_state_changed',
    'conn_state_polled',
    'network_type_changed',
    'proxy_connected',
    'token_requested',
    'token_will_expire',
    'user_mute_audio',
    'remote_audio_state',
    'audio_routing_changed',
    'local_audio_state',
    'local_video_state',
    'remote_video_state',
    'user_mute_video',
    'remote_video_stream_high_default_set',
    'remote_video_stream_high_requested',
    'video_quality_warning_local',
    'video_quality_warning_remote',
    'local_video_view_created',
    'remote_video_view_created',
    'leave_channel',
    'agora_error',
    'begin_error',
    'invite_status_terminal',
    'screen_auto_close',
  };
  RtcEngine? _engine;
  RtcEngineEventHandler? _eventHandler;
  String? _token;
  String? _agoraAppId;
  String? _rtcUserAccount;
  int _rtcUid = 0;
  String? _seenTerminalInviteStatus;

  bool _joined = false;
  int? _remoteUid;
  bool _ended = false;
  bool _endingCall = false;
  bool _isLoading = true;
  String? _fatalError;

  // Controls
  bool _muted = false;
  bool _speakerOn = true;
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
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _inviteSub;
  bool _remoteEverJoined = false;
  bool _missedLogged = false;
  bool _callkitMarkedConnected = false;
  bool _nativeAcceptedCallCleared = false;

  bool get _useFlutterTextureRenderer =>
      Platform.isIOS && _preferFlutterTextureRendererOnIOS;

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

  Future<void> _diagCall(
    String stage, {
    Map<String, dynamic>? meta,
    int metaLimit = 500,
  }) async {
    final baseMeta = <String, dynamic>{
      'inviteId': widget.inviteId ?? '',
      'channel': widget.channelName,
      'isCaller': widget.isCaller,
      ...?meta,
    };
    final metaStr = baseMeta.toString();
    final payload = <String, dynamic>{
      'stage': stage,
      'meta': metaStr.length > metaLimit
          ? metaStr.substring(0, metaLimit)
          : metaStr,
    };
    debugPrint('[DIAG][call] $stage meta=${payload['meta']}');
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      if (stage == 'begin_start') {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'diag.callTrail': FieldValue.delete(),
          'diag.currentCallInviteId': widget.inviteId ?? '',
          'diag.currentCallChannel': widget.channelName,
          'diag.currentCallIsCaller': widget.isCaller,
          'diag.currentCallStartedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      final shouldPersistUserDiag = _persistedUserDiagStages.contains(stage) ||
          (stage == 'conn_state_changed' &&
              '${meta?['state'] ?? ''}'.contains('connectionStateFailed'));
      if (shouldPersistUserDiag) {
        final userUpdate = <String, dynamic>{
          'diag.lastCallStage': stage,
          'diag.lastCallAt': FieldValue.serverTimestamp(),
          'diag.lastCallMeta': payload['meta'],
          'diag.lastCallInviteId': widget.inviteId ?? '',
          'diag.lastCallChannel': widget.channelName,
          'diag.lastCallIsCaller': widget.isCaller,
          'diag.callTrail.$stage.at': FieldValue.serverTimestamp(),
          'diag.callTrail.$stage.meta': payload['meta'],
          'diag.callTrail.$stage.inviteId': widget.inviteId ?? '',
          'diag.callTrail.$stage.channel': widget.channelName,
          'diag.callTrail.$stage.isCaller': widget.isCaller,
        };
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          ...userUpdate,
        }, SetOptions(merge: true));
      }
      if (!_diagEnabled) return;
      final inviteId = (widget.inviteId ?? '').trim();
      if (inviteId.isNotEmpty) {
        final inviteUpdate = <String, dynamic>{
          'debug.$uid.stage': stage,
          'debug.$uid.at': FieldValue.serverTimestamp(),
          'debug.$uid.meta': payload['meta'],
        };
        await FirebaseFirestore.instance
            .collection('callInvites')
            .doc(inviteId)
            .set({
          ...inviteUpdate,
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _begin();
  }

  Future<void> _clearStoredAcceptedCallRecovery() async {
    if (_nativeAcceptedCallCleared) return;
    _nativeAcceptedCallCleared = true;
    try {
      await _pushTokenChannel.invokeMethod('clearStoredAcceptedCall');
    } catch (_) {
      _nativeAcceptedCallCleared = false;
    }
  }

  Future<void> _begin() async {
    try {
      await _diagCall('begin_start', meta: {
        'isCaller': widget.isCaller,
        'isVideo': widget.isVideo,
        'inviteId': widget.inviteId ?? '',
      });
      await _diagCall('engine_wait_previous_shutdown');
      try {
        await _lastEngineShutdown;
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await _clearStoredAcceptedCallRecovery();
      final channel = widget.channelName;
      if (channel.isEmpty) throw Exception('Channel name is empty');
      if (channel.length > 64) throw Exception('Channel name too long');

      await _cleanupEngine();
      await _diagCall('engine_precleanup_done');

      // Permissions (request sequentially to avoid iOS prompt issues)
      await _ensurePermission(Permission.microphone, 'Microphone');
      await _diagCall('mic_permission_ok');
      if (widget.isVideo) {
        await _ensurePermission(Permission.camera, 'Camera');
        await _diagCall('camera_permission_ok');
      }

      final inviteId = (widget.inviteId ?? '').trim();
      if (!widget.isCaller && inviteId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('callInvites')
              .doc(inviteId)
              .set({
            'status': 'accepted',
            'acceptedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          await _diagCall('invite_marked_accepted');
        } catch (e) {
          await _diagCall('invite_mark_accepted_error', meta: {'error': '$e'});
        }
      }
      await _markCallkitConnectedForAcceptedCall();

      final currentUser = FirebaseAuth.instance.currentUser;
      final requestedUid = _deriveRtcUidFromFirebaseUid(currentUser?.uid ?? '');
      final requestedUserAccount = requestedUid.toString();

      // Token & engine
      final auth = await fetchAgoraToken(
        channelName: channel,
        uid: requestedUid,
        userAccount: requestedUserAccount,
        identityMode: 'uid',
      );
      _token = auth.token;
      _agoraAppId = auth.appId;
      _rtcUserAccount = auth.userAccount;
      _rtcUid = auth.uid > 0 ? auth.uid : requestedUid;
      await _diagCall('token_ok', meta: {
        'rtcUidRequested': requestedUid,
        'rtcUidServer': auth.uid,
        'rtcUidFinal': _rtcUid,
        'rtcUserAccountRequested': requestedUserAccount,
        'rtcUserAccountServer': auth.userAccount,
        'tokenIdentityMode': auth.identityMode,
        'tokenVersion': auth.tokenVersion,
        'appIdSuffix': _agoraAppId!.substring(_agoraAppId!.length - 6),
        'appIdSource': auth.appId.toLowerCase() == _agoraFallbackAppId
            ? 'server_matches_fallback'
            : 'server',
        'serverAppIdLen': auth.appId.length,
        'serverAppIdMatchesFallback':
            auth.appId.toLowerCase() == _agoraFallbackAppId,
        'serverAppIdSuffix': auth.appId.length >= 6
            ? auth.appId.substring(auth.appId.length - 6)
            : auth.appId,
      });

      final engine = await _createAndInitializeEngine();
      await _diagCall('engine_initialized');

      await engine.enableAudio();
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
      await _diagCall('channel_profile_set', meta: {
        'profile': 'communication',
        'source': 'engine_and_join_options',
      });

      final handler = RtcEngineEventHandler(
        onError: (ErrorCodeType err, String msg) {
          _diagCall('agora_error', meta: {'code': '$err', 'msg': msg});
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
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          _joinWatchdog?.cancel();
          _diagCall('join_success', meta: {
            'localUid': connection.localUid ?? -1,
            'elapsedMs': elapsed,
          });
          unawaited(_markCallkitConnected());
          setState(() => _joined = true);
          // If callee never joins, mark as unavailable after 35s
          _ringTimeout?.cancel();
          _ringTimeout = Timer(const Duration(seconds: 45), () {
            if (!mounted) return;
            if (_remoteUid == null && !_ended) {
              _recordMissedCall(reason: 'timeout');
              setState(() {
                _ended = true;
                _fatalError = 'User unavailable';
              });
            }
          });
        },
        onUserJoined: (RtcConnection connection, int uid, int elapsed) async {
          await _diagCall('remote_joined', meta: {'remoteUid': uid});
          _ringTimeout?.cancel();
          _remoteEverJoined = true;
          setState(() {
            _remoteUid = uid;
            _remoteVideoReady = false;
            _remoteVideoMuted = false;
          });
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

          if ((widget.inviteId ?? '').isNotEmpty) {
            try {
              await FirebaseFirestore.instance
                  .collection('callInvites')
                  .doc(widget.inviteId!)
                  .set({
                'status': 'connected',
                'connectedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            } catch (_) {}
          }
        },
        onUserOffline:
            (RtcConnection connection, int uid, UserOfflineReasonType r) {
          _diagCall('remote_offline', meta: {'remoteUid': uid, 'reason': '$r'});
          // Remote hung up/declined
          if (!_remoteEverJoined) {
            _recordMissedCall(reason: 'declined_or_unavailable');
          }
          setState(() {
            _remoteUid = null;
            _fatalError = 'User declined or unavailable';
            _remoteVideoReady = false;
            _remoteVideoMuted = false;
          });
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          _joinWatchdog?.cancel();
          _diagCall('leave_channel');
          setState(() {
            _remoteUid = null;
            _ended = true;
            _remoteVideoReady = false;
            _remoteVideoMuted = false;
          });
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
        'channel': channel,
        'uid': _rtcUid,
        'userAccount': _rtcUserAccount ?? '',
        'joinMode': 'uid',
        'tokenIdentityMode': auth.identityMode,
        'tokenMode': 'provided',
        'publishMicrophoneTrack': true,
        'publishCameraTrack': widget.isVideo,
        'autoSubscribeAudio': true,
        'autoSubscribeVideo': widget.isVideo,
      });
      await engine.joinChannel(
        token: _token ?? '',
        channelId: channel,
        uid: _rtcUid,
        options: joinOptions,
      );
      await _diagCall('join_returned', meta: {
        'channel': channel,
        'uid': _rtcUid,
        'joinMode': 'uid',
        'tokenIdentityMode': auth.identityMode,
      });
      await _pollConnectionState('join_returned');
      _scheduleConnectionStatePolls();
      _startJoinWatchdog(channel);
      _bindInviteStatus();
      await _diagCall('begin_done');
    } catch (e) {
      if (_engine != null) {
        _lastEngineShutdown = _cleanupEngine();
        await _lastEngineShutdown;
      }
      await _diagCall('begin_error', meta: {'error': '$e'});
      if (mounted) {
        setState(() => _fatalError = e.toString());
      }
      _scheduleAutoClose('begin_error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<RtcEngine> _createAndInitializeEngine() async {
    return _createAndInitializeEngineAttempt(attempt: 1);
  }

  String _sanitizeAgoraLogSegment(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return cleaned.isEmpty ? 'call' : cleaned;
  }

  Future<String?> _prepareAgoraLogPath({required int attempt}) async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final agoraDir = Directory('${supportDir.path}/agora_logs');
      await agoraDir.create(recursive: true);
      final callId = _sanitizeAgoraLogSegment(
        (widget.inviteId ?? '').trim().isNotEmpty
            ? widget.inviteId!.trim()
            : widget.channelName,
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
        try {
          await FirebaseFirestore.instance
              .collection('callInvites')
              .doc(inviteId)
              .set({
            'status': 'ended',
            'endedAt': FieldValue.serverTimestamp(),
            'endedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
            'endReason': 'join_watchdog_timeout',
          }, SetOptions(merge: true));
        } catch (_) {}
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

  void _bindInviteStatus() {
    final id = (widget.inviteId ?? '').trim();
    if (id.isEmpty) return;
    _inviteSub?.cancel();
    _inviteSub = FirebaseFirestore.instance
        .collection('callInvites')
        .doc(id)
        .snapshots()
        .listen((snap) {
      if (!mounted || !snap.exists) return;
      final data = snap.data() ?? const <String, dynamic>{};
      final status = (data['status'] ?? '').toString().toLowerCase();
      if (status == 'declined' ||
          status == 'ended' ||
          status == 'cancelled' ||
          status == 'missed') {
        if (_seenTerminalInviteStatus == status) return;
        _seenTerminalInviteStatus = status;
        _diagCall('invite_status_terminal', meta: {'status': status});
        _ringTimeout?.cancel();
        if (!_ended) {
          setState(() {
            _ended = true;
            _fatalError = 'Call ended';
          });
        }
        _scheduleAutoClose('invite_status_terminal');
      }
    });
  }

  String _chatIdFor(String a, String b) {
    final ids = [a, b]..sort();
    return ids.join('_');
  }

  Future<void> _recordMissedCall({required String reason}) async {
    if (_missedLogged || !widget.isCaller) return;
    final other = (widget.otherUserId ?? '').trim();
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null || other.isEmpty || me == other) return;

    _missedLogged = true;
    final now = Timestamp.now();
    final chatId = _chatIdFor(me, other);
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
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

      final inviteId = (widget.inviteId ?? '').trim();
      if (inviteId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('callInvites')
            .doc(inviteId)
            .set({
          'status': 'missed',
          'missedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
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
    if (engine == null) return;
    final handler = _eventHandler;
    _engine = null;
    _eventHandler = null;
    try {
      if (handler != null) {
        engine.unregisterEventHandler(handler);
      }
    } catch (_) {}
    try {
      await engine.leaveChannel().timeout(const Duration(seconds: 2));
    } catch (_) {}
    if (widget.isVideo) {
      try {
        await engine.stopPreview().timeout(const Duration(seconds: 1));
      } catch (_) {}
    }
    if (release) {
      try {
        await engine.release(sync: true).timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  Future<void> _closeScreenAfterTerminalState(String reason) async {
    if (_endingCall) return;
    _endingCall = true;
    _autoCloseTimer?.cancel();
    await _diagCall('screen_auto_close', meta: {'reason': reason});
    try {
      await _cleanupEngine();
      final callkitId = _callkitId;
      if (callkitId.isNotEmpty) {
        try {
          await FlutterCallkitIncoming.endCall(callkitId);
        } catch (_) {}
      }
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
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
    _ringTimeout?.cancel();
    _joinWatchdog?.cancel();
    _autoCloseTimer?.cancel();
    _inviteSub?.cancel();
    _lastEngineShutdown = _cleanupEngine();
    super.dispose();
  }

  Future<void> _toggleMute() async {
    _muted = !_muted;
    await _engine?.muteLocalAudioStream(_muted);
    setState(() {});
  }

  Future<void> _toggleSpeaker() async {
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
      await _diagCall('end_call_pressed');
      _joinWatchdog?.cancel();
      final id = (widget.inviteId ?? '').trim();
      final endedBy = FirebaseAuth.instance.currentUser?.uid ?? '';
      await _cleanupEngine();
      final callkitId = _callkitId;
      if (callkitId.isNotEmpty) {
        try {
          await FlutterCallkitIncoming.endCall(callkitId);
        } catch (_) {}
      }
      if (id.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('callInvites')
              .doc(id)
              .set({
            'status': 'ended',
            'endedAt': FieldValue.serverTimestamp(),
            'endedBy': endedBy,
          }, SetOptions(merge: true));
        } catch (_) {}
      }
      if (mounted) Navigator.of(context).pop();
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
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_fatalError != null) {
      return _ErrorScreen(
          title: title, message: _fatalError!, onClose: () => _endCall());
    }

    if (_ended) {
      return _EndedScreen(title: title, onClose: () => _endCall());
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
          ],
        ),
      ),
      bottomNavigationBar: _controlsBar(),
    );
  }

  Widget _videoLayout() {
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
              connection: RtcConnection(channelId: widget.channelName),
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
                  child: Row(
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
                        label: _remoteUid != null ? 'Connected' : 'Calling…',
                      ),
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
                          color: Colors.black.withOpacity(0.38),
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
                                color: Colors.black.withOpacity(0.55),
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

  Widget _controlsBar({bool video = false}) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        color: video ? Colors.black.withOpacity(0.35) : AppColors.canvas,
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
        color: Colors.black.withOpacity(0.45),
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
            BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8)
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
  const _EndedScreen({required this.title, required this.onClose});
  final String title;
  final VoidCallback onClose;

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
            const Text(
              'Call ended',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
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
  });

  final String title;
  final String message;
  final VoidCallback onClose;

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
