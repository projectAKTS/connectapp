import 'dart:io';

import 'package:connect_app/call_v2/call_v2_runtime_configuration.dart';
import 'package:connect_app/call_v2/design/call_v2_production_lifecycle_design.dart';
import 'package:connect_app/call_v2/design/call_v2_production_route_design.dart';
import 'package:connect_app/call_v2/integration/call_v2_app_integration.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/production/call_v2_pre_integration_gate.dart';
import 'package:connect_app/call_v2/production/call_v2_production_composition.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('route and screen design covers all future destinations without widgets',
      () {
    final routeDesign = callV2ProductionRouteDesign;

    expect(
      routeDesign.routes.map((route) => route.destination).toSet(),
      CallV2ProductionRouteDestination.values.toSet(),
    );
    expect(
      routeDesign.screens.map((screen) => screen.destination).toSet(),
      CallV2ProductionRouteDestination.values.toSet(),
    );
    expect(
        routeDesign.routes.map((route) => route.name),
        everyElement(
          allOf(
            startsWith('/call-v2/'),
            isNot(contains('{')),
            isNot(contains(':')),
          ),
        ));
    for (final route in routeDesign.routes) {
      expect(
          route.argumentPolicies,
          containsAll(<Object>[
            CallV2ProductionRouteArgumentPolicy.typedSessionReferenceOnly,
            CallV2ProductionRouteArgumentPolicy.noArbitraryMap,
            CallV2ProductionRouteArgumentPolicy.noCredentialPayload,
            CallV2ProductionRouteArgumentPolicy.noIdentifierInRouteName,
          ]));
      expect(
          route.precedencePolicies,
          containsAll(<Object>[
            CallV2ProductionRoutePrecedencePolicy.existingAppRoutesFirst,
            CallV2ProductionRoutePrecedencePolicy.callV2RoutesBehindGates,
            CallV2ProductionRoutePrecedencePolicy.unknownRouteUnchanged,
            CallV2ProductionRoutePrecedencePolicy.v1RouteOwnershipUnchanged,
          ]));
    }
    expect(
        routeDesign.routeSinkPolicies,
        containsAll(<Object>[
          CallV2ProductionRouteSinkPolicy.injectedAppOwnedNavigationAccess,
          CallV2ProductionRouteSinkPolicy.noGlobalMutableSingleton,
          CallV2ProductionRouteSinkPolicy.removeOnlyOwnedCallRoutes,
          CallV2ProductionRouteSinkPolicy.preserveHostAndUnrelatedRoutes,
          CallV2ProductionRouteSinkPolicy.serializeNavigation,
          CallV2ProductionRouteSinkPolicy.disposalInvalidatesQueue,
          CallV2ProductionRouteSinkPolicy
              .missingNavigationAccessReturnsControlledError,
          CallV2ProductionRouteSinkPolicy
              .inactiveAppDefersNonCriticalNavigation,
          CallV2ProductionRouteSinkPolicy.noNotificationOrDeepLinkHandling,
        ]));
  });

  test('screen responsibilities exclude provider details and raw failures', () {
    final screens = {
      for (final screen in callV2ProductionRouteDesign.screens)
        screen.destination: screen,
    };

    expect(
      screens[CallV2ProductionRouteDestination.connecting]!.responsibilities,
      containsAll(<Object>[
        CallV2ProductionScreenResponsibility.genericConnectingState,
        CallV2ProductionScreenResponsibility.cancelAction,
      ]),
    );
    expect(
      screens[CallV2ProductionRouteDestination.activeAudio]!.responsibilities,
      containsAll(<Object>[
        CallV2ProductionScreenResponsibility.mute,
        CallV2ProductionScreenResponsibility.speaker,
        CallV2ProductionScreenResponsibility.leave,
        CallV2ProductionScreenResponsibility.sanitizedDuration,
        CallV2ProductionScreenResponsibility.connectionStatus,
      ]),
    );
    expect(
      screens[CallV2ProductionRouteDestination.activeVideo]!.responsibilities,
      containsAll(<Object>[
        CallV2ProductionScreenResponsibility.mute,
        CallV2ProductionScreenResponsibility.cameraToggle,
        CallV2ProductionScreenResponsibility.cameraSwitch,
        CallV2ProductionScreenResponsibility.leave,
        CallV2ProductionScreenResponsibility.localRenderingBoundary,
        CallV2ProductionScreenResponsibility.remoteRenderingBoundary,
        CallV2ProductionScreenResponsibility.lifecycleSafeRendering,
      ]),
    );
    expect(
      screens[CallV2ProductionRouteDestination.controlledFailure]!
          .responsibilities,
      containsAll(<Object>[
        CallV2ProductionScreenResponsibility.controlledErrorOnly,
        CallV2ProductionScreenResponsibility.retryOnlyWhenCoordinatorAllows,
      ]),
    );
    for (final screen in screens.values) {
      expect(
          screen.disallowedDetails,
          contains(
            CallV2ProductionScreenDisallowedDetail.rawIdentifier,
          ));
    }
  });

  test('permission auth App Check and observability policies are explicit', () {
    final lifecycle = callV2ProductionLifecycleDesign;

    expect(lifecycle.audioPermissionPolicy.requiresMicrophone, isTrue);
    expect(lifecycle.audioPermissionPolicy.requiresCamera, isFalse);
    expect(lifecycle.videoPermissionPolicy.requiresMicrophone, isTrue);
    expect(lifecycle.videoPermissionPolicy.requiresCamera, isTrue);
    expect(
        lifecycle.audioPermissionPolicy.timing,
        containsAll(<Object>[
          CallV2ProductionPermissionTiming.afterExplicitUserLaunch,
          CallV2ProductionPermissionTiming.neverDuringAppStartup,
          CallV2ProductionPermissionTiming.neverDuringComposition,
          CallV2ProductionPermissionTiming.neverWhenRolloutDisabled,
        ]));
    expect(lifecycle.videoPermissionPolicy.outcomes.toSet(),
        CallV2ProductionPermissionOutcome.values.toSet());
    expect(
        lifecycle.authAppCheckPolicies,
        containsAll(<Object>[
          CallV2ProductionAuthAppCheckPolicy
              .authenticatedIdentityRequiredBeforeLaunch,
          CallV2ProductionAuthAppCheckPolicy.localIdentityDerivedInternally,
          CallV2ProductionAuthAppCheckPolicy.remoteParticipantMustDiffer,
          CallV2ProductionAuthAppCheckPolicy.appCheckBeforeBackendCallable,
          CallV2ProductionAuthAppCheckPolicy.signOutTriggersCleanup,
          CallV2ProductionAuthAppCheckPolicy.noIdentityInRouteNames,
        ]));
    expect(lifecycle.observabilityEvents.toSet(),
        CallV2ProductionObservabilityEvent.values.toSet());
    expect(
        lifecycle.observabilityPolicies,
        containsAll(<Object>[
          CallV2ProductionObservabilityPolicy.noUid,
          CallV2ProductionObservabilityPolicy.noCallId,
          CallV2ProductionObservabilityPolicy.noParticipantId,
          CallV2ProductionObservabilityPolicy.noCredential,
          CallV2ProductionObservabilityPolicy.noChannel,
          CallV2ProductionObservabilityPolicy.noRawError,
          CallV2ProductionObservabilityPolicy.noStackTrace,
          CallV2ProductionObservabilityPolicy.noRouteArguments,
          CallV2ProductionObservabilityPolicy
              .sinkFailureNeverAffectsCallBehavior,
        ]));
  });

  test('kill switch closure policies cover every gate and phase', () {
    final policies = callV2ProductionLifecycleDesign.gateClosurePolicies;

    for (final gate in CallV2ProductionGate.values) {
      for (final phase in CallV2ProductionGateClosurePhase.values) {
        expect(
          policies
              .where((policy) => policy.gate == gate && policy.phase == phase),
          hasLength(1),
          reason: '${gate.name}/${phase.name}',
        );
      }
    }
  });

  test('existing runtime integration remains hard disabled and unreachable',
      () async {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(resolveCallV2Route(const RouteSettings(name: '/call-v2/connecting')),
        isNull);
    await initializeCallV2AppIntegrationShell();
    expect(
      callV2DefaultRuntimeConfiguration.enabled,
      isFalse,
    );
    expect(
      const CallV2PreIntegrationGate().evaluate().rolloutAuthorized,
      isFalse,
    );
  });

  test('design phase does not add real screens, route sink, or wiring files',
      () {
    final sourcePaths = Directory('lib/call_v2')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.path)
        .toList(growable: false);

    expect(
      sourcePaths.where((path) => path.contains('/design/')),
      isNotEmpty,
    );
    expect(
      sourcePaths.where((path) => path.contains('production_call_v2_screen')),
      isEmpty,
    );
    expect(
      sourcePaths
          .where((path) => path.contains('production_call_v2_route_sink')),
      isEmpty,
    );
    expect(
      File('lib/call_v2/integration/call_v2_rollout_policy.dart')
          .readAsStringSync(),
      contains('static const bool productionEnabled = false;'),
    );
    expect(
      File('lib/call_v2/integration/call_v2_route_registry.dart')
          .readAsStringSync(),
      contains('if (!CallV2RolloutPolicy.productionEnabled) return null;'),
    );
    expect(
      File('lib/main.dart').readAsStringSync(),
      contains('initializeCallV2AppIntegrationShellSafely()'),
    );
    expect(
      File('lib/main.dart').readAsStringSync(),
      isNot(contains('callV2ProductionIntegrationDesign')),
    );
    expect(
      File('lib/navigation/app_router.dart').readAsStringSync(),
      isNot(contains('callV2ProductionIntegrationDesign')),
    );
  });

  test('design files do not import production wiring dependencies', () {
    final sources = Directory('lib/call_v2/design')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    for (final forbidden in <String>[
      'package:flutter/',
      'cloud_firestore',
      'cloud_functions',
      'firebase_auth',
      'firebase_app_check',
      '../production/call_v2_production_composition.dart',
      '../startup/',
      '../ui/',
      '../rtc/production/',
      '../permissions/production/',
      '../firebase/',
      'MaterialPageRoute',
      'CupertinoPageRoute',
      'Widget ',
      'StatefulWidget',
      'StatelessWidget',
    ]) {
      expect(sources.contains(forbidden), isFalse, reason: forbidden);
    }
  });

  test('isolated production composition remains unchanged and not ready', () {
    expect(
        callV2IsolatedProductionCompositionCapabilities
            .runtimeStartupBridgeAvailable,
        isFalse);
    expect(
        callV2IsolatedProductionCompositionCapabilities
            .uiRouteIntegrationAvailable,
        isFalse);
    expect(
        callV2IsolatedProductionCompositionCapabilities.observabilityAvailable,
        isFalse);
  });
}
