import 'package:flutter/widgets.dart';

import '../call_v2_production_presentation_snapshot.dart';
import '../call_v2_production_route_descriptor.dart';
import '../call_v2_production_route_destination.dart';
import '../call_v2_production_user_action.dart';
import '../call_v2_production_view_model_mapper.dart';
import 'call_v2_active_audio_shell.dart';
import 'call_v2_active_video_shell.dart';
import 'call_v2_connecting_shell.dart';
import 'call_v2_controlled_failure_shell.dart';
import 'call_v2_production_shell_factory_result.dart';

class CallV2ProductionScreenFactory {
  const CallV2ProductionScreenFactory();

  CallV2ProductionScreenFactoryResult<Widget> createScreen({
    required CallV2ProductionRouteDescriptor descriptor,
    required CallV2ProductionViewModel viewModel,
    ValueChanged<CallV2ProductionUserAction>? onAction,
    int minimumGeneration = 0,
  }) {
    final generation = descriptor.generation;
    if (generation < 0 || minimumGeneration < 0) {
      return _rejected(
        CallV2ProductionScreenFactoryError.invalidInput,
        descriptor,
      );
    }
    if (generation < minimumGeneration) {
      return _rejected(
        CallV2ProductionScreenFactoryError.staleGeneration,
        descriptor,
      );
    }
    if (descriptor.terminalStatus ==
        CallV2ProductionPresentationTerminalStatus.terminalDisposed) {
      return const CallV2ProductionScreenFactoryResult.noScreen();
    }

    final destination = descriptor.destination;
    if (!destination.isAvailable ||
        destination ==
            CallV2ProductionRouteDestination.incomingReviewReserved) {
      return _rejected(
        CallV2ProductionScreenFactoryError.reservedDestination,
        descriptor,
      );
    }

    final expectedRouteName = _expectedRouteName(destination);
    if (expectedRouteName == null ||
        descriptor.routeName != expectedRouteName) {
      return _rejected(
        CallV2ProductionScreenFactoryError.routeNameMismatch,
        descriptor,
      );
    }

    return switch (destination) {
      CallV2ProductionRouteDestination.connecting =>
        viewModel is CallV2ConnectingProductionViewModel
            ? CallV2ProductionScreenFactoryResult.rendered(
                CallV2ConnectingScreen(
                  viewModel: viewModel.value,
                  onAction: onAction,
                ),
              )
            : _rejected(
                CallV2ProductionScreenFactoryError.destinationViewModelMismatch,
                descriptor,
              ),
      CallV2ProductionRouteDestination.activeAudio =>
        viewModel is CallV2ActiveAudioProductionViewModel
            ? CallV2ProductionScreenFactoryResult.rendered(
                CallV2ActiveAudioScreen(
                  viewModel: viewModel.value,
                  onAction: onAction,
                ),
              )
            : _rejected(
                CallV2ProductionScreenFactoryError.destinationViewModelMismatch,
                descriptor,
              ),
      CallV2ProductionRouteDestination.activeVideo =>
        viewModel is CallV2ActiveVideoProductionViewModel
            ? CallV2ProductionScreenFactoryResult.rendered(
                CallV2ActiveVideoScreen(
                  viewModel: viewModel.value,
                  onAction: onAction,
                ),
              )
            : _rejected(
                CallV2ProductionScreenFactoryError.destinationViewModelMismatch,
                descriptor,
              ),
      CallV2ProductionRouteDestination.controlledFailure =>
        viewModel is CallV2ControlledFailureProductionViewModel
            ? CallV2ProductionScreenFactoryResult.rendered(
                CallV2ControlledFailureScreen(
                  viewModel: viewModel.value,
                  onAction: onAction,
                ),
              )
            : _rejected(
                CallV2ProductionScreenFactoryError.destinationViewModelMismatch,
                descriptor,
              ),
      CallV2ProductionRouteDestination.incomingReviewReserved => _rejected(
          CallV2ProductionScreenFactoryError.reservedDestination,
          descriptor,
        ),
    };
  }

  String? _expectedRouteName(CallV2ProductionRouteDestination destination) {
    try {
      return CallV2ProductionRouteNames.forDestination(destination);
    } on ArgumentError {
      return null;
    }
  }

  CallV2ProductionScreenFactoryRejected<Widget> _rejected(
    CallV2ProductionScreenFactoryError error,
    CallV2ProductionRouteDescriptor descriptor,
  ) {
    return CallV2ProductionScreenFactoryRejected<Widget>(
      error,
      destination: descriptor.destination.name,
      generation: descriptor.generation,
    );
  }
}
