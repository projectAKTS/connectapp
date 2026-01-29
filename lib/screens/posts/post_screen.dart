import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connect_app/utils/time_utils.dart';
import 'package:intl/intl.dart';

class PostScreen extends StatefulWidget {
  final Map<String, dynamic> postData;

  const PostScreen({Key? key, required this.postData}) : super(key: key);

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  bool isLiked = false;
  int likesCount = 0;
  final TextEditingController _commentController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    likesCount = widget.postData['likes'] ?? 0;
    isLiked = (widget.postData['likedBy'] ?? []).contains(currentUser?.uid);
  }

  Future<void> _toggleLike() async {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postData['id']);
    final userId = currentUser?.uid;

    if (userId == null) return;

    setState(() {
      isLiked = !isLiked;
      likesCount += isLiked ? 1 : -1;
    });

    await postRef.update({
      'likes': likesCount,
      'likedBy': isLiked
          ? FieldValue.arrayUnion([userId])
          : FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postData['id']);
    await postRef.collection('comments').add({
      'content': _commentController.text.trim(),
      'userName': currentUser?.email ?? 'Anonymous',
      'timestamp': FieldValue.serverTimestamp(),
    });

    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.postData;
    List<String> tags = (post['tags'] as List<dynamic>?)?.cast<String>() ?? [];
    final List<String> imageUrls = (() {
      final v = post['imageUrls'];
      if (v is List) {
        return v
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      final single = (post['imageUrl'] ?? '').toString().trim();
      if (single.isNotEmpty) return [single];
      return <String>[];
    })();
    final bool isProTip = post['isProTip'] ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(post['userName'] ?? 'Post Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isProTip)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('💡 Pro Tip', style: TextStyle(color: Colors.orange)),
              ),
            const SizedBox(height: 8),

            Text(
              post['content'] ?? 'No content available',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            if (imageUrls.isNotEmpty)
              _PostMediaCarousel(urls: imageUrls),

            if (tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8.0,
                children: tags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    backgroundColor: Colors.blue.shade100,
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 16),

            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.favorite, color: isLiked ? Colors.red : Colors.grey),
                  onPressed: _toggleLike,
                ),
                Text('$likesCount likes', style: const TextStyle(fontSize: 16)),
              ],
            ),

            const Divider(height: 32),

            // COMMENTS
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(post['id'])
                    .collection('comments')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final comments = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final commentData = comments[index].data() as Map<String, dynamic>;

                      // Robust timestamp parsing
                      final dt = parseFirestoreTimestamp(commentData['timestamp']);
                      final formatted = dt != null
                          ? DateFormat('MMM d, yyyy – hh:mm a').format(dt)
                          : '';

                      return ListTile(
                        leading: const Icon(Icons.comment, color: Colors.grey),
                        title: Text(commentData['userName'] ?? 'Unknown User'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(commentData['content'] ?? ''),
                            if (formatted.isNotEmpty)
                              Text(
                                formatted,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const Divider(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(hintText: 'Add a comment...'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _addComment,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PostMediaCarousel extends StatefulWidget {
  final List<String> urls;
  const _PostMediaCarousel({required this.urls});

  @override
  State<_PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends State<_PostMediaCarousel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.urls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          widget.urls.first,
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          SizedBox(
            height: 240,
            width: double.infinity,
            child: PageView.builder(
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => Image.network(
                widget.urls[i],
                fit: BoxFit.cover,
                loadingBuilder: (c, w, p) =>
                    p == null ? w : Container(color: Colors.black12),
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.black12,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image, color: Colors.black45),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.urls.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 14 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(active ? 0.55 : 0.25),
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
