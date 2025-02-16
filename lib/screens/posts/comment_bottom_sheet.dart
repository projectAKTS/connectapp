import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CommentBottomSheet extends StatefulWidget {
  final String postId;

  const CommentBottomSheet({Key? key, required this.postId}) : super(key: key);

  @override
  _CommentBottomSheetState createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<CommentBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  bool _isPosting = false;

  /// Fetches comments for the post
  Stream<QuerySnapshot> _fetchComments() {
    return _firestore
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Posts a new comment and auto-scrolls to the top
  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty || _isPosting) return;

    setState(() {
      _isPosting = true;
    });

    try {
      final String userId = FirebaseAuth.instance.currentUser!.uid;

      // ✅ Fetch user name from Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      String userName = userDoc.exists
          ? (userDoc['fullName'] ?? 'Anonymous')
          : 'Anonymous';

      await _firestore.collection('posts').doc(widget.postId).collection('comments').add({
        'text': _commentController.text.trim(),
        'userId': userId,
        'userName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,
        'likedBy': [],
      });

      _commentController.clear();

      // ✅ Auto-scroll to the top after posting a comment
      Future.delayed(Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        }
      });

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
    return Container( // ✅ Removed DraggableScrollableSheet, replaced with Container
      padding: const EdgeInsets.all(12), 
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // ✅ Auto-size based on content
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
          SizedBox(
            height: 300, // ✅ Adjusted height to fit content
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
                  controller: _scrollController,
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    var commentData = comments[index].data() as Map<String, dynamic>;

                    String commentText = commentData['text'] ?? 'No content';
                    String userName = commentData['userName'] ?? 'Anonymous';

                    // ✅ Fix Timestamp Handling
                    Timestamp? timestamp = commentData['timestamp'];
                    String formattedTime = timestamp != null
                        ? DateFormat('MMM d, yyyy - hh:mm a').format(timestamp.toDate())
                        : 'Just now';

                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(commentText),
                      subtitle: Text('$userName\n$formattedTime'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
