class CallV2ProductionIntegrationApproval {
  const CallV2ProductionIntegrationApproval({
    this.architectureReviewApproved = false,
    this.securityReviewApproved = false,
    this.privacyReviewApproved = false,
    this.backendDeploymentConfirmed = false,
    this.firestoreRulesDeploymentConfirmed = false,
    this.callableDeploymentConfirmed = false,
    this.appCheckEnforcementConfirmed = false,
    this.rtcProviderProductionConfigurationConfirmed = false,
    this.iosPermissionDeclarationsConfirmed = false,
    this.androidPermissionDeclarationsConfirmed = false,
    this.productionObservabilitySinkConfirmed = false,
    this.productionSmokePlanApproved = false,
    this.rollbackDrillCompleted = false,
    this.productOwnerApproved = false,
    this.engineeringOwnerApproved = false,
    this.releaseManagerApproved = false,
    this.limitedRolloutApproved = false,
  });

  const CallV2ProductionIntegrationApproval.fullyApproved()
      : architectureReviewApproved = true,
        securityReviewApproved = true,
        privacyReviewApproved = true,
        backendDeploymentConfirmed = true,
        firestoreRulesDeploymentConfirmed = true,
        callableDeploymentConfirmed = true,
        appCheckEnforcementConfirmed = true,
        rtcProviderProductionConfigurationConfirmed = true,
        iosPermissionDeclarationsConfirmed = true,
        androidPermissionDeclarationsConfirmed = true,
        productionObservabilitySinkConfirmed = true,
        productionSmokePlanApproved = true,
        rollbackDrillCompleted = true,
        productOwnerApproved = true,
        engineeringOwnerApproved = true,
        releaseManagerApproved = true,
        limitedRolloutApproved = true;

  final bool architectureReviewApproved;
  final bool securityReviewApproved;
  final bool privacyReviewApproved;
  final bool backendDeploymentConfirmed;
  final bool firestoreRulesDeploymentConfirmed;
  final bool callableDeploymentConfirmed;
  final bool appCheckEnforcementConfirmed;
  final bool rtcProviderProductionConfigurationConfirmed;
  final bool iosPermissionDeclarationsConfirmed;
  final bool androidPermissionDeclarationsConfirmed;
  final bool productionObservabilitySinkConfirmed;
  final bool productionSmokePlanApproved;
  final bool rollbackDrillCompleted;
  final bool productOwnerApproved;
  final bool engineeringOwnerApproved;
  final bool releaseManagerApproved;
  final bool limitedRolloutApproved;

  bool get approvalsComplete {
    return architectureReviewApproved &&
        securityReviewApproved &&
        privacyReviewApproved &&
        backendDeploymentConfirmed &&
        firestoreRulesDeploymentConfirmed &&
        callableDeploymentConfirmed &&
        appCheckEnforcementConfirmed &&
        rtcProviderProductionConfigurationConfirmed &&
        iosPermissionDeclarationsConfirmed &&
        androidPermissionDeclarationsConfirmed &&
        productionObservabilitySinkConfirmed &&
        productionSmokePlanApproved &&
        rollbackDrillCompleted &&
        productOwnerApproved &&
        engineeringOwnerApproved &&
        releaseManagerApproved &&
        limitedRolloutApproved;
  }

  Map<String, bool> toSafeDebugMap() {
    return <String, bool>{
      'architectureReviewApproved': architectureReviewApproved,
      'securityReviewApproved': securityReviewApproved,
      'privacyReviewApproved': privacyReviewApproved,
      'backendDeploymentConfirmed': backendDeploymentConfirmed,
      'firestoreRulesDeploymentConfirmed': firestoreRulesDeploymentConfirmed,
      'callableDeploymentConfirmed': callableDeploymentConfirmed,
      'appCheckEnforcementConfirmed': appCheckEnforcementConfirmed,
      'rtcProviderProductionConfigurationConfirmed':
          rtcProviderProductionConfigurationConfirmed,
      'iosPermissionDeclarationsConfirmed': iosPermissionDeclarationsConfirmed,
      'androidPermissionDeclarationsConfirmed':
          androidPermissionDeclarationsConfirmed,
      'productionObservabilitySinkConfirmed':
          productionObservabilitySinkConfirmed,
      'productionSmokePlanApproved': productionSmokePlanApproved,
      'rollbackDrillCompleted': rollbackDrillCompleted,
      'productOwnerApproved': productOwnerApproved,
      'engineeringOwnerApproved': engineeringOwnerApproved,
      'releaseManagerApproved': releaseManagerApproved,
      'limitedRolloutApproved': limitedRolloutApproved,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionIntegrationApproval(${toSafeDebugMap()})';
  }
}
