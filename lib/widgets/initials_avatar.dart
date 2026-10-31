import 'package:connect_app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// A profile photo, or the person's initials when there is none.
class InitialsAvatar extends StatelessWidget {
  final String url;
  final String name;
  final double radius;
  const InitialsAvatar(
      {super.key, required this.url, this.name = '', this.radius = 20});

  /// Up to two initials; people recognise names faster than a generic icon.
  String get _initials {
    // Words that start with a letter, so "Yakup Akturk 2026" gives "YA".
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where(
            (p) => p.isNotEmpty && RegExp(r'^\p{L}', unicode: true).hasMatch(p))
        .toList();
    if (parts.isEmpty) return '';
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (url.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(url));
    }
    final initials = _initials;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.avatarBg,
      child: initials.isEmpty
          ? const Icon(Icons.person_outline, color: AppColors.avatarFg)
          : Text(
              initials,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.7,
              ),
            ),
    );
  }
}
