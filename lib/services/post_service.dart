import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'gamification_service.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GamificationService _gamificationService = GamificationService();

  /// ✅ Create a new post and award XP
  Future<void> createPost(String content, List<String> tags) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String postId = const Uuid().v4();

    await _firestore.collection('posts').doc(postId).set({
      'id': postId,
      'userID': user.uid,
      'userName': user.displayName ?? 'Anonymous',
      'content': content,
      'tags': tags,
      'timestamp': FieldValue.serverTimestamp(),
      'likes': 0,
      'likedBy': [],
    });

    // ✅ Award XP for posting (+10 XP per post)
    await _gamificationService.awardXP(user.uid, 10);
  }
}
