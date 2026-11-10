import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/screens/posts/post_image_viewer.dart';

/// Opens [PostVideoPlayer] over the current screen with a fade.
Future<void> openVideoPlayer(
  BuildContext context, {
  String? url,
  File? file,
  VideoPlayerController? controller,
}) {
  // Root navigator: full screen above the tab bar.
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) =>
          PostVideoPlayer(url: url, file: file, controller: controller),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// Full-screen video with its own controls. Given a [controller] (the one
/// already playing in the feed) it carries on from there and leaves it
/// running for the feed; otherwise it opens [url] or [file] itself.
class PostVideoPlayer extends StatefulWidget {
  final String? url;
  final File? file;
  final VideoPlayerController? controller;

  const PostVideoPlayer({super.key, this.url, this.file, this.controller})
      : assert(url != null || file != null || controller != null,
            'Provide url, file or controller');

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer>
    with SingleTickerProviderStateMixin {
  late final VideoPlayerController _video;
  late final bool _owns;
  bool _failed = false;
  bool _chrome = true;
  Timer? _hide;
  late final AnimationController _reset;
  Animation<double>? _resetAnim;
  double _drag = 0;

  @override
  void initState() {
    super.initState();
    _reset = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(() => setState(() => _drag = _resetAnim?.value ?? 0));
    _owns = widget.controller == null;
    _video = widget.controller ??
        (widget.file != null
            ? VideoPlayerController.file(widget.file!)
            : VideoPlayerController.networkUrl(Uri.parse(widget.url!)));
    if (_video.value.isInitialized) {
      _video.play();
      _scheduleHide();
    } else {
      _video.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _video.play();
        _scheduleHide();
      }).catchError((_) {
        if (mounted) setState(() => _failed = true);
      });
    }
  }

  @override
  void dispose() {
    _hide?.cancel();
    _reset.dispose();
    if (_owns) _video.dispose();
    super.dispose();
  }

  void _scheduleHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted && _video.value.isPlaying) setState(() => _chrome = false);
    });
  }

  void _togglePlay() {
    final v = _video.value;
    if (v.isPlaying) {
      _video.pause();
      _hide?.cancel();
    } else {
      if (v.duration > Duration.zero && v.position >= v.duration) {
        _video.seekTo(Duration.zero);
      }
      _video.play();
      _scheduleHide();
    }
    setState(() => _chrome = true);
  }

  void _toggleChrome() {
    setState(() => _chrome = !_chrome);
    if (_chrome) _scheduleHide();
  }

  void _snapBack() {
    _resetAnim = Tween<double>(begin: _drag, end: 0).animate(
      CurvedAnimation(parent: _reset, curve: Curves.easeOutCubic),
    );
    _reset.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final fade = (1 - _drag.abs() / 320).clamp(0.0, 1.0);
    final scale = (1 - _drag.abs() / 1200).clamp(0.9, 1.0);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: fade),
      body: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: _video,
        builder: (context, v, _) {
          final ended = v.duration > Duration.zero && v.position >= v.duration;
          final showChrome = (_chrome || !v.isPlaying) && _drag == 0;
          return Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleChrome,
                onVerticalDragStart: (_) => _reset.stop(),
                onVerticalDragUpdate: (d) =>
                    setState(() => _drag += d.delta.dy),
                onVerticalDragEnd: (d) {
                  if (_drag.abs() > 120 ||
                      d.velocity.pixelsPerSecond.dy.abs() > 900) {
                    Navigator.of(context).maybePop();
                  } else {
                    _snapBack();
                  }
                },
                child: Transform.translate(
                  offset: Offset(0, _drag),
                  child: Transform.scale(
                    scale: scale,
                    child: Center(
                      child: _failed
                          ? const Icon(Icons.videocam_off_outlined,
                              color: Colors.white54, size: 40)
                          : v.isInitialized
                              ? AspectRatio(
                                  aspectRatio: v.aspectRatio,
                                  child: VideoPlayer(_video),
                                )
                              : const CircularProgressIndicator(
                                  color: Colors.white),
                    ),
                  ),
                ),
              ),
              if (v.isInitialized && v.isBuffering && v.isPlaying)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              IgnorePointer(
                ignoring: !showChrome,
                child: AnimatedOpacity(
                  opacity: showChrome ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Stack(
                    children: [
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                          child: Row(
                            children: [
                              ViewerRoundButton(
                                icon: Icons.close_rounded,
                                tooltip: context.l10n.mediaClose,
                                onTap: () => Navigator.of(context).maybePop(),
                              ),
                              const Spacer(),
                              ViewerRoundButton(
                                icon: v.volume == 0
                                    ? Icons.volume_off_rounded
                                    : Icons.volume_up_rounded,
                                tooltip: v.volume == 0
                                    ? context.l10n.mediaUnmute
                                    : context.l10n.mediaMute,
                                onTap: () {
                                  _video.setVolume(v.volume == 0 ? 1 : 0);
                                  _scheduleHide();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (v.isInitialized)
                        Center(
                          child: ViewerRoundButton(
                            size: 68,
                            icon: ended
                                ? Icons.replay_rounded
                                : v.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                            tooltip: v.isPlaying
                                ? context.l10n.mediaPause
                                : context.l10n.mediaPlay,
                            onTap: _togglePlay,
                          ),
                        ),
                      if (v.isInitialized)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: VideoScrubBar(controller: _video),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Seek bar with elapsed and total time.
class VideoScrubBar extends StatelessWidget {
  final VideoPlayerController controller;
  final bool compact;
  const VideoScrubBar(
      {super.key, required this.controller, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final v = controller.value;
    const time = TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      fontFeatures: [FontFeature.tabularFigures()],
      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
    );
    final bar = VideoProgressIndicator(
      controller,
      allowScrubbing: !compact,
      // The padding is part of the touch area, so the thin bar is easy to drag.
      padding:
          compact ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 12),
      colors: VideoProgressColors(
        playedColor: Colors.white,
        bufferedColor: Colors.white.withValues(alpha: 0.4),
        backgroundColor: Colors.white.withValues(alpha: 0.2),
      ),
    );
    if (compact) return SizedBox(height: 3, child: bar);
    return Row(
      children: [
        Text(formatMediaDuration(v.position), style: time),
        const SizedBox(width: 10),
        Expanded(child: bar),
        const SizedBox(width: 10),
        Text(formatMediaDuration(v.duration), style: time),
      ],
    );
  }
}
