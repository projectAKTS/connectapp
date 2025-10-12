import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart' as crypto;

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // -------------------------
  // Initialize Firestore user
  // -------------------------
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
      }, SetOptions(merge: true));
    } catch (e) {
      print('🔥 Error initializing user in Firestore: $e');
      rethrow;
    }
  }

  // -------------------------
  // Email / Password
  // -------------------------
  Future<User?> signInWithEmail(String email, String password) async {
    final creds = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return creds.user;
  }

  Future<User?> registerWithEmail(
    String email,
    String password,
    String fullName,
  ) async {
    final creds = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = creds.user;
    if (user == null) throw Exception('Failed to create user');
    await user.updateDisplayName(fullName);
    await user.reload();
    await initializeUserInFirestore(user, fullName, email);
    return _auth.currentUser;
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // -------------------------
  // Google Sign-in
  // -------------------------
  Future<User?> signInWithGoogle() async {
    try {
      final gsi = GoogleSignIn();
      await gsi.signOut();
      await _auth.signOut();

      final googleUser = await gsi.signIn().timeout(const Duration(seconds: 25));
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication.timeout(const Duration(seconds: 15));
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final creds = await _auth.signInWithCredential(credential).timeout(const Duration(seconds: 20));
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
      print('🔥 Error during Google sign-in: $e');
      rethrow;
    }
  }

  // -------------------------
  // Apple Sign-in (Fixed)
  // -------------------------
  Future<User?> signInWithApple() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      print('⚠️ Apple Sign-In only available on iOS/macOS');
      return null;
    }

    final available = await SignInWithApple.isAvailable();
    if (!available) {
      throw Exception('❌ Sign in with Apple not available.');
    }

    try {
      print('\n\n🔍 ----- APPLE SIGN-IN DEBUG START -----');

      final rawNonce = _randomNonce();
      final hashedNonce = _sha256(rawNonce);

      final appleCred = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      ).timeout(const Duration(seconds: 35));

      print('\n🧾 Identity Token: ${appleCred.identityToken}');
      print('🔑 Authorization Code: ${appleCred.authorizationCode}');
      print('📧 Email: ${appleCred.email}');
      print('👤 User ID: ${appleCred.userIdentifier}');

      // ✅ FIX: pass BOTH idToken + authorizationCode to Firebase
      final oauthCred = OAuthProvider('apple.com').credential(
        idToken: appleCred.identityToken,
        accessToken: appleCred.authorizationCode, // 👈 critical fix
        rawNonce: rawNonce,
      );

      final creds = await _auth.signInWithCredential(oauthCred).timeout(const Duration(seconds: 20));
      final user = creds.user;

      if (user != null) {
        final fullName = [
          appleCred.givenName ?? '',
          appleCred.familyName ?? '',
        ].where((n) => n.isNotEmpty).join(' ').trim();

        if (fullName.isNotEmpty && user.displayName != fullName) {
          await user.updateDisplayName(fullName);
        }

        await initializeUserInFirestore(
          user,
          fullName.isNotEmpty ? fullName : (user.displayName ?? 'Anonymous'),
          user.email ?? appleCred.email ?? '',
        );
      }

      print('✅ ----- APPLE SIGN-IN SUCCESS -----');
      return user;
    } on TimeoutException {
      print('⏳ Apple sign-in timeout.');
      rethrow;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        print('🚫 Apple sign-in canceled by user.');
        return null;
      }
      print('❌ Apple sign-in failed: ${e.code.name} ${e.message}');
      rethrow;
    } catch (e, st) {
      print('\n❌ ----- APPLE SIGN-IN ERROR -----');
      print('Error during Apple sign-in: $e');
      print('Stack trace: $st');
      rethrow;
    }
  }

  // -------------------------
  // Sign-out
  // -------------------------
  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
      await _auth.signOut();
    } catch (e) {
      print('⚠️ Error signing out: $e');
    }
  }

  User? getCurrentUser() => _auth.currentUser;

  // -------------------------
  // Helpers for Nonce
  // -------------------------
  String _randomNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final rand = Random.secure();
    return List.generate(length, (_) => charset[rand.nextInt(charset.length)]).join();
  }

  String _sha256(String input) => crypto.sha256.convert(utf8.encode(input)).toString();
}
