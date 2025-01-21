import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> updateFollowersFollowing({
    required String currentUserId,
    required String targetUserId,
    required bool isFollow,
  }) async {
    final currentUserRef = _firestore.collection('users').doc(currentUserId);
    final targetUserRef = _firestore.collection('users').doc(targetUserId);

    try {
      if (isFollow) {
        await targetUserRef.update({
          'followers': FieldValue.arrayUnion([currentUserId])
        });
        await currentUserRef.update({
          'following': FieldValue.arrayUnion([targetUserId])
        });
      } else {
        await targetUserRef.update({
          'followers': FieldValue.arrayRemove([currentUserId])
        });
        await currentUserRef.update({
          'following': FieldValue.arrayRemove([targetUserId])
        });
      }
    } catch (e) {
      print("Error updating followers/following: $e");
    }
  }
}
