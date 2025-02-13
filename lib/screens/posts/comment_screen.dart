import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommentScreen extends StatelessWidget {
  final String postId;

  const CommentScreen({Key? key, required this.postId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comments')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .collection('comments')
            .orderBy('timestamp', descending: true) // ✅ Ensure comments appear in order
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No comments yet. Be the first to comment!'));
          }

          final comments = snapshot.data!.docs;

          return ListView.builder(
            itemCount: comments.length,
            itemBuilder: (context, index) {
              final comment = comments[index];
              final data = comment.data() as Map<String, dynamic>? ?? {};

              final String content = data['text'] ?? 'No content'; // ✅ Change 'content' to 'text'
              final String userId = data['userId'] ?? 'Unknown User';
              final int likes = data['likes'] ?? 0;
              final List<String> likedBy =
                  List<String>.from(data['likedBy'] ?? []);

              return ListTile(
                title: Text(content),
                subtitle: Text('By: $userId'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        likedBy.contains(FirebaseAuth.instance.currentUser!.uid)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: likedBy.contains(FirebaseAuth.instance.currentUser!.uid)
                            ? Colors.red
                            : Colors.grey,
                      ),
                      onPressed: () => _toggleLike(postId, comment.id, likedBy),
                    ),
                    Text('$likes'),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _toggleLike(String postId, String commentId, List<String> likedBy) async {
    final String userId = FirebaseAuth.instance.currentUser!.uid;
    final commentRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);

    if (likedBy.contains(userId)) {
      await commentRef.update({
        'likes': FieldValue.increment(-1),
        'likedBy': FieldValue.arrayRemove([userId]),
      });
    } else {
      await commentRef.update({
        'likes': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([userId]),
      });
    }
  }
}
