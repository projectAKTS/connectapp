import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConnectionService {
  static final _ref = FirebaseFirestore.instance.collection('connections');

  /// Create or update a connection between current user and [otherUserId]
  static Future<void> ensureConnection(String otherUserId) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null || me == otherUserId) return;

    final existing = await _ref
        .where('users', arrayContains: me)
        .limit(20)
        .get();

    for (final doc in existing.docs) {
      final users = (doc.data()['users'] as List).cast<String>();
      if (users.contains(otherUserId)) {
        await doc.reference.update({'connectedAt': Timestamp.now()});
        return;
      }
    }

    await _ref.add({
      'users': [me, otherUserId],
      'connectedAt': Timestamp.now(),
    });
  }
}
