// lib/screens/consultation/consultation_call_screen.dart

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

// Bring in your App ID and token from your Agora setup
import '../Agora_Call_Screen.dart' show appId, token;

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

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    // 1. Ask for camera and mic permissions
    await [Permission.camera, Permission.microphone].request();

    // 2. Create and initialize the Agora engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: appId));

    // 3. Enable video
    await _engine.enableVideo();

    // 4. Set up event handlers
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
      ),
    );

    // 5. Join the channel using dynamic roomId
    await _engine.joinChannel(
      token: token,
      channelId: widget.roomId,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  @override
  void dispose() {
    // 1. Leave channel
    _engine.leaveChannel();
    // 2. Release resources
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
