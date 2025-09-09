import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connect_app/services/gamification_service.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GamificationService _gamificationService = GamificationService();

  /// Creates a new post.
  Future<void> createPost(
    String content,
    List<String> tags,
    String postType, {
    String? imageUrl,
    String? videoUrl,
    String? videoThumbUrl,
    double? mediaAspectRatio,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User must be logged in');

    final docRef = _firestore.collection('posts').doc();
    final String postId = docRef.id;

    final userSnap = await _firestore.collection('users').doc(user.uid).get();
    final String userName = userSnap.data()?['fullName'] ?? 'Unknown User';
    final String userAvatar = userSnap.data()?['profilePicture'] ?? '';

    final Map<String, dynamic> postData = {
      'id':            postId,
      'userID':        user.uid,
      'userName':      userName,
      'userAvatar':    userAvatar,
      'content':       content,
      'postType':      postType,
      'tags':          tags,
      'timestamp':     FieldValue.serverTimestamp(),
      'likes':         0,
      'commentsCount': 0,
      'helpfulVotes':  0,
      'engagementScore': 0,
      'isBoosted':     false,
      'boostExpiresAt': null,
      'boostScore':    0,
      'likedBy':       <String>[],
      'isFeatured':    false,
    };

    // Include media keys only when present
    if (imageUrl != null && imageUrl.isNotEmpty) {
      postData['imageUrl'] = imageUrl;
    }
    if (videoUrl != null && videoUrl.isNotEmpty) {
      postData['videoUrl'] = videoUrl;
    }
    if (videoThumbUrl != null && videoThumbUrl.isNotEmpty) {
      postData['videoThumbUrl'] = videoThumbUrl;
    }
    if (mediaAspectRatio != null && mediaAspectRatio > 0) {
      postData['mediaAspectRatio'] = mediaAspectRatio;
    }

    await docRef.set(postData);

    // Award XP (if you keep this mechanic)
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

      final uData = uSnap.data()!;
      final String today = DateTime.now().toIso8601String().substring(0, 10);
      final String? lastBoost = uData['lastBoostDate'] as String?;
      if (lastBoost == today) {
        throw Exception("You've already boosted today.");
      }

      final int xp = uData['xpPoints'] as int? ?? 0;
      if (xp < 50) throw Exception("Not enough XP to boost.");

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
      final String today = DateTime.now().toIso8601String().substring(0, 10);

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
