import '../call_v2_contract_manifest.dart';
import '../call_v2_production_capabilities.dart';
import '../call_v2_runtime_configuration.dart';
import '../integration/call_v2_isolated_boundary_evidence.dart';
import '../integration/call_v2_rollout_policy.dart';
import '../observability/call_v2_observability_capabilities.dart';
import 'call_v2_final_readiness_audit.dart';
import 'call_v2_production_integration_approval.dart';

enum CallV2ProductionIntegrationGateStatus {
  blocked,
  approved,
}

enum CallV2ProductionIntegrationGateBlocker {
  architectureReviewMissing,
  securityReviewMissing,
  privacyReviewMissing,
  backendDeploymentMissing,
  firestoreRulesDeploymentMissing,
  callableDeploymentMissing,
  appCheckEnforcementMissing,
  rtcProductionConfigurationMissing,
  iosPermissionsMissing,
  androidPermissionsMissing,
  productionObservabilityMissing,
  smokePlanMissing,
  rollbackDrillMissing,
  productApprovalMissing,
  engineeringApprovalMissing,
  releaseApprovalMissing,
  limitedRolloutApprovalMissing,
  phase3ContractMissing,
  productionAdaptersMissing,
  startupBoundaryMissing,
  uiBoundaryMissing,
  observabilityBoundaryMissing,
  hardDisabledStartupShellMissing,
  hardDisabledRouteRegistryMissing,
  isolatedRouteFactoryMissing,
  isolatedPresentationAdapterMissing,
  isolatedIntegrationHarnessMissing,
  isolatedWidgetHarnessMissing,
  realStartupIntegrationPresent,
  realRouteDestinationPresent,
  productionScreenPresent,
  productionRouteSinkPresent,
  runtimeStartupPresent,
  rolloutFlagEnabled,
}

class CallV2PreIntegrationStructuralEvidence {
  const CallV2PreIntegrationStructuralEvidence({
    required this.isolatedRouteFactoryAvailable,
    required this.isolatedPresentationAdapterAvailable,
    required this.isolatedIntegrationHarnessAvailable,
    required this.isolatedWidgetHarnessAvailable,
  });

  factory CallV2PreIntegrationStructuralEvidence.fromAcceptedTypes() {
    final evidence = buildCallV2IsolatedBoundaryEvidence();
    return CallV2PreIntegrationStructuralEvidence.fromBoundaryEvidence(
      evidence,
    );
  }

  factory CallV2PreIntegrationStructuralEvidence.fromBoundaryEvidence(
    CallV2IsolatedBoundaryEvidence evidence,
  ) {
    return CallV2PreIntegrationStructuralEvidence(
      isolatedRouteFactoryAvailable: evidence.routeFactoryAvailable,
      isolatedPresentationAdapterAvailable:
          evidence.presentationAdapterAvailable,
      isolatedIntegrationHarnessAvailable: evidence.integrationHarnessAvailable,
      isolatedWidgetHarnessAvailable:
          evidence.widgetNavigationBoundaryAvailable,
    );
  }

  final bool isolatedRouteFactoryAvailable;
  final bool isolatedPresentationAdapterAvailable;
  final bool isolatedIntegrationHarnessAvailable;
  final bool isolatedWidgetHarnessAvailable;

  Map<String, bool> toSafeDebugMap() {
    return <String, bool>{
      'isolatedRouteFactoryAvailable': isolatedRouteFactoryAvailable,
      'isolatedPresentationAdapterAvailable':
          isolatedPresentationAdapterAvailable,
      'isolatedIntegrationHarnessAvailable':
          isolatedIntegrationHarnessAvailable,
      'isolatedWidgetHarnessAvailable': isolatedWidgetHarnessAvailable,
    };
  }
}

class CallV2ProductionIntegrationGateResult {
  const CallV2ProductionIntegrationGateResult({
    required this.phase3ContractAccepted,
    required this.productionAdaptersReady,
    required this.startupBoundaryReady,
    required this.uiBoundaryReady,
    required this.observabilityBoundaryReady,
    required this.hardDisabledStartupShellPresent,
    required this.hardDisabledRouteRegistryPresent,
    required this.isolatedRouteFactoryVerified,
    required this.isolatedPresentationAdapterVerified,
    required this.isolatedIntegrationHarnessVerified,
    required this.isolatedWidgetHarnessVerified,
    required this.realStartupIntegrationAbsent,
    required this.realRouteDestinationAbsent,
    required this.productionScreenAbsent,
    required this.productionRouteSinkAbsent,
    required this.runtimeStartupAbsent,
    required this.rolloutFlagDisabled,
    required this.approvalsComplete,
    required this.structurallyReady,
    required this.actualIntegrationAuthorized,
    required this.rolloutAuthorized,
    required this.status,
    required this.blockers,
  });

