import 'package:flutter/foundation.dart';

import '../ui/call_v2_production_mapping_result.dart';
import '../ui/call_v2_production_presentation_snapshot.dart';
import '../ui/call_v2_production_route_descriptor.dart';
import '../ui/call_v2_production_route_destination.dart';
import '../ui/call_v2_production_route_factory.dart';
import '../ui/call_v2_production_user_action.dart';
import '../ui/call_v2_production_view_model_mapper.dart';
import '../ui/call_v2_production_view_model_result.dart';
import 'call_v2_production_route_object_factory.dart';
import 'call_v2_production_route_sink.dart';
import 'call_v2_production_route_sink_adapter.dart';
import 'call_v2_production_route_sink_result.dart';
import 'call_v2_production_ui_composition_result.dart';
import 'call_v2_production_ui_composition_status.dart';

typedef CallV2ProductionUiRolloutReader = bool Function();
typedef CallV2ProductionUiMinimumGenerationReader = int Function();

final class CallV2ProductionUiCompositionOwner {
  CallV2ProductionUiCompositionOwner({
    CallV2ProductionRouteSink? routeSink,
    CallV2ProductionRouteSinkAdapter? routeSinkAdapter,
    CallV2ProductionRouteFactory routeFactory =
        const CallV2ProductionRouteFactory(),
    CallV2ProductionViewModelMapper viewModelMapper =
        const CallV2ProductionViewModelMapper(),
    CallV2ProductionRouteObjectFactory routeObjectFactory =
        const CallV2ProductionRouteObjectFactory(),
    ValueChanged<CallV2ProductionUserAction>? onAction,
    CallV2ProductionUiRolloutReader? rolloutEnabled,
    CallV2ProductionUiMinimumGenerationReader? minimumGeneration,
    int minimumGenerationValue = 0,
  })  : _routeSink = routeSink,
        _routeSinkAdapter = routeSinkAdapter,
        _routeFactory = routeFactory,
        _viewModelMapper = viewModelMapper,
        _routeObjectFactory = routeObjectFactory,
        _onAction = onAction,
        _rolloutEnabled = rolloutEnabled ?? (() => false),
        _minimumGeneration =
            minimumGeneration ?? (() => minimumGenerationValue);

  final CallV2ProductionRouteSinkAdapter? _routeSinkAdapter;
  final CallV2ProductionRouteFactory _routeFactory;
  final CallV2ProductionViewModelMapper _viewModelMapper;
  final CallV2ProductionRouteObjectFactory _routeObjectFactory;
  final ValueChanged<CallV2ProductionUserAction>? _onAction;
  final CallV2ProductionUiRolloutReader _rolloutEnabled;
  final CallV2ProductionUiMinimumGenerationReader _minimumGeneration;

  CallV2ProductionRouteSink? _routeSink;
  CallV2ProductionUiCompositionStatus _status =
      const CallV2ProductionUiCompositionStatus();

  CallV2ProductionUiCompositionStatus get status => _status;

  CallV2ProductionUiCompositionResult initialize() {
    if (_status.disposed) {
      return const CallV2ProductionUiCompositionResult.disposed();
    }
    final rolloutEnabled = _safeRolloutEnabled();
    if (!rolloutEnabled) {
      _status = _status.copyWith(
        lifecycle: CallV2ProductionUiCompositionLifecycle.disabled,
        rolloutEnabled: false,
      );
      return const CallV2ProductionUiCompositionResult.disabled();
    }
    _status = _status.copyWith(
      lifecycle: CallV2ProductionUiCompositionLifecycle.initialized,
      rolloutEnabled: true,
    );
    return const CallV2ProductionUiCompositionResult.initialized();
  }

