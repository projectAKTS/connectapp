// lib/services/post_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connect_app/services/gamification_service.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GamificationService _gamificationService = GamificationService();

  /// Creates a new post with 3 positional arguments and 2 named options.
  Future<void> createPost(
    String content,
    List<String> tags,
    String postType, {
    String? imageUrl,
    bool isProTip = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User must be logged in');

    // Use Firestore-generated doc ID as the post ID
    final docRef = _firestore.collection('posts').doc();
    final String postId = docRef.id;

    // Fetch the user's display name
    final userSnap = await _firestore.collection('users').doc(user.uid).get();
    final String userName = userSnap.data()?['fullName'] ?? 'Unknown User';

    // Build the post data map
    final Map<String, dynamic> postData = {
      'id': postId,
      'userID': user.uid,
      'userName': userName,
      'content': content,
      'postType': postType,
      'tags': tags,
      'timestamp': FieldValue.serverTimestamp(),
      'likes': 0,
      'commentsCount': 0,
      'helpfulVotes': 0,
      'engagementScore': 0,
      'isBoosted': false,
      'boostExpiresAt': null,
      'boostScore': 0,
      'likedBy': <String>[],
      'isProTip': isProTip,
      'isFeatured': false,
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
    };

    // Write to Firestore
    await docRef.set(postData);

    // Award XP for creating a post
    await _gamificationService.awardXP(user.uid, 10, isPost: true);
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

      final userData = uSnap.data()!;
      final String today = DateTime.now().toString().substring(0, 10);
      final String? lastBoost = userData['lastBoostDate'];
      if (lastBoost == today) {
        throw Exception("You've already boosted today.");
      }

      final int xp = userData['xpPoints'] ?? 0;
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
      final data = doc.data();
      final exp = data['boostExpiresAt'] as Timestamp?;
      if (exp != null && exp.toDate().isBefore(DateTime.now())) {
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
      final List votesGiven = uData['helpfulVotesGiven'] ?? [];
      final String today = DateTime.now().toString().substring(0, 10);

      final already = votesGiven.any((v) => v['postId'] == postId);
      if (already) {
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

      final todayCount =
          votesGiven.where((v) => v['date'] == today).length;
      if (todayCount >= 5) return false;

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
