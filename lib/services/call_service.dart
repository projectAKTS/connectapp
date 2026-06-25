import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:connect_app/services/call_session_manager.dart';

class CallService {
  static String generateChannelName(String uid1, String uid2) {
    return CallSessionManager.generateChannelName(uid1, uid2);
  }

  Future<void> startCall(
    BuildContext context, {
    required String toUid,
    required String toName,
    required bool isVideo,
    bool navigateCaller = true,
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) throw Exception('Not signed in');

    if (navigateCaller) {
      if (!context.mounted) return;
      await CallSessionManager.instance.startOutgoingCall(
        context,
        toUid: toUid,
        toName: toName,
        isVideo: isVideo,
      );
    }
  }
}
