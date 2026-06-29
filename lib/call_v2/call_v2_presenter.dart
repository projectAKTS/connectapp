import 'call_navigation_coordinator_v2.dart';
import 'call_v2_api.dart';
import 'call_v2_harness.dart';
import 'domain/call_lifecycle.dart';
import 'domain/call_local_phase.dart';
import 'domain/call_snapshot.dart';
import 'domain/participant_media_state.dart';

class CallV2PresentationState {
  const CallV2PresentationState({
    required this.localPhase,
    required this.titleKey,
    required this.statusKey,
    required this.acceptEnabled,
    required this.declineEnabled,
    required this.cancelEnabled,
    required this.endEnabled,
    required this.reportMediaEnabled,
    required this.openNavigationIntentPending,
    required this.closeNavigationIntentPending,
  });

  final CallLocalPhase localPhase;
  final String titleKey;
  final String statusKey;
  final bool acceptEnabled;
  final bool declineEnabled;
  final bool cancelEnabled;
  final bool endEnabled;
  final bool reportMediaEnabled;
  final bool openNavigationIntentPending;
  final bool closeNavigationIntentPending;

  static const idle = CallV2PresentationState(
    localPhase: CallLocalPhase.idle,
    titleKey: 'call_v2.title.idle',
    statusKey: 'call_v2.status.idle',
    acceptEnabled: false,
    declineEnabled: false,
    cancelEnabled: false,
    endEnabled: false,
    reportMediaEnabled: false,
    openNavigationIntentPending: false,
    closeNavigationIntentPending: false,
  );
}

class CallV2Presenter {
  CallV2Presenter({required CallV2Harness harness}) : _harness = harness {
    _refreshPresentationState();
  }

  final CallV2Harness _harness;
  CallNavigationIntent? _pendingOpenNavigationIntent;
  CallNavigationIntent? _pendingCloseNavigationIntent;
  CallV2PresentationState _state = CallV2PresentationState.idle;

  CallV2PresentationState get state {
    _refreshPresentationState();
    return _state;
  }

  void injectPublicSnapshot(CallSnapshot snapshot) {
    final before = _harness.snapshot;
    _harness.injectPublicSnapshot(snapshot);
    final accepted = _harness.snapshot;
    if (!_sameAcceptedSnapshot(before, accepted)) {
      _captureNavigationIntent(accepted);
    }
    _refreshPresentationState();
  }

  Future<void> acceptCall() {
    final context = _contextForAllowedAction((state) => state.acceptEnabled);
    if (context == null) return Future<void>.value();
    return _harness.acceptCall(context);
  }

  Future<void> declineCall() {
    final context = _contextForAllowedAction((state) => state.declineEnabled);
    if (context == null) return Future<void>.value();
    return _harness.declineCall(context);
  }

  Future<void> cancelCall() {
    final context = _contextForAllowedAction((state) => state.cancelEnabled);
    if (context == null) return Future<void>.value();
    return _harness.cancelCall(context);
  }

  Future<void> endCall() {
    final context = _contextForAllowedAction((state) => state.endEnabled);
    if (context == null) return Future<void>.value();
    return _harness.endCall(context);
  }

  Future<void> reportMedia({
    required ParticipantMediaState mediaState,
    required int mediaVersion,
  }) {
    final context =
        _contextForAllowedAction((state) => state.reportMediaEnabled);
    if (context == null) return Future<void>.value();
    return _harness.reportMedia(
      context,
      mediaState: mediaState,
      mediaVersion: mediaVersion,
    );
  }

  CallNavigationIntent? takeOpenNavigationIntent() {
    final intent = _pendingOpenNavigationIntent;
    if (intent == null) return null;
    _pendingOpenNavigationIntent = null;
    _refreshPresentationState();
    return intent;
  }

  CallNavigationIntent? takeCloseNavigationIntent() {
    final intent = _pendingCloseNavigationIntent;
    if (intent == null) return null;
    _pendingCloseNavigationIntent = null;
    _refreshPresentationState();
    return intent;
  }

  Future<void> cleanupIfTerminal() async {
    await _harness.cleanupIfTerminal();
    if (_harness.snapshot == null) {
      _pendingOpenNavigationIntent = null;
      _pendingCloseNavigationIntent = null;
    }
    _refreshPresentationState();
  }

  CallV2RequestContext? _contextForAllowedAction(
    bool Function(CallV2PresentationState state) isAllowed,
  ) {
    final currentState = state;
    final snapshot = _harness.snapshot;
    if (snapshot == null || !isAllowed(currentState)) return null;
    return CallV2RequestContext(
      callId: snapshot.callId,
      version: snapshot.version,
    );
  }

