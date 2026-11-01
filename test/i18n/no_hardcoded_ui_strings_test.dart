import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// User-facing text in active screens comes from the ARB files. This scan
/// fails on new English literals in Text(...) and common text properties.
///
/// Excluded: screens that are unreachable or gated off for the MVP. They are
/// kept for later and must be translated before they are turned on.
const _excluded = {
  'lib/screens/premium/premium_screen.dart', // gated (MvpFeatures.premium)
  'lib/screens/premium/premium_tab.dart', // gated
  'lib/screens/posts/boost_post_screen.dart', // unreachable
  'lib/screens/explore/explore_screen.dart', // unreachable
  'lib/screens/posts/comment_screen.dart', // unreachable
  'lib/screens/FollowersScreen.dart', // unreachable
  'lib/screens/FollowingScreen.dart', // unreachable
  'lib/screens/profile/expert_directory_screen.dart', // unreachable
  'lib/screens/consultation/select_consultant_screen.dart', // unreachable
};

final _pattern = RegExp(
  r"(?:Text\(\s*|(?:label|title|tooltip|hintText|labelText|helperText"
  r"|subtitle|message|content):\s*(?:const\s+)?(?:Text\(\s*)?)"
  r"'([^'$]*[A-Za-z]{2,}[^']*)'",
);

void main() {
  test('active screens have no hard-coded English UI text', () {
    final offenders = <String>[];
    for (final dir in ['lib/screens', 'lib/widgets']) {
      for (final entity in Directory(dir).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll('\\', '/');
        if (_excluded.contains(path)) continue;
        for (final m in _pattern.allMatches(entity.readAsStringSync())) {
          offenders.add('$path: ${m[1]}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Add these to lib/l10n/app_en.arb and app_fr.arb');
  });
}
