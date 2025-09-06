// lib/debug/firestore_probe.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirestoreProbe {
  static Future<void> run() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('🔎 FirestoreProbe: no user (skipping).');
      return;
    }

    // Print project we’re hitting
    final app = FirebaseFirestore.instance.app;
    debugPrint('🔎 FirestoreProbe: projectId=${app.options.projectId} appId=${app.options.appId}');

    // 1) Read current user doc and print keys
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    try {
      final snap = await userRef.get();
      final data = snap.data();
      debugPrint('🔎 FirestoreProbe: READ users/${user.uid} exists=${snap.exists}');
      if (data != null) {
        final keys = data.keys.toList()..sort();
        debugPrint('🔎 FirestoreProbe: user keys (${keys.length}): $keys');
      }
    } catch (e) {
      debugPrint('❌ FirestoreProbe: READ users/${user.uid} failed -> $e');
    }

    // 2) Try writing FCM fields (same keys NotificationService uses)
    try {
      debugPrint('🔎 FirestoreProbe: WRITE users/${user.uid} (fcmToken,fcmTokens) ...');
      await userRef.set({
        'fcmToken': 'debug-token-123',
        'fcmTokens': FieldValue.arrayUnion(['debug-token-123']),
      }, SetOptions(merge: true));
      debugPrint('✅ FirestoreProbe: WRITE users/${user.uid} OK');
    } on FirebaseException catch (e) {
      debugPrint('❌ FirestoreProbe: WRITE users/${user.uid} FAILED '
          'code=${e.code} message=${e.message}');
    }

    // 3) Try follow create/update (merge) for self -> self (safe probe)
    final followerRef = FirebaseFirestore.instance
        .collection('followers')
        .doc(user.uid) // target user
        .collection('userFollowers')
        .doc(user.uid); // follower is me

    try {
      debugPrint('🔎 FirestoreProbe: SET followers/${user.uid}/userFollowers/${user.uid} ...');
      await followerRef.set({'timestamp': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      debugPrint('✅ FirestoreProbe: SET followers/... OK');
    } on FirebaseException catch (e) {
      debugPrint('❌ FirestoreProbe: SET followers/... FAILED code=${e.code} message=${e.message}');
    }

    // 4) Try delete (unfollow)
    try {
      debugPrint('🔎 FirestoreProbe: DELETE followers/${user.uid}/userFollowers/${user.uid} ...');
      await followerRef.delete();
      debugPrint('✅ FirestoreProbe: DELETE followers/... OK');
    } on FirebaseException catch (e) {
      debugPrint('❌ FirestoreProbe: DELETE followers/... FAILED code=${e.code} message=${e.message}');
    }
  }
}