  final bool phase3ContractAccepted;
  final bool productionAdaptersReady;
  final bool startupBoundaryReady;
  final bool uiBoundaryReady;
  final bool observabilityBoundaryReady;
  final bool hardDisabledStartupShellPresent;
  final bool hardDisabledRouteRegistryPresent;
  final bool isolatedRouteFactoryVerified;
  final bool isolatedPresentationAdapterVerified;
  final bool isolatedIntegrationHarnessVerified;
  final bool isolatedWidgetHarnessVerified;
  final bool realStartupIntegrationAbsent;
  final bool realRouteDestinationAbsent;
  final bool productionScreenAbsent;
  final bool productionRouteSinkAbsent;
  final bool runtimeStartupAbsent;
  final bool rolloutFlagDisabled;
  final bool approvalsComplete;
  final bool structurallyReady;
  final bool actualIntegrationAuthorized;
  final bool rolloutAuthorized;
  final CallV2ProductionIntegrationGateStatus status;
  final Set<CallV2ProductionIntegrationGateBlocker> blockers;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'phase3ContractAccepted': phase3ContractAccepted,
      'productionAdaptersReady': productionAdaptersReady,
      'startupBoundaryReady': startupBoundaryReady,
      'uiBoundaryReady': uiBoundaryReady,
      'observabilityBoundaryReady': observabilityBoundaryReady,
      'hardDisabledStartupShellPresent': hardDisabledStartupShellPresent,
      'hardDisabledRouteRegistryPresent': hardDisabledRouteRegistryPresent,
      'isolatedRouteFactoryVerified': isolatedRouteFactoryVerified,
      'isolatedPresentationAdapterVerified':
          isolatedPresentationAdapterVerified,
      'isolatedIntegrationHarnessVerified': isolatedIntegrationHarnessVerified,
      'isolatedWidgetHarnessVerified': isolatedWidgetHarnessVerified,
      'realStartupIntegrationAbsent': realStartupIntegrationAbsent,
      'realRouteDestinationAbsent': realRouteDestinationAbsent,
      'productionScreenAbsent': productionScreenAbsent,
      'productionRouteSinkAbsent': productionRouteSinkAbsent,
      'runtimeStartupAbsent': runtimeStartupAbsent,
      'rolloutFlagDisabled': rolloutFlagDisabled,
      'approvalsComplete': approvalsComplete,
      'structurallyReady': structurallyReady,
      'actualIntegrationAuthorized': actualIntegrationAuthorized,
      'rolloutAuthorized': rolloutAuthorized,
      'status': status.name,
      'blockers': blockers.map((blocker) => blocker.name).toList(),
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionIntegrationGateResult(${toSafeDebugMap()})';
  }
}

class CallV2PreIntegrationGate {
  const CallV2PreIntegrationGate({
    this.finalReadinessAuditor = const CallV2FinalReadinessAuditor(),
  });

  final CallV2FinalReadinessAuditor finalReadinessAuditor;

