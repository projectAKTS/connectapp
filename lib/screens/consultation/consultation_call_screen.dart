// lib/screens/consultation/consultation_call_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '/services/interaction_service.dart';

const String appId = 'dac900a04a87460c87c3d18b63cac65d';

/// ---- FETCH TOKEN FROM REMOTE SERVER ----
Future<String> fetchAgoraToken(String channelName, int uid) async {
  final url = Uri.parse(
    'https://agora-token-server-production-2a8c.up.railway.app/getToken',
  );

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
    return (body['token'] ?? '').toString();
  } else {
    throw Exception('Failed to fetch Agora token: ${response.body}');
  }
}

/// ---- MAIN SCREEN ----
class ConsultationCallScreen extends StatefulWidget {
  final String roomId; // usually consultation ID or Agora channel name
  final String otherUserId; // 👈 Firestore UID of other participant
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
  late final RtcEngine _engine;
  String? _token;

  bool _joined = false;
  int? _remoteUid;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _setupAgora();
  }

  Future<void> _setupAgora() async {
    try {
      // Request permissions
      await [Permission.microphone, Permission.camera].request();

      // Fetch token
      final token = await fetchAgoraToken(widget.roomId, 0);
      _token = token;

      // Initialize engine
      _engine = createAgoraRtcEngine();
      await _engine.initialize(const RtcEngineContext(appId: appId));
      await _engine.enableVideo();

      // Event handlers
      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            setState(() => _joined = true);
          },
          onUserJoined: (connection, uid, elapsed) async {
            setState(() => _remoteUid = uid);

            // ✅ Record connection once both users join
            final me = FirebaseAuth.instance.currentUser?.uid;
            if (me != null) {
              await InteractionService.recordInteraction(widget.otherUserId);
            }
          },
          onUserOffline: (connection, uid, reason) {
            setState(() => _remoteUid = null);
          },
          onError: (err, msg) {
            setState(() {
              _hasError = true;
              _errorMessage = 'Agora error: $err - $msg';
            });
          },
        ),
      );

      // Join channel
      await _engine.joinChannel(
        token: token,
        channelId: widget.roomId,
        uid: 0,
        options: const ChannelMediaOptions(),
      );
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Setup failed: $e';
      });
    } finally {
      setState(() => _isLoading = false);
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

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Consultation Call')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError) {
      return Scaffold(
        appBar: AppBar(title: Text('Consultation Call')),
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
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Consultation with ${widget.otherUserName}'),
      ),
      body: Center(
        child: _joined
            ? (_remoteUid != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.video_call, size: 64, color: Colors.green),
                      const SizedBox(height: 16),
                      Text(
                        'Connected with ${widget.otherUserName}',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Waiting for the other participant...'),
                    ],
                  ))
            : const CircularProgressIndicator(),
      ),
    );
  }
}
