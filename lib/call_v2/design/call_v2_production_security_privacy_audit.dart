enum CallV2ProductionSensitiveDataCategory {
  uid,
  callId,
  participantId,
  token,
  credential,
  channel,
  routeArgument,
  rawBackendPayload,
  rawException,
  stackTrace,
  arbitraryRouteString,
}

enum CallV2ProductionSafeDebugField {
  status,
  lifecycle,
  destination,
  generation,
  error,
  disposed,
  terminal,
  rolloutEnabled,
  eventType,
  policy,
  booleanFlag,
}

enum CallV2ProductionRoutePayloadRule {
  fixedCanonicalRouteNamesOnly,
  routeSettingsArgumentsNull,
  noDynamicIdentifierSegments,
  noQueryOrFragment,
  noCredentialOrTokenMaterial,
}

enum CallV2ProductionLoggingConstraint {
  noPrint,
  noDebugPrint,
  noLogger,
  noAnalytics,
  noRawExceptionMessage,
  noStackTrace,
  nonCallV2FindingsRemainBacklogOnly,
}

enum CallV2ProductionWidgetPrivacyConstraint {
  keysUseStaticCallV2LabelsOnly,
  semanticsUseGenericLabelsOnly,
  failureCopyUsesControlledGenericText,
  noIdentifiersInLabels,
}

enum CallV2ProductionIsolationConstraint {
  rolloutDisabled,
  noMainWiring,
  noAppRouterWiring,
  noRouteRegistryEnablement,
  noStartupWiring,
  noProductionCompositionWiring,
  noFirebaseBackendRtcPermissionAccess,
  noNavigatorKeyOrContextStorage,
  noTimersStreamsOrSubscriptions,
  noDependencyPlatformOrConfigChanges,
  backupBranchProtected,
}

enum CallV2ProductionBacklogFinding {
  appCheckDebugTokenLoggingOutsideCallV2,
  chatRouteArgumentLoggingOutsideCallV2,
}

enum CallV2ProductionManualApprovalGate {
  exposeRouteArguments,
  addCallV2Logging,
  addDynamicRouteNames,
  wireRealAppRoutes,
  enableRollout,
  relaxSensitiveDataPolicy,
}

final class CallV2ProductionSecurityPrivacyAudit {
  const CallV2ProductionSecurityPrivacyAudit({
    required this.allowedRouteNames,
    required this.forbiddenSensitiveCategories,
    required this.allowedSafeDebugFields,
    required this.routePayloadRules,
    required this.loggingConstraints,
    required this.widgetPrivacyConstraints,
    required this.isolationConstraints,
    required this.backlogFindings,
    required this.manualApprovalGates,
  });

  final Set<String> allowedRouteNames;
  final Set<CallV2ProductionSensitiveDataCategory> forbiddenSensitiveCategories;
  final Set<CallV2ProductionSafeDebugField> allowedSafeDebugFields;
  final Set<CallV2ProductionRoutePayloadRule> routePayloadRules;
  final Set<CallV2ProductionLoggingConstraint> loggingConstraints;
  final Set<CallV2ProductionWidgetPrivacyConstraint> widgetPrivacyConstraints;
  final Set<CallV2ProductionIsolationConstraint> isolationConstraints;
  final Set<CallV2ProductionBacklogFinding> backlogFindings;
  final Set<CallV2ProductionManualApprovalGate> manualApprovalGates;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'allowedRouteCount': allowedRouteNames.length,
      'forbiddenSensitiveCategoryCount': forbiddenSensitiveCategories.length,
      'allowedSafeDebugFieldCount': allowedSafeDebugFields.length,
      'routePayloadRuleCount': routePayloadRules.length,
      'loggingConstraintCount': loggingConstraints.length,
      'widgetPrivacyConstraintCount': widgetPrivacyConstraints.length,
      'isolationConstraintCount': isolationConstraints.length,
      'backlogFindingCount': backlogFindings.length,
      'manualApprovalGateCount': manualApprovalGates.length,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionSecurityPrivacyAudit(${toSafeDebugMap()})';
  }
}

