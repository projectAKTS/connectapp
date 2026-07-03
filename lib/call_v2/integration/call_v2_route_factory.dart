import 'package:flutter/widgets.dart';

import '../call_v2_api.dart';
import 'call_v2_route_registry.dart';

abstract interface class CallV2RouteFactory {
  Route<dynamic> create(CallV2RouteDestination destination);
}

sealed class CallV2RouteDestination {
  const CallV2RouteDestination();

  const factory CallV2RouteDestination.connecting() =
      CallV2ConnectingRouteDestination;

  const factory CallV2RouteDestination.ready() = CallV2ReadyRouteDestination;

  const factory CallV2RouteDestination.controlledFailure({
    required CallV2ClientErrorCode errorCode,
  }) = CallV2ControlledFailureRouteDestination;
}

final class CallV2ConnectingRouteDestination extends CallV2RouteDestination {
  const CallV2ConnectingRouteDestination();

  @override
  String toString() => 'CallV2RouteDestination.connecting()';
}

final class CallV2ReadyRouteDestination extends CallV2RouteDestination {
  const CallV2ReadyRouteDestination();

  @override
  String toString() => 'CallV2RouteDestination.ready()';
}

final class CallV2ControlledFailureRouteDestination
    extends CallV2RouteDestination {
  const CallV2ControlledFailureRouteDestination({required this.errorCode});

  final CallV2ClientErrorCode errorCode;

  @override
  String toString() {
    return 'CallV2RouteDestination.controlledFailure(errorCode: $errorCode)';
  }
}

class CallV2RouteFactoryNames {
  const CallV2RouteFactoryNames._();

  static const String connecting = CallV2RouteNames.connecting;
  static const String ready = CallV2RouteNames.ready;
  static const String controlledFailure = '/call-v2/unavailable';
}
