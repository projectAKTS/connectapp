import '../call_v2_contract_manifest.dart';
import '../call_v2_production_capabilities.dart';
import '../call_v2_production_readiness.dart';
import '../call_v2_runtime_configuration.dart';
import '../observability/call_v2_observability_capabilities.dart';

enum CallV2RolloutGateStatus {
  closed,
  open,
}

class CallV2ActualRolloutPrerequisites {
  const CallV2ActualRolloutPrerequisites({
    this.appStartupWired = false,
    this.realRoutesWired = false,
    this.realScreensWired = false,
    this.productionTelemetryWired = false,
    this.releaseConfigurationReviewed = false,
    this.rolloutOwnerApproved = false,
    this.rollbackPlanApproved = false,
    this.productionSmokeTestPlanApproved = false,
    this.deploymentApproved = false,
    this.platformPermissionDeclarationsConfirmed = false,
    this.backendDeploymentConfirmed = false,
    this.appCheckEnforcementConfirmed = false,
    this.defaultRolloutEnabled = false,
    this.deploymentPerformed = false,
  });

  final bool appStartupWired;
  final bool realRoutesWired;
  final bool realScreensWired;
  final bool productionTelemetryWired;
  final bool releaseConfigurationReviewed;
  final bool rolloutOwnerApproved;
  final bool rollbackPlanApproved;
  final bool productionSmokeTestPlanApproved;
  final bool deploymentApproved;
  final bool platformPermissionDeclarationsConfirmed;
  final bool backendDeploymentConfirmed;
  final bool appCheckEnforcementConfirmed;
  final bool defaultRolloutEnabled;
  final bool deploymentPerformed;

  bool get readyForActualRollout {
    return appStartupWired &&
        realRoutesWired &&
        realScreensWired &&
        productionTelemetryWired &&
        releaseConfigurationReviewed &&
        rolloutOwnerApproved &&
        rollbackPlanApproved &&
        productionSmokeTestPlanApproved &&
        deploymentApproved;
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'appStartupWired': appStartupWired,
      'realRoutesWired': realRoutesWired,
      'realScreensWired': realScreensWired,
      'productionTelemetryWired': productionTelemetryWired,
      'releaseConfigurationReviewed': releaseConfigurationReviewed,
      'rolloutOwnerApproved': rolloutOwnerApproved,
      'rollbackPlanApproved': rollbackPlanApproved,
      'productionSmokeTestPlanApproved': productionSmokeTestPlanApproved,
      'deploymentApproved': deploymentApproved,
      'platformPermissionDeclarationsConfirmed':
          platformPermissionDeclarationsConfirmed,
      'backendDeploymentConfirmed': backendDeploymentConfirmed,
      'appCheckEnforcementConfirmed': appCheckEnforcementConfirmed,
      'defaultRolloutEnabled': defaultRolloutEnabled,
      'deploymentPerformed': deploymentPerformed,
    };
  }
}

class CallV2FinalReadinessAuditResult {
  const CallV2FinalReadinessAuditResult({
    required this.contractManifestAccepted,
    required this.runtimeGraphAccepted,
    required this.callableAdapterAvailable,
    required this.firestoreSourceAvailable,
    required this.rtcCredentialProviderAvailable,
    required this.rtcAdapterAvailable,
    required this.authIdentityAvailable,
    required this.appCheckAvailable,
    required this.permissionGatewayAvailable,
    required this.startupBridgeAvailable,
    required this.uiRouteContractAvailable,
    required this.observabilityAvailable,
    required this.nativeCallIntegrationAvailable,
    required this.appStartupWired,
    required this.realRoutesWired,
    required this.realScreensWired,
    required this.productionTelemetryWired,
    required this.deploymentPerformed,
    required this.defaultRolloutEnabled,
    required this.readyForAdapterImplementation,
    required this.readyForProductionEnablement,
    required this.readyForActualRollout,
  });

