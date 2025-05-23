import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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
      });
    } catch (e) {
      print('Error initializing user in Firestore: $e');
    }
  }

  /// Sign in with email & password.
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final creds = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return creds.user;
    } on FirebaseAuthException catch (e) {
      print('Error during sign‑in: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      print('Unknown error during sign‑in: $e');
      return null;
    }
  }

  /// Register with email & password, set displayName, and write Firestore user.
  Future<User?> registerWithEmail(
    String email,
    String password,
    String fullName,
  ) async {
    try {
      // 1) Create the user in Firebase Auth
      final creds = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = creds.user;
      if (user == null) {
        return null;
      }

      // 2) Update their displayName in Auth
      await user.updateDisplayName(fullName);
      await user.reload(); // refresh the User object

      // 3) Create the Firestore document
      await initializeUserInFirestore(user, fullName, email);

      // 4) Return the signed‑up user
      return _auth.currentUser;
    } on FirebaseAuthException catch (e) {
      print('Error during registration: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      print('Unexpected error during registration: $e');
      return null;
    }
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
      return null;
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
      return null;
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
