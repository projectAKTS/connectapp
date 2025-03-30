import 'package:cloud_firestore/cloud_firestore.dart';

class GamificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ Award XP, Track Actions, and Unlock Badges
  Future<void> awardXP(
    String userId,
    int xp, {
    bool isPost = false,
    bool isHelpful = false,
    bool isComment = false,
    bool isLike = false,
    bool isShare = false,
    bool isBoost = false,
  }) async {
    DocumentReference userRef = _firestore.collection('users').doc(userId);

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot userDoc = await transaction.get(userRef);
      if (!userDoc.exists) return;

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      int currentXP = userData['xpPoints'] ?? 0;
      int newXP = isBoost ? currentXP - xp : currentXP + xp;
      if (newXP < 0) return;

      int newPostCount = (userData['postCount'] ?? 0) + (isPost ? 1 : 0);
      int newCommentCount = (userData['commentCount'] ?? 0) + (isComment ? 1 : 0);
      int helpfulMarks = (userData['helpfulMarks'] ?? 0) + (isHelpful ? 1 : 0);

      List<String> updatedBadges = List<String>.from(userData['badges'] ?? []);

      if (isHelpful) {
        List<Map<String, dynamic>> helpfulVotesGiven =
            List<Map<String, dynamic>>.from(userData['helpfulVotesGiven'] ?? []);
        helpfulVotesGiven.add({
          'date': DateTime.now().toString().substring(0, 10),
        });
        transaction.update(userRef, {'helpfulVotesGiven': helpfulVotesGiven});
      }

      if (newPostCount == 2 && !updatedBadges.contains('🏅 First Contributor')) {
        updatedBadges.add('🏅 First Contributor');
      }
      if (newPostCount == 5 && !updatedBadges.contains('🌟 Profile Highlight')) {
        updatedBadges.add('🌟 Profile Highlight');
      }
      if (newPostCount == 15 && !updatedBadges.contains('🚀 Priority Post Boost')) {
        updatedBadges.add('🚀 Priority Post Boost');
      }

      if (newXP >= 100 && !updatedBadges.contains('🥉 Beginner Helper')) {
        updatedBadges.add('🥉 Beginner Helper');
      }
      if (newXP >= 300 && !updatedBadges.contains('🥈 Skilled Helper')) {
        updatedBadges.add('🥈 Skilled Helper');
      }
      if (newXP >= 500 && !updatedBadges.contains('🥇 Expert Helper')) {
        updatedBadges.add('🥇 Expert Helper');
      }
      if (newXP >= 1000 && !updatedBadges.contains('👑 Legendary Helper')) {
        updatedBadges.add('👑 Legendary Helper');
      }

      if (helpfulMarks == 5 && !updatedBadges.contains('❤ Kind Contributor')) {
        updatedBadges.add('❤ Kind Contributor');
      }
      if (helpfulMarks == 20 && !updatedBadges.contains('🌟 Trusted Problem Solver')) {
        updatedBadges.add('🌟 Trusted Problem Solver');
      }

      if (newCommentCount == 5 && !updatedBadges.contains('💬 Conversationalist')) {
        updatedBadges.add('💬 Conversationalist');
      }
      if (newCommentCount == 50 && !updatedBadges.contains('🧠 Community Mentor')) {
        updatedBadges.add('🧠 Community Mentor');
      }

      if (isBoost && !updatedBadges.contains('🚀 Boost Enthusiast')) {
        updatedBadges.add('🚀 Boost Enthusiast');
      }

      // Check for Premium Trial (one-time trial)
      String? premiumStatus = userData['premiumStatus'];
      bool hasUsedTrial = userData['trialUsed'] == true;
      if (newXP >= 300) {
        if (!hasUsedTrial &&
            (premiumStatus == null || premiumStatus.isEmpty || premiumStatus == 'none')) {
          DateTime expiration = DateTime.now().add(const Duration(days: 3));
          transaction.update(userRef, {
            'premiumStatus': 'trial',
            'premiumExpiresAt': expiration,
            'trialUsed': true,
          });

          if (!updatedBadges.contains('⭐ Premium Trial')) {
            updatedBadges.add('⭐ Premium Trial');
          }
        }
      }

      transaction.update(userRef, {
        'xpPoints': newXP,
        'postCount': newPostCount,
        'commentCount': newCommentCount,
        'helpfulMarks': helpfulMarks,
        'badges': updatedBadges,
      });
    });
  }

  /// 🚀 Spend XP for Boosting a Post (unchanged)
  Future<bool> spendXPForBoost(String userId, int xpCost) async {
    DocumentReference userRef = _firestore.collection('users').doc(userId);

    return await _firestore.runTransaction((transaction) async {
      DocumentSnapshot userDoc = await transaction.get(userRef);
      if (!userDoc.exists) return false;

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      int currentXP = userData['xpPoints'] ?? 0;

      if (currentXP < xpCost) return false;

      transaction.update(userRef, {
        'xpPoints': FieldValue.increment(-xpCost),
      });

      return true;
    });
  }
}
