import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../posts/comment_bottom_sheet.dart';
import 'package:intl/intl.dart';

class HomeContentScreen extends StatelessWidget {
  const HomeContentScreen({Key? key}) : super(key: key);

  Future<void> _toggleLike(BuildContext context, String postId, List<String> likedBy) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be logged in to like posts.')),
      );
      return;
    }

    final String userId = currentUser.uid;
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot postSnapshot = await transaction.get(postRef);
        if (!postSnapshot.exists) return;

        Map<String, dynamic> postData = postSnapshot.data() as Map<String, dynamic>;
        List likedByList = postData['likedBy'] ?? [];
        int likes = postData['likes'] ?? 0;

        if (likedByList.contains(userId)) {
          transaction.update(postRef, {
            'likes': likes - 1,
            'likedBy': FieldValue.arrayRemove([userId]),
          });
        } else {
          transaction.update(postRef, {
            'likes': likes + 1,
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
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final String? currentUserId = currentUser?.uid; 

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

              final Map<String, dynamic> data = post.data() as Map<String, dynamic>? ?? {};
              final String postId = post.id;
              final String userName = data['userName'] ?? 'Unknown User'; // ✅ Fix for Anonymous issue
              final String content = data['content'] ?? 'No content available';
              final List<String> likedBy =
                  (data['likedBy'] != null) ? List<String>.from(data['likedBy']) : [];
              final int likes = data['likes'] ?? 0;
              final String postOwnerId = data['userID'] ?? 'unknown_user';

              String formattedTime = 'Just now';
              if (data.containsKey('timestamp') && data['timestamp'] is Timestamp) {
                formattedTime = DateFormat('MMM d, yyyy - hh:mm a')
                    .format((data['timestamp'] as Timestamp).toDate());
              }

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
                          const CircleAvatar(child: Icon(Icons.person), radius: 20),
                          const SizedBox(width: 10),
                          Text(userName, // ✅ Display correct username
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                                onPressed: () {
                                  if (currentUserId != null) {
                                    _toggleLike(context, postId, likedBy);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please log in to like posts.')),
                                    );
                                  }
                                },
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

                      if (currentUserId != null && postOwnerId != 'unknown_user')
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              if (currentUserId == postOwnerId) {
                                Navigator.pushNamed(
                                  context,
                                  '/boostPost',
                                  arguments: {'postId': postId},
                                );
                              } else {
                                Navigator.pushNamed(
                                  context,
                                  '/profile',
                                  arguments: {'userId': postOwnerId},
                                );
                              }
                            },
                            child: Text(
                              currentUserId == postOwnerId ? 'Boost Post' : 'View Profile',
                              style: TextStyle(color: Colors.blue),
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
