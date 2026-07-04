enum CallV2ProductionSecurityChecklistItem {
  leastPrivilegeFirestoreAccess,
  callableAuthentication,
  appCheckEnforcement,
  tokenTtl,
  tokenAudienceChannelBinding,
  uidOwnership,
  participantAuthorization,
  replayResistance,
  noSecretsInAppBundle,
  noIdentifiersInLogs,
  noIdentifiersInRouteNames,
  permissionMinimization,
  backgroundPrivacy,
  screenRecordingPolicyConsideration,
  localCameraPreviewPrivacy,
  dataRetention,
  incidentResponse,
  rollback,
}

enum CallV2ProductionSecurityChecklistStatus {
  required,
  notVerified,
  blocked,
}

class CallV2ProductionSecurityChecklistEntry {
  const CallV2ProductionSecurityChecklistEntry({
    required this.item,
    required this.status,
  });

  final CallV2ProductionSecurityChecklistItem item;
  final CallV2ProductionSecurityChecklistStatus status;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'item': item.name,
      'status': status.name,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionSecurityChecklistEntry(${toSafeDebugMap()})';
  }
}

class CallV2ProductionSecurityChecklist {
  factory CallV2ProductionSecurityChecklist({
    required List<CallV2ProductionSecurityChecklistEntry> entries,
  }) {
    return CallV2ProductionSecurityChecklist._(
      List<CallV2ProductionSecurityChecklistEntry>.unmodifiable(entries),
    );
  }

  const CallV2ProductionSecurityChecklist._(this.entries);

  final List<CallV2ProductionSecurityChecklistEntry> entries;

  CallV2ProductionSecurityChecklistEntry entryFor(
    CallV2ProductionSecurityChecklistItem item,
  ) {
    return entries.singleWhere((entry) => entry.item == item);
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'entries': entries.map((entry) => entry.toSafeDebugMap()).toList(),
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionSecurityChecklist(${toSafeDebugMap()})';
  }
}

const callV2ProductionSecurityChecklistEntries =
    <CallV2ProductionSecurityChecklistEntry>[
  CallV2ProductionSecurityChecklistEntry(
    item: CallV2ProductionSecurityChecklistItem.leastPrivilegeFirestoreAccess,
    status: CallV2ProductionSecurityChecklistStatus.notVerified,
  ),
  CallV2ProductionSecurityChecklistEntry(
    item: CallV2ProductionSecurityChecklistItem.callableAuthentication,
    status: CallV2ProductionSecurityChecklistStatus.notVerified,
  ),
  CallV2ProductionSecurityChecklistEntry(
    item: CallV2ProductionSecurityChecklistItem.appCheckEnforcement,
    status: CallV2ProductionSecurityChecklistStatus.notVerified,
  ),
  CallV2ProductionSecurityChecklistEntry(
    item: CallV2ProductionSecurityChecklistItem.tokenTtl,
    status: CallV2ProductionSecurityChecklistStatus.notVerified,
  ),
  CallV2ProductionSecurityChecklistEntry(
    item: CallV2ProductionSecurityChecklistItem.tokenAudienceChannelBinding,
    status: CallV2ProductionSecurityChecklistStatus.notVerified,
  ),
  CallV2ProductionSecurityChecklistEntry(
    item: CallV2ProductionSecurityChecklistItem.uidOwnership,
    status: CallV2ProductionSecurityChecklistStatus.notVerified,
  ),
  CallV2ProductionSecurityChecklistEntry(
    item: CallV2ProductionSecurityChecklistItem.participantAuthorization,
    status: CallV2ProductionSecurityChecklistStatus.notVerified,
  ),
  CallV2ProductionSecurityChecklistEntry(
    item: CallV2ProductionSecurityChecklistItem.replayResistance,
    status: CallV2ProductionSecurityChecklistStatus.notVerified,
  ),
  CallV2ProductionSecurityChecklistEntry(
    item: CallV2ProductionSecurityChecklistItem.noSecretsInAppBundle,
    status: CallV2ProductionSecurityChecklistStatus.notVerified,
  ),
  CallV2ProductionSecurityChecklistEntry(
    item: CallV2ProductionSecurityChecklistItem.noIdentifiersInLogs,
    status: CallV2ProductionSecurityChecklistStatus.notVerified,
  ),
  CallV2ProductionSecurityChecklistEntry(
    item: CallV2ProductionSecurityChecklistItem.noIdentifiersInRouteNames,
    status: CallV2ProductionSecurityChecklistStatus.notVerified,
  ),
  CallV2ProductionSecurityChecklistEntry(
    item: CallV2ProductionSecurityChecklistItem.permissionMinimization,
    status: CallV2ProductionSecurityChecklistStatus.notVerified,
  ),
  CallV2ProductionSecurityChecklistEntry(
    item: CallV2ProductionSecurityChecklistItem.backgroundPrivacy,
    status: CallV2ProductionSecurityChecklistStatus.notVerified,
  ),
  CallV2ProductionSecurityChecklistEntry(
    item: CallV2ProductionSecurityChecklistItem
        .screenRecordingPolicyConsideration,
    status: CallV2ProductionSecurityChecklistStatus.blocked,
  ),
  CallV2ProductionSecurityChecklistEntry(
    item: CallV2ProductionSecurityChecklistItem.localCameraPreviewPrivacy,
    status: CallV2ProductionSecurityChecklistStatus.notVerified,
  ),
  CallV2ProductionSecurityChecklistEntry(
    item: CallV2ProductionSecurityChecklistItem.dataRetention,
    status: CallV2ProductionSecurityChecklistStatus.notVerified,
  ),
  CallV2ProductionSecurityChecklistEntry(
    item: CallV2ProductionSecurityChecklistItem.incidentResponse,
    status: CallV2ProductionSecurityChecklistStatus.notVerified,
  ),
  CallV2ProductionSecurityChecklistEntry(
    item: CallV2ProductionSecurityChecklistItem.rollback,
    status: CallV2ProductionSecurityChecklistStatus.notVerified,
  ),
];

final callV2ProductionSecurityChecklist = CallV2ProductionSecurityChecklist(
  entries: callV2ProductionSecurityChecklistEntries,
);
