import 'call_v2_production_dependency_ownership_plan.dart';
import 'call_v2_production_failure_matrix.dart';
import 'call_v2_production_lifecycle_design.dart';
import 'call_v2_production_route_design.dart';
import 'call_v2_production_security_checklist.dart';

enum CallV2ProductionCompositionStep {
  checkRolloutPolicy,
  checkPreIntegrationApproval,
  requireAuthenticatedUserBoundary,
  requireAppCheckBoundary,
  supplyRuntimeConfigurationExplicitly,
  constructProductionCompositionOnce,
  constructStartupBridge,
  constructUiCoordinator,
  constructPresentationAdapter,
  attachRouteSink,
  startLifecycleOwner,
  runtimeStartsOnlyOnExplicitLaunch,
}

enum CallV2ProductionCompositionInvariant {
  appStartupDoesNotAutomaticallyStartCall,
  compositionConstructionDoesNotInitializeRtc,
  permissionsNotRequestedDuringComposition,
  noRouteBeforeAuthenticatedLaunch,
  noRuntimeStartBeforeGuardedUserAction,
}

enum CallV2ProductionIntegrationNonGoal {
  realAppStartupWiring,
  productionCompositionOwnership,
  realRouteRegistration,
  productionScreens,
  productionNavigationSink,
  runtimeStartup,
  firebaseCalls,
  appCheckEnforcement,
  permissions,
  rtcInitialization,
  observabilityProvider,
  deepLinks,
  notificationRouting,
  nativeCallUi,
  backgroundServices,
  backendDeployment,
  platformPermissionDeclarations,
  rolloutEnablement,
}

enum CallV2ProductionDesignModePolicy {
  dataOnly,
  advisoryOnly,
  immutableModels,
  noCallbacks,
  noServiceInstances,
  noRuntimeWiring,
  noRouteRegistration,
  noScreenImplementation,
  noPlatformApiAccess,
}

class CallV2ProductionIntegrationDesign {
  factory CallV2ProductionIntegrationDesign({
    required List<CallV2ProductionDesignModePolicy> designModePolicies,
    required List<CallV2ProductionCompositionStep> compositionSequence,
    required List<CallV2ProductionCompositionInvariant> compositionInvariants,
    required CallV2ProductionDependencyOwnershipPlan dependencyOwnership,
    required CallV2ProductionRouteDesign routeDesign,
    required CallV2ProductionLifecycleDesign lifecycleDesign,
    required CallV2ProductionFailureMatrix failureMatrix,
    required CallV2ProductionSecurityChecklist securityChecklist,
    required List<CallV2ProductionIntegrationNonGoal> nonGoals,
  }) {
    return CallV2ProductionIntegrationDesign._(
      List<CallV2ProductionDesignModePolicy>.unmodifiable(designModePolicies),
      List<CallV2ProductionCompositionStep>.unmodifiable(compositionSequence),
      List<CallV2ProductionCompositionInvariant>.unmodifiable(
        compositionInvariants,
      ),
      dependencyOwnership,
      routeDesign,
      lifecycleDesign,
      failureMatrix,
      securityChecklist,
      List<CallV2ProductionIntegrationNonGoal>.unmodifiable(nonGoals),
    );
  }

  const CallV2ProductionIntegrationDesign._(
    this.designModePolicies,
    this.compositionSequence,
    this.compositionInvariants,
    this.dependencyOwnership,
    this.routeDesign,
    this.lifecycleDesign,
    this.failureMatrix,
    this.securityChecklist,
    this.nonGoals,
  );

  final List<CallV2ProductionDesignModePolicy> designModePolicies;
  final List<CallV2ProductionCompositionStep> compositionSequence;
  final List<CallV2ProductionCompositionInvariant> compositionInvariants;
  final CallV2ProductionDependencyOwnershipPlan dependencyOwnership;
  final CallV2ProductionRouteDesign routeDesign;
  final CallV2ProductionLifecycleDesign lifecycleDesign;
  final CallV2ProductionFailureMatrix failureMatrix;
  final CallV2ProductionSecurityChecklist securityChecklist;
  final List<CallV2ProductionIntegrationNonGoal> nonGoals;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'designModePolicies':
          designModePolicies.map((policy) => policy.name).toList(),
      'compositionSequence':
          compositionSequence.map((step) => step.name).toList(),
      'compositionInvariants':
          compositionInvariants.map((invariant) => invariant.name).toList(),
      'dependencyOwnership': dependencyOwnership.toSafeDebugMap(),
      'routeDesign': routeDesign.toSafeDebugMap(),
      'lifecycleDesign': lifecycleDesign.toSafeDebugMap(),
      'failureMatrix': failureMatrix.toSafeDebugMap(),
      'securityChecklist': securityChecklist.toSafeDebugMap(),
      'nonGoals': nonGoals.map((nonGoal) => nonGoal.name).toList(),
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionIntegrationDesign(${toSafeDebugMap()})';
  }
}

