import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app_check/call_v2_app_check_boundary.dart';
import '../call_v2_api.dart';
import '../call_v2_contract_manifest.dart';
import '../call_v2_feature_gate.dart';
import '../call_v2_media_orchestrator.dart';
import '../call_v2_media_session_controller.dart';
import '../call_v2_production_capabilities.dart';
import '../call_v2_production_readiness.dart';
import '../call_v2_runtime.dart';
import '../call_v2_runtime_configuration.dart';
import '../call_v2_runtime_configuration_validator.dart';
import '../domain/call_snapshot.dart';
import '../firebase/call_v2_app_check_transport.dart';
import '../firebase/call_v2_callable_transport.dart';
import '../firebase/call_v2_document_snapshot_transport.dart';
import '../firebase/firebase_call_v2_app_check_boundary.dart';
import '../firebase/firebase_call_v2_auth_identity_provider.dart';
import '../firebase/firebase_call_v2_rtc_credential_provider.dart';
import '../firebase/firebase_call_v2_snapshot_source.dart';
import '../firebase/firebase_callable_call_v2_api.dart';
import '../firebase/firebase_firestore_call_v2_snapshot_transport.dart';
import '../firebase/firebase_functions_call_v2_transport.dart';
import '../identity/call_v2_auth_identity_provider.dart';
import '../permissions/call_v2_media_permission_gateway.dart';
import '../permissions/production/call_v2_permission_transport.dart';
import '../permissions/production/production_call_v2_media_permission_gateway.dart';
import '../rtc/call_v2_rtc_config_provider.dart';
import '../rtc/production/call_v2_rtc_engine_transport.dart';
import '../rtc/production/production_call_v2_rtc_adapter.dart';

class CallV2ProductionComposition {
  CallV2ProductionComposition({
    required this.configuration,
    required this.featureGate,
    required this.runtime,
    required this.api,
    required this.snapshotSource,
    required this.rtcCredentialProvider,
    required this.rtcAdapter,
    required this.authIdentityProvider,
    required this.appCheckBoundary,
    required this.permissionGateway,
    required this.capabilities,
  });

  final CallV2RuntimeConfiguration configuration;
  final CallV2FeatureGate featureGate;
  final CallV2Runtime runtime;
  final CallableCallV2Api api;
  final FirebaseCallV2SnapshotSource snapshotSource;
  final CallV2RtcConfigProvider rtcCredentialProvider;
  final ProductionCallV2RtcAdapter rtcAdapter;
  final CallV2AuthIdentityProvider authIdentityProvider;
  final CallV2AppCheckBoundary appCheckBoundary;
  final CallV2MediaPermissionGateway permissionGateway;
  final CallV2ProductionCapabilities capabilities;

  Future<void>? _disposeFuture;
  bool _disposed = false;

  CallV2ProductionReadinessResult auditReadiness({
    CallV2ProductionReadinessAuditor auditor =
        const CallV2ProductionReadinessAuditor(),
    CallV2ContractManifest manifest = callV2Phase3ContractManifest,
  }) {
    return auditor.audit(
      manifest: manifest,
      configuration: configuration,
      capabilities: capabilities,
    );
  }

  Future<void> dispose() {
    final inFlight = _disposeFuture;
    if (inFlight != null) return inFlight;
    if (_disposed) return Future<void>.value();
    final future = _dispose();
    _disposeFuture = future;
    return future;
  }

  Future<void> _dispose() async {
    CallV2ClientErrorCode? errorCode;
    try {
      await runtime.stop();
    } on CallV2ClientError catch (error) {
      errorCode ??= error.code;
    } catch (_) {
      errorCode ??= CallV2ClientErrorCode.unavailable;
    }

    try {
      await rtcAdapter.dispose();
    } on CallV2ClientError catch (error) {
      errorCode ??= error.code;
    } catch (_) {
      errorCode ??= CallV2ClientErrorCode.unavailable;
    } finally {
      _disposed = true;
      _disposeFuture = null;
    }

    if (errorCode != null) {
      throw CallV2ClientError(errorCode);
    }
  }
}

class CallV2ProductionCompositionFactory {
  const CallV2ProductionCompositionFactory({
    this.configurationValidator = const CallV2RuntimeConfigurationValidator(),
  });

  final CallV2RuntimeConfigurationValidator configurationValidator;

