import 'package:cloud_firestore/cloud_firestore.dart';

import 'call_v2_document_snapshot_transport.dart';

class FirebaseFirestoreCallV2SnapshotTransport
    implements CallV2DocumentSnapshotTransport {
  FirebaseFirestoreCallV2SnapshotTransport({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> callDocument(
    String collectionName,
    String callId,
  ) {
    return _firestore.collection(collectionName).doc(callId).snapshots();
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> participantDocument(
    String collectionName,
    String callId,
    String participantCollectionName,
    String participantUid,
  ) {
    return _firestore
        .collection(collectionName)
        .doc(callId)
        .collection(participantCollectionName)
        .doc(participantUid)
        .snapshots();
  }
}
