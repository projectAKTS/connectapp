import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../posts/comment_bottom_sheet.dart'; // If you still need it
import 'package:connect_app/services/post_service.dart';
import 'package:connect_app/services/gamification_service.dart'; // If needed for direct calls

class HomeContentScreen extends StatefulWidget {
  const HomeContentScreen({Key? key}) : super(key: key);

  @override
  _HomeContentScreenState createState() => _HomeContentScreenState();
}

class _HomeContentScreenState extends State<HomeContentScreen> {
  final Map<String, int> helpfulVotesMap = {}; // Store Helpful Votes in State
  final PostService _postService = PostService();

  /// A safe helper to show a SnackBar if the widget is still mounted
  void _safeShowSnackBar(String message) {
    // 1) Check if widget is still in the widget tree
    if (!mounted) return;
    // 2) Get the messenger if it exists
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    // 3) Show the SnackBar
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Toggle the "like" status of a post
  Future<void> _toggleLike(BuildContext context, String postId, List<String> likedBy) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _safeShowSnackBar('You need to be logged in to like posts.');
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
          // Already liked -> unlike
          transaction.update(postRef, {
            'likes': likes - 1,
            'likedBy': FieldValue.arrayRemove([userId]),
          });
        } else {
          // Not liked -> like
          transaction.update(postRef, {
            'likes': likes + 1,
            'likedBy': FieldValue.arrayUnion([userId]),
          });
        }
      });
    } catch (e) {
      _safeShowSnackBar('Error toggling like: $e');
    }
  }

  /// Mark Post as Helpful
  Future<void> _markHelpful(BuildContext context, String postId, String postOwnerId) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _safeShowSnackBar('You need to be logged in to mark as helpful.');
      return;
    }

    final String userId = currentUser.uid;
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    final ownerRef = FirebaseFirestore.instance.collection('users').doc(postOwnerId);

    try {
      DocumentSnapshot userSnapshot = await userRef.get();
      if (!userSnapshot.exists) {
        _safeShowSnackBar('User document not found.');
        return;
      }

      List<dynamic> userHelpfulVotes = userSnapshot['helpfulVotesGiven'] ?? [];
      bool hasVoted = userHelpfulVotes.any((vote) => vote['postId'] == postId);

      // Update local UI immediately
      setState(() {
        int currentVotes = helpfulVotesMap[postId] ?? 0;
        if (hasVoted) {
          // Removing a vote -> clamp to 0
          helpfulVotesMap[postId] = (currentVotes > 0) ? currentVotes - 1 : 0;
        } else {
          // Adding a vote
          helpfulVotesMap[postId] = currentVotes + 1;
        }
      });

      if (hasVoted) {
        // Remove the helpful vote in Firestore
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          transaction.update(userRef, {
            'helpfulVotesGiven': FieldValue.arrayRemove([
              {
                'postId': postId,
                'date': DateTime.now().toString().substring(0, 10),
              }
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

        // Show feedback if still mounted
        _safeShowSnackBar('Helpful vote removed.');
      } else {
        // Check how many helpful votes user has cast today
        int helpfulVotesToday = userHelpfulVotes.where((vote) {
          return vote['date'] == DateTime.now().toString().substring(0, 10);
        }).length;

        if (helpfulVotesToday >= 5) {
          // Revert local increment
          setState(() {
            int currentLocal = helpfulVotesMap[postId] ?? 1;
            currentLocal = (currentLocal > 0) ? currentLocal - 1 : 0;
            helpfulVotesMap[postId] = currentLocal;
          });

          _safeShowSnackBar('You can only mark 5 posts as helpful per day.');
          return;
        }

        // Mark post helpful in Firestore
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          transaction.update(userRef, {
            'helpfulVotesGiven': FieldValue.arrayUnion([
              {
                'postId': postId,
                'date': DateTime.now().toString().substring(0, 10),
              }
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

        _safeShowSnackBar('Post marked as helpful!');
      }
    } catch (e) {
      // If the transaction failed, revert local increment
      setState(() {
        int currentLocal = helpfulVotesMap[postId] ?? 0;
        // Only decrement if we previously incremented
        if (currentLocal > 0) {
          helpfulVotesMap[postId] = currentLocal - 1;
        }
      });

      _safeShowSnackBar('Error marking helpful: $e');
    }
  }

  /// Boost a Post (6 hours, sets a boostScore)
  Future<void> _boostPost(BuildContext context, String postId) async {
    try {
      // Now we boost for 6 hours
      await _postService.boostPost(postId, 6);
      _safeShowSnackBar('Post boosted successfully for 6 hours!');
    } catch (e) {
      _safeShowSnackBar('Error boosting post: $e');
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
            // Order by isBoosted, then boostScore, then helpfulVotes, then time
            .orderBy('isBoosted', descending: true)
            .orderBy('boostScore', descending: true)
            .orderBy('helpfulVotes', descending: true)
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
              final Map<String, dynamic> data =
                  post.data() as Map<String, dynamic>? ?? {};
              final String postId = post.id;

              final String userName = data['userName'] ?? 'Unknown User';
              final String content = data['content'] ?? 'No content available';
              final List<String> likedBy = (data['likedBy'] != null)
                  ? List<String>.from(data['likedBy'])
                  : [];
              final int likes = data['likes'] ?? 0;

              // If we haven't cached helpfulVotes in local map, fallback to DB value
              final int dbHelpfulVotes = data['helpfulVotes'] ?? 0;
              final int localHelpful = helpfulVotesMap[postId] ?? dbHelpfulVotes;
              // Extra clamp in case we accidentally go below 0
              final int helpfulVotes = (localHelpful < 0) ? 0 : localHelpful;

              final String postOwnerId = data['userID'] ?? 'unknown_user';
              final bool isBoosted = data['isBoosted'] ?? false;

              // Format timestamp
              String formattedTime = 'Just now';
              if (data.containsKey('timestamp') && data['timestamp'] is Timestamp) {
                formattedTime = DateFormat('MMM d, yyyy - hh:mm a')
                    .format((data['timestamp'] as Timestamp).toDate());
              }

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
                      // User name
                      Text(
                        userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Post content
                      Text(content, style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 8),

                      // Row of buttons (like, helpful, boost)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // Like button
                          IconButton(
                            icon: Icon(
                              Icons.favorite,
                              color: likedBy.contains(currentUserId)
                                  ? Colors.red
                                  : Colors.grey,
                            ),
                            onPressed: () =>
                                _toggleLike(context, postId, likedBy),
                          ),

                          // Mark helpful
                          IconButton(
                            icon: const Icon(Icons.thumb_up, color: Colors.blue),
                            onPressed: () =>
                                _markHelpful(context, postId, postOwnerId),
                          ),
                          Text('$helpfulVotes helpful'),
                          const SizedBox(width: 16),

                          // If the user owns this post and it's not boosted, show "Boost" button
                          if (currentUserId == postOwnerId && !isBoosted) ...[
                            IconButton(
                              icon: const Icon(Icons.rocket_launch,
                                  color: Colors.orange),
                              onPressed: () => _boostPost(context, postId),
                            ),
                            const SizedBox(width: 8),
                            const Text('Boost'),
                          ],

                          // If the post is boosted, show a label or different icon
                          if (isBoosted) ...[
                            const Icon(Icons.rocket_launch,
                                color: Colors.orange),
                            const SizedBox(width: 4),
                            const Text(
                              'Boosted!',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),

                      // Timestamp
                      Text(
                        formattedTime,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
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
