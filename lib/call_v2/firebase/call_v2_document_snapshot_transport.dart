import 'package:cloud_firestore/cloud_firestore.dart';

abstract interface class CallV2DocumentSnapshotTransport {
  Stream<DocumentSnapshot<Map<String, dynamic>>> callDocument(
    String collectionName,
    String callId,
  );

  Stream<DocumentSnapshot<Map<String, dynamic>>> participantDocument(
    String collectionName,
    String callId,
    String participantCollectionName,
    String participantUid,
  );
}
