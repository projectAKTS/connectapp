import 'call_v2_contract_manifest.dart';
import 'call_v2_production_capabilities.dart';
import 'call_v2_runtime_configuration.dart';
import 'call_v2_runtime_configuration_validator.dart';

enum CallV2ProductionReadinessIssueCode {
  configurationInvalid,
  featureGateMustRemainDisabled,
  missingCallableApiAdapter,
  missingFirestoreSnapshotSource,
  missingRtcConfigProvider,
  missingRtcAdapter,
  missingAuthIdentitySource,
  missingAppCheck,
  missingPermissionGateway,
  missingRuntimeStartupBridge,
  missingUiRouteIntegration,
  missingNativeCallIntegration,
  missingObservability,
  contractVersionMismatch,
  contractInvariantMismatch,
}

class CallV2ProductionReadinessIssue {
  const CallV2ProductionReadinessIssue({
    required this.code,
    required this.field,
  });

  final CallV2ProductionReadinessIssueCode code;
  final String field;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'code': code.name,
      'field': field,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionReadinessIssue(${toSafeDebugMap()})';
  }
}

class CallV2ProductionReadinessResult {
  const CallV2ProductionReadinessResult({
    required this.readyForAdapterImplementation,
    required this.readyForProductionEnablement,
    required this.issues,
  });

  final bool readyForAdapterImplementation;
  final bool readyForProductionEnablement;
  final List<CallV2ProductionReadinessIssue> issues;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'readyForAdapterImplementation': readyForAdapterImplementation,
      'readyForProductionEnablement': readyForProductionEnablement,
      'issues': issues.map((issue) => issue.toSafeDebugMap()).toList(),
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionReadinessResult(${toSafeDebugMap()})';
  }
}

class CallV2ProductionReadinessAuditor {
  const CallV2ProductionReadinessAuditor({
    this.configurationValidator = const CallV2RuntimeConfigurationValidator(),
  });

  final CallV2RuntimeConfigurationValidator configurationValidator;

  CallV2ProductionReadinessResult audit({
    required CallV2ContractManifest manifest,
    required CallV2RuntimeConfiguration configuration,
    required CallV2ProductionCapabilities capabilities,
  }) {
    final issues = <CallV2ProductionReadinessIssue>[];
    final configurationValidation = configurationValidator.validate(
      configuration,
    );

    if (!configurationValidation.isValid) {
      issues.add(const CallV2ProductionReadinessIssue(
        code: CallV2ProductionReadinessIssueCode.configurationInvalid,
        field: 'configuration',
      ));
    }
    if (!manifest.hasAcceptedVersion) {
      issues.add(const CallV2ProductionReadinessIssue(
        code: CallV2ProductionReadinessIssueCode.contractVersionMismatch,
        field: 'manifest.version',
      ));
    }
    _validateManifestInvariants(manifest, issues);

    final readyForAdapterImplementation = configurationValidation.isValid &&
        manifest.hasAcceptedVersion &&
        manifest.hasRequiredPhase3Invariants;

    if (readyForAdapterImplementation) {
      _validateProductionEnablementInputs(configuration, capabilities, issues);
    }

    final readyForProductionEnablement = readyForAdapterImplementation &&
        configuration.enabled &&
        configuration.environment == CallV2Environment.production &&
        configuration.rtcProvider == CallV2RtcProviderKind.agora &&
        _hasRequiredProductionCapabilities(capabilities);

    return CallV2ProductionReadinessResult(
      readyForAdapterImplementation: readyForAdapterImplementation,
      readyForProductionEnablement: readyForProductionEnablement,
      issues: List<CallV2ProductionReadinessIssue>.unmodifiable(issues),
    );
  }

