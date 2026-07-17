import 'package:flutter/widgets.dart';

import '../ui/call_v2_production_route_destination.dart';
import 'call_v2_rollout_policy.dart';
import 'disabled_call_v2_route_registry.dart';

abstract interface class CallV2RouteRegistry {
  Route<dynamic>? resolve(RouteSettings settings);
}

class CallV2RouteNames {
  const CallV2RouteNames._();

  static const String connecting = CallV2ProductionRouteNames.connecting;
  static const String activeAudio = CallV2ProductionRouteNames.activeAudio;
  static const String activeVideo = CallV2ProductionRouteNames.activeVideo;
  static const String controlledFailure =
      CallV2ProductionRouteNames.controlledFailure;

  static const Set<String> production = <String>{
    connecting,
    activeAudio,
    activeVideo,
    controlledFailure,
  };

  @Deprecated('Legacy non-production harness route. Not a production route.')
  static const String ready = '/call-v2/ready';
}

const Set<String> callV2DeveloperCanonicalRouteNames =
    CallV2RouteNames.production;

enum CallV2RouteRegistryActivationStatus {
  developerOnly,
  rolloutFalse,
  resolverNullWhileFalse,
  routeNamesKnown,
  routeFactoryBlockedWhileFalse,
  routeSinkBlockedWhileFalse,
  noRouteObjectCreatedWhileFalse,
  noScreenCreatedWhileFalse,
  noRuntimeStart,
  noBackendAccess,
  noRtcPermissionAccess,
  noNavigationAccess,
  noLifecycleRegistration,
  noAsyncHandles,
  noDependencyPlatformConfigChanges,
  noDeployment,
  v1Protected,
}

enum CallV2RouteRegistryActivationDecision {
  pass,
  blocked,
}

final class CallV2RouteRegistryActivation {
  const CallV2RouteRegistryActivation({
    required this.statuses,
    required this.canonicalRouteCount,
    required this.excludedRouteCount,
  });

  final Set<CallV2RouteRegistryActivationStatus> statuses;
  final int canonicalRouteCount;
  final int excludedRouteCount;

  CallV2RouteRegistryActivationDecision get decision {
    return passes
        ? CallV2RouteRegistryActivationDecision.pass
        : CallV2RouteRegistryActivationDecision.blocked;
  }

  bool get passes =>
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsResolverNullWhileFalse &&
      recordsRouteNamesKnown &&
      recordsRouteFactoryBlockedWhileFalse &&
      recordsRouteSinkBlockedWhileFalse &&
      recordsNoRouteObjectCreatedWhileFalse &&
      recordsNoScreenCreatedWhileFalse &&
      recordsNoRuntimeStart &&
      recordsNoBackendAccess &&
      recordsNoRtcPermissionAccess &&
      recordsNoNavigationAccess &&
      recordsNoLifecycleRegistration &&
      recordsNoAsyncHandles &&
      recordsNoDependencyPlatformConfigChanges &&
      recordsNoDeployment &&
      recordsV1Protected;

  bool get recordsDeveloperOnly =>
      statuses.contains(CallV2RouteRegistryActivationStatus.developerOnly);

  bool get recordsRolloutFalse =>
      statuses.contains(CallV2RouteRegistryActivationStatus.rolloutFalse) &&
      !CallV2RolloutPolicy.productionEnabled;

  bool get recordsResolverNullWhileFalse => statuses.contains(
        CallV2RouteRegistryActivationStatus.resolverNullWhileFalse,
      );

  bool get recordsRouteNamesKnown =>
      statuses.contains(CallV2RouteRegistryActivationStatus.routeNamesKnown) &&
      canonicalRouteCount == callV2DeveloperCanonicalRouteNames.length &&
      !isCallV2DeveloperCanonicalRouteName(CallV2RouteNames.ready);

  bool get recordsRouteFactoryBlockedWhileFalse => statuses.contains(
        CallV2RouteRegistryActivationStatus.routeFactoryBlockedWhileFalse,
      );

  bool get recordsRouteSinkBlockedWhileFalse => statuses.contains(
        CallV2RouteRegistryActivationStatus.routeSinkBlockedWhileFalse,
      );

  bool get recordsNoRouteObjectCreatedWhileFalse => statuses.contains(
        CallV2RouteRegistryActivationStatus.noRouteObjectCreatedWhileFalse,
      );

  bool get recordsNoScreenCreatedWhileFalse => statuses.contains(
        CallV2RouteRegistryActivationStatus.noScreenCreatedWhileFalse,
      );

  bool get recordsNoRuntimeStart =>
      statuses.contains(CallV2RouteRegistryActivationStatus.noRuntimeStart);

  bool get recordsNoBackendAccess =>
      statuses.contains(CallV2RouteRegistryActivationStatus.noBackendAccess);

  bool get recordsNoRtcPermissionAccess => statuses.contains(
        CallV2RouteRegistryActivationStatus.noRtcPermissionAccess,
      );

  bool get recordsNoNavigationAccess =>
      statuses.contains(CallV2RouteRegistryActivationStatus.noNavigationAccess);

  bool get recordsNoLifecycleRegistration => statuses.contains(
        CallV2RouteRegistryActivationStatus.noLifecycleRegistration,
      );

  bool get recordsNoAsyncHandles =>
      statuses.contains(CallV2RouteRegistryActivationStatus.noAsyncHandles);

  bool get recordsNoDependencyPlatformConfigChanges => statuses.contains(
        CallV2RouteRegistryActivationStatus.noDependencyPlatformConfigChanges,
      );

