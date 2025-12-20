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

import 'package:connect_app/screens/posts/post_image_viewer.dart';
import 'package:connect_app/screens/posts/post_video_player.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({Key? key}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final PostService _postService = PostService();
  final StreakService _streakService = StreakService();

  final TextEditingController _quickController = TextEditingController();
  final FocusNode _quickFocus = FocusNode();

  final TextEditingController _a1 = TextEditingController();
  final TextEditingController _a2 = TextEditingController();
  final TextEditingController _a3 = TextEditingController();

  final FocusNode _a1Focus = FocusNode();
  final FocusNode _a2Focus = FocusNode();
  final FocusNode _a3Focus = FocusNode();

  bool _isPosting = false;

  final List<File> _imageFiles = [];
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

  final Map<String, String> templateDescriptions = const {
    'Quick post': 'Write freely in one field.',
    'Experience': 'Share a story + what you learned.',
    'Advice Request': 'Ask a question and add context.',
    'How-To Guide': 'Explain steps so others can follow.',
    'Lessons Learned': 'Summarize takeaways from a topic.',
  };

  final List<String> selectedTags = [];
  final TextEditingController _tagController = TextEditingController();
  final FocusNode _tagFocus = FocusNode();

  bool _isTyping = false;

  bool get _hasMedia => _imageFiles.isNotEmpty || _videoFile != null;

  bool get _canPost {
    if (_isPosting) return false;

    if (_selectedTemplate == null) {
      return _quickController.text.trim().isNotEmpty || _hasMedia;
    }

    final hasAnyAnswer =
        _a1.text.trim().isNotEmpty || _a2.text.trim().isNotEmpty || _a3.text.trim().isNotEmpty;

    return hasAnyAnswer || _hasMedia;
  }

  @override
  void initState() {
    super.initState();

    void syncTyping() {
      final focused = _quickFocus.hasFocus ||
          _a1Focus.hasFocus ||
          _a2Focus.hasFocus ||
          _a3Focus.hasFocus ||
          _tagFocus.hasFocus;
      if (_isTyping != focused) setState(() => _isTyping = focused);
    }

    _quickFocus.addListener(syncTyping);
    _a1Focus.addListener(syncTyping);
    _a2Focus.addListener(syncTyping);
    _a3Focus.addListener(syncTyping);
    _tagFocus.addListener(syncTyping);
  }

  @override
  void dispose() {
    _quickController.dispose();
    _quickFocus.dispose();

    _a1.dispose();
    _a2.dispose();
    _a3.dispose();

    _a1Focus.dispose();
    _a2Focus.dispose();
    _a3Focus.dispose();

    _tagController.dispose();
    _tagFocus.dispose();
    super.dispose();
  }

  // —— Tags helpers ————————————————————————————————————————
  void _addTagFromField() {
    final raw = _tagController.text.trim();
    if (raw.isEmpty) return;

    final tag = raw.startsWith('#') ? raw : '#$raw';
    if (!selectedTags.contains(tag)) {
      setState(() => selectedTags.add(tag));
    }
    _tagController.clear();
    _tagFocus.requestFocus();
  }

  void _clearTags() => setState(() => selectedTags.clear());

  // ✅ tags sheet: INSTANT visual updates (no reopen needed)
  void _openTagsSheet() {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) {
        final bottom = MediaQuery.of(sheetCtx).viewInsets.bottom;

        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              void addTagInstant() {
                _addTagFromField();
                if (mounted) setSheetState(() {}); // ✅ refresh chips instantly
              }

              void removeTagInstant(String t) {
                setState(() => selectedTags.remove(t)); // updates main + sheet
                if (mounted) setSheetState(() {});
              }

              void clearTagsInstant() {
                _clearTags();
                if (mounted) setSheetState(() {});
              }

              return Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottom),
                child: SingleChildScrollView(
                  child: _InlineTagsComposer(
                    controller: _tagController,
                    focusNode: _tagFocus,
                    autofocus: true,
                    tags: selectedTags,
                    onAdd: addTagInstant, // ✅ instant
                    onRemove: removeTagInstant, // ✅ instant
                    onClear: clearTagsInstant, // ✅ instant
                  ),
                ),
              );
            },
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) FocusScope.of(context).unfocus();
    });
  }

  // —— Media pickers ————————————————————————————————————————
  Future<void> _pickPhotos({required bool addMore}) async {
    final picks = await picker.pickMultiImage(maxWidth: 1600, imageQuality: 85);
    if (picks.isEmpty) return;

    setState(() {
      if (!addMore) _imageFiles.clear();
      _imageFiles.addAll(picks.map((e) => File(e.path)));

      _videoFile = null;
      _videoThumbPath = null;
      _mediaAspect = 1.0;
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
        maxWidth: 900,
        quality: 80,
        timeMs: 0,
      );
      thumbPath = out;
    } catch (_) {
      thumbPath = null;
    }

    setState(() {
      _videoFile = video;
      _videoThumbPath = thumbPath;
      _mediaAspect = 16 / 9;

      _imageFiles.clear();
    });
  }

  void _removePhotoAt(int index) {
    setState(() {
      if (index >= 0 && index < _imageFiles.length) _imageFiles.removeAt(index);
    });
  }

  void _removeVideo() {
    setState(() {
      _videoFile = null;
      _videoThumbPath = null;
      _mediaAspect = null;
    });
  }

  void _removeAllMedia() {
    setState(() {
      _imageFiles.clear();
      _videoFile = null;
      _videoThumbPath = null;
      _mediaAspect = null;
    });
  }

  // ✅ media sheet: bottom sheet style + INSTANT updates (no reopen)
  void _openMediaSheet() {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              Future<void> pickPhotosFromSheet({required bool addMore}) async {
                await _pickPhotos(addMore: addMore);
                if (mounted) setSheetState(() {}); // ✅ instant
              }

              Future<void> pickVideoFromSheet() async {
                await _pickVideo();
                if (mounted) setSheetState(() {});
              }

              void removeAllFromSheet() {
                _removeAllMedia();
                if (mounted) setSheetState(() {});
              }

              void removePhotoAtFromSheet(int i) {
                _removePhotoAt(i);
                if (mounted) setSheetState(() {});
              }

              void removeVideoFromSheet() {
                _removeVideo();
                if (mounted) setSheetState(() {});
              }

              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                child: _MediaPanel(
                  imageFiles: _imageFiles,
                  videoFile: _videoFile,
                  videoThumbPath: _videoThumbPath,
                  onAddPhotos: () => pickPhotosFromSheet(addMore: false),
                  onAddVideo: pickVideoFromSheet,
                  onRemoveAll: removeAllFromSheet,
                  onRemovePhotoAt: removePhotoAtFromSheet,
                  onRemoveVideo: removeVideoFromSheet,
                  onAddMorePhotos: () => pickPhotosFromSheet(addMore: true),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // —— Templates ————————————————————————————————————————————————
  void _selectTemplate(String name) {
    setState(() {
      _selectedTemplate = name;
      _quickController.clear();
    });
    Future.microtask(() => FocusScope.of(context).unfocus());
  }

  void _setQuickPost() {
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
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        _setQuickPost();
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text(
                        'Set Quick',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _TemplateRowPro(
                  title: 'Quick post',
                  subtitle: templateDescriptions['Quick post']!,
                  selected: _selectedTemplate == null,
                  icon: Icons.flash_on_rounded,
                  onTap: () {
                    Navigator.pop(context);
                    _setQuickPost();
                  },
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 10),
                ...templates.keys.map((k) {
                  return _TemplateRowPro(
                    title: k,
                    subtitle: templateDescriptions[k] ?? '',
                    selected: _selectedTemplate == k,
                    icon: Icons.view_list_outlined,
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

  // —— Clear everything after successful post ——————————————————————
  void _resetComposer() {
    _quickController.clear();
    _a1.clear();
    _a2.clear();
    _a3.clear();
    _tagController.clear();
    selectedTags.clear();
    _removeAllMedia();
    FocusScope.of(context).unfocus();
    setState(() {});
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

    if (content.trim().isEmpty && !_hasMedia) return;

    setState(() => _isPosting = true);

    String? imageUrl;
    String? videoUrl;
    String? videoThumbUrl;

    try {
      if (_imageFiles.isNotEmpty) {
        final first = _imageFiles.first;
        final ref = FirebaseStorage.instance
            .ref()
            .child('post_images')
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(first);
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

      _resetComposer();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Posted ✅')),
      );

      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) Navigator.of(context).maybePop('posted');
      });
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
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            leading: const SizedBox(width: 0),
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
                Text(
                  _selectedTemplate ?? 'Quick post',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: _isPosting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Post', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    _ModeChip(
                      label: 'Quick',
                      selected: _selectedTemplate == null,
                      onTap: _setQuickPost,
                    ),
                    const SizedBox(width: 8),
                    _ModeChip(
                      label: 'Template',
                      selected: _selectedTemplate != null,
                      onTap: _openTemplateSheet,
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              const SizedBox(height: 10),
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
                          a1Focus: _a1Focus,
                          a2Focus: _a2Focus,
                          a3Focus: _a3Focus,
                          onChanged: () => setState(() {}),
                        ),
                ),
              ),

              // ✅ keep 2 buttons exactly like before (Media + Tags)
              SafeArea(
                top: false,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _PillButton(
                          label: (_imageFiles.isNotEmpty || _videoFile != null)
                              ? 'Media (${_imageFiles.length + (_videoFile != null ? 1 : 0)})'
                              : 'Media',
                          icon: Icons.photo_library_outlined,
                          onTap: _openMediaSheet,
                          selected: _hasMedia,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PillButton(
                          label: selectedTags.isNotEmpty ? 'Tags (${selectedTags.length})' : 'Tags',
                          icon: Icons.tag_outlined,
                          onTap: _openTagsSheet,
                          selected: selectedTags.isNotEmpty,
                        ),
                      ),
                    ],
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

// ===== Media panel (bottom sheet content) =====

class _MediaPanel extends StatelessWidget {
  final List<File> imageFiles;
  final File? videoFile;
  final String? videoThumbPath;

  final VoidCallback onAddPhotos;
  final VoidCallback onAddVideo;

  final VoidCallback onRemoveAll;
  final ValueChanged<int> onRemovePhotoAt;
  final VoidCallback onRemoveVideo;
  final VoidCallback onAddMorePhotos;

  const _MediaPanel({
    required this.imageFiles,
    required this.videoFile,
    required this.videoThumbPath,
    required this.onAddPhotos,
    required this.onAddVideo,
    required this.onRemoveAll,
    required this.onRemovePhotoAt,
    required this.onRemoveVideo,
    required this.onAddMorePhotos,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhotos = imageFiles.isNotEmpty;
    final hasVideo = videoFile != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Media',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onRemoveAll,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Text(
                    'Remove all',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _SheetAction(
                  icon: Icons.image_outlined,
                  label: hasPhotos ? 'Replace photos' : 'Add photos',
                  onTap: onAddPhotos,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SheetAction(
                  icon: Icons.videocam_outlined,
                  label: hasVideo ? 'Replace video' : 'Add video',
                  onTap: onAddVideo,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (hasPhotos)
            _PhotosRow(
              imageFiles: imageFiles,
              onRemoveAt: onRemovePhotoAt,
              onAdd: onAddMorePhotos,
            ),

          if (hasVideo) ...[
            if (hasPhotos) const SizedBox(height: 12),
            _BigVideoPreview(
              thumbPath: videoThumbPath,
              videoFile: videoFile!,
              onRemove: onRemoveVideo,
            ),
          ],

          if (!hasPhotos && !hasVideo)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'No media added yet.',
                style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: AppColors.muted),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
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

class _PhotosRow extends StatelessWidget {
  final List<File> imageFiles;
  final ValueChanged<int> onRemoveAt;
  final VoidCallback onAdd;

  const _PhotosRow({
    required this.imageFiles,
    required this.onRemoveAt,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    const double size = 86;
    const double radius = 16;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...List.generate(imageFiles.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(radius),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostImageViewer(file: imageFiles[i]),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius),
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: Image.file(imageFiles[i], fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -6,
                    top: -6,
                    child: _MiniRemoveButton(onTap: () => onRemoveAt(i)),
                  ),
                ],
              ),
            );
          }),
          InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: onAdd,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Icon(Icons.add_rounded, size: 28, color: AppColors.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigVideoPreview extends StatelessWidget {
  final String? thumbPath;
  final File videoFile;
  final VoidCallback onRemove;

  const _BigVideoPreview({
    required this.thumbPath,
    required this.videoFile,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostVideoPlayer(file: videoFile)),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 140,
              width: double.infinity,
              child: (thumbPath != null && thumbPath!.isNotEmpty)
                  ? Image.file(File(thumbPath!), fit: BoxFit.cover)
                  : Container(
                      color: AppColors.button,
                      alignment: Alignment.center,
                      child: const Icon(Icons.videocam_rounded, color: AppColors.muted, size: 34),
                    ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
              ),
            ),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: Material(
              color: Colors.black.withOpacity(0.50),
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Icon(Icons.close, size: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniRemoveButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MiniRemoveButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.55),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Icon(Icons.close, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

// ===== Tags =====

class _InlineTagsComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool autofocus;
  final List<String> tags;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  const _InlineTagsComposer({
    required this.controller,
    required this.focusNode,
    required this.autofocus,
    required this.tags,
    required this.onAdd,
    required this.onRemove,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Tags',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
                letterSpacing: -0.2,
              ),
            ),
            const Spacer(),
            if (tags.isNotEmpty)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onClear,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: autofocus,
                textInputAction: TextInputAction.done,
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: 'Add a tag (e.g. career)',
                  hintStyle: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
                  ),
                ),
                // ✅ onSubmitted triggers instantly (sheet refresh handled by onAdd)
                onSubmitted: (_) => onAdd(),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 44,
              child: TextButton(
                onPressed: onAdd,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primary.withOpacity(0.10),
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: AppColors.primary.withOpacity(0.25)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: tags
                  .map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          t,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        backgroundColor: Colors.white,
                        shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
                        deleteIcon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                        onDeleted: () => onRemove(t),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}

// ===== Editors =====

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

  final FocusNode a1Focus;
  final FocusNode a2Focus;
  final FocusNode a3Focus;

  final VoidCallback onChanged;

  const _TemplateEditor({
    required this.template,
    required this.a1,
    required this.a2,
    required this.a3,
    required this.a1Focus,
    required this.a2Focus,
    required this.a3Focus,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget block(String q, TextEditingController c, FocusNode f) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              q,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: c,
              focusNode: f,
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
        block(template['q1']!, a1, a1Focus),
        block(template['q2']!, a2, a2Focus),
        block(template['q3']!, a3, a3Focus),
      ],
    );
  }
}

// ===== UI components =====

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.primary.withOpacity(0.10) : AppColors.button;
    final fg = selected ? AppColors.primary : AppColors.text;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.primary.withOpacity(0.25) : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _TemplateRowPro extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  const _TemplateRowPro({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final leadingBg = selected ? AppColors.primary.withOpacity(0.10) : AppColors.button;
    final leadingFg = selected ? AppColors.primary : AppColors.muted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: leadingBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(selected ? Icons.check_rounded : icon, color: leadingFg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  const _PillButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.primary.withOpacity(0.10) : Colors.white;
    final border = selected ? AppColors.primary.withOpacity(0.25) : AppColors.border;
    final iconColor = selected ? AppColors.primary : AppColors.muted;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                    fontSize: 13,
                    letterSpacing: -0.2,
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
