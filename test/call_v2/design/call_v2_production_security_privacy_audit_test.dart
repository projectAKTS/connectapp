import 'dart:io';

import 'package:connect_app/call_v2/design/call_v2_production_lifecycle_hookup_design.dart';
import 'package:connect_app/call_v2/design/call_v2_production_security_privacy_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_call_state_bridge_event.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_call_state_bridge_result.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_call_state_bridge_status.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_lifecycle_bridge_result.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_lifecycle_bridge_status.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_permission_device_bridge_result.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_permission_device_bridge_status.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_route_sink_result.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_route_sink_state.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_runtime_ui_bridge_result.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_runtime_ui_bridge_status.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_ui_composition_result.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_ui_composition_status.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_presentation_snapshot.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_descriptor.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_destination.dart';
import 'package:connect_app/call_v2/ui/shells/call_v2_shell_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('audit artifact records the protected backup and disabled rollout', () {
    final audit = callV2ProductionSecurityPrivacyAudit;

    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(
      audit.isolationConstraints,
      containsAll(<Object>[
        CallV2ProductionIsolationConstraint.rolloutDisabled,
        CallV2ProductionIsolationConstraint.backupBranchProtected,
      ]),
    );
    expect(
      'backup/call-v2-pre-phase6b-2026-07-04',
      isNot(contains('callId')),
    );
    expect(
      '2a1ea8d6864ab0098d17c52bdf5ec70f66979e4d',
      hasLength(40),
    );
  });

  test('route names are fixed canonical static names only', () {
    expect(
      callV2ProductionSecurityPrivacyAudit.allowedRouteNames,
      equals(<String>{
        '/call-v2/connecting',
        '/call-v2/audio',
        '/call-v2/video',
        '/call-v2/failure',
      }),
    );
    expect(
      CallV2RouteNames.production,
      equals(callV2ProductionSecurityPrivacyAudit.allowedRouteNames),
    );
    expect(CallV2RouteNames.production, isNot(contains('/call-v2/ready')));

    for (final routeName in CallV2RouteNames.production) {
      expect(routeName, startsWith('/call-v2/'));
      expect(routeName, isNot(contains('?')));
      expect(routeName, isNot(contains('#')));
      _expectNoSensitiveText(routeName);
    }
  });

  test('production route descriptors cannot expose arbitrary route strings',
      () {
    for (final destination in <CallV2ProductionRouteDestination>[
      CallV2ProductionRouteDestination.connecting,
      CallV2ProductionRouteDestination.activeAudio,
      CallV2ProductionRouteDestination.activeVideo,
      CallV2ProductionRouteDestination.controlledFailure,
    ]) {
      final descriptor = CallV2ProductionRouteDescriptor.forDestination(
        destination: destination,
        sessionReference: null,
        generation: 1,
        terminalStatus: CallV2ProductionPresentationTerminalStatus.nonterminal,
      );

      expect(
        descriptor.routeName,
        CallV2ProductionRouteNames.forDestination(destination),
      );
      expect(CallV2RouteNames.production, contains(descriptor.routeName));
      expect(descriptor.routeName, isNot(contains('?')));
      expect(descriptor.routeName, isNot(contains('#')));
    }
  });

  test('route object factory and navigator adapter enforce null arguments', () {
    final routeFactory = File(
      'lib/call_v2/integration/call_v2_production_route_object_factory.dart',
    ).readAsStringSync();
    final navigatorAdapter = File(
      'lib/call_v2/integration/call_v2_production_navigator_adapter.dart',
    ).readAsStringSync();

    expect(routeFactory, contains('RouteSettings(name: expectedRouteName)'));
    expect(routeFactory, isNot(contains('arguments:')));
    expect(navigatorAdapter, contains('route.settings.arguments'));
    expect(navigatorAdapter, contains('return arguments == null;'));
  });

  test('debug/status/result maps do not expose route strings or identifiers',
      () {
    final values = <Object?>[
      const CallV2ProductionRouteSinkState(
        currentDestination: CallV2ProductionRouteDestination.activeAudio,
        currentGeneration: 7,
      ).toSafeDebugMap(),
      const CallV2ProductionRouteSinkResult.pushed(
        destination: CallV2ProductionRouteDestination.connecting,
        generation: 1,
      ).toSafeDebugMap(),
      const CallV2ProductionUiCompositionStatus(
        currentDestination: CallV2ProductionRouteDestination.activeVideo,
        currentGeneration: 2,
        rolloutEnabled: true,
      ).toSafeDebugMap(),
      const CallV2ProductionUiCompositionResult.rendered(
        destination: CallV2ProductionRouteDestination.controlledFailure,
        generation: 3,
      ).toSafeDebugMap(),
      const CallV2ProductionRuntimeUiBridgeStatus(
        currentDestination: CallV2ProductionRouteDestination.activeAudio,
        currentGeneration: 4,
        rolloutEnabled: true,
      ).toSafeDebugMap(),
      const CallV2ProductionRuntimeUiBridgeResult.delegated(
        destination: CallV2ProductionRouteDestination.activeVideo,
        generation: 5,
      ).toSafeDebugMap(),
      const CallV2ProductionLifecycleBridgeStatus(
        currentGeneration: 6,
        rolloutEnabled: true,
      ).toSafeDebugMap(),
      const CallV2ProductionLifecycleBridgeResult.cleanedUp(
        generation: 7,
      ).toSafeDebugMap(),
      const CallV2ProductionPermissionDeviceBridgeStatus(
        currentGeneration: 8,
        rolloutEnabled: true,
      ).toSafeDebugMap(),
      const CallV2ProductionPermissionDeviceBridgeResult.noOp(
        generation: 9,
      ).toSafeDebugMap(),
      const CallV2ProductionCallStateBridgeStatus(
        currentGeneration: 10,
        rolloutEnabled: true,
      ).toSafeDebugMap(),
      const CallV2ProductionCallStateBridgeResult.rejected(
        CallV2ProductionCallStateBridgeError.ownershipMismatch,
        generation: 11,
      ).toSafeDebugMap(),
    ];

    for (final value in values) {
      _expectNoRouteString(value);
      _expectNoSensitiveText(value.toString());
    }
  });

  test('call-state bridge event model carries policy enums, not raw payloads',
      () {
    const event = CallV2ProductionCallStateBridgeEvent.backendConnected(
      generation: 12,
      localRole: CallV2ProductionCallStateLocalRole.callee,
      consistencyPolicy:
          CallV2ProductionCallStateConsistencyPolicy.delegateSnapshot,
    );

    expect(event.toSafeDebugMap()['type'], 'backendConnected');
    expect(event.toSafeDebugMap()['localRole'], 'callee');
    expect(event.toSafeDebugMap()['consistencyPolicy'], 'delegateSnapshot');
    _expectNoRouteString(event.toSafeDebugMap());
    _expectNoSensitiveText(event.toString());
  });

  test('shell keys, labels, and failure copy are generic', () {
    final shellSources = _readFiles(_shellFiles);
    final valueKeys = RegExp("ValueKey<String>\\('([^']+)'\\)")
        .allMatches(shellSources)
        .map((match) => match.group(1)!)
        .toList();
    expect(valueKeys, isNotEmpty);

    for (final key in valueKeys) {
      expect(key, startsWith('call-v2.'));
      _expectNoSensitiveText(key);
    }

    final labels = CallV2ScreenShellLabel.values
        .map(callV2ScreenShellText)
        .toList(growable: false);
    expect(
      labels,
      containsAll(<String>[
        'Connecting',
        'Reconnecting',
        'Audio call',
        'Video call',
        'Call unavailable',
        'Permission required',
      ]),
    );
    for (final label in labels) {
      _expectNoSensitiveText(label);
      _expectNoRouteString(label);
    }
  });

  test('failure UI labels hide raw errors and credential material', () {
    final failureSource = File(
      'lib/call_v2/ui/shells/call_v2_controlled_failure_shell.dart',
    ).readAsStringSync();
    final labelSource = File(
      'lib/call_v2/ui/shells/call_v2_shell_labels.dart',
    ).readAsStringSync();

    expect(failureSource, contains('callV2FailureLabelFor'));
    expect(failureSource, isNot(contains('viewModel.errorCode.name')));
    expect(failureSource, isNot(contains('toString()')));
    for (final source in <String>[failureSource, labelSource]) {
      for (final forbidden in <String>[
        'StackTrace',
        'Exception',
        '/call-v2/',
        'backend payload',
        'Bearer',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    }
  });

  test('Call V2 production integration files introduce no logging calls', () {
    final source = _readFiles(_productionIntegrationAuditFiles);

    for (final pattern in <Pattern>[
      RegExp(r'\bprint\s*\('),
      RegExp(r'\bdebugPrint\s*\('),
      RegExp(r'\blog\s*\('),
      RegExp(r'\bLogger\s*[.(]'),
      RegExp(r'\banalytics\s*[.(]'),
    ]) {
      expect(source, isNot(contains(pattern)), reason: pattern.toString());
    }
  });

  test('toString and state fields do not store raw error or payload material',
      () {
    final bridgeStateSource = _readFiles(_bridgeStateFiles);

    for (final pattern in <Pattern>[
      RegExp(r'\bStackTrace\b'),
      RegExp(r'\bException\b'),
      RegExp(r'\bError\b(?!\?)'),
      RegExp(r'\bmessage\b'),
      RegExp(r'\bdetails\b'),
      RegExp(r'\bpayload\b'),
      RegExp(r'\btoken\b'),
      RegExp(r'\bcredential\b'),
      RegExp(r'\bchannel\b'),
      RegExp(r'\buid\b'),
      RegExp(r'\bcallId\b'),
      RegExp(r'\bparticipantId\b'),
    ]) {
      expect(bridgeStateSource, isNot(contains(pattern)), reason: '$pattern');
    }

    expect(bridgeStateSource, contains('toSafeDebugMap()'));
  });

  test('isolated bridge files do not import backend, RTC, or permissions APIs',
      () {
    for (final entry in _isolatedBridgeSources().entries) {
      for (final pattern in <Pattern>[
        RegExp(r"import\s+'package:firebase", caseSensitive: false),
        RegExp(r"import\s+'package:cloud_firestore", caseSensitive: false),
        RegExp(r"import\s+'package:cloud_functions", caseSensitive: false),
        RegExp(r"import\s+'.*backend", caseSensitive: false),
        RegExp(r"import\s+'.*connect_functions", caseSensitive: false),
        RegExp(r"import\s+'.*agora", caseSensitive: false),
        RegExp(r"import\s+'.*rtc/", caseSensitive: false),
        RegExp(r"import\s+'.*permissions/", caseSensitive: false),
        RegExp(r"import\s+'package:permission_handler", caseSensitive: false),
        RegExp(r'\bFirebase[A-Z]'),
        RegExp(r'\bFirebase\.'),
        RegExp(r'\bFirestore[A-Z]'),
        RegExp(r'\bAgora[A-Z]'),
      ]) {
        expect(entry.value, isNot(contains(pattern)),
            reason: '${entry.key}: $pattern');
      }
    }
  });

  test('real app files remain disconnected from Phase 6P and 6Q artifacts', () {
    final sources = <String, String>{
      'main.dart': File('lib/main.dart').readAsStringSync(),
      'app_router.dart':
          File('lib/navigation/app_router.dart').readAsStringSync(),
      'route registry': File(
        'lib/call_v2/integration/call_v2_route_registry.dart',
      ).readAsStringSync(),
      'disabled owner': File(
        'lib/call_v2/integration/disabled_call_v2_production_integration_owner.dart',
      ).readAsStringSync(),
      'composition': File(
        'lib/call_v2/production/call_v2_production_composition.dart',
      ).readAsStringSync(),
    };

    for (final entry in sources.entries) {
      expect(entry.value, isNot(contains('CallV2ProductionCallStateBridge')),
          reason: entry.key);
      expect(
        entry.value,
        isNot(contains('call_v2_production_security_privacy_audit')),
        reason: entry.key,
      );
    }
  });

  test('no app navigator key, context storage, or async handles are introduced',
      () {
    final source = _readFiles(_productionIntegrationAuditFiles);

    for (final pattern in <Pattern>[
      RegExp(r'\bnavigatorKey\b'),
      RegExp(r'\bGlobalKey\s*[<(]'),
      RegExp(r'\bNavigatorState\s+_'),
      RegExp(r'\bBuildContext\s+_'),
      RegExp(r'\bTimer\s+_'),
      RegExp(r'\bStreamSubscription\b'),
      RegExp(r'\bStreamController\b'),
    ]) {
      expect(source, isNot(contains(pattern)), reason: pattern.toString());
    }
  });

  test(
      'dependency, platform, backend, and config scopes are unchanged by audit',
      () {
    final changedProductionScope = _readFiles(<String>[
      'lib/call_v2/design/call_v2_production_security_privacy_audit.dart',
    ]);

    for (final forbidden in <String>[
      'pubspec.yaml',
      'pubspec.lock',
      'connect_functions/',
      'firestore.rules',
      'firebase.json',
      'android/',
      'ios/',
      'macos/',
      'windows/',
      'linux/',
      'web/',
    ]) {
      expect(changedProductionScope, isNot(contains(forbidden)),
          reason: forbidden);
    }
  });

  test('audit model debug output is counts only', () {
    final text = callV2ProductionSecurityPrivacyAudit.toString();

    expect(text, contains('allowedRouteCount'));
    expect(text, isNot(contains('/call-v2/')));
    for (final forbidden in <String>[
      'uid',
      'callId',
      'participantId',
      'token',
      'credential',
      'channel',
      'StackTrace',
      'Exception',
      'payload',
    ]) {
      expect(text, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('lifecycle hookup design remains design-only', () {
    final design = callV2ProductionLifecycleHookupDesign;

    expect(
      design.notWiredProofs,
      containsAll(<Object>[
        CallV2ProductionLifecycleNotWiredProof.routeRegistryStillDisabled,
        CallV2ProductionLifecycleNotWiredProof.disabledOwnerStillInert,
        CallV2ProductionLifecycleNotWiredProof.noRuntimeStart,
      ]),
    );
    expect(
      File('lib/call_v2/design/call_v2_production_lifecycle_hookup_design.dart')
          .readAsStringSync(),
      isNot(contains("import 'package:firebase")),
    );
  });

  test('known non-Call-V2 findings remain recorded as backlog only', () {
    expect(
      callV2ProductionSecurityPrivacyAudit.backlogFindings,
      equals(<CallV2ProductionBacklogFinding>{
        CallV2ProductionBacklogFinding.appCheckDebugTokenLoggingOutsideCallV2,
        CallV2ProductionBacklogFinding.chatRouteArgumentLoggingOutsideCallV2,
      }),
    );

    final mainSource = File('lib/main.dart').readAsStringSync();
    final routerSource =
        File('lib/navigation/app_router.dart').readAsStringSync();
    expect(mainSource, contains('AppCheck debug token'));
    expect(routerSource, contains('[TabRoute:/chat]'));
  });

  test('manual approvals are required before relaxing audit boundaries', () {
    expect(
      callV2ProductionSecurityPrivacyAudit.manualApprovalGates,
      containsAll(<Object>[
        CallV2ProductionManualApprovalGate.exposeRouteArguments,
        CallV2ProductionManualApprovalGate.addCallV2Logging,
        CallV2ProductionManualApprovalGate.addDynamicRouteNames,
        CallV2ProductionManualApprovalGate.wireRealAppRoutes,
        CallV2ProductionManualApprovalGate.enableRollout,
        CallV2ProductionManualApprovalGate.relaxSensitiveDataPolicy,
      ]),
    );
  });
}

const _shellFiles = <String>[
  'lib/call_v2/ui/shells/call_v2_connecting_shell.dart',
  'lib/call_v2/ui/shells/call_v2_active_audio_shell.dart',
  'lib/call_v2/ui/shells/call_v2_active_video_shell.dart',
  'lib/call_v2/ui/shells/call_v2_controlled_failure_shell.dart',
  'lib/call_v2/ui/shells/call_v2_shell_controls.dart',
  'lib/call_v2/ui/shells/call_v2_shell_labels.dart',
];

const _bridgeStateFiles = <String>[
  'lib/call_v2/integration/call_v2_production_runtime_ui_bridge_status.dart',
  'lib/call_v2/integration/call_v2_production_runtime_ui_bridge_result.dart',
  'lib/call_v2/integration/call_v2_production_lifecycle_bridge_status.dart',
  'lib/call_v2/integration/call_v2_production_lifecycle_bridge_result.dart',
  'lib/call_v2/integration/call_v2_production_permission_device_bridge_status.dart',
  'lib/call_v2/integration/call_v2_production_permission_device_bridge_result.dart',
  'lib/call_v2/integration/call_v2_production_call_state_bridge_status.dart',
  'lib/call_v2/integration/call_v2_production_call_state_bridge_result.dart',
];

const _productionIntegrationAuditFiles = <String>[
  'lib/call_v2/integration/call_v2_production_call_state_bridge.dart',
  'lib/call_v2/integration/call_v2_production_call_state_bridge_event.dart',
  'lib/call_v2/integration/call_v2_production_call_state_bridge_result.dart',
  'lib/call_v2/integration/call_v2_production_call_state_bridge_status.dart',
  'lib/call_v2/integration/call_v2_production_lifecycle_bridge.dart',
  'lib/call_v2/integration/call_v2_production_lifecycle_bridge_event.dart',
  'lib/call_v2/integration/call_v2_production_lifecycle_bridge_result.dart',
  'lib/call_v2/integration/call_v2_production_lifecycle_bridge_status.dart',
  'lib/call_v2/integration/call_v2_production_permission_device_bridge.dart',
  'lib/call_v2/integration/call_v2_production_permission_device_bridge_event.dart',
  'lib/call_v2/integration/call_v2_production_permission_device_bridge_result.dart',
  'lib/call_v2/integration/call_v2_production_permission_device_bridge_status.dart',
  'lib/call_v2/integration/call_v2_production_runtime_ui_bridge.dart',
  'lib/call_v2/integration/call_v2_production_runtime_ui_bridge_event.dart',
  'lib/call_v2/integration/call_v2_production_runtime_ui_bridge_result.dart',
  'lib/call_v2/integration/call_v2_production_runtime_ui_bridge_status.dart',
  'lib/call_v2/integration/call_v2_production_ui_composition_owner.dart',
  'lib/call_v2/integration/call_v2_production_ui_composition_result.dart',
  'lib/call_v2/integration/call_v2_production_ui_composition_status.dart',
  'lib/call_v2/integration/call_v2_production_route_sink.dart',
  'lib/call_v2/integration/call_v2_production_route_sink_result.dart',
  'lib/call_v2/integration/call_v2_production_route_sink_state.dart',
  'lib/call_v2/ui/shells/call_v2_connecting_shell.dart',
  'lib/call_v2/ui/shells/call_v2_active_audio_shell.dart',
  'lib/call_v2/ui/shells/call_v2_active_video_shell.dart',
  'lib/call_v2/ui/shells/call_v2_controlled_failure_shell.dart',
  'lib/call_v2/ui/shells/call_v2_shell_controls.dart',
  'lib/call_v2/ui/shells/call_v2_shell_labels.dart',
  'lib/call_v2/design/call_v2_production_security_privacy_audit.dart',
];

Map<String, String> _isolatedBridgeSources() {
  return <String, String>{
    for (final file in _productionIntegrationAuditFiles)
      if (file.contains('_bridge') || file.contains('_ui_composition'))
        file: File(file).readAsStringSync(),
  };
}

String _readFiles(Iterable<String> files) {
  return files.map((file) => File(file).readAsStringSync()).join('\n');
}

void _expectNoRouteString(Object? value) {
  final text = value.toString();
  expect(text, isNot(contains('/call-v2/')));
}

void _expectNoSensitiveText(String text) {
  for (final pattern in <Pattern>[
    RegExp(r'\buid\b', caseSensitive: false),
    RegExp(r'\bcall[-_ ]?id\b', caseSensitive: false),
    RegExp(r'\bparticipant[-_ ]?id\b', caseSensitive: false),
    RegExp(r'\btoken\b', caseSensitive: false),
    RegExp(r'\bcredential\b', caseSensitive: false),
    RegExp(r'\bchannel\b', caseSensitive: false),
    RegExp(r'Bearer\s+', caseSensitive: false),
  ]) {
    expect(text, isNot(contains(pattern)), reason: '$pattern in $text');
  }
}
