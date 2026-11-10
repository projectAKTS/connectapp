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

/// A "last seen" time on the user's own document. Right after the app writes
/// it as a server timestamp the local copy holds null until the server
/// answers; reading that as "never seen" briefly marks everything unread.
DateTime? seenTimestamp(Map<String, dynamic>? data, String key) {
  if (data == null || !data.containsKey(key)) return null;
  return parseFirestoreTimestamp(data[key]) ??
      (data[key] == null ? DateTime.now() : null);
}
