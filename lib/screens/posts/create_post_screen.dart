// lib/screens/posts/create_post_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:connect_app/services/post_service.dart';
import 'package:connect_app/services/streak_service.dart';
import 'package:connect_app/theme/tokens.dart';

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
  List<String> selectedTags = [];
  String selectedType = 'Experience';

  File? _imageFile;
  File? _videoFile;
  String? _videoThumbPath;
  double? _mediaAspect; // image ~16/9, video ~1.0

  final picker = ImagePicker();

  final Map<String, String> typePrompt = const {
    'Experience': 'What happened? What did you learn?',
    'Advice': 'What help do you need? Be specific.',
    'How-To': 'Break it down step-by-step.',
    'Looking For...': 'Describe your situation and the kind of people you’d like advice or insight from.',
  };

  final Map<String, String> typeDescriptions = const {
    'Experience': 'Share what you’ve been through to help others',
    'Advice': 'Ask for tips or feedback on a challenge',
    'How-To': 'Break down how to solve something step-by-step',
    'Looking For...': 'Find people who’ve been through a specific experience',
  };

  bool get _canPost => !_isPosting && _contentController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  // —— Media pickers ————————————————————————————————————————
  Future<void> _pickImage() async {
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
        _videoFile = null;
        _videoThumbPath = null;
        _mediaAspect = 16 / 9; // horizontal look
      });
    }
  }

  Future<void> _pickVideo() async {
    final picked = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );
    if (picked == null) return;

    final video = File(picked.path);

    // Generate a local JPEG thumbnail (square, ~480px)
    String? thumbPath;
    try {
      final tempDir = await getTemporaryDirectory();
      final out = await VideoThumbnail.thumbnailFile(
        video: video.path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 480,
        quality: 75,
        timeMs: 0, // first frame
      );
      if (out != null) thumbPath = out;
    } catch (_) {
      // if it fails, we’ll still post without a thumb
    }

    setState(() {
      _videoFile = video;
      _imageFile = null;
      _mediaAspect = 1.0;      // square look in feed
      _videoThumbPath = thumbPath; // may be null if generation failed
    });
  }

  // —— Save post ————————————————————————————————————————————————
  Future<void> _savePost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write your post')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to post')),
      );
      return;
    }

    setState(() => _isPosting = true);

    String? imageUrl;
    String? videoUrl;
    String? videoThumbUrl;

    try {
      // Upload image (if any)
      if (_imageFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('post_images')
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_imageFile!);
        imageUrl = await ref.getDownloadURL();
      }

      // Upload video (if any)
      if (_videoFile != null) {
        final vRef = FirebaseStorage.instance
            .ref()
            .child('post_videos')
            .child('${DateTime.now().millisecondsSinceEpoch}.mp4');
        await vRef.putFile(_videoFile!);
        videoUrl = await vRef.getDownloadURL();

        // Upload thumb if we generated one
        if (_videoThumbPath != null) {
          final tRef = FirebaseStorage.instance
              .ref()
              .child('post_video_thumbs')
              .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
          await tRef.putFile(File(_videoThumbPath!));
          videoThumbUrl = await tRef.getDownloadURL();
        }
      }

      await _postService.createPost(
        content,
        selectedTags,
        selectedType,
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        videoThumbUrl: videoThumbUrl,
        mediaAspectRatio: _mediaAspect,
      );

      await _streakService.updateStreak(currentUser.uid);

      // Reset form
      _contentController.clear();
      _tagController.clear();
      setState(() {
        selectedTags.clear();
        _imageFile = null;
        _videoFile = null;
        _videoThumbPath = null;
        _mediaAspect = null;
        selectedType = 'Experience';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Post created!')),
      );

      if (Navigator.canPop(context)) {
        Navigator.pop(context, 'posted');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post: $e')),
      );
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  // —— UI helpers ————————————————————————————————————————————————
  InputDecoration _pillInput({required String hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.button,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _mediaPreview() {
    if (_imageFile != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(_imageFile!, height: 220, fit: BoxFit.cover),
          ),
          Positioned(
            top: 8, right: 8,
            child: _RemoveChip(onTap: () {
              setState(() {
                _imageFile = null;
                _mediaAspect = null;
              });
            }),
          ),
        ],
      );
    }

    if (_videoFile != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _videoThumbPath != null
                ? Image.file(File(_videoThumbPath!), height: 220, fit: BoxFit.cover)
                : Container(
                    height: 220,
                    color: Colors.black12,
                    child: const Center(child: Icon(Icons.videocam, size: 64, color: Colors.black54)),
                  ),
          ),
          Positioned(
            top: 8, right: 8,
            child: _RemoveChip(onTap: () {
              setState(() {
                _videoFile = null;
                _videoThumbPath = null;
                _mediaAspect = null;
              });
            }),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.canvas,
          title: const Text('Create a Post'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose Post Type:',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: typePrompt.keys.map((type) {
                  final isSel = selectedType == type;
                  return ChoiceChip(
                    label: Text(type),
                    selected: isSel,
                    onSelected: (_) => setState(() => selectedType = type),
                    selectedColor: AppColors.button,
                    backgroundColor: AppColors.card,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSel ? AppColors.text : AppColors.text.withOpacity(0.9),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              Text(typeDescriptions[selectedType]!, style: Theme.of(context).textTheme.bodyMedium),

              const SizedBox(height: 20),
              TextField(
                controller: _contentController,
                maxLines: 8,
                textInputAction: TextInputAction.newline,
                decoration: _pillInput(hint: typePrompt[selectedType]!),
              ),

              const SizedBox(height: 20),
              TextField(
                controller: _tagController,
                decoration: _pillInput(hint: 'Type a tag and press enter (e.g. #career)'),
                onSubmitted: (value) {
                  final raw = value.trim();
                  if (raw.isNotEmpty) {
                    final tag = raw.startsWith('#') ? raw : '#$raw';
                    if (!selectedTags.contains(tag)) {
                      setState(() => selectedTags.add(tag));
                    }
                  }
                  _tagController.clear();
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedTags.map((tag) {
                  return Chip(
                    label: Text(tag, style: const TextStyle(fontWeight: FontWeight.w600)),
                    backgroundColor: AppColors.button,
                    shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
                    deleteIcon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                    onDeleted: () => setState(() => selectedTags.remove(tag)),
                  );
                }).toList(),
              ),

              const Divider(height: 32, color: AppColors.border),

              _mediaPreview(),
              if (_imageFile != null || _videoFile != null) const SizedBox(height: 12),

              Row(
                children: [
                  TextButton.icon(
                    onPressed: _isPosting ? null : _pickImage,
                    icon: const Icon(Icons.image),
                    label: const Text('Add Image'),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.button,
                      foregroundColor: AppColors.text,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: _isPosting ? null : _pickVideo,
                    icon: const Icon(Icons.videocam),
                    label: const Text('Add Video'),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.button,
                      foregroundColor: AppColors.text,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: _isPosting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(_isPosting ? 'Posting...' : 'Post'),
                onPressed: _canPost ? _savePost : null,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoveChip extends StatelessWidget {
  final VoidCallback onTap;
  const _RemoveChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.close, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
