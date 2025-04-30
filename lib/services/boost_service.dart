// lib/services/boost_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class BoostService {
  /// Boost a post for [hours] hours.
  static Future<void> boostPost(String postId, int hours) {
    final until = DateTime.now().add(Duration(hours: hours));
    return FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .update({'boostedUntil': until});
  }

  /// Boost a profile for [hours] hours.
  static Future<void> boostProfile(String userId, int hours) {
    final until = DateTime.now().add(Duration(hours: hours));
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'boostedUntil': until});
  }
}
