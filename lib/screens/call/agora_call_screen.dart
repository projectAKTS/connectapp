// lib/call/agora_call_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:connect_app/theme/tokens.dart';
import '/services/interaction_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

const String appId = 'dac900a04a87460c87c3d18b63cac65d';

/// ---- TOKEN FETCH ----
Future<String> fetchAgoraToken({
  required String channelName,
  required int uid,
}) async {
  final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
      .httpsCallable('getAgoraRtcToken');
  final resp = await callable.call({
    'channelName': channelName,
    'uid': uid,
    'role': 'publisher',
    'expireSeconds': 3600,
  });
  final data = (resp.data as Map?) ?? const {};
  final token = (data['token'] as String?)?.trim();
  if (token == null || token.isEmpty) {
    throw Exception('Token service returned empty token');
  }
  return token;
}

class AgoraCallScreen extends StatefulWidget {
  final String channelName;
  final bool isVideo;
  final String otherUserName;

  const AgoraCallScreen({
    Key? key,
    required this.channelName,
    required this.isVideo,
    required this.otherUserName,
  }) : super(key: key);

  @override
  State<AgoraCallScreen> createState() => _AgoraCallScreenState();
}

class _AgoraCallScreenState extends State<AgoraCallScreen> {
  late final RtcEngine _engine;
  String? _token;

  bool _joined = false;
  int? _remoteUid;
  bool _ended = false;
  bool _isLoading = true;
  String? _fatalError;

  // Controls
  bool _muted = false;
  bool _speakerOn = true;
  bool _frontCamera = true;

  // Video layout state
  bool _localIsBig = false; // tap to swap big/local
  Offset _pipPos = const Offset(12, 120); // PiP top-left corner

  Timer? _ringTimeout;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  Future<void> _begin() async {
    try {
      final channel = widget.channelName;
      if (channel.isEmpty) throw Exception('Channel name is empty');
      if (channel.length > 64) throw Exception('Channel name too long');

      // Permissions (request sequentially to avoid iOS prompt issues)
      await _ensurePermission(Permission.microphone, 'Microphone');
      if (widget.isVideo) {
        await _ensurePermission(Permission.camera, 'Camera');
      }

      // Token & engine
      const int uid = 0; // let SDK assign, token also for 0
      _token = await fetchAgoraToken(channelName: channel, uid: uid);

      _engine = createAgoraRtcEngine();
      await _engine.initialize(const RtcEngineContext(appId: appId));

      await _engine.setChannelProfile(ChannelProfileType.channelProfileCommunication);
      await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine.enableAudio();
      await _engine.setDefaultAudioRouteToSpeakerphone(true);

      if (widget.isVideo) {
        await _engine.enableVideo();
        await _engine.startPreview();
      } else {
        await _engine.disableVideo();
      }

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onError: (ErrorCodeType err, String msg) {
            setState(() => _fatalError = 'Agora error: $err - $msg');
          },
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            setState(() => _joined = true);
            // If callee never joins, mark as unavailable after 35s
            _ringTimeout?.cancel();
            _ringTimeout = Timer(const Duration(seconds: 35), () {
              if (!mounted) return;
              if (_remoteUid == null && !_ended) {
                setState(() => _fatalError = 'User unavailable');
              }
            });
          },
          onUserJoined: (RtcConnection connection, int uid, int elapsed) async {
          _ringTimeout?.cancel();
          setState(() => _remoteUid = uid);

          // 👇 Add this
          final me = FirebaseAuth.instance.currentUser?.uid;
          if (me != null) {
            // Extract the other user ID from channelName if you encoded it like `${me}_${otherId}`
            final parts = widget.channelName.split('_');
            final other = parts.firstWhere((p) => p != me, orElse: () => '');
            if (other.isNotEmpty) {
              await InteractionService.recordInteraction(other);
            }
          }
        },

          onUserOffline: (RtcConnection connection, int uid, UserOfflineReasonType r) {
            // Remote hung up/declined
            setState(() {
              _remoteUid = null;
              _fatalError = 'User declined or unavailable';
            });
          },
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            setState(() {
              _remoteUid = null;
              _ended = true;
            });
          },
        ),
      );

      await _engine.joinChannel(
        token: _token!,
        channelId: channel,
        uid: uid,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishMicrophoneTrack: true,
          publishCameraTrack: widget.isVideo,
          autoSubscribeAudio: true,
          autoSubscribeVideo: widget.isVideo,
        ),
      );
    } catch (e) {
      setState(() => _fatalError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _ensurePermission(Permission permission, String label) async {
    final status = await permission.status;
    if (status.isGranted) return;
    final result = await permission.request();
    if (!result.isGranted) {
      throw Exception('$label permission not granted ($result)');
    }
  }

  @override
  void dispose() {
    _ringTimeout?.cancel();
    try {
      _engine.leaveChannel();
      _engine.release();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _toggleMute() async {
    _muted = !_muted;
    await _engine.muteLocalAudioStream(_muted);
    setState(() {});
  }

  Future<void> _toggleSpeaker() async {
    _speakerOn = !_speakerOn;
    await _engine.setEnableSpeakerphone(_speakerOn);
    setState(() {});
  }

  Future<void> _switchCamera() async {
    _frontCamera = !_frontCamera;
    await _engine.switchCamera();
    setState(() {});
  }

  void _endCall() {
    try {
      _engine.leaveChannel();
    } catch (_) {}
    Navigator.of(context).pop();
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
      return _ErrorScreen(title: title, message: _fatalError!, onClose: _endCall);
    }

    if (_ended) {
      return _EndedScreen(title: title, onClose: _endCall);
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
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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
    final remote = (_remoteUid != null)
        ? AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _engine,
              canvas: VideoCanvas(uid: _remoteUid),
              connection: RtcConnection(channelId: widget.channelName),
            ),
          )
        : const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Text(
                'Waiting for the other user to join…',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );

    final local = AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine,
        canvas: const VideoCanvas(uid: 0),
      ),
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
                child: ClipRect(child: _localIsBig ? local : remote),
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
                          Positioned.fill(child: _localIsBig ? remote : local),
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
      onTap: _endCall,
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
              const Icon(Icons.error_outline, color: AppColors.danger, size: 64),
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
