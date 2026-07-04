import '../call_v2_api.dart';

enum CallV2ProductionIntegrationLifecycle {
  uninitialized,
  disabled,
  initialized,
  starting,
  running,
  stopping,
  stopped,
  failed,
  disposed,
}

class CallV2ProductionIntegrationStatus {
  const CallV2ProductionIntegrationStatus({
    required this.lifecycle,
    required this.rolloutEnabled,
    required this.compositionConstructed,
    required this.runtimeStarted,
    required this.routesRegistered,
    required this.screensAvailable,
    this.errorCode,
  });

  static const uninitialized = CallV2ProductionIntegrationStatus(
    lifecycle: CallV2ProductionIntegrationLifecycle.uninitialized,
    rolloutEnabled: false,
    compositionConstructed: false,
    runtimeStarted: false,
    routesRegistered: false,
    screensAvailable: false,
  );

  final CallV2ProductionIntegrationLifecycle lifecycle;
  final CallV2ClientErrorCode? errorCode;
  final bool rolloutEnabled;
  final bool compositionConstructed;
  final bool runtimeStarted;
  final bool routesRegistered;
  final bool screensAvailable;

  CallV2ProductionIntegrationStatus copyWith({
    CallV2ProductionIntegrationLifecycle? lifecycle,
    CallV2ClientErrorCode? errorCode,
    bool? rolloutEnabled,
    bool? compositionConstructed,
    bool? runtimeStarted,
    bool? routesRegistered,
    bool? screensAvailable,
    bool clearError = false,
  }) {
    return CallV2ProductionIntegrationStatus(
      lifecycle: lifecycle ?? this.lifecycle,
      errorCode: clearError ? null : errorCode ?? this.errorCode,
      rolloutEnabled: rolloutEnabled ?? this.rolloutEnabled,
      compositionConstructed:
          compositionConstructed ?? this.compositionConstructed,
      runtimeStarted: runtimeStarted ?? this.runtimeStarted,
      routesRegistered: routesRegistered ?? this.routesRegistered,
      screensAvailable: screensAvailable ?? this.screensAvailable,
    );
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'lifecycle': lifecycle.name,
      if (errorCode != null) 'errorCode': errorCode!.name,
      'rolloutEnabled': rolloutEnabled,
      'compositionConstructed': compositionConstructed,
      'runtimeStarted': runtimeStarted,
      'routesRegistered': routesRegistered,
      'screensAvailable': screensAvailable,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionIntegrationStatus(${toSafeDebugMap()})';
  }
}
