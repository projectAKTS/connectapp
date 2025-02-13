class Comment {
  final String id;
  final String postId;
  final String userId;
  final String text;
  final DateTime timestamp;
  final int likes;
  final List<String> likedBy;
  final String? parentId; // Null if it's a top-level comment

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.text,
    required this.timestamp,
    this.likes = 0,
    this.likedBy = const [],
    this.parentId,
  });

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'userId': userId,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'likes': likes,
      'likedBy': likedBy,
      'parentId': parentId,
    };
  }

  // Convert from Firestore JSON
  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      postId: json['postId'],
      userId: json['userId'],
      text: json['text'],
      timestamp: DateTime.parse(json['timestamp']),
      likes: json['likes'] ?? 0,
      likedBy: List<String>.from(json['likedBy'] ?? []),
      parentId: json['parentId'],
    );
  }
}
