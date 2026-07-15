import 'call_v2_developer_pre_wiring_safety_gate.dart';

enum CallV2DeveloperRtcPermissionApprovalEvidence {
  phase7YHumanApproved,
  rtcPermissionOwnerOnly,
  developerOnly,
  rolloutFalse,
  noRuntimeConstruction,
  noRuntimeStartup,
  noBackendFirebase,
  noNavigation,
  noLifecycleRegistration,
  noRouteRegistryMutation,
  noMediaEngine,
  noRtcChannelJoin,
  noRtcTokenChannelConsumption,
  noPermissionRequest,
  noMicrophoneCameraPrompt,
  noDeviceEnumeration,
  noMediaCapture,
  noCameraPreview,
  noAudioVideoPublish,
  noRtcCallbacksListenersSubscriptions,
  noProductionServiceContact,
  noStartupMainRouterWiring,
  noPubspecPlatformConfig,
  noRulesFunctionsConfig,
  noDeployment,
  v1Protected,
}

enum CallV2DeveloperRtcPermissionApprovalRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2DeveloperRtcPermissionApprovalScope {
  factory CallV2DeveloperRtcPermissionApprovalScope({
    required CallV2DeveloperPreWiringSafetyGate preWiringGate,
    required List<CallV2DeveloperRtcPermissionApprovalEvidence> evidence,
    required List<String> allowedFutureFiles,
    required List<String> forbiddenFutureFiles,
    required List<CallV2DeveloperRtcPermissionApprovalRollback> rollback,
  }) {
    return CallV2DeveloperRtcPermissionApprovalScope._(
      preWiringGate,
      List<CallV2DeveloperRtcPermissionApprovalEvidence>.unmodifiable(
        evidence,
      ),
      List<String>.unmodifiable(allowedFutureFiles),
      List<String>.unmodifiable(forbiddenFutureFiles),
      List<CallV2DeveloperRtcPermissionApprovalRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2DeveloperRtcPermissionApprovalScope._(
    this.preWiringGate,
    this.evidence,
    this.allowedFutureFiles,
    this.forbiddenFutureFiles,
    this.rollback,
  );

  final CallV2DeveloperPreWiringSafetyGate preWiringGate;
  final List<CallV2DeveloperRtcPermissionApprovalEvidence> evidence;
  final List<String> allowedFutureFiles;
  final List<String> forbiddenFutureFiles;
  final List<CallV2DeveloperRtcPermissionApprovalRollback> rollback;

  CallV2DeveloperPreWiringSafetyGate get evaluatedGate =>
      preWiringGate.evaluateFutureScope(
        selectedScope: CallV2DeveloperPreWiringScope.rtcPermissionOwnerOnly,
        explicitFutureApproval: true,
        allowedFilesListed: true,
        oneCommitRollbackConfirmed: true,
      );

  bool get hasHumanApproval => evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence.phase7YHumanApproved,
      );

  bool get isRtcPermissionOwnerOnly => evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence.rtcPermissionOwnerOnly,
      );

