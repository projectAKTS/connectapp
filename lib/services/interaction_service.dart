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

    print(
        '[InteractionService] Trying to record connection between $me and $otherUserId');

    try {
      // Avoid transaction reads on non-existing docs, which can fail under
      // strict rules and surface as permission-denied for first interaction.
      await ref.set({
        'userId': ids[0],
        'connectedUserId': ids[1],
        'users': ids,
        'lastInteractionAt': FieldValue.serverTimestamp(),
        'connectedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      try {
        await _db.collection('users').doc(me).set({
          'diag.lastConnectionStage': 'record_ok',
          'diag.lastConnectionAt': FieldValue.serverTimestamp(),
          'diag.lastConnectionPeer': otherUserId,
          'diag.lastConnectionError': FieldValue.delete(),
        }, SetOptions(merge: true));
      } catch (_) {}
    } catch (e) {
      print('[InteractionService] ERROR: $e');
      try {
        await _db.collection('users').doc(me).set({
          'diag.lastConnectionStage': 'record_error',
          'diag.lastConnectionAt': FieldValue.serverTimestamp(),
          'diag.lastConnectionPeer': otherUserId,
          'diag.lastConnectionError': '$e',
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }
}
