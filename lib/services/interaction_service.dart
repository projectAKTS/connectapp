import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InteractionService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static Future<void> recordInteraction(String otherUserId) async {
    final me = _auth.currentUser?.uid;
    if (me == null || me == otherUserId) {
      print('[InteractionService] Skipped: invalid self or null user.');
      return;
    }

    final ids = [me, otherUserId]..sort();
    final docId = ids.join('_');
    final ref = _db.collection('connections').doc(docId);

    print('[InteractionService] Trying to record connection between $me and $otherUserId');

    await _db.runTransaction((txn) async {
      final existing = await txn.get(ref);
      if (existing.exists) {
        print('[InteractionService] Updating existing connection: $docId');
        txn.update(ref, {'connectedAt': FieldValue.serverTimestamp()});
      } else {
        print('[InteractionService] Creating new connection: $docId');
        txn.set(ref, {
          'userId': me,
          'connectedUserId': otherUserId,
          'users': ids,
          'connectedAt': FieldValue.serverTimestamp(),
        });
      }
    }).catchError((e) {
      print('[InteractionService] ERROR: $e');
    });
  }
}
