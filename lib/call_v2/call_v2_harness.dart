import 'call_navigation_coordinator_v2.dart';
import 'call_session_manager_v2.dart';
import 'call_v2_api.dart';
import 'call_v2_callable_results.dart';
import 'call_v2_feature_gate.dart';
import 'domain/call_local_phase.dart';
import 'domain/call_snapshot.dart';
import 'pending_started_call_v2.dart';

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

  PendingStartedCallV2? get pendingStartedCall =>
      _sessionManager.pendingStartedCall;

  CallLocalPhase get localPhase => _sessionManager.localPhase;

  void injectPublicSnapshot(CallSnapshot snapshot) {
    if (!_featureGate.enabled) return;
    _sessionManager.injectSnapshot(snapshot);
  }

  Future<StartCallV2Result> startCall(StartCallV2Request request) {
    if (!_featureGate.enabled) {
      return Future<StartCallV2Result>.error(
        const CallV2ClientError(CallV2ClientErrorCode.rejected),
      );
    }
    return _sessionManager.startCall(request);
  }

  Future<CallV2LifecycleCommandResult> acceptCall(
    CallV2LifecycleCommandRequest request,
  ) {
    if (!_featureGate.enabled) {
      return Future<CallV2LifecycleCommandResult>.error(
        const CallV2ClientError(CallV2ClientErrorCode.rejected),
      );
    }
    return _sessionManager.acceptCall(request);
  }

  Future<CallV2LifecycleCommandResult> declineCall(
    CallV2LifecycleCommandRequest request,
  ) {
    if (!_featureGate.enabled) {
      return Future<CallV2LifecycleCommandResult>.error(
        const CallV2ClientError(CallV2ClientErrorCode.rejected),
      );
    }
    return _sessionManager.declineCall(request);
  }

  Future<CallV2LifecycleCommandResult> cancelCall(
    CallV2LifecycleCommandRequest request,
  ) {
    if (!_featureGate.enabled) {
      return Future<CallV2LifecycleCommandResult>.error(
        const CallV2ClientError(CallV2ClientErrorCode.rejected),
      );
    }
    return _sessionManager.cancelCall(request);
  }

  Future<CallV2LifecycleCommandResult> endCall(
    CallV2LifecycleCommandRequest request,
  ) {
    if (!_featureGate.enabled) {
      return Future<CallV2LifecycleCommandResult>.error(
        const CallV2ClientError(CallV2ClientErrorCode.rejected),
      );
    }
    return _sessionManager.endCall(request);
  }

  Future<CallV2MediaReportResult> reportMedia(
    CallV2MediaReportRequest request,
  ) {
    if (!_featureGate.enabled) {
      return Future<CallV2MediaReportResult>.error(
        const CallV2ClientError(CallV2ClientErrorCode.rejected),
      );
    }
    return _sessionManager.reportMedia(request);
  }

  Future<CallV2LeaseRenewalResult> renewLease(
      CallV2LeaseRenewalRequest request) {
    if (!_featureGate.enabled) {
      return Future<CallV2LeaseRenewalResult>.error(
        const CallV2ClientError(CallV2ClientErrorCode.rejected),
      );
    }
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