  final bool contractManifestAccepted;
  final bool runtimeGraphAccepted;
  final bool callableAdapterAvailable;
  final bool firestoreSourceAvailable;
  final bool rtcCredentialProviderAvailable;
  final bool rtcAdapterAvailable;
  final bool authIdentityAvailable;
  final bool appCheckAvailable;
  final bool permissionGatewayAvailable;
  final bool startupBridgeAvailable;
  final bool uiRouteContractAvailable;
  final bool observabilityAvailable;
  final bool nativeCallIntegrationAvailable;
  final bool appStartupWired;
  final bool realRoutesWired;
  final bool realScreensWired;
  final bool productionTelemetryWired;
  final bool deploymentPerformed;
  final bool defaultRolloutEnabled;
  final bool readyForAdapterImplementation;
  final bool readyForProductionEnablement;
  final bool readyForActualRollout;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'contractManifestAccepted': contractManifestAccepted,
      'runtimeGraphAccepted': runtimeGraphAccepted,
      'callableAdapterAvailable': callableAdapterAvailable,
      'firestoreSourceAvailable': firestoreSourceAvailable,
      'rtcCredentialProviderAvailable': rtcCredentialProviderAvailable,
      'rtcAdapterAvailable': rtcAdapterAvailable,
      'authIdentityAvailable': authIdentityAvailable,
      'appCheckAvailable': appCheckAvailable,
      'permissionGatewayAvailable': permissionGatewayAvailable,
      'startupBridgeAvailable': startupBridgeAvailable,
      'uiRouteContractAvailable': uiRouteContractAvailable,
      'observabilityAvailable': observabilityAvailable,
      'nativeCallIntegrationAvailable': nativeCallIntegrationAvailable,
      'appStartupWired': appStartupWired,
      'realRoutesWired': realRoutesWired,
      'realScreensWired': realScreensWired,
      'productionTelemetryWired': productionTelemetryWired,
      'deploymentPerformed': deploymentPerformed,
      'defaultRolloutEnabled': defaultRolloutEnabled,
      'readyForAdapterImplementation': readyForAdapterImplementation,
      'readyForProductionEnablement': readyForProductionEnablement,
      'readyForActualRollout': readyForActualRollout,
    };
  }

  @override
  String toString() {
    return 'CallV2FinalReadinessAuditResult(${toSafeDebugMap()})';
  }
}

class CallV2RollbackPlan {
  const CallV2RollbackPlan({
    this.featureGateDisableAvailable = true,
    this.routeRemovalAvailable = true,
    this.startupBridgeRemovalAvailable = true,
    this.backendCompatibilityPreserved = true,
    this.v1FallbackPreserved = true,
    this.dataMigrationRequired = false,
    this.destructiveRollbackRequired = false,
  });

  final bool featureGateDisableAvailable;
  final bool routeRemovalAvailable;
  final bool startupBridgeRemovalAvailable;
  final bool backendCompatibilityPreserved;
  final bool v1FallbackPreserved;
  final bool dataMigrationRequired;
  final bool destructiveRollbackRequired;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'featureGateDisableAvailable': featureGateDisableAvailable,
      'routeRemovalAvailable': routeRemovalAvailable,
      'startupBridgeRemovalAvailable': startupBridgeRemovalAvailable,
      'backendCompatibilityPreserved': backendCompatibilityPreserved,
      'v1FallbackPreserved': v1FallbackPreserved,
      'dataMigrationRequired': dataMigrationRequired,
      'destructiveRollbackRequired': destructiveRollbackRequired,
    };
  }

  @override
  String toString() {
    return 'CallV2RollbackPlan(${toSafeDebugMap()})';
  }
}

class CallV2RolloutGateResult {
  const CallV2RolloutGateResult({
    required this.status,
    required this.validProductionConfiguration,
    required this.readinessAuditorPassed,
    required this.startupIntegrationConfirmed,
    required this.routeIntegrationConfirmed,
    required this.screenIntegrationConfirmed,
    required this.productionObservabilitySinkConfirmed,
    required this.platformPermissionDeclarationsConfirmed,
    required this.backendDeploymentConfirmed,
    required this.appCheckEnforcementConfirmed,
    required this.releaseApprovalConfirmed,
    required this.rollbackProcedureConfirmed,
  });

