import 'call_snapshot.dart';

sealed class CallEvent {
  const CallEvent({
    required this.callId,
    required this.eventId,
  })  : assert(callId.length > 0, 'callId must not be empty'),
        assert(eventId.length > 0, 'eventId must not be empty');

  final String callId;
  final String eventId;
}

base class CallSnapshotReceived extends CallEvent {
  CallSnapshotReceived({
    required this.snapshot,
    required this.localParticipantRole,
  }) : super(
          callId: snapshot.callId,
          eventId: 'snapshot:${snapshot.callId}:${snapshot.version}:'
              '${snapshot.callerMediaVersion}:${snapshot.calleeMediaVersion}',
        );

  final CallSnapshot snapshot;
  final CallParticipantRole localParticipantRole;
}

sealed class UserCommandEvent extends CallEvent {
  const UserCommandEvent({
    required super.callId,
    required this.commandId,
  })  : assert(commandId.length > 0, 'commandId must not be empty'),
        super(eventId: 'command:$commandId');

  final String commandId;
}

final class LocalUserAccepted extends UserCommandEvent {
  const LocalUserAccepted({
    required super.callId,
    required super.commandId,
  });
}

final class LocalUserDeclined extends UserCommandEvent {
  const LocalUserDeclined({
    required super.callId,
    required super.commandId,
  });
}

final class LocalUserCancelled extends UserCommandEvent {
  const LocalUserCancelled({
    required super.callId,
    required super.commandId,
  });
}

final class LocalUserEnded extends UserCommandEvent {
  const LocalUserEnded({
    required super.callId,
    required super.commandId,
  });
}

final class PrepareMediaRequested extends CallEvent {
  const PrepareMediaRequested({
    required super.callId,
    required super.eventId,
  });
}

final class JoinMediaRequested extends CallEvent {
  const JoinMediaRequested({
    required super.callId,
    required super.eventId,
  });
}

final class LocalMediaPreparing extends CallEvent {
  const LocalMediaPreparing({
    required super.callId,
    required super.eventId,
  });
}

final class LocalMediaJoining extends CallEvent {
  const LocalMediaJoining({
    required super.callId,
    required super.eventId,
  });
}

final class LocalMediaJoined extends CallEvent {
  const LocalMediaJoined({
    required super.callId,
    required super.eventId,
  });
}

final class PeerMediaJoined extends CallEvent {
  const PeerMediaJoined({
    required super.callId,
    required super.eventId,
  });
}

final class RemoteDetected extends CallEvent {
  const RemoteDetected({
    required super.callId,
    required super.eventId,
  });
}

final class MediaReconnecting extends CallEvent {
  const MediaReconnecting({
    required super.callId,
    required super.eventId,
  });
}

final class MediaReconnected extends CallEvent {
  const MediaReconnected({
    required super.callId,
    required super.eventId,
  });
}

final class MediaFailed extends CallEvent {
  const MediaFailed({
    required super.callId,
    required super.eventId,
    this.failureCode,
  });

  final String? failureCode;
}

final class NativeIncomingPresented extends CallEvent {
  const NativeIncomingPresented({
    required super.callId,
    required super.eventId,
  });
}

final class NativeAccepted extends UserCommandEvent {
  const NativeAccepted({
    required super.callId,
    required super.commandId,
  });
}

final class NativeDeclined extends UserCommandEvent {
  const NativeDeclined({
    required super.callId,
    required super.commandId,
  });
}

final class RouteOpened extends CallEvent {
  const RouteOpened({
    required super.callId,
    required super.eventId,
  });
}

final class RouteOpenFailed extends CallEvent {
  const RouteOpenFailed({
    required super.callId,
    required super.eventId,
    this.reason,
  });

  final String? reason;
}

final class RetryOpenCallRouteRequested extends CallEvent {
  const RetryOpenCallRouteRequested({
    required super.callId,
    required super.eventId,
  });
}

final class RouteClosed extends CallEvent {
  const RouteClosed({
    required super.callId,
    required super.eventId,
  });
}

final class IncomingRoutePresented extends CallEvent {
  const IncomingRoutePresented({
    required super.callId,
    required super.eventId,
  });
}

final class IncomingRoutePresentationFailed extends CallEvent {
  const IncomingRoutePresentationFailed({
    required super.callId,
    required super.eventId,
    this.reason,
  });

  final String? reason;
}

final class RetryIncomingRoutePresentationRequested extends CallEvent {
  const RetryIncomingRoutePresentationRequested({
    required super.callId,
    required super.eventId,
  });
}

final class IncomingRouteClosed extends CallEvent {
  const IncomingRouteClosed({
    required super.callId,
    required super.eventId,
  });
}

final class AppResumed extends CallEvent {
  const AppResumed({
    required super.callId,
    required super.eventId,
  });
}

final class CleanupCompleted extends CallEvent {
  const CleanupCompleted({
    required super.callId,
    required super.eventId,
  });
}

final class NativeCallEnded extends CallEvent {
  const NativeCallEnded({
    required super.callId,
    required super.eventId,
  });
}