  bool get recordsNoDeployment =>
      statuses.contains(CallV2RouteRegistryActivationStatus.noDeployment);

  bool get recordsV1Protected =>
      statuses.contains(CallV2RouteRegistryActivationStatus.v1Protected);

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'canonicalRouteCount': canonicalRouteCount,
      'excludedRouteCount': excludedRouteCount,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'resolverNullWhileFalse': recordsResolverNullWhileFalse,
      'routeNamesKnown': recordsRouteNamesKnown,
      'routesReachable': false,
      'routeObjectsCreated': false,
      'screensCreated': false,
      'runtimeStarted': false,
      'deploymentChanged': false,
      'v1Protected': recordsV1Protected,
    };
  }

  @override
  String toString() {
    return 'CallV2RouteRegistryActivation(${toSafeDebugMap()})';
  }
}

const callV2RouteRegistryActivation = CallV2RouteRegistryActivation(
  statuses: <CallV2RouteRegistryActivationStatus>{
    CallV2RouteRegistryActivationStatus.developerOnly,
    CallV2RouteRegistryActivationStatus.rolloutFalse,
    CallV2RouteRegistryActivationStatus.resolverNullWhileFalse,
    CallV2RouteRegistryActivationStatus.routeNamesKnown,
    CallV2RouteRegistryActivationStatus.routeFactoryBlockedWhileFalse,
    CallV2RouteRegistryActivationStatus.routeSinkBlockedWhileFalse,
    CallV2RouteRegistryActivationStatus.noRouteObjectCreatedWhileFalse,
    CallV2RouteRegistryActivationStatus.noScreenCreatedWhileFalse,
    CallV2RouteRegistryActivationStatus.noRuntimeStart,
    CallV2RouteRegistryActivationStatus.noBackendAccess,
    CallV2RouteRegistryActivationStatus.noRtcPermissionAccess,
    CallV2RouteRegistryActivationStatus.noNavigationAccess,
    CallV2RouteRegistryActivationStatus.noLifecycleRegistration,
    CallV2RouteRegistryActivationStatus.noAsyncHandles,
    CallV2RouteRegistryActivationStatus.noDependencyPlatformConfigChanges,
    CallV2RouteRegistryActivationStatus.noDeployment,
    CallV2RouteRegistryActivationStatus.v1Protected,
  },
  canonicalRouteCount: 4,
  excludedRouteCount: 1,
);

bool get isCallV2DeveloperRouteRegistrationEnabled =>
    CallV2RolloutPolicy.productionEnabled;

bool isCallV2DeveloperCanonicalRouteName(String? name) {
  return callV2DeveloperCanonicalRouteNames.contains(name);
}

enum CallV2DeveloperRouteRegistryDecisionKind {
  rolloutDisabled,
  canonicalRoutePrepared,
  excludedCallV2Route,
  nonCallV2Route,
}

final class CallV2DeveloperRouteRegistryDecision {
  const CallV2DeveloperRouteRegistryDecision({
    required this.kind,
    required this.rolloutEnabled,
    required this.canonicalRoute,
    required this.callV2Route,
  });

  final CallV2DeveloperRouteRegistryDecisionKind kind;
  final bool rolloutEnabled;
  final bool canonicalRoute;
  final bool callV2Route;

  bool get routeMayResolve =>
      rolloutEnabled &&
      kind == CallV2DeveloperRouteRegistryDecisionKind.canonicalRoutePrepared;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'kind': kind.name,
      'rolloutEnabled': rolloutEnabled,
      'canonicalRoute': canonicalRoute,
      'callV2Route': callV2Route,
      'canonicalRouteCount': callV2DeveloperCanonicalRouteNames.length,
      'routeMayResolve': routeMayResolve,
    };
  }

  @override
  String toString() {
    return 'CallV2DeveloperRouteRegistryDecision(${toSafeDebugMap()})';
  }
}

CallV2DeveloperRouteRegistryDecision describeCallV2RouteRegistryDecision(
  RouteSettings settings,
) {
  if (!isCallV2DeveloperRouteRegistrationEnabled) {
    return const CallV2DeveloperRouteRegistryDecision(
      kind: CallV2DeveloperRouteRegistryDecisionKind.rolloutDisabled,
      rolloutEnabled: false,
      canonicalRoute: false,
      callV2Route: false,
    );
  }

  final routeName = settings.name;
  final isCanonicalRoute = isCallV2DeveloperCanonicalRouteName(routeName);
  final isCallV2Route = routeName?.startsWith('/call-v2/') ?? false;

  return CallV2DeveloperRouteRegistryDecision(
    kind: isCanonicalRoute
        ? CallV2DeveloperRouteRegistryDecisionKind.canonicalRoutePrepared
        : isCallV2Route
            ? CallV2DeveloperRouteRegistryDecisionKind.excludedCallV2Route
            : CallV2DeveloperRouteRegistryDecisionKind.nonCallV2Route,
    rolloutEnabled: true,
    canonicalRoute: isCanonicalRoute,
    callV2Route: isCallV2Route,
  );
}

Route<dynamic>? resolveCallV2Route(RouteSettings settings) {
  if (!CallV2RolloutPolicy.productionEnabled) return null;

  final decision = describeCallV2RouteRegistryDecision(settings);
  if (!decision.routeMayResolve) return null;

  return const DisabledCallV2RouteRegistry().resolve(settings);
}
