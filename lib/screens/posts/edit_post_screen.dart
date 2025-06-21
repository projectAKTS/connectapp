// lib/screens/posts/edit_post_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditPostScreen extends StatefulWidget {
  const EditPostScreen({super.key});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final TextEditingController _contentController = TextEditingController();
  List<String> selectedTags = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args != null) {
      _contentController.text = args['content'] ?? '';
      selectedTags = List<String>.from(args['tags'] ?? []);
    }
  }

  Future<void> _updatePost(String postId) async {
    try {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'content': _contentController.text.trim(),
        'tags': selectedTags,
        'timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post updated successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update post: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String postId = args?['postId'] ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Post')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _contentController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Post Content',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _updatePost(postId),
              child: const Text('Update Post'),
            ),
          ],
        ),
      ),
    );
  }
}
