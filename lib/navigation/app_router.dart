// lib/navigation/app_router.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:connect_app/screens/chat/chat_screen.dart';
import 'package:connect_app/screens/consultation/consultation_booking_screen.dart';
import 'package:connect_app/screens/profile/profile_screen.dart';
import 'package:connect_app/screens/posts/post_detail_screen.dart';

class AppRouter {
  /// Routes that should work BOTH on root navigator AND inside tab navigators.
  static Route<dynamic>? onGenerateSharedRoute(RouteSettings settings) {
    final name = settings.name;
    if (name == null) return null;

    // Handle deep link style: /profile/<id> and /post/<id>
    final uri = Uri.tryParse(name);
    if (uri != null) {
      if (uri.pathSegments.length == 2 && uri.pathSegments[0] == 'profile') {
        final userId = uri.pathSegments[1];
        return CupertinoPageRoute(
          settings: settings,
          builder: (_) => ProfileScreen(userID: userId),
        );
      }

      if (uri.pathSegments.length == 2 && uri.pathSegments[0] == 'post') {
        final postId = uri.pathSegments[1];
        return CupertinoPageRoute(
          settings: settings,
          builder: (_) => PostDetailScreen(postId: postId),
        );
      }
    }

    // Named routes with arguments
    if (name == '/chat') {
      final args = settings.arguments as Map<String, dynamic>?;
      final otherUserId = args?['otherUserId'] as String?;
      final otherUserName = args?['otherUserName'] as String?;
      final otherUserAvatar = args?['otherUserAvatar'] as String?;

      if (otherUserId == null || otherUserId.isEmpty) {
        return CupertinoPageRoute(
          settings: settings,
          builder: (_) => const Scaffold(
            body: Center(child: Text('Missing otherUserId')),
          ),
        );
      }

      return CupertinoPageRoute(
        settings: settings,
        builder: (_) => ChatScreen(
          otherUserId: otherUserId,
          otherUserName: otherUserName,
          otherUserAvatar: otherUserAvatar,
        ),
      );
    }

    if (name == '/consultation') {
      final args = settings.arguments as Map<String, dynamic>?;
      final id = args?['targetUserId'] as String?;
      final targetName = args?['targetUserName'] as String?;

      if (id == null || id.isEmpty || targetName == null || targetName.isEmpty) {
        return CupertinoPageRoute(
          settings: settings,
          builder: (_) => const Scaffold(
            body: Center(child: Text('Invalid consultation arguments')),
          ),
        );
      }

      return CupertinoPageRoute(
        settings: settings,
        builder: (_) => ConsultationBookingScreen(
          targetUserId: id,
          targetUserName: targetName,
        ),
      );
    }

    return null;
  }

  /// Tab navigator route factory: shared routes first, otherwise return the tab root.
  static Route<dynamic> onGenerateTabRoute({
    required RouteSettings settings,
    required Widget tabRoot,
  }) {
    final shared = onGenerateSharedRoute(settings);
    if (shared != null) return shared;

    return CupertinoPageRoute(
      settings: settings,
      builder: (_) => tabRoot,
    );
  }
}
