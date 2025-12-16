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

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  late final VideoPlayerController _controller;
  ChewieController? _chewie;

  @override
  void initState() {
    super.initState();

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
    _chewie?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: _chewie == null
            ? const CircularProgressIndicator(color: Colors.white)
            : Chewie(controller: _chewie!),
      ),
    );
  }
}
