import 'package:flutter/material.dart';

import '../ui/call_v2_production_presentation_snapshot.dart';
import '../ui/call_v2_production_route_descriptor.dart';
import '../ui/call_v2_production_route_destination.dart';
import '../ui/call_v2_production_user_action.dart';
import '../ui/call_v2_production_view_model_mapper.dart';
import '../ui/shells/call_v2_production_shell_factory.dart';
import '../ui/shells/call_v2_production_shell_factory_result.dart';
import 'call_v2_production_route_object_factory_result.dart';

class CallV2ProductionRouteObjectFactory {
  const CallV2ProductionRouteObjectFactory({
    CallV2ProductionScreenFactory screenFactory =
        const CallV2ProductionScreenFactory(),
  }) : _screenFactory = screenFactory;

  final CallV2ProductionScreenFactory _screenFactory;

  CallV2ProductionRouteObjectFactoryResult<dynamic> createRoute({
    required CallV2ProductionRouteDescriptor descriptor,
    required CallV2ProductionViewModel viewModel,
    ValueChanged<CallV2ProductionUserAction>? onAction,
    int minimumGeneration = 0,
  }) {
    final generation = descriptor.generation;
    if (generation < 0 || minimumGeneration < 0) {
      return _rejected(
        CallV2ProductionRouteObjectFactoryError.invalidInput,
        descriptor,
      );
    }
    if (generation < minimumGeneration) {
      return _rejected(
        CallV2ProductionRouteObjectFactoryError.staleGeneration,
        descriptor,
      );
    }
    if (descriptor.terminalStatus ==
        CallV2ProductionPresentationTerminalStatus.terminalDisposed) {
      return const CallV2ProductionRouteObjectFactoryResult.noRoute();
    }

    final destination = descriptor.destination;
    if (!destination.isAvailable ||
        destination ==
            CallV2ProductionRouteDestination.incomingReviewReserved) {
      return _rejected(
        CallV2ProductionRouteObjectFactoryError.reservedDestination,
        descriptor,
      );
    }

    final expectedRouteName = _expectedRouteName(destination);
    if (expectedRouteName == null ||
        descriptor.routeName != expectedRouteName) {
      return _rejected(
        CallV2ProductionRouteObjectFactoryError.routeNameMismatch,
        descriptor,
      );
    }

    final screenResult = _screenFactory.createScreen(
      descriptor: descriptor,
      viewModel: viewModel,
      onAction: onAction,
      minimumGeneration: minimumGeneration,
    );
    return switch (screenResult) {
      CallV2ProductionScreenFactoryRendered<Widget>(:final value) =>
        CallV2ProductionRouteObjectFactoryResult.route(
          MaterialPageRoute<dynamic>(
            settings: RouteSettings(name: expectedRouteName),
            builder: (_) => value,
          ),
        ),
      CallV2ProductionScreenFactoryNoScreen<Widget>() =>
        const CallV2ProductionRouteObjectFactoryResult.noRoute(),
      CallV2ProductionScreenFactoryRejected<Widget>(:final error) =>
        _rejected(_mapScreenError(error), descriptor),
    };
  }

  String? _expectedRouteName(CallV2ProductionRouteDestination destination) {
    try {
      return CallV2ProductionRouteNames.forDestination(destination);
    } on ArgumentError {
      return null;
    }
  }

  CallV2ProductionRouteObjectFactoryError _mapScreenError(
    CallV2ProductionScreenFactoryError error,
  ) {
    return switch (error) {
      CallV2ProductionScreenFactoryError.invalidInput =>
        CallV2ProductionRouteObjectFactoryError.invalidInput,
      CallV2ProductionScreenFactoryError.staleGeneration =>
        CallV2ProductionRouteObjectFactoryError.staleGeneration,
      CallV2ProductionScreenFactoryError.routeNameMismatch =>
        CallV2ProductionRouteObjectFactoryError.routeNameMismatch,
      CallV2ProductionScreenFactoryError.reservedDestination =>
        CallV2ProductionRouteObjectFactoryError.reservedDestination,
      CallV2ProductionScreenFactoryError.destinationViewModelMismatch =>
        CallV2ProductionRouteObjectFactoryError.destinationViewModelMismatch,
      CallV2ProductionScreenFactoryError.terminalDescriptor =>
        CallV2ProductionRouteObjectFactoryError.terminalDescriptor,
      CallV2ProductionScreenFactoryError.unsupportedDestination =>
        CallV2ProductionRouteObjectFactoryError.unsupportedDestination,
    };
  }

  CallV2ProductionRouteObjectFactoryRejected<dynamic> _rejected(
    CallV2ProductionRouteObjectFactoryError error,
    CallV2ProductionRouteDescriptor descriptor,
  ) {
    return CallV2ProductionRouteObjectFactoryRejected<dynamic>(
      error,
      destination: descriptor.destination.name,
      generation: descriptor.generation,
    );
  }
}
