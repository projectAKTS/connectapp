import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // ✅ For timestamp formatting

class CommentBottomSheet extends StatefulWidget {
  final String postId;

  const CommentBottomSheet({Key? key, required this.postId}) : super(key: key);

  @override
  _CommentBottomSheetState createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<CommentBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isPosting = false;

  /// Fetches comments for the post, ensures latest comments appear first
  Stream<QuerySnapshot> _fetchComments() {
    return _firestore
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .where('timestamp', isNotEqualTo: null) // ✅ Fix for sorting
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Posts a new comment
  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty || _isPosting) return;

    setState(() {
      _isPosting = true;
    });

    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;

      await _firestore.collection('posts').doc(widget.postId).collection('comments').add({
        'text': _commentController.text.trim(),
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(), // ✅ Firestore Timestamp
      });

      _commentController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error posting comment: $e')),
      );
    } finally {
      setState(() {
        _isPosting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // 🔹 Comment Input Field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: 'Write a comment...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: _isPosting
                          ? const CircularProgressIndicator()
                          : const Icon(Icons.send),
                      onPressed: _postComment,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 🔹 Comments List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _fetchComments(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No comments yet.'));
                    }

                    final comments = snapshot.data!.docs;

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        var commentData = comments[index].data() as Map<String, dynamic>;

                        String commentText = commentData['text'] ?? 'No content';
                        String userId = commentData['userId'] ?? 'Unknown';

                        // ✅ Fix Timestamp Handling (prevents crash)
                        var rawTimestamp = commentData['timestamp'];
                        Timestamp? timestamp = rawTimestamp is Timestamp
                            ? rawTimestamp
                            : (rawTimestamp != null
                                ? Timestamp.fromMillisecondsSinceEpoch(int.tryParse(rawTimestamp) ?? 0)
                                : null);

                        // ✅ Format timestamp safely
                        String formattedTime = timestamp != null
                            ? DateFormat('MMM d, yyyy - hh:mm a').format(timestamp.toDate())
                            : 'Just now';

                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(commentText),
                          subtitle: Text('User: $userId\n$formattedTime'),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
