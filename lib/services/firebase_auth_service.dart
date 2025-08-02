import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:connect_app/utils/time_utils.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Initialize a new user document in Firestore.
  Future<void> initializeUserInFirestore(
    User user,
    String fullName,
    String email,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fullName': fullName,
        'email': email,
        'bio': 'No bio available yet.',
        'followers': [],
        'following': [],
        'postsCount': 0,
        'profilePicture': '',
        'createdAt': FieldValue.serverTimestamp(),
        // Gamification fields
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
      }, SetOptions(merge: true)); // <-- make merge explicit just in case
    } catch (e) {
      print('Error initializing user in Firestore: $e');
      rethrow;
    }
  }

  /// Sign in with email & password. Let exceptions bubble up.
  Future<User?> signInWithEmail(String email, String password) async {
    final creds = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return creds.user;
  }

  /// Register with email & password, set displayName, and write Firestore user.
  /// Let all exceptions bubble up!
  Future<User?> registerWithEmail(
    String email,
    String password,
    String fullName,
  ) async {
    // 1) Create the user in Firebase Auth
    final creds = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = creds.user;
    if (user == null) {
      throw Exception('Failed to create user');
    }

    // 2) Update their displayName in Auth
    await user.updateDisplayName(fullName);
    await user.reload();

    // 3) Create the Firestore document (if not exists, merge: true)
    await initializeUserInFirestore(user, fullName, email);

    // 4) Return the signed‑up user
    return _auth.currentUser;
  }

  /// Sign in with Google.
  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final creds = await _auth.signInWithCredential(credential);
      final user = creds.user;
      if (user != null) {
        await initializeUserInFirestore(
          user,
          user.displayName ?? 'Anonymous',
          user.email ?? '',
        );
      }
      return user;
    } catch (e) {
      print('Error during Google sign‑in: $e');
      rethrow; // Let the error propagate
    }
  }

  /// Sign in with Apple.
  Future<User?> signInWithApple() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      print('Apple Sign-In only on iOS/macOS');
      return null;
    }
    try {
      final appleCred = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName
        ],
      );
      final oauthCred = OAuthProvider('apple.com').credential(
        idToken: appleCred.identityToken,
      );
      final creds = await _auth.signInWithCredential(oauthCred);
      final user = creds.user;
      if (user != null) {
        await initializeUserInFirestore(
          user,
          user.displayName ?? 'Anonymous',
          user.email ?? '',
        );
      }
      return user;
    } catch (e) {
      print('Error during Apple sign‑in: $e');
      rethrow;
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  /// Get the current user (or null).
  User? getCurrentUser() => _auth.currentUser;
}
