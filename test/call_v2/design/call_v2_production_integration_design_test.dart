import 'dart:io';

import 'package:connect_app/call_v2/design/call_v2_production_dependency_ownership_plan.dart';
import 'package:connect_app/call_v2/design/call_v2_production_integration_design.dart';
import 'package:connect_app/call_v2/design/call_v2_production_lifecycle_design.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('design models are immutable, data-only, and safe to inspect', () {
    final design = callV2ProductionIntegrationDesign;

    expect(
      () => design.designModePolicies.add(
        CallV2ProductionDesignModePolicy.noCallbacks,
      ),
      throwsUnsupportedError,
    );
    expect(
      () => design.compositionSequence.add(
        CallV2ProductionCompositionStep.checkRolloutPolicy,
      ),
      throwsUnsupportedError,
    );
    expect(
      () => design.dependencyOwnership.items.add(
        callV2ProductionDependencyOwnershipItems.first,
      ),
      throwsUnsupportedError,
    );
    expect(
        design.designModePolicies,
        containsAll(<Object>[
          CallV2ProductionDesignModePolicy.dataOnly,
          CallV2ProductionDesignModePolicy.advisoryOnly,
          CallV2ProductionDesignModePolicy.immutableModels,
          CallV2ProductionDesignModePolicy.noCallbacks,
          CallV2ProductionDesignModePolicy.noServiceInstances,
        ]));
    _expectSafeDebug(design.toString());
  });

  test('design source contains no executable production integration surface',
      () {
    final sources = _designSources().join('\n');

    for (final forbidden in <String>[
      'VoidCallback',
      'Function()',
      'Future<void> Function',
      'BuildContext',
      'NavigatorState',
      'FirebaseFirestore',
      'FirebaseAuth',
      'FirebaseFunctions',
      'FirebaseAppCheck',
      'CallV2RtcEngineTransport',
      'ProductionCallV2RtcAdapter(',
      'GlobalKey',
      'runApp',
      'initializeApp',
      'httpsCallable',
      'Permission.',
      'Map<String, dynamic>',
    ]) {
      expect(sources.contains(forbidden), isFalse, reason: forbidden);
    }
  });

  test('composition sequence is deterministic and does not start runtime early',
      () {
    expect(
        callV2ProductionIntegrationDesign.compositionSequence,
        <CallV2ProductionCompositionStep>[
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
        ]);
    expect(
      callV2ProductionIntegrationDesign.compositionInvariants,
      containsAll(<Object>[
        CallV2ProductionCompositionInvariant
            .appStartupDoesNotAutomaticallyStartCall,
        CallV2ProductionCompositionInvariant
            .compositionConstructionDoesNotInitializeRtc,
        CallV2ProductionCompositionInvariant
            .permissionsNotRequestedDuringComposition,
        CallV2ProductionCompositionInvariant.noRouteBeforeAuthenticatedLaunch,
        CallV2ProductionCompositionInvariant
            .noRuntimeStartBeforeGuardedUserAction,
      ]),
    );
  });

  test('ownership plan covers every required dependency once without cycles',
      () {
    final plan = callV2ProductionDependencyOwnershipPlan;

    expect(
      plan.items.map((item) => item.dependency).toSet(),
      CallV2ProductionDependency.values.toSet(),
    );
    for (final dependency in CallV2ProductionDependency.values) {
      expect(
        plan.items.where((item) => item.dependency == dependency),
        hasLength(1),
      );
    }
    expect(plan.hasCircularOwnership, isFalse);
    expect(plan.constructionOrder.toSet(),
        CallV2ProductionDependency.values.toSet());
    expect(
        plan.disposalOrder.toSet(), CallV2ProductionDependency.values.toSet());
    expect(
      plan.ownershipFor(CallV2ProductionDependency.runtime).startPoint,
      CallV2ProductionLifecyclePoint.afterAuthenticatedLaunch,
    );
    expect(
      plan.ownershipFor(CallV2ProductionDependency.rtcAdapter).startPoint,
      CallV2ProductionLifecyclePoint.afterAuthenticatedLaunch,
    );
    expect(
      plan.items.where(
        (item) =>
            item.ownershipTransfer ==
            CallV2ProductionOwnershipTransferPolicy.forbidden,
      ),
      isNotEmpty,
    );
  });

  test('runtime lifecycle states and policies are explicit', () {
    final lifecycle = callV2ProductionIntegrationDesign.lifecycleDesign;

    expect(
      CallV2ProductionRuntimeLifecycleState.values.toSet(),
      containsAll(<Object>[
        CallV2ProductionRuntimeLifecycleState.unavailable,
        CallV2ProductionRuntimeLifecycleState.idle,
        CallV2ProductionRuntimeLifecycleState.preparing,
        CallV2ProductionRuntimeLifecycleState.connecting,
        CallV2ProductionRuntimeLifecycleState.ready,
        CallV2ProductionRuntimeLifecycleState.reconnecting,
        CallV2ProductionRuntimeLifecycleState.ending,
        CallV2ProductionRuntimeLifecycleState.ended,
        CallV2ProductionRuntimeLifecycleState.failed,
        CallV2ProductionRuntimeLifecycleState.disposed,
      ]),
    );
    expect(lifecycle.transitions.where((transition) => transition.allowed),
        isNotEmpty);
    expect(lifecycle.transitions.where((transition) => !transition.allowed),
        isNotEmpty);
    expect(
        lifecycle.runtimePolicies,
        containsAll(<Object>[
          CallV2ProductionRuntimePolicy.noAutomaticLaunchOnAppStartup,
          CallV2ProductionRuntimePolicy.duplicateSameLaunchSharesInFlightWork,
          CallV2ProductionRuntimePolicy.conflictingLaunchRejected,
          CallV2ProductionRuntimePolicy.backgroundDoesNotLaunchNewCall,
          CallV2ProductionRuntimePolicy.authSignOutStopsRuntimeAndClearsSession,
          CallV2ProductionRuntimePolicy.networkLossMovesToReconnecting,
          CallV2ProductionRuntimePolicy.tokenRefreshUsesCredentialProviderOnly,
          CallV2ProductionRuntimePolicy.remoteLeaveEndsOwnedSession,
          CallV2ProductionRuntimePolicy
              .disposeOrderIsLifecycleRouteCoordinatorBridgeRuntimeRtc,
        ]));
    expect(
      lifecycle.appLifecyclePolicies.map((policy) => policy.state).toSet(),
      CallV2ProductionAppLifecycleState.values.toSet(),
    );
  });

  test('explicit non-goals keep Phase 6A design-only', () {
    expect(callV2ProductionIntegrationDesign.nonGoals.toSet(),
        CallV2ProductionIntegrationNonGoal.values.toSet());
    expect(
        callV2ProductionIntegrationDesign.nonGoals,
        containsAll(<Object>[
          CallV2ProductionIntegrationNonGoal.realAppStartupWiring,
          CallV2ProductionIntegrationNonGoal.realRouteRegistration,
          CallV2ProductionIntegrationNonGoal.productionScreens,
          CallV2ProductionIntegrationNonGoal.productionNavigationSink,
          CallV2ProductionIntegrationNonGoal.runtimeStartup,
          CallV2ProductionIntegrationNonGoal.firebaseCalls,
          CallV2ProductionIntegrationNonGoal.permissions,
          CallV2ProductionIntegrationNonGoal.rtcInitialization,
          CallV2ProductionIntegrationNonGoal.backendDeployment,
          CallV2ProductionIntegrationNonGoal.rolloutEnablement,
        ]));
  });
}

List<String> _designSources() {
  return Directory('lib/call_v2/design')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.readAsStringSync())
      .toList(growable: false);
}

void _expectSafeDebug(String text) {
  for (final forbidden in <String>[
    'uid_',
    'call_',
    'participant_',
    'token=',
    'channel=',
    'Bearer ',
    'stackTrace',
  ]) {
    expect(text.contains(forbidden), isFalse, reason: forbidden);
  }
}