final callV2ProductionIntegrationDesign = CallV2ProductionIntegrationDesign(
  designModePolicies: <CallV2ProductionDesignModePolicy>[
    CallV2ProductionDesignModePolicy.dataOnly,
    CallV2ProductionDesignModePolicy.advisoryOnly,
    CallV2ProductionDesignModePolicy.immutableModels,
    CallV2ProductionDesignModePolicy.noCallbacks,
    CallV2ProductionDesignModePolicy.noServiceInstances,
    CallV2ProductionDesignModePolicy.noRuntimeWiring,
    CallV2ProductionDesignModePolicy.noRouteRegistration,
    CallV2ProductionDesignModePolicy.noScreenImplementation,
    CallV2ProductionDesignModePolicy.noPlatformApiAccess,
  ],
  compositionSequence: <CallV2ProductionCompositionStep>[
    CallV2ProductionCompositionStep.checkRolloutPolicy,
    CallV2ProductionCompositionStep.checkPreIntegrationApproval,
    CallV2ProductionCompositionStep.requireAuthenticatedUserBoundary,
    CallV2ProductionCompositionStep.requireAppCheckBoundary,
    CallV2ProductionCompositionStep.supplyRuntimeConfigurationExplicitly,
    CallV2ProductionCompositionStep.constructProductionCompositionOnce,
    CallV2ProductionCompositionStep.constructStartupBridge,
    CallV2ProductionCompositionStep.constructUiCoordinator,
    CallV2ProductionCompositionStep.constructPresentationAdapter,
    CallV2ProductionCompositionStep.attachRouteSink,
    CallV2ProductionCompositionStep.startLifecycleOwner,
    CallV2ProductionCompositionStep.runtimeStartsOnlyOnExplicitLaunch,
  ],
  compositionInvariants: <CallV2ProductionCompositionInvariant>[
    CallV2ProductionCompositionInvariant
        .appStartupDoesNotAutomaticallyStartCall,
    CallV2ProductionCompositionInvariant
        .compositionConstructionDoesNotInitializeRtc,
    CallV2ProductionCompositionInvariant
        .permissionsNotRequestedDuringComposition,
    CallV2ProductionCompositionInvariant.noRouteBeforeAuthenticatedLaunch,
    CallV2ProductionCompositionInvariant.noRuntimeStartBeforeGuardedUserAction,
  ],
  dependencyOwnership: callV2ProductionDependencyOwnershipPlan,
  routeDesign: callV2ProductionRouteDesign,
  lifecycleDesign: callV2ProductionLifecycleDesign,
  failureMatrix: callV2ProductionFailureMatrix,
  securityChecklist: callV2ProductionSecurityChecklist,
  nonGoals: <CallV2ProductionIntegrationNonGoal>[
    CallV2ProductionIntegrationNonGoal.realAppStartupWiring,
    CallV2ProductionIntegrationNonGoal.productionCompositionOwnership,
    CallV2ProductionIntegrationNonGoal.realRouteRegistration,
    CallV2ProductionIntegrationNonGoal.productionScreens,
    CallV2ProductionIntegrationNonGoal.productionNavigationSink,
    CallV2ProductionIntegrationNonGoal.runtimeStartup,
    CallV2ProductionIntegrationNonGoal.firebaseCalls,
    CallV2ProductionIntegrationNonGoal.appCheckEnforcement,
    CallV2ProductionIntegrationNonGoal.permissions,
    CallV2ProductionIntegrationNonGoal.rtcInitialization,
    CallV2ProductionIntegrationNonGoal.observabilityProvider,
    CallV2ProductionIntegrationNonGoal.deepLinks,
    CallV2ProductionIntegrationNonGoal.notificationRouting,
    CallV2ProductionIntegrationNonGoal.nativeCallUi,
    CallV2ProductionIntegrationNonGoal.backgroundServices,
    CallV2ProductionIntegrationNonGoal.backendDeployment,
    CallV2ProductionIntegrationNonGoal.platformPermissionDeclarations,
    CallV2ProductionIntegrationNonGoal.rolloutEnablement,
  ],
);
