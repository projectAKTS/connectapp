import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Staging builds (`--dart-define-from-file=config/staging/firebase.env.json`,
/// via tool/build_staging.sh) talk to the staging Firebase project only.
/// Values come from build defines, so nothing is in git and production
/// builds are unchanged (HELPERLY_ENV unset).
class StagingFirebaseOptions {
  StagingFirebaseOptions._();

  static const String env = String.fromEnvironment('HELPERLY_ENV');
  static bool get enabled => env == 'staging';

  static const String productionProjectId = 'connectapp-278b4';

  static const String _projectId = String.fromEnvironment('STAGING_PROJECT_ID');
  static const String _senderId = String.fromEnvironment('STAGING_SENDER_ID');
  static const String _bucket =
      String.fromEnvironment('STAGING_STORAGE_BUCKET');

  static FirebaseOptions get current {
    final android = defaultTargetPlatform == TargetPlatform.android;
    final options = FirebaseOptions(
      apiKey: android
          ? const String.fromEnvironment('STAGING_ANDROID_API_KEY')
          : const String.fromEnvironment('STAGING_IOS_API_KEY'),
      appId: android
          ? const String.fromEnvironment('STAGING_ANDROID_APP_ID')
          : const String.fromEnvironment('STAGING_IOS_APP_ID'),
      messagingSenderId: _senderId,
      projectId: _projectId,
      storageBucket: _bucket,
      iosBundleId: android
          ? null
          : const String.fromEnvironment('STAGING_IOS_BUNDLE_ID'),
    );
    if (options.apiKey.isEmpty ||
        options.appId.isEmpty ||
        _projectId.isEmpty ||
        _projectId == productionProjectId) {
      throw StateError('Staging build without valid staging Firebase config');
    }
    return options;
  }

  /// Fails closed: a staging build that ended up on another project (for
  /// example the native config was not swapped) refuses to run.
  static void assertIsolated(String connectedProjectId) {
    if (!enabled) return;
    if (connectedProjectId != _projectId ||
        connectedProjectId == productionProjectId) {
      throw StateError(
          'Staging build connected to "$connectedProjectId", expected "$_projectId"');
    }
  }
}
