class UserModel {
  final String userId;
  final String fullName;
  final int xpPoints;
  final int postCount;
  final int commentCount;
  final int helpfulMarks;
  final int streakDays;
  final List<String> badges;

  UserModel({
    required this.userId,
    required this.fullName,
    this.xpPoints = 0,
    this.postCount = 0,
    this.commentCount = 0,
    this.helpfulMarks = 0,
    this.streakDays = 0,
    this.badges = const [],
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String userId) {
    return UserModel(
      userId: userId,
      fullName: data['fullName'] ?? 'Unknown User',
      xpPoints: data['xpPoints'] ?? 0,
      postCount: data['postCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      helpfulMarks: data['helpfulMarks'] ?? 0,
      streakDays: data['streakDays'] ?? 0,
      badges: List<String>.from(data['badges'] ?? []),
    );
  }
}
