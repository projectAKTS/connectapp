import 'call_snapshot.dart';

sealed class CallEvent {
  const CallEvent({
    required this.callId,
    this.version,
    this.dedupeKey,
  });

  final String callId;
  final int? version;
  final String? dedupeKey;

  String get eventId => dedupeKey ?? '$runtimeType:$callId:${version ?? -1}';
}

base class CallSnapshotReceived extends CallEvent {
  CallSnapshotReceived({
    required this.snapshot,
    required this.localParticipantRole,
    String? dedupeKey,
  }) : super(
          callId: snapshot.callId,
          version: snapshot.version,
          dedupeKey: dedupeKey,
        );

  final CallSnapshot snapshot;
  final CallParticipantRole localParticipantRole;

  @override
  String get eventId {
    return dedupeKey ??
        '$runtimeType:$callId:$version:${snapshot.lifecycle}:'
            '${snapshot.callerMediaState}:${snapshot.calleeMediaState}';
  }
}

final class TerminalSnapshotReceived extends CallSnapshotReceived {
  TerminalSnapshotReceived({
    required super.snapshot,
    required super.localParticipantRole,
    super.dedupeKey,
  });
}

final class LocalUserAccepted extends CallEvent {
  const LocalUserAccepted({
    required super.callId,
    super.version,
    super.dedupeKey,
  });
}

final class LocalUserDeclined extends CallEvent {
  const LocalUserDeclined({
    required super.callId,
    super.version,
    super.dedupeKey,
  });
}

final class LocalUserCancelled extends CallEvent {
  const LocalUserCancelled({
    required super.callId,
    super.version,
    super.dedupeKey,
  });
}

final class LocalUserEnded extends CallEvent {
  const LocalUserEnded({
    required super.callId,
    super.version,
    super.dedupeKey,
  });
}

final class LocalMediaPreparing extends CallEvent {
  const LocalMediaPreparing({
    required super.callId,
    super.version,
    super.dedupeKey,
  });
}

final class LocalMediaJoining extends CallEvent {
  const LocalMediaJoining({
    required super.callId,
    super.version,
    super.dedupeKey,
  });
}

final class LocalMediaJoined extends CallEvent {
  const LocalMediaJoined({
    required super.callId,
    super.version,
    super.dedupeKey,
  });
}

final class PeerMediaJoined extends CallEvent {
  const PeerMediaJoined({
    required super.callId,
    super.version,
    super.dedupeKey,
  });
}

final class RemoteDetected extends CallEvent {
  const RemoteDetected({
    required super.callId,
    super.version,
    super.dedupeKey,
  });
}

final class MediaReconnecting extends CallEvent {
  const MediaReconnecting({
    required super.callId,
    super.version,
    super.dedupeKey,
  });
}

final class MediaReconnected extends CallEvent {
  const MediaReconnected({
    required super.callId,
    super.version,
    super.dedupeKey,
  });
}

final class MediaFailed extends CallEvent {
  const MediaFailed({
    required super.callId,
    super.version,
    this.failureCode,
    super.dedupeKey,
  });

  final String? failureCode;

  @override
  String get eventId =>
      dedupeKey ?? '$runtimeType:$callId:${version ?? -1}:${failureCode ?? ''}';
}

final class NativeIncomingPresented extends CallEvent {
  const NativeIncomingPresented({
    required super.callId,
    super.version,
    super.dedupeKey,
  });
}

final class NativeAccepted extends CallEvent {
  const NativeAccepted({
    required super.callId,
    super.version,
    super.dedupeKey,
  });
}

final class NativeDeclined extends CallEvent {
  const NativeDeclined({
    required super.callId,
    super.version,
    super.dedupeKey,
  });
}

final class RouteOpened extends CallEvent {
  const RouteOpened({
    required super.callId,
    super.version,
    super.dedupeKey,
  });
}

final class RouteClosed extends CallEvent {
  const RouteClosed({
    required super.callId,
    super.version,
    super.dedupeKey,
  });
}

final class AppResumed extends CallEvent {
  const AppResumed({
    required super.callId,
    super.version,
    super.dedupeKey,
  });
}
