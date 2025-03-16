import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:connect_app/services/gamification_service.dart'; // ✅ Import XP system

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GamificationService _gamificationService = GamificationService(); // ✅ Add Gamification

  /// ✅ Create a new post and award XP
  Future<void> createPost(String content, List<String> tags) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String postId = const Uuid().v4();
    String userId = user.uid;

    // ✅ Fetch user details from Firestore
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(userId).get();
    String userName =
        userDoc.exists ? (userDoc['fullName'] ?? 'Unknown User') : 'Unknown User';

    // ✅ Store Post in Firestore (add boostScore: 0)
    await _firestore.collection('posts').doc(postId).set({
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
      'boostScore': 0, // NEW: default 0
      'likedBy': [],
    });

    // ✅ Award XP for posting
    await _gamificationService.awardXP(userId, 10, isPost: true);
    print('🎉 XP awarded for post!');
  }

  /// 🚀 **Boost a Post (Costs 50 XP, 6-hour duration, boostScore=100, 1 boost per day)**
  Future<void> boostPost(String postId, int boostDurationHours) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String userId = user.uid;
    DocumentReference userRef = _firestore.collection('users').doc(userId);
    DocumentReference postRef = _firestore.collection('posts').doc(postId);

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot userSnapshot = await transaction.get(userRef);
      DocumentSnapshot postSnapshot = await transaction.get(postRef);

      if (!userSnapshot.exists || !postSnapshot.exists) return;

      Map<String, dynamic> userData =
          userSnapshot.data() as Map<String, dynamic>;

      // Check daily boost limit: use YYYY-MM-DD format
      String currentDate = DateTime.now().toString().substring(0, 10);
      String? lastBoostDate = userData['lastBoostDate'];
      if (lastBoostDate != null && lastBoostDate == currentDate) {
        throw Exception("You have already boosted a post today. Please try again tomorrow.");
      }

      int currentXP = userData['xpPoints'] ?? 0;
      if (currentXP < 50) {
        throw Exception("Not enough XP to boost the post!");
      }

      final boostExpiration = DateTime.now().add(Duration(hours: boostDurationHours));

      // Add a boostScore so it sorts higher
      transaction.update(postRef, {
        'isBoosted': true,
        'boostExpiresAt': boostExpiration,
        'boostScore': 100, // Arbitrary number to rank boosted posts
      });

      // Deduct XP and update last boost date
      transaction.update(userRef, {
        'xpPoints': FieldValue.increment(-50),
        'lastBoostDate': currentDate,
      });

      print('🚀 Post boosted successfully!');
    });
  }

  /// ⏳ **Automatically Remove Expired Boosts**
  Future<void> removeExpiredBoosts() async {
    final QuerySnapshot snapshot = await _firestore
        .collection('posts')
        .where('isBoosted', isEqualTo: true)
        .get();

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['boostExpiresAt'] != null) {
        DateTime boostEndTime = (data['boostExpiresAt'] as Timestamp).toDate();
        if (boostEndTime.isBefore(DateTime.now())) {
          await doc.reference.update({
            'isBoosted': false,
            'boostExpiresAt': null,
            'boostScore': 0, // Reset boost score
          });
        }
      }
    }
  }

  /// ✅ **Mark Post as Helpful (Max 5 per day)**
  Future<void> markPostHelpful(String postId, String postOwnerId) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String userId = user.uid;
    final userRef = _firestore.collection('users').doc(userId);
    final postRef = _firestore.collection('posts').doc(postId);
    final ownerRef = _firestore.collection('users').doc(postOwnerId);

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot userSnapshot = await transaction.get(userRef);
      DocumentSnapshot postSnapshot = await transaction.get(postRef);

      if (!userSnapshot.exists || !postSnapshot.exists) return;

      Map<String, dynamic> userData =
          userSnapshot.data() as Map<String, dynamic>;
      Map<String, dynamic> postData =
          postSnapshot.data() as Map<String, dynamic>;

      List userHelpfulVotes = userData['helpfulVotesGiven'] ?? [];
      bool hasVoted = userHelpfulVotes.any((vote) => vote['postId'] == postId);

      if (hasVoted) {
        // Remove vote
        transaction.update(userRef, {
          'helpfulVotesGiven': FieldValue.arrayRemove([
            {'postId': postId, 'date': DateTime.now().toString().substring(0, 10)}
          ]),
        });

        transaction.update(postRef, {
          'helpfulVotes': (postData['helpfulVotes'] ?? 0) - 1,
        });

        transaction.update(ownerRef, {
          'xpPoints': FieldValue.increment(-10),
          'helpfulMarks': FieldValue.increment(-1),
        });

        print('❌ Helpful vote removed.');
      } else {
        int helpfulVotesToday = userHelpfulVotes.where((vote) {
          return vote['date'] == DateTime.now().toString().substring(0, 10);
        }).length;

        if (helpfulVotesToday >= 5) {
          print('⚠ You can only mark 5 posts as helpful per day.');
          return;
        }

        transaction.update(userRef, {
          'helpfulVotesGiven': FieldValue.arrayUnion([
            {'postId': postId, 'date': DateTime.now().toString().substring(0, 10)}
          ]),
        });

        transaction.update(postRef, {
          'helpfulVotes': (postData['helpfulVotes'] ?? 0) + 1,
        });

        transaction.update(ownerRef, {
          'xpPoints': FieldValue.increment(10),
          'helpfulMarks': FieldValue.increment(1),
        });

        print('✅ Post marked as helpful!');
      }
    });
  }
}