  CallV2ProductionIntegrationGateResult evaluate({
    CallV2ProductionIntegrationApproval approval =
        const CallV2ProductionIntegrationApproval(),
    CallV2ContractManifest manifest = callV2Phase3ContractManifest,
    CallV2RuntimeConfiguration configuration =
        _callV2PreIntegrationProductionConfiguration,
    CallV2ProductionCapabilities capabilities =
        callV2IsolatedObservabilityCapabilities,
    CallV2ActualRolloutPrerequisites actualRolloutPrerequisites =
        const CallV2ActualRolloutPrerequisites(),
    CallV2PreIntegrationStructuralEvidence? structuralEvidence,
  }) {
    final evidence = structuralEvidence ??
        CallV2PreIntegrationStructuralEvidence.fromAcceptedTypes();
    final finalReadiness = finalReadinessAuditor.audit(
      manifest: manifest,
      configuration: configuration,
      capabilities: capabilities,
      actualRolloutPrerequisites: actualRolloutPrerequisites,
    );

    final phase3ContractAccepted = finalReadiness.contractManifestAccepted &&
        finalReadiness.runtimeGraphAccepted;
    final productionAdaptersReady = finalReadiness.readyForProductionEnablement;
    final startupBoundaryReady = finalReadiness.startupBridgeAvailable;
    final uiBoundaryReady = finalReadiness.uiRouteContractAvailable;
    final observabilityBoundaryReady = finalReadiness.observabilityAvailable;
    final hardDisabledStartupShellPresent =
        !CallV2RolloutPolicy.productionEnabled &&
            manifest.startupUiRoutesNativeWiringAbsent;
    final hardDisabledRouteRegistryPresent =
        !CallV2RolloutPolicy.productionEnabled &&
            manifest.startupUiRoutesNativeWiringAbsent;
    final isolatedRouteFactoryVerified = evidence.isolatedRouteFactoryAvailable;
    final isolatedPresentationAdapterVerified =
        evidence.isolatedPresentationAdapterAvailable;
    final isolatedIntegrationHarnessVerified =
        evidence.isolatedIntegrationHarnessAvailable;
    final isolatedWidgetHarnessVerified =
        evidence.isolatedWidgetHarnessAvailable;
    final realStartupIntegrationAbsent = !finalReadiness.appStartupWired;
    final realRouteDestinationAbsent = !finalReadiness.realRoutesWired;
    final productionScreenAbsent = !finalReadiness.realScreensWired;
    final productionRouteSinkAbsent = !finalReadiness.realRoutesWired;
    final runtimeStartupAbsent = !finalReadiness.appStartupWired;
    final rolloutFlagDisabled = !CallV2RolloutPolicy.productionEnabled;
    final approvalsComplete = approval.approvalsComplete;
    final structurallyReady = phase3ContractAccepted &&
        productionAdaptersReady &&
        startupBoundaryReady &&
        uiBoundaryReady &&
        observabilityBoundaryReady &&
        hardDisabledStartupShellPresent &&
        hardDisabledRouteRegistryPresent &&
        isolatedRouteFactoryVerified &&
        isolatedPresentationAdapterVerified &&
        isolatedIntegrationHarnessVerified &&
        isolatedWidgetHarnessVerified &&
        realStartupIntegrationAbsent &&
        realRouteDestinationAbsent &&
        productionScreenAbsent &&
        productionRouteSinkAbsent &&
        runtimeStartupAbsent &&
        rolloutFlagDisabled;
    final actualIntegrationAuthorized = approvalsComplete &&
        finalReadiness.appStartupWired &&
        finalReadiness.realRoutesWired &&
        finalReadiness.realScreensWired &&
        finalReadiness.productionTelemetryWired &&
        CallV2RolloutPolicy.productionEnabled;
    final rolloutAuthorized =
        actualIntegrationAuthorized && finalReadiness.readyForActualRollout;
    final status = structurallyReady && approvalsComplete
        ? CallV2ProductionIntegrationGateStatus.approved
        : CallV2ProductionIntegrationGateStatus.blocked;

    return CallV2ProductionIntegrationGateResult(
      phase3ContractAccepted: phase3ContractAccepted,
      productionAdaptersReady: productionAdaptersReady,
      startupBoundaryReady: startupBoundaryReady,
      uiBoundaryReady: uiBoundaryReady,
      observabilityBoundaryReady: observabilityBoundaryReady,
      hardDisabledStartupShellPresent: hardDisabledStartupShellPresent,
      hardDisabledRouteRegistryPresent: hardDisabledRouteRegistryPresent,
      isolatedRouteFactoryVerified: isolatedRouteFactoryVerified,
      isolatedPresentationAdapterVerified: isolatedPresentationAdapterVerified,
      isolatedIntegrationHarnessVerified: isolatedIntegrationHarnessVerified,
      isolatedWidgetHarnessVerified: isolatedWidgetHarnessVerified,
      realStartupIntegrationAbsent: realStartupIntegrationAbsent,
      realRouteDestinationAbsent: realRouteDestinationAbsent,
      productionScreenAbsent: productionScreenAbsent,
      productionRouteSinkAbsent: productionRouteSinkAbsent,
      runtimeStartupAbsent: runtimeStartupAbsent,
      rolloutFlagDisabled: rolloutFlagDisabled,
      approvalsComplete: approvalsComplete,
      structurallyReady: structurallyReady,
      actualIntegrationAuthorized: actualIntegrationAuthorized,
      rolloutAuthorized: rolloutAuthorized,
      status: status,
      blockers: Set<CallV2ProductionIntegrationGateBlocker>.unmodifiable(
        _blockers(
          approval: approval,
          phase3ContractAccepted: phase3ContractAccepted,
          productionAdaptersReady: productionAdaptersReady,
          startupBoundaryReady: startupBoundaryReady,
          uiBoundaryReady: uiBoundaryReady,
          observabilityBoundaryReady: observabilityBoundaryReady,
          hardDisabledStartupShellPresent: hardDisabledStartupShellPresent,
          hardDisabledRouteRegistryPresent: hardDisabledRouteRegistryPresent,
          isolatedRouteFactoryVerified: isolatedRouteFactoryVerified,
          isolatedPresentationAdapterVerified:
              isolatedPresentationAdapterVerified,
          isolatedIntegrationHarnessVerified:
              isolatedIntegrationHarnessVerified,
          isolatedWidgetHarnessVerified: isolatedWidgetHarnessVerified,
          realStartupIntegrationAbsent: realStartupIntegrationAbsent,
          realRouteDestinationAbsent: realRouteDestinationAbsent,
          productionScreenAbsent: productionScreenAbsent,
          productionRouteSinkAbsent: productionRouteSinkAbsent,
          runtimeStartupAbsent: runtimeStartupAbsent,
          rolloutFlagDisabled: rolloutFlagDisabled,
        ),
      ),
    );
  }