  Future<CallV2ProductionUiCompositionResult> renderSnapshot(
    CallV2ProductionPresentationSnapshot snapshot,
  ) async {
    if (_status.disposed) {
      return _rejected(CallV2ProductionUiCompositionError.disposed);
    }
    final rolloutEnabled = _safeRolloutEnabled();
    if (!rolloutEnabled) {
      _status = _status.copyWith(
        lifecycle: CallV2ProductionUiCompositionLifecycle.disabled,
        rolloutEnabled: false,
      );
      return CallV2ProductionUiCompositionResult.disabled(
        destination: snapshot.destination,
        generation: snapshot.generation,
      );
    }
    _status = _status.copyWith(rolloutEnabled: true);

    final minimumGeneration = _safeMinimumGeneration();
    if (minimumGeneration < 0 || snapshot.generation < 0) {
      return _rejected(
        CallV2ProductionUiCompositionError.invalidSnapshot,
        destination: snapshot.destination,
        generation: snapshot.generation,
      );
    }

    final descriptorResult = _routeFactory.createDescriptor(
      snapshot,
      minimumGeneration: minimumGeneration,
    );
    final CallV2ProductionRouteDescriptor? descriptor;
    switch (descriptorResult) {
      case CallV2ProductionMappingSuccess<CallV2ProductionRouteDescriptor>(
          :final value
        ):
        descriptor = value;
      case CallV2ProductionMappingNoRoute<CallV2ProductionRouteDescriptor>():
        descriptor = null;
      case CallV2ProductionMappingRejected<CallV2ProductionRouteDescriptor>(
          :final error
        ):
        return _returnRejectedMapping(error, snapshot);
    }
    if (descriptor == null) {
      return close(generation: snapshot.generation);
    }

    final viewModelResult = _viewModelMapper.map(
      snapshot,
      minimumGeneration: minimumGeneration,
    );
    final CallV2ProductionViewModel? viewModel;
    switch (viewModelResult) {
      case CallV2ProductionViewModelSuccess<CallV2ProductionViewModel>(
          :final value
        ):
        viewModel = value;
      case CallV2ProductionViewModelNoView<CallV2ProductionViewModel>():
        viewModel = null;
      case CallV2ProductionViewModelRejected<CallV2ProductionViewModel>(
          :final error
        ):
        return _returnRejectedViewModel(error, snapshot);
    }
    if (viewModel == null) {
      return close(generation: snapshot.generation);
    }

    final routeSinkResult = _requireRouteSink(
      destination: descriptor.destination,
      generation: descriptor.generation,
    );
    if (routeSinkResult is CallV2ProductionUiCompositionResult) {
      return routeSinkResult;
    }
    if (routeSinkResult is! CallV2ProductionRouteSink) {
      return _rejected(
        CallV2ProductionUiCompositionError.routeSinkRejected,
        destination: descriptor.destination,
        generation: descriptor.generation,
      );
    }
    final routeSink = routeSinkResult;

    final sinkResult = await routeSink.show(
      descriptor: descriptor,
      viewModel: viewModel,
      onAction: _onAction,
      minimumGeneration: minimumGeneration,
    );
    return _mapSinkResult(sinkResult);
  }

  Future<CallV2ProductionUiCompositionResult> close({int? generation}) async {
    if (_status.disposed) {
      return _rejected(CallV2ProductionUiCompositionError.disposed);
    }
    final rolloutEnabled = _safeRolloutEnabled();
    if (!rolloutEnabled) {
      _status = _status.copyWith(
        lifecycle: CallV2ProductionUiCompositionLifecycle.disabled,
        rolloutEnabled: false,
      );
      return CallV2ProductionUiCompositionResult.disabled(
        generation: generation,
      );
    }
    final routeSinkResult = _requireRouteSink(generation: generation);
    if (routeSinkResult is CallV2ProductionUiCompositionResult) {
      return routeSinkResult;
    }
    if (routeSinkResult is! CallV2ProductionRouteSink) {
      return _rejected(
        CallV2ProductionUiCompositionError.routeSinkRejected,
        generation: generation,
      );
    }
    final routeSink = routeSinkResult;
    final sinkResult = await routeSink.close();
    return _mapSinkResult(sinkResult, fallbackGeneration: generation);
  }

