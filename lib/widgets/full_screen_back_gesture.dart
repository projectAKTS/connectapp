import 'package:flutter/material.dart';

class FullScreenBackGesture extends StatefulWidget {
  final Widget child;

  const FullScreenBackGesture({super.key, required this.child});

  @override
  State<FullScreenBackGesture> createState() => _FullScreenBackGestureState();
}

class _FullScreenBackGestureState extends State<FullScreenBackGesture> {
  double _dragDx = 0;

  void _reset() => _dragDx = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _reset(),
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 0) {
          _dragDx += details.delta.dx;
        }
      },
      onHorizontalDragEnd: (details) {
        final nav = Navigator.of(context);
        if (!nav.canPop()) {
          _reset();
          return;
        }
        final velocity = details.velocity.pixelsPerSecond.dx;
        if (_dragDx > 80 || velocity > 700) {
          nav.maybePop();
        }
        _reset();
      },
      child: widget.child,
    );
  }
}
