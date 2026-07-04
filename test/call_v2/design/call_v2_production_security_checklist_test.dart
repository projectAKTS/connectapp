import 'package:connect_app/call_v2/design/call_v2_production_security_checklist.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('security checklist covers every required item exactly once', () {
    final checklist = callV2ProductionSecurityChecklist;

    expect(
      checklist.entries.map((entry) => entry.item).toSet(),
      CallV2ProductionSecurityChecklistItem.values.toSet(),
    );
    for (final item in CallV2ProductionSecurityChecklistItem.values) {
      expect(
        checklist.entries.where((entry) => entry.item == item),
        hasLength(1),
      );
    }
  });

  test('no security checklist item is marked verified in design phase', () {
    for (final entry in callV2ProductionSecurityChecklist.entries) {
      expect(
        entry.status,
        isNot(CallV2ProductionSecurityChecklistStatus.required),
        reason: entry.item.name,
      );
      expect(
        <CallV2ProductionSecurityChecklistStatus>[
          CallV2ProductionSecurityChecklistStatus.notVerified,
          CallV2ProductionSecurityChecklistStatus.blocked,
        ],
        contains(entry.status),
      );
    }
  });

  test('checklist includes privacy, authorization, replay, and rollback items',
      () {
    expect(
      callV2ProductionSecurityChecklist.entries.map((entry) => entry.item),
      containsAll(<Object>[
        CallV2ProductionSecurityChecklistItem.leastPrivilegeFirestoreAccess,
        CallV2ProductionSecurityChecklistItem.callableAuthentication,
        CallV2ProductionSecurityChecklistItem.appCheckEnforcement,
        CallV2ProductionSecurityChecklistItem.tokenTtl,
        CallV2ProductionSecurityChecklistItem.tokenAudienceChannelBinding,
        CallV2ProductionSecurityChecklistItem.uidOwnership,
        CallV2ProductionSecurityChecklistItem.participantAuthorization,
        CallV2ProductionSecurityChecklistItem.replayResistance,
        CallV2ProductionSecurityChecklistItem.noSecretsInAppBundle,
        CallV2ProductionSecurityChecklistItem.noIdentifiersInLogs,
        CallV2ProductionSecurityChecklistItem.noIdentifiersInRouteNames,
        CallV2ProductionSecurityChecklistItem.permissionMinimization,
        CallV2ProductionSecurityChecklistItem.backgroundPrivacy,
        CallV2ProductionSecurityChecklistItem
            .screenRecordingPolicyConsideration,
        CallV2ProductionSecurityChecklistItem.localCameraPreviewPrivacy,
        CallV2ProductionSecurityChecklistItem.dataRetention,
        CallV2ProductionSecurityChecklistItem.incidentResponse,
        CallV2ProductionSecurityChecklistItem.rollback,
      ]),
    );
  });

  test('checklist debug output is structured and contains no dynamic evidence',
      () {
    final text = callV2ProductionSecurityChecklist.toString();

    for (final forbidden in <String>[
      'verified',
      'ticket',
      'timestamp',
      '202',
      'uid_',
      'Bearer ',
      'raw',
      'stack',
    ]) {
      expect(text.contains(forbidden), isFalse, reason: forbidden);
    }
  });
}
