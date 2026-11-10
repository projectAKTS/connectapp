// lib/screens/posts/create_post_screen.dart
import 'package:connect_app/l10n/l10n.dart';
import 'dart:io';

import 'package:connect_app/services/content_filter.dart';
import 'package:connect_app/services/app_telemetry.dart';
import 'package:flutter/material.dart';
import 'package:connect_app/widgets/main_scaffold.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:connect_app/services/post_service.dart';
import 'package:connect_app/services/streak_service.dart';
import 'package:connect_app/services/firestore_read_helper.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:connect_app/widgets/initials_avatar.dart';
import 'package:connect_app/widgets/post_media.dart';

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
  Duration? _videoDuration;

  final picker = ImagePicker();

  static const _maxPhotos = 10;
  static const _maxVideo = Duration(minutes: 3);

  String _myName = '';
  String _myAvatar = '';

  String? _selectedTemplate; // null => Quick

  // Keys are the stored post types; prompts and descriptions follow the
  // app language (the prompts become part of the author's post).
  Map<String, Map<String, String>> get templates {
    final l = context.l10n;
    return {
      'Experience': {
        'q1': l.tplExperienceQ1,
        'q2': l.tplExperienceQ2,
        'q3': l.tplExperienceQ3,
      },
      'Advice Request': {
        'q1': l.tplAdviceQ1,
        'q2': l.tplAdviceQ2,
        'q3': l.tplAdviceQ3,
      },
      'How-To Guide': {
        'q1': l.tplHowToQ1,
        'q2': l.tplHowToQ2,
        'q3': l.tplHowToQ3,
      },
      'Lessons Learned': {
        'q1': l.tplLessonsQ1,
        'q2': l.tplLessonsQ2,
        'q3': l.tplLessonsQ3,
      },
    };
  }

  Map<String, String> get templateDescriptions {
    final l = context.l10n;
    return {
      'Quick post': l.tplQuickDesc,
      'Experience': l.tplExperienceDesc,
      'Advice Request': l.tplAdviceDesc,
      'How-To Guide': l.tplHowToDesc,
      'Lessons Learned': l.tplLessonsDesc,
    };
  }

  String _templateLabel(String? key) {
    final l = context.l10n;
    switch (key) {
      case null:
        return l.createQuickPost;
      case 'Experience':
        return l.postFilterExperience;
      case 'Advice Request':
        return l.postFilterAdvice;
      case 'How-To Guide':
        return l.postFilterHowTo;
      case 'Lessons Learned':
        return l.postFilterLessons;
    }
    return key;
  }

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

    final hasAnyAnswer = _a1.text.trim().isNotEmpty ||
        _a2.text.trim().isNotEmpty ||
        _a3.text.trim().isNotEmpty;

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
    _loadMe();
  }

  Future<void> _loadMe() async {
    final uid = HelperlyTestRuntime.currentUid;
    _myName = HelperlyTestRuntime.currentDisplayName ?? '';
    if (uid == null || uid.isEmpty) return;
    try {
      final me = await FirestoreReadHelper.getDoc(
          HelperlyTestRuntime.firestore.collection('users').doc(uid));
      final d = me.data() ?? const <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        final name = '${d['displayName'] ?? d['fullName'] ?? ''}'.trim();
        if (name.isNotEmpty) _myName = name;
        _myAvatar = '${d['profilePicture'] ?? ''}';
      });
    } catch (_) {}
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
  /// Width / height of a picture as it is shown.
  static Future<double?> _imageAspect(File f) async {
    try {
      final img = await decodeImageFromList(await f.readAsBytes());
      final a = img.width / img.height;
      img.dispose();
      return a.isFinite && a > 0 ? a : null;
    } catch (_) {
      return null;
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Adds photos (up to [_maxPhotos]); photos replace a chosen video.
  Future<void> _addPhotos(List<File> files) async {
    if (files.isEmpty || !mounted) return;
    final keep = _videoFile == null ? List<File>.from(_imageFiles) : <File>[];
    final room = _maxPhotos - keep.length;
    if (files.length > room) {
      _snack(context.l10n.createPhotoLimit(_maxPhotos));
    }
    keep.addAll(files.take(room < 0 ? 0 : room));
    if (keep.isEmpty) return;
    final aspect = await _imageAspect(keep.first);
    if (!mounted) return;
    setState(() {
      _imageFiles
        ..clear()
        ..addAll(keep);
      _videoFile = null;
      _videoThumbPath = null;
      _videoDuration = null;
      _mediaAspect = aspect ?? 1.0;
    });
  }

  Future<void> _pickPhotos() async {
    HapticFeedback.selectionClick();
    final picks = await picker.pickMultiImage(maxWidth: 1600, imageQuality: 85);
    await _addPhotos(picks.map((e) => File(e.path)).toList());
  }

  Future<void> _takePhoto() async {
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) await _addPhotos([File(picked.path)]);
  }

  Future<void> _pickVideo() async {
    HapticFeedback.selectionClick();
    await _setVideo(await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: _maxVideo,
    ));
  }

  Future<void> _recordVideo() async {
    await _setVideo(await picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: _maxVideo,
    ));
  }

  /// A video replaces any photos; its frame gives the preview and shape.
  Future<void> _setVideo(XFile? picked) async {
    if (picked == null) return;
    final video = File(picked.path);

    Duration? length;
    double? aspect;
    try {
      final probe = VideoPlayerController.file(video);
      await probe.initialize();
      length = probe.value.duration;
      aspect = probe.value.aspectRatio;
      await probe.dispose();
    } catch (_) {}
    // The library picker does not enforce maxDuration everywhere.
    if (!mounted) return;
    if (length != null && length > _maxVideo + const Duration(seconds: 1)) {
      _snack(context.l10n.createVideoTooLong(_maxVideo.inMinutes));
      return;
    }

    String? thumbPath;
    try {
      final tempDir = await getTemporaryDirectory();
      thumbPath = await VideoThumbnail.thumbnailFile(
        video: video.path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 900,
        quality: 80,
        timeMs: 0,
      );
    } catch (_) {
      thumbPath = null;
    }
    // The frame is already upright; the player's size may not be.
    if (thumbPath != null) {
      aspect = await _imageAspect(File(thumbPath)) ?? aspect;
    }
    if (!mounted) return;

    setState(() {
      _videoFile = video;
      _videoThumbPath = thumbPath;
      _videoDuration = length;
      _mediaAspect = aspect ?? 16 / 9;
      _imageFiles.clear();
    });
  }

  void _openCamera() {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    _chooseMediaType(context, onPhoto: _takePhoto, onVideo: _recordVideo);
  }

  Future<void> _removePhotoAt(int index) async {
    if (index < 0 || index >= _imageFiles.length) return;
    setState(() => _imageFiles.removeAt(index));
    if (index == 0 && _imageFiles.isNotEmpty) {
      final aspect = await _imageAspect(_imageFiles.first);
      if (mounted) setState(() => _mediaAspect = aspect ?? 1.0);
    }
  }

  void _removeVideo() {
    setState(() {
      _videoFile = null;
      _videoThumbPath = null;
      _videoDuration = null;
      _mediaAspect = null;
    });
  }

  void _removeAllMedia() {
    setState(() {
      _imageFiles.clear();
      _videoFile = null;
      _videoThumbPath = null;
      _videoDuration = null;
      _mediaAspect = null;
    });
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
                    Text(
                      context.l10n.createTemplates,
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
                      child: Text(
                        context.l10n.createSetQuick,
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
                  title: context.l10n.createQuickPost,
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
                    title: _templateLabel(k),
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
        SnackBar(content: Text(context.l10n.createLoginToPost)),
      );
      return;
    }

    FocusScope.of(context).unfocus();

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
    if (!ContentFilter.isAllowed('$content ${selectedTags.join(' ')}')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.contentRejected)),
      );
      return;
    }

    setState(() => _isPosting = true);

    final type = _selectedTemplate ?? 'Quick';

    try {
      if (_hasMedia) {
        final imageFiles = List<File>.from(_imageFiles);
        final videoFile = _videoFile;
        final videoThumbPath = _videoThumbPath;
        final mediaAspect = _mediaAspect;
        final mediaCount = imageFiles.length + (videoFile != null ? 1 : 0);

        final postId = await _postService.createPostShell(
          content,
          selectedTags,
          type,
          mediaUploading: true,
          mediaCount: mediaCount,
          hasVideo: videoFile != null,
          mediaAspectRatio: mediaAspect,
          videoDurationMs:
              videoFile != null ? _videoDuration?.inMilliseconds : null,
        );

        await _streakService.updateStreak(currentUser.uid);

        if (!mounted) return;
        _resetComposer();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.homePostingInBackground)),
        );

        Future.delayed(const Duration(milliseconds: 150), () {
          if (!mounted) return;
          // Opened as a tab root nothing pops: show the feed with the post.
          if (!Navigator.of(context).canPop()) MainTabs.requested.value = 0;
          Navigator.of(context).maybePop('posted');
        });

        _uploadMediaAndUpdatePost(
          postId: postId,
          imageFiles: imageFiles,
          videoFile: videoFile,
          videoThumbPath: videoThumbPath,
          mediaAspect: mediaAspect,
        );

        return;
      }

      await _postService.createPost(
        content,
        selectedTags,
        type,
      );

      await _streakService.updateStreak(currentUser.uid);

      if (!mounted) return;

      _resetComposer();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.createPosted)),
      );
      AppTelemetry.event('post_created');

      Future.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        // Opened as a tab root nothing pops: show the feed with the post.
        if (!Navigator.of(context).canPop()) MainTabs.requested.value = 0;
        Navigator.of(context).maybePop('posted');
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.createPostFailed)),
      );
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Future<void> _uploadMediaAndUpdatePost({
    required String postId,
    required List<File> imageFiles,
    required File? videoFile,
    required String? videoThumbPath,
    required double? mediaAspect,
  }) async {
    String? imageUrl;
    final List<String> imageUrls = [];
    String? videoUrl;
    String? videoThumbUrl;
    // Storage rules let only the owner write under post_*/{uid}/.
    final ownerUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      if (imageFiles.isNotEmpty) {
        for (var i = 0; i < imageFiles.length; i++) {
          final file = imageFiles[i];
          final ref = FirebaseStorage.instance
              .ref()
              .child('post_images')
              .child(ownerUid)
              .child('${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
          await ref
              .putFile(file, SettableMetadata(contentType: 'image/jpeg'))
              .timeout(const Duration(minutes: 3));
          imageUrls.add(await ref.getDownloadURL());
        }
        if (imageUrls.isNotEmpty) imageUrl = imageUrls.first;
      }

      if (videoFile != null) {
        final vRef = FirebaseStorage.instance
            .ref()
            .child('post_videos')
            .child(ownerUid)
            .child('${DateTime.now().millisecondsSinceEpoch}.mp4');
        await vRef
            .putFile(videoFile, SettableMetadata(contentType: 'video/mp4'))
            .timeout(const Duration(minutes: 5));
        videoUrl = await vRef.getDownloadURL();

        if (videoThumbPath != null) {
          final tRef = FirebaseStorage.instance
              .ref()
              .child('post_video_thumbs')
              .child(ownerUid)
              .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
          await tRef
              .putFile(File(videoThumbPath),
                  SettableMetadata(contentType: 'image/jpeg'))
              .timeout(const Duration(minutes: 2));
          videoThumbUrl = await tRef.getDownloadURL();
        }
      }

      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
        if (videoUrl != null && videoUrl.isNotEmpty) 'videoUrl': videoUrl,
        if (videoThumbUrl != null && videoThumbUrl.isNotEmpty)
          'videoThumbUrl': videoThumbUrl,
        if (mediaAspect != null && mediaAspect > 0)
          'mediaAspectRatio': mediaAspect,
        'mediaUploadStatus': 'ready',
        'mediaUploadUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'mediaUploadStatus': 'failed',
        'mediaUploadUpdatedAt': FieldValue.serverTimestamp(),
      });
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
    final canClose = Navigator.of(context).canPop();
    final photoCount = _imageFiles.length;

    return Theme(
      data: localTheme,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: canClose
                ? IconButton(
                    tooltip: context.l10n.mediaClose,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                : null,
            title: Text(
              context.l10n.createTitle,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            centerTitle: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TextButton(
                  onPressed: _canPost ? _savePost : null,
                  style: TextButton.styleFrom(
                    backgroundColor:
                        _canPost ? AppColors.primary : AppColors.button,
                    foregroundColor: _canPost ? Colors.white : AppColors.muted,
                    shape: const StadiumBorder(),
                    minimumSize: const Size(72, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: _isPosting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(context.l10n.tabPost,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              AbsorbPointer(
                absorbing: _isPosting,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          Row(
                            children: [
                              InitialsAvatar(
                                  url: _myAvatar, name: _myName, radius: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_myName.isNotEmpty)
                                      Text(
                                        _myName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: AppColors.text,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    _TypeSelector(
                                      label: _templateLabel(_selectedTemplate),
                                      onTap: _openTemplateSheet,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _selectedTemplate == null
                              ? _QuickEditor(
                                  controller: _quickController,
                                  focusNode: _quickFocus,
                                  onChanged: () => setState(() {}),
                                  readOnly: _isPosting,
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
                                  readOnly: _isPosting,
                                ),
                          if (selectedTags.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final t in selectedTags)
                                  _TagChip(
                                    label: t,
                                    onRemove: () =>
                                        setState(() => selectedTags.remove(t)),
                                  ),
                              ],
                            ),
                          ],
                          if (_hasMedia) ...[
                            const SizedBox(height: 16),
                            _ComposerMedia(
                              photos: _imageFiles,
                              videoFile: _videoFile,
                              videoThumbPath: _videoThumbPath,
                              videoDuration: _videoDuration,
                              aspect: postMediaAspect(_mediaAspect),
                              canAddPhotos: photoCount < _maxPhotos,
                              onAddPhotos: _pickPhotos,
                              onRemovePhoto: _removePhotoAt,
                              onRemoveVideo: _removeVideo,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border:
                            Border(top: BorderSide(color: AppColors.border)),
                      ),
                      padding: const EdgeInsets.fromLTRB(6, 2, 14, 2),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            _ToolButton(
                              icon: Icons.photo_library_outlined,
                              tooltip: context.l10n.createAddPhotos,
                              active: photoCount > 0,
                              onTap: _pickPhotos,
                            ),
                            _ToolButton(
                              icon: Icons.photo_camera_outlined,
                              tooltip: context.l10n.createUseCamera,
                              onTap: _openCamera,
                            ),
                            _ToolButton(
                              icon: Icons.videocam_outlined,
                              tooltip: context.l10n.createAddVideo,
                              active: _videoFile != null,
                              onTap: _pickVideo,
                            ),
                            _ToolButton(
                              icon: Icons.tag_rounded,
                              tooltip: context.l10n.createTags,
                              active: selectedTags.isNotEmpty,
                              onTap: _openTagsSheet,
                            ),
                            const Spacer(),
                            if (photoCount > 0)
                              Text(
                                context.l10n
                                    .mediaCounter(photoCount, _maxPhotos),
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isPosting)
                Positioned.fill(
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.65),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.l10n.createPosting,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
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

// ===== Composer media =====

/// The chosen photos or video, shown in the composer the way the post
/// will look. Tap to view full screen; the x removes one.
class _ComposerMedia extends StatelessWidget {
  final List<File> photos;
  final File? videoFile;
  final String? videoThumbPath;
  final Duration? videoDuration;
  final double aspect;
  final bool canAddPhotos;
  final VoidCallback onAddPhotos;
  final ValueChanged<int> onRemovePhoto;
  final VoidCallback onRemoveVideo;

  const _ComposerMedia({
    required this.photos,
    required this.videoFile,
    required this.videoThumbPath,
    required this.videoDuration,
    required this.aspect,
    required this.canAddPhotos,
    required this.onAddPhotos,
    required this.onRemovePhoto,
    required this.onRemoveVideo,
  });

  @override
  Widget build(BuildContext context) {
    final video = videoFile;
    if (video != null) {
      final thumb = videoThumbPath;
      return _Removable(
        onRemove: onRemoveVideo,
        child: GestureDetector(
          onTap: () => openVideoPlayer(context, file: video),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: aspect,
              child: ColoredBox(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumb != null && thumb.isNotEmpty)
                      Image.file(File(thumb), fit: BoxFit.contain),
                    Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.8),
                              width: 2),
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 36),
                      ),
                    ),
                    if (videoDuration != null)
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: ViewerPill(
                          icon: Icons.videocam_rounded,
                          text: formatMediaDuration(videoDuration!),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (photos.length == 1) {
      return _Removable(
        onRemove: () => onRemovePhoto(0),
        child: GestureDetector(
          onTap: () => openImageViewer(context, files: photos),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: aspect,
              child: Image.file(photos.first, fit: BoxFit.cover),
            ),
          ),
        ),
      );
    }

    const height = 220.0;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: photos.length + (canAddPhotos ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == photos.length) {
            return Material(
              color: AppColors.button,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onAddPhotos,
                child: SizedBox(
                  width: height * 0.6,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_photo_alternate_outlined,
                          color: AppColors.muted, size: 30),
                      const SizedBox(height: 6),
                      Text(
                        context.l10n.createAddPhotos,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return _Removable(
            onRemove: () => onRemovePhoto(i),
            child: GestureDetector(
              onTap: () =>
                  openImageViewer(context, files: photos, initialIndex: i),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: height * 0.8,
                  height: height,
                  child: Image.file(photos[i], fit: BoxFit.cover),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A round x in the corner of a photo or video.
class _Removable extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;
  const _Removable({required this.child, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 8,
          right: 8,
          child: ViewerRoundButton(
            size: 30,
            icon: Icons.close_rounded,
            tooltip: context.l10n.commonRemove,
            onTap: onRemove,
          ),
        ),
      ],
    );
  }
}

/// Icon button in the composer's bottom bar.
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      iconSize: 24,
      color: active ? AppColors.primary : AppColors.muted,
      icon: Icon(icon),
    );
  }
}

/// "Quick post ▾": picks the post type.
class _TypeSelector extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TypeSelector({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Icon(Icons.arrow_drop_down_rounded,
                  color: AppColors.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// A chosen tag under the text, with an x to drop it.
class _TagChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _TagChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            customBorder: const CircleBorder(),
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(2),
              child:
                  Icon(Icons.close_rounded, size: 16, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

void _chooseMediaType(
  BuildContext context, {
  required VoidCallback onPhoto,
  required VoidCallback onVideo,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(context.l10n.createTakePhoto),
                onTap: () {
                  Navigator.pop(ctx);
                  onPhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: Text(context.l10n.createRecordVideo),
                onTap: () {
                  Navigator.pop(ctx);
                  onVideo();
                },
              ),
            ],
          ),
        ),
      );
    },
  );
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
            Text(
              context.l10n.createTags,
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
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Text(
                    context.l10n.commonClear,
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
                  hintText: context.l10n.createTagHint,
                  hintStyle: const TextStyle(
                      color: AppColors.muted, fontWeight: FontWeight.w600),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.4),
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
                    side:
                        BorderSide(color: AppColors.primary.withOpacity(0.25)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: Text(context.l10n.createAdd,
                    style: TextStyle(fontWeight: FontWeight.w900)),
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
                        shape: const StadiumBorder(
                            side: BorderSide(color: AppColors.border)),
                        deleteIcon: const Icon(Icons.close,
                            size: 18, color: AppColors.muted),
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
  final bool readOnly;

  const _QuickEditor({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.readOnly,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(
        fontSize: 18,
        height: 1.35,
        color: AppColors.text,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: context.l10n.createQuickHint,
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
  final bool readOnly;

  const _TemplateEditor({
    required this.template,
    required this.a1,
    required this.a2,
    required this.a3,
    required this.a1Focus,
    required this.a2Focus,
    required this.a3Focus,
    required this.onChanged,
    required this.readOnly,
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
              readOnly: readOnly,
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
    final leadingBg =
        selected ? AppColors.primary.withOpacity(0.10) : AppColors.button;
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
                child: Icon(selected ? Icons.check_rounded : icon,
                    color: leadingFg),
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
                selected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
