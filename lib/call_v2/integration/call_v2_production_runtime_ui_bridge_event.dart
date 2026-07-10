import '../call_v2_api.dart';
import '../ui/call_v2_production_presentation_snapshot.dart';
import '../ui/call_v2_production_view_state.dart';

enum CallV2ProductionRuntimeUiBridgeEventType {
  initialize,
  presentationSnapshot,
  close,
  dispose,
  runtimeTerminated,
  runtimeFailedControlled,
  invalid,
}

enum CallV2ProductionRuntimeUiBridgeControlledFailure {
  unavailable,
  rejected,
  unauthorized,
  invalidRequest,
}

final class CallV2ProductionRuntimeUiBridgeEvent {
  const CallV2ProductionRuntimeUiBridgeEvent._({
    required this.type,
    this.snapshot,
    this.generation,
    this.controlledFailure,
  });

  const factory CallV2ProductionRuntimeUiBridgeEvent.initialize() =
      _InitializeCallV2ProductionRuntimeUiBridgeEvent;

  factory CallV2ProductionRuntimeUiBridgeEvent.presentationSnapshot(
    CallV2ProductionPresentationSnapshot snapshot,
  ) = _PresentationSnapshotCallV2ProductionRuntimeUiBridgeEvent;

  const factory CallV2ProductionRuntimeUiBridgeEvent.close({
    int? generation,
  }) = _CloseCallV2ProductionRuntimeUiBridgeEvent;

  const factory CallV2ProductionRuntimeUiBridgeEvent.dispose() =
      _DisposeCallV2ProductionRuntimeUiBridgeEvent;

  const factory CallV2ProductionRuntimeUiBridgeEvent.runtimeTerminated({
    int? generation,
  }) = _RuntimeTerminatedCallV2ProductionRuntimeUiBridgeEvent;

  const factory CallV2ProductionRuntimeUiBridgeEvent.runtimeFailedControlled({
    required CallV2ProductionRuntimeUiBridgeControlledFailure failure,
    required int generation,
  }) = _RuntimeFailedControlledCallV2ProductionRuntimeUiBridgeEvent;

  const factory CallV2ProductionRuntimeUiBridgeEvent.invalid({
    int? generation,
  }) = _InvalidCallV2ProductionRuntimeUiBridgeEvent;

  final CallV2ProductionRuntimeUiBridgeEventType type;
  final CallV2ProductionPresentationSnapshot? snapshot;
  final int? generation;
  final CallV2ProductionRuntimeUiBridgeControlledFailure? controlledFailure;

  CallV2ProductionPresentationSnapshot? toControlledFailureSnapshot() {
    final failure = controlledFailure;
    final eventGeneration = generation;
    if (failure == null || eventGeneration == null || eventGeneration < 0) {
      return null;
    }
    return CallV2ProductionPresentationSnapshot.controlledFailure(
      sessionReference: null,
      generation: eventGeneration,
      screenState: CallV2ProductionControlledFailureScreenState(
        errorCode: failure.toClientErrorCode(),
        retryPolicy: CallV2ProductionFailureRetryPolicy.retryUnavailable,
        dismissPolicy: CallV2ProductionFailureDismissPolicy.dismissAllowed,
      ),
    );
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'type': type.name,
      if (snapshot != null) 'snapshot': snapshot!.toSafeDebugMap(),
      if (generation != null) 'generation': generation,
      if (controlledFailure != null)
        'controlledFailure': controlledFailure!.name,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionRuntimeUiBridgeEvent(${toSafeDebugMap()})';
  }
}

extension CallV2ProductionRuntimeUiBridgeControlledFailureClientCode
    on CallV2ProductionRuntimeUiBridgeControlledFailure {
  CallV2ClientErrorCode toClientErrorCode() {
    return switch (this) {
      CallV2ProductionRuntimeUiBridgeControlledFailure.unavailable =>
        CallV2ClientErrorCode.unavailable,
      CallV2ProductionRuntimeUiBridgeControlledFailure.rejected =>
        CallV2ClientErrorCode.rejected,
      CallV2ProductionRuntimeUiBridgeControlledFailure.unauthorized =>
        CallV2ClientErrorCode.unauthorized,
      CallV2ProductionRuntimeUiBridgeControlledFailure.invalidRequest =>
        CallV2ClientErrorCode.invalidRequest,
    };
  }
}

final class _InitializeCallV2ProductionRuntimeUiBridgeEvent
    extends CallV2ProductionRuntimeUiBridgeEvent {
  const _InitializeCallV2ProductionRuntimeUiBridgeEvent()
      : super._(type: CallV2ProductionRuntimeUiBridgeEventType.initialize);
}

final class _PresentationSnapshotCallV2ProductionRuntimeUiBridgeEvent
    extends CallV2ProductionRuntimeUiBridgeEvent {
  _PresentationSnapshotCallV2ProductionRuntimeUiBridgeEvent(
    CallV2ProductionPresentationSnapshot snapshot,
  ) : super._(
          type: CallV2ProductionRuntimeUiBridgeEventType.presentationSnapshot,
          snapshot: snapshot,
          generation: snapshot.generation,
        );
}

final class _CloseCallV2ProductionRuntimeUiBridgeEvent
    extends CallV2ProductionRuntimeUiBridgeEvent {
  const _CloseCallV2ProductionRuntimeUiBridgeEvent({int? generation})
      : super._(
          type: CallV2ProductionRuntimeUiBridgeEventType.close,
          generation: generation,
        );
}

final class _DisposeCallV2ProductionRuntimeUiBridgeEvent
    extends CallV2ProductionRuntimeUiBridgeEvent {
  const _DisposeCallV2ProductionRuntimeUiBridgeEvent()
      : super._(type: CallV2ProductionRuntimeUiBridgeEventType.dispose);
}

final class _RuntimeTerminatedCallV2ProductionRuntimeUiBridgeEvent
    extends CallV2ProductionRuntimeUiBridgeEvent {
  const _RuntimeTerminatedCallV2ProductionRuntimeUiBridgeEvent({
    int? generation,
  }) : super._(
          type: CallV2ProductionRuntimeUiBridgeEventType.runtimeTerminated,
          generation: generation,
        );
}

final class _RuntimeFailedControlledCallV2ProductionRuntimeUiBridgeEvent
    extends CallV2ProductionRuntimeUiBridgeEvent {
  const _RuntimeFailedControlledCallV2ProductionRuntimeUiBridgeEvent({
    required CallV2ProductionRuntimeUiBridgeControlledFailure failure,
    required int generation,
  }) : super._(
          type:
              CallV2ProductionRuntimeUiBridgeEventType.runtimeFailedControlled,
          controlledFailure: failure,
          generation: generation,
        );
}

final class _InvalidCallV2ProductionRuntimeUiBridgeEvent
    extends CallV2ProductionRuntimeUiBridgeEvent {
  const _InvalidCallV2ProductionRuntimeUiBridgeEvent({int? generation})
      : super._(
          type: CallV2ProductionRuntimeUiBridgeEventType.invalid,
          generation: generation,
        );
}
