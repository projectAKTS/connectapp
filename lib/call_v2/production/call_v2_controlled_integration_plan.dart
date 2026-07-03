enum CallV2IntegrationStep {
  verifyProductionFirebaseConfiguration,
  verifyAgoraConfiguration,
  verifyAppCheckEnforcement,
  verifyAuthIdentityFlow,
  verifyMicrophonePermissionStrings,
  verifyCameraPermissionStrings,
  wireCompositionAtStartup,
  registerCallRoutes,
  addCallScreens,
  connectSafeObservabilitySink,
  runStagingSmokeTests,
  runFailureAndRollbackDrills,
  obtainReleaseApproval,
  enableLimitedRollout,
  monitorLimitedRollout,
  expandRollout,
}

enum CallV2IntegrationStepStatus {
  notStarted,
  blocked,
  ready,
  completed,
}

class CallV2IntegrationPlanItem {
  const CallV2IntegrationPlanItem({
    required this.step,
    required this.status,
  });

  final CallV2IntegrationStep step;
  final CallV2IntegrationStepStatus status;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'step': step.name,
      'status': status.name,
    };
  }

  @override
  String toString() {
    return 'CallV2IntegrationPlanItem(${toSafeDebugMap()})';
  }
}

class CallV2ControlledIntegrationPlan {
  const CallV2ControlledIntegrationPlan({required this.items});

  final List<CallV2IntegrationPlanItem> items;

  CallV2IntegrationStepStatus statusFor(CallV2IntegrationStep step) {
    return items.singleWhere((item) => item.step == step).status;
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'items': items.map((item) => item.toSafeDebugMap()).toList(),
    };
  }

  @override
  String toString() {
    return 'CallV2ControlledIntegrationPlan(${toSafeDebugMap()})';
  }
}

const callV2ControlledIntegrationPlan = CallV2ControlledIntegrationPlan(
  items: <CallV2IntegrationPlanItem>[
    CallV2IntegrationPlanItem(
      step: CallV2IntegrationStep.verifyProductionFirebaseConfiguration,
      status: CallV2IntegrationStepStatus.ready,
    ),
    CallV2IntegrationPlanItem(
      step: CallV2IntegrationStep.verifyAgoraConfiguration,
      status: CallV2IntegrationStepStatus.ready,
    ),
    CallV2IntegrationPlanItem(
      step: CallV2IntegrationStep.verifyAppCheckEnforcement,
      status: CallV2IntegrationStepStatus.ready,
    ),
    CallV2IntegrationPlanItem(
      step: CallV2IntegrationStep.verifyAuthIdentityFlow,
      status: CallV2IntegrationStepStatus.ready,
    ),
    CallV2IntegrationPlanItem(
      step: CallV2IntegrationStep.verifyMicrophonePermissionStrings,
      status: CallV2IntegrationStepStatus.ready,
    ),
    CallV2IntegrationPlanItem(
      step: CallV2IntegrationStep.verifyCameraPermissionStrings,
      status: CallV2IntegrationStepStatus.ready,
    ),
    CallV2IntegrationPlanItem(
      step: CallV2IntegrationStep.wireCompositionAtStartup,
      status: CallV2IntegrationStepStatus.notStarted,
    ),
    CallV2IntegrationPlanItem(
      step: CallV2IntegrationStep.registerCallRoutes,
      status: CallV2IntegrationStepStatus.notStarted,
    ),
    CallV2IntegrationPlanItem(
      step: CallV2IntegrationStep.addCallScreens,
      status: CallV2IntegrationStepStatus.notStarted,
    ),
    CallV2IntegrationPlanItem(
      step: CallV2IntegrationStep.connectSafeObservabilitySink,
      status: CallV2IntegrationStepStatus.notStarted,
    ),
    CallV2IntegrationPlanItem(
      step: CallV2IntegrationStep.runStagingSmokeTests,
      status: CallV2IntegrationStepStatus.blocked,
    ),
    CallV2IntegrationPlanItem(
      step: CallV2IntegrationStep.runFailureAndRollbackDrills,
      status: CallV2IntegrationStepStatus.blocked,
    ),
    CallV2IntegrationPlanItem(
      step: CallV2IntegrationStep.obtainReleaseApproval,
      status: CallV2IntegrationStepStatus.blocked,
    ),
    CallV2IntegrationPlanItem(
      step: CallV2IntegrationStep.enableLimitedRollout,
      status: CallV2IntegrationStepStatus.blocked,
    ),
    CallV2IntegrationPlanItem(
      step: CallV2IntegrationStep.monitorLimitedRollout,
      status: CallV2IntegrationStepStatus.blocked,
    ),
    CallV2IntegrationPlanItem(
      step: CallV2IntegrationStep.expandRollout,
      status: CallV2IntegrationStepStatus.blocked,
    ),
  ],
);
