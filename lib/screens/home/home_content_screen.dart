import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../posts/post_screen.dart';

class HomeContentScreen extends StatelessWidget {
  const HomeContentScreen({Key? key}) : super(key: key);

  /// Toggles the "like" status of a post.
  Future<void> _toggleLike(BuildContext context, String postId, List<String> likedBy) async {
    final String userId = FirebaseAuth.instance.currentUser!.uid;
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot postSnapshot = await transaction.get(postRef);

        if (!postSnapshot.exists) return;

        Map<String, dynamic> postData = postSnapshot.data() as Map<String, dynamic>;
        List likedByList = postData['likedBy'] ?? [];

        if (likedByList.contains(userId)) {
          transaction.update(postRef, {
            'likes': FieldValue.increment(-1),
            'likedBy': FieldValue.arrayRemove([userId]),
          });
          print('Post unliked: $postId by $userId');
        } else {
          transaction.update(postRef, {
            'likes': FieldValue.increment(1),
            'likedBy': FieldValue.arrayUnion([userId]),
          });
          print('Post liked: $postId by $userId');
        }
      });
    } catch (e) {
      print('Error toggling like: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to toggle like: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No posts yet! Create one to get started.'));
          }

          final posts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final data = post.data() as Map<String, dynamic>? ?? {};

              final String postId = post.id;
              final String userName = data['userName'] ?? 'Anonymous';
              final String content = data['content'] ?? 'No content available';
              final List<String> likedBy =
                  data['likedBy'] != null ? List<String>.from(data['likedBy']) : [];
              final int likes = data['likes'] ?? 0;
              final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                child: ListTile(
                  title: Text(content),
                  subtitle: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          likedBy.contains(currentUserId) ? Icons.favorite : Icons.favorite_border,
                          color: likedBy.contains(currentUserId) ? Colors.red : Colors.grey,
                        ),
                        onPressed: () => _toggleLike(context, postId, likedBy),
                      ),
                      Text('$likes likes'),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
