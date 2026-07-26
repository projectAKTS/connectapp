import 'call_v2_runtime_config.dart';
import 'call_v2_runtime_mode.dart';
import 'call_v2_runtime_state.dart';

enum CallV2DevControlBlockedReason {
  none,
  productionDisabled,
  rolloutDisabled,
  waitingToStart,
  waitingForPermissions,
  waitingForAccess,
  waitingForSetup,
  waitingForJoin,
  waitingForReady,
  terminal,
}

class CallV2DevControlState {
  const CallV2DevControlState({
    required this.canStart,
    required this.canRequestPermissions,
    required this.canRequestAccess,
    required this.canInitializeRtc,
    required this.canJoinRtc,
    required this.canActivate,
    required this.canEnd,
    required this.blockedReason,
  });

  factory CallV2DevControlState.fromRuntime({
    required CallV2RuntimeConfig config,
    required CallV2RuntimeState state,
    required bool hasAccess,
    required bool isRtcInitialized,
    required bool isRtcJoined,
    required bool isDisposed,
  }) {
    if (config.mode == CallV2RuntimeMode.productionDisabled || isDisposed) {
      return const CallV2DevControlState(
        canStart: false,
        canRequestPermissions: false,
        canRequestAccess: false,
        canInitializeRtc: false,
        canJoinRtc: false,
        canActivate: false,
        canEnd: false,
        blockedReason: CallV2DevControlBlockedReason.productionDisabled,
      );
    }

    final canStart = state.phase == CallV2RuntimePhase.idle ||
        state.phase == CallV2RuntimePhase.ended ||
        state.phase == CallV2RuntimePhase.failed;
    final canRequestPermissions = config.allowPermissionRequests &&
        state.phase == CallV2RuntimePhase.permissionPreflight;
    final canRequestAccess = config.allowTokenRequests &&
        state.phase == CallV2RuntimePhase.connecting &&
        !hasAccess;
    final canInitializeRtc = config.allowRtcInitialization &&
        state.phase == CallV2RuntimePhase.connecting &&
        hasAccess &&
        !isRtcInitialized;
    final canJoinRtc = config.allowRtcJoin &&
        state.phase == CallV2RuntimePhase.connecting &&
        isRtcInitialized &&
        !isRtcJoined;
    final canActivate = state.phase == CallV2RuntimePhase.ready && isRtcJoined;
    final canEnd = state.phase != CallV2RuntimePhase.idle &&
        state.phase != CallV2RuntimePhase.ended &&
        !isDisposed;

    return CallV2DevControlState(
      canStart: canStart,
      canRequestPermissions: canRequestPermissions,
      canRequestAccess: canRequestAccess,
      canInitializeRtc: canInitializeRtc,
      canJoinRtc: canJoinRtc,
      canActivate: canActivate,
      canEnd: canEnd,
      blockedReason: _reasonFor(
        state: state,
        hasAccess: hasAccess,
        isRtcInitialized: isRtcInitialized,
        isRtcJoined: isRtcJoined,
      ),
    );
  }

  final bool canStart;
  final bool canRequestPermissions;
  final bool canRequestAccess;
  final bool canInitializeRtc;
  final bool canJoinRtc;
  final bool canActivate;
  final bool canEnd;
  final CallV2DevControlBlockedReason blockedReason;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'canStart': canStart,
      'canRequestPermissions': canRequestPermissions,
      'canRequestAccess': canRequestAccess,
      'canInitializeRtc': canInitializeRtc,
      'canJoinRtc': canJoinRtc,
      'canActivate': canActivate,
      'canEnd': canEnd,
      'blockedReason': blockedReason.name,
    };
  }

  @override
  String toString() => 'CallV2DevControlState(${toSafeDebugMap()})';
}

CallV2DevControlBlockedReason _reasonFor({
  required CallV2RuntimeState state,
  required bool hasAccess,
  required bool isRtcInitialized,
  required bool isRtcJoined,
}) {
  switch (state.phase) {
    case CallV2RuntimePhase.idle:
    case CallV2RuntimePhase.ended:
    case CallV2RuntimePhase.failed:
      return CallV2DevControlBlockedReason.none;
    case CallV2RuntimePhase.permissionPreflight:
    case CallV2RuntimePhase.requestingPermission:
      return CallV2DevControlBlockedReason.waitingForPermissions;
    case CallV2RuntimePhase.connecting:
      if (!hasAccess) return CallV2DevControlBlockedReason.waitingForAccess;
      if (!isRtcInitialized) {
        return CallV2DevControlBlockedReason.waitingForSetup;
      }
      if (!isRtcJoined) return CallV2DevControlBlockedReason.waitingForJoin;
      return CallV2DevControlBlockedReason.waitingForReady;
    case CallV2RuntimePhase.ready:
      return CallV2DevControlBlockedReason.waitingForReady;
    case CallV2RuntimePhase.active:
    case CallV2RuntimePhase.ending:
    case CallV2RuntimePhase.preparing:
    case CallV2RuntimePhase.ringing:
      return CallV2DevControlBlockedReason.terminal;
  }
}
