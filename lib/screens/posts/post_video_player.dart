import 'dart:io';
import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';

class PostVideoPlayer extends StatefulWidget {
  final String? url; // ✅ for Home
  final File? file;  // ✅ for Create preview

  const PostVideoPlayer({
    super.key,
    this.url,
    this.file,
  }) : assert(url != null || file != null, 'Provide either url or file');

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer>
    with SingleTickerProviderStateMixin {
  late final VideoPlayerController _controller;
  ChewieController? _chewie;
  late final AnimationController _resetController;
  Animation<double>? _resetAnim;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(() {
        setState(() {
          _dragOffset = _resetAnim?.value ?? 0;
        });
      });

    _controller = widget.file != null
        ? VideoPlayerController.file(widget.file!)
        : VideoPlayerController.networkUrl(Uri.parse(widget.url!));

    _controller.initialize().then((_) {
      _chewie = ChewieController(
        videoPlayerController: _controller,
        autoPlay: true,
        looping: false,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        showControls: true,
      );
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _resetController.dispose();
    _chewie?.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _animateBack() {
    _resetController.stop();
    _resetAnim = Tween<double>(begin: _dragOffset, end: 0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    );
    _resetController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final dragAbs = _dragOffset.abs();
    final bgOpacity = (1 - (dragAbs / 320)).clamp(0.0, 1.0);
    final scale = (1 - (dragAbs / 1200)).clamp(0.9, 1.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(bgOpacity),
        foregroundColor: Colors.white,
      ),
      body: GestureDetector(
        onVerticalDragStart: (_) => _resetController.stop(),
        onVerticalDragUpdate: (details) {
          setState(() {
            _dragOffset += details.delta.dy;
          });
        },
        onVerticalDragEnd: (details) {
          final velocity = details.velocity.pixelsPerSecond.dy.abs();
          if (_dragOffset.abs() > 140 || velocity > 900) {
            Navigator.of(context).maybePop();
            return;
          }
          _animateBack();
        },
        child: Container(
          color: Colors.black.withOpacity(bgOpacity),
          child: Center(
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: Transform.scale(
                scale: scale,
                child: _chewie == null
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Chewie(controller: _chewie!),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
