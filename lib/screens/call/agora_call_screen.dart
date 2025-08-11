// lib/call/agora_call_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

const String appId = 'dac900a04a87460c87c3d18b63cac65d';

/// ---- TOKEN FETCH (POST to your server) ----
Future<String> fetchAgoraToken({
  required String channelName,
  required int uid,
}) async {
  final url = Uri.parse(
    'https://agora-token-server-production-2a8c.up.railway.app/getToken',
  );

  final resp = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'tokenType': 'rtc',
      'channel': channelName,
      'role': 'publisher', // caller is a broadcaster
      'uid': uid.toString(), // must match joinChannel uid type/value
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
  String? _fatalError; // show in UI

  @override
  void initState() {
    super.initState();
    _begin();
  }

  Future<void> _begin() async {
    try {
      // 1) Validate channel name early
      final channel = widget.channelName;
      debugPrint('👉 Joining channel: "$channel" (len: ${channel.length}) '
          'isVideo=${widget.isVideo}');
      if (channel.isEmpty) throw Exception('Channel name is empty');
      if (channel.length > 64) {
        throw Exception(
          'Channel name is too long (${channel.length}). Must be ≤ 64 characters.',
        );
      }

      // 2) Permissions
      if (widget.isVideo) {
        final statuses =
            await [Permission.microphone, Permission.camera].request();
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

      // 3) Get token (uid must match join)
      const int uid = 0; // 0 lets SDK assign; token must also be for uid 0
      _token = await fetchAgoraToken(channelName: channel, uid: uid);
      debugPrint('✅ Got token (len: ${_token!.length})');

      // 4) Init engine & handlers
      _engine = createAgoraRtcEngine();
      await _engine.initialize(const RtcEngineContext(appId: appId));

      await _engine.setChannelProfile(
        ChannelProfileType.channelProfileCommunication,
      );
      await _engine.setClientRole(
        role: ClientRoleType.clientRoleBroadcaster,
      );
      await _engine.enableAudio();
      await _engine.setDefaultAudioRouteToSpeakerphone(true);

      if (widget.isVideo) {
        await _engine.enableVideo();
      } else {
        await _engine.disableVideo();
      }

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onError: (ErrorCodeType err, String msg) {
            debugPrint('❌ Agora onError: $err - $msg');
            setState(() => _fatalError = 'Agora error: $err - $msg');
          },
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint('✅ Local joined: ${connection.channelId}');
            setState(() => _joined = true);
          },
          onUserJoined: (RtcConnection connection, int uid, int elapsed) {
            debugPrint('👋 Remote joined: $uid');
            setState(() => _remoteUid = uid);
          },
          onUserOffline:
              (RtcConnection connection, int uid, UserOfflineReasonType r) {
            debugPrint('👋 Remote left: $uid reason=$r');
            setState(() {
              _remoteUid = null;
              _ended = true;
            });
          },
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            debugPrint('👋 Local left channel');
            setState(() {
              _remoteUid = null;
              _ended = true;
            });
          },
        ),
      );

      // 5) Join
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
      debugPrint('❌ Call setup failed: $e');
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

  // ---------------- UI ----------------

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

    if (_remoteUid != null) {
      return _ConnectedScreen(
        title: title,
        otherUserName: widget.otherUserName,
        onEnd: _endCall,
      );
    }

    return _ConnectingScreen(
      title: title,
      otherUserName: widget.otherUserName,
      joined: _joined,
      onCancel: _endCall,
    );
  }
}

// ------- Simple screens -------

class _ConnectingScreen extends StatelessWidget {
  const _ConnectingScreen({
    required this.title,
    required this.otherUserName,
    required this.joined,
    required this.onCancel,
  });

  final String title;
  final String otherUserName;
  final bool joined;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F0F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(onPressed: onCancel),
        title: Text(title),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.call, size: 72, color: Colors.purple),
            const SizedBox(height: 16),
            Text('Calling $otherUserName...',
                style: const TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              joined ? 'Waiting for user to join...' : 'Connecting...',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.call_end),
              label: const Text('Cancel Call'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(220, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectedScreen extends StatelessWidget {
  const _ConnectedScreen({
    required this.title,
    required this.otherUserName,
    required this.onEnd,
  });

  final String title;
  final String otherUserName;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F0F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(onPressed: onEnd),
        title: Text(title),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 72),
            const SizedBox(height: 12),
            const Text('Connected!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('You are talking with: $otherUserName'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onEnd,
              icon: const Icon(Icons.call_end),
              label: const Text('End Call'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(180, 48),
              ),
            ),
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
