import 'package:flutter/material.dart';

/// Swipe-back now comes from the page route itself (SwipeBackPageTransitionsBuilder
/// in the app theme), which follows the finger. This wrapper stays so screens
/// that use it keep compiling; a second, non-following swipe here would win
/// over the route's.
class FullScreenBackGesture extends StatelessWidget {
  final Widget child;

  const FullScreenBackGesture({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}