  final CallV2RolloutGateStatus status;
  final bool validProductionConfiguration;
  final bool readinessAuditorPassed;
  final bool startupIntegrationConfirmed;
  final bool routeIntegrationConfirmed;
  final bool screenIntegrationConfirmed;
  final bool productionObservabilitySinkConfirmed;
  final bool platformPermissionDeclarationsConfirmed;
  final bool backendDeploymentConfirmed;
  final bool appCheckEnforcementConfirmed;
  final bool releaseApprovalConfirmed;
  final bool rollbackProcedureConfirmed;

  bool get isOpen => status == CallV2RolloutGateStatus.open;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'status': status.name,
      'validProductionConfiguration': validProductionConfiguration,
      'readinessAuditorPassed': readinessAuditorPassed,
      'startupIntegrationConfirmed': startupIntegrationConfirmed,
      'routeIntegrationConfirmed': routeIntegrationConfirmed,
      'screenIntegrationConfirmed': screenIntegrationConfirmed,
      'productionObservabilitySinkConfirmed':
          productionObservabilitySinkConfirmed,
      'platformPermissionDeclarationsConfirmed':
          platformPermissionDeclarationsConfirmed,
      'backendDeploymentConfirmed': backendDeploymentConfirmed,
      'appCheckEnforcementConfirmed': appCheckEnforcementConfirmed,
      'releaseApprovalConfirmed': releaseApprovalConfirmed,
      'rollbackProcedureConfirmed': rollbackProcedureConfirmed,
    };
  }

  @override
  String toString() {
    return 'CallV2RolloutGateResult(${toSafeDebugMap()})';
  }
}

class CallV2FinalReadinessAuditor {
  const CallV2FinalReadinessAuditor({
    this.readinessAuditor = const CallV2ProductionReadinessAuditor(),
  });

  final CallV2ProductionReadinessAuditor readinessAuditor;

  CallV2FinalReadinessAuditResult audit({
    CallV2ContractManifest manifest = callV2Phase3ContractManifest,
    required CallV2RuntimeConfiguration configuration,
    CallV2ProductionCapabilities capabilities =
        callV2IsolatedObservabilityCapabilities,
    CallV2ActualRolloutPrerequisites actualRolloutPrerequisites =
        const CallV2ActualRolloutPrerequisites(),
  }) {
    final readiness = readinessAuditor.audit(
      manifest: manifest,
      configuration: configuration,
      capabilities: capabilities,
    );

    return CallV2FinalReadinessAuditResult(
      contractManifestAccepted: manifest.hasAcceptedVersion,
      runtimeGraphAccepted: manifest.hasExactAcceptedDependencyGraph,
      callableAdapterAvailable: capabilities.callableApiAdapterAvailable,
      firestoreSourceAvailable: capabilities.firestoreSnapshotSourceAvailable,
      rtcCredentialProviderAvailable: capabilities.rtcConfigProviderAvailable,
      rtcAdapterAvailable: capabilities.rtcAdapterAvailable,
      authIdentityAvailable: capabilities.authIdentitySourceAvailable,
      appCheckAvailable: capabilities.appCheckAvailable,
      permissionGatewayAvailable: capabilities.permissionGatewayAvailable,
      startupBridgeAvailable: capabilities.runtimeStartupBridgeAvailable,
      uiRouteContractAvailable: capabilities.uiRouteIntegrationAvailable,
      observabilityAvailable: capabilities.observabilityAvailable,
      nativeCallIntegrationAvailable:
          capabilities.nativeCallIntegrationAvailable,
      appStartupWired: actualRolloutPrerequisites.appStartupWired,
      realRoutesWired: actualRolloutPrerequisites.realRoutesWired,
      realScreensWired: actualRolloutPrerequisites.realScreensWired,
      productionTelemetryWired:
          actualRolloutPrerequisites.productionTelemetryWired,
      deploymentPerformed: actualRolloutPrerequisites.deploymentPerformed,
      defaultRolloutEnabled: actualRolloutPrerequisites.defaultRolloutEnabled,
      readyForAdapterImplementation: readiness.readyForAdapterImplementation,
      readyForProductionEnablement: readiness.readyForProductionEnablement,
      readyForActualRollout: readiness.readyForProductionEnablement &&
          actualRolloutPrerequisites.readyForActualRollout,
    );
  }

