// lib/services/call_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:connect_app/screens/call/agora_call_screen.dart';

class CallService {
  static String generateChannelName(String uid1, String uid2) {
    String clean(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');
    final a = clean(uid1);
    final b = clean(uid2);
    final pair = [a, b]..sort();

    final sa = pair[0].length > 12 ? pair[0].substring(0, 12) : pair[0];
    final sb = pair[1].length > 12 ? pair[1].substring(0, 12) : pair[1];
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);

    var name = 'c_${sa}_${sb}_$ts';
    if (name.length > 64) name = name.substring(0, 64);
    return name;
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

    final meDoc =
        await FirebaseFirestore.instance.collection('users').doc(me.uid).get();
    final fromName = (meDoc.data()?['fullName'] as String?) ??
        (meDoc.data()?['name'] as String?) ??
        'Unknown';

    final channel = generateChannelName(me.uid, toUid);

    await FirebaseFirestore.instance.collection('callInvites').add({
      'fromUid': me.uid,
      'fromName': fromName,
      'toUid': toUid,
      'toName': toName,
      'channel': channel,
      'isVideo': isVideo,
      'status': 'ringing',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (navigateCaller) {
      final nav = Navigator.of(context, rootNavigator: true);
      // ignore: use_build_context_synchronously
      nav.push(
        MaterialPageRoute(
          builder: (_) => AgoraCallScreen(
            channelName: channel,
            isVideo: isVideo,
            otherUserName: toName,
          ),
        ),
      );
    }
  }
}
