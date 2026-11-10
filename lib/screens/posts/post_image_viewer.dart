import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import 'package:connect_app/l10n/l10n.dart';

/// Opens [PostImageViewer] over the current screen with a fade.
Future<void> openImageViewer(
  BuildContext context, {
  List<String> urls = const [],
  List<File> files = const [],
  int initialIndex = 0,
}) {
  // Root navigator: full screen above the tab bar.
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) => PostImageViewer(
        urls: urls,
        files: files,
        initialIndex: initialIndex,
      ),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// Full-screen photos: swipe between them, pinch to zoom, swipe down or tap
/// close to leave. A tap hides the controls.
class PostImageViewer extends StatefulWidget {
  final List<String> urls;
  final List<File> files;
  final int initialIndex;

  const PostImageViewer({
    super.key,
    this.urls = const [],
    this.files = const [],
    this.initialIndex = 0,
  }) : assert(urls.length + files.length > 0, 'Provide urls or files');

  @override
  State<PostImageViewer> createState() => _PostImageViewerState();
}

class _PostImageViewerState extends State<PostImageViewer>
    with SingleTickerProviderStateMixin {
  late final PageController _pages;
  late final AnimationController _reset;
  Animation<double>? _resetAnim;
  late int _index;
  double _drag = 0;
  bool _zoomed = false;
  bool _chrome = true;

  int get _count =>
      widget.files.isNotEmpty ? widget.files.length : widget.urls.length;

  ImageProvider _provider(int i) => widget.files.isNotEmpty
      ? FileImage(widget.files[i])
      : NetworkImage(widget.urls[i]) as ImageProvider;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, _count - 1);
    _pages = PageController(initialPage: _index);
    _reset = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(() => setState(() => _drag = _resetAnim?.value ?? 0));
  }

  @override
  void dispose() {
    _reset.dispose();
    _pages.dispose();
    super.dispose();
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
    final showChrome = _chrome && _drag == 0;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: fade),
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => setState(() => _chrome = !_chrome),
            onVerticalDragStart: _zoomed ? null : (_) => _reset.stop(),
            onVerticalDragUpdate:
                _zoomed ? null : (d) => setState(() => _drag += d.delta.dy),
            onVerticalDragEnd: _zoomed
                ? null
                : (d) {
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
                child: PhotoViewGallery.builder(
                  pageController: _pages,
                  itemCount: _count,
                  backgroundDecoration:
                      const BoxDecoration(color: Colors.transparent),
                  onPageChanged: (i) => setState(() => _index = i),
                  scaleStateChangedCallback: (s) => setState(
                      () => _zoomed = s != PhotoViewScaleState.initial),
                  loadingBuilder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  builder: (_, i) => PhotoViewGalleryPageOptions(
                    imageProvider: _provider(i),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 3,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white54, size: 40),
                    ),
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            ignoring: !showChrome,
            child: AnimatedOpacity(
              opacity: showChrome ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: SafeArea(
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
                      if (_count > 1)
                        ViewerPill(
                          text: context.l10n.mediaCounter(_index + 1, _count),
                        ),
                      const Spacer(),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_count > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: showChrome ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child:
                          PageDots(count: _count, index: _index, light: true),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Translucent round icon button used over photos and video.
class ViewerRoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;

  const ViewerRoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: Colors.white, size: size * 0.52),
          ),
        ),
      ),
    );
  }
}

/// Small dark pill with white text ("2 / 5", "1:24").
class ViewerPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  const ViewerPill({super.key, required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 13),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Page dots under a photo carousel.
class PageDots extends StatelessWidget {
  final int count;
  final int index;
  final bool light;
  const PageDots(
      {super.key,
      required this.count,
      required this.index,
      this.light = false});

  @override
  Widget build(BuildContext context) {
    final on = light ? Colors.white : const Color(0xFF3A3A3A);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: on.withValues(alpha: i == index ? 0.9 : 0.35),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
      ],
    );
  }
}

/// "1:05" for a video length.
String formatMediaDuration(Duration d) {
  final s = d.inSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$sec' : '$m:$sec';
}
