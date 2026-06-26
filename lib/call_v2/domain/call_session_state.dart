import 'call_lifecycle.dart';
import 'call_local_phase.dart';
import 'call_snapshot.dart';
import 'participant_media_state.dart';

enum NativePresentationState {
  notPresented,
  callkitPresented,
  acceptedNatively,
  declinedNatively,
  endedNatively;
}

class CallSessionState {
  CallSessionState({
    required this.callId,
    required this.latestVersion,
    required this.lifecycle,
    required this.localParticipantRole,
    required this.localMediaState,
    required this.peerMediaState,
    required this.localPhase,
    required this.nativePresentationState,
    required this.incomingRoutePresented,
    required this.callRouteOpening,
    required this.callRouteOpen,
    required this.terminalCleanupCompleted,
    Set<String> processedEventIds = const <String>{},
    Set<String> presentedRouteCallIds = const <String>{},
    Set<String> openedRouteCallIds = const <String>{},
    Set<String> closedRouteCallIds = const <String>{},
    Set<String> cleanupCallIds = const <String>{},
  })  : processedEventIds = Set.unmodifiable(processedEventIds),
        presentedRouteCallIds = Set.unmodifiable(presentedRouteCallIds),
        openedRouteCallIds = Set.unmodifiable(openedRouteCallIds),
        closedRouteCallIds = Set.unmodifiable(closedRouteCallIds),
        cleanupCallIds = Set.unmodifiable(cleanupCallIds);

  factory CallSessionState.initial() {
    return CallSessionState(
      callId: null,
      latestVersion: 0,
      lifecycle: null,
      localParticipantRole: null,
      localMediaState: ParticipantMediaState.notJoined,
      peerMediaState: ParticipantMediaState.notJoined,
      localPhase: CallLocalPhase.idle,
      nativePresentationState: NativePresentationState.notPresented,
      incomingRoutePresented: false,
      callRouteOpening: false,
      callRouteOpen: false,
      terminalCleanupCompleted: false,
    );
  }

  final String? callId;
  final int latestVersion;
  final CallLifecycle? lifecycle;
  final CallParticipantRole? localParticipantRole;
  final ParticipantMediaState localMediaState;
  final ParticipantMediaState peerMediaState;
  final CallLocalPhase localPhase;
  final NativePresentationState nativePresentationState;
  final bool incomingRoutePresented;
  final bool callRouteOpening;
  final bool callRouteOpen;
  final bool terminalCleanupCompleted;
  final Set<String> processedEventIds;
  final Set<String> presentedRouteCallIds;
  final Set<String> openedRouteCallIds;
  final Set<String> closedRouteCallIds;
  final Set<String> cleanupCallIds;

  bool get isIdle => callId == null;
  bool get isTerminal => lifecycle?.isTerminal ?? false;

  CallSessionState copyWith({
    String? callId,
    int? latestVersion,
    CallLifecycle? lifecycle,
    CallParticipantRole? localParticipantRole,
    ParticipantMediaState? localMediaState,
    ParticipantMediaState? peerMediaState,
    CallLocalPhase? localPhase,
    NativePresentationState? nativePresentationState,
    bool? incomingRoutePresented,
    bool? callRouteOpening,
    bool? callRouteOpen,
    bool? terminalCleanupCompleted,
    Set<String>? processedEventIds,
    Set<String>? presentedRouteCallIds,
    Set<String>? openedRouteCallIds,
    Set<String>? closedRouteCallIds,
    Set<String>? cleanupCallIds,
  }) {
    return CallSessionState(
      callId: callId ?? this.callId,
      latestVersion: latestVersion ?? this.latestVersion,
      lifecycle: lifecycle ?? this.lifecycle,
      localParticipantRole: localParticipantRole ?? this.localParticipantRole,
      localMediaState: localMediaState ?? this.localMediaState,
      peerMediaState: peerMediaState ?? this.peerMediaState,
      localPhase: localPhase ?? this.localPhase,
      nativePresentationState:
          nativePresentationState ?? this.nativePresentationState,
      incomingRoutePresented:
          incomingRoutePresented ?? this.incomingRoutePresented,
      callRouteOpening: callRouteOpening ?? this.callRouteOpening,
      callRouteOpen: callRouteOpen ?? this.callRouteOpen,
      terminalCleanupCompleted:
          terminalCleanupCompleted ?? this.terminalCleanupCompleted,
      processedEventIds: processedEventIds ?? this.processedEventIds,
      presentedRouteCallIds:
          presentedRouteCallIds ?? this.presentedRouteCallIds,
      openedRouteCallIds: openedRouteCallIds ?? this.openedRouteCallIds,
      closedRouteCallIds: closedRouteCallIds ?? this.closedRouteCallIds,
      cleanupCallIds: cleanupCallIds ?? this.cleanupCallIds,
    );
  }

  CallSessionState markProcessed(String eventId) {
    return copyWith(
      processedEventIds: <String>{...processedEventIds, eventId},
    );
  }
}