  CallV2RolloutGateResult evaluateRolloutGate({
    CallV2ContractManifest manifest = callV2Phase3ContractManifest,
    required CallV2RuntimeConfiguration configuration,
    CallV2ProductionCapabilities capabilities =
        callV2IsolatedObservabilityCapabilities,
    CallV2ActualRolloutPrerequisites actualRolloutPrerequisites =
        const CallV2ActualRolloutPrerequisites(),
    CallV2RollbackPlan rollbackPlan = const CallV2RollbackPlan(),
  }) {
    final readiness = readinessAuditor.audit(
      manifest: manifest,
      configuration: configuration,
      capabilities: capabilities,
    );
    final validProductionConfiguration =
        readiness.readyForAdapterImplementation &&
            configuration.enabled &&
            configuration.environment == CallV2Environment.production &&
            configuration.rtcProvider == CallV2RtcProviderKind.agora;
    final readinessAuditorPassed = readiness.readyForProductionEnablement;
    final rollbackProcedureConfirmed =
        actualRolloutPrerequisites.rollbackPlanApproved &&
            rollbackPlan.featureGateDisableAvailable &&
            rollbackPlan.routeRemovalAvailable &&
            rollbackPlan.startupBridgeRemovalAvailable &&
            rollbackPlan.backendCompatibilityPreserved &&
            rollbackPlan.v1FallbackPreserved &&
            !rollbackPlan.dataMigrationRequired &&
            !rollbackPlan.destructiveRollbackRequired;
    final open = validProductionConfiguration &&
        readinessAuditorPassed &&
        actualRolloutPrerequisites.appStartupWired &&
        actualRolloutPrerequisites.realRoutesWired &&
        actualRolloutPrerequisites.realScreensWired &&
        actualRolloutPrerequisites.productionTelemetryWired &&
        actualRolloutPrerequisites.platformPermissionDeclarationsConfirmed &&
        actualRolloutPrerequisites.backendDeploymentConfirmed &&
        actualRolloutPrerequisites.appCheckEnforcementConfirmed &&
        actualRolloutPrerequisites.releaseConfigurationReviewed &&
        actualRolloutPrerequisites.rolloutOwnerApproved &&
        actualRolloutPrerequisites.productionSmokeTestPlanApproved &&
        actualRolloutPrerequisites.deploymentApproved &&
        rollbackProcedureConfirmed;

    return CallV2RolloutGateResult(
      status:
          open ? CallV2RolloutGateStatus.open : CallV2RolloutGateStatus.closed,
      validProductionConfiguration: validProductionConfiguration,
      readinessAuditorPassed: readinessAuditorPassed,
      startupIntegrationConfirmed: actualRolloutPrerequisites.appStartupWired,
      routeIntegrationConfirmed: actualRolloutPrerequisites.realRoutesWired,
      screenIntegrationConfirmed: actualRolloutPrerequisites.realScreensWired,
      productionObservabilitySinkConfirmed:
          actualRolloutPrerequisites.productionTelemetryWired,
      platformPermissionDeclarationsConfirmed:
          actualRolloutPrerequisites.platformPermissionDeclarationsConfirmed,
      backendDeploymentConfirmed:
          actualRolloutPrerequisites.backendDeploymentConfirmed,
      appCheckEnforcementConfirmed:
          actualRolloutPrerequisites.appCheckEnforcementConfirmed,
      releaseApprovalConfirmed:
          actualRolloutPrerequisites.rolloutOwnerApproved &&
              actualRolloutPrerequisites.releaseConfigurationReviewed &&
              actualRolloutPrerequisites.deploymentApproved,
      rollbackProcedureConfirmed: rollbackProcedureConfirmed,
    );
  }
}
