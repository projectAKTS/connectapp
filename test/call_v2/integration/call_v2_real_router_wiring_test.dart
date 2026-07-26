import 'dart:io';

import 'package:connect_app/call_v2/call_v2_runtime_configuration.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/production/call_v2_final_readiness_audit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('real root router wiring', () {
    test('main references the isolated route registry', () {
      final source = _mainSource();

      expect(
        source,
        contains("import 'call_v2/integration/call_v2_route_registry.dart';"),
      );
      expect(source, contains('resolveCallV2Route(settings)'));
      expect(source.contains('call_v2/production'), isFalse);
      expect(source.contains('call_v2/startup'), isFalse);
      expect(source.contains('call_v2/ui'), isFalse);
      expect(source.contains('CallV2ProductionComposition'), isFalse);
      expect(source.contains('ProductionCallV2StartupBridge'), isFalse);
      expect(source.contains('ProductionCallV2UiCoordinator'), isFalse);
    });

    test('existing route entries remain present and unchanged', () {
      final source = _mainSource();

      for (final route in <String>[
        "'/': (_) => const AuthGate()",
        "'/home': (_) => const MainScaffold()",
        "'/login': (_) => const FullScreenBackGesture(child: LoginScreen())",
        "'/register': (_) => const FullScreenBackGesture(child: SignupScreen())",
        "'/forgot-password': (_) =>",
        "'/create_post': (_) =>",
        "'/search': (_) => const FullScreenBackGesture(child: SearchScreen())",
        "'/edit_post': (_) =>",
        "'/my_consultations': (_) =>",
        "'/premium': (_) => FullScreenBackGesture(child: PremiumScreen())",
        "'/onboarding': (_) =>",
        "'/paymentSetup': (_) =>",
      ]) {
        expect(source, contains(route), reason: route);
      }
    });

    test('Call V2 fallback is after existing special route cases', () {
      final source = _onGenerateRouteSource();

      final profileIndex = source.indexOf("uri.pathSegments[0] == 'profile'");
      final postIndex = source.indexOf("uri.pathSegments[0] == 'post'");
      final consultationIndex =
          source.indexOf("settings.name == '/consultation'");
      final chatIndex = source.indexOf("settings.name == '/chat'");
      final callV2Index = source.indexOf('resolveCallV2Route(settings)');
      final returnNullIndex = source.lastIndexOf('return null;');

      expect(callV2Index, greaterThan(profileIndex));
      expect(callV2Index, greaterThan(postIndex));
      expect(callV2Index, greaterThan(consultationIndex));
      expect(callV2Index, greaterThan(chatIndex));
      expect(returnNullIndex, greaterThan(callV2Index));
    });

    test('unknown route behavior remains AuthGate fallback', () {
      final source = _mainSource();
      final unknownIndex = source.indexOf('onUnknownRoute: (settings)');
      final authGateIndex =
          source.indexOf('builder: (_) => const AuthGate()', unknownIndex);

      expect(unknownIndex, greaterThanOrEqualTo(0));
      expect(authGateIndex, greaterThan(unknownIndex));
    });

    test('tab router remains separate and does not reference Call V2', () {
      final source = _read('lib/navigation/app_router.dart');

      expect(source.contains('call_v2'), isFalse);
      expect(source.contains('CallV2'), isFalse);
      expect(source.contains('resolveCallV2Route'), isFalse);
    });

    test('main route table has no Call V2 destination entries', () {
      final source = _mainSource();

      for (final forbidden in <String>[
        "'${CallV2RouteNames.connecting}'",
        "'${CallV2RouteNames.ready}'",
        'CallV2Screen',
        'CallV2Connecting',
        'CallV2Active',
        'IncomingCallV2',
        'ActiveCallV2',
        'Scaffold(body: Center(child: Text(',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });
  });

  group('no screens and no external entry points', () {
    test('no Call V2 screen files or deep-link/notification routing were added',
        () {
      final callV2Files = Directory('lib/call_v2')
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.path)
          .toList();

      for (final path in callV2Files) {
        if (path.endsWith('call_v2_dev_screen.dart')) continue;
        if (path.endsWith('call_v2_dev_screen_factory.dart')) continue;
        expect(path, isNot(contains('screen')), reason: path);
      }

      final source = _mainSource();
      for (final forbidden in <String>[
        'FirebaseDynamicLinks.instance.onLink.listen((data) {\n'
            '      final uri = data.link;\n'
            '      final ctx = navigatorKey.currentContext;\n'
            '      if (ctx == null) return;\n'
            '\n'
            "      if (uri.path == '/call-v2",
        'incoming_call_v2',
        'call_v2_notification',
        'CallV2RouteIntent',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('registry does not parse route payload while disabled', () {
      final source = _read(
        'lib/call_v2/integration/call_v2_route_registry.dart',
      );

      for (final forbidden in <String>[
        'settings.arguments',
        'as Map',
        'CallV2UiLaunchRequest',
        'CallV2StartupRequest',
        'callId',
        'uid',
        'debugPrint',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });
  });

  group('startup and readiness regression', () {
    test('Phase 5A startup shell remains unawaited', () {
      final source = _mainSource();

      expect(
        source,
        contains('unawaited(initializeCallV2AppIntegrationShellSafely());'),
      );
      expect(source.contains('await initializeCallV2AppIntegration'), isFalse);
    });

    test('actual rollout readiness remains false and gate closed', () {
      final result = const CallV2FinalReadinessAuditor().audit(
        configuration: _productionConfig(),
      );
      final gate = const CallV2FinalReadinessAuditor().evaluateRolloutGate(
        configuration: _productionConfig(),
      );

      expect(result.readyForAdapterImplementation, isTrue);
      expect(result.readyForProductionEnablement, isTrue);
      expect(result.readyForActualRollout, isFalse);
      expect(result.realRoutesWired, isFalse);
      expect(result.realScreensWired, isFalse);
      expect(result.productionTelemetryWired, isFalse);
      expect(gate.status, CallV2RolloutGateStatus.closed);
    });
  });
}

String _mainSource() => _read('lib/main.dart');

String _onGenerateRouteSource() {
  final source = _mainSource();
  final start = source.indexOf('onGenerateRoute: (settings) {');
  final end = source.indexOf('onUnknownRoute: (settings)');
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
