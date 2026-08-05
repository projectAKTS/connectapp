// lib/services/firebase_auth_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart' as crypto;

import 'notification_service.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// ✅ Keep ONE instance (iOS stable)
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email', 'profile'],
  );

  /// ✅ Prevent overlapping flows (double-tap)
  Future<User?>? _googleInFlight;

  // -------------------------
  // Initialize Firestore user
  // -------------------------
  Future<void> initializeUserInFirestore(
    User user,
    String fullName,
    String email,
  ) async {
    try {
      final displayName = fullName.trim();
      final displayNameLc = displayName.toLowerCase();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'fullName': fullName,
          'fullNameLower': fullName.toLowerCase(),
          'displayName': displayName,
          'displayName_lc': displayNameLc,
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
        },
        SetOptions(merge: true),
      );
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
  // Google Sign-in (ALWAYS ASK / ALWAYS PICKER)
  // -------------------------
  /// ✅ Always shows Google account chooser every time.
  /// ✅ Allows "Use another account".
  /// ✅ No silent sign-in.
  /// ✅ No automatic reuse.
  ///
  /// NOTE: We do NOT signOut Firebase before this.
  Future<User?> signInWithGoogleAlwaysAsk() {
    _googleInFlight ??= _signInWithGoogleAlwaysAskInternal();
    return _googleInFlight!.whenComplete(() => _googleInFlight = null);
  }

  Future<User?> _signInWithGoogleAlwaysAskInternal() async {
    try {
      // Force chooser:
      // - disconnect removes previous consent (strongest)
      // - signOut clears cached user for this app session
      try {
        await _googleSignIn.disconnect();
      } catch (_) {}
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // cancelled

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw Exception('Google sign-in failed: missing idToken');
      }

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
      print('🔥 Error during Google sign-in: $e');
      rethrow;
    }
  }

  // -------------------------
  // Apple Sign-in (keep as-is)
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
      );

      print('\n🧾 Identity Token: ${appleCred.identityToken}');
      print('🔑 Authorization Code: ${appleCred.authorizationCode}');
      print('📧 Email: ${appleCred.email}');
      print('👤 User ID: ${appleCred.userIdentifier}');

      final oauthCred = OAuthProvider('apple.com').credential(
        idToken: appleCred.identityToken,
        accessToken: appleCred.authorizationCode,
        rawNonce: rawNonce,
      );

      final creds = await _auth.signInWithCredential(oauthCred);
      final user = creds.user;

      if (user != null) {
        final fullName = [
          appleCred.givenName ?? '',
          appleCred.familyName ?? '',
        ].where((n) => n.isNotEmpty).join(' ').trim();

        final email = user.email ?? appleCred.email ?? '';
        var resolvedName =
            fullName.isNotEmpty ? fullName : (user.displayName ?? '').trim();
        if (resolvedName.isEmpty) {
          resolvedName = _fallbackNameFromEmail(email);
        }
        if (resolvedName.isEmpty) resolvedName = 'User';

        if (user.displayName != resolvedName) {
          await user.updateDisplayName(resolvedName);
        }

        await initializeUserInFirestore(
          user,
          resolvedName,
          email,
        );
      }

      print('✅ ----- APPLE SIGN-IN SUCCESS -----');
      return user;
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
    await NotificationService.prepareCurrentUserForSignOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  User? getCurrentUser() => _auth.currentUser;

  // -------------------------
  // Helpers for Nonce
  // -------------------------
  String _randomNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final rand = Random.secure();
    return List.generate(length, (_) => charset[rand.nextInt(charset.length)])
        .join();
  }

  String _sha256(String input) =>
      crypto.sha256.convert(utf8.encode(input)).toString();

  String _fallbackNameFromEmail(String email) {
    if (email.isEmpty || !email.contains('@')) return '';
    final base = email.split('@').first;
    final cleaned = base.replaceAll(RegExp(r'[^A-Za-z0-9]+'), ' ').trim();
    if (cleaned.isEmpty) return '';
    return cleaned
        .split(' ')
        .map((p) {
          if (p.isEmpty) return '';
          return p[0].toUpperCase() + p.substring(1);
        })
        .join(' ')
        .trim();
  }
}
