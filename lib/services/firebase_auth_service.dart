import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
  Future<User?> registerWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
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
      if (googleUser == null) return null; // User canceled login

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      print('Error during Google sign-in: $e');
      return null;
    }
  }

  /// ✅ Sign in with Apple (Only for iOS/macOS)
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
      return userCredential.user;
    } catch (e) {
      print('Error during Apple sign-in: $e');
      return null;
    }
  }

  /// ✅ Sign Out (Supports Google sign-out as well)
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await GoogleSignIn().signOut(); // Logout from Google
    } catch (e) {
      print('Error during sign-out: $e');
    }
  }

  /// ✅ Reset Password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      print('Password reset email sent.');
    } on FirebaseAuthException catch (e) {
      print('Error during password reset: ${e.message}');
    } catch (e) {
      print('Unknown error during password reset: $e');
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

  /// ✅ Update Email
  Future<bool> updateEmail(String newEmail) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updateEmail(newEmail);
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating email: $e');
      return false;
    }
  }

  /// ✅ Update Password
  Future<bool> updatePassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating password: $e');
      return false;
    }
  }

  /// ✅ Delete User Account
  Future<bool> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting account: $e');
      return false;
    }
  }
}