  void _validateManifestInvariants(
    CallV2ContractManifest manifest,
    List<CallV2ProductionReadinessIssue> issues,
  ) {
    if (!manifest.featureGateDefaultsDisabled) {
      issues.add(const CallV2ProductionReadinessIssue(
        code: CallV2ProductionReadinessIssueCode.featureGateMustRemainDisabled,
        field: 'manifest.featureGateDefaultsDisabled',
      ));
    }
    if (!manifest.runtimeConstructionSideEffectFree) {
      _addContractInvariantIssue(
        issues,
        'manifest.runtimeConstructionSideEffectFree',
      );
    }
    if (!manifest.runtimeStartDoesNotStartMedia) {
      _addContractInvariantIssue(
        issues,
        'manifest.runtimeStartDoesNotStartMedia',
      );
    }
    if (!manifest.lifecycleSnapshotAuthoritative) {
      _addContractInvariantIssue(
        issues,
        'manifest.lifecycleSnapshotAuthoritative',
      );
    }
    if (!manifest.subscriptionCoordinatorOwnsFirestoreSubscriptionFlow) {
      _addContractInvariantIssue(
        issues,
        'manifest.subscriptionCoordinatorOwnsFirestoreSubscriptionFlow',
      );
    }
    if (!manifest.runtimeOwnsTopLevelStartStopSequencing) {
      _addContractInvariantIssue(
        issues,
        'manifest.runtimeOwnsTopLevelStartStopSequencing',
      );
    }
    if (!manifest.orchestratorOwnsSnapshotToMediaSequencing) {
      _addContractInvariantIssue(
        issues,
        'manifest.orchestratorOwnsSnapshotToMediaSequencing',
      );
    }
    if (!manifest.resolverOwnsConfigResolution) {
      _addContractInvariantIssue(
        issues,
        'manifest.resolverOwnsConfigResolution',
      );
    }
    if (!manifest.mediaControllerOwnsRtcAdapterCalls) {
      _addContractInvariantIssue(
        issues,
        'manifest.mediaControllerOwnsRtcAdapterCalls',
      );
    }
    if (!manifest.terminalSnapshotOwnsMediaCleanup) {
      _addContractInvariantIssue(
        issues,
        'manifest.terminalSnapshotOwnsMediaCleanup',
      );
    }
    if (!manifest.duplicateOperationsShareInFlightWork) {
      _addContractInvariantIssue(
        issues,
        'manifest.duplicateOperationsShareInFlightWork',
      );
    }
    if (!manifest.generationAndOperationIdentityProtectStaleCompletion) {
      _addContractInvariantIssue(
        issues,
        'manifest.generationAndOperationIdentityProtectStaleCompletion',
      );
    }
    if (!manifest.rawCredentialsNeverAppearInPublicState) {
      _addContractInvariantIssue(
        issues,
        'manifest.rawCredentialsNeverAppearInPublicState',
      );
    }
    if (!manifest.productionAdaptersAbsent) {
      _addContractInvariantIssue(issues, 'manifest.productionAdaptersAbsent');
    }
    if (!manifest.startupUiRoutesNativeWiringAbsent) {
      _addContractInvariantIssue(
        issues,
        'manifest.startupUiRoutesNativeWiringAbsent',
      );
    }
    if (!_containsAllEdges(
      manifest.allowedDependencyEdges,
      callV2AllowedDependencyEdges,
    )) {
      _addContractInvariantIssue(issues, 'manifest.allowedDependencyEdges');
    }
    if (!_containsAllEdges(
      manifest.forbiddenDependencyEdges,
      callV2ForbiddenDependencyEdges,
    )) {
      _addContractInvariantIssue(issues, 'manifest.forbiddenDependencyEdges');
    }
  }

