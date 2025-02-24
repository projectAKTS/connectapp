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
  final TextEditingController _contentController = TextEditingController();
  bool _isPosting = false;
  List<String> selectedTags = [];

  final List<String> predefinedTags = ['Career', 'Travel', 'Health', 'Technology', 'Education', 'Finance'];

  Future<void> _savePost() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please write some content')));
      return;
    }

    setState(() => _isPosting = true);

    try {
      final String postId = const Uuid().v4();
      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not logged in.')));
        return;
      }

      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String userName = userData['fullName'] ?? 'Anonymous';

      await FirebaseFirestore.instance.collection('posts').doc(postId).set({
        'id': postId,
        'userID': currentUser.uid,
        'userName': userName,
        'content': _contentController.text.trim(),
        'tags': selectedTags,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,
        'likedBy': [],
      });

      // ✅ Update User XP and Post Count
      int newPostCount = (userData['postCount'] ?? 0) + 1;
      int newXP = (userData['xpPoints'] ?? 0) + 10;

      List<String> updatedBadges = List<String>.from(userData['badges'] ?? []);
      if (newPostCount == 2 && !updatedBadges.contains('First Contributor')) updatedBadges.add('First Contributor');
      if (newPostCount == 5 && !updatedBadges.contains('Profile Highlight')) updatedBadges.add('Profile Highlight');
      if (newPostCount == 15 && !updatedBadges.contains('Priority Post Boost')) updatedBadges.add('Priority Post Boost');

      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
        'postCount': newPostCount,
        'xpPoints': newXP,
        'badges': updatedBadges,
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post created successfully!')));
      _contentController.clear();
      selectedTags.clear();

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
