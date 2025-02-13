class Comment {
  final String id;
  final String userId;
  final String userName;
  final String content;
  final DateTime timestamp;
  final List<String> likedBy;

  Comment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.content,
    required this.timestamp,
    required this.likedBy,
  });

  // Convert Firestore Document to Comment Object
  factory Comment.fromFirestore(Map<String, dynamic> data, String docId) {
    return Comment(
      id: docId,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      likedBy: List<String>.from(data['likedBy'] ?? []),
    );
  }

  // Convert Comment Object to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'content': content,
      'timestamp': timestamp,
      'likedBy': likedBy,
    };
  }
}
