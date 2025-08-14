import 'dart:convert';
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

  @override
  void initState() {
    super.initState();
    _begin();
  }

  Future<void> _begin() async {
    try {
      final channel = widget.channelName;
      if (channel.isEmpty) throw Exception('Channel name is empty');
      if (channel.length > 64) {
        throw Exception('Channel name too long (${channel.length}). ≤ 64 chars.');
      }

      // permissions
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

      const int uid = 0; // SDK assigns
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
          },
          onUserJoined: (RtcConnection connection, int uid, int elapsed) {
            setState(() => _remoteUid = uid);
          },
          onUserOffline: (RtcConnection connection, int uid, UserOfflineReasonType r) {
            setState(() {
              _remoteUid = null;
              _ended = true;
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
    try {
      _engine.leaveChannel();
      _engine.release();
    } catch (_) {}
    super.dispose();
  }

  void _endCall() {
    try {
      _engine.leaveChannel();
    } catch (_) {}
    Navigator.of(context).pop();
  }

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

    // VIDEO UI
    if (widget.isVideo) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Talking with ${widget.otherUserName}'),
          actions: [
            IconButton(
              onPressed: _endCall,
              icon: const Icon(Icons.call_end, color: Colors.redAccent),
            ),
          ],
        ),
        body: Stack(
          children: [
            // remote (full screen)
            Positioned.fill(
              child: _remoteUid != null
                  ? AgoraVideoView(
                      controller: VideoViewController.remote(
                        rtcEngine: _engine,
                        canvas: VideoCanvas(uid: _remoteUid),
                        connection: RtcConnection(channelId: widget.channelName),
                      ),
                    )
                  : const Center(
                      child: Text(
                        'Waiting for the other user to join…',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
            ),
            // local (PiP)
            Positioned(
              right: 12,
              bottom: 24,
              width: 120,
              height: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.2)),
                  child: AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: _engine,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // AUDIO UI
    return _ConnectingOrConnectedAudio(
      title: title,
      otherUserName: widget.otherUserName,
      joined: _joined,
      onEnd: _endCall,
    );
  }
}

class _ConnectingOrConnectedAudio extends StatelessWidget {
  const _ConnectingOrConnectedAudio({
    required this.title,
    required this.otherUserName,
    required this.joined,
    required this.onEnd,
  });

  final String title;
  final String otherUserName;
  final bool joined;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F0F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(title),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: onEnd,
            icon: const Icon(Icons.call_end, color: Colors.redAccent),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.call, size: 72, color: Colors.purple),
            const SizedBox(height: 16),
            Text(
              joined ? 'Connected to $otherUserName' : 'Calling $otherUserName…',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            if (!joined) const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

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
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.redAccent),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onClose, child: const Text('Close')),
            ],
          ),
        ),
      ),
    );
  }
}
