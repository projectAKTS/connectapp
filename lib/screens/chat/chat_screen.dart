// lib/screens/chat/chat_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';

import '../../theme/tokens.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String? otherUserName;   // 👈 optional again
  final String? otherUserAvatar;

  const ChatScreen({
    Key? key,
    required this.otherUserId,
    this.otherUserName,
    this.otherUserAvatar,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final String _me;
  late final String _chatId;

  late final Future<void> _ready;

  final _inputCtrl = TextEditingController();
  final _picker = ImagePicker();
  bool _sending = false;

  String? _titleName; // 👈 resolved name for AppBar

  @override
  void initState() {
    super.initState();
    _me = FirebaseAuth.instance.currentUser!.uid;
    final ids = [_me, widget.otherUserId]..sort();
    _chatId = ids.join('_');
    _ready = _ensureChatDoc();
    _resolveTitleName();
  }

  Future<void> _ensureChatDoc() async {
    final ref = FirebaseFirestore.instance.collection('chats').doc(_chatId);
    await ref.set({
      'users': FieldValue.arrayUnion([_me, widget.otherUserId]),
      'participants': FieldValue.arrayUnion([_me, widget.otherUserId]),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Load name if not provided
  Future<void> _resolveTitleName() async {
    final passed = widget.otherUserName?.trim();
    if (passed != null && passed.isNotEmpty) {
      _titleName = passed;
      setState(() {});
      return;
    }
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(widget.otherUserId).get();
      final d = snap.data();
      final name = (d?['displayName'] ??
              d?['fullName'] ??
              d?['name'] ??
              d?['userName'] ??
              '')
          .toString()
          .trim();
      if (mounted) setState(() => _titleName = name.isEmpty ? null : name);
    } catch (_) {
      // ignore; fall back to 'Chat'
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  List<types.Message> _toMessages(QuerySnapshot snap) {
    return snap.docs.map((d) {
      final m = d.data() as Map<String, dynamic>;
      final authorId = (m['authorId'] ?? '') as String;
      final ts = (m['createdAt'] as Timestamp?)?.millisecondsSinceEpoch;
      final createdAt = ts ?? DateTime.now().millisecondsSinceEpoch;
      final author = types.User(id: authorId);

      switch (m['type']) {
        case 'image':
          return types.ImageMessage(
            id: d.id,
            author: author,
            createdAt: createdAt,
            name: (m['name'] ?? 'image') as String,
            size: (m['size'] ?? 0) as int,
            uri: (m['uri'] ?? '') as String,
          );
        case 'video':
          return types.CustomMessage(
            id: d.id,
            author: author,
            createdAt: createdAt,
            metadata: {
              'uri': (m['uri'] ?? '') as String,
              'name': (m['name'] ?? 'video') as String,
              'mime': (m['mime'] ?? 'video/mp4') as String,
            },
          );
        case 'file':
          return types.FileMessage(
            id: d.id,
            author: author,
            createdAt: createdAt,
            name: (m['name'] ?? 'file') as String,
            size: (m['size'] ?? 0) as int,
            uri: (m['uri'] ?? '') as String,
            mimeType: (m['mime'] ?? '') as String,
          );
        default:
          return types.TextMessage(
            id: d.id,
            author: author,
            createdAt: createdAt,
            text: (m['text'] ?? '') as String,
          );
      }
    }).toList();
  }

  Future<void> _sendText(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    _inputCtrl.clear();

    await _ready;

    final now = Timestamp.now();
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(_chatId);

    await chatRef.collection('messages').add({
      'authorId': _me,
      'createdAt': now,
      'type': 'text',
      'text': t,
    });

    await chatRef.set({'updatedAt': now}, SetOptions(merge: true));
  }

  Future<void> _pickAttachment() async {
    if (_sending) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Photo'),
              onTap: () => Navigator.pop(context, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Video'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    try {
      if (action == 'photo') {
        final x = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 92,
          maxWidth: 2000,
        );
        if (x != null) await _uploadAndSend(x, isImage: true);
      } else if (action == 'video') {
        final x = await _picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 3),
        );
        if (x != null) await _uploadAndSend(x, isImage: false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t attach file: $e')),
      );
    }
  }

  Future<void> _uploadAndSend(XFile x, {required bool isImage}) async {
    await _ready;
    setState(() => _sending = true);
    try {
      final bytes = await x.readAsBytes();
      final name = p.basename(x.path);
      final mime =
          lookupMimeType(name, headerBytes: bytes) ?? (isImage ? 'image/jpeg' : 'video/mp4');

      final folder = isImage ? 'images' : 'videos';
      final ref = FirebaseStorage.instance
          .ref()
          .child('chats/$_chatId/$folder/${DateTime.now().millisecondsSinceEpoch}_$name');

      final task = await ref.putData(
        bytes,
        SettableMetadata(contentType: mime),
      );

      final url = await task.ref.getDownloadURL();

      final chatRef = FirebaseFirestore.instance.collection('chats').doc(_chatId);
      await chatRef.collection('messages').add({
        'authorId': _me,
        'createdAt': Timestamp.now(),
        'type': isImage ? 'image' : 'video',
        'uri': url,
        'name': name,
        'size': bytes.length,
        'mime': mime,
      });
      await chatRef.set({'updatedAt': Timestamp.now()}, SetOptions(merge: true));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openUri(String uri) async {
    final u = Uri.parse(uri);
    if (await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    const _chatTheme = DefaultChatTheme(
      backgroundColor: AppColors.canvas,
      primaryColor: AppColors.button,
      secondaryColor: AppColors.button,
      messageBorderRadius: 16,
      sentMessageBodyTextStyle: TextStyle(color: AppColors.text, fontSize: 16, height: 1.35),
      receivedMessageBodyTextStyle: TextStyle(color: AppColors.text, fontSize: 16, height: 1.35),
      inputBackgroundColor: AppColors.button,
      inputTextColor: AppColors.text,
      inputTextStyle: TextStyle(color: AppColors.text, fontSize: 16),
    );

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.avatarBg,
              foregroundImage: (widget.otherUserAvatar?.isNotEmpty ?? false)
                  ? NetworkImage(widget.otherUserAvatar!)
                  : null,
              child: const Icon(Icons.person_outline, color: AppColors.avatarFg, size: 18),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                _titleName?.isNotEmpty == true ? _titleName! : 'Chat',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder<void>(
        future: _ready,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .doc(_chatId)
                .collection('messages')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              final msgs = snap.hasData ? _toMessages(snap.data!) : const <types.Message>[];

              return Chat(
                messages: msgs,
                onSendPressed: (_) {},
                user: types.User(id: _me),
                theme: _chatTheme,

                onMessageTap: (ctx, msg) async {
                  if (msg is types.FileMessage) await _openUri(msg.uri);
                },

                customBottomWidget: _Composer(
                  controller: _inputCtrl,
                  sending: _sending,
                  onAttach: _pickAttachment,
                  onSend: _sendText,
                ),

                // Inline renderer for video messages
                customMessageBuilder: (message, {required int messageWidth}) {
                  if (message is types.CustomMessage) {
                    final meta = message.metadata ?? {};
                    final uri = (meta['uri'] ?? '') as String;
                    final mime = (meta['mime'] ?? 'video/mp4') as String;
                    if (uri.isNotEmpty && mime.startsWith('video/')) {
                      return _VideoBubble(uri: uri, maxWidth: messageWidth);
                    }
                  }
                  return const SizedBox.shrink();
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onAttach;
  final ValueChanged<String> onSend;

  const _Composer({
    required this.controller,
    required this.sending,
    required this.onAttach,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Row(
        children: [
          InkWell(
            onTap: sending ? null : onAttach,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.button,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.add, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.button,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 46, maxHeight: 140),
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    hintText: 'Message',
                    hintStyle: TextStyle(color: AppColors.muted),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: sending
                ? null
                : () {
                    final t = controller.text.trim();
                    if (t.isNotEmpty) onSend(t);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(52, 46),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Icon(Icons.send_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

/// ===== Fixed & polished inline video bubble ================================
class _VideoBubble extends StatefulWidget {
  final String uri;
  final int maxWidth;
  const _VideoBubble({required this.uri, required this.maxWidth});

  @override
  State<_VideoBubble> createState() => _VideoBubbleState();
}

class _VideoBubbleState extends State<_VideoBubble> {
  late final VideoPlayerController _video;
  ChewieController? _chewie;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _video = VideoPlayerController.networkUrl(Uri.parse(widget.uri));
    _video.initialize().then((_) {
      if (!mounted) return;
      _video.setVolume(1.0);
      _chewie = ChewieController(
        videoPlayerController: _video,
        autoPlay: false,
        looping: false,
        showControls: false, // we draw chrome ourselves
        allowFullScreen: true,
        allowMuting: true,
      );
      setState(() {});
    });
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (!_video.value.isInitialized) return;
    _video.value.isPlaying ? _video.pause() : _video.play();
    setState(() {});
  }

  void _toggleMute() {
    _muted = !_muted;
    _video.setVolume(_muted ? 0.0 : 1.0);
    setState(() {});
  }

  void _openFullscreen() {
    if (!_video.value.isInitialized) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenVideoPage(initialUrl: widget.uri),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final aspect = _video.value.isInitialized ? _video.value.aspectRatio : (16 / 9);

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: widget.maxWidth.toDouble(),
          maxHeight: 380,
        ),
        color: Colors.black,
        child: !_video.value.isInitialized || _chewie == null
            ? AspectRatio(
                aspectRatio: aspect,
                child: const Center(child: CircularProgressIndicator()),
              )
            : Stack(
                children: [
                  // 1) The video
                  AspectRatio(aspectRatio: aspect, child: Chewie(controller: _chewie!)),

                  // 2) Full-surface tap layer (UNDER the corner buttons)
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(onTap: _togglePlay),
                    ),
                  ),

                  // 3) Center play button (only when paused) – tappable
                  if (!_video.value.isPlaying)
                    Positioned.fill(
                      child: Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _togglePlay,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                          ),
                        ),
                      ),
                    ),

                  // 4) Top-left: fullscreen
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _ChromeIconButton(
                      icon: Icons.fullscreen,
                      onPressed: _openFullscreen,
                    ),
                  ),

                  // 5) Top-right: mute
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _ChromeIconButton(
                      icon: _muted ? Icons.volume_off : Icons.volume_up,
                      onPressed: _toggleMute,
                    ),
                  ),

                  // 6) Bottom progress
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.45), Colors.transparent],
                        ),
                      ),
                      child: VideoProgressIndicator(
                        _video,
                        allowScrubbing: true,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        colors: const VideoProgressColors(
                          playedColor: AppColors.primary,
                          bufferedColor: Colors.white70,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Fullscreen player route
class _FullscreenVideoPage extends StatefulWidget {
  final String initialUrl;
  const _FullscreenVideoPage({required this.initialUrl});

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  late final VideoPlayerController _controller;
  ChewieController? _chewie;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.initialUrl));
    _controller.initialize().then((_) {
      if (!mounted) return;
      _chewie = ChewieController(
        videoPlayerController: _controller,
        autoPlay: true,
        looping: false,
        showControls: true,
        allowMuting: true,
        allowFullScreen: false, // already full screen via route
      );
      setState(() {});
    });
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aspect = _controller.value.isInitialized ? _controller.value.aspectRatio : 16 / 9;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: _chewie == null
                  ? const CircularProgressIndicator()
                  : AspectRatio(aspectRatio: aspect, child: Chewie(controller: _chewie!)),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: _ChromeIconButton(
                icon: Icons.close,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small rounded icon button (white icon on dark pill)
class _ChromeIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _ChromeIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
