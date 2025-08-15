import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

const String appId = 'dac900a04a87460c87c3d18b63cac65d';

Future<String> fetchAgoraToken({
  required String channelName,
  required int uid,
}) async {
  final url = Uri.parse('https://agora-token-server-production-2a8c.up.railway.app/getToken');
  final resp = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'tokenType': 'rtc',
      'channel': channelName,
      'role': 'publisher',
      'uid': uid.toString(),
      'expire': 3600,
    }),
  );
  if (resp.statusCode != 200) {
    throw Exception('Token server error (${resp.statusCode}): ${resp.body}');
  }
  final body = jsonDecode(resp.body);
  final token = (body['token'] as String?)?.trim();
  if (token == null || token.isEmpty) {
    throw Exception('Token server returned empty token');
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

  // controls
  bool _muted = false;
  bool _speakerOn = true;
  bool _frontCamera = true;

  // video layout
  bool _localIsBig = false; // tap to swap
  Offset _pipOffset = const Offset(12, 24); // draggable PiP

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

      if (widget.isVideo) {
        final statuses = await [Permission.microphone, Permission.camera].request();
        if (statuses[Permission.microphone] != PermissionStatus.granted) {
          throw Exception('Microphone permission not granted');
        }
        if (statuses[Permission.camera] != PermissionStatus.granted) {
          throw Exception('Camera permission not granted');
        }
      } else {
        if (await Permission.microphone.request() != PermissionStatus.granted) {
          throw Exception('Microphone permission not granted');
        }
      }

      const int uid = 0;
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
            // if callee doesn't join within 35s → unavailable
            _ringTimeout?.cancel();
            _ringTimeout = Timer(const Duration(seconds: 35), () {
              if (mounted && _remoteUid == null && !_ended) {
                setState(() {
                  _fatalError = 'User unavailable';
                });
              }
            });
          },
          onUserJoined: (RtcConnection connection, int uid, int elapsed) {
            _ringTimeout?.cancel();
            setState(() => _remoteUid = uid);
          },
          onUserOffline: (RtcConnection connection, int uid, UserOfflineReasonType r) {
            // if user leaves/declines after joining
            setState(() {
              _remoteUid = null;
              _fatalError = 'User unavailable';
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

  @override
  void dispose() {
    _ringTimeout?.cancel();
    try { _engine.leaveChannel(); _engine.release(); } catch (_) {}
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
    try { _engine.leaveChannel(); } catch (_) {}
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

    if (widget.isVideo) {
      return _videoLayout();
    }
    return _audioLayout();
  }

  Widget _audioLayout() {
    final status = (_remoteUid != null)
        ? 'Connected to ${widget.otherUserName}'
        : 'Ringing…';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F0F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Audio Call'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.call, size: 72, color: Colors.purple),
            const SizedBox(height: 16),
            Text(status, style: const TextStyle(fontSize: 18, color: Colors.grey)),
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
            child: Text('Waiting for the other user to join…',
                style: TextStyle(color: Colors.white70)),
          );

    final local = AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine,
        canvas: const VideoCanvas(uid: 0),
      ),
    );

    final big = ClipRRect(
      borderRadius: BorderRadius.circular(0),
      child: _localIsBig ? local : remote,
    );

    final pip = GestureDetector(
      onTap: () => setState(() => _localIsBig = !_localIsBig),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 120, height: 180, child: _localIsBig ? remote : local),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: big),
          // draggable PiP
          Positioned(
            right: _pipOffset.dx,
            bottom: _pipOffset.dy + 72, // leave space for bottom bar
            child: Draggable(
              feedback: Material(type: MaterialType.transparency, child: pip),
              childWhenDragging: const SizedBox.shrink(),
              onDragEnd: (d) {
                final size = MediaQuery.of(context).size;
                final x = (size.width - d.offset.dx - 120).clamp(12, size.width - 132);
                final y = (size.height - d.offset.dy - 180).clamp(12, size.height - 252);
                setState(() => _pipOffset = Offset(x.toDouble(), y.toDouble()));
              },
              child: pip,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _controlsBar(video: true),
    );
  }

  Widget _controlsBar({bool video = false}) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        color: video ? Colors.black.withOpacity(0.25) : Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _roundButton(
              icon: _muted ? Icons.mic_off : Icons.mic,
              onTap: _toggleMute,
              isActive: !_muted,
            ),
            if (video)
              _roundButton(
                icon: Icons.cameraswitch,
                onTap: _switchCamera,
                isActive: _frontCamera,
              ),
            _hangupButton(),
            _roundButton(
              icon: Icons.volume_up,
              onTap: _toggleSpeaker,
              isActive: _speakerOn,
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = true,
  }) {
    return InkResponse(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.grey.shade300,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)],
        ),
        child: Icon(icon, color: Colors.black87),
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
          color: Colors.redAccent,
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
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Call ended',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 12),
              const Text('Something went wrong.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.redAccent)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onClose, child: const Text('Close')),
            ],
          ),
        ),
      ),
    );
  }
}
