// lib/screens/posts/post_video_player.dart
import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';

class PostVideoPlayer extends StatefulWidget {
  final String url;
  const PostVideoPlayer({super.key, required this.url});

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  late final VideoPlayerController _controller;
  ChewieController? _chewie;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        _chewie = ChewieController(
          videoPlayerController: _controller,
          autoPlay: true,
          looping: false,
          allowMuting: true,
          allowPlaybackSpeedChanging: true,
          showControls: true,
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
