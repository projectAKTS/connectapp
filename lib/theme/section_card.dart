import 'package:flutter/material.dart';

/// A shared rounded container with border + soft shadow.
/// Keeps cards consistent across the app (used by Home/Search, etc.).
class SectionCard extends StatelessWidget {
  const SectionCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  }) : super(key: key);

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline),
        boxShadow: const [
          BoxShadow(color: Color(0x140F4C46), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}
