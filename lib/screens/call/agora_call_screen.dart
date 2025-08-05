import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

// Replace with your real Agora App ID and token for production!
const String appId = '7ed4caa5d4e34f6894d0fc682b7e4dec';
const String token = '007eJxTYQAo4dogfMRmbdPMe0VrBbt/bUzfn7kJG+GW8OO5ImsCmYK';

class AgoraCallScreen extends StatefulWidget {
  final String channelName;
  final bool isVideo;
  final String otherUserId;

  const AgoraCallScreen({
    Key? key,
    required this.channelName,
    required this.isVideo,
    required this.otherUserId,
  }) : super(key: key);

  @override
  State<AgoraCallScreen> createState() => _AgoraCallScreenState();
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
    // Request permissions
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
          setState(() => _remoteUid = null);
        },
      ),
    );

    await _engine.joinChannel(
      token: token,
      channelId: widget.channelName,
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isVideo ? 'Video Call' : 'Audio Call'),
      ),
      body: Center(
        child: _joined
            ? (_remoteUid != null
                ? Text('Connected to user ID: $_remoteUid')
                : const Text('Waiting for another user to join...'))
            : const CircularProgressIndicator(),
      ),
    );
  }
}
