import 'package:flutter/material.dart';
import 'agora_call_screen.dart';

class IncomingCallScreen extends StatelessWidget {
  const IncomingCallScreen({
    super.key,
    required this.channel,
    required this.isVideo,
    required this.fromName,
  });

  final String channel;
  final bool isVideo;
  final String fromName;

  @override
  Widget build(BuildContext context) {
    final title = isVideo ? 'Incoming Video Call' : 'Incoming Audio Call';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F0F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(title),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.ring_volume, size: 80, color: Colors.purple),
              const SizedBox(height: 16),
              Text('From $fromName',
                  style: const TextStyle(fontSize: 18, color: Colors.black87)),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => AgoraCallScreen(
                            channelName: channel,
                            isVideo: isVideo,
                            otherUserName: fromName,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.call),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(130, 48),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.call_end),
                    label: const Text('Decline'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(130, 48),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
