// lib/screens/posts/create_post_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Quick post
  final TextEditingController _quickController = TextEditingController();
  final FocusNode _quickFocus = FocusNode();

  // Template answers
  final TextEditingController _a1 = TextEditingController();
  final TextEditingController _a2 = TextEditingController();
  final TextEditingController _a3 = TextEditingController();

  bool _isPosting = false;

  File? _imageFile;
  File? _videoFile;
  String? _videoThumbPath;
  double? _mediaAspect;

  final picker = ImagePicker();

  String? _selectedTemplate; // null => Quick

  final Map<String, Map<String, String>> templates = const {
    'Experience': {
      'q1': 'What happened?',
      'q2': 'What did you learn?',
      'q3': 'What advice would you give others?',
    },
    'Advice Request': {
      'q1': 'What’s your challenge or question?',
      'q2': 'What have you tried so far?',
      'q3': 'What kind of advice do you need?',
    },
    'How-To Guide': {
      'q1': 'What are you explaining?',
      'q2': 'List the steps clearly',
      'q3': 'What’s the key takeaway?',
    },
    'Lessons Learned': {
      'q1': 'Topic of your lesson',
      'q2': 'List 3–10 lessons or takeaways',
      'q3': 'One key message for others',
    },
  };

  // tags kept simple
  final List<String> selectedTags = [];
  final TextEditingController _tagController = TextEditingController();

  bool get _canPost {
    if (_isPosting) return false;
    final hasMedia = _imageFile != null || _videoFile != null;

    if (_selectedTemplate == null) {
      return _quickController.text.trim().isNotEmpty || hasMedia;
    }

    final hasAnyAnswer = _a1.text.trim().isNotEmpty ||
        _a2.text.trim().isNotEmpty ||
        _a3.text.trim().isNotEmpty;

    return hasAnyAnswer || hasMedia;
  }

  @override
  void dispose() {
    _quickController.dispose();
    _quickFocus.dispose();
    _a1.dispose();
    _a2.dispose();
    _a3.dispose();
    _tagController.dispose();
    super.dispose();
  }

  // —— Navigation close (safe; avoids weird blank state) ————————————————
  void _close() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).maybePop();
  }

  // —— Media pickers ————————————————————————————————————————
  Future<void> _pickImage() async {
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _imageFile = File(picked.path);
      _videoFile = null;
      _videoThumbPath = null;
      _mediaAspect = 16 / 9;
    });
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
        maxWidth: 520,
        quality: 75,
        timeMs: 0,
      );
      thumbPath = out;
    } catch (_) {}

    setState(() {
      _videoFile = video;
      _imageFile = null;
      _mediaAspect = 1.0;
      _videoThumbPath = thumbPath;
    });
  }

  void _removeMedia() {
    setState(() {
      _imageFile = null;
      _videoFile = null;
      _videoThumbPath = null;
      _mediaAspect = null;
    });
  }

  // —— Templates ————————————————————————————————————————————————
  void _selectTemplate(String name) {
    setState(() {
      _selectedTemplate = name;
      _quickController.clear();
    });

    Future.microtask(() {
      FocusScope.of(context).unfocus();
    });
  }

  void _clearTemplate() {
    setState(() {
      _selectedTemplate = null;
      _a1.clear();
      _a2.clear();
      _a3.clear();
    });

    Future.microtask(() => _quickFocus.requestFocus());
  }

  void _openTemplateSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'Templates',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        _clearTemplate();
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('Clear',
                          style: TextStyle(color: AppColors.muted)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...templates.keys.map((k) {
                  final selected = _selectedTemplate == k;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.button,
                      child: Icon(
                        selected ? Icons.check : Icons.view_list_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      k,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _selectTemplate(k);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // —— Tags ————————————————————————————————————————————————
  void _openTagsSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'Tags',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() => selectedTags.clear());
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('Clear',
                          style: TextStyle(color: AppColors.muted)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _tagController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: 'Type a tag and press enter (e.g. career)',
                    filled: false,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (value) {
                    final raw = value.trim();
                    if (raw.isEmpty) return;
                    final tag = raw.startsWith('#') ? raw : '#$raw';
                    if (!selectedTags.contains(tag)) {
                      setState(() => selectedTags.add(tag));
                    }
                    _tagController.clear();
                  },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedTags
                        .map(
                          (t) => Chip(
                            label: Text(t),
                            backgroundColor: AppColors.button,
                            shape: const StadiumBorder(
                              side: BorderSide(color: AppColors.border),
                            ),
                            deleteIcon: const Icon(Icons.close,
                                size: 18, color: AppColors.muted),
                            onDeleted: () =>
                                setState(() => selectedTags.remove(t)),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // —— Save post ————————————————————————————————————————————————
  Future<void> _savePost() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to post')),
      );
      return;
    }

    String content = '';
    if (_selectedTemplate == null) {
      content = _quickController.text.trim();
    } else {
      final t = templates[_selectedTemplate]!;
      content = [
        t['q1']!,
        _a1.text.trim(),
        '',
        t['q2']!,
        _a2.text.trim(),
        '',
        t['q3']!,
        _a3.text.trim(),
      ].join('\n');
    }

    if (content.trim().isEmpty && _imageFile == null && _videoFile == null) return;

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

      final type = _selectedTemplate ?? 'Quick';

      await _postService.createPost(
        content,
        selectedTags,
        type,
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        videoThumbUrl: videoThumbUrl,
        mediaAspectRatio: _mediaAspect,
      );

      await _streakService.updateStreak(currentUser.uid);

      if (!mounted) return;

      // ✅ safe pop (don’t force rootNavigator here)
      Navigator.of(context).maybePop('posted');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post: $e')),
      );
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  // —— UI ————————————————————————————————————————————————
  @override
  Widget build(BuildContext context) {
    // local override so ONLY this screen has blank fields
    final localTheme = Theme.of(context).copyWith(
      scaffoldBackgroundColor: Colors.white,
      canvasColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: false,
        fillColor: Colors.transparent,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
    );

    return Theme(
      data: localTheme,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          appBar: AppBar(
            leadingWidth: 84,
            leading: TextButton(
              onPressed: _close,
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
                padding: const EdgeInsets.only(left: 12),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Create a post',
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_selectedTemplate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _selectedTemplate!,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            centerTitle: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TextButton(
                  onPressed: _canPost ? _savePost : null,
                  style: TextButton.styleFrom(
                    backgroundColor: _canPost ? AppColors.primary : AppColors.button,
                    foregroundColor: _canPost ? Colors.white : AppColors.muted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: _isPosting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Post',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: _selectedTemplate == null
                      ? _QuickEditor(
                          controller: _quickController,
                          focusNode: _quickFocus,
                          onChanged: () => setState(() {}),
                        )
                      : _TemplateEditor(
                          template: templates[_selectedTemplate]!,
                          a1: _a1,
                          a2: _a2,
                          a3: _a3,
                          onChanged: () => setState(() {}),
                        ),
                ),
              ),

              if (_imageFile != null || _videoFile != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _imageFile != null
                            ? Image.file(_imageFile!, height: 180, fit: BoxFit.cover)
                            : (_videoThumbPath != null
                                ? Image.file(File(_videoThumbPath!),
                                    height: 180, fit: BoxFit.cover)
                                : Container(
                                    height: 180,
                                    color: Colors.black12,
                                    child: const Center(
                                      child: Icon(Icons.videocam,
                                          size: 48, color: Colors.black54),
                                    ),
                                  )),
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Material(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: _removeMedia,
                            child: const Padding(
                              padding:
                                  EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Icon(Icons.close,
                                  size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ✅ premium bottom action bar (ONLY this screen)
              SafeArea(
                top: false,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.border, width: 1)),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: _CreatePostActionBar(
                    disabled: _isPosting,
                    onPhoto: _pickImage,
                    onVideo: _pickVideo,
                    onTemplate: _openTemplateSheet,
                    onTags: _openTagsSheet,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickEditor extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;

  const _QuickEditor({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(
        fontSize: 18,
        height: 1.35,
        color: AppColors.text,
        fontWeight: FontWeight.w500,
      ),
      decoration: const InputDecoration(
        hintText: 'What do you want to talk about?',
        hintStyle: TextStyle(
          color: Color(0xFF9C9A96),
          fontWeight: FontWeight.w500,
        ),
      ),
      onChanged: (_) => onChanged(),
    );
  }
}

class _TemplateEditor extends StatelessWidget {
  final Map<String, String> template;
  final TextEditingController a1;
  final TextEditingController a2;
  final TextEditingController a3;
  final VoidCallback onChanged;

  const _TemplateEditor({
    required this.template,
    required this.a1,
    required this.a2,
    required this.a3,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget block(String q, TextEditingController c) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              q,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: c,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                fontSize: 18,
                height: 1.35,
                color: AppColors.text,
                fontWeight: FontWeight.w500,
              ),
              // ✅ removed "Write here..."
              decoration: const InputDecoration(
                hintText: '',
                isCollapsed: true,
                border: InputBorder.none,
              ),
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: 10),
            const Divider(height: 18, color: AppColors.border),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        block(template['q1']!, a1),
        block(template['q2']!, a2),
        block(template['q3']!, a3),
      ],
    );
  }
}

/// ✅ Premium bottom bar (ONLY in create post screen)
class _CreatePostActionBar extends StatelessWidget {
  final bool disabled;
  final VoidCallback onPhoto;
  final VoidCallback onVideo;
  final VoidCallback onTemplate;
  final VoidCallback onTags;

  const _CreatePostActionBar({
    required this.disabled,
    required this.onPhoto,
    required this.onVideo,
    required this.onTemplate,
    required this.onTags,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: AppColors.button,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _ActionItem(
            icon: Icons.image_outlined,
            label: 'Photo',
            disabled: disabled,
            onTap: onPhoto,
          ),
          const _ActionSep(),
          _ActionItem(
            icon: Icons.videocam_outlined,
            label: 'Video',
            disabled: disabled,
            onTap: onVideo,
          ),
          const _ActionSep(),
          _ActionItem(
            icon: Icons.view_list_outlined,
            label: 'Template',
            disabled: disabled,
            onTap: onTemplate,
          ),
          const _ActionSep(),
          _ActionItem(
            icon: Icons.tag_outlined,
            label: 'Tags',
            disabled: disabled,
            onTap: onTags,
          ),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool disabled;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = disabled ? AppColors.border : AppColors.muted;
    final text = disabled ? AppColors.border : AppColors.text;

    return Expanded(
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionSep extends StatelessWidget {
  const _ActionSep();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 26,
      color: AppColors.border,
    );
  }
}
