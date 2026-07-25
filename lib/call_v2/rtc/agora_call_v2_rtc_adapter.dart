import '../call_v2_feature_gate.dart';

class AgoraCallV2RtcAdapterGate {
  const AgoraCallV2RtcAdapterGate({
    required this.featureGate,
  });

  final CallV2FeatureGate featureGate;

  bool get allowsConstruction => false;

  bool get productionJoinDisabled => true;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'allowsConstruction': allowsConstruction,
      'productionJoinDisabled': productionJoinDisabled,
      'featureGateEnabled': featureGate.enabled,
    };
  }
}
