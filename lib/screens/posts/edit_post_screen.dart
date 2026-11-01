// lib/screens/posts/edit_post_screen.dart
import 'package:connect_app/l10n/l10n.dart';
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
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

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
        SnackBar(content: Text(context.l10n.editPostUpdated)),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.editPostFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String postId = args?['postId'] ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.editPostTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _contentController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: context.l10n.editPostContent,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _updatePost(postId),
              child: Text(context.l10n.editPostUpdate),
            ),
          ],
        ),
      ),
    );
  }
}
