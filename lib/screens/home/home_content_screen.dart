import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../posts/comment_bottom_sheet.dart';
import 'package:intl/intl.dart'; // ✅ For formatting timestamps

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
        } else {
          transaction.update(postRef, {
            'likes': FieldValue.increment(1),
            'likedBy': FieldValue.arrayUnion([userId]),
          });
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error toggling like: $e')),
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
              final String userName = data['userName'] ?? 'Anonymous'; // ✅ Fixed userName issue
              final String content = data['content'] ?? 'No content available';
              final List<String> likedBy =
                  data['likedBy'] != null ? List<String>.from(data['likedBy']) : [];
              final int likes = data['likes'] ?? 0;
              final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

              // ✅ Format timestamp properly
              String formattedTime = data['timestamp'] != null
                  ? DateFormat('MMM d, yyyy - hh:mm a')
                      .format((data['timestamp'] as Timestamp).toDate())
                  : 'Just now';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            child: Icon(Icons.person), // Default user avatar
                            radius: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            userName, // ✅ Fixed userName display
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(content, style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  likedBy.contains(currentUserId)
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: likedBy.contains(currentUserId) ? Colors.red : Colors.grey,
                                ),
                                onPressed: () => _toggleLike(context, postId, likedBy),
                              ),
                              Text('$likes likes'),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.comment),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                builder: (context) => CommentBottomSheet(postId: postId),
                              );
                            },
                          ),
                        ],
                      ),
                      Text(formattedTime, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
