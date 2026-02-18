import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:connect_app/utils/time_utils.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:connect_app/widgets/full_screen_back_gesture.dart';

class PostDetailScreen extends StatelessWidget {
  final String postId;
  const PostDetailScreen({Key? key, required this.postId}) : super(key: key);

  (String?, String) _extractBadgeAndBody(String raw) {
    final lines = raw.split('\n');
    int idx = 0;
    while (idx < lines.length && lines[idx].trim().isEmpty) idx++;
    if (idx >= lines.length) return (null, raw);

    final first = lines[idx].trim();
    final reg = RegExp(r'^\*\*(.+?)\*\*$');
    final m = reg.firstMatch(first);
    if (m != null && m.group(1) != null) {
      final label = m.group(1)!.trim();
      if (label.toLowerCase().endsWith(' post')) {
        final rest = [...lines]..removeAt(idx);
        if (idx < rest.length && rest[idx].trim().isEmpty) {
          rest.removeAt(idx);
        }
        return (label, rest.join('\n').trimLeft());
      }
    }
    return (null, raw);
  }

  TextSpan _parseSimpleMarkdownToSpan(
    String text, {
    required TextStyle base,
    required TextStyle strong,
  }) {
    final spans = <TextSpan>[];
    int i = 0;
    while (i < text.length) {
      final start = text.indexOf('**', i);
      if (start == -1) {
        spans.add(TextSpan(text: text.substring(i), style: base));
        break;
      }
      if (start > i) {
        spans.add(TextSpan(text: text.substring(i, start), style: base));
      }
      final end = text.indexOf('**', start + 2);
      if (end == -1) {
        spans.add(TextSpan(text: text.substring(start), style: base));
        break;
      }
      spans.add(TextSpan(text: text.substring(start + 2, end), style: strong));
      i = end + 2;
    }
    return TextSpan(children: spans, style: base);
  }

