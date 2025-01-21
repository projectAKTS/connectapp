import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'comment_screen.dart';

class HomeContentScreen extends StatelessWidget {
  const HomeContentScreen({Key? key}) : super(key: key);

  /// Toggles the "like" status of a post.
  Future<void> _toggleLike(BuildContext context, String postId, List<String> likedBy) async {
    final String userId = FirebaseAuth.instance.currentUser!.uid;
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    try {
      if (likedBy.contains(userId)) {
        // If the user already liked the post, remove the like
        await postRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([userId]),
        });
        print("Post unliked by: $userId");
      } else {
        // If the user hasn't liked the post, add a like
        await postRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([userId]),
        });
        print("Post liked by: $userId");
      }
    } catch (e) {
      // Log and handle permission issues or other errors
      print("Error toggling like: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to toggle like. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
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
            return const Center(
              child: Text(
                'No posts yet! Create one to get started.',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final posts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final data = post.data() as Map<String, dynamic>? ?? {};

              // Extract post details safely
              final String postId = data['id'] ?? '';
              final String userName = data['userName'] ?? 'Anonymous'; // Fetch username from posts
              final String content = data['content'] ?? 'No content available';
              final List<String> likedBy =
                  data['likedBy'] != null ? List<String>.from(data['likedBy']) : [];
              final int likes = data['likes'] ?? 0;
              final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Display the user name
                      Row(
                        children: [
                          const CircleAvatar(
                            child: Icon(Icons.person),
                            radius: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            userName, // Display username instead of email
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Display the content of the post
                      Text(
                        content,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 10),

                      // Action buttons for like and comment
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Like button
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  likedBy.contains(currentUserId)
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: likedBy.contains(currentUserId)
                                      ? Colors.red
                                      : Colors.grey,
                                ),
                                onPressed: () {
                                  _toggleLike(context, post.id, likedBy);
                                },
                              ),
                              Text('$likes'),
                            ],
                          ),
                          // Comment button
                          IconButton(
                            icon: const Icon(Icons.comment),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CommentScreen(postId: post.id),
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      // Timestamp of the post
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          (data['timestamp'] != null
                                  ? (data['timestamp'] as Timestamp).toDate()
                                  : DateTime.now())
                              .toLocal()
                              .toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
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
