import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? parseFirestoreTimestamp(dynamic ts) {
  if (ts == null) return null;
  if (ts is Timestamp) return ts.toDate();
  if (ts is DateTime) return ts;
  if (ts is String) {
    try {
      return DateTime.parse(ts);
    } catch (_) {
      return null;
    }
  }
  return null;
}