  Widget _postTypeBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  List<String> _extractImageUrls(Map<String, dynamic> data) {
    final v = data['imageUrls'];
    if (v is List) {
      return v
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final single = (data['imageUrl'] ?? '').toString().trim();
    if (single.isNotEmpty) return [single];
    return [];
  }

  String _extractVideoUrl(Map<String, dynamic> data) {
    return (data['videoUrl'] ?? '').toString().trim();
  }

  String _extractVideoThumbUrl(Map<String, dynamic> data) {
    return (data['videoThumbUrl'] ?? '').toString().trim();
  }

  double _extractMediaAspect(Map<String, dynamic> data,
      {required bool hasMedia}) {
    final raw = data['mediaAspectRatio'];
    if (raw is num && raw > 0) return raw.toDouble();
    return hasMedia ? (16 / 9) : 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final double minCardHeight = screenH * 0.30 < 220 ? 220 : screenH * 0.30;

    return FullScreenBackGesture(
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          backgroundColor: AppColors.canvas,
          elevation: 0,
          title: const Text('Post Detail'),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .doc(postId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('Post not found.'));
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final dt = parseFirestoreTimestamp(data['timestamp']);
            final date = dt != null
                ? DateFormat.yMMMd().add_jm().format(dt)
                : 'Unknown date';
            final content = (data['content'] ?? '').toString();
            final (maybeBadge, body) = _extractBadgeAndBody(content);
            final badge = maybeBadge ?? 'Quick Post';

            final base = const TextStyle(
                fontSize: 16, height: 1.4, color: AppColors.text);
            final strong = const TextStyle(
              fontSize: 16,
              height: 1.4,
              color: AppColors.text,
              fontWeight: FontWeight.w700,
            );
            final span =
                _parseSimpleMarkdownToSpan(body, base: base, strong: strong);
            final imageUrls = _extractImageUrls(data);
            final videoUrl = _extractVideoUrl(data);
            final videoThumbUrl = _extractVideoThumbUrl(data);
            final hasMedia = imageUrls.isNotEmpty || videoUrl.isNotEmpty;
            final mediaAspect = _extractMediaAspect(data, hasMedia: hasMedia);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minCardHeight),
                child: SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: const Border.fromBorderSide(
                          BorderSide(color: AppColors.border)),
                      boxShadow: const [AppShadows.soft],
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 56),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                (data['userName'] ?? 'Anonymous').toString(),
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              if (imageUrls.isNotEmpty) ...[
                                _DetailMediaCarousel(
                                  urls: imageUrls,
                                  aspect: mediaAspect,
                                ),
                                const SizedBox(height: 12),
                              ] else if (videoUrl.isNotEmpty) ...[
                                _DetailVideoPlayer(
                                  url: videoUrl,
                                  thumbUrl: videoThumbUrl,
                                  aspect: mediaAspect,
                                ),
                                const SizedBox(height: 12),
                              ],
                              _postTypeBadge(badge),
                              const SizedBox(height: 8),
                              RichText(text: span),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: Text(
                            'Posted on $date',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DetailMediaCarousel extends StatefulWidget {
  final List<String> urls;
  final double aspect;
  const _DetailMediaCarousel({
    required this.urls,
    required this.aspect,
  });

  @override
  State<_DetailMediaCarousel> createState() => _DetailMediaCarouselState();
}

class _DetailMediaCarouselState extends State<_DetailMediaCarousel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.urls.length == 1) {
      return _DetailMediaImage(
        url: widget.urls.first,
        aspect: widget.aspect,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: widget.aspect,
            child: PageView.builder(
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => Image.network(
                widget.urls[i],
                fit: BoxFit.cover,
                loadingBuilder: (c, w, p) =>
                    p == null ? w : Container(color: AppColors.button),
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.button,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image, color: AppColors.muted),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.urls.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 14 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(active ? 0.55 : 0.25),
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailMediaImage extends StatelessWidget {
  final String url;
  final double aspect;

  const _DetailMediaImage({
    required this.url,
    required this.aspect,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: aspect,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (c, w, p) =>
              p == null ? w : Container(color: AppColors.button),
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.button,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image, color: AppColors.muted),
          ),
        ),
      ),
    );
  }
}

class _DetailVideoPlayer extends StatefulWidget {
  final String url;
  final String thumbUrl;
  final double aspect;

  const _DetailVideoPlayer({
    required this.url,
    required this.thumbUrl,
    required this.aspect,
  });

  @override
  State<_DetailVideoPlayer> createState() => _DetailVideoPlayerState();
}

class _DetailVideoPlayerState extends State<_DetailVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _failed = false;
  bool _playing = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setVolume(0.0);
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      await _controller.initialize();
      if (!mounted) return;
      setState(() {
        _ready = true;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (!_ready) return;
    if (_controller.value.isPlaying) {
      await _controller.pause();
      if (mounted) setState(() => _playing = false);
    } else {
      await _controller.play();
      if (mounted) setState(() => _playing = true);
    }
  }

  Future<void> _toggleMute() async {
    if (!_ready) return;
    final next = !_muted;
    await _controller.setVolume(next ? 0.0 : 1.0);
    if (mounted) {
      setState(() => _muted = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallbackAspect = widget.aspect > 0 ? widget.aspect : (16 / 9);
    final aspect = _ready && _controller.value.isInitialized
        ? _controller.value.aspectRatio
        : fallbackAspect;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: (aspect.isFinite && aspect > 0) ? aspect : fallbackAspect,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_ready)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              )
            else if (_failed)
              Container(
                color: AppColors.button,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.videocam_off_outlined,
                  color: AppColors.muted,
                  size: 30,
                ),
              )
            else if (widget.thumbUrl.isNotEmpty)
              Image.network(
                widget.thumbUrl,
                fit: BoxFit.cover,
              )
            else
              Container(color: AppColors.button),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggle,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _playing ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: GestureDetector(
                onTap: _toggleMute,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(
                    _muted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 16,
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
