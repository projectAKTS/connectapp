import 'dart:io';

import 'package:connect_app/call_v2/production/call_v2_production_integration_approval.dart';
import 'package:connect_app/call_v2/production/call_v2_production_integration_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('approval model', () {
    test('defaults every approval input to false', () {
      const approval = CallV2ProductionIntegrationApproval();

      expect(approval.toSafeDebugMap().values, everyElement(false));
      expect(approval.approvalsComplete, isFalse);
    });

    test('fully approved simulation sets every approval input to true', () {
      const approval = CallV2ProductionIntegrationApproval.fullyApproved();

      expect(approval.toSafeDebugMap().values, everyElement(true));
      expect(approval.approvalsComplete, isTrue);
    });

    test('approval inputs are immutable boolean declarations only', () {
      final source = _read(
        'lib/call_v2/production/'
        'call_v2_production_integration_approval.dart',
      );

      expect(source.contains('final bool '), isTrue);
      for (final forbidden in <String>[
        'final String',
        'String?',
        'DateTime',
        'Uri',
        'Object?',
        'dynamic',
        'metadata',
        'ticket',
        'email',
        'token',
        'secret',
        'signature',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('safe debug representation contains no identities or secrets', () {
      const approval = CallV2ProductionIntegrationApproval.fullyApproved();
      final text = approval.toString();

      for (final forbidden in <String>[
        '@',
        'uid',
        'user',
        'http://',
        'https://',
        'secret',
        'token',
        'credential',
      ]) {
        expect(text.toLowerCase().contains(forbidden), isFalse);
      }
    });
  });

  group('integration plan snapshot', () {
    test('mutating source list after construction does not alter snapshot', () {
      final sourceItems = <CallV2ProductionIntegrationPlanItem>[
        const CallV2ProductionIntegrationPlanItem(
          step:
              CallV2ProductionIntegrationPlanStep.addProductionDependencyOwner,
          status: CallV2ProductionIntegrationPlanStepStatus.notStarted,
        ),
      ];
      final snapshot = CallV2ProductionIntegrationPlanSnapshot(
        items: sourceItems,
      );

      sourceItems.add(
        const CallV2ProductionIntegrationPlanItem(
          step: CallV2ProductionIntegrationPlanStep.deployBackend,
          status: CallV2ProductionIntegrationPlanStepStatus.blocked,
        ),
      );

      expect(snapshot.items, hasLength(1));
      expect(
        snapshot.statusFor(
          CallV2ProductionIntegrationPlanStep.addProductionDependencyOwner,
        ),
        CallV2ProductionIntegrationPlanStepStatus.notStarted,
      );
    });

    test('direct mutation through snapshot items is rejected', () {
      expect(
        () => callV2ProductionIntegrationPlanSnapshot.items.add(
          const CallV2ProductionIntegrationPlanItem(
            step: CallV2ProductionIntegrationPlanStep.deployBackend,
            status: CallV2ProductionIntegrationPlanStepStatus.blocked,
          ),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => callV2ProductionIntegrationPlanSnapshot.items.remove(
          callV2ProductionIntegrationPlanSnapshot.items.first,
        ),
        throwsUnsupportedError,
      );
    });

    test('contains every typed future production step exactly once', () {
      expect(
        callV2ProductionIntegrationPlanSnapshot.items
            .map((item) => item.step)
            .toSet(),
        CallV2ProductionIntegrationPlanStep.values.toSet(),
      );
      expect(
        callV2ProductionIntegrationPlanSnapshot.items,
        hasLength(CallV2ProductionIntegrationPlanStep.values.length),
      );
    });

    test('all steps are blocked or not started and none can be completed', () {
      expect(
        CallV2ProductionIntegrationPlanStepStatus.values,
        unorderedEquals(<CallV2ProductionIntegrationPlanStepStatus>[
          CallV2ProductionIntegrationPlanStepStatus.blocked,
          CallV2ProductionIntegrationPlanStepStatus.notStarted,
        ]),
      );
      for (final item in callV2ProductionIntegrationPlanSnapshot.items) {
        expect(
          item.status,
          anyOf(
            CallV2ProductionIntegrationPlanStepStatus.blocked,
            CallV2ProductionIntegrationPlanStepStatus.notStarted,
          ),
        );
      }
    });

    test('critical integration steps are not started or blocked', () {
      expect(
        callV2ProductionIntegrationPlanSnapshot.statusFor(
          CallV2ProductionIntegrationPlanStep
              .constructProductionCompositionAfterHardGate,
        ),
        CallV2ProductionIntegrationPlanStepStatus.notStarted,
      );
      expect(
        callV2ProductionIntegrationPlanSnapshot.statusFor(
          CallV2ProductionIntegrationPlanStep.addProductionRouteSink,
        ),
        CallV2ProductionIntegrationPlanStepStatus.notStarted,
      );
      expect(
        callV2ProductionIntegrationPlanSnapshot.statusFor(
          CallV2ProductionIntegrationPlanStep.registerRealGuardedRoutes,
        ),
        CallV2ProductionIntegrationPlanStepStatus.notStarted,
      );
      expect(
        callV2ProductionIntegrationPlanSnapshot.statusFor(
          CallV2ProductionIntegrationPlanStep.addProductionCallScreens,
        ),
        CallV2ProductionIntegrationPlanStepStatus.notStarted,
      );
      expect(
        callV2ProductionIntegrationPlanSnapshot.statusFor(
          CallV2ProductionIntegrationPlanStep.deployBackend,
        ),
        CallV2ProductionIntegrationPlanStepStatus.blocked,
      );
      expect(
        callV2ProductionIntegrationPlanSnapshot.statusFor(
          CallV2ProductionIntegrationPlanStep.conductLimitedRollout,
        ),
        CallV2ProductionIntegrationPlanStepStatus.blocked,
      );
    });

    test('plan is typed, immutable, and has no executable callbacks', () {
      final source = _read(
        'lib/call_v2/production/call_v2_production_integration_plan.dart',
      );

      expect(
          source.contains('enum CallV2ProductionIntegrationPlanStep'), isTrue);
      expect(
          source.contains('List<CallV2ProductionIntegrationPlanItem>'), isTrue);
      expect(
          source.contains(
              'List<CallV2ProductionIntegrationPlanItem>.unmodifiable'),
          isTrue);
      for (final forbidden in <String>[
        'Function',
        'VoidCallback',
        'Future<',
        'async',
        'await',
        'completed',
        'Firebase',
        'Navigator.',
        'Navigator(',
        'deploy',
      ]) {
        if (forbidden == 'deploy') {
          expect(
            source.contains('void deploy') || source.contains('Future deploy'),
            isFalse,
          );
        } else {
          expect(source.contains(forbidden), isFalse, reason: forbidden);
        }
      }
    });
  });
}

String _read(String path) => File(path).readAsStringSync();
