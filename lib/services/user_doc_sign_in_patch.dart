import 'package:cloud_firestore/cloud_firestore.dart';

/// What the app writes to `users/{uid}` each time a user is signed in.
///
/// The name and the new-profile defaults are written only from a server
/// read with no local writes pending ([fromServer]). Otherwise the snapshot
/// can be partial (on a fresh sign-in the push-token write is still pending
/// and the profile reads as empty) or stale (renamed on another device):
/// writing a name from it replaced real names with "User".
Map<String, dynamic> userDocSignInPatch({
  required bool exists,
  required bool fromServer,
  required Map<String, dynamic> data,
  required String authName,
  required String appLocale,
}) {
  final patch = <String, dynamic>{
    // Lets the server write push notifications in the app's language.
    'appLocale': appLocale,
  };
  if (!fromServer) return patch;

  final existingName =
      (data['displayName'] ?? data['fullName'] ?? '').toString().trim();
  final name = existingName.isNotEmpty
      ? existingName
      : (authName.trim().isNotEmpty ? authName.trim() : 'User');
  patch.addAll({
    'displayName': name,
    'displayName_lc': name.toLowerCase(),
    'fullName': name,
    'fullNameLower': name.toLowerCase(),
  });

  if (!exists) {
    patch.addAll({
      'bio': '',
      'followers': [],
      'following': [],
      'postsCount': 0,
      'profilePicture': '',
      'createdAt': FieldValue.serverTimestamp(),
      'xpPoints': 0,
      'badges': [],
      'postCount': 0,
      'commentCount': 0,
      'helpfulMarks': 0,
      'dailyLoginStreak': 0,
      'postingStreak': 0,
      'lastLoginDate': null,
      'lastPostDate': null,
      'referralCount': 0,
      'categoryPosts': {
        'Career': 0,
        'Travel': 0,
        'Finance': 0,
        'Technology': 0,
        'Health': 0,
      },
      'activePerks': {
        'priorityPostBoost': null,
        'profileHighlight': null,
        'commentBoost': null,
      },
      'premiumStatus': 'none',
      'trialUsed': false,
    });
  }
  return patch;
}
