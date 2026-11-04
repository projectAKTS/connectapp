import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Blurs media until the viewer taps it (docs/SAFETY_ROADMAP.md #6): received
/// chat photos, and post photos the server marked sensitive.
///
/// Uncontrolled by default (remembers the tap itself); pass [revealed] and
/// [onReveal] when the parent must keep the state, as in a scrolling chat.
class SensitiveMediaCover extends StatefulWidget {
  final Widget child;
  final String label;
  final bool? revealed;
  final VoidCallback? onReveal;

  const SensitiveMediaCover({
    super.key,
    required this.child,
    required this.label,
    this.revealed,
    this.onReveal,
  });

  @override
  State<SensitiveMediaCover> createState() => _SensitiveMediaCoverState();
}

class _SensitiveMediaCoverState extends State<SensitiveMediaCover> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.revealed ?? _revealed) return widget.child;
    return ClipRect(
      child: Stack(
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: IgnorePointer(child: widget.child),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.black26,
              child: InkWell(
                onTap: () {
                  if (widget.onReveal != null) {
                    widget.onReveal!();
                  } else {
                    setState(() => _revealed = true);
                  }
                },
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility_off_outlined,
                            color: Colors.white),
                        const SizedBox(height: 6),
                        Text(
                          widget.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
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
