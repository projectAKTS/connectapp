import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/post_service.dart';
import '../../widgets/zoomable_image.dart';
import 'package:connect_app/utils/time_utils.dart';

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

  void _safeShowSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildPostTypeBadge(String type) {
    final colors = {
      'Advice': Colors.blue,
      'Looking For...': Colors.green,
      'Experience': Colors.deepPurple.shade600,
      'How-To': Colors.amber,
    };
    final icons = {
      'Advice': Icons.question_answer,
      'Looking For...': Icons.search,
      'Experience': Icons.book,
      'How-To': Icons.lightbulb,
    };
    return Chip(
      avatar: Icon(icons[type] ?? Icons.info, size: 16, color: Colors.white),
      label: Text(type, style: const TextStyle(color: Colors.white)),
      backgroundColor: colors[type]!,
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _reportPost(String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (reportedPosts[postId] == true) {
      _safeShowSnackBar("Already reported.");
      return;
    }
    final confirm = await showDialog<bool>(
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
      await FirebaseFirestore.instance.collection('reports').add({
        'postId': postId,
        'reportedBy': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      setState(() => reportedPosts[postId] = true);
      _safeShowSnackBar('Post reported.');
    }
  }

  Future<void> _toggleLike(String postId, List likedBy) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    final isLiked = likedBy.contains(uid);
    await FirebaseFirestore.instance.collection('posts').doc(postId).update({
      'likes': FieldValue.increment(isLiked ? -1 : 1),
      'likedBy': isLiked ? FieldValue.arrayRemove([uid]) : FieldValue.arrayUnion([uid]),
    });
    setState(() => likedPosts[postId] = !isLiked);
  }

  Future<void> _toggleHelpful(String postId, String ownerId) async {
    final wasHelpful = helpfulVotes[postId] == true;
    final result = await _postService.markPostHelpful(postId, ownerId);
    if (result) {
      setState(() => helpfulVotes[postId] = !wasHelpful);
      _safeShowSnackBar(helpfulVotes[postId]! ? 'Marked as helpful!' : 'Helpful vote removed.');
    } else {
      _safeShowSnackBar('⚠ You can mark only 5 posts as helpful per day.');
    }
  }

  Future<void> _boostPost(String postId) async {
    try {
      await _postService.boostPost(postId, 6);
      setState(() => boostedPosts[postId] = true);
      _safeShowSnackBar('🚀 Post boosted for 6 hours.');
    } catch (e) {
      _safeShowSnackBar('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemBuilder: (c, i) {
                  final doc = _cachedPosts[i];
                  final data = doc.data()! as Map<String, dynamic>;
                  final postId = doc.id;
                  final userName = data['userName'] ?? 'User';
                  final content = data['content'] ?? '';
                  final imageUrl = data['imageUrl'] ?? '';
                  // >>> TIMESTAMP FIX
                  final dt = parseFirestoreTimestamp(data['timestamp']);
                  // <<<
                  final ownerId = data['userID'] ?? '';
                  final likedBy = data['likedBy'] as List? ?? [];
                  final tags = data['tags'] as List? ?? [];
                  final structuredTypes = ['Advice','Looking For...','Experience','How-To'];
                  final type = structuredTypes.firstWhere(
                      (t) => tags.contains(t),
                      orElse: () => 'Experience'
                  );
                  final userTags = tags.where((t) => !structuredTypes.contains(t)).toList();
                  final isLiked = likedPosts[postId] ?? likedBy.contains(currentUserId);
                  final isHelp = helpfulVotes[postId] == true;
                  final isRep = reportedPosts[postId] == true;
                  final isMyPost = ownerId == currentUserId;
                  final isBoosted = data['isBoosted'] == true || boostedPosts[postId] == true;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const CircleAvatar(child: Icon(Icons.person)),
                            const SizedBox(width: 10),
                            Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Spacer(),
                            if (isMyPost)
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => Navigator.pushNamed(c, '/edit_post', arguments: {
                                  'postId': postId,
                                  'content': content,
                                  'tags': tags,
                                }),
                              )
                            else
                              IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _reportPost(postId)),
                          ]),
                          const SizedBox(height: 6),
                          _buildPostTypeBadge(type),
                          if (imageUrl.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ZoomableImage(imageUrl: imageUrl),
                          ],
                          const SizedBox(height: 8),
                          Text(content, style: const TextStyle(fontSize: 15)),
                          if (userTags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              children: userTags
                                  .take(3)
                                  .map((t) => Chip(
                                        label: Text('#$t', style: const TextStyle(fontSize: 12)),
                                        visualDensity: VisualDensity.compact,
                                      ))
                                  .toList(),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            dt == null
                                ? 'Just now'
                                : DateFormat('MMM d, yyyy').format(dt),
                            style: const TextStyle(color: Colors.grey)),
                          const Divider(height: 20),
                          Row(children: [
                            IconButton(icon: Icon(Icons.favorite, color: isLiked ? Colors.red : Colors.grey),
                                onPressed: () => _toggleLike(postId, likedBy)),
                            const SizedBox(width: 4),
                            IconButton(icon: Icon(Icons.thumb_up_alt, color: isHelp ? Colors.green : Colors.grey),
                                onPressed: () => _toggleHelpful(postId, ownerId)),
                            const Spacer(),
                            if (isMyPost && !isBoosted)
                              IconButton(icon: const Icon(Icons.rocket_launch, color: Colors.grey),
                                  onPressed: () => _boostPost(postId)),
                            if (isBoosted)
                              Row(children: const [
                                Icon(Icons.rocket_launch, color: Colors.orange),
                                SizedBox(width: 4),
                                Text('Boosted!', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))
                              ]),
                            IconButton(icon: Icon(Icons.flag, color: isRep ? Colors.red : Colors.grey),
                                onPressed: () => _reportPost(postId)),
                          ]),
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
