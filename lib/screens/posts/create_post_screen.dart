import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
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
  final TextEditingController _tagController = TextEditingController();

  bool _isPosting = false;
  bool _isProTip = false;
  File? _imageFile;
  List<String> selectedTags = [];
  String selectedType = 'Experience';

  final Map<String, String> typePrompt = {
    'Experience': 'What happened? What did you learn?',
    'Advice': 'What help do you need? Be specific.',
    'How-To': 'Break it down step-by-step.',
    'Looking For...': 'Describe your situation and the kind of people you’d like advice or insight from.',
  };

  final Map<String, String> typeDescriptions = {
    'Experience': 'Share what you’ve been through to help others',
    'Advice': 'Ask for tips or feedback on a challenge',
    'How-To': 'Break down how to solve something step-by-step',
    'Looking For...': 'Find people who’ve been through a specific experience',
  };

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _savePost() async {
    final content = _contentController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write your post')),
      );
      return;
    }

    setState(() => _isPosting = true);

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      String? imageUrl;
      if (_imageFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('post_images')
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_imageFile!);
        imageUrl = await ref.getDownloadURL();
      }

      await _postService.createPost(
        content,
        [...selectedTags, selectedType],
        imageUrl: imageUrl,
        isProTip: _isProTip,
      );

      await _streakService.updateStreak(currentUser.uid);

      _contentController.clear();
      _tagController.clear();
      setState(() {
        _imageFile = null;
        selectedTags.clear();
        _isProTip = false;
        selectedType = 'Experience';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Post created!')),
      );

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post: $e')));
    } finally {
      setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Create a Post')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose Post Type:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['Experience', 'Advice', 'How-To', 'Looking For...'].map((type) {
                  return ChoiceChip(
                    label: Text(type),
                    selected: selectedType == type,
                    onSelected: (_) => setState(() => selectedType = type),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                typeDescriptions[selectedType] ?? '',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),

              const SizedBox(height: 20),
              const Text('Your Post', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _contentController,
                maxLines: 6,
                minLines: 5,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[100],
                  hintText: typePrompt[selectedType],
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Text('Tags', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _tagController,
                decoration: InputDecoration(
                  hintText: 'Type a tag and press enter (e.g. #career)',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onSubmitted: (value) {
                  final tag = value.trim();
                  if (tag.isNotEmpty && !selectedTags.contains(tag)) {
                    setState(() {
                      selectedTags.add(tag.startsWith('#') ? tag : '#$tag');
                    });
                    _tagController.clear();
                  }
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: selectedTags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    backgroundColor: Colors.blue.shade50,
                    deleteIcon: const Icon(Icons.close),
                    onDeleted: () {
                      setState(() => selectedTags.remove(tag));
                    },
                  );
                }).toList(),
              ),

              const Divider(height: 32),

              Row(
                children: [
                  Checkbox(value: _isProTip, onChanged: (val) => setState(() => _isProTip = val ?? false)),
                  const Text('Mark as Pro Tip'),
                ],
              ),

              if (_imageFile != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(_imageFile!, height: 200, fit: BoxFit.cover),
                ),
              ],
              TextButton.icon(
                icon: const Icon(Icons.image),
                label: const Text("Add Image"),
                onPressed: _pickImage,
              ),

              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: _isPosting ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.send),
                label: Text(_isPosting ? 'Posting...' : 'Post'),
                onPressed: _isPosting ? null : _savePost,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
