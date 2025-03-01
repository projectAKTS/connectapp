import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class StreakService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ Check and update streaks daily
  Future<void> updateStreak(String userId) async {
    DocumentReference userRef = _firestore.collection('users').doc(userId);

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot userDoc = await transaction.get(userRef);
      if (!userDoc.exists) return;

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      int currentStreak = (userData['streakDays'] ?? 0);
      Timestamp? lastPostDate = userData['lastPostDate'];

      if (lastPostDate == null || _isNewDay(lastPostDate)) {
        currentStreak++;
      } else {
        currentStreak = 1; // Reset streak if inactive
      }

      transaction.update(userRef, {
        'streakDays': currentStreak,
        'lastPostDate': FieldValue.serverTimestamp(),
      });

      // ✅ Notify users at key milestones
      if ([5, 10, 30].contains(currentStreak)) {
        await FirebaseMessaging.instance.sendMessage(
          to: userId,
          data: {
            'title': '🔥 Streak Alert!',
            'body': 'You’re on a $currentStreak-day streak! Keep it up!',
          },
        );
      }
    });
  }

  /// ✅ Helper function to check if it's a new day
  bool _isNewDay(Timestamp lastPostDate) {
    DateTime lastDate = lastPostDate.toDate();
    DateTime today = DateTime.now();
    return today.difference(lastDate).inDays >= 1;
  }
}
