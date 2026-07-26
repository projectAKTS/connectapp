import '../integration/call_v2_rollout_policy.dart';

class InternalCallV2RtcAdapterGate {
  const InternalCallV2RtcAdapterGate({
    this.allowAdapterConstruction = false,
    this.allowInitialization = false,
    this.allowJoin = false,
  });

  final bool allowAdapterConstruction;
  final bool allowInitialization;
  final bool allowJoin;

  bool get canConstructAdapter {
    return allowAdapterConstruction && !CallV2RolloutPolicy.productionEnabled;
  }

  bool get canInitialize {
    return canConstructAdapter && allowInitialization;
  }

  bool get canJoin {
    return canInitialize && allowJoin;
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'constructionAllowed': canConstructAdapter,
      'setupAllowed': canInitialize,
      'joinAllowed': canJoin,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
    };
  }
}
