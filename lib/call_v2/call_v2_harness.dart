import 'call_navigation_coordinator_v2.dart';
import 'call_session_manager_v2.dart';
import 'call_v2_api.dart';
import 'call_v2_feature_gate.dart';
import 'domain/call_local_phase.dart';
import 'domain/call_snapshot.dart';
import 'domain/participant_media_state.dart';

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

  Future<void> startCall(CallV2RequestContext context) {
    if (!_featureGate.enabled) return Future<void>.value();
    return _sessionManager.startCall(context);
  }

  Future<void> acceptCall(CallV2RequestContext context) {
    if (!_featureGate.enabled) return Future<void>.value();
    return _sessionManager.acceptCall(context);
  }

  Future<void> declineCall(CallV2RequestContext context) {
    if (!_featureGate.enabled) return Future<void>.value();
    return _sessionManager.declineCall(context);
  }

  Future<void> cancelCall(CallV2RequestContext context) {
    if (!_featureGate.enabled) return Future<void>.value();
    return _sessionManager.cancelCall(context);
  }

  Future<void> endCall(CallV2RequestContext context) {
    if (!_featureGate.enabled) return Future<void>.value();
    return _sessionManager.endCall(context);
  }

  Future<void> reportMedia(
    CallV2RequestContext context, {
    required ParticipantMediaState mediaState,
    required int mediaVersion,
  }) {
    if (!_featureGate.enabled) return Future<void>.value();
    return _sessionManager.reportMedia(
      context,
      mediaState: mediaState,
      mediaVersion: mediaVersion,
    );
  }

  Future<void> renewLease(CallV2RequestContext context) {
    if (!_featureGate.enabled) return Future<void>.value();
    return _sessionManager.renewLease(context);
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
