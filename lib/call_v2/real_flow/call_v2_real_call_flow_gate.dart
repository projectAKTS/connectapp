enum CallV2RealCallConnectionSystem {
  legacyV1,
  callV2Dev,
}

const String callV2DevInviteSystemValue = 'call_v2_dev';

class CallV2RealCallFlowConfig {
  const CallV2RealCallFlowConfig({
    this.enabled = _defaultEnabled,
    this.devCallableEnabled = _defaultDevCallableEnabled,
    this.devAgoraAppId = _defaultDevAgoraAppId,
  });

  static const bool _defaultEnabled = bool.fromEnvironment(
    'CALL_V2_REAL_FLOW_ENABLED',
    defaultValue: false,
  );
  static const bool _defaultDevCallableEnabled = bool.fromEnvironment(
    'CALL_V2_REAL_FLOW_DEV_CALLABLE',
    defaultValue: true,
  );
  static const String _defaultDevAgoraAppId = String.fromEnvironment(
    'CALL_V2_DEV_AGORA_APP_ID',
    defaultValue: '',
  );

  final bool enabled;
  final bool devCallableEnabled;
  final String devAgoraAppId;

  bool get hasDevAgoraAppId => _isAgoraAppId(devAgoraAppId);

  bool get canUseCallV2Dev {
    return enabled && devCallableEnabled && hasDevAgoraAppId;
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'callV2Selected': canUseCallV2Dev,
      'devCallableSelected': enabled && devCallableEnabled,
      'configurationReady': hasDevAgoraAppId,
      'fallbackUsed': enabled && !canUseCallV2Dev,
      'blockerCode': _blockerCode,
    };
  }

  String get _blockerCode {
    if (!enabled) return 'disabled';
    if (!devCallableEnabled) return 'dev_callable_disabled';
    if (!hasDevAgoraAppId) return 'missing_dev_application';
    return 'none';
  }

  @override
  String toString() => 'CallV2RealCallFlowConfig(${toSafeDebugMap()})';
}

class CallV2RealCallFlowDecision {
  const CallV2RealCallFlowDecision({
    required this.connectionSystem,
    required this.devCallableSelected,
    required this.fallbackUsed,
    required this.blockerCode,
  });

  const CallV2RealCallFlowDecision.legacy({
    bool fallbackUsed = false,
    String blockerCode = 'disabled',
  }) : this(
          connectionSystem: CallV2RealCallConnectionSystem.legacyV1,
          devCallableSelected: false,
          fallbackUsed: fallbackUsed,
          blockerCode: blockerCode,
        );

  const CallV2RealCallFlowDecision.callV2Dev()
      : this(
          connectionSystem: CallV2RealCallConnectionSystem.callV2Dev,
          devCallableSelected: true,
          fallbackUsed: false,
          blockerCode: 'none',
        );

  final CallV2RealCallConnectionSystem connectionSystem;
  final bool devCallableSelected;
  final bool fallbackUsed;
  final String blockerCode;

  bool get callV2Selected {
    return connectionSystem == CallV2RealCallConnectionSystem.callV2Dev;
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'callV2Selected': callV2Selected,
      'devCallableSelected': devCallableSelected,
      'fallbackUsed': fallbackUsed,
      'blockerCode': blockerCode,
    };
  }

  @override
  String toString() => 'CallV2RealCallFlowDecision(${toSafeDebugMap()})';
}

class CallV2RealCallFlowGate {
  const CallV2RealCallFlowGate({
    this.config = const CallV2RealCallFlowConfig(),
  });

  final CallV2RealCallFlowConfig config;

  CallV2RealCallFlowDecision selectForUserStartedCall({
    required bool isVideo,
  }) {
    if (config.canUseCallV2Dev) {
      return const CallV2RealCallFlowDecision.callV2Dev();
    }
    return CallV2RealCallFlowDecision.legacy(
      fallbackUsed: config.enabled,
      blockerCode: config.toSafeDebugMap()['blockerCode']! as String,
    );
  }

  Map<String, Object?> toSafeDebugMap() => config.toSafeDebugMap();
}

CallV2RealCallConnectionSystem callConnectionSystemFromInviteValue(
  Object? value,
) {
  return value == callV2DevInviteSystemValue
      ? CallV2RealCallConnectionSystem.callV2Dev
      : CallV2RealCallConnectionSystem.legacyV1;
}

String? callConnectionSystemToInviteValue(
  CallV2RealCallConnectionSystem value,
) {
  switch (value) {
    case CallV2RealCallConnectionSystem.legacyV1:
      return null;
    case CallV2RealCallConnectionSystem.callV2Dev:
      return callV2DevInviteSystemValue;
  }
}

bool _isAgoraAppId(String value) {
  return RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(value.trim());
}
