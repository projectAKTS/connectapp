class CallV2ProductionCapabilities {
  const CallV2ProductionCapabilities({
    required this.callableApiAdapterAvailable,
    required this.firestoreSnapshotSourceAvailable,
    required this.rtcConfigProviderAvailable,
    required this.rtcAdapterAvailable,
    required this.authIdentitySourceAvailable,
    required this.appCheckAvailable,
    required this.permissionGatewayAvailable,
    required this.runtimeStartupBridgeAvailable,
    required this.uiRouteIntegrationAvailable,
    required this.nativeCallIntegrationAvailable,
    required this.observabilityAvailable,
  });

  final bool callableApiAdapterAvailable;
  final bool firestoreSnapshotSourceAvailable;
  final bool rtcConfigProviderAvailable;
  final bool rtcAdapterAvailable;
  final bool authIdentitySourceAvailable;
  final bool appCheckAvailable;
  final bool permissionGatewayAvailable;
  final bool runtimeStartupBridgeAvailable;
  final bool uiRouteIntegrationAvailable;
  final bool nativeCallIntegrationAvailable;
  final bool observabilityAvailable;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'callableApiAdapterAvailable': callableApiAdapterAvailable,
      'firestoreSnapshotSourceAvailable': firestoreSnapshotSourceAvailable,
      'rtcConfigProviderAvailable': rtcConfigProviderAvailable,
      'rtcAdapterAvailable': rtcAdapterAvailable,
      'authIdentitySourceAvailable': authIdentitySourceAvailable,
      'appCheckAvailable': appCheckAvailable,
      'permissionGatewayAvailable': permissionGatewayAvailable,
      'runtimeStartupBridgeAvailable': runtimeStartupBridgeAvailable,
      'uiRouteIntegrationAvailable': uiRouteIntegrationAvailable,
      'nativeCallIntegrationAvailable': nativeCallIntegrationAvailable,
      'observabilityAvailable': observabilityAvailable,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionCapabilities(${toSafeDebugMap()})';
  }
}

const callV2NoProductionCapabilities = CallV2ProductionCapabilities(
  callableApiAdapterAvailable: false,
  firestoreSnapshotSourceAvailable: false,
  rtcConfigProviderAvailable: false,
  rtcAdapterAvailable: false,
  authIdentitySourceAvailable: false,
  appCheckAvailable: false,
  permissionGatewayAvailable: false,
  runtimeStartupBridgeAvailable: false,
  uiRouteIntegrationAvailable: false,
  nativeCallIntegrationAvailable: false,
  observabilityAvailable: false,
);
