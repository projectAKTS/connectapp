enum CallV2ProductionIntegrationPlanStep {
  addProductionDependencyOwner,
  constructProductionCompositionAfterHardGate,
  addProductionRouteSink,
  addProductionCallScreens,
  registerRealGuardedRoutes,
  connectCoordinatorToPresentationLayer,
  addLifecycleOwnership,
  validatePermissions,
  validateAppCheck,
  deployBackend,
  runStagingSmokeTests,
  runRollbackDrill,
  conductLimitedRollout,
  monitor,
  expandRollout,
}

enum CallV2ProductionIntegrationPlanStepStatus {
  blocked,
  notStarted,
}

class CallV2ProductionIntegrationPlanItem {
  const CallV2ProductionIntegrationPlanItem({
    required this.step,
    required this.status,
  });

  final CallV2ProductionIntegrationPlanStep step;
  final CallV2ProductionIntegrationPlanStepStatus status;

  Map<String, String> toSafeDebugMap() {
    return <String, String>{
      'step': step.name,
      'status': status.name,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionIntegrationPlanItem(${toSafeDebugMap()})';
  }
}

class CallV2ProductionIntegrationPlanSnapshot {
  const CallV2ProductionIntegrationPlanSnapshot({required this.items});

  final List<CallV2ProductionIntegrationPlanItem> items;

  CallV2ProductionIntegrationPlanStepStatus statusFor(
    CallV2ProductionIntegrationPlanStep step,
  ) {
    return items.singleWhere((item) => item.step == step).status;
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'items': items.map((item) => item.toSafeDebugMap()).toList(),
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionIntegrationPlanSnapshot(${toSafeDebugMap()})';
  }
}

const callV2ProductionIntegrationPlanSnapshot =
    CallV2ProductionIntegrationPlanSnapshot(
  items: <CallV2ProductionIntegrationPlanItem>[
    CallV2ProductionIntegrationPlanItem(
      step: CallV2ProductionIntegrationPlanStep.addProductionDependencyOwner,
      status: CallV2ProductionIntegrationPlanStepStatus.notStarted,
    ),
    CallV2ProductionIntegrationPlanItem(
      step: CallV2ProductionIntegrationPlanStep
          .constructProductionCompositionAfterHardGate,
      status: CallV2ProductionIntegrationPlanStepStatus.notStarted,
    ),
    CallV2ProductionIntegrationPlanItem(
      step: CallV2ProductionIntegrationPlanStep.addProductionRouteSink,
      status: CallV2ProductionIntegrationPlanStepStatus.notStarted,
    ),
    CallV2ProductionIntegrationPlanItem(
      step: CallV2ProductionIntegrationPlanStep.addProductionCallScreens,
      status: CallV2ProductionIntegrationPlanStepStatus.notStarted,
    ),
    CallV2ProductionIntegrationPlanItem(
      step: CallV2ProductionIntegrationPlanStep.registerRealGuardedRoutes,
      status: CallV2ProductionIntegrationPlanStepStatus.notStarted,
    ),
    CallV2ProductionIntegrationPlanItem(
      step: CallV2ProductionIntegrationPlanStep
          .connectCoordinatorToPresentationLayer,
      status: CallV2ProductionIntegrationPlanStepStatus.notStarted,
    ),
    CallV2ProductionIntegrationPlanItem(
      step: CallV2ProductionIntegrationPlanStep.addLifecycleOwnership,
      status: CallV2ProductionIntegrationPlanStepStatus.notStarted,
    ),
    CallV2ProductionIntegrationPlanItem(
      step: CallV2ProductionIntegrationPlanStep.validatePermissions,
      status: CallV2ProductionIntegrationPlanStepStatus.blocked,
    ),
    CallV2ProductionIntegrationPlanItem(
      step: CallV2ProductionIntegrationPlanStep.validateAppCheck,
      status: CallV2ProductionIntegrationPlanStepStatus.blocked,
    ),
    CallV2ProductionIntegrationPlanItem(
      step: CallV2ProductionIntegrationPlanStep.deployBackend,
      status: CallV2ProductionIntegrationPlanStepStatus.blocked,
    ),
    CallV2ProductionIntegrationPlanItem(
      step: CallV2ProductionIntegrationPlanStep.runStagingSmokeTests,
      status: CallV2ProductionIntegrationPlanStepStatus.blocked,
    ),
    CallV2ProductionIntegrationPlanItem(
      step: CallV2ProductionIntegrationPlanStep.runRollbackDrill,
      status: CallV2ProductionIntegrationPlanStepStatus.blocked,
    ),
    CallV2ProductionIntegrationPlanItem(
      step: CallV2ProductionIntegrationPlanStep.conductLimitedRollout,
      status: CallV2ProductionIntegrationPlanStepStatus.blocked,
    ),
    CallV2ProductionIntegrationPlanItem(
      step: CallV2ProductionIntegrationPlanStep.monitor,
      status: CallV2ProductionIntegrationPlanStepStatus.blocked,
    ),
    CallV2ProductionIntegrationPlanItem(
      step: CallV2ProductionIntegrationPlanStep.expandRollout,
      status: CallV2ProductionIntegrationPlanStepStatus.blocked,
    ),
  ],
);