  CallV2ProductionUiCompositionResult dispose() {
    if (_status.disposed) {
      return const CallV2ProductionUiCompositionResult.disposed();
    }
    _routeSink?.dispose();
    _status = _status.copyWith(
      lifecycle: CallV2ProductionUiCompositionLifecycle.disposed,
      clearCurrent: true,
      disposed: true,
      rolloutEnabled: _safeRolloutEnabled(),
    );
    return const CallV2ProductionUiCompositionResult.disposed();
  }

  Object _requireRouteSink({
    CallV2ProductionRouteDestination? destination,
    int? generation,
  }) {
    final existing = _routeSink;
    if (existing != null) return existing;
    final adapter = _routeSinkAdapter;
    if (adapter == null) {
      return _rejected(
        CallV2ProductionUiCompositionError.routeSinkRejected,
        destination: destination,
        generation: generation,
      );
    }
    final created = CallV2ProductionRouteSink(
      adapter: adapter,
      routeFactory: _routeObjectFactory,
    );
    _routeSink = created;
    return created;
  }

  bool _safeRolloutEnabled() {
    try {
      return _rolloutEnabled();
    } catch (_) {
      return false;
    }
  }

  int _safeMinimumGeneration() {
    try {
      return _minimumGeneration();
    } catch (_) {
      return -1;
    }
  }

  CallV2ProductionUiCompositionResult _returnRejectedMapping(
    CallV2ProductionMappingError error,
    CallV2ProductionPresentationSnapshot snapshot,
  ) {
    return _rejected(
      _mapRouteMappingError(error),
      destination: snapshot.destination,
      generation: snapshot.generation,
    );
  }

  CallV2ProductionUiCompositionResult _returnRejectedViewModel(
    CallV2ProductionViewModelError error,
    CallV2ProductionPresentationSnapshot snapshot,
  ) {
    return _rejected(
      _mapViewModelError(error),
      destination: snapshot.destination,
      generation: snapshot.generation,
    );
  }

  CallV2ProductionUiCompositionResult _mapSinkResult(
    CallV2ProductionRouteSinkResult result, {
    int? fallbackGeneration,
  }) {
    return switch (result) {
      CallV2ProductionRouteSinkPushed(:final destination, :final generation) =>
        _rendered(destination: destination, generation: generation),
      CallV2ProductionRouteSinkReplaced(
        :final destination,
        :final generation
      ) =>
        _rendered(destination: destination, generation: generation),
      CallV2ProductionRouteSinkPopped() => _closed(fallbackGeneration),
      CallV2ProductionRouteSinkNoOp(:final destination, :final generation) =>
        _noOp(destination: destination, generation: generation),
      CallV2ProductionRouteSinkRejected(
        :final error,
        :final destination,
        :final generation
      ) =>
        _rejected(
          _mapRouteSinkError(error),
          destination: destination,
          generation: generation,
        ),
    };
  }

  CallV2ProductionUiCompositionResult _rendered({
    required CallV2ProductionRouteDestination destination,
    required int generation,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionUiCompositionLifecycle.rendered,
      currentDestination: destination,
      currentGeneration: generation,
      rolloutEnabled: true,
    );
    return CallV2ProductionUiCompositionResult.rendered(
      destination: destination,
      generation: generation,
    );
  }

