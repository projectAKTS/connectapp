import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/screens/posts/post_image_viewer.dart';
import 'package:connect_app/screens/posts/post_video_player.dart';
import 'package:connect_app/theme/tokens.dart';

/// Box shape for post media: the photo's own shape, kept between 4:5
/// (portrait) and 1.91:1 (landscape) so one post never fills the screen.
double postMediaAspect(Object? stored) {
  final v = stored is num && stored > 0 ? stored.toDouble() : 16 / 9;
  return v.clamp(0.8, 1.91);
}

/// Photos as a swipeable carousel; a tap opens them full screen.
class PostPhotos extends StatefulWidget {
  final List<String> urls;
  final double aspect;
  const PostPhotos({super.key, required this.urls, required this.aspect});

  @override
  State<PostPhotos> createState() => _PostPhotosState();
}

class _PostPhotosState extends State<PostPhotos> {
  int _index = 0;
  int? _decodeWidth;

  /// Decoded at the size shown, not the 1600px upload: decoding full
  /// photos while swiping is what made the carousel stutter.
  ImageProvider _provider(int i) => ResizeImage.resizeIfNeeded(
      _decodeWidth, null, NetworkImage(widget.urls[i]));

  void _warm(int width) {
    if (_decodeWidth == width) return;
    _decodeWidth = width;
    // Load every photo now so each swipe lands on a ready picture.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (var i = 0; i < widget.urls.length; i++) {
        precacheImage(_provider(i), context, onError: (_, __) {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    Widget photo(int i) => GestureDetector(
          onTap: () => openImageViewer(context, urls: urls, initialIndex: i),
          child: Image(
            image: _provider(i),
            fit: BoxFit.cover,
            width: double.infinity,
            gaplessPlayback: true,
            loadingBuilder: (c, w, p) =>
                p == null ? w : const ColoredBox(color: AppColors.button),
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: AppColors.button,
              child: Center(
                child:
                    Icon(Icons.broken_image_outlined, color: AppColors.muted),
              ),
            ),
          ),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: widget.aspect,
        child: LayoutBuilder(builder: (context, box) {
          final dpr = MediaQuery.devicePixelRatioOf(context);
          _warm((box.maxWidth * dpr).round());
          if (urls.length == 1) return photo(0);
          return Stack(
            children: [
              PageView.builder(
                itemCount: urls.length,
                // Builds the next photo ahead of the swipe.
                allowImplicitScrolling: true,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => photo(i),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: ViewerPill(
                  text: context.l10n.mediaCounter(_index + 1, urls.length),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                child: IgnorePointer(
                  child:
                      PageDots(count: urls.length, index: _index, light: true),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// The one feed video playing now; starting another pauses it.
final ValueNotifier<Object?> _playingInFeed = ValueNotifier(null);

/// A video that plays inside the post on tap, with mute and full screen.
/// Nothing downloads until the reader taps play.
class PostVideo extends StatefulWidget {
  final String url;
  final String thumbUrl;
  final double aspect;
  final Duration? duration;

  const PostVideo({
    super.key,
    required this.url,
    required this.thumbUrl,
    required this.aspect,
    this.duration,
  });

  @override
  State<PostVideo> createState() => _PostVideoState();
}

class _PostVideoState extends State<PostVideo> {
  VideoPlayerController? _video;
  bool _loading = false;
  bool _failed = false;
  final _token = Object();
  List<ScrollPosition> _scrolls = const [];

  @override
  void initState() {
    super.initState();
    _playingInFeed.addListener(_onOtherStarted);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // TickerMode turns off when another screen or tab covers this one.
    if (!TickerMode.of(context)) _video?.pause();
    // The feed nests a non-scrolling list in the page scroll: watch all.
    final scrolls = <ScrollPosition>[];
    for (var s = Scrollable.maybeOf(context);
        s != null;
        s = Scrollable.maybeOf(s.context)) {
      scrolls.add(s.position);
    }
    for (final p in _scrolls) {
      p.removeListener(_pauseWhenScrolledAway);
    }
    _scrolls = scrolls;
    for (final p in _scrolls) {
      p.addListener(_pauseWhenScrolledAway);
    }
  }

  /// The feed builds every card at once, so a video scrolled out of sight
  /// is never disposed; pause it instead.
  void _pauseWhenScrolledAway() {
    final c = _video;
    if (c == null || !c.value.isPlaying || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final screen = MediaQuery.sizeOf(context).height;
    final visible =
        (top + box.size.height).clamp(0.0, screen) - top.clamp(0.0, screen);
    if (visible < box.size.height * 0.3) c.pause();
  }

  @override
  void dispose() {
    _playingInFeed.removeListener(_onOtherStarted);
    for (final p in _scrolls) {
      p.removeListener(_pauseWhenScrolledAway);
    }
    if (_playingInFeed.value == _token) _playingInFeed.value = null;
    _video?.dispose();
    super.dispose();
  }

  void _onOtherStarted() {
    if (_playingInFeed.value != _token) _video?.pause();
  }

  Future<void> _start() async {
    _playingInFeed.value = _token;
    final existing = _video;
    if (existing != null) {
      final v = existing.value;
      if (v.duration > Duration.zero && v.position >= v.duration) {
        await existing.seekTo(Duration.zero);
      }
      await existing.play();
      return;
    }
    setState(() => _loading = true);
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() {
        _video = c;
        _loading = false;
      });
      if (_playingInFeed.value == _token) await c.play();
    } catch (_) {
      c.dispose();
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  void _openFullScreen() {
    final c = _video;
    if (c == null) {
      openVideoPlayer(context, url: widget.url);
      return;
    }
    _playingInFeed.value = _token;
    openVideoPlayer(context, controller: c);
  }

  @override
  Widget build(BuildContext context) {
    final c = _video;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: widget.aspect,
        child: ColoredBox(
          color: Colors.black,
          child: c == null
              ? _poster(context)
              : ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: c,
                  builder: (context, v, _) => _playing(context, c, v),
                ),
        ),
      ),
    );
  }

  Widget _poster(BuildContext context) {
    return GestureDetector(
      onTap: _failed ? _openFullScreen : _start,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.thumbUrl.isNotEmpty)
            Image.network(
              widget.thumbUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          Center(
            child: _loading
                ? const CircularProgressIndicator(color: Colors.white)
                : Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.8), width: 2),
                    ),
                    child: Icon(
                      _failed
                          ? Icons.videocam_off_outlined
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                      semanticLabel: context.l10n.mediaPlay,
                    ),
                  ),
          ),
          if (widget.duration != null && widget.duration! > Duration.zero)
            Positioned(
              right: 10,
              bottom: 10,
              child: ViewerPill(
                icon: Icons.videocam_rounded,
                text: formatMediaDuration(widget.duration!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _playing(
      BuildContext context, VideoPlayerController c, VideoPlayerValue v) {
    final ended = v.duration > Duration.zero && v.position >= v.duration;
    final left = v.duration - v.position;
    return GestureDetector(
      onTap: () => v.isPlaying ? c.pause() : _start(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fill the post's box like the photo did; full screen shows it all.
          ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: v.size.width > 0 ? v.size.width : 16,
                height: v.size.height > 0 ? v.size.height : 9,
                child: VideoPlayer(c),
              ),
            ),
          ),
          if (!v.isPlaying)
            Center(
              child: ViewerRoundButton(
                size: 60,
                icon: ended ? Icons.replay_rounded : Icons.play_arrow_rounded,
                tooltip: context.l10n.mediaPlay,
                onTap: _start,
              ),
            )
          else if (v.isBuffering)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          Positioned(
            left: 10,
            bottom: 12,
            child: ViewerPill(
                text: formatMediaDuration(
                    left.isNegative ? Duration.zero : left)),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Row(
              children: [
                ViewerRoundButton(
                  size: 34,
                  icon: v.volume == 0
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  tooltip: v.volume == 0
                      ? context.l10n.mediaUnmute
                      : context.l10n.mediaMute,
                  onTap: () => c.setVolume(v.volume == 0 ? 1 : 0),
                ),
                const SizedBox(width: 6),
                ViewerRoundButton(
                  size: 34,
                  icon: Icons.fullscreen_rounded,
                  tooltip: context.l10n.mediaFullScreen,
                  onTap: _openFullScreen,
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoScrubBar(controller: c, compact: true),
          ),
        ],
      ),
    );
  }
}

/// Grey box shown while the author's photos or video are still uploading,
/// or, to the author, when the upload failed.
class PostMediaPending extends StatelessWidget {
  final double aspect;
  final bool failed;
  const PostMediaPending(
      {super.key, required this.aspect, required this.failed});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: aspect,
        child: ColoredBox(
          color: AppColors.button,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                failed
                    ? const Icon(Icons.error_outline_rounded,
                        color: AppColors.muted, size: 28)
                    : const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                const SizedBox(height: 10),
                Text(
                  failed
                      ? context.l10n.postMediaFailed
                      : context.l10n.postMediaUploading,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
