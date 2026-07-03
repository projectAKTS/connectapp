import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_app_integration.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_app_integration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rollout policy', () {
    test('production rollout constant is compile-time false', () {
      expect(CallV2RolloutPolicy.productionEnabled, isFalse);

      final source = _read(
        'lib/call_v2/integration/call_v2_rollout_policy.dart',
      );
      expect(source, contains('static const bool productionEnabled = false;'));
    });

    test('policy is immutable and has no runtime override surface', () {
      final source = _read(
        'lib/call_v2/integration/call_v2_rollout_policy.dart',
      );

      for (final forbidden in <String>[
        'static bool',
        'set productionEnabled',
        'bool.fromEnvironment',
        'String.fromEnvironment',
        'Platform.environment',
        'RemoteConfig',
        'FirebaseRemoteConfig',
        'FirebaseFirestore',
        'SharedPreferences',
        'kDebugMode',
        'kProfileMode',
        'kReleaseMode',
        'flavor',
        'Flavor',
        'callback',
        'enable(',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });
  });

  group('disabled integration', () {
    test('constructor, initialize, and dispose are side-effect free', () async {
      const integration = DisabledCallV2AppIntegration();

      await integration.initialize();
      await integration.initialize();
      await integration.dispose();
      await integration.dispose();
    });

    test('dispose before initialize is safe', () async {
      await const DisabledCallV2AppIntegration().dispose();
    });

    test('startup shell returns while disabled and does not throw', () async {
      await initializeCallV2AppIntegrationShell();
      await initializeCallV2AppIntegrationShellSafely();
    });

    test('integration sources contain no live service access', () {
      final source = _integrationSource();

      for (final forbidden in <String>[
        'FirebaseAuth.instance',
        'FirebaseFirestore.instance',
        'FirebaseFunctions.instance',
        'FirebaseFunctions.instanceFor',
        'FirebaseAppCheck.instance',
        'Permission.',
        'requestPermission',
        'RtcEngine',
        'createAgora',
        'CallV2ProductionComposition',
        'ProductionCallV2StartupBridge',
        'ProductionCallV2UiCoordinator',
        'CallV2Runtime(',
        'Navigator',
        'registerRoute',
        'routes:',
        'StreamSubscription',
        'WidgetsBindingObserver',
        'FirebaseAnalytics',
        'FirebaseCrashlytics',
        'Sentry',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('rollout check precedes disabled implementation construction', () {
      final source = _read(
        'lib/call_v2/integration/call_v2_app_integration.dart',
      );
      final policyIndex =
          source.indexOf('CallV2RolloutPolicy.productionEnabled');
      final disabledIndex = source.indexOf('DisabledCallV2AppIntegration');

      expect(policyIndex, greaterThanOrEqualTo(0));
      expect(disabledIndex, greaterThan(policyIndex));
    });
  });

  group('repository isolation', () {
    test('no real Call V2 routes, screens, or external telemetry were added',
        () {
      _expectFileDoesNotContain('lib/navigation/app_router.dart', <String>[
        'call_v2',
        'CallV2',
      ]);
      _expectDirectoryDoesNotContain('lib/screens', <String>[
        'call_v2/integration',
        'call_v2/production',
        'CallV2ProductionComposition',
        'ProductionCallV2StartupBridge',
        'ProductionCallV2UiCoordinator',
      ]);
      _expectDirectoryDoesNotContain('lib/services', <String>[
        'call_v2/integration',
        'call_v2/production',
        'CallV2ProductionComposition',
        'ProductionCallV2StartupBridge',
        'ProductionCallV2UiCoordinator',
      ]);

      final source = _integrationSource();
      for (final forbidden in <String>[
        'FirebaseAnalytics',
        'FirebaseCrashlytics',
        'Sentry',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });
  });
}

String _integrationSource() {
  return <String>[
    'lib/call_v2/integration/call_v2_rollout_policy.dart',
    'lib/call_v2/integration/call_v2_app_integration.dart',
    'lib/call_v2/integration/disabled_call_v2_app_integration.dart',
  ].map(_read).join('\n');
}

String _read(String path) => File(path).readAsStringSync();

void _expectFileDoesNotContain(String path, List<String> forbiddenValues) {
  final source = _read(path);
  for (final forbidden in forbiddenValues) {
    expect(source.contains(forbidden), isFalse, reason: '$path $forbidden');
  }
}

void _expectDirectoryDoesNotContain(
  String path,
  List<String> forbiddenValues,
) {
  final directory = Directory(path);
  if (!directory.existsSync()) return;

  final source = directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.readAsStringSync())
      .join('\n');
  for (final forbidden in forbiddenValues) {
    expect(source.contains(forbidden), isFalse, reason: '$path $forbidden');
  }
}
