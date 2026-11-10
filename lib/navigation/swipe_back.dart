import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// iOS-style page slide where a swipe to the right anywhere on the page (not
/// only from the left edge) drags the page back, following the finger.
/// Set for every platform in the app theme, so all [MaterialPageRoute]s get it.
///
/// Swipes that a page's own horizontal content claims first (photo
/// carousels, sliders, text fields) keep working: the innermost gesture wins.
/// Adapted from Flutter's CupertinoPageRoute back gesture (BSD licence),
/// whose drag area is only 20px wide.
class SwipeBackPageTransitionsBuilder extends PageTransitionsBuilder {
  const SwipeBackPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final gesture = route.navigator?.userGestureInProgress ?? false;
    return CupertinoPageTransition(
      primaryRouteAnimation: animation,
      secondaryRouteAnimation: secondaryAnimation,
      linearTransition: gesture,
      child: _SwipeBackDetector<T>(route: route, child: child),
    );
  }
}

// A little easier than iOS (1.0 and half the screen): a short flick or a
// third of the screen is enough.
const double _minFlingVelocity = 0.6; // Screen widths per second.
const Duration _settleDuration = Duration(milliseconds: 350);

class _SwipeBackDetector<T> extends StatefulWidget {
  final PageRoute<T> route;
  final Widget child;
  const _SwipeBackDetector(
      {super.key, required this.route, required this.child});

  @override
  State<_SwipeBackDetector<T>> createState() => _SwipeBackDetectorState<T>();
}

class _SwipeBackDetectorState<T> extends State<_SwipeBackDetector<T>> {
  late final HorizontalDragGestureRecognizer _drag;
  AnimationController? _controller;

  PageRoute<T> get _route => widget.route;

  // ignore: invalid_use_of_protected_member
  AnimationController? get _routeController => _route.controller;

  /// Same conditions as Flutter's own iOS back swipe.
  bool get _enabled {
    final route = _route;
    final nav = route.navigator;
    if (nav == null || route.isFirst || route.fullscreenDialog) return false;
    if (route.willHandlePopInternally) return false;
    if (route.popDisposition == RoutePopDisposition.doNotPop) return false;
    if (route.animation?.status != AnimationStatus.completed) return false;
    if (route.secondaryAnimation?.status != AnimationStatus.dismissed) {
      return false;
    }
    return !nav.userGestureInProgress;
  }

  @override
  void initState() {
    super.initState();
    _drag = HorizontalDragGestureRecognizer(debugOwner: this)
      ..onStart = _onStart
      ..onUpdate = _onUpdate
      ..onEnd = _onEnd
      ..onCancel = _onCancel;
  }

  @override
  void dispose() {
    _drag.dispose();
    if (_controller != null) {
      // Leave the navigator out of gesture mode if the page goes mid-drag.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = _route.navigator;
        if (nav != null && nav.mounted && nav.userGestureInProgress) {
          nav.didStopUserGesture();
        }
      });
    }
    super.dispose();
  }

  void _onStart(DragStartDetails _) {
    final controller = _routeController;
    if (controller == null || !_enabled) return;
    _controller = controller;
    _route.navigator!.didStartUserGesture();
  }

  double _logical(double v) =>
      Directionality.of(context) == TextDirection.rtl ? -v : v;

  void _onUpdate(DragUpdateDetails d) {
    final c = _controller;
    if (c == null) return;
    c.value -= _logical(d.primaryDelta! / context.size!.width);
  }

  void _onEnd(DragEndDetails d) =>
      _finish(_logical(d.velocity.pixelsPerSecond.dx / context.size!.width));

  void _onCancel() => _finish(0);

  void _finish(double velocity) {
    final c = _controller;
    _controller = null;
    if (c == null) return;
    final nav = _route.navigator!;
    final isCurrent = _route.isCurrent;
    final bool stay;
    if (!isCurrent) {
      stay = _route.isActive;
    } else if (velocity.abs() >= _minFlingVelocity) {
      stay = velocity <= 0;
    } else {
      stay = c.value > 0.65;
    }
    const curve = Curves.fastEaseInToSlowEaseOut;
    if (stay) {
      c.animateTo(1.0, duration: _settleDuration, curve: curve);
    } else {
      if (isCurrent) nav.pop();
      if (c.isAnimating) {
        c.animateBack(0.0, duration: _settleDuration, curve: curve);
      }
    }
    if (c.isAnimating) {
      // Stay in gesture mode until the page settles, as Flutter does.
      late AnimationStatusListener done;
      done = (_) {
        nav.didStopUserGesture();
        c.removeStatusListener(done);
      };
      c.addStatusListener(done);
    } else {
      nav.didStopUserGesture();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        if (_enabled) _drag.addPointer(e);
      },
      child: widget.child,
    );
  }
}