  void _validateProductionEnablementInputs(
    CallV2RuntimeConfiguration configuration,
    CallV2ProductionCapabilities capabilities,
    List<CallV2ProductionReadinessIssue> issues,
  ) {
    if (!configuration.enabled ||
        configuration.environment != CallV2Environment.production ||
        configuration.rtcProvider != CallV2RtcProviderKind.agora) {
      issues.add(const CallV2ProductionReadinessIssue(
        code: CallV2ProductionReadinessIssueCode.configurationInvalid,
        field: 'configuration.productionEnablement',
      ));
    }
    if (!capabilities.callableApiAdapterAvailable) {
      issues.add(const CallV2ProductionReadinessIssue(
        code: CallV2ProductionReadinessIssueCode.missingCallableApiAdapter,
        field: 'capabilities.callableApiAdapterAvailable',
      ));
    }
    if (!capabilities.firestoreSnapshotSourceAvailable) {
      issues.add(const CallV2ProductionReadinessIssue(
        code: CallV2ProductionReadinessIssueCode.missingFirestoreSnapshotSource,
        field: 'capabilities.firestoreSnapshotSourceAvailable',
      ));
    }
    if (!capabilities.rtcConfigProviderAvailable) {
      issues.add(const CallV2ProductionReadinessIssue(
        code: CallV2ProductionReadinessIssueCode.missingRtcConfigProvider,
        field: 'capabilities.rtcConfigProviderAvailable',
      ));
    }
    if (!capabilities.rtcAdapterAvailable) {
      issues.add(const CallV2ProductionReadinessIssue(
        code: CallV2ProductionReadinessIssueCode.missingRtcAdapter,
        field: 'capabilities.rtcAdapterAvailable',
      ));
    }
    if (!capabilities.authIdentitySourceAvailable) {
      issues.add(const CallV2ProductionReadinessIssue(
        code: CallV2ProductionReadinessIssueCode.missingAuthIdentitySource,
        field: 'capabilities.authIdentitySourceAvailable',
      ));
    }
    if (!capabilities.appCheckAvailable) {
      issues.add(const CallV2ProductionReadinessIssue(
        code: CallV2ProductionReadinessIssueCode.missingAppCheck,
        field: 'capabilities.appCheckAvailable',
      ));
    }
    if (!capabilities.permissionGatewayAvailable) {
      issues.add(const CallV2ProductionReadinessIssue(
        code: CallV2ProductionReadinessIssueCode.missingPermissionGateway,
        field: 'capabilities.permissionGatewayAvailable',
      ));
    }
    if (!capabilities.runtimeStartupBridgeAvailable) {
      issues.add(const CallV2ProductionReadinessIssue(
        code: CallV2ProductionReadinessIssueCode.missingRuntimeStartupBridge,
        field: 'capabilities.runtimeStartupBridgeAvailable',
      ));
    }
    if (!capabilities.uiRouteIntegrationAvailable) {
      issues.add(const CallV2ProductionReadinessIssue(
        code: CallV2ProductionReadinessIssueCode.missingUiRouteIntegration,
        field: 'capabilities.uiRouteIntegrationAvailable',
      ));
    }
    if (!capabilities.observabilityAvailable) {
      issues.add(const CallV2ProductionReadinessIssue(
        code: CallV2ProductionReadinessIssueCode.missingObservability,
        field: 'capabilities.observabilityAvailable',
      ));
    }
  }

  void _addContractInvariantIssue(
    List<CallV2ProductionReadinessIssue> issues,
    String field,
  ) {
    issues.add(CallV2ProductionReadinessIssue(
      code: CallV2ProductionReadinessIssueCode.contractInvariantMismatch,
      field: field,
    ));
  }

  bool _hasRequiredProductionCapabilities(
    CallV2ProductionCapabilities capabilities,
  ) {
    return capabilities.callableApiAdapterAvailable &&
        capabilities.firestoreSnapshotSourceAvailable &&
        capabilities.rtcConfigProviderAvailable &&
        capabilities.rtcAdapterAvailable &&
        capabilities.authIdentitySourceAvailable &&
        capabilities.appCheckAvailable &&
        capabilities.permissionGatewayAvailable &&
        capabilities.runtimeStartupBridgeAvailable &&
        capabilities.uiRouteIntegrationAvailable &&
        capabilities.observabilityAvailable;
  }

  bool _containsAllEdges(
    List<CallV2ContractEdge> actual,
    List<CallV2ContractEdge> expected,
  ) {
    for (final edge in expected) {
      if (!actual.contains(edge)) return false;
    }
    return true;
  }
}