  bool get isDeveloperOnly => evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence.developerOnly,
      );

  bool get isRolloutEnabled => !evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence.rolloutFalse,
      );

  bool get constructsRuntime => !evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence.noRuntimeConstruction,
      );

  bool get startsRuntime => !evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence.noRuntimeStartup,
      );

  bool get accessesBackendFirebase => !evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence.noBackendFirebase,
      );

  bool get wiresNavigation => !evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence.noNavigation,
      );

  bool get registersLifecycleObserver => !evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence.noLifecycleRegistration,
      );

  bool get mutatesRouteRegistry => !evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence.noRouteRegistryMutation,
      );

  bool get createsProviderMediaEngine => !evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence.noMediaEngine,
      );

  bool get joinsRtcChannel => !evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence.noRtcChannelJoin,
      );

  bool get consumesRtcTokenChannel => !evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence
            .noRtcTokenChannelConsumption,
      );

  bool get requestsPermission => !evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence.noPermissionRequest,
      );

  bool get promptsMicrophoneCamera => !evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence.noMicrophoneCameraPrompt,
      );

  bool get enumeratesDevices => !evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence.noDeviceEnumeration,
      );

  bool get capturesMedia => !evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence.noMediaCapture,
      );

  bool get startsCameraPreview => !evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence.noCameraPreview,
      );

  bool get publishesAudioVideo => !evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence.noAudioVideoPublish,
      );

  bool get opensRtcCallbacksListenersSubscriptions => !evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence
            .noRtcCallbacksListenersSubscriptions,
      );

  bool get contactsProductionServices => !evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence.noProductionServiceContact,
      );

  bool get wiresStartupMainRouter => !evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence.noStartupMainRouterWiring,
      );

  bool get changesPubspecPlatformConfig => !evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence.noPubspecPlatformConfig,
      );

  bool get changesRulesFunctionsConfig => !evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence.noRulesFunctionsConfig,
      );

  bool get isDeploymentApproved => !evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence.noDeployment,
      );

  bool get protectsV1 => evidence.contains(
        CallV2DeveloperRtcPermissionApprovalEvidence.v1Protected,
      );

  bool get allowedFutureFilesAreRtcPermissionOwnerOnly =>
      allowedFutureFiles.length == 2 &&
      allowedFutureFiles.contains(
        'lib/call_v2/integration/call_v2_rtc_permission_owner.dart',
      ) &&
      allowedFutureFiles.contains(
        'test/call_v2/integration/call_v2_rtc_permission_owner_test.dart',
      );

  bool get forbidsOutOfScopeFutureFiles =>
      forbiddenFutureFiles.contains('lib/main.dart') &&
      forbiddenFutureFiles.contains('lib/navigation/app_router.dart') &&
      forbiddenFutureFiles.contains('lib/call_v2/startup/**') &&
      forbiddenFutureFiles.contains('lib/call_v2/runtime/**') &&
      forbiddenFutureFiles.contains('lib/call_v2/firebase/**') &&
      forbiddenFutureFiles.contains(
        'lib/call_v2/integration/call_v2_route_registry.dart',
      ) &&
      forbiddenFutureFiles.contains(
        'lib/call_v2/integration/call_v2_lifecycle_observer.dart',
      ) &&
      forbiddenFutureFiles.contains(
        'lib/call_v2/integration/call_v2_navigator_owner.dart',
      ) &&
      forbiddenFutureFiles.contains(
        'lib/call_v2/integration/call_v2_backend_firebase_owner.dart',
      ) &&
      forbiddenFutureFiles.contains(
        'lib/call_v2/production/call_v2_production_composition.dart',
      ) &&
      forbiddenFutureFiles.contains('lib/call_v2/rtc/**') &&
      forbiddenFutureFiles.contains('lib/call_v2/permissions/**') &&
      forbiddenFutureFiles.contains('pubspec.yaml') &&
      forbiddenFutureFiles.contains('pubspec.lock') &&
      forbiddenFutureFiles.contains('android/**') &&
      forbiddenFutureFiles.contains('ios/**') &&
      forbiddenFutureFiles.contains('macos/**') &&
      forbiddenFutureFiles.contains('web/**') &&
      forbiddenFutureFiles.contains('firestore.rules') &&
      forbiddenFutureFiles.contains('firebase.json') &&
      forbiddenFutureFiles.contains('connect_functions/**');

  bool get rollbackPreserved =>
      rollback.contains(
        CallV2DeveloperRtcPermissionApprovalRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2DeveloperRtcPermissionApprovalRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2DeveloperRtcPermissionApprovalRollback.keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2DeveloperRtcPermissionApprovalRollback.keepDisabledOwnerInert,
      ) &&
      rollback.contains(
        CallV2DeveloperRtcPermissionApprovalRollback.noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2DeveloperRtcPermissionApprovalRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2DeveloperRtcPermissionApprovalRollback.v1Unaffected,
      );

  bool get isStrictlyClosed =>
      hasHumanApproval &&
      isRtcPermissionOwnerOnly &&
      isDeveloperOnly &&
      !isRolloutEnabled &&
      !constructsRuntime &&
      !startsRuntime &&
      !accessesBackendFirebase &&
      !wiresNavigation &&
      !registersLifecycleObserver &&
      !mutatesRouteRegistry &&
      !createsProviderMediaEngine &&
      !joinsRtcChannel &&
      !consumesRtcTokenChannel &&
      !requestsPermission &&
      !promptsMicrophoneCamera &&
      !enumeratesDevices &&
      !capturesMedia &&
      !startsCameraPreview &&
      !publishesAudioVideo &&
      !opensRtcCallbacksListenersSubscriptions &&
      !contactsProductionServices &&
      !wiresStartupMainRouter &&
      !changesPubspecPlatformConfig &&
      !changesRulesFunctionsConfig &&
      !isDeploymentApproved &&
      protectsV1 &&
      allowedFutureFilesAreRtcPermissionOwnerOnly &&
      forbidsOutOfScopeFutureFiles &&
      rollbackPreserved;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'evidenceCount': evidence.length,
      'allowedFutureFileCount': allowedFutureFiles.length,
      'forbiddenFutureFileCount': forbiddenFutureFiles.length,
      'rollbackCount': rollback.length,
      'gateDecision': evaluatedGate.decision.name,
      'humanApproved': hasHumanApproval,
      'ownerOnly': isRtcPermissionOwnerOnly,
      'developerOnly': isDeveloperOnly,
      'rolloutEnabled': isRolloutEnabled,
      'constructsRuntime': constructsRuntime,
      'startsRuntime': startsRuntime,
      'accessesBackend': accessesBackendFirebase,
      'wiresNavigation': wiresNavigation,
      'registersLifecycleObserver': registersLifecycleObserver,
      'mutatesRouteRegistry': mutatesRouteRegistry,
      'createsMediaEngine': createsProviderMediaEngine,
      'joinsMediaChannel': joinsRtcChannel,
      'usesCredentialMaterial': consumesRtcTokenChannel,
      'requestsPermission': requestsPermission,
      'promptsMicrophoneCamera': promptsMicrophoneCamera,
      'enumeratesDevices': enumeratesDevices,
      'capturesMedia': capturesMedia,
      'startsCameraPreview': startsCameraPreview,
      'publishesAudioVideo': publishesAudioVideo,
      'opensProviderCallbacks': opensRtcCallbacksListenersSubscriptions,
      'contactsProductionServices': contactsProductionServices,
      'wiresStartupMainRouter': wiresStartupMainRouter,
      'changesPubspecPlatformConfig': changesPubspecPlatformConfig,
      'changesServerConfig': changesRulesFunctionsConfig,
      'deploymentApproved': isDeploymentApproved,
      'allowedFilesScoped': allowedFutureFilesAreRtcPermissionOwnerOnly,
      'forbiddenFilesScoped': forbidsOutOfScopeFutureFiles,
      'rollbackPreserved': rollbackPreserved,
      'protectsV1': protectsV1,
      'strictlyClosed': isStrictlyClosed,
    };
  }

  @override
  String toString() {
    return 'CallV2DeveloperRtcPermissionApprovalScope'
        '(${toSafeDebugMap()})';
  }
}

