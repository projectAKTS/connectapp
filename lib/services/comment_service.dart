import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/comment_model.dart';

class CommentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a comment
  Future<void> addComment(Comment comment) async {
    await _firestore
        .collection('posts')
        .doc(comment.postId)
        .collection('comments')
        .doc(comment.id)
        .set(comment.toJson());
  }

  // Get comments for a post
  Stream<List<Comment>> getComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Comment.fromJson(doc.data()))
            .toList());
  }

  // Like a comment
  Future<void> likeComment(String postId, String commentId, String userId) async {
    final commentRef = _firestore.collection('posts').doc(postId).collection('comments').doc(commentId);

    final commentSnap = await commentRef.get();
    if (!commentSnap.exists) return;

    List<String> likedBy = List<String>.from(commentSnap['likedBy'] ?? []);
    int likes = commentSnap['likes'] ?? 0;

    if (likedBy.contains(userId)) {
      likedBy.remove(userId);
      likes--;
    } else {
      likedBy.add(userId);
      likes++;
    }

    await commentRef.update({'likes': likes, 'likedBy': likedBy});
  }

  // Delete a comment
  Future<void> deleteComment(String postId, String commentId) async {
    await _firestore.collection('posts').doc(postId).collection('comments').doc(commentId).delete();
  }
}
