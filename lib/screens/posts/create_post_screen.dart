import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connect_app/services/post_service.dart';
import 'package:connect_app/services/streak_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({Key? key}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final PostService _postService = PostService();
  final StreakService _streakService = StreakService();

  final TextEditingController _contentController = TextEditingController();
  bool _isPosting = false;
  List<String> selectedTags = [];

  final List<String> predefinedTags = ['Career', 'Travel', 'Health', 'Technology', 'Education', 'Finance'];

  Future<void> _savePost() async {
    String content = _contentController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please write some content')));
      return;
    }

    setState(() => _isPosting = true);

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not logged in.')));
        return;
      }

      // ✅ Ensure `selectedTags` is always a List<String>
      List<String> tagsToSave = selectedTags.isNotEmpty ? List<String>.from(selectedTags) : [];

      // ✅ Create the post (XP is awarded inside PostService)
      await _postService.createPost(content, tagsToSave);

      // ✅ Update streaks
      await _streakService.updateStreak(currentUser.uid);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post created successfully!')));

      // ✅ Clear input fields
      _contentController.clear();
      setState(() => selectedTags = []);

      // ✅ Navigate back
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create post. Error: $e')));
    } finally {
      setState(() => _isPosting = false);
    }
  }

  void _addTag(String tag) {
    if (!selectedTags.contains(tag) && tag.isNotEmpty) {
      setState(() => selectedTags.add(tag));
    }
  }

  void _removeTag(String tag) {
    setState(() => selectedTags.remove(tag));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Post')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _contentController,
              decoration: InputDecoration(
                hintText: 'Write a post...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // 🔹 Predefined Tags
            Wrap(
              spacing: 8.0,
              children: predefinedTags.map((tag) {
                return FilterChip(
                  label: Text(tag),
                  selected: selectedTags.contains(tag),
                  onSelected: (selected) => selected ? _addTag(tag) : _removeTag(tag),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: _isPosting ? null : _savePost,
              child: _isPosting ? const CircularProgressIndicator(color: Colors.white) : const Text('Post'),
            ),
          ],
        ),
      ),
    );
  }
}