  CallV2ProductionUiCompositionResult _closed(int? generation) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionUiCompositionLifecycle.closed,
      clearCurrent: true,
      rolloutEnabled: true,
    );
    return CallV2ProductionUiCompositionResult.closed(generation: generation);
  }

  CallV2ProductionUiCompositionResult _noOp({
    CallV2ProductionRouteDestination? destination,
    int? generation,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionUiCompositionLifecycle.initialized,
      currentDestination: destination,
      currentGeneration: generation,
      rolloutEnabled: _safeRolloutEnabled(),
    );
    return CallV2ProductionUiCompositionResult.noOp(
      destination: destination,
      generation: generation,
    );
  }

  CallV2ProductionUiCompositionResult _rejected(
    CallV2ProductionUiCompositionError error, {
    CallV2ProductionRouteDestination? destination,
    int? generation,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionUiCompositionLifecycle.rejected,
      rolloutEnabled: _safeRolloutEnabled(),
    );
    return CallV2ProductionUiCompositionResult.rejected(
      error,
      destination: destination,
      generation: generation,
    );
  }

  CallV2ProductionUiCompositionError _mapRouteMappingError(
    CallV2ProductionMappingError error,
  ) {
    return switch (error) {
      CallV2ProductionMappingError.invalidInput =>
        CallV2ProductionUiCompositionError.invalidSnapshot,
      CallV2ProductionMappingError.staleGeneration =>
        CallV2ProductionUiCompositionError.staleGeneration,
      CallV2ProductionMappingError.reservedDestination =>
        CallV2ProductionUiCompositionError.reservedDestination,
      CallV2ProductionMappingError.invalidRouteName =>
        CallV2ProductionUiCompositionError.routeMappingRejected,
    };
  }

  CallV2ProductionUiCompositionError _mapViewModelError(
    CallV2ProductionViewModelError error,
  ) {
    return switch (error) {
      CallV2ProductionViewModelError.invalidInput =>
        CallV2ProductionUiCompositionError.invalidSnapshot,
      CallV2ProductionViewModelError.staleGeneration =>
        CallV2ProductionUiCompositionError.staleGeneration,
      CallV2ProductionViewModelError.reservedDestination =>
        CallV2ProductionUiCompositionError.reservedDestination,
      CallV2ProductionViewModelError.incompatibleState =>
        CallV2ProductionUiCompositionError.viewModelMappingRejected,
      CallV2ProductionViewModelError.invalidActions =>
        CallV2ProductionUiCompositionError.viewModelMappingRejected,
    };
  }

  CallV2ProductionUiCompositionError _mapRouteSinkError(
    CallV2ProductionRouteSinkError error,
  ) {
    return switch (error) {
      CallV2ProductionRouteSinkError.invalidInput =>
        CallV2ProductionUiCompositionError.invalidSnapshot,
      CallV2ProductionRouteSinkError.staleGeneration =>
        CallV2ProductionUiCompositionError.staleGeneration,
      CallV2ProductionRouteSinkError.disposed =>
        CallV2ProductionUiCompositionError.disposed,
      CallV2ProductionRouteSinkError.adapterDisposed =>
        CallV2ProductionUiCompositionError.disposed,
      CallV2ProductionRouteSinkError.routeFactoryRejected =>
        CallV2ProductionUiCompositionError.routeSinkRejected,
      CallV2ProductionRouteSinkError.invalidTransition =>
        CallV2ProductionUiCompositionError.invalidTransition,
      CallV2ProductionRouteSinkError.destinationViewModelMismatch =>
        CallV2ProductionUiCompositionError.routeSinkRejected,
      CallV2ProductionRouteSinkError.routeNameMismatch =>
        CallV2ProductionUiCompositionError.routeSinkRejected,
      CallV2ProductionRouteSinkError.reservedDestination =>
        CallV2ProductionUiCompositionError.reservedDestination,
      CallV2ProductionRouteSinkError.terminalDescriptor =>
        CallV2ProductionUiCompositionError.terminal,
      CallV2ProductionRouteSinkError.navigationInProgress =>
        CallV2ProductionUiCompositionError.routeSinkRejected,
      CallV2ProductionRouteSinkError.adapterOperationFailed =>
        CallV2ProductionUiCompositionError.routeSinkRejected,
    };
  }
}
