import 'call_navigation_coordinator_v2.dart';
import 'call_session_manager_v2.dart';
import 'call_v2_api.dart';
import 'call_v2_feature_gate.dart';
import 'domain/call_local_phase.dart';
import 'domain/call_snapshot.dart';

class CallV2Harness {
  CallV2Harness({
    required CallV2FeatureGate featureGate,
    required CallV2Api api,
    required CallParticipantRole Function() localParticipantRole,
  })  : _featureGate = featureGate,
        _sessionManager = CallSessionManagerV2(
          featureGate: featureGate,
          api: api,
          localParticipantRole: localParticipantRole,
        ),
        _navigationCoordinator = CallNavigationCoordinatorV2();

  final CallV2FeatureGate _featureGate;
  final CallSessionManagerV2 _sessionManager;
  final CallNavigationCoordinatorV2 _navigationCoordinator;

  CallSnapshot? get snapshot => _sessionManager.snapshot;

  CallLocalPhase get localPhase => _sessionManager.localPhase;

  void injectPublicSnapshot(CallSnapshot snapshot) {
    if (!_featureGate.enabled) return;
    _sessionManager.injectSnapshot(snapshot);
  }

  Future<void> startCall(StartCallV2Request request) {
    if (!_featureGate.enabled) return Future<void>.value();
    return _sessionManager.startCall(request);
  }

  Future<void> acceptCall(CallV2LifecycleCommandRequest request) {
    if (!_featureGate.enabled) return Future<void>.value();
    return _sessionManager.acceptCall(request);
  }

  Future<void> declineCall(CallV2LifecycleCommandRequest request) {
    if (!_featureGate.enabled) return Future<void>.value();
    return _sessionManager.declineCall(request);
  }

  Future<void> cancelCall(CallV2LifecycleCommandRequest request) {
    if (!_featureGate.enabled) return Future<void>.value();
    return _sessionManager.cancelCall(request);
  }

  Future<void> endCall(CallV2LifecycleCommandRequest request) {
    if (!_featureGate.enabled) return Future<void>.value();
    return _sessionManager.endCall(request);
  }

  Future<void> reportMedia(CallV2MediaReportRequest request) {
    if (!_featureGate.enabled) return Future<void>.value();
    return _sessionManager.reportMedia(request);
  }

  Future<void> renewLease(CallV2LeaseRenewalRequest request) {
    if (!_featureGate.enabled) return Future<void>.value();
    return _sessionManager.renewLease(request);
  }

  CallNavigationIntent? openNavigationIntentFor(CallSnapshot snapshot) {
    if (!_featureGate.enabled) return null;
    return _navigationCoordinator.openIntentFor(snapshot);
  }

  CallNavigationIntent? closeNavigationIntentFor(CallSnapshot snapshot) {
    if (!_featureGate.enabled) return null;
    return _navigationCoordinator.closeIntentFor(snapshot);
  }

  Future<void> cleanupIfTerminal() {
    if (!_featureGate.enabled) return Future<void>.value();
    return _sessionManager.cleanupIfTerminal();
  }
}