const callV2ProductionSecurityPrivacyAudit =
    CallV2ProductionSecurityPrivacyAudit(
  allowedRouteNames: <String>{
    '/call-v2/connecting',
    '/call-v2/audio',
    '/call-v2/video',
    '/call-v2/failure',
  },
  forbiddenSensitiveCategories: <CallV2ProductionSensitiveDataCategory>{
    CallV2ProductionSensitiveDataCategory.uid,
    CallV2ProductionSensitiveDataCategory.callId,
    CallV2ProductionSensitiveDataCategory.participantId,
    CallV2ProductionSensitiveDataCategory.token,
    CallV2ProductionSensitiveDataCategory.credential,
    CallV2ProductionSensitiveDataCategory.channel,
    CallV2ProductionSensitiveDataCategory.routeArgument,
    CallV2ProductionSensitiveDataCategory.rawBackendPayload,
    CallV2ProductionSensitiveDataCategory.rawException,
    CallV2ProductionSensitiveDataCategory.stackTrace,
    CallV2ProductionSensitiveDataCategory.arbitraryRouteString,
  },
  allowedSafeDebugFields: <CallV2ProductionSafeDebugField>{
    CallV2ProductionSafeDebugField.status,
    CallV2ProductionSafeDebugField.lifecycle,
    CallV2ProductionSafeDebugField.destination,
    CallV2ProductionSafeDebugField.generation,
    CallV2ProductionSafeDebugField.error,
    CallV2ProductionSafeDebugField.disposed,
    CallV2ProductionSafeDebugField.terminal,
    CallV2ProductionSafeDebugField.rolloutEnabled,
    CallV2ProductionSafeDebugField.eventType,
    CallV2ProductionSafeDebugField.policy,
    CallV2ProductionSafeDebugField.booleanFlag,
  },
  routePayloadRules: <CallV2ProductionRoutePayloadRule>{
    CallV2ProductionRoutePayloadRule.fixedCanonicalRouteNamesOnly,
    CallV2ProductionRoutePayloadRule.routeSettingsArgumentsNull,
    CallV2ProductionRoutePayloadRule.noDynamicIdentifierSegments,
    CallV2ProductionRoutePayloadRule.noQueryOrFragment,
    CallV2ProductionRoutePayloadRule.noCredentialOrTokenMaterial,
  },
  loggingConstraints: <CallV2ProductionLoggingConstraint>{
    CallV2ProductionLoggingConstraint.noPrint,
    CallV2ProductionLoggingConstraint.noDebugPrint,
    CallV2ProductionLoggingConstraint.noLogger,
    CallV2ProductionLoggingConstraint.noAnalytics,
    CallV2ProductionLoggingConstraint.noRawExceptionMessage,
    CallV2ProductionLoggingConstraint.noStackTrace,
    CallV2ProductionLoggingConstraint.nonCallV2FindingsRemainBacklogOnly,
  },
  widgetPrivacyConstraints: <CallV2ProductionWidgetPrivacyConstraint>{
    CallV2ProductionWidgetPrivacyConstraint.keysUseStaticCallV2LabelsOnly,
    CallV2ProductionWidgetPrivacyConstraint.semanticsUseGenericLabelsOnly,
    CallV2ProductionWidgetPrivacyConstraint
        .failureCopyUsesControlledGenericText,
    CallV2ProductionWidgetPrivacyConstraint.noIdentifiersInLabels,
  },
  isolationConstraints: <CallV2ProductionIsolationConstraint>{
    CallV2ProductionIsolationConstraint.rolloutDisabled,
    CallV2ProductionIsolationConstraint.noMainWiring,
    CallV2ProductionIsolationConstraint.noAppRouterWiring,
    CallV2ProductionIsolationConstraint.noRouteRegistryEnablement,
    CallV2ProductionIsolationConstraint.noStartupWiring,
    CallV2ProductionIsolationConstraint.noProductionCompositionWiring,
    CallV2ProductionIsolationConstraint.noFirebaseBackendRtcPermissionAccess,
    CallV2ProductionIsolationConstraint.noNavigatorKeyOrContextStorage,
    CallV2ProductionIsolationConstraint.noTimersStreamsOrSubscriptions,
    CallV2ProductionIsolationConstraint.noDependencyPlatformOrConfigChanges,
    CallV2ProductionIsolationConstraint.backupBranchProtected,
  },
  backlogFindings: <CallV2ProductionBacklogFinding>{
    CallV2ProductionBacklogFinding.appCheckDebugTokenLoggingOutsideCallV2,
    CallV2ProductionBacklogFinding.chatRouteArgumentLoggingOutsideCallV2,
  },
  manualApprovalGates: <CallV2ProductionManualApprovalGate>{
    CallV2ProductionManualApprovalGate.exposeRouteArguments,
    CallV2ProductionManualApprovalGate.addCallV2Logging,
    CallV2ProductionManualApprovalGate.addDynamicRouteNames,
    CallV2ProductionManualApprovalGate.wireRealAppRoutes,
    CallV2ProductionManualApprovalGate.enableRollout,
    CallV2ProductionManualApprovalGate.relaxSensitiveDataPolicy,
  },
);
