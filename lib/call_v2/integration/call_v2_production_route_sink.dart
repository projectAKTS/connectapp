import 'package:flutter/widgets.dart';

import '../ui/call_v2_production_presentation_snapshot.dart';
import '../ui/call_v2_production_route_descriptor.dart';
import '../ui/call_v2_production_route_destination.dart';
import '../ui/call_v2_production_user_action.dart';
import '../ui/call_v2_production_view_model_mapper.dart';
import 'call_v2_production_route_object_factory.dart';
import 'call_v2_production_route_object_factory_result.dart';
import 'call_v2_production_route_sink_adapter.dart';
import 'call_v2_production_route_sink_result.dart';
import 'call_v2_production_route_sink_state.dart';

class CallV2ProductionRouteSink {
  CallV2ProductionRouteSink({
    required CallV2ProductionRouteSinkAdapter adapter,
    CallV2ProductionRouteObjectFactory routeFactory =
        const CallV2ProductionRouteObjectFactory(),
  })  : _adapter = adapter,
        _routeFactory = routeFactory;

  final CallV2ProductionRouteSinkAdapter _adapter;
  final CallV2ProductionRouteObjectFactory _routeFactory;

  CallV2ProductionRouteSinkState _state =
      const CallV2ProductionRouteSinkState();
  int _operationGeneration = 0;

  CallV2ProductionRouteSinkState get state => _state;

  Future<CallV2ProductionRouteSinkResult> show({
    required CallV2ProductionRouteDescriptor descriptor,
    required CallV2ProductionViewModel viewModel,
    ValueChanged<CallV2ProductionUserAction>? onAction,
    int minimumGeneration = 0,
  }) async {
    final destination = descriptor.destination;
    final generation = descriptor.generation;
    final guard = _guard(
      destination: destination,
      generation: generation,
      minimumGeneration: minimumGeneration,
    );
    if (guard != null) return guard;

    if (descriptor.terminalStatus ==
        CallV2ProductionPresentationTerminalStatus.terminalDisposed) {
      return close();
    }
    if (!destination.isAvailable ||
        destination ==
            CallV2ProductionRouteDestination.incomingReviewReserved) {
      return CallV2ProductionRouteSinkResult.rejected(
        CallV2ProductionRouteSinkError.reservedDestination,
        destination: destination,
        generation: generation,
      );
    }

    final currentDestination = _state.currentDestination;
    final currentGeneration = _state.currentGeneration;
    if (currentDestination == destination && currentGeneration == generation) {
      return CallV2ProductionRouteSinkResult.noOp(
        destination: destination,
        generation: generation,
      );
    }
    if (!_canTransition(to: destination)) {
      return CallV2ProductionRouteSinkResult.rejected(
        CallV2ProductionRouteSinkError.invalidTransition,
        destination: destination,
        generation: generation,
      );
    }

    final routeResult = _routeFactory.createRoute(
      descriptor: descriptor,
      viewModel: viewModel,
      onAction: onAction,
      minimumGeneration: minimumGeneration,
    );
    return switch (routeResult) {
      CallV2ProductionRouteObjectFactoryRoute<dynamic>(:final value) =>
        _navigate(
          route: value,
          destination: destination,
          generation: generation,
          replace: currentDestination != null,
        ),
      CallV2ProductionRouteObjectFactoryNoRoute<dynamic>() => close(),
      CallV2ProductionRouteObjectFactoryRejected<dynamic>(:final error) =>
        CallV2ProductionRouteSinkResult.rejected(
          _mapFactoryError(error),
          destination: destination,
          generation: generation,
        ),
    };
  }

  Future<CallV2ProductionRouteSinkResult> close() async {
    final guard = _operationGuard();
    if (guard != null) return guard;
    if (_state.currentDestination == null) {
      return const CallV2ProductionRouteSinkResult.noOp();
    }

    final operation = _beginOperation();
    try {
      await _adapter.popCallV2Route();
    } catch (_) {
      _endOperation(operation);
      return const CallV2ProductionRouteSinkResult.rejected(
        CallV2ProductionRouteSinkError.adapterOperationFailed,
      );
    }
    if (!_canCompleteOperation(operation)) {
      _endOperation(operation);
      return const CallV2ProductionRouteSinkResult.rejected(
        CallV2ProductionRouteSinkError.disposed,
      );
    }
    _state = _state.copyWith(clearCurrent: true);
    _endOperation(operation);
    return const CallV2ProductionRouteSinkResult.popped();
  }

  CallV2ProductionRouteSinkResult dispose() {
    if (_state.disposed) {
      return const CallV2ProductionRouteSinkResult.noOp();
    }
    _operationGeneration += 1;
    _state = _state.copyWith(
      clearCurrent: true,
      disposed: true,
      navigationInProgress: false,
    );
    return const CallV2ProductionRouteSinkResult.noOp();
  }

