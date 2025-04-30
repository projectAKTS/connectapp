// lib/screens/Agora_Call_Screen.dart

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

const String appId = '7ed4caa5d4e34f6894d0fc682b7e4dec';
const String token = '007eJxTYQAo4dogfMRmbdPMe0VrBbt/bUzfn7kJG+GW8OO5ImsCmYK';
const String channelName = 'TestAKTS';

class AgoraCallScreen extends StatefulWidget {
  const AgoraCallScreen({Key? key}) : super(key: key);
  @override
  _AgoraCallScreenState createState() => _AgoraCallScreenState();
}

class _AgoraCallScreenState extends State<AgoraCallScreen> {
  late final RtcEngine _engine;
  int? _remoteUid;
  bool _joined = false;

  @override
  void initState() {
    super.initState();
    _setupAgora();
  }

  Future<void> _setupAgora() async {
    // Request camera and microphone permissions
    await [Permission.camera, Permission.microphone].request();

    // Create the engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: appId));

    // Enable video
    await _engine.enableVideo();

    // Register event handlers
    _engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        setState(() { _joined = true; });
      },
      onUserJoined: (connection, uid, elapsed) {
        setState(() { _remoteUid = uid; });
      },
      onUserOffline: (connection, uid, reason) {
        setState(() { _remoteUid = null; });
      },
    ));

    // Join the channel
    await _engine.joinChannel(
      token: token,
      channelId: channelName,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  @override
  void dispose() {
    // Clean up the engine
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agora Video Call')),
      body: Center(
        child: _joined
            ? (_remoteUid != null
                ? Text('Connected to user ID: \$_remoteUid')
                : const Text('Waiting for another user to join...'))
            : const CircularProgressIndicator(),
      ),
    );
  }
}