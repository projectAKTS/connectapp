import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String appId = 'dac900a04a87460c87c3d18b63cac65d';

// ---- TOKEN FETCH FUNCTION (POST, production-ready) ----
Future<String> fetchAgoraToken(String channelName, int uid) async {
  final url = Uri.parse('https://agora-token-server-production-2a8c.up.railway.app/getToken');
  final response = await http.post(
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
  if (response.statusCode == 200) {
    final body = jsonDecode(response.body);
    return body['token'] ?? '';
  } else {
    throw Exception('Failed to get token: ${response.body}');
  }
}

class AgoraCallScreen extends StatefulWidget {
  final String channelName;
  final bool isVideo;
  final String otherUserName; // Pass display name here!

  const AgoraCallScreen({
    Key? key,
    required this.channelName,
    required this.isVideo,
    required this.otherUserName, // <-- display name, not UID!
  }) : super(key: key);

  @override
  State<AgoraCallScreen> createState() => _AgoraCallScreenState();
}

class _AgoraCallScreenState extends State<AgoraCallScreen> {
  late final RtcEngine _engine;
  int? _remoteUid;
  bool _joined = false;
  bool _callEnded = false;
  bool _isError = false;
  String? _errorMessage;
  bool _isLoadingToken = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _fetchTokenAndSetupAgora();
  }

  Future<void> _fetchTokenAndSetupAgora() async {
    try {
      final token = await fetchAgoraToken(widget.channelName, 0);
      setState(() {
        _token = token;
        _isLoadingToken = false;
      });
      await _setupAgora(token);
    } catch (e) {
      setState(() {
        _isError = true;
        _errorMessage = 'Token fetch/setup error: $e';
        _isLoadingToken = false;
      });
    }
  }

  Future<void> _setupAgora(String token) async {
    try {
      if (widget.isVideo) {
        await [Permission.camera, Permission.microphone].request();
      } else {
        await Permission.microphone.request();
      }
      _engine = createAgoraRtcEngine();
      await _engine.initialize(RtcEngineContext(appId: appId));
      if (widget.isVideo) {
        await _engine.enableVideo();
      } else {
        await _engine.disableVideo();
      }

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            setState(() => _joined = true);
          },
          onUserJoined: (connection, uid, elapsed) {
            setState(() => _remoteUid = uid);
          },
          onUserOffline: (connection, uid, reason) {
            setState(() {
              _callEnded = true;
              _remoteUid = null;
            });
          },
          onLeaveChannel: (connection, stats) {
            setState(() {
              _callEnded = true;
              _remoteUid = null;
            });
          },
          onError: (err, msg) {
            setState(() {
              _isError = true;
              _errorMessage = 'Agora error: $err - $msg';
            });
          },
        ),
      );

      await _engine.joinChannel(
        token: token,
        channelId: widget.channelName,
        uid: 0,
        options: const ChannelMediaOptions(),
      );
    } catch (e) {
      setState(() {
        _isError = true;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  void _endCall() {
    _engine.leaveChannel();
    Navigator.of(context).pop();
  }

  Widget _buildConnecting() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.purple.shade50,
            child: Icon(
              widget.isVideo ? Icons.videocam : Icons.phone,
              size: 36,
              color: Colors.purple,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            widget.isVideo ? "Video Call" : "Audio Call",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            "Calling ${widget.otherUserName}...",
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 40),
          const SizedBox(
            width: 48, height: 48,
            child: CircularProgressIndicator(strokeWidth: 5, color: Colors.deepPurple),
          ),
          const SizedBox(height: 32),
          Text(
            _joined ? "Waiting for user to join..." : "Connecting...",
            style: const TextStyle(fontSize: 17, color: Colors.grey),
          ),
          const SizedBox(height: 48),
          ElevatedButton.icon(
            onPressed: _endCall,
            icon: const Icon(Icons.call_end),
            label: const Text("Cancel Call"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size(220, 55),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnected() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 64),
          const SizedBox(height: 18),
          const Text(
            "Connected!",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          Text(
            "You are talking with: ${widget.otherUserName}",
            style: const TextStyle(fontSize: 17),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _endCall,
            icon: const Icon(Icons.call_end),
            label: const Text("End Call"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size(180, 50),
              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallEnded() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, color: Colors.grey, size: 50),
          const SizedBox(height: 20),
          const Text(
            "Call ended",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Close"),
          )
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 50),
          const SizedBox(height: 20),
          const Text(
            "Something went wrong.",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 14, color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Close"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingToken) {
      return Scaffold(
        appBar: AppBar(title: const Text('Connecting...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8F0F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(onPressed: _endCall),
        title: Text(widget.isVideo ? 'Video Call' : 'Audio Call'),
        centerTitle: true,
      ),
      body: _isError
          ? _buildError()
          : _callEnded
              ? _buildCallEnded()
              : (_remoteUid != null
                  ? _buildConnected()
                  : _buildConnecting()),
    );
  }
}
