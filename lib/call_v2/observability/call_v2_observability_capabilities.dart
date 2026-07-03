import '../call_v2_production_capabilities.dart';

const callV2IsolatedObservabilityCapabilities = CallV2ProductionCapabilities(
  callableApiAdapterAvailable: true,
  firestoreSnapshotSourceAvailable: true,
  rtcConfigProviderAvailable: true,
  rtcAdapterAvailable: true,
  authIdentitySourceAvailable: true,
  appCheckAvailable: true,
  permissionGatewayAvailable: true,
  runtimeStartupBridgeAvailable: true,
  uiRouteIntegrationAvailable: true,
  nativeCallIntegrationAvailable: false,
  observabilityAvailable: true,
);
