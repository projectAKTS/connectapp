import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../posts/comment_bottom_sheet.dart';
import '../posts/create_post_screen.dart';
import 'package:connect_app/services/post_service.dart';
import 'package:connect_app/services/gamification_service.dart';
import 'package:connect_app/utils/time_utils.dart';

class HomeContentScreen extends StatefulWidget {
  const HomeContentScreen({Key? key}) : super(key: key);

  @override
  _HomeContentScreenState createState() => _HomeContentScreenState();
}

class _HomeContentScreenState extends State<HomeContentScreen> {
  final Map<String, int> helpfulVotesMap = {};
  final PostService _postService = PostService();
  final ScrollController _scrollController = ScrollController();

  void _safeShowSnackBar(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _goToCreatePost() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
    if (result == 'posted') {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Future<void> _reportPost(BuildContext context, String postId) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _safeShowSnackBar('You need to be logged in to report posts.');
      return;
    }
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Post'),
        content: const Text('Are you sure you want to report this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('reports').add({
          'postId': postId,
          'reportedBy': currentUser.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
        _safeShowSnackBar('Post reported. Thank you for your feedback.');
      } catch (e) {
        _safeShowSnackBar('Error reporting post: $e');
      }
    }
  }

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
      _safeShowSnackBar('Error toggling like: $e');
    }
  }

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

      setState(() {
        int currentVotes = helpfulVotesMap[postId] ?? 0;
        if (hasVoted) {
          helpfulVotesMap[postId] = (currentVotes > 0) ? currentVotes - 1 : 0;
        } else {
          helpfulVotesMap[postId] = currentVotes + 1;
        }
      });

      if (hasVoted) {
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
        _safeShowSnackBar('Helpful vote removed.');
      } else {
        int helpfulVotesToday = userHelpfulVotes.where((vote) {
          return vote['date'] == DateTime.now().toString().substring(0, 10);
        }).length;

        if (helpfulVotesToday >= 5) {
          setState(() {
            int currentLocal = helpfulVotesMap[postId] ?? 1;
            currentLocal = (currentLocal > 0) ? currentLocal - 1 : 0;
            helpfulVotesMap[postId] = currentLocal;
          });
          _safeShowSnackBar('You can only mark 5 posts as helpful per day.');
          return;
        }

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
      setState(() {
        int currentLocal = helpfulVotesMap[postId] ?? 0;
        if (currentLocal > 0) {
          helpfulVotesMap[postId] = currentLocal - 1;
        }
      });
      _safeShowSnackBar('Error marking helpful: $e');
    }
  }

  Future<void> _boostPost(BuildContext context, String postId) async {
    try {
      await _postService.boostPost(postId, 6);
      _safeShowSnackBar('Post boosted successfully for 6 hours!');
    } catch (e) {
      _safeShowSnackBar('Error boosting post: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final String? currentUserId = currentUser?.uid;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _goToCreatePost,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
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
            controller: _scrollController,
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
              final int dbHelpfulVotes = data['helpfulVotes'] ?? 0;
              final int localHelpful = helpfulVotesMap[postId] ?? dbHelpfulVotes;
              final int helpfulVotes = (localHelpful < 0) ? 0 : localHelpful;
              final String postOwnerId = data['userID'] ?? 'unknown_user';
              final bool isBoosted = data['isBoosted'] ?? false;

              String formattedTime = 'Just now';
              final dt = parseFirestoreTimestamp(data['timestamp']);
              if (dt != null) {
                formattedTime = DateFormat('MMM d, yyyy - hh:mm a').format(dt);
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
                      Text(
                        userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(content, style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
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
                          IconButton(
                            icon: const Icon(Icons.thumb_up, color: Colors.blue),
                            onPressed: () =>
                                _markHelpful(context, postId, postOwnerId),
                          ),
                          Text('$helpfulVotes helpful'),
                          const SizedBox(width: 16),
                          if (currentUserId == postOwnerId && !isBoosted) ...[
                            IconButton(
                              icon: const Icon(Icons.rocket_launch,
                                  color: Colors.orange),
                              onPressed: () => _boostPost(context, postId),
                            ),
                            const SizedBox(width: 8),
                            const Text('Boost'),
                          ],
                          if (isBoosted) ...[
                            const Icon(Icons.rocket_launch, color: Colors.orange),
                            const SizedBox(width: 4),
                            const Text(
                              'Boosted!',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                          IconButton(
                            icon: const Icon(Icons.flag, color: Colors.red),
                            onPressed: () => _reportPost(context, postId),
                          ),
                        ],
                      ),
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
