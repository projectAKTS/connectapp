import 'dart:async';
import 'dart:ui';

import 'package:connect_app/services/app_prefs.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Crash reporting and product analytics for the MVP: where people get stuck
/// and what crashes. Events carry no personal data (no names, emails, text).
///
/// Both are off until the user turns them on in Settings, and neither is
/// linked to the account. Native collection is off in Info.plist /
/// AndroidManifest too, so nothing is sent before this runs; the SDKs keep
/// the user's later choice across restarts. While crash reports are off,
/// reports the SDK cached on the device are deleted, never sent.
class AppTelemetry {
  AppTelemetry._();

  static bool _started = false;

  /// [AppPrefs] key for the user's usage-statistics choice.
  static const String usageStatsPrefKey = 'usageStats';

  static bool get usageStatsEnabled =>
      AppPrefs.getBool(usageStatsPrefKey) ?? false;

  /// [AppPrefs] key for the user's crash-report choice.
  static const String crashReportsPrefKey = 'crashReports';

  static bool get crashReportsEnabled =>
      AppPrefs.getBool(crashReportsPrefKey) ?? false;

  /// Saves the user's crash-report choice and applies it.
  static Future<void> setCrashReportsEnabled(bool enabled) async {
    await AppPrefs.set(crashReportsPrefKey, enabled);
    await _applyCrashReports();
  }

  static Future<void> _applyCrashReports() async {
    final on = crashReportsEnabled && !kDebugMode;
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setCrashlyticsCollectionEnabled(on);
      if (!on) await crashlytics.deleteUnsentReports();
    } catch (_) {}
  }

  /// Saves the user's choice and applies it.
  static Future<void> setUsageStatsEnabled(bool enabled) async {
    await AppPrefs.set(usageStatsPrefKey, enabled);
    try {
      await FirebaseAnalytics.instance
          .setAnalyticsCollectionEnabled(enabled && !kDebugMode);
    } catch (_) {}
  }

  /// Call once, right after Firebase.initializeApp in main().
  static Future<void> init() async {
    if (_started) return;
    _started = true;
    try {
      await _applyCrashReports();
      // Errors are only handed to Crashlytics while the user allows it, so
      // nothing is even cached on the device otherwise.
      final previousFlutterOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        previousFlutterOnError?.call(details);
        if (crashReportsEnabled && !kDebugMode) {
          unawaited(
              FirebaseCrashlytics.instance.recordFlutterFatalError(details));
        }
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        if (crashReportsEnabled && !kDebugMode) {
          unawaited(FirebaseCrashlytics.instance
              .recordError(error, stack, fatal: true));
        }
        return true;
      };
      await FirebaseAnalytics.instance
          .setAnalyticsCollectionEnabled(usageStatsEnabled && !kDebugMode);
      FirebaseAuth.instance.authStateChanges().listen((u) => setUser(u?.uid));
    } catch (e) {
      debugPrint('Telemetry start failed: $e');
    }
  }

  static Future<void> setUser(String? uid) async {
    try {
      // Neither crash reports nor usage statistics are linked to the
      // account; this clears ids set by older builds.
      await FirebaseCrashlytics.instance.setUserIdentifier('');
      await FirebaseAnalytics.instance.setUserId(id: null);
    } catch (_) {}
  }

  /// Screen views from named routes.
  static NavigatorObserver get observer =>
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance);

  /// One product event; [params] must not contain personal data.
  static void event(String name, [Map<String, Object>? params]) {
    unawaited(() async {
      try {
        await FirebaseAnalytics.instance
            .logEvent(name: name, parameters: params);
      } catch (_) {}
    }());
  }
}