  Future<CallV2ProductionRouteSinkResult> _navigate({
    required Route<dynamic> route,
    required CallV2ProductionRouteDestination destination,
    required int generation,
    required bool replace,
  }) async {
    final operation = _beginOperation();
    try {
      if (replace) {
        await _adapter.replace(route);
      } else {
        await _adapter.push(route);
      }
    } catch (_) {
      _endOperation(operation);
      return CallV2ProductionRouteSinkResult.rejected(
        CallV2ProductionRouteSinkError.adapterOperationFailed,
        destination: destination,
        generation: generation,
      );
    }
    if (!_canCompleteOperation(operation)) {
      _endOperation(operation);
      return CallV2ProductionRouteSinkResult.rejected(
        CallV2ProductionRouteSinkError.disposed,
        destination: destination,
        generation: generation,
      );
    }
    _state = _state.copyWith(
      currentDestination: destination,
      currentGeneration: generation,
    );
    _endOperation(operation);
    if (replace) {
      return CallV2ProductionRouteSinkResult.replaced(
        destination: destination,
        generation: generation,
      );
    }
    return CallV2ProductionRouteSinkResult.pushed(
      destination: destination,
      generation: generation,
    );
  }

  CallV2ProductionRouteSinkResult? _guard({
    required CallV2ProductionRouteDestination destination,
    required int generation,
    required int minimumGeneration,
  }) {
    final operationGuard = _operationGuard();
    if (operationGuard != null) return operationGuard;
    if (generation < 0 || minimumGeneration < 0) {
      return CallV2ProductionRouteSinkResult.rejected(
        CallV2ProductionRouteSinkError.invalidInput,
        destination: destination,
        generation: generation,
      );
    }
    final currentGeneration = _state.currentGeneration;
    if (generation < minimumGeneration ||
        (currentGeneration != null && generation < currentGeneration)) {
      return CallV2ProductionRouteSinkResult.rejected(
        CallV2ProductionRouteSinkError.staleGeneration,
        destination: destination,
        generation: generation,
      );
    }
    return null;
  }

  CallV2ProductionRouteSinkResult? _operationGuard() {
    if (_state.disposed) {
      return const CallV2ProductionRouteSinkResult.rejected(
        CallV2ProductionRouteSinkError.disposed,
      );
    }
    if (_adapter.isDisposed) {
      return const CallV2ProductionRouteSinkResult.rejected(
        CallV2ProductionRouteSinkError.adapterDisposed,
      );
    }
    if (_state.navigationInProgress) {
      return const CallV2ProductionRouteSinkResult.rejected(
        CallV2ProductionRouteSinkError.navigationInProgress,
      );
    }
    return null;
  }

  bool _canTransition({
    required CallV2ProductionRouteDestination to,
  }) {
    final from = _state.currentDestination;
    if (from == null) return true;
    if (from == to) return true;
    return switch (from) {
      CallV2ProductionRouteDestination.connecting =>
        to == CallV2ProductionRouteDestination.activeAudio ||
            to == CallV2ProductionRouteDestination.activeVideo ||
            to == CallV2ProductionRouteDestination.controlledFailure,
      CallV2ProductionRouteDestination.activeAudio =>
        to == CallV2ProductionRouteDestination.controlledFailure,
      CallV2ProductionRouteDestination.activeVideo =>
        to == CallV2ProductionRouteDestination.controlledFailure,
      CallV2ProductionRouteDestination.controlledFailure => false,
      CallV2ProductionRouteDestination.incomingReviewReserved => false,
    };
  }

  int _beginOperation() {
    final operation = _operationGeneration + 1;
    _operationGeneration = operation;
    _state = _state.copyWith(navigationInProgress: true);
    return operation;
  }

  void _endOperation(int operation) {
    if (_operationGeneration == operation) {
      _state = _state.copyWith(navigationInProgress: false);
    }
  }

  bool _canCompleteOperation(int operation) {
    return !_state.disposed && _operationGeneration == operation;
  }

  CallV2ProductionRouteSinkError _mapFactoryError(
    CallV2ProductionRouteObjectFactoryError error,
  ) {
    return switch (error) {
      CallV2ProductionRouteObjectFactoryError.invalidInput =>
        CallV2ProductionRouteSinkError.invalidInput,
      CallV2ProductionRouteObjectFactoryError.screenFactoryRejected =>
        CallV2ProductionRouteSinkError.routeFactoryRejected,
      CallV2ProductionRouteObjectFactoryError.staleGeneration =>
        CallV2ProductionRouteSinkError.staleGeneration,
      CallV2ProductionRouteObjectFactoryError.routeNameMismatch =>
        CallV2ProductionRouteSinkError.routeNameMismatch,
      CallV2ProductionRouteObjectFactoryError.reservedDestination =>
        CallV2ProductionRouteSinkError.reservedDestination,
      CallV2ProductionRouteObjectFactoryError.destinationViewModelMismatch =>
        CallV2ProductionRouteSinkError.destinationViewModelMismatch,
      CallV2ProductionRouteObjectFactoryError.terminalDescriptor =>
        CallV2ProductionRouteSinkError.terminalDescriptor,
      CallV2ProductionRouteObjectFactoryError.unsupportedDestination =>
        CallV2ProductionRouteSinkError.routeFactoryRejected,
    };
  }
}
