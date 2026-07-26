import '../integration/call_v2_rollout_policy.dart';
import 'call_v2_runtime_mode.dart';

class CallV2RuntimeConfig {
  const CallV2RuntimeConfig({
    required this.mode,
    required this.allowPermissionRequests,
    required this.allowTokenRequests,
    required this.allowRtcInitialization,
    required this.allowRtcJoin,
    required this.exposeDevUi,
  });

  const CallV2RuntimeConfig.fake()
      : mode = CallV2RuntimeMode.fake,
        allowPermissionRequests = true,
        allowTokenRequests = true,
        allowRtcInitialization = true,
        allowRtcJoin = true,
        exposeDevUi = true;

  const CallV2RuntimeConfig.internalRealDevice({
    this.allowPermissionRequests = false,
    this.allowTokenRequests = false,
    this.allowRtcInitialization = false,
    this.allowRtcJoin = false,
    this.exposeDevUi = false,
  }) : mode = CallV2RuntimeMode.internalRealDevice;

  const CallV2RuntimeConfig.productionDisabled()
      : mode = CallV2RuntimeMode.productionDisabled,
        allowPermissionRequests = false,
        allowTokenRequests = false,
        allowRtcInitialization = false,
        allowRtcJoin = false,
        exposeDevUi = false;

  static const CallV2RuntimeConfig defaultDevelopment =
      CallV2RuntimeConfig.fake();

  static const CallV2RuntimeConfig defaultProduction =
      CallV2RuntimeConfig.productionDisabled();

  final CallV2RuntimeMode mode;
  final bool allowPermissionRequests;
  final bool allowTokenRequests;
  final bool allowRtcInitialization;
  final bool allowRtcJoin;
  final bool exposeDevUi;

  bool get productionRolloutEnabled => CallV2RolloutPolicy.productionEnabled;

  bool get canUseInternalRealDevice {
    return mode == CallV2RuntimeMode.internalRealDevice &&
        !productionRolloutEnabled;
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'mode': _safeModeName,
      'permissionStepAllowed': allowPermissionRequests,
      'accessStepAllowed': allowTokenRequests,
      'setupStepAllowed': allowRtcInitialization,
      'joinStepAllowed': allowRtcJoin,
      'devUiExposed': exposeDevUi,
      'rolloutEnabled': productionRolloutEnabled,
    };
  }

  @override
  String toString() => 'CallV2RuntimeConfig(${toSafeDebugMap()})';

  String get _safeModeName {
    switch (mode) {
      case CallV2RuntimeMode.fake:
        return 'fake';
      case CallV2RuntimeMode.internalRealDevice:
        return 'internal';
      case CallV2RuntimeMode.productionDisabled:
        return 'disabled';
    }
  }
}
