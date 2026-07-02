import 'package:cloud_firestore/cloud_firestore.dart';

import '../call_v2_api.dart';
import '../call_v2_callable_results.dart';
import '../call_v2_feature_gate.dart';
import 'call_v2_document_snapshot_transport.dart';
import 'firebase_firestore_call_v2_snapshot_transport.dart';

class FirebaseCallV2SnapshotSource {
  FirebaseCallV2SnapshotSource({
    required CallV2FeatureGate featureGate,
    required CallV2DocumentSnapshotTransport transport,
    required String callCollectionName,
    required String participantSubcollectionName,
  })  : _featureGate = featureGate,
        _transport = transport,
        _callCollectionName = _validatePathSegment(callCollectionName),
        _participantSubcollectionName = _validatePathSegment(
          participantSubcollectionName,
        );

  factory FirebaseCallV2SnapshotSource.fromFirebaseFirestore({
    required CallV2FeatureGate featureGate,
    required FirebaseFirestore firestore,
    required String callCollectionName,
    required String participantSubcollectionName,
  }) {
    return FirebaseCallV2SnapshotSource(
      featureGate: featureGate,
      transport: FirebaseFirestoreCallV2SnapshotTransport(
        firestore: firestore,
      ),
      callCollectionName: callCollectionName,
      participantSubcollectionName: participantSubcollectionName,
    );
  }

  final CallV2FeatureGate _featureGate;
  final CallV2DocumentSnapshotTransport _transport;
  final String _callCollectionName;
  final String _participantSubcollectionName;

  Stream<DocumentSnapshot<Map<String, dynamic>>> callDocumentStream(
    String callId,
  ) {
    if (!_featureGate.enabled) {
      return Stream<DocumentSnapshot<Map<String, dynamic>>>.error(
        const CallV2ClientError(CallV2ClientErrorCode.rejected),
      );
    }
    final validatedCallId = _validatePathSegment(callId);
    return _transport.callDocument(_callCollectionName, validatedCallId);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> participantDocumentStream(
    String callId,
    String participantUid,
  ) {
    if (!_featureGate.enabled) {
      return Stream<DocumentSnapshot<Map<String, dynamic>>>.error(
        const CallV2ClientError(CallV2ClientErrorCode.rejected),
      );
    }
    final validatedCallId = _validatePathSegment(callId);
    final validatedParticipantUid = _validatePathSegment(participantUid);
    return _transport.participantDocument(
      _callCollectionName,
      validatedCallId,
      _participantSubcollectionName,
      validatedParticipantUid,
    );
  }
}

String _validatePathSegment(String value) {
  if (value.isEmpty ||
      value.trim() != value ||
      value.length > callV2MaxCallableIdentifierLength ||
      value.contains('/')) {
    throw const CallV2ClientError(CallV2ClientErrorCode.invalidRequest);
  }
  return value;
}
