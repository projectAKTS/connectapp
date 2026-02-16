// lib/screens/consultation/consultation_call_screen.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:connect_app/theme/tokens.dart';
import '/services/interaction_service.dart';

const String appId = 'dac900a04a87460c87c3d18b63cac65d';

/// ---- FETCH TOKEN FROM REMOTE SERVER ----
Future<String> fetchAgoraToken(String channelName, int uid) async {
  final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
      .httpsCallable('getAgoraRtcToken');
  final response = await callable.call({
    'channelName': channelName,
    'uid': uid,
    'role': 'publisher',
    'expireSeconds': 3600,
  });
  final data = (response.data as Map?) ?? const {};
  final token = (data['token'] ?? '').toString().trim();
  if (token.isEmpty) {
    throw Exception('Token service returned empty token');
  }
  return token;
}

class ConsultationCallScreen extends StatefulWidget {
  final String roomId; // Agora channel
  final String otherUserId;
  final String otherUserName;

  const ConsultationCallScreen({
    Key? key,
    required this.roomId,
    required this.otherUserId,
    required this.otherUserName,
  }) : super(key: key);

  @override
  State<ConsultationCallScreen> createState() => _ConsultationCallScreenState();
}

class _ConsultationCallScreenState extends State<ConsultationCallScreen> {
  RtcEngine? _engine;
  String? _token;

  bool _joined = false;
  int? _remoteUid;

  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  bool _micMuted = false;
  bool _camOff = false;

  bool _interactionRecorded = false;

  @override
  void initState() {
    super.initState();
    _setupAgora();
  }

  Future<void> _setupAgora() async {
    try {
      // Permissions
      await _ensurePermission(Permission.microphone, 'Microphone');
      await _ensurePermission(Permission.camera, 'Camera');

      // Fetch token
      _token = await fetchAgoraToken(widget.roomId, 0);

      // Create + init engine
      final engine = createAgoraRtcEngine();
      _engine = engine;

      await engine.initialize(const RtcEngineContext(appId: appId));
      await engine.enableVideo();
      await engine.setChannelProfile(ChannelProfileType.channelProfileCommunication);

      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) async {
            if (!mounted) return;
            setState(() => _joined = true);

            // (Optional) record “started call”
            await _recordInteractionOnce();
          },
          onUserJoined: (connection, uid, elapsed) async {
            if (!mounted) return;
            setState(() => _remoteUid = uid);

            // ✅ record when the other user actually joins
            await _recordInteractionOnce();
          },
          onUserOffline: (connection, uid, reason) {
            if (!mounted) return;
            setState(() => _remoteUid = null);
          },
          onError: (err, msg) {
            if (!mounted) return;
            setState(() {
              _hasError = true;
              _errorMessage = 'Agora error: $err - $msg';
            });
          },
        ),
      );

      await engine.startPreview();

      // Join channel
      await engine.joinChannel(
        token: _token!,
        channelId: widget.roomId,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = 'Setup failed: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _ensurePermission(Permission permission, String label) async {
    final status = await permission.status;
    if (status.isGranted) return;
    final result = await permission.request();
    if (!result.isGranted) {
      throw Exception('$label permission denied ($result).');
    }
  }

  Future<void> _recordInteractionOnce() async {
    if (_interactionRecorded) return;
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return;
    _interactionRecorded = true;
    await InteractionService.recordInteraction(widget.otherUserId);
  }

  @override
  void dispose() {
    final engine = _engine;
    _engine = null;
    () async {
      try {
        await engine?.leaveChannel();
        await engine?.stopPreview();
        await engine?.release();
      } catch (_) {}
    }();
    super.dispose();
  }

  Future<void> _endCall() async {
    try {
      await _engine?.leaveChannel();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _toggleMic() async {
    _micMuted = !_micMuted;
    await _engine?.muteLocalAudioStream(_micMuted);
    if (mounted) setState(() {});
  }

  Future<void> _toggleCam() async {
    _camOff = !_camOff;
    await _engine?.muteLocalVideoStream(_camOff);
    if (mounted) setState(() {});
  }

  Future<void> _switchCamera() async {
    await _engine?.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          backgroundColor: AppColors.canvas,
          title: const Text('Consultation Call'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError) {
      final isPermissionError =
          (_errorMessage ?? '').toLowerCase().contains('permission');
      return Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          backgroundColor: AppColors.canvas,
          title: const Text('Consultation Call'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? 'Unknown error occurred',
                  style: const TextStyle(fontSize: 16, color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (isPermissionError) ...[
                  OutlinedButton(
                    onPressed: openAppSettings,
                    child: const Text('Open Settings'),
                  ),
                  const SizedBox(height: 10),
                ],
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final joined = _joined;
    final remote = _remoteUid;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Consultation • ${widget.otherUserName}'),
      ),
      body: Stack(
        children: [
          // Remote (or waiting)
          Positioned.fill(
            child: joined
                ? (remote != null
                    ? AgoraVideoView(
                        controller: VideoViewController.remote(
                          rtcEngine: _engine!,
                          canvas: VideoCanvas(uid: remote),
                          connection: RtcConnection(channelId: widget.roomId),
                        ),
                      )
                    : _waitingUi())
                : const Center(child: CircularProgressIndicator()),
          ),

          // Local preview (top-right)
          Positioned(
            top: 14,
            right: 14,
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              clipBehavior: Clip.antiAlias,
              child: (_engine == null)
                  ? const SizedBox.shrink()
                  : AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: _engine!,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    ),
            ),
          ),

          // Controls (bottom)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ctrlButton(
                      icon: _micMuted ? Icons.mic_off : Icons.mic,
                      label: _micMuted ? 'Muted' : 'Mic',
                      onTap: _toggleMic,
                    ),
                    _ctrlButton(
                      icon: _camOff ? Icons.videocam_off : Icons.videocam,
                      label: _camOff ? 'Camera off' : 'Camera',
                      onTap: _toggleCam,
                    ),
                    _ctrlButton(
                      icon: Icons.cameraswitch,
                      label: 'Flip',
                      onTap: _switchCamera,
                    ),
                    _hangupButton(onTap: _endCall),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _waitingUi() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 14),
            Text(
              'Waiting for the other participant…',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _ctrlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 74,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _hangupButton({required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 74,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.call_end, color: Colors.white, size: 24),
            SizedBox(height: 6),
            Text('End', style: TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