  CallV2ProductionComposition create({
    required CallV2RuntimeConfiguration configuration,
    required FirebaseFunctions functions,
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required FirebaseAppCheck appCheck,
    required CallV2RtcEngineTransport rtcTransport,
    required CallV2PermissionTransport permissionTransport,
    required String Function() localParticipantUid,
    required CallParticipantRole Function() localParticipantRole,
    required CallV2MediaReportKeyFactory mediaReportKeyFactory,
    required String Function(
      String callId,
      CallV2MediaOrchestrationKeyPurpose purpose,
    ) orchestrationKeyFactory,
  }) {
    return createWithTransports(
      configuration: configuration,
      callableTransport: FirebaseFunctionsCallV2Transport(
        functions: functions,
      ),
      snapshotTransport: FirebaseFirestoreCallV2SnapshotTransport(
        firestore: firestore,
      ),
      auth: auth,
      appCheckTransport: FirebaseCallV2AppCheckTransport(appCheck: appCheck),
      rtcTransport: rtcTransport,
      permissionTransport: permissionTransport,
      localParticipantUid: localParticipantUid,
      localParticipantRole: localParticipantRole,
      mediaReportKeyFactory: mediaReportKeyFactory,
      orchestrationKeyFactory: orchestrationKeyFactory,
    );
  }

  CallV2ProductionComposition createWithTransports({
    required CallV2RuntimeConfiguration configuration,
    required CallV2CallableTransport callableTransport,
    required CallV2DocumentSnapshotTransport snapshotTransport,
    required FirebaseAuth auth,
    required CallV2AppCheckTransport appCheckTransport,
    required CallV2RtcEngineTransport rtcTransport,
    required CallV2PermissionTransport permissionTransport,
    required String Function() localParticipantUid,
    required CallParticipantRole Function() localParticipantRole,
    required CallV2MediaReportKeyFactory mediaReportKeyFactory,
    required String Function(
      String callId,
      CallV2MediaOrchestrationKeyPurpose purpose,
    ) orchestrationKeyFactory,
  }) {
    final validation = configurationValidator.validate(configuration);
    if (!validation.isValid) {
      throw const CallV2ClientError(CallV2ClientErrorCode.invalidRequest);
    }

    final featureGate = CallV2FeatureGate(enabled: configuration.enabled);
    final api = FirebaseCallableCallV2Api(
      featureGate: featureGate,
      transport: callableTransport,
    );
    final snapshotSource = FirebaseCallV2SnapshotSource(
      featureGate: featureGate,
      transport: snapshotTransport,
      callCollectionName: configuration.callCollectionName,
      participantSubcollectionName: configuration.participantSubcollectionName,
    );
    final rtcCredentialProvider = FirebaseCallV2RtcCredentialProvider(
      featureGate: featureGate,
      transport: callableTransport,
    );
    final rtcAdapter = ProductionCallV2RtcAdapter(
      featureGate: featureGate,
      transport: rtcTransport,
    );
    final authIdentityProvider = FirebaseCallV2AuthIdentityProvider(
      featureGate: featureGate,
      auth: auth,
    );
    final appCheckBoundary = FirebaseCallV2AppCheckBoundary(
      featureGate: featureGate,
      transport: appCheckTransport,
    );
    final permissionGateway = ProductionCallV2MediaPermissionGateway(
      featureGate: featureGate,
      transport: permissionTransport,
    );
    final runtime = createCallV2Runtime(
      featureGate: featureGate,
      api: api,
      callDocumentStream: snapshotSource.callDocumentStream,
      participantDocumentStream: snapshotSource.participantDocumentStream,
      rtcConfigProvider: rtcCredentialProvider,
      rtcAdapter: rtcAdapter,
      localParticipantUid: localParticipantUid,
      localParticipantRole: localParticipantRole,
      mediaReportKeyFactory: mediaReportKeyFactory,
      orchestrationKeyFactory: orchestrationKeyFactory,
    );

    return CallV2ProductionComposition(
      configuration: configuration,
      featureGate: featureGate,
      runtime: runtime,
      api: api,
      snapshotSource: snapshotSource,
      rtcCredentialProvider: rtcCredentialProvider,
      rtcAdapter: rtcAdapter,
      authIdentityProvider: authIdentityProvider,
      appCheckBoundary: appCheckBoundary,
      permissionGateway: permissionGateway,
      capabilities: callV2IsolatedProductionCompositionCapabilities,
    );
  }
}

const callV2IsolatedProductionCompositionCapabilities =
    CallV2ProductionCapabilities(
  callableApiAdapterAvailable: true,
  firestoreSnapshotSourceAvailable: true,
  rtcConfigProviderAvailable: true,
  rtcAdapterAvailable: true,
  authIdentitySourceAvailable: true,
  appCheckAvailable: true,
  permissionGatewayAvailable: true,
  runtimeStartupBridgeAvailable: false,
  uiRouteIntegrationAvailable: false,
  nativeCallIntegrationAvailable: false,
  observabilityAvailable: false,
);
