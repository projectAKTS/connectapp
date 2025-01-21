import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({Key? key}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  // Define the TextEditingController and the posting state
  final TextEditingController _contentController = TextEditingController();
  bool _isPosting = false;

  // Define the method to save the post
  Future<void> _savePost() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write some content')),
      );
      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      final String postId = const Uuid().v4();
      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in.')),
        );
        return;
      }

      // Fetch the username from Firestore
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      final userName = userDoc.data()?['userName'] ?? 'Anonymous';

      // Save the post in Firestore
      await FirebaseFirestore.instance.collection('posts').doc(postId).set({
        'id': postId,
        'userID': currentUser.uid,
        'userName': userName, // Save username from users collection
        'content': _contentController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,
        'likedBy': [], // Initialize empty list for likes
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post created successfully!')),
      );

      // Clear the text field and navigate back to home
      _contentController.clear();
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      print("Error creating post: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create post. Please try again.')),
      );
    } finally {
      setState(() {
        _isPosting = false;
      });
    }
  }

  // Dispose the TextEditingController when the widget is destroyed
  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Post')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Write something...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            _isPosting
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _savePost,
                    child: const Text('Post'),
                  ),
          ],
        ),
      ),
    );
  }
}
