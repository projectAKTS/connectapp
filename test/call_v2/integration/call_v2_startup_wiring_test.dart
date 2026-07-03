import 'dart:io';

import 'package:connect_app/call_v2/call_v2_runtime_configuration.dart';
import 'package:connect_app/call_v2/production/call_v2_final_readiness_audit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('actual startup wiring', () {
    test('main references only the isolated integration shell', () {
      final source = _mainSource();

      expect(
        source,
        contains("import 'call_v2/integration/call_v2_app_integration.dart';"),
      );
      expect(
        source,
        contains('unawaited(initializeCallV2AppIntegrationShellSafely());'),
      );
      expect(source.contains('call_v2/production'), isFalse);
      expect(source.contains('call_v2/startup'), isFalse);
      expect(source.contains('call_v2/ui'), isFalse);
      expect(source.contains('CallV2ProductionComposition'), isFalse);
      expect(source.contains('ProductionCallV2StartupBridge'), isFalse);
      expect(source.contains('ProductionCallV2UiCoordinator'), isFalse);
    });

    test('Firebase initialization and app root ordering are preserved', () {
      final source = _mainFunctionSource();

      final bindingIndex =
          source.indexOf('WidgetsFlutterBinding.ensureInitialized();');
      final firebaseIndex = source.indexOf('await Firebase.initializeApp(');
      final appCheckIndex =
          source.indexOf('await FirebaseAppCheck.instance.activate(');
      final messagingIndex =
          source.indexOf('FirebaseMessaging.onBackgroundMessage');
      final notificationIndex = source.indexOf('notificationService =');
      final callV2Index =
          source.indexOf('initializeCallV2AppIntegrationShellSafely');
      final runAppIndex = source.indexOf('runApp(const MyApp())');

      expect(bindingIndex, greaterThanOrEqualTo(0));
      expect(firebaseIndex, greaterThan(bindingIndex));
      expect(appCheckIndex, greaterThan(firebaseIndex));
      expect(messagingIndex, greaterThan(appCheckIndex));
      expect(notificationIndex, greaterThan(messagingIndex));
      expect(callV2Index, greaterThan(notificationIndex));
      expect(runAppIndex, greaterThan(callV2Index));
    });

    test('startup does not await Call V2 and cannot fail app launch', () {
      final source = _mainSource();
      final shellSource = _read(
        'lib/call_v2/integration/call_v2_app_integration.dart',
      );

      expect(source.contains('await initializeCallV2AppIntegration'), isFalse);
      expect(
        source,
        contains('unawaited(initializeCallV2AppIntegrationShellSafely());'),
      );
      expect(shellSource, contains('try {'));
      expect(shellSource, contains('} catch (_) {'));
    });

    test('no global Call V2 service locator or singleton is retained', () {
      final source = _mainSource();

      for (final forbidden in <String>[
        'late final CallV2',
        'static final CallV2',
        'GetIt',
        'Provider<CallV2',
        'MultiProvider',
        'callV2Integration =',
        'CallV2ProductionComposition(',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('route table contains no Call V2 user-facing entries', () {
      final source = _mainSource();

      for (final forbidden in <String>[
        "'/call-v2'",
        "'/call_v2'",
        "'/v2-call'",
        'CallV2Screen',
        'IncomingCallV2',
        'ActiveCallV2',
        'CallV2RouteIntent',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });
  });

  group('readiness regression', () {
    test('Phase 4 readiness remains distinct from actual rollout', () {
      final result = const CallV2FinalReadinessAuditor().audit(
        configuration: _productionConfig(),
      );
      final gate = const CallV2FinalReadinessAuditor().evaluateRolloutGate(
        configuration: _productionConfig(),
      );

      expect(result.readyForAdapterImplementation, isTrue);
      expect(result.readyForProductionEnablement, isTrue);
      expect(result.readyForActualRollout, isFalse);
      expect(result.appStartupWired, isFalse);
      expect(result.realRoutesWired, isFalse);
      expect(result.realScreensWired, isFalse);
      expect(result.productionTelemetryWired, isFalse);
      expect(gate.status, CallV2RolloutGateStatus.closed);
    });
  });
}

String _mainSource() => _read('lib/main.dart');

String _mainFunctionSource() {
  final source = _mainSource();
  final start = source.indexOf('Future<void> main() async {');
  final end = source.indexOf('void _handlePurchaseUpdates');
  expect(start, greaterThanOrEqualTo(0));
  expect(end, greaterThan(start));
  return source.substring(start, end);
}

String _read(String path) => File(path).readAsStringSync();

CallV2RuntimeConfiguration _productionConfig() {
  return CallV2RuntimeConfiguration(
    enabled: true,
    environment: CallV2Environment.production,
    rtcProvider: CallV2RtcProviderKind.agora,
    rtcAppIdReference: 'CALL_V2_AGORA_APP_ID_REFERENCE',
    callCollectionName: 'calls',
    participantSubcollectionName: 'participants',
    rtcTokenMaxLifetime: callV2AcceptedRtcTokenMaxLifetime,
    minimumTokenRemainingValidity: const Duration(seconds: 60),
  );
}
