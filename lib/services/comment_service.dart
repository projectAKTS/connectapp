import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/comment_model.dart';

class CommentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ Add a new comment
  Future<void> addComment(String postId, String content) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final commentRef = _firestore.collection('posts').doc(postId).collection('comments').doc();

    final comment = Comment(
      id: commentRef.id,
      userId: user.uid,
      userName: user.displayName ?? 'Anonymous',
      content: content,
      timestamp: DateTime.now(),
      likedBy: [],
    );

    await commentRef.set(comment.toFirestore());
  }

  // ✅ Fetch comments for a post
  Stream<List<Comment>> getComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Comment.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // ✅ Like or Unlike a comment
  Future<void> toggleLike(String postId, String commentId, String userId, bool isLiked) async {
    final commentRef = _firestore.collection('posts').doc(postId).collection('comments').doc(commentId);

    if (isLiked) {
      await commentRef.update({'likedBy': FieldValue.arrayRemove([userId])});
    } else {
      await commentRef.update({'likedBy': FieldValue.arrayUnion([userId])});
    }
  }
}
