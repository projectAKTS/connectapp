import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ Get the top XP earners for the leaderboard
  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    QuerySnapshot snapshot = await _firestore
        .collection('users')
        .orderBy('xpPoints', descending: true)
        .limit(10)
        .get();

    return snapshot.docs.map((doc) {
      return {
        'userId': doc.id,
        'fullName': doc['fullName'] ?? 'Unknown User',
        'xpPoints': doc['xpPoints'] ?? 0,
        'badges': doc['badges'] ?? [],
      };
    }).toList();
  }
}
