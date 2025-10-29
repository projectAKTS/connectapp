import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InteractionService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Ensures both users are connected after any meaningful interaction
  static Future<void> recordInteraction(String otherUserId) async {
    final me = _auth.currentUser?.uid;
    if (me == null || me == otherUserId) return;

    final ids = [me, otherUserId]..sort();
    final docId = ids.join('_');
    final ref = _db.collection('connections').doc(docId);

    await _db.runTransaction((t) async {
      final doc = await t.get(ref);
      if (!doc.exists) {
        t.set(ref, {
          'users': ids,
          'connectedAt': FieldValue.serverTimestamp(),
        });
      } else {
        t.update(ref, {'connectedAt': FieldValue.serverTimestamp()});
      }
    });
  }
}
