import 'call_v2_production_permission_device_bridge_event.dart';
import 'call_v2_production_permission_device_bridge_result.dart';

enum CallV2ProductionPermissionDeviceBridgeLifecycle {
  uninitialized,
  initialized,
  disabled,
  delegated,
  closed,
  noOp,
  rejected,
  disposed,
  terminal,
}

final class CallV2ProductionPermissionDeviceBridgeStatus {
  const CallV2ProductionPermissionDeviceBridgeStatus({
    this.lifecycle =
        CallV2ProductionPermissionDeviceBridgeLifecycle.uninitialized,
    this.currentGeneration,
    this.disposed = false,
    this.terminal = false,
    this.rolloutEnabled = false,
    this.lastEvent,
    this.lastRecoveryPolicy,
    this.lastError,
  });

  final CallV2ProductionPermissionDeviceBridgeLifecycle lifecycle;
  final int? currentGeneration;
  final bool disposed;
  final bool terminal;
  final bool rolloutEnabled;
  final CallV2ProductionPermissionDeviceBridgeEventType? lastEvent;
  final CallV2ProductionPermissionDeviceRecoveryPolicy? lastRecoveryPolicy;
  final CallV2ProductionPermissionDeviceBridgeError? lastError;

  CallV2ProductionPermissionDeviceBridgeStatus copyWith({
    CallV2ProductionPermissionDeviceBridgeLifecycle? lifecycle,
    int? currentGeneration,
    bool clearGeneration = false,
    bool? disposed,
    bool? terminal,
    bool? rolloutEnabled,
    CallV2ProductionPermissionDeviceBridgeEventType? lastEvent,
    CallV2ProductionPermissionDeviceRecoveryPolicy? lastRecoveryPolicy,
    CallV2ProductionPermissionDeviceBridgeError? lastError,
    bool clearLastError = false,
  }) {
    return CallV2ProductionPermissionDeviceBridgeStatus(
      lifecycle: lifecycle ?? this.lifecycle,
      currentGeneration:
          clearGeneration ? null : currentGeneration ?? this.currentGeneration,
      disposed: disposed ?? this.disposed,
      terminal: terminal ?? this.terminal,
      rolloutEnabled: rolloutEnabled ?? this.rolloutEnabled,
      lastEvent: lastEvent ?? this.lastEvent,
      lastRecoveryPolicy: lastRecoveryPolicy ?? this.lastRecoveryPolicy,
      lastError: clearLastError ? null : lastError ?? this.lastError,
    );
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'lifecycle': lifecycle.name,
      'currentGeneration': currentGeneration,
      'disposed': disposed,
      'terminal': terminal,
      'rolloutEnabled': rolloutEnabled,
      'lastEvent': lastEvent?.name,
      'lastRecoveryPolicy': lastRecoveryPolicy?.name,
      'lastError': lastError?.name,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionPermissionDeviceBridgeStatus(${toSafeDebugMap()})';
  }
}
