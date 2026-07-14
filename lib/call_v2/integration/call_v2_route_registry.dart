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
