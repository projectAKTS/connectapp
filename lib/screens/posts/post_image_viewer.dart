import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class PostImageViewer extends StatefulWidget {
  final String? url; // ✅ for Home
  final File? file;  // ✅ for Create preview

  const PostImageViewer({
    super.key,
    this.url,
    this.file,
  }) : assert(url != null || file != null, 'Provide either url or file');

  @override
  State<PostImageViewer> createState() => _PostImageViewerState();
}

class _PostImageViewerState extends State<PostImageViewer>
    with SingleTickerProviderStateMixin {
  final PhotoViewController _controller = PhotoViewController();
  final PhotoViewScaleStateController _scaleController =
      PhotoViewScaleStateController();
  late final AnimationController _resetController;
  Animation<double>? _resetAnim;
  double _dragOffset = 0;

  @override
  void dispose() {
    _resetController.dispose();
    _controller.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  bool _canSwipeBack() {
    final scale = _controller.scale;
    if (scale == null) return true;
    return scale <= 1.01;
  }

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
    final ImageProvider provider =
        widget.file != null ? FileImage(widget.file!) : NetworkImage(widget.url!);
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
        onVerticalDragStart: (_) {
          if (_canSwipeBack()) _resetController.stop();
        },
        onVerticalDragUpdate: (details) {
          if (!_canSwipeBack()) return;
          setState(() {
            _dragOffset += details.delta.dy;
          });
        },
        onVerticalDragEnd: (details) {
          if (!_canSwipeBack()) return;
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
                child: PhotoView(
                  imageProvider: provider,
                  controller: _controller,
                  scaleStateController: _scaleController,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
