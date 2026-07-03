import 'dart:async';
import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/call_v2_contract_manifest.dart';
import 'package:connect_app/call_v2/call_v2_production_capabilities.dart';
import 'package:connect_app/call_v2/call_v2_production_readiness.dart';
import 'package:connect_app/call_v2/call_v2_runtime_configuration.dart';
import 'package:connect_app/call_v2/observability/call_v2_diagnostic_event.dart';
import 'package:connect_app/call_v2/observability/call_v2_diagnostic_sink.dart';
import 'package:connect_app/call_v2/observability/call_v2_observability.dart';
import 'package:connect_app/call_v2/observability/call_v2_observability_capabilities.dart';
import 'package:connect_app/call_v2/observability/production_call_v2_observer.dart';
import 'package:connect_app/call_v2/production/call_v2_production_composition.dart';
import 'package:connect_app/call_v2/startup/call_v2_startup_bridge.dart';
import 'package:connect_app/call_v2/startup/production_call_v2_startup_bridge.dart';
import 'package:connect_app/call_v2/ui/call_v2_ui_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('construction and isolation', () {
    test('constructor has no side effects and performs no sink write', () {
      final sink = _RecordingSink();

      ProductionCallV2Observer(
        sink: sink,
        isEnabled: () => true,
      );

      expect(sink.events, isEmpty);
    });

    test('source has no singleton, external telemetry, console, or persistence',
        () {
      final source = _observabilitySource();

      for (final forbidden in <String>[
        '.instance',
        'FirebaseAnalytics',
        'FirebaseCrashlytics',
        'Sentry',
        'print(',
        'debugPrint',
        'developer.log',
        'File(',
        'Directory(',
        'HttpClient',
        'Socket',
        'package:http',
        'dart:io',
        'Platform.environment',
        'String.fromEnvironment',
        'Secret',
        'secret',
        'token',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('main, route, screen, and service sources remain unwired', () {
      for (final path in <String>[
        'lib/main.dart',
        'lib/navigation/app_router.dart',
      ]) {
        final file = File(path);
        if (!file.existsSync()) continue;
        final source = file.readAsStringSync();
        expect(source.contains('call_v2/observability'), isFalse, reason: path);
        expect(source.contains('ProductionCallV2Observer'), isFalse,
            reason: path);
      }

      for (final directoryPath in <String>['lib/screens', 'lib/services']) {
        final directory = Directory(directoryPath);
        if (!directory.existsSync()) continue;
        final source = directory
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .map((file) => file.readAsStringSync())
            .join('\n');
        expect(source.contains('call_v2/observability'), isFalse,
            reason: directoryPath);
        expect(source.contains('ProductionCallV2Observer'), isFalse,
            reason: directoryPath);
      }
    });
  });

  group('event safety', () {
    test('event model exposes no identifier or raw metadata fields', () {
      final source = File(
        'lib/call_v2/observability/call_v2_diagnostic_event.dart',
      ).readAsStringSync();

      for (final forbidden in <String>[
        'metadata',
        'details',
        'message',
        'exception',
        'StackTrace',
        'callId',
        'uid',
        'Uid',
        'channelName',
        'rtcUid',
        'rtcToken',
        'appCheckToken',
        'projectId',
        'firestorePath',
        'providerError',
        'firebase',
        'agora',
        'DateTime',
        'Duration',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('safe debug representation contains only enums and booleans', () {
      const event = CallV2DiagnosticEvent(
        category: CallV2DiagnosticCategory.uiFlow,
        outcome: CallV2DiagnosticOutcome.failed,
        stage: CallV2DiagnosticStage.launch,
        errorCode: CallV2ClientErrorCode.unavailable,
        isVideo: true,
        localRole: CallV2LocalParticipantRole.caller,
        retryAttempted: false,
        cleanupAttempted: true,
        cleanupSucceeded: false,
      );

      final debugMap = event.toSafeDebugMap();

      expect(debugMap, <String, Object?>{
        'category': 'uiFlow',
        'outcome': 'failed',
        'stage': 'launch',
        'errorCode': 'unavailable',
        'isVideo': true,
        'localRole': 'caller',
        'retryAttempted': false,
        'cleanupAttempted': true,
        'cleanupSucceeded': false,
      });
      expect(
        debugMap.values,
        everyElement(anyOf(isA<String>(), isA<bool>())),
      );
      _expectNoUnsafeContent(debugMap.toString());
      _expectNoUnsafeContent(event.toString());
    });

    test('controlled error representation includes only client error code', () {
      const event = CallV2DiagnosticEvent(
        category: CallV2DiagnosticCategory.runtime,
        outcome: CallV2DiagnosticOutcome.rejected,
        errorCode: CallV2ClientErrorCode.unauthorized,
      );

      expect(event.toSafeDebugMap(), <String, Object?>{
        'category': 'runtime',
        'outcome': 'rejected',
        'errorCode': 'unauthorized',
      });
      expect(event.toString(), isNot(contains('message')));
      expect(event.toString(), isNot(contains('details')));
    });
  });

  group('feature gate', () {
    test('disabled observer completes successfully with zero sink writes',
        () async {
      final sink = _RecordingSink();
      final observer = ProductionCallV2Observer(
        sink: sink,
        isEnabled: () => false,
      );

      await observer.record(_event());

      expect(sink.events, isEmpty);
    });

    test('enabled observer writes exactly once', () async {
      final sink = _RecordingSink();
      final observer = ProductionCallV2Observer(
        sink: sink,
        isEnabled: () => true,
      );

      await observer.record(_event());

      expect(sink.events, <CallV2DiagnosticEvent>[_event()]);
    });

    test('dynamic authoritative gate changes are respected', () async {
      var enabled = false;
      final sink = _RecordingSink();
      final observer = ProductionCallV2Observer(
        sink: sink,
        isEnabled: () => enabled,
      );

      await observer.record(_event());
      enabled = true;
      await observer.record(_event(outcome: CallV2DiagnosticOutcome.succeeded));

      expect(sink.events, hasLength(1));
      expect(sink.events.single.outcome, CallV2DiagnosticOutcome.succeeded);
    });
  });

  group('failure isolation', () {
    test('sink exception does not escape and is not retried', () async {
      final sink = _RecordingSink(error: StateError('boom'));
      final observer = ProductionCallV2Observer(
        sink: sink,
        isEnabled: () => true,
      );

      await observer.record(_event());

      expect(sink.writeCount, 1);
    });

    test('sink controlled error does not escape and is not retried', () async {
      final sink = _RecordingSink(
        error: const CallV2ClientError(CallV2ClientErrorCode.unavailable),
      );
      final observer = ProductionCallV2Observer(
        sink: sink,
        isEnabled: () => true,
      );

      await observer.record(_event());

      expect(sink.writeCount, 1);
    });

    test('concurrent explicit writes remain independent', () async {
      final sink = _RecordingSink();
      final observer = ProductionCallV2Observer(
        sink: sink,
        isEnabled: () => true,
      );

      await Future.wait(<Future<void>>[
        observer.record(_event(stage: CallV2DiagnosticStage.start)),
        observer.record(_event(stage: CallV2DiagnosticStage.stop)),
      ]);

      expect(sink.events, hasLength(2));
      expect(
        sink.events.map((event) => event.stage),
        containsAll(<CallV2DiagnosticStage>[
          CallV2DiagnosticStage.start,
          CallV2DiagnosticStage.stop,
        ]),
      );
    });

    test('observer failure does not alter caller state', () async {
      var callerState = 'before';
      final observer = ProductionCallV2Observer(
        sink: _RecordingSink(error: StateError('sink failed')),
        isEnabled: () => true,
      );

      await observer.record(_event());
      callerState = 'after';

      expect(callerState, 'after');
    });
  });

  group('no-op behavior', () {
    test('no-op observer completes successfully and exposes no data', () async {
      const observer = CallV2NoopObserver();

      await observer.record(_event());

      expect(observer.toString(), isNot(contains('callA')));
      expect(observer.toString(), isNot(contains('uid')));
      expect(observer.toString(), isNot(contains('token')));
    });
  });

  group('optional integration hooks', () {
    test('no startup, UI, RTC, or cleanup hooks were added in this phase', () {
      for (final path in <String>[
        'lib/call_v2/startup/production_call_v2_startup_bridge.dart',
        'lib/call_v2/ui/production_call_v2_ui_coordinator.dart',
        'lib/call_v2/rtc/production/production_call_v2_rtc_adapter.dart',
        'lib/call_v2/production/call_v2_production_composition.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('CallV2Observer'), isFalse, reason: path);
        expect(source.contains('ProductionCallV2Observer'), isFalse,
            reason: path);
      }
    });
  });

  group('capability and readiness', () {
    test('isolated observability capabilities are production complete', () {
      expect(
        callV2IsolatedObservabilityCapabilities.callableApiAdapterAvailable,
        isTrue,
      );
      expect(
        callV2IsolatedObservabilityCapabilities
            .firestoreSnapshotSourceAvailable,
        isTrue,
      );
      expect(
        callV2IsolatedObservabilityCapabilities.rtcConfigProviderAvailable,
        isTrue,
      );
      expect(
          callV2IsolatedObservabilityCapabilities.rtcAdapterAvailable, isTrue);
      expect(
        callV2IsolatedObservabilityCapabilities.authIdentitySourceAvailable,
        isTrue,
      );
      expect(callV2IsolatedObservabilityCapabilities.appCheckAvailable, isTrue);
      expect(
        callV2IsolatedObservabilityCapabilities.permissionGatewayAvailable,
        isTrue,
      );
      expect(
        callV2IsolatedObservabilityCapabilities.runtimeStartupBridgeAvailable,
        isTrue,
      );
      expect(
        callV2IsolatedObservabilityCapabilities.uiRouteIntegrationAvailable,
        isTrue,
      );
      expect(
        callV2IsolatedObservabilityCapabilities.observabilityAvailable,
        isTrue,
      );
      expect(
        callV2IsolatedObservabilityCapabilities.nativeCallIntegrationAvailable,
        isFalse,
      );
    });

    test('accepted auditor reports readiness for valid enabled config', () {
      final result = const CallV2ProductionReadinessAuditor().audit(
        manifest: callV2Phase3ContractManifest,
        configuration: _productionConfig(),
        capabilities: callV2IsolatedObservabilityCapabilities,
      );

      expect(result.readyForAdapterImplementation, isTrue);
      expect(result.readyForProductionEnablement, isTrue);
      expect(result.issues, isEmpty);
    });

    test('previous capability constants and no-capabilities constant unchanged',
        () {
      expect(
        callV2IsolatedStartupBridgeCapabilities.uiRouteIntegrationAvailable,
        isFalse,
      );
      expect(
        callV2IsolatedStartupBridgeCapabilities.observabilityAvailable,
        isFalse,
      );
      expect(
        callV2IsolatedUiRouteIntegrationCapabilities.observabilityAvailable,
        isFalse,
      );
      expect(
        callV2IsolatedProductionCompositionCapabilities
            .runtimeStartupBridgeAvailable,
        isFalse,
      );
      expect(
        callV2IsolatedProductionCompositionCapabilities
            .uiRouteIntegrationAvailable,
        isFalse,
      );
      expect(
        callV2IsolatedProductionCompositionCapabilities.observabilityAvailable,
        isFalse,
      );
      expect(callV2NoProductionCapabilities.toSafeDebugMap().values,
          everyElement(false));
    });

    test('auditor and manifest remain unchanged', () {
      final source = File(
        'lib/call_v2/call_v2_production_readiness.dart',
      ).readAsStringSync();

      expect(source.contains('observabilityAvailable'), isTrue);
      expect(source.contains('nativeCallIntegrationAvailable &&'), isFalse);
      expect(callV2Phase3ContractManifest.productionAdaptersAbsent, isTrue);
      expect(
        callV2Phase3ContractManifest.startupUiRoutesNativeWiringAbsent,
        isTrue,
      );
    });
  });
}

CallV2DiagnosticEvent _event({
  CallV2DiagnosticOutcome outcome = CallV2DiagnosticOutcome.started,
  CallV2DiagnosticStage stage = CallV2DiagnosticStage.launch,
}) {
  return CallV2DiagnosticEvent(
    category: CallV2DiagnosticCategory.startup,
    outcome: outcome,
    stage: stage,
    isVideo: false,
    localRole: CallV2LocalParticipantRole.callee,
  );
}

CallV2RuntimeConfiguration _productionConfig() {
  return const CallV2RuntimeConfiguration(
    enabled: true,
    environment: CallV2Environment.production,
    rtcProvider: CallV2RtcProviderKind.agora,
    rtcAppIdReference: 'CALL_V2_AGORA_APP_ID_REFERENCE',
    callCollectionName: 'calls',
    participantSubcollectionName: 'participants',
    rtcTokenMaxLifetime: callV2AcceptedRtcTokenMaxLifetime,
    minimumTokenRemainingValidity: Duration(seconds: 60),
  );
}

String _observabilitySource() {
  return Directory('lib/call_v2/observability')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.readAsStringSync())
      .join('\n');
}

void _expectNoUnsafeContent(String text) {
  for (final forbidden in <String>[
    'callA',
    'uid',
    'remoteUser',
    'channel',
    'token',
    'calls/',
    'FirebaseException',
    'Agora',
    'StackTrace',
    'project',
    'path',
    'payload',
  ]) {
    expect(text, isNot(contains(forbidden)), reason: forbidden);
  }
}

class _RecordingSink implements CallV2DiagnosticSink {
  _RecordingSink({this.error});

  final Object? error;
  final events = <CallV2DiagnosticEvent>[];
  int writeCount = 0;

  @override
  Future<void> write(CallV2DiagnosticEvent event) async {
    writeCount += 1;
    events.add(event);
    final thrown = error;
    if (thrown != null) throw thrown;
  }
}
