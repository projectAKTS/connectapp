import 'dart:io';

import 'package:connect_app/call_v2/call_v2_contract_manifest.dart';
import 'package:connect_app/call_v2/call_v2_production_capabilities.dart';
import 'package:connect_app/call_v2/call_v2_production_readiness.dart';
import 'package:connect_app/call_v2/call_v2_runtime_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('manifest', () {
    test('default manifest version is Phase 3 V2', () {
      expect(
        callV2Phase3ContractManifest.version,
        CallV2ContractVersion.v2Phase3,
      );
    });

    test('feature gate default disabled invariant is true', () {
      expect(callV2Phase3ContractManifest.featureGateDefaultsDisabled, isTrue);
    });

    test('constructor side-effect-free invariant is true', () {
      expect(
        callV2Phase3ContractManifest.runtimeConstructionSideEffectFree,
        isTrue,
      );
    });

    test('snapshot-authority invariant is true', () {
      expect(
        callV2Phase3ContractManifest.lifecycleSnapshotAuthoritative,
        isTrue,
      );
    });

    test('runtime-start-does-not-start-media invariant is true', () {
      expect(
        callV2Phase3ContractManifest.runtimeStartDoesNotStartMedia,
        isTrue,
      );
    });

    test('credentials-not-in-state invariant is true', () {
      expect(
        callV2Phase3ContractManifest.rawCredentialsNeverAppearInPublicState,
        isTrue,
      );
    });

    test('production adapters absent invariant is true', () {
      expect(callV2Phase3ContractManifest.productionAdaptersAbsent, isTrue);
    });

    test('startup UI native wiring absent invariant is true', () {
      expect(
        callV2Phase3ContractManifest.startupUiRoutesNativeWiringAbsent,
        isTrue,
      );
    });

    test('manifest is immutable', () {
      expect(
        () => callV2Phase3ContractManifest.allowedDependencyEdges.add(
          const CallV2ContractEdge(
            from: CallV2ContractNode.runtime,
            to: CallV2ContractNode.rtcAdapter,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('manifest safe debug output contains no secrets', () {
      _expectNoSecretLikeContent(
        callV2Phase3ContractManifest.toSafeDebugMap().toString(),
      );
      _expectNoSecretLikeContent(callV2Phase3ContractManifest.toString());
    });
  });

  group('capability model', () {
    test('default capabilities are all false', () {
      expect(
        callV2NoProductionCapabilities.toSafeDebugMap().values,
        everyElement(false),
      );
    });

    test('capability model construction has no side effects', () {
      const CallV2ProductionCapabilities(
        callableApiAdapterAvailable: false,
        firestoreSnapshotSourceAvailable: false,
        rtcConfigProviderAvailable: false,
        rtcAdapterAvailable: false,
        authIdentitySourceAvailable: false,
        appCheckAvailable: false,
        permissionGatewayAvailable: false,
        runtimeStartupBridgeAvailable: false,
        uiRouteIntegrationAvailable: false,
        nativeCallIntegrationAvailable: false,
        observabilityAvailable: false,
      );

      _expectProductionSourcesDoNotContain(<String>[
        'instance',
        'initializeApp',
        'Platform.environment',
      ]);
    });

    test('capability debug output is allowlisted', () {
      expect(callV2NoProductionCapabilities.toSafeDebugMap().keys, <String>{
        'callableApiAdapterAvailable',
        'firestoreSnapshotSourceAvailable',
        'rtcConfigProviderAvailable',
        'rtcAdapterAvailable',
        'authIdentitySourceAvailable',
        'appCheckAvailable',
        'permissionGatewayAvailable',
        'runtimeStartupBridgeAvailable',
        'uiRouteIntegrationAvailable',
        'nativeCallIntegrationAvailable',
        'observabilityAvailable',
      });
    });

    test('no dynamic metadata accepted', () {
      expect(
        callV2NoProductionCapabilities.toSafeDebugMap().containsKey('metadata'),
        isFalse,
      );
    });

    test('no secret-bearing field exists', () {
      final text = callV2NoProductionCapabilities.toSafeDebugMap().toString();

      _expectNoSecretLikeContent(text);
    });
  });

  group('adapter implementation readiness', () {
    test(
        'accepted manifest disabled config and no capabilities are adapter ready',
        () {
      final result = _audit(
        configuration: _disabledConfig(),
        capabilities: callV2NoProductionCapabilities,
      );

      expect(result.readyForAdapterImplementation, isTrue);
      expect(result.readyForProductionEnablement, isFalse);
    });

    test('invalid configuration makes adapter implementation readiness false',
        () {
      final result = _audit(
        configuration: _disabledConfig(callCollectionName: ''),
      );

      expect(result.readyForAdapterImplementation, isFalse);
      expect(
          _codes(result),
          contains(
            CallV2ProductionReadinessIssueCode.configurationInvalid,
          ));
    });

    test('contract version mismatch makes readiness false', () {
      final result = _audit(
        manifest: _manifest(version: CallV2ContractVersion.unsupported),
        configuration: _disabledConfig(),
      );

      expect(result.readyForAdapterImplementation, isFalse);
      expect(
          _codes(result),
          contains(
            CallV2ProductionReadinessIssueCode.contractVersionMismatch,
          ));
    });

    test('broken snapshot-authority invariant makes readiness false', () {
      final result = _audit(
        manifest: _manifest(lifecycleSnapshotAuthoritative: false),
        configuration: _disabledConfig(),
      );

      expect(result.readyForAdapterImplementation, isFalse);
      expect(
          _fields(result),
          contains(
            'manifest.lifecycleSnapshotAuthoritative',
          ));
    });

    test('broken credential-redaction invariant makes readiness false', () {
      final result = _audit(
        manifest: _manifest(rawCredentialsNeverAppearInPublicState: false),
        configuration: _disabledConfig(),
      );

      expect(result.readyForAdapterImplementation, isFalse);
      expect(
          _fields(result),
          contains(
            'manifest.rawCredentialsNeverAppearInPublicState',
          ));
    });

    test('missing production capabilities do not block adapter implementation',
        () {
      final result = _audit(
        configuration: _disabledConfig(),
        capabilities: callV2NoProductionCapabilities,
      );

      expect(result.readyForAdapterImplementation, isTrue);
    });

    test('issue ordering deterministic', () {
      final result = _audit(
        manifest: _manifest(
          version: CallV2ContractVersion.unsupported,
          lifecycleSnapshotAuthoritative: false,
        ),
        configuration: _disabledConfig(callCollectionName: ''),
      );

      expect(_codes(result), <CallV2ProductionReadinessIssueCode>[
        CallV2ProductionReadinessIssueCode.configurationInvalid,
        CallV2ProductionReadinessIssueCode.contractVersionMismatch,
        CallV2ProductionReadinessIssueCode.contractInvariantMismatch,
      ]);
    });

    test('issue list unmodifiable', () {
      final result = _audit(configuration: _disabledConfig());

      expect(
        () => result.issues.add(const CallV2ProductionReadinessIssue(
          code: CallV2ProductionReadinessIssueCode.configurationInvalid,
          field: 'configuration',
        )),
        throwsUnsupportedError,
      );
    });
  });

  group('production enablement', () {
    test('disabled config never ready for production enablement', () {
      final result = _audit(
        configuration:
            _disabledConfig(environment: CallV2Environment.production),
        capabilities: _allRequiredCapabilities(),
      );

      expect(result.readyForAdapterImplementation, isTrue);
      expect(result.readyForProductionEnablement, isFalse);
    });

    test('enabled production config with no capabilities is not ready', () {
      final result = _audit(
        configuration: _productionConfig(),
        capabilities: callV2NoProductionCapabilities,
      );

      expect(result.readyForAdapterImplementation, isTrue);
      expect(result.readyForProductionEnablement, isFalse);
    });

    test('each missing required capability produces its exact issue', () {
      final result = _audit(
        configuration: _productionConfig(),
        capabilities: callV2NoProductionCapabilities,
      );

      expect(
          _codes(result),
          containsAll(<CallV2ProductionReadinessIssueCode>[
            CallV2ProductionReadinessIssueCode.missingCallableApiAdapter,
            CallV2ProductionReadinessIssueCode.missingFirestoreSnapshotSource,
            CallV2ProductionReadinessIssueCode.missingRtcConfigProvider,
            CallV2ProductionReadinessIssueCode.missingRtcAdapter,
            CallV2ProductionReadinessIssueCode.missingAuthIdentitySource,
            CallV2ProductionReadinessIssueCode.missingAppCheck,
            CallV2ProductionReadinessIssueCode.missingPermissionGateway,
            CallV2ProductionReadinessIssueCode.missingRuntimeStartupBridge,
            CallV2ProductionReadinessIssueCode.missingUiRouteIntegration,
            CallV2ProductionReadinessIssueCode.missingObservability,
          ]));
      expect(
        _codes(result),
        isNot(contains(
          CallV2ProductionReadinessIssueCode.missingNativeCallIntegration,
        )),
      );
    });

    test('all required capabilities and valid production config is ready', () {
      final result = _audit(
        configuration: _productionConfig(),
        capabilities: _allRequiredCapabilities(),
      );

      expect(result.readyForAdapterImplementation, isTrue);
      expect(result.readyForProductionEnablement, isTrue);
      expect(result.issues, isEmpty);
    });

    test('fake provider never produces production-enable readiness', () {
      final result = _audit(
        configuration: _productionConfig(
          rtcProvider: CallV2RtcProviderKind.fake,
          rtcAppIdReference: '',
        ),
        capabilities: _allRequiredCapabilities(),
      );

      expect(result.readyForProductionEnablement, isFalse);
    });

    test('provider none never produces production-enable readiness', () {
      final result = _audit(
        configuration: _productionConfig(
          rtcProvider: CallV2RtcProviderKind.none,
          rtcAppIdReference: '',
        ),
        capabilities: _allRequiredCapabilities(),
      );

      expect(result.readyForProductionEnablement, isFalse);
    });

    test('missing App Check blocks readiness', () {
      final result = _audit(
        configuration: _productionConfig(),
        capabilities: _allRequiredCapabilities(appCheckAvailable: false),
      );

      expect(result.readyForProductionEnablement, isFalse);
      expect(
          _codes(result),
          contains(
            CallV2ProductionReadinessIssueCode.missingAppCheck,
          ));
    });

    test('missing auth identity blocks readiness', () {
      final result = _audit(
        configuration: _productionConfig(),
        capabilities:
            _allRequiredCapabilities(authIdentitySourceAvailable: false),
      );

      expect(result.readyForProductionEnablement, isFalse);
      expect(
          _codes(result),
          contains(
            CallV2ProductionReadinessIssueCode.missingAuthIdentitySource,
          ));
    });

    test('missing permission gateway blocks readiness', () {
      final result = _audit(
        configuration: _productionConfig(),
        capabilities:
            _allRequiredCapabilities(permissionGatewayAvailable: false),
      );

      expect(result.readyForProductionEnablement, isFalse);
      expect(
          _codes(result),
          contains(
            CallV2ProductionReadinessIssueCode.missingPermissionGateway,
          ));
    });

    test('missing startup bridge blocks readiness', () {
      final result = _audit(
        configuration: _productionConfig(),
        capabilities:
            _allRequiredCapabilities(runtimeStartupBridgeAvailable: false),
      );

      expect(result.readyForProductionEnablement, isFalse);
      expect(
          _codes(result),
          contains(
            CallV2ProductionReadinessIssueCode.missingRuntimeStartupBridge,
          ));
    });

    test('missing UI route integration blocks readiness', () {
      final result = _audit(
        configuration: _productionConfig(),
        capabilities:
            _allRequiredCapabilities(uiRouteIntegrationAvailable: false),
      );

      expect(result.readyForProductionEnablement, isFalse);
      expect(
          _codes(result),
          contains(
            CallV2ProductionReadinessIssueCode.missingUiRouteIntegration,
          ));
    });

    test('missing observability blocks readiness', () {
      final result = _audit(
        configuration: _productionConfig(),
        capabilities: _allRequiredCapabilities(observabilityAvailable: false),
      );

      expect(result.readyForProductionEnablement, isFalse);
      expect(
          _codes(result),
          contains(
            CallV2ProductionReadinessIssueCode.missingObservability,
          ));
    });

    test('native call integration follows documented optional policy', () {
      final result = _audit(
        configuration: _productionConfig(),
        capabilities:
            _allRequiredCapabilities(nativeCallIntegrationAvailable: false),
      );

      expect(result.readyForProductionEnablement, isTrue);
      expect(
          _codes(result),
          isNot(contains(
            CallV2ProductionReadinessIssueCode.missingNativeCallIntegration,
          )));
    });

    test('no raw config values appear in issues', () {
      final result = _audit(
        configuration: _productionConfig(
          rtcAppIdReference: 'CALL_V2_AGORA_APP_ID',
          callCollectionName: 'calls_private_value',
        ),
        capabilities: callV2NoProductionCapabilities,
      );
      final text = result.issues.map((issue) => issue.toString()).join('\n');

      expect(text, isNot(contains('CALL_V2_AGORA_APP_ID')));
      expect(text, isNot(contains('calls_private_value')));
    });

    test('no secret-like strings appear in result toString', () {
      final result = _audit(
        configuration: _productionConfig(),
        capabilities: callV2NoProductionCapabilities,
      );

      _expectNoSecretLikeContent(result.toString());
    });
  });

  group('dependency graph', () {
    test('accepted ownership edges are present', () {
      expect(
        callV2Phase3ContractManifest.allowedDependencyEdges,
        containsAll(callV2AllowedDependencyEdges),
      );
    });

    test('runtime-to-RTC-adapter edge forbidden', () {
      expect(
        callV2Phase3ContractManifest.forbiddenDependencyEdges,
        contains(const CallV2ContractEdge(
          from: CallV2ContractNode.runtime,
          to: CallV2ContractNode.rtcAdapter,
        )),
      );
    });

    test('runtime-to-Firebase edge forbidden', () {
      expect(
        callV2Phase3ContractManifest.forbiddenDependencyEdges,
        containsAll(<CallV2ContractEdge>{
          const CallV2ContractEdge(
            from: CallV2ContractNode.runtime,
            to: CallV2ContractNode.firestore,
          ),
          const CallV2ContractEdge(
            from: CallV2ContractNode.runtime,
            to: CallV2ContractNode.firebaseAuth,
          ),
          const CallV2ContractEdge(
            from: CallV2ContractNode.runtime,
            to: CallV2ContractNode.firebaseFunctions,
          ),
        }),
      );
    });

    test('resolver-to-RTC-adapter edge forbidden', () {
      expect(
        callV2Phase3ContractManifest.forbiddenDependencyEdges,
        contains(const CallV2ContractEdge(
          from: CallV2ContractNode.resolver,
          to: CallV2ContractNode.rtcAdapter,
        )),
      );
    });

    test('media-controller-to-Firestore edge forbidden', () {
      expect(
        callV2Phase3ContractManifest.forbiddenDependencyEdges,
        contains(const CallV2ContractEdge(
          from: CallV2ContractNode.mediaController,
          to: CallV2ContractNode.firestore,
        )),
      );
    });

    test('UI-to-RTC-adapter edge forbidden', () {
      expect(
        callV2Phase3ContractManifest.forbiddenDependencyEdges,
        contains(const CallV2ContractEdge(
          from: CallV2ContractNode.ui,
          to: CallV2ContractNode.rtcAdapter,
        )),
      );
    });

    test('allowed graph is immutable', () {
      expect(
        () => callV2AllowedDependencyEdges.clear(),
        throwsUnsupportedError,
      );
    });

    test('edge ordering deterministic', () {
      expect(
        callV2AllowedDependencyEdges.map((edge) => edge.toSafeDebugMap()),
        <Map<String, Object?>>[
          <String, Object?>{'from': 'runtime', 'to': 'subscriptionCoordinator'},
          <String, Object?>{'from': 'subscriptionCoordinator', 'to': 'harness'},
          <String, Object?>{'from': 'runtime', 'to': 'mediaOrchestrator'},
          <String, Object?>{'from': 'mediaOrchestrator', 'to': 'resolver'},
          <String, Object?>{'from': 'resolver', 'to': 'mediaController'},
          <String, Object?>{'from': 'mediaController', 'to': 'rtcAdapter'},
        ],
      );
    });
  });

  group('isolation', () {
    test('no Firebase singleton access', () {
      _expectProductionSourcesDoNotContain(<String>[
        'Firebase.initializeApp',
        'FirebaseFirestore.instance',
        'FirebaseAuth.instance',
        'FirebaseFunctions.instance',
        'FirebaseAppCheck.instance',
      ]);
    });

    test('no environment-variable access', () {
      _expectProductionSourcesDoNotContain(<String>[
        'Platform.environment',
        'String.fromEnvironment',
        'dotenv',
      ]);
    });

    test('no RTC SDK import', () {
      _expectProductionSourcesDoNotContain(<String>[
        'agora_rtc_engine',
        'AgoraRtcEngine',
        'Twilio',
      ]);
    });

    test('no file-system inspection', () {
      _expectProductionSourcesDoNotContain(<String>[
        "dart:io",
        'File(',
        'Directory(',
        'readAsString',
      ]);
    });

    test('no startup wiring', () {
      _expectProductionSourcesDoNotContain(<String>[
        'main.dart',
        'runApp',
        'WidgetsFlutterBinding',
      ]);
    });

    test('no UI route changes', () {
      _expectProductionSourcesDoNotContain(<String>[
        'Navigator',
        'MaterialPageRoute',
        'BuildContext',
      ]);
    });
  });
}

CallV2ProductionReadinessResult _audit({
  CallV2ContractManifest manifest = callV2Phase3ContractManifest,
  required CallV2RuntimeConfiguration configuration,
  CallV2ProductionCapabilities capabilities = callV2NoProductionCapabilities,
}) {
  return const CallV2ProductionReadinessAuditor().audit(
    manifest: manifest,
    configuration: configuration,
    capabilities: capabilities,
  );
}

List<CallV2ProductionReadinessIssueCode> _codes(
  CallV2ProductionReadinessResult result,
) {
  return result.issues.map((issue) => issue.code).toList();
}

List<String> _fields(CallV2ProductionReadinessResult result) {
  return result.issues.map((issue) => issue.field).toList();
}

CallV2RuntimeConfiguration _disabledConfig({
  CallV2Environment environment = CallV2Environment.local,
  String callCollectionName = 'calls',
}) {
  return CallV2RuntimeConfiguration(
    enabled: false,
    environment: environment,
    rtcProvider: CallV2RtcProviderKind.none,
    rtcAppIdReference: '',
    callCollectionName: callCollectionName,
    participantSubcollectionName: 'participants',
    rtcTokenMaxLifetime: callV2AcceptedRtcTokenMaxLifetime,
    minimumTokenRemainingValidity: const Duration(seconds: 60),
  );
}

CallV2RuntimeConfiguration _productionConfig({
  CallV2RtcProviderKind rtcProvider = CallV2RtcProviderKind.agora,
  String rtcAppIdReference = 'CALL_V2_AGORA_APP_ID_REFERENCE',
  String callCollectionName = 'calls',
}) {
  return CallV2RuntimeConfiguration(
    enabled: true,
    environment: CallV2Environment.production,
    rtcProvider: rtcProvider,
    rtcAppIdReference: rtcAppIdReference,
    callCollectionName: callCollectionName,
    participantSubcollectionName: 'participants',
    rtcTokenMaxLifetime: callV2AcceptedRtcTokenMaxLifetime,
    minimumTokenRemainingValidity: const Duration(seconds: 60),
  );
}

CallV2ProductionCapabilities _allRequiredCapabilities({
  bool callableApiAdapterAvailable = true,
  bool firestoreSnapshotSourceAvailable = true,
  bool rtcConfigProviderAvailable = true,
  bool rtcAdapterAvailable = true,
  bool authIdentitySourceAvailable = true,
  bool appCheckAvailable = true,
  bool permissionGatewayAvailable = true,
  bool runtimeStartupBridgeAvailable = true,
  bool uiRouteIntegrationAvailable = true,
  bool nativeCallIntegrationAvailable = false,
  bool observabilityAvailable = true,
}) {
  return CallV2ProductionCapabilities(
    callableApiAdapterAvailable: callableApiAdapterAvailable,
    firestoreSnapshotSourceAvailable: firestoreSnapshotSourceAvailable,
    rtcConfigProviderAvailable: rtcConfigProviderAvailable,
    rtcAdapterAvailable: rtcAdapterAvailable,
    authIdentitySourceAvailable: authIdentitySourceAvailable,
    appCheckAvailable: appCheckAvailable,
    permissionGatewayAvailable: permissionGatewayAvailable,
    runtimeStartupBridgeAvailable: runtimeStartupBridgeAvailable,
    uiRouteIntegrationAvailable: uiRouteIntegrationAvailable,
    nativeCallIntegrationAvailable: nativeCallIntegrationAvailable,
    observabilityAvailable: observabilityAvailable,
  );
}

CallV2ContractManifest _manifest({
  CallV2ContractVersion version = CallV2ContractVersion.v2Phase3,
  bool lifecycleSnapshotAuthoritative = true,
  bool rawCredentialsNeverAppearInPublicState = true,
}) {
  return CallV2ContractManifest(
    version: version,
    featureGateDefaultsDisabled: true,
    runtimeConstructionSideEffectFree: true,
    runtimeStartDoesNotStartMedia: true,
    lifecycleSnapshotAuthoritative: lifecycleSnapshotAuthoritative,
    subscriptionCoordinatorOwnsFirestoreSubscriptionFlow: true,
    runtimeOwnsTopLevelStartStopSequencing: true,
    orchestratorOwnsSnapshotToMediaSequencing: true,
    resolverOwnsConfigResolution: true,
    mediaControllerOwnsRtcAdapterCalls: true,
    terminalSnapshotOwnsMediaCleanup: true,
    duplicateOperationsShareInFlightWork: true,
    generationAndOperationIdentityProtectStaleCompletion: true,
    rawCredentialsNeverAppearInPublicState:
        rawCredentialsNeverAppearInPublicState,
    productionAdaptersAbsent: true,
    startupUiRoutesNativeWiringAbsent: true,
    allowedDependencyEdges: callV2AllowedDependencyEdges,
    forbiddenDependencyEdges: callV2ForbiddenDependencyEdges,
  );
}

void _expectProductionSourcesDoNotContain(List<String> forbiddenTerms) {
  final source = _productionSourcePaths
      .map((path) => File(path).readAsStringSync())
      .join('\n');

  for (final forbidden in forbiddenTerms) {
    expect(source, isNot(contains(forbidden)), reason: forbidden);
  }
}

void _expectNoSecretLikeContent(String text) {
  final lower = text.toLowerCase();
  for (final forbidden in _secretLikeTerms) {
    expect(lower, isNot(contains(forbidden)), reason: forbidden);
  }
}

const _productionSourcePaths = <String>[
  'lib/call_v2/call_v2_contract_manifest.dart',
  'lib/call_v2/call_v2_production_capabilities.dart',
  'lib/call_v2/call_v2_production_readiness.dart',
];

const _secretLikeTerms = <String>[
  'rawtoken',
  'access_token',
  'authtoken',
  'secret',
  'privatekey',
  'private key',
  'serviceaccount',
  'service account',
  'apikey',
  'api key',
  'clientsecret',
];