final callV2DeveloperRtcPermissionApprovalScope =
    CallV2DeveloperRtcPermissionApprovalScope(
  preWiringGate: callV2DeveloperPreWiringSafetyGate,
  evidence: <CallV2DeveloperRtcPermissionApprovalEvidence>[
    CallV2DeveloperRtcPermissionApprovalEvidence.phase7YHumanApproved,
    CallV2DeveloperRtcPermissionApprovalEvidence.rtcPermissionOwnerOnly,
    CallV2DeveloperRtcPermissionApprovalEvidence.developerOnly,
    CallV2DeveloperRtcPermissionApprovalEvidence.rolloutFalse,
    CallV2DeveloperRtcPermissionApprovalEvidence.noRuntimeConstruction,
    CallV2DeveloperRtcPermissionApprovalEvidence.noRuntimeStartup,
    CallV2DeveloperRtcPermissionApprovalEvidence.noBackendFirebase,
    CallV2DeveloperRtcPermissionApprovalEvidence.noNavigation,
    CallV2DeveloperRtcPermissionApprovalEvidence.noLifecycleRegistration,
    CallV2DeveloperRtcPermissionApprovalEvidence.noRouteRegistryMutation,
    CallV2DeveloperRtcPermissionApprovalEvidence.noMediaEngine,
    CallV2DeveloperRtcPermissionApprovalEvidence.noRtcChannelJoin,
    CallV2DeveloperRtcPermissionApprovalEvidence.noRtcTokenChannelConsumption,
    CallV2DeveloperRtcPermissionApprovalEvidence.noPermissionRequest,
    CallV2DeveloperRtcPermissionApprovalEvidence.noMicrophoneCameraPrompt,
    CallV2DeveloperRtcPermissionApprovalEvidence.noDeviceEnumeration,
    CallV2DeveloperRtcPermissionApprovalEvidence.noMediaCapture,
    CallV2DeveloperRtcPermissionApprovalEvidence.noCameraPreview,
    CallV2DeveloperRtcPermissionApprovalEvidence.noAudioVideoPublish,
    CallV2DeveloperRtcPermissionApprovalEvidence
        .noRtcCallbacksListenersSubscriptions,
    CallV2DeveloperRtcPermissionApprovalEvidence.noProductionServiceContact,
    CallV2DeveloperRtcPermissionApprovalEvidence.noStartupMainRouterWiring,
    CallV2DeveloperRtcPermissionApprovalEvidence.noPubspecPlatformConfig,
    CallV2DeveloperRtcPermissionApprovalEvidence.noRulesFunctionsConfig,
    CallV2DeveloperRtcPermissionApprovalEvidence.noDeployment,
    CallV2DeveloperRtcPermissionApprovalEvidence.v1Protected,
  ],
  allowedFutureFiles: <String>[
    'lib/call_v2/integration/call_v2_rtc_permission_owner.dart',
    'test/call_v2/integration/call_v2_rtc_permission_owner_test.dart',
  ],
  forbiddenFutureFiles: <String>[
    'lib/main.dart',
    'lib/navigation/app_router.dart',
    'lib/call_v2/startup/**',
    'lib/call_v2/runtime/**',
    'lib/call_v2/firebase/**',
    'lib/call_v2/integration/call_v2_route_registry.dart',
    'lib/call_v2/integration/call_v2_lifecycle_observer.dart',
    'lib/call_v2/integration/call_v2_navigator_owner.dart',
    'lib/call_v2/integration/call_v2_backend_firebase_owner.dart',
    'lib/call_v2/production/call_v2_production_composition.dart',
    'lib/call_v2/rtc/**',
    'lib/call_v2/permissions/**',
    'pubspec.yaml',
    'pubspec.lock',
    'android/**',
    'ios/**',
    'macos/**',
    'web/**',
    'firestore.rules',
    'firebase.json',
    'connect_functions/**',
  ],
  rollback: <CallV2DeveloperRtcPermissionApprovalRollback>[
    CallV2DeveloperRtcPermissionApprovalRollback.oneCommitRevert,
    CallV2DeveloperRtcPermissionApprovalRollback.keepRolloutFalse,
    CallV2DeveloperRtcPermissionApprovalRollback.keepRouteRegistryNull,
    CallV2DeveloperRtcPermissionApprovalRollback.keepDisabledOwnerInert,
    CallV2DeveloperRtcPermissionApprovalRollback.noDeploymentRequired,
    CallV2DeveloperRtcPermissionApprovalRollback.noConfigChanges,
    CallV2DeveloperRtcPermissionApprovalRollback.v1Unaffected,
  ],
);
