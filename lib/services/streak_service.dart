import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class StreakService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ Check and update daily login/posting streaks
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
      }

      // 🔹 Streak Badges
      List<String> updatedBadges = List<String>.from(userData['badges'] ?? []);
      if (currentStreak == 7 && !updatedBadges.contains('🔥 Streak Starter')) {
        updatedBadges.add('🔥 Streak Starter');
      }
      if (currentStreak == 30 && !updatedBadges.contains('💪 Dedicated Contributor')) {
        updatedBadges.add('💪 Dedicated Contributor');
      }

      transaction.update(userRef, {
        'streakDays': currentStreak,
        'lastPostDate': FieldValue.serverTimestamp(),
        'badges': updatedBadges,
      });

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

  /// ✅ Check if it's a new day
  bool _isNewDay(Timestamp lastPostDate) {
    DateTime lastDate = lastPostDate.toDate();
    DateTime today = DateTime.now();
    return today.difference(lastDate).inDays >= 1;
  }
}
