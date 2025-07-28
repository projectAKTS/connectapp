// lib/services/post_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connect_app/services/gamification_service.dart';
import 'package:connect_app/utils/time_utils.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GamificationService _gamificationService = GamificationService();

  /// Creates a new post and updates the user's streak.
  Future<void> createPost(
    String content,
    List<String> tags,
    String postType, {
    String? imageUrl,
    bool isProTip = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User must be logged in');

    // 1) Generate a new post ID and build data
    final docRef = _firestore.collection('posts').doc();
    final String postId = docRef.id;
    final userSnap = await _firestore.collection('users').doc(user.uid).get();
    final String userName = userSnap.data()?['fullName'] ?? 'Unknown User';

    final postData = <String, dynamic>{
      'id':           postId,
      'userID':       user.uid,
      'userName':     userName,
      'content':      content,
      'postType':     postType,
      'tags':         tags,
      'timestamp':    FieldValue.serverTimestamp(),
      'likes':        0,
      'commentsCount':0,
      'helpfulVotes': 0,
      'engagementScore': 0,
      'isBoosted':    false,
      'boostExpiresAt': null,
      'boostScore':   0,
      'likedBy':      <String>[],
      'isProTip':     isProTip,
      'isFeatured':   false,
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
    };

    print('POST DEBUG: ${postData.map((k, v) => MapEntry(k, v.runtimeType.toString()))}');
    print('POST FULL: $postData');

    // 2) Write the new post
    await docRef.set(postData);

    // 3) Award XP
    await _gamificationService.awardXP(user.uid, 10, isPost: true);

    // 4) Update streak in the user's document
    final userRef = _firestore.collection('users').doc(user.uid);
    final uSnap = await userRef.get();
    if (uSnap.exists) {
      final data = uSnap.data()!;
      final String today = DateTime.now().toIso8601String().substring(0,10);

      // Robustly handle lastPostDate as String or Timestamp
      String? lastPostDate;
      final lpd = data['lastPostDate'];
      if (lpd is String) {
        lastPostDate = lpd;
      } else if (lpd is Timestamp) {
        lastPostDate = lpd.toDate().toIso8601String().substring(0, 10);
      } else {
        lastPostDate = null;
      }

      final int currentStreak = data['streakDays'] as int? ?? 0;

      int newStreak;
      if (lastPostDate == today) {
        // already posted today → leave streak unchanged
        newStreak = currentStreak;
      } else {
        final String yesterday = DateTime
            .now()
            .subtract(const Duration(days: 1))
            .toIso8601String()
            .substring(0,10);
        // if they posted exactly yesterday → +1, otherwise reset to 1
        newStreak = (lastPostDate == yesterday) ? currentStreak + 1 : 1;
      }

      await userRef.update({
        'streakDays':   newStreak,
        'lastPostDate': today,
      });
    }
  }

  Future<void> boostPost(String postId, int boostDurationHours) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);
    final postRef = _firestore.collection('posts').doc(postId);

    await _firestore.runTransaction((tx) async {
      final uSnap = await tx.get(userRef);
      final pSnap = await tx.get(postRef);
      if (!uSnap.exists || !pSnap.exists) return;

      final uData = uSnap.data()!;
      final String today = DateTime.now().toIso8601String().substring(0,10);
      final String? lastBoost = uData['lastBoostDate'] as String?;
      if (lastBoost == today) {
        throw Exception("You've already boosted today.");
      }

      final int xp = uData['xpPoints'] as int? ?? 0;
      if (xp < 50) {
        throw Exception("Not enough XP to boost.");
      }

      final expireAt = DateTime.now().add(Duration(hours: boostDurationHours));
      tx.update(postRef, {
        'isBoosted': true,
        'boostExpiresAt': expireAt,
        'boostScore': 100,
      });
      tx.update(userRef, {
        'xpPoints': FieldValue.increment(-50),
        'lastBoostDate': today,
      });
    });
  }

  Future<void> removeExpiredBoosts() async {
    final snap = await _firestore
        .collection('posts')
        .where('isBoosted', isEqualTo: true)
        .get();
    for (var doc in snap.docs) {
      final exp = (doc.data()['boostExpiresAt'] as Timestamp?)?.toDate();
      if (exp != null && exp.isBefore(DateTime.now())) {
        await doc.reference.update({
          'isBoosted': false,
          'boostExpiresAt': null,
          'boostScore': 0,
        });
      }
    }
  }

  Future<bool> markPostHelpful(String postId, String ownerId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final userRef = _firestore.collection('users').doc(user.uid);
    final postRef = _firestore.collection('posts').doc(postId);
    final ownerRef = _firestore.collection('users').doc(ownerId);

    return await _firestore.runTransaction((tx) async {
      final uSnap = await tx.get(userRef);
      final pSnap = await tx.get(postRef);
      if (!uSnap.exists || !pSnap.exists) return false;

      final uData = uSnap.data()!;
      final votesGiven = uData['helpfulVotesGiven'] as List<dynamic>? ?? [];
      final String today = DateTime.now().toIso8601String().substring(0,10);

      final hasVoted = votesGiven.any((v) => v['postId'] == postId);
      if (hasVoted) {
        tx.update(userRef, {
          'helpfulVotesGiven': FieldValue.arrayRemove([
            {'postId': postId, 'date': today}
          ])
        });
        tx.update(postRef, {'helpfulVotes': FieldValue.increment(-1)});
        tx.update(ownerRef, {
          'helpfulMarks': FieldValue.increment(-1),
          'xpPoints': FieldValue.increment(-10),
        });
        return true;
      }

      final usedToday = votesGiven.where((v) => v['date'] == today).length;
      if (usedToday >= 5) return false;

      tx.update(userRef, {
        'helpfulVotesGiven': FieldValue.arrayUnion([
          {'postId': postId, 'date': today}
        ])
      });
      tx.update(postRef, {'helpfulVotes': FieldValue.increment(1)});
      tx.update(ownerRef, {
        'helpfulMarks': FieldValue.increment(1),
        'xpPoints': FieldValue.increment(10),
      });
      return true;
    });
  }
}
