import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_mapping_result.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_presentation_snapshot.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_descriptor.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_destination.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_factory.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_view_state.dart';
import 'package:connect_app/call_v2/ui/call_v2_ui_session_reference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const factory = CallV2ProductionRouteFactory();

  test('none snapshot produces a typed no-route result', () {
    final result = factory.createDescriptor(
      CallV2ProductionPresentationSnapshot.none(generation: 1),
    );

    expect(result, isA<CallV2ProductionMappingNoRoute>());
  });

  test('connecting, audio, video, and failure map to fixed route names only',
      () {
    final cases = <CallV2ProductionPresentationSnapshot, String>{
      CallV2ProductionPresentationSnapshot.connecting(
        sessionReference: _session(1),
        screenState: const CallV2ProductionConnectingScreenState(
          mediaMode: CallV2ProductionMediaMode.audio,
          cancelAvailable: true,
          connectionPhase: CallV2ProductionConnectionPhase.connecting,
        ),
      ): '/call-v2/connecting',
      CallV2ProductionPresentationSnapshot.activeAudio(
        sessionReference: _session(2),
        screenState: const CallV2ProductionActiveAudioScreenState(
          muted: false,
          speakerEnabled: true,
          leaveEnabled: true,
          connectionPhase: CallV2ProductionConnectionPhase.connected,
          elapsedSeconds: 0,
          reconnecting: false,
        ),
      ): '/call-v2/audio',
      CallV2ProductionPresentationSnapshot.activeVideo(
        sessionReference: _session(
          3,
          mediaMode: CallV2ProductionMediaMode.video,
        ),
        screenState: const CallV2ProductionActiveVideoScreenState(
          microphoneMuted: false,
          localCameraEnabled: true,
          remoteVideoAvailable: true,
          cameraSwitchAvailable: true,
          leaveEnabled: true,
          connectionPhase: CallV2ProductionConnectionPhase.connected,
          renderingState: CallV2ProductionVideoRenderingState.rendering,
          reconnecting: false,
        ),
      ): '/call-v2/video',
      CallV2ProductionPresentationSnapshot.controlledFailure(
        sessionReference: _session(4),
        screenState: const CallV2ProductionControlledFailureScreenState(
          errorCode: CallV2ClientErrorCode.rejected,
          retryPolicy: CallV2ProductionFailureRetryPolicy.retryAllowed,
          dismissPolicy: CallV2ProductionFailureDismissPolicy.dismissAllowed,
        ),
      ): '/call-v2/failure',
    };

    for (final entry in cases.entries) {
      final result = factory.createDescriptor(entry.key);
      expect(result, isA<CallV2ProductionMappingSuccess>());
      final descriptor = (result as CallV2ProductionMappingSuccess<
              CallV2ProductionRouteDescriptor>)
          .value;
      expect(descriptor.routeName, entry.value);
      expect(descriptor.routeName, isNot(contains('?')));
      expect(descriptor.routeName, isNot(contains(r'$')));
    }
  });

  test('terminal snapshot produces no live route', () {
    final result = factory.createDescriptor(
      CallV2ProductionPresentationSnapshot.none(
        generation: 10,
        terminalStatus:
            CallV2ProductionPresentationTerminalStatus.terminalDisposed,
      ),
    );

    expect(result, isA<CallV2ProductionMappingNoRoute>());
  });

  test('stale generation is rejected', () {
    final result = factory.createDescriptor(
      CallV2ProductionPresentationSnapshot.none(generation: 3),
      minimumGeneration: 4,
    );

    expect(result, isA<CallV2ProductionMappingRejected>());
    expect(
      (result as CallV2ProductionMappingRejected).error,
      CallV2ProductionMappingError.staleGeneration,
    );
  });

  test('reserved route remains rejected by fixed contract', () {
    expect(
      () => CallV2ProductionRouteNames.forDestination(
        CallV2ProductionRouteDestination.incomingReviewReserved,
      ),
      throwsArgumentError,
    );
  });

  test('factory performs no side effects', () {
    final snapshot = CallV2ProductionPresentationSnapshot.none(generation: 5);
    final before = snapshot.toString();

    expect(factory.createDescriptor(snapshot),
        isA<CallV2ProductionMappingNoRoute>());
    expect(factory.createDescriptor(snapshot),
        isA<CallV2ProductionMappingNoRoute>());
    expect(snapshot.toString(), before);
  });
}

CallV2UiSessionReference _session(
  int generation, {
  CallV2ProductionMediaMode mediaMode = CallV2ProductionMediaMode.audio,
}) {
  return CallV2UiSessionReference(
    generation: generation,
    mediaMode: mediaMode,
    localLifecycleStatus: CallV2ProductionLocalLifecycleStatus.active,
    connectionPhase: CallV2ProductionConnectionPhase.connected,
  );
}
