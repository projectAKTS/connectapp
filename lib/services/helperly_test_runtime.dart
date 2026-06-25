import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HelperlyTestRuntime {
  static const bool isEnabled =
      bool.fromEnvironment('HELPERLY_TEST_MODE', defaultValue: false);

  static FirebaseFirestore? _firestoreOverride;
  static String? _currentUidOverride;
  static String? _currentDisplayNameOverride;

  static FirebaseFirestore get firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  static String? get currentUid =>
      _currentUidOverride ?? FirebaseAuth.instance.currentUser?.uid;

  static String? get currentDisplayName =>
      _currentDisplayNameOverride ??
      FirebaseAuth.instance.currentUser?.displayName;

  static void configureForTest({
    required FirebaseFirestore firestore,
    required String currentUid,
    String? currentDisplayName,
  }) {
    _firestoreOverride = firestore;
    _currentUidOverride = currentUid;
    _currentDisplayNameOverride = currentDisplayName;
  }

  static void clear() {
    _firestoreOverride = null;
    _currentUidOverride = null;
    _currentDisplayNameOverride = null;
  }
}
