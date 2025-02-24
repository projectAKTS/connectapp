import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// ✅ Initialize User in Firestore
  Future<void> initializeUserInFirestore(User user, String fullName, String email) async {
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

        // ✅ Gamification Fields
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
          'Health': 0
        },
        'activePerks': {
          'priorityPostBoost': null,
          'profileHighlight': null,
          'commentBoost': null
        }
      });
    } catch (e) {
      print('Error initializing user: $e');
    }
  }

  /// ✅ Sign in with Email & Password
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print('Error during sign-in: ${e.message}');
      return null;
    } catch (e) {
      print('Unknown error during sign-in: $e');
      return null;
    }
  }

  /// ✅ Register with Email & Password
  Future<User?> registerWithEmail(String email, String password, String fullName) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = userCredential.user;

      if (user != null) {
        await initializeUserInFirestore(user, fullName, email);
      }
      return user;
    } on FirebaseAuthException catch (e) {
      print('Error during registration: ${e.message}');
      return null;
    } catch (e) {
      print('Unknown error during registration: $e');
      return null;
    }
  }

  /// ✅ Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        await initializeUserInFirestore(user, user.displayName ?? 'Anonymous', user.email ?? '');
      }
      return user;
    } catch (e) {
      print('Error during Google sign-in: $e');
      return null;
    }
  }

  /// ✅ Sign in with Apple
  Future<User?> signInWithApple() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      print("Apple Sign-In is only available on iOS & macOS");
      return null;
    }

    try {
      final AuthorizationCredentialAppleID appleCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );

      final OAuthCredential credential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        await initializeUserInFirestore(user, user.displayName ?? 'Anonymous', user.email ?? '');
      }
      return user;
    } catch (e) {
      print('Error during Apple sign-in: $e');
      return null;
    }
  }

  /// ✅ Sign Out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await GoogleSignIn().signOut();
    } catch (e) {
      print('Error during sign-out: $e');
    }
  }

  /// ✅ Get Current User
  User? getCurrentUser() {
    try {
      return _auth.currentUser;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }
}
