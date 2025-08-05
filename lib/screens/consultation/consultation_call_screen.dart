// lib/screens/consultation/consultation_call_screen.dart

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String appId = 'dac900a04a87460c87c3d18b63cac65d';

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

class ConsultationCallScreen extends StatefulWidget {
  final String roomId;
  final String userName;

  const ConsultationCallScreen({
    Key? key,
    required this.roomId,
    required this.userName,
  }) : super(key: key);

  @override
  State<ConsultationCallScreen> createState() => _ConsultationCallScreenState();
}

class _ConsultationCallScreenState extends State<ConsultationCallScreen> {
  late final RtcEngine _engine;
  bool _joined = false;
  int? _remoteUid;
  bool _isError = false;
  String? _errorMessage;
  bool _isLoadingToken = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _fetchTokenAndInitAgora();
  }

  Future<void> _fetchTokenAndInitAgora() async {
    try {
      final token = await fetchAgoraToken(widget.roomId, 0);
      setState(() {
        _token = token;
        _isLoadingToken = false;
      });
      await _initAgora(token);
    } catch (e) {
      setState(() {
        _isError = true;
        _errorMessage = 'Token fetch/setup error: $e';
        _isLoadingToken = false;
      });
    }
  }

  Future<void> _initAgora(String token) async {
    await [Permission.camera, Permission.microphone].request();
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: appId));
    await _engine.enableVideo();
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          setState(() {
            _joined = true;
          });
        },
        onUserJoined: (connection, uid, elapsed) {
          setState(() {
            _remoteUid = uid;
          });
        },
        onUserOffline: (connection, uid, reason) {
          setState(() {
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
      channelId: widget.roomId,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingToken) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Consultation: ${widget.roomId}'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_isError) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Consultation: ${widget.roomId}'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 50),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? "Unknown error.",
                style: const TextStyle(fontSize: 16, color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Close"),
              )
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Consultation: ${widget.roomId}'),
      ),
      body: Center(
        child: _joined
            ? (_remoteUid != null
                ? Text('User ${widget.userName} joined (UID: $_remoteUid)')
                : const Text('Waiting for the other participant...'))
            : const CircularProgressIndicator(),
      ),
    );
  }
}
