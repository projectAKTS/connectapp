import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/post_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Map<String, bool> reportedPosts = {};
  final Map<String, bool> likedPosts = {};
  final Map<String, bool> helpfulVotes = {};
  final Map<String, bool> boostedPosts = {};
  final PostService _postService = PostService();
  bool _isLoading = true;
  List<DocumentSnapshot> _cachedPosts = [];

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('posts')
        .orderBy('isBoosted', descending: true)
        .orderBy('boostScore', descending: true)
        .orderBy('helpfulVotes', descending: true)
        .orderBy('timestamp', descending: true)
        .get();

    if (!mounted) return;
    setState(() {
      _cachedPosts = snapshot.docs;
      _isLoading = false;
    });
  }

  void _safeShowSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reportPost(String postId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    if (reportedPosts[postId] == true) {
      _safeShowSnackBar("Already reported.");
      return;
    }

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Report Post'),
        content: const Text('Are you sure you want to report this post?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Report')),
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
        setState(() => reportedPosts[postId] = true);
        _safeShowSnackBar('Post reported.');
      } catch (e) {
        _safeShowSnackBar('Failed to report post: $e');
      }
    }
  }

  Future<void> _toggleLike(String postId, List likedBy) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userId = currentUser.uid;
    final isLiked = likedBy.contains(userId);
    await FirebaseFirestore.instance.collection('posts').doc(postId).update({
      'likes': FieldValue.increment(isLiked ? -1 : 1),
      'likedBy': isLiked
          ? FieldValue.arrayRemove([userId])
          : FieldValue.arrayUnion([userId]),
    });
    setState(() => likedPosts[postId] = !isLiked);
  }

  Future<void> _toggleHelpful(String postId, String postOwnerId) async {
    final wasHelpful = helpfulVotes[postId] == true;
    final result = await _postService.markPostHelpful(postId, postOwnerId);

    if (result == true) {
      setState(() => helpfulVotes[postId] = !wasHelpful);
      _safeShowSnackBar(
        helpfulVotes[postId]! ? 'Marked as helpful!' : 'Helpful vote removed.',
      );
    } else {
      _safeShowSnackBar('⚠ You can only mark 5 posts as helpful per day.');
    }
  }

  Future<void> _boostPost(String postId) async {
    try {
      await _postService.boostPost(postId, 6);
      setState(() => boostedPosts[postId] = true);
      _safeShowSnackBar('🚀 Post boosted for 6 hours.');
    } catch (e) {
      _safeShowSnackBar('Failed to boost post: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect App'),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchPosts,
              child: ListView.builder(
                itemCount: _cachedPosts.length,
                padding: const EdgeInsets.only(bottom: 16),
                itemBuilder: (c, i) {
                  final doc = _cachedPosts[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final String postId = doc.id;
                  final String userName = data['userName'] ?? 'User';
                  final String content = data['content'] ?? '';
                  final String imageUrl = data['imageUrl'] ?? '';
                  final Timestamp ts = data['timestamp'];
                  final String ownerId = data['userID'] ?? '';
                  final List likedBy = data['likedBy'] ?? [];
                  final bool isBoosted = data['isBoosted'] == true;

                  final bool isLiked = likedPosts[postId] ?? likedBy.contains(currentUserId);
                  final bool isHelpful = helpfulVotes[postId] == true;
                  final bool isReported = reportedPosts[postId] == true;
                  final bool isMyPost = ownerId == currentUserId;
                  final bool isOwnerBoosted = boostedPosts[postId] == true;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(child: Icon(Icons.person)),
                              const SizedBox(width: 10),
                              Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const Spacer(),
                              if (isMyPost)
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () {
                                    Navigator.pushNamed(c, '/edit_post', arguments: {
                                      'postId': postId,
                                      'content': content,
                                      'tags': data['tags'],
                                    });
                                  },
                                )
                              else
                                IconButton(
                                  icon: const Icon(Icons.more_vert),
                                  onPressed: () => _reportPost(postId),
                                ),
                            ],
                          ),
                          if (imageUrl.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            AspectRatio(aspectRatio: 1, child: Image.network(imageUrl, fit: BoxFit.cover)),
                          ],
                          const SizedBox(height: 8),
                          Text(content),
                          const SizedBox(height: 8),
                          Text(
                            DateFormat('MMM d, yyyy').format(ts.toDate()),
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.favorite, color: isLiked ? Colors.red : Colors.grey),
                                onPressed: () => _toggleLike(postId, likedBy),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: Icon(Icons.thumb_up_alt,
                                    color: isHelpful ? Colors.green : Colors.grey),
                                onPressed: () => _toggleHelpful(postId, ownerId),
                              ),
                              const Spacer(),
                              if (isMyPost && !isBoosted && !isOwnerBoosted) ...[
                                IconButton(
                                  icon: const Icon(Icons.rocket_launch, color: Colors.grey),
                                  onPressed: () => _boostPost(postId),
                                ),
                              ],
                              if ((isBoosted || isOwnerBoosted)) ...[
                                const Icon(Icons.rocket_launch, color: Colors.orange),
                                const SizedBox(width: 4),
                                const Text('Boosted!', style: TextStyle(color: Colors.orange)),
                              ],
                              IconButton(
                                icon: Icon(Icons.flag, color: isReported ? Colors.red : Colors.grey),
                                onPressed: () => _reportPost(postId),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
