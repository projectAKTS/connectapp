import 'dart:io';

import 'package:connect_app/screens/settings/settings_screen.dart';
import 'package:connect_app/services/app_prefs.dart';
import 'package:connect_app/services/app_telemetry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => AppPrefs.debugSetForTest({}));

  testWidgets('crash reports and usage statistics start off; choices persist',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    SwitchListTile toggle(String key) =>
        tester.widget<SwitchListTile>(find.byKey(Key(key)));
    expect(toggle('settings_crash_reports').value, isFalse);
    expect(toggle('settings_usage_stats').value, isFalse);
    expect(AppTelemetry.crashReportsEnabled, isFalse);

    await tester.tap(find.byKey(const Key('settings_crash_reports')));
    await tester.pumpAndSettle();
    expect(AppPrefs.getBool(AppTelemetry.crashReportsPrefKey), isTrue);
    expect(AppTelemetry.crashReportsEnabled, isTrue);

    await tester.tap(find.byKey(const Key('settings_crash_reports')));
    await tester.pumpAndSettle();
    expect(AppTelemetry.crashReportsEnabled, isFalse);
  });

  test('native collection is off before the app code runs', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    for (final key in [
      'firebase_crashlytics_collection_enabled',
      'firebase_analytics_collection_enabled',
      'google_analytics_adid_collection_enabled',
    ]) {
      expect(
          manifest,
          matches(RegExp('android:name="$key"\\s*\\n\\s*'
              'android:value="false"')),
          reason: key);
    }
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    for (final key in [
      'FirebaseCrashlyticsCollectionEnabled',
      'FIREBASE_ANALYTICS_COLLECTION_ENABLED',
    ]) {
      expect(plist, matches(RegExp('<key>$key</key>\\s*<false/>')),
          reason: key);
    }
  });

  test('telemetry never links reports to the account', () {
    final src = File('lib/services/app_telemetry.dart').readAsStringSync();
    expect(src, isNot(contains('setUserIdentifier(uid')));
    expect(src, contains("setUserIdentifier('')"));
    expect(src, contains('setUserId(id: null)'));
    expect(src, contains('deleteUnsentReports'));
  });
}
