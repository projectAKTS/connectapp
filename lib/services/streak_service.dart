import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:connect_app/utils/time_utils.dart';

class StreakService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> updateStreak(String userId) async {
    DocumentReference userRef = _firestore.collection('users').doc(userId);

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot userDoc = await transaction.get(userRef);
      if (!userDoc.exists) return;

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      int currentStreak = (userData['streakDays'] ?? 0);

      // Robust timestamp parsing
      dynamic lastPostDate = userData['lastPostDate'];
      if (lastPostDate == null || _isNewDay(lastPostDate)) {
        currentStreak++;
      }

      List<String> updatedBadges = List<String>.from(userData['badges'] ?? []);
      if (currentStreak == 7 && !updatedBadges.contains('🔥 Streak Starter')) {
        updatedBadges.add('🔥 Streak Starter');
      }
      if (currentStreak == 30 && !updatedBadges.contains('💪 Dedicated Contributor')) {
        updatedBadges.add('💪 Dedicated Contributor');
      }

      // Debug print
      final updateMap = {
        'streakDays': currentStreak,
        'lastPostDate': FieldValue.serverTimestamp(),
        'badges': updatedBadges,
      };
      print('STREAK DEBUG UPDATE MAP: $updateMap');

      transaction.update(userRef, updateMap);

      if (Platform.isAndroid && [5, 10, 30].contains(currentStreak)) {
        try {
          await FirebaseMessaging.instance.sendMessage(
            to: userId,
            data: {
              'title': '🔥 Streak Alert!',
              'body': 'You’re on a $currentStreak-day streak! Keep it up!',
            },
          );
        } catch (e) {
          print('⚠ Android notification skipped or failed: $e');
        }
      }
    });
  }

  /// Robust day check - accepts Timestamp, String, DateTime, or null
  bool _isNewDay(dynamic lastPostDate) {
    final lastDate = parseFirestoreTimestamp(lastPostDate);
    if (lastDate == null) return true; // treat as new day if missing
    final today = DateTime.now();
    return today.difference(lastDate).inDays >= 1;
  }
}
