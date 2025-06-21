import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:connect_app/services/gamification_service.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GamificationService _gamificationService = GamificationService();

  Future<void> createPost(
    String content,
    List<String> tags, {
    String? imageUrl,
    bool isProTip = false,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final String postId = const Uuid().v4();
    final String userId = user.uid;

    final DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(userId).get();
    final String userName =
        userDoc.exists ? (userDoc['fullName'] ?? 'Unknown User') : 'Unknown User';

    final Map<String, dynamic> postData = {
      'id': postId,
      'userID': userId,
      'userName': userName,
      'content': content,
      'tags': tags,
      'timestamp': FieldValue.serverTimestamp(),
      'likes': 0,
      'commentsCount': 0,
      'helpfulVotes': 0,
      'engagementScore': 0,
      'isBoosted': false,
      'boostExpiresAt': null,
      'boostScore': 0,
      'likedBy': [],
      'isProTip': isProTip,
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
    };

    await _firestore.collection('posts').doc(postId).set(postData);
    await _gamificationService.awardXP(userId, 10, isPost: true);
    print('🎉 XP awarded for post!');
  }

  Future<void> boostPost(String postId, int boostDurationHours) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final String userId = user.uid;
    final userRef = _firestore.collection('users').doc(userId);
    final postRef = _firestore.collection('posts').doc(postId);

    await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final postSnapshot = await transaction.get(postRef);

      if (!userSnapshot.exists || !postSnapshot.exists) return;

      final userData = userSnapshot.data() as Map<String, dynamic>;
      final String currentDate = DateTime.now().toString().substring(0, 10);
      final String? lastBoostDate = userData['lastBoostDate'];

      if (lastBoostDate != null && lastBoostDate == currentDate) {
        throw Exception("You have already boosted a post today.");
      }

      final int currentXP = userData['xpPoints'] ?? 0;
      if (currentXP < 50) {
        throw Exception("Not enough XP to boost the post!");
      }

      final boostExpiration = DateTime.now().add(Duration(hours: boostDurationHours));

      transaction.update(postRef, {
        'isBoosted': true,
        'boostExpiresAt': boostExpiration,
        'boostScore': 100,
      });

      transaction.update(userRef, {
        'xpPoints': FieldValue.increment(-50),
        'lastBoostDate': currentDate,
      });

      print('🚀 Post boosted successfully!');
    });
  }

  Future<void> removeExpiredBoosts() async {
    final QuerySnapshot snapshot = await _firestore
        .collection('posts')
        .where('isBoosted', isEqualTo: true)
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['boostExpiresAt'] != null) {
        final DateTime boostEndTime = (data['boostExpiresAt'] as Timestamp).toDate();
        if (boostEndTime.isBefore(DateTime.now())) {
          await doc.reference.update({
            'isBoosted': false,
            'boostExpiresAt': null,
            'boostScore': 0,
          });
        }
      }
    }
  }

  /// ✅ Now returns `true` if vote added or removed, `false` if limit reached
  Future<bool> markPostHelpful(String postId, String postOwnerId) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final String userId = user.uid;
    final userRef = _firestore.collection('users').doc(userId);
    final postRef = _firestore.collection('posts').doc(postId);
    final ownerRef = _firestore.collection('users').doc(postOwnerId);

    return await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final postSnapshot = await transaction.get(postRef);

      if (!userSnapshot.exists || !postSnapshot.exists) return false;

      final userData = userSnapshot.data() as Map<String, dynamic>;
      final postData = postSnapshot.data() as Map<String, dynamic>;

      final List userHelpfulVotes = userData['helpfulVotesGiven'] ?? [];
      final bool hasVoted = userHelpfulVotes.any((vote) => vote['postId'] == postId);
      final String today = DateTime.now().toString().substring(0, 10);

      if (hasVoted) {
        transaction.update(userRef, {
          'helpfulVotesGiven': FieldValue.arrayRemove([
            {'postId': postId, 'date': today}
          ]),
        });
        transaction.update(postRef, {
          'helpfulVotes': FieldValue.increment(-1),
        });
        transaction.update(ownerRef, {
          'xpPoints': FieldValue.increment(-10),
          'helpfulMarks': FieldValue.increment(-1),
        });
        print('❌ Helpful vote removed.');
        return true;
      } else {
        final int helpfulVotesToday = userHelpfulVotes
            .where((vote) => vote['date'] == today)
            .length;

        if (helpfulVotesToday >= 5) {
          print('⚠ You can only mark 5 posts as helpful per day.');
          return false;
        }

        transaction.update(userRef, {
          'helpfulVotesGiven': FieldValue.arrayUnion([
            {'postId': postId, 'date': today}
          ]),
        });
        transaction.update(postRef, {
          'helpfulVotes': FieldValue.increment(1),
        });
        transaction.update(ownerRef, {
          'xpPoints': FieldValue.increment(10),
          'helpfulMarks': FieldValue.increment(1),
        });
        print('✅ Post marked as helpful!');
        return true;
      }
    });
  }
}