  List<CallV2ProductionIntegrationGateBlocker> _blockers({
    required CallV2ProductionIntegrationApproval approval,
    required bool phase3ContractAccepted,
    required bool productionAdaptersReady,
    required bool startupBoundaryReady,
    required bool uiBoundaryReady,
    required bool observabilityBoundaryReady,
    required bool hardDisabledStartupShellPresent,
    required bool hardDisabledRouteRegistryPresent,
    required bool isolatedRouteFactoryVerified,
    required bool isolatedPresentationAdapterVerified,
    required bool isolatedIntegrationHarnessVerified,
    required bool isolatedWidgetHarnessVerified,
    required bool realStartupIntegrationAbsent,
    required bool realRouteDestinationAbsent,
    required bool productionScreenAbsent,
    required bool productionRouteSinkAbsent,
    required bool runtimeStartupAbsent,
    required bool rolloutFlagDisabled,
  }) {
    final blockers = <CallV2ProductionIntegrationGateBlocker>[];
    void require(
      bool condition,
      CallV2ProductionIntegrationGateBlocker blocker,
    ) {
      if (!condition) blockers.add(blocker);
    }

    require(
      approval.architectureReviewApproved,
      CallV2ProductionIntegrationGateBlocker.architectureReviewMissing,
    );
    require(
      approval.securityReviewApproved,
      CallV2ProductionIntegrationGateBlocker.securityReviewMissing,
    );
    require(
      approval.privacyReviewApproved,
      CallV2ProductionIntegrationGateBlocker.privacyReviewMissing,
    );
    require(
      approval.backendDeploymentConfirmed,
      CallV2ProductionIntegrationGateBlocker.backendDeploymentMissing,
    );
    require(
      approval.firestoreRulesDeploymentConfirmed,
      CallV2ProductionIntegrationGateBlocker.firestoreRulesDeploymentMissing,
    );
    require(
      approval.callableDeploymentConfirmed,
      CallV2ProductionIntegrationGateBlocker.callableDeploymentMissing,
    );
    require(
      approval.appCheckEnforcementConfirmed,
      CallV2ProductionIntegrationGateBlocker.appCheckEnforcementMissing,
    );
    require(
      approval.rtcProviderProductionConfigurationConfirmed,
      CallV2ProductionIntegrationGateBlocker.rtcProductionConfigurationMissing,
    );
    require(
      approval.iosPermissionDeclarationsConfirmed,
      CallV2ProductionIntegrationGateBlocker.iosPermissionsMissing,
    );
    require(
      approval.androidPermissionDeclarationsConfirmed,
      CallV2ProductionIntegrationGateBlocker.androidPermissionsMissing,
    );
    require(
      approval.productionObservabilitySinkConfirmed,
      CallV2ProductionIntegrationGateBlocker.productionObservabilityMissing,
    );
    require(
      approval.productionSmokePlanApproved,
      CallV2ProductionIntegrationGateBlocker.smokePlanMissing,
    );
    require(
      approval.rollbackDrillCompleted,
      CallV2ProductionIntegrationGateBlocker.rollbackDrillMissing,
    );
    require(
      approval.productOwnerApproved,
      CallV2ProductionIntegrationGateBlocker.productApprovalMissing,
    );
    require(
      approval.engineeringOwnerApproved,
      CallV2ProductionIntegrationGateBlocker.engineeringApprovalMissing,
    );
    require(
      approval.releaseManagerApproved,
      CallV2ProductionIntegrationGateBlocker.releaseApprovalMissing,
    );
    require(
      approval.limitedRolloutApproved,
      CallV2ProductionIntegrationGateBlocker.limitedRolloutApprovalMissing,
    );
    require(
      phase3ContractAccepted,
      CallV2ProductionIntegrationGateBlocker.phase3ContractMissing,
    );
    require(
      productionAdaptersReady,
      CallV2ProductionIntegrationGateBlocker.productionAdaptersMissing,
    );
    require(
      startupBoundaryReady,
      CallV2ProductionIntegrationGateBlocker.startupBoundaryMissing,
    );
    require(
      uiBoundaryReady,
      CallV2ProductionIntegrationGateBlocker.uiBoundaryMissing,
    );
    require(
      observabilityBoundaryReady,
      CallV2ProductionIntegrationGateBlocker.observabilityBoundaryMissing,
    );
    require(
      hardDisabledStartupShellPresent,
      CallV2ProductionIntegrationGateBlocker.hardDisabledStartupShellMissing,
    );
    require(
      hardDisabledRouteRegistryPresent,
      CallV2ProductionIntegrationGateBlocker.hardDisabledRouteRegistryMissing,
    );
    require(
      isolatedRouteFactoryVerified,
      CallV2ProductionIntegrationGateBlocker.isolatedRouteFactoryMissing,
    );
    require(
      isolatedPresentationAdapterVerified,
      CallV2ProductionIntegrationGateBlocker.isolatedPresentationAdapterMissing,
    );
    require(
      isolatedIntegrationHarnessVerified,
      CallV2ProductionIntegrationGateBlocker.isolatedIntegrationHarnessMissing,
    );
    require(
      isolatedWidgetHarnessVerified,
      CallV2ProductionIntegrationGateBlocker.isolatedWidgetHarnessMissing,
    );
    require(
      realStartupIntegrationAbsent,
      CallV2ProductionIntegrationGateBlocker.realStartupIntegrationPresent,
    );
    require(
      realRouteDestinationAbsent,
      CallV2ProductionIntegrationGateBlocker.realRouteDestinationPresent,
    );
    require(
      productionScreenAbsent,
      CallV2ProductionIntegrationGateBlocker.productionScreenPresent,
    );
    require(
      productionRouteSinkAbsent,
      CallV2ProductionIntegrationGateBlocker.productionRouteSinkPresent,
    );
    require(
      runtimeStartupAbsent,
      CallV2ProductionIntegrationGateBlocker.runtimeStartupPresent,
    );
    require(
      rolloutFlagDisabled,
      CallV2ProductionIntegrationGateBlocker.rolloutFlagEnabled,
    );
    return blockers;
  }
}

const _callV2PreIntegrationProductionConfiguration = CallV2RuntimeConfiguration(
  enabled: true,
  environment: CallV2Environment.production,
  rtcProvider: CallV2RtcProviderKind.agora,
  rtcAppIdReference: 'CALL_V2_AGORA_APP_ID_REFERENCE',
  callCollectionName: 'calls',
  participantSubcollectionName: 'participants',
  rtcTokenMaxLifetime: callV2AcceptedRtcTokenMaxLifetime,
  minimumTokenRemainingValidity: Duration(seconds: 60),
);
