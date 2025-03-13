import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../posts/comment_bottom_sheet.dart';
import 'package:intl/intl.dart';

class HomeContentScreen extends StatefulWidget {
  const HomeContentScreen({Key? key}) : super(key: key);

  @override
  _HomeContentScreenState createState() => _HomeContentScreenState();
}

class _HomeContentScreenState extends State<HomeContentScreen> {
  final Map<String, int> helpfulVotesMap = {}; // ✅ Store Helpful Votes in State

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

  /// ✅ Mark Post as Helpful (Final Version)
  Future<void> _markHelpful(BuildContext context, String postId, String postOwnerId) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be logged in to mark as helpful.')),
      );
      return;
    }

    final String userId = currentUser.uid;
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    final ownerRef = FirebaseFirestore.instance.collection('users').doc(postOwnerId);

    try {
      DocumentSnapshot userSnapshot = await userRef.get();
      if (!userSnapshot.exists) return;

      List<dynamic> userHelpfulVotes = userSnapshot['helpfulVotesGiven'] ?? [];
      bool hasVoted = userHelpfulVotes.any((vote) => vote['postId'] == postId);

      setState(() {
        int currentVotes = helpfulVotesMap[postId] ?? 0;
        if (hasVoted) {
          helpfulVotesMap[postId] = (currentVotes > 0) ? currentVotes - 1 : 0; // ✅ Prevent Negative
        } else {
          helpfulVotesMap[postId] = currentVotes + 1;
        }
      });

      if (hasVoted) {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          transaction.update(userRef, {
            'helpfulVotesGiven': FieldValue.arrayRemove([
              {'postId': postId, 'date': DateTime.now().toString().substring(0, 10)}
            ]),
          });
          transaction.update(postRef, {
            'helpfulVotes': FieldValue.increment(-1),
          });
          transaction.update(ownerRef, {
            'xpPoints': FieldValue.increment(-10),
            'helpfulMarks': FieldValue.increment(-1),
          });
        });
      } else {
        int helpfulVotesToday = userHelpfulVotes.where((vote) {
          return vote['date'] == DateTime.now().toString().substring(0, 10);
        }).length;

        if (helpfulVotesToday >= 5) {
          setState(() {
            helpfulVotesMap[postId] = helpfulVotesMap[postId]! - 1;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You can only mark 5 posts as helpful per day.')),
          );
          return;
        }

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          transaction.update(userRef, {
            'helpfulVotesGiven': FieldValue.arrayUnion([
              {'postId': postId, 'date': DateTime.now().toString().substring(0, 10)}
            ]),
          });
          transaction.update(postRef, {
            'helpfulVotes': FieldValue.increment(1),
          });
          transaction.update(ownerRef, {
            'xpPoints': FieldValue.increment(10),
            'helpfulMarks': FieldValue.increment(1),
          });
        });
      }
    } catch (e) {
      setState(() {
        helpfulVotesMap[postId] = (helpfulVotesMap[postId] ?? 0) - 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking helpful: $e')),
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
            .orderBy('helpfulVotes', descending: true)
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
              final String userName = data['userName'] ?? 'Unknown User';
              final String content = data['content'] ?? 'No content available';
              final List<String> likedBy = (data['likedBy'] != null) ? List<String>.from(data['likedBy']) : [];
              final int likes = data['likes'] ?? 0;
              final int helpfulVotes = helpfulVotesMap[postId] ?? data['helpfulVotes'] ?? 0;
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
                      Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      Text(content, style: const TextStyle(fontSize: 14)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(icon: Icon(Icons.favorite, color: likedBy.contains(currentUserId) ? Colors.red : Colors.grey),
                            onPressed: () => _toggleLike(context, postId, likedBy)),
                          IconButton(icon: const Icon(Icons.thumb_up, color: Colors.blue),
                            onPressed: () => _markHelpful(context, postId, postOwnerId)),
                          Text('$helpfulVotes helpful'),
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
