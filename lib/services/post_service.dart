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
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
    String userName = userDoc.exists ? (userDoc['fullName'] ?? 'Unknown User') : 'Unknown User';

    // ✅ Store Post in Firestore
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
      'likedBy': [],
    });

    // ✅ Award XP for posting
    await _gamificationService.awardXP(userId, 10, isPost: true);
    print('🎉 XP awarded for post!');
  }

  /// 🚀 Boost a post (Allows users to promote their post)
  Future<void> boostPost(String postId, int boostDurationHours) async {
    final boostExpiration = DateTime.now().add(Duration(hours: boostDurationHours));

    await _firestore.collection('posts').doc(postId).update({
      'isBoosted': true,
      'boostExpiresAt': boostExpiration,
    });
  }

  /// ⏳ Automatically remove expired boosts
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
          });
        }
      }
    }
  }

  /// ✅ Mark Post as Helpful (Max 5 per day)
  Future<void> markPostHelpful(String postId, String postOwnerId) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String userId = user.uid;
    final userRef = _firestore.collection('users').doc(userId);
    final postRef = _firestore.collection('posts').doc(postId);

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot userSnapshot = await transaction.get(userRef);
      DocumentSnapshot postSnapshot = await transaction.get(postRef);

      if (!userSnapshot.exists || !postSnapshot.exists) return;

      Map<String, dynamic> userData = userSnapshot.data() as Map<String, dynamic>;
      Map<String, dynamic> postData = postSnapshot.data() as Map<String, dynamic>;

      List userHelpfulVotes = userData['helpfulVotesGiven'] ?? [];
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

      _gamificationService.awardXP(postOwnerId, 10, isHelpful: true);
    });

    print('✅ Marked post as helpful!');
  }
}