  void _captureNavigationIntent(CallSnapshot? snapshot) {
    if (snapshot == null) return;
    if (snapshot.lifecycle.isTerminal) {
      _pendingOpenNavigationIntent = null;
      _pendingCloseNavigationIntent =
          _harness.closeNavigationIntentFor(snapshot);
      return;
    }
    if (_opensRoute(snapshot)) {
      _pendingOpenNavigationIntent = _harness.openNavigationIntentFor(snapshot);
    }
  }

  void _refreshPresentationState() {
    final snapshot = _harness.snapshot;
    if (snapshot == null) {
      _state = CallV2PresentationState(
        localPhase: CallLocalPhase.idle,
        titleKey: CallV2PresentationState.idle.titleKey,
        statusKey: CallV2PresentationState.idle.statusKey,
        acceptEnabled: false,
        declineEnabled: false,
        cancelEnabled: false,
        endEnabled: false,
        reportMediaEnabled: false,
        openNavigationIntentPending: _pendingOpenNavigationIntent != null,
        closeNavigationIntentPending: _pendingCloseNavigationIntent != null,
      );
      return;
    }

    final localPhase = _harness.localPhase;
    final terminal = snapshot.lifecycle.isTerminal;
    final calleeRinging = snapshot.lifecycle == CallLifecycle.ringing &&
        localPhase == CallLocalPhase.presentingIncoming;
    final callerRinging = snapshot.lifecycle == CallLifecycle.ringing &&
        localPhase == CallLocalPhase.outgoingRinging;
    final connected = snapshot.lifecycle == CallLifecycle.accepted ||
        snapshot.lifecycle == CallLifecycle.active;

    _state = CallV2PresentationState(
      localPhase: localPhase,
      titleKey: _titleKeyFor(snapshot.lifecycle, localPhase),
      statusKey: _statusKeyFor(snapshot.lifecycle, localPhase),
      acceptEnabled: calleeRinging && !terminal,
      declineEnabled: calleeRinging && !terminal,
      cancelEnabled: callerRinging && !terminal,
      endEnabled: connected && !terminal,
      reportMediaEnabled: connected && !terminal,
      openNavigationIntentPending: _pendingOpenNavigationIntent != null,
      closeNavigationIntentPending: _pendingCloseNavigationIntent != null,
    );
  }

  bool _opensRoute(CallSnapshot snapshot) {
    final localPhase = _harness.localPhase;
    return snapshot.lifecycle.isNonTerminal &&
        (localPhase == CallLocalPhase.openingCallRoute ||
            localPhase == CallLocalPhase.inCall);
  }

  String _titleKeyFor(CallLifecycle lifecycle, CallLocalPhase localPhase) {
    switch (lifecycle) {
      case CallLifecycle.ringing:
        return localPhase == CallLocalPhase.outgoingRinging
            ? 'call_v2.title.outgoing'
            : 'call_v2.title.incoming';
      case CallLifecycle.accepted:
      case CallLifecycle.active:
        return 'call_v2.title.connected';
      case CallLifecycle.completed:
      case CallLifecycle.declined:
      case CallLifecycle.cancelled:
      case CallLifecycle.missed:
      case CallLifecycle.failed:
        return 'call_v2.title.ended';
    }
  }

  String _statusKeyFor(CallLifecycle lifecycle, CallLocalPhase localPhase) {
    switch (lifecycle) {
      case CallLifecycle.ringing:
        return localPhase == CallLocalPhase.outgoingRinging
            ? 'call_v2.status.outgoing_ringing'
            : 'call_v2.status.incoming_ringing';
      case CallLifecycle.accepted:
        return 'call_v2.status.accepted';
      case CallLifecycle.active:
        return 'call_v2.status.active';
      case CallLifecycle.completed:
        return 'call_v2.status.completed';
      case CallLifecycle.declined:
        return 'call_v2.status.declined';
      case CallLifecycle.cancelled:
        return 'call_v2.status.cancelled';
      case CallLifecycle.missed:
        return 'call_v2.status.missed';
      case CallLifecycle.failed:
        return 'call_v2.status.failed';
    }
  }

  bool _sameAcceptedSnapshot(CallSnapshot? before, CallSnapshot? after) {
    if (before == null || after == null) return before == after;
    return before.callId == after.callId &&
        before.version == after.version &&
        before.lifecycle == after.lifecycle;
  }
}
