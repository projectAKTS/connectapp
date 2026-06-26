import 'call_lifecycle.dart';
import 'call_local_phase.dart';
import 'call_snapshot.dart';
import 'participant_media_state.dart';

enum NativePresentationState {
  notPresented,
  callkitPresented,
  acceptedNatively,
  declinedNatively,
  endingRequested,
  endedNatively;
}

enum CallRouteState {
  notRequested,
  opening,
  open,
  failed,
  closed;
}

enum IncomingRouteState {
  notRequested,
  opening,
  presented,
  failed,
  closed;
}

enum CleanupStatus {
  notRequested,
  requested,
  completed;
}

class CallSessionState {
  CallSessionState({
    required this.callId,
    required this.latestAuthoritativeVersion,
    required this.lifecycle,
    required this.localParticipantRole,
    required this.localMediaState,
    required this.peerMediaState,
    required this.localMediaVersion,
    required this.peerMediaVersion,
    required this.localPhase,
    required this.nativePresentationState,
    required this.incomingRouteState,
    required this.callRouteState,
    required this.cleanupStatus,
    List<String> processedEventIds = const <String>[],
  }) : processedEventIds = List.unmodifiable(processedEventIds);

  factory CallSessionState.initial() {
    return CallSessionState(
      callId: null,
      latestAuthoritativeVersion: 0,
      lifecycle: null,
      localParticipantRole: null,
      localMediaState: ParticipantMediaState.notJoined,
      peerMediaState: ParticipantMediaState.notJoined,
      localMediaVersion: 0,
      peerMediaVersion: 0,
      localPhase: CallLocalPhase.idle,
      nativePresentationState: NativePresentationState.notPresented,
      incomingRouteState: IncomingRouteState.notRequested,
      callRouteState: CallRouteState.notRequested,
      cleanupStatus: CleanupStatus.notRequested,
    );
  }

  static const int maxProcessedEventIds = 64;

  final String? callId;
  final int latestAuthoritativeVersion;
  final CallLifecycle? lifecycle;
  final CallParticipantRole? localParticipantRole;
  final ParticipantMediaState localMediaState;
  final ParticipantMediaState peerMediaState;
  final int localMediaVersion;
  final int peerMediaVersion;
  final CallLocalPhase localPhase;
  final NativePresentationState nativePresentationState;
  final IncomingRouteState incomingRouteState;
  final CallRouteState callRouteState;
  final CleanupStatus cleanupStatus;
  final List<String> processedEventIds;

  bool get isIdle => callId == null;
  bool get isTerminal => lifecycle?.isTerminal ?? false;
  bool get hasProcessedEvents => processedEventIds.isNotEmpty;

  CallSessionState copyWith({
    Object? callId = _notSet,
    int? latestAuthoritativeVersion,
    Object? lifecycle = _notSet,
    Object? localParticipantRole = _notSet,
    ParticipantMediaState? localMediaState,
    ParticipantMediaState? peerMediaState,
    int? localMediaVersion,
    int? peerMediaVersion,
    CallLocalPhase? localPhase,
    NativePresentationState? nativePresentationState,
    IncomingRouteState? incomingRouteState,
    CallRouteState? callRouteState,
    CleanupStatus? cleanupStatus,
    List<String>? processedEventIds,
  }) {
    return CallSessionState(
      callId: identical(callId, _notSet) ? this.callId : callId as String?,
      latestAuthoritativeVersion:
          latestAuthoritativeVersion ?? this.latestAuthoritativeVersion,
      lifecycle: identical(lifecycle, _notSet)
          ? this.lifecycle
          : lifecycle as CallLifecycle?,
      localParticipantRole: identical(localParticipantRole, _notSet)
          ? this.localParticipantRole
          : localParticipantRole as CallParticipantRole?,
      localMediaState: localMediaState ?? this.localMediaState,
      peerMediaState: peerMediaState ?? this.peerMediaState,
      localMediaVersion: localMediaVersion ?? this.localMediaVersion,
      peerMediaVersion: peerMediaVersion ?? this.peerMediaVersion,
      localPhase: localPhase ?? this.localPhase,
      nativePresentationState:
          nativePresentationState ?? this.nativePresentationState,
      incomingRouteState: incomingRouteState ?? this.incomingRouteState,
      callRouteState: callRouteState ?? this.callRouteState,
      cleanupStatus: cleanupStatus ?? this.cleanupStatus,
      processedEventIds: processedEventIds ?? this.processedEventIds,
    );
  }

  CallSessionState markProcessed(String eventId) {
    final nextIds = <String>[...processedEventIds, eventId];
    final boundedIds = nextIds.length <= maxProcessedEventIds
        ? nextIds
        : nextIds.sublist(nextIds.length - maxProcessedEventIds);
    return copyWith(processedEventIds: boundedIds);
  }
}

class _NotSet {
  const _NotSet();
}

const _notSet = _NotSet();
