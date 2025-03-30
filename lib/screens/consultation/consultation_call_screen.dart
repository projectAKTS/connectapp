import 'package:flutter/material.dart';
import 'package:jitsi_meet/jitsi_meet.dart';

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
  @override
  void initState() {
    super.initState();
    _joinMeeting();
  }

  Future<void> _joinMeeting() async {
    try {
      var options = JitsiMeetingOptions(room: widget.roomId)
        ..userDisplayName = widget.userName
        ..audioMuted = false
        ..videoMuted = false;
      await JitsiMeet.joinMeeting(options);
    } catch (e) {
      print("Error joining meeting: $e");
    }
  }

  @override
  void dispose() {
    JitsiMeet.removeAllListeners();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Joining ${widget.roomId}'),
      ),
      body: const Center(
        child: Text('Connecting to call...'),
      ),
    );
  }
}
