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

  // For template fields
  final TextEditingController _field1 = TextEditingController();
  final TextEditingController _field2 = TextEditingController();
  final TextEditingController _field3 = TextEditingController();

  bool _isPosting = false;
  List<String> selectedTags = [];
  String selectedType = 'Experience';
  String postMode = 'Quick';
  String selectedTemplate = 'Experience';

  File? _imageFile;
  File? _videoFile;
  String? _videoThumbPath;
  double? _mediaAspect;

  final picker = ImagePicker();

  final Map<String, Map<String, String>> templates = {
    'Experience': {
      'desc': 'Share what you went through and what you learned',
      'q1': 'What happened?',
      'q2': 'What did you learn?',
      'q3': 'What advice would you give others?',
    },
    'Advice Request': {
      'desc': 'Ask the community for help or insight',
      'q1': 'What’s your challenge or question?',
      'q2': 'What have you tried so far?',
      'q3': 'What kind of advice do you need?',
    },
    'How-To Guide': {
      'desc': 'Teach others something step-by-step',
      'q1': 'What are you explaining?',
      'q2': 'List the steps clearly',
      'q3': 'What’s the key takeaway?',
    },
    'Lessons Learned': {
      'desc': 'Share a few insights or realizations',
      'q1': 'Topic of your lesson',
      'q2': 'List 3–10 lessons or takeaways',
      'q3': 'One key message for others',
    },
  };

  bool get _canPost {
    if (_isPosting) return false;
    if (postMode == 'Quick') {
      return _contentController.text.trim().isNotEmpty;
    } else {
      return _field1.text.trim().isNotEmpty ||
          _field2.text.trim().isNotEmpty ||
          _field3.text.trim().isNotEmpty;
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _tagController.dispose();
    _field1.dispose();
    _field2.dispose();
    _field3.dispose();
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
        _mediaAspect = 16 / 9;
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

    String? thumbPath;
    try {
      final tempDir = await getTemporaryDirectory();
      final out = await VideoThumbnail.thumbnailFile(
        video: video.path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 480,
        quality: 75,
        timeMs: 0,
      );
      if (out != null) thumbPath = out;
    } catch (_) {}

    setState(() {
      _videoFile = video;
      _imageFile = null;
      _mediaAspect = 1.0;
      _videoThumbPath = thumbPath;
    });
  }

  // —— Save post ————————————————————————————————————————————————
  Future<void> _savePost() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please log in to post')));
      return;
    }

    String content;
    if (postMode == 'Quick') {
      content = _contentController.text.trim();
      if (content.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please write your post')));
        return;
      }
    } else {
      content = '''
**${selectedTemplate} Post**

**${templates[selectedTemplate]!['q1']}**
${_field1.text.trim()}

**${templates[selectedTemplate]!['q2']}**
${_field2.text.trim()}

**${templates[selectedTemplate]!['q3']}**
${_field3.text.trim()}
''';
    }

    setState(() => _isPosting = true);
    String? imageUrl;
    String? videoUrl;
    String? videoThumbUrl;

    try {
      if (_imageFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('post_images')
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_imageFile!);
        imageUrl = await ref.getDownloadURL();
      }

      if (_videoFile != null) {
        final vRef = FirebaseStorage.instance
            .ref()
            .child('post_videos')
            .child('${DateTime.now().millisecondsSinceEpoch}.mp4');
        await vRef.putFile(_videoFile!);
        videoUrl = await vRef.getDownloadURL();

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
        selectedTemplate,
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        videoThumbUrl: videoThumbUrl,
        mediaAspectRatio: _mediaAspect,
      );

      await _streakService.updateStreak(currentUser.uid);

      _contentController.clear();
      _tagController.clear();
      _field1.clear();
      _field2.clear();
      _field3.clear();
      setState(() {
        selectedTags.clear();
        _imageFile = null;
        _videoFile = null;
        _videoThumbPath = null;
        _mediaAspect = null;
        selectedType = 'Experience';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('✅ Post created!')));

      if (Navigator.canPop(context)) {
        Navigator.pop(context, 'posted');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to post: $e')));
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  // —— UI Helpers ————————————————————————————————————————————————
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
            top: 8,
            right: 8,
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
                    child: const Center(
                        child: Icon(Icons.videocam, size: 64, color: Colors.black54)),
                  ),
          ),
          Positioned(
            top: 8,
            right: 8,
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

  // —— Enhanced Template Input Builder ———————————————————————————
  Widget _buildTemplateFields() {
    final tpl = templates[selectedTemplate]!;
    final iconMap = {
      'Experience': Icons.auto_stories_rounded,
      'Advice Request': Icons.lightbulb_outline_rounded,
      'How-To Guide': Icons.list_alt_rounded,
      'Lessons Learned': Icons.school_rounded,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.button,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.star_rounded, color: AppColors.text, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tip: Posts that share what you learned get 3× more helpful votes ✨',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.text.withOpacity(0.8)),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Icon(iconMap[selectedTemplate] ?? Icons.auto_awesome_rounded,
                color: AppColors.text.withOpacity(0.8)),
            const SizedBox(width: 8),
            Text(
              tpl['desc']!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.text.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTemplateCard(
          title: tpl['q1']!,
          controller: _field1,
          hint: 'Type your answer here...',
        ),
        const SizedBox(height: 14),
        _buildTemplateCard(
          title: tpl['q2']!,
          controller: _field2,
          hint: 'Add more details or steps...',
        ),
        const SizedBox(height: 14),
        _buildTemplateCard(
          title: tpl['q3']!,
          controller: _field3,
          hint: 'What’s the takeaway for others?',
        ),
      ],
    );
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Quick Post'),
                    selected: postMode == 'Quick',
                    onSelected: (_) => setState(() => postMode = 'Quick'),
                    selectedColor: AppColors.button,
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Template Post'),
                    selected: postMode == 'Template',
                    onSelected: (_) => setState(() => postMode = 'Template'),
                    selectedColor: AppColors.button,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (postMode == 'Quick')
                TextField(
                  controller: _contentController,
                  maxLines: 8,
                  decoration: _pillInput(
                      hint:
                          'Share your experience, advice, or insight to help others...'),
                )
              else ...[
                Text('Choose Template:',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: templates.keys.map((type) {
                    final isSel = selectedTemplate == type;
                    return ChoiceChip(
                      label: Text(type),
                      selected: isSel,
                      onSelected: (_) => setState(() => selectedTemplate = type),
                      selectedColor: AppColors.button,
                      backgroundColor: AppColors.card,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildTemplateFields(),
                ),
              ],
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
                children: selectedTags
                    .map((tag) => Chip(
                          label: Text(tag,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          backgroundColor: AppColors.button,
                          shape: const StadiumBorder(
                              side: BorderSide(color: AppColors.border)),
                          deleteIcon:
                              const Icon(Icons.close, size: 18, color: AppColors.muted),
                          onDeleted: () => setState(() => selectedTags.remove(tag)),
                        ))
                    .toList(),
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              Text('Remove',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildTemplateCard({
  required String title,
  required TextEditingController controller,
  required String hint,
}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.text,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.text.withOpacity(0.5)),
            border: InputBorder.none,
            isDense: true,
          ),
          style: const TextStyle(height: 1.4),
        ),
      ],
    ),
  );
}
