import 'package:cloud_firestore/cloud_firestore.dart';

class GamificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ Award XP and check for badge unlocks
  Future<void> awardXP(String userId, int xp) async {
    DocumentReference userRef = _firestore.collection('users').doc(userId);

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot userDoc = await transaction.get(userRef);
      if (!userDoc.exists) return;

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      int newXP = (userData['xpPoints'] ?? 0) + xp;
      int newPostCount = (userData['postCount'] ?? 0) + 1;
      List<String> updatedBadges = List<String>.from(userData['badges'] ?? []);

      // 🔹 Badge Unlock Logic
      if (newPostCount == 2 && !updatedBadges.contains('🏅 First Contributor')) {
        updatedBadges.add('🏅 First Contributor');
      }
      if (newPostCount == 5 && !updatedBadges.contains('🌟 Profile Highlight')) {
        updatedBadges.add('🌟 Profile Highlight');
      }
      if (newPostCount == 15 && !updatedBadges.contains('🚀 Priority Post Boost')) {
        updatedBadges.add('🚀 Priority Post Boost');
      }

      transaction.update(userRef, {
        'xpPoints': newXP,
        'postCount': newPostCount,
        'badges': updatedBadges,
      });
    });
  }
}
