import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../call_v2/diagnostics/call_v2_physical_diagnostic_ledger.dart';
import '../call_v2/real_flow/call_v2_call_lifecycle_arbiter.dart';
import '../call_v2/real_flow/call_v2_incoming_listener_backoff.dart';
import '../call_v2/real_flow/call_v2_real_call_flow_gate.dart';
import '../screens/call/agora_call_screen.dart';
import '../screens/call/incoming_call_screen.dart';
import 'callkit_id.dart';
import 'diagnostic_service.dart';
import 'firestore_read_helper.dart';
import 'helperly_test_runtime.dart';

const Duration _callInviteHandledTtl = Duration(minutes: 2);
const Duration _ringingTimeout = Duration(seconds: 45);
const Duration _acceptedJoiningTimeout = Duration(seconds: 35);
const Duration _acceptedNativeRouteWatchTimeout = Duration(seconds: 20);
const Duration _defaultAcceptedNativeEndVerificationDelay =
    Duration(milliseconds: 150);
const Duration _iosCallkitFallbackGrace = Duration(milliseconds: 900);
const bool _enableIosCallKit =
    bool.fromEnvironment('ENABLE_IOS_CALLKIT', defaultValue: true);

enum CallInviteStatus {
  ringing,
  accepted,
  joining,
  connected,
  declined,
  missed,
  cancelled,
  ended,
  failed,
  unknown,
}

enum CallSessionPhase {
  idle,
  incomingPrompt,
  outgoingRinging,
  accepted,
  joining,
  connected,
  terminal,
}

enum _AcceptInviteDecision {
  accepted,
  alreadyAccepted,
  missing,
  wrongRecipient,
  terminal,
  invalidStatus,
  invalidPayload,
  unavailable,
  superseded,
}

enum IncomingUiOwner {
  none,
  callkit,
  flutter,
}

enum AcceptedCallRecoveryResult {
  opened,
  alreadyOpen,
  pendingTeardown,
  pendingAuth,
  pendingNavigator,
  pendingNetwork,
  busy,
  terminal,
  invalid,
  failed,
}

enum _RouteOpenResult {
  opened,
  alreadyOpenSameInvite,
  navigatorUnavailable,
  routeBusy,
  failed,
}

enum _IncomingCandidateResult {
  opened,
  alreadyOpen,
  acceptedPending,
  pending,
  callkitOwned,
  flutterPrompted,
  busy,
  networkPending,
  terminal,
  ignored,
  failed,
}

class _AcceptInviteTransactionResult {
  const _AcceptInviteTransactionResult({
    required this.decision,
    this.authoritativePayload,
    this.authoritativeStatus = CallInviteStatus.unknown,
  });

  final _AcceptInviteDecision decision;
  final CallInvitePayload? authoritativePayload;
  final CallInviteStatus authoritativeStatus;

  bool get accepted =>
      decision == _AcceptInviteDecision.accepted ||
      decision == _AcceptInviteDecision.alreadyAccepted;
}

bool _matchesAcceptedCallIdentity({
  required String firstInviteId,
  required String firstCallkitId,
  required String secondInviteId,
  required String secondCallkitId,
}) {
  final firstExactId = firstCallkitId.trim().toLowerCase();
  final secondExactId = secondCallkitId.trim().toLowerCase();
  if (firstExactId.isNotEmpty && secondExactId.isNotEmpty) {
    return firstExactId == secondExactId;
  }
  final firstFallbackId = firstInviteId.trim();
  return firstFallbackId.isNotEmpty && firstFallbackId == secondInviteId.trim();
}

class CallTerminalSignal {
  const CallTerminalSignal({
    required this.inviteId,
    required this.status,
    required this.message,
    this.isError = false,
  });

  final String inviteId;
  final String status;
  final String message;
  final bool isError;
}

class CallInvitePayload {
  const CallInvitePayload({
    required this.inviteId,
    required this.channel,
    required this.isVideo,
    required this.fromName,
    required this.fromUid,
    required this.toUid,
    this.acceptedCallkitId = '',
    this.connectionSystem = CallV2RealCallConnectionSystem.legacyV1,
  });

  final String inviteId;
  final String channel;
  final bool isVideo;
  final String fromName;
  final String fromUid;
  final String toUid;
  final String acceptedCallkitId;
  final CallV2RealCallConnectionSystem connectionSystem;

  CallInvitePayload withAcceptedCallkitId(String callkitId) {
    final exactId = callkitId.trim();
    if (exactId.isEmpty || exactId == acceptedCallkitId) return this;
    return CallInvitePayload(
      inviteId: inviteId,
      channel: channel,
      isVideo: isVideo,
      fromName: fromName,
      fromUid: fromUid,
      toUid: toUid,
      acceptedCallkitId: exactId,
      connectionSystem: connectionSystem,
    );
  }

  bool matchesAcceptedIdentity(CallInvitePayload other) {
    return _matchesAcceptedCallIdentity(
      firstInviteId: inviteId,
      firstCallkitId: acceptedCallkitId,
      secondInviteId: other.inviteId,
      secondCallkitId: other.acceptedCallkitId,
    );
  }
}

class _AcceptedNativeRouteWatch {
  _AcceptedNativeRouteWatch({
    required this.payload,
    required this.lifecycleGeneration,
    required this.claimed,
    required this.startedAt,
  });

  CallInvitePayload payload;
  int lifecycleGeneration;
  bool claimed;
  final DateTime startedAt;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? subscription;
  Timer? timeoutTimer;
  Future<void>? cleanupFuture;
  bool routeOpened = false;
  bool terminal = false;

  bool matchesInvite(String inviteId) => payload.inviteId == inviteId.trim();

  bool matchesIdentity(CallInvitePayload other) =>
      payload.matchesAcceptedIdentity(other);

  bool matchesSession(_CallSession session) {
    return _matchesAcceptedCallIdentity(
      firstInviteId: payload.inviteId,
      firstCallkitId: payload.acceptedCallkitId,
      secondInviteId: session.inviteId,
      secondCallkitId: session.acceptedCallkitId,
    );
  }
}

class _PendingAcceptedInviteIntent {
  const _PendingAcceptedInviteIntent({
    required this.payload,
    required this.ownerGeneration,
    this.claimedGeneration,
  });

  final CallInvitePayload payload;
  final int ownerGeneration;
  final int? claimedGeneration;

  bool matchesInvite(String inviteId) => payload.inviteId == inviteId.trim();

  bool matchesIdentity(CallInvitePayload other) =>
      payload.matchesAcceptedIdentity(other);

  _PendingAcceptedInviteIntent claimedBy(int generation) {
    return _PendingAcceptedInviteIntent(
      payload: payload,
      ownerGeneration: ownerGeneration,
      claimedGeneration: generation,
    );
  }
}

class _AcceptedRouteContinuation {
  _AcceptedRouteContinuation({
    required this.payload,
    required this.claimedGeneration,
  });

  CallInvitePayload payload;
  final int claimedGeneration;
  bool acceptanceConfirmed = false;
  CallInviteStatus authoritativeStatus = CallInviteStatus.unknown;

  bool matches({
    required String inviteId,
    required int generation,
  }) {
    return payload.inviteId == inviteId.trim() &&
        claimedGeneration == generation;
  }
}

class NativeCallSnapshot {
  const NativeCallSnapshot({
    required this.callkitId,
    required this.inviteId,
    required this.channel,
    this.accepted = false,
  });

  final String callkitId;
  final String inviteId;
  final String channel;
  final bool accepted;
}

typedef NativeCallListProvider = Future<List<NativeCallSnapshot>> Function();
typedef NativeCallEnder = Future<void> Function(String callkitId);
typedef NativeIncomingCallPresenter = Future<bool> Function(
  CallInvitePayload payload,
);
typedef NativeInviteStateMarker = Future<void> Function({
  required String inviteId,
  required String channel,
  required String callkitId,
  required String state,
});
typedef StoredAcceptedCallRecoveryClearer = Future<void> Function({
  required String inviteId,
  required String callkitId,
});
typedef AppForegroundProvider = Future<bool> Function();
typedef AcceptedRouteReadinessCanceller = void Function();
typedef NativeRouteOwnershipAcknowledger = Future<bool> Function(
  String exactNativeKey,
);
typedef CallScreenOpenRecorderForTest = Future<void> Function({
  required String inviteId,
  required String channel,
  required String acceptedCallkitId,
  required bool isVideo,
  required String otherUserName,
  required String? otherUserId,
  required bool isCaller,
  required CallV2RealCallConnectionSystem connectionSystem,
  required bool callV2FallbackUsed,
  required String callV2BlockerCode,
});

class _CallSession {
  _CallSession({
    required this.inviteId,
    required this.channel,
    required this.isVideo,
    required this.isCaller,
    required this.otherUserId,
    required this.otherUserName,
    required this.phase,
    required this.status,
    this.connectionSystem = CallV2RealCallConnectionSystem.legacyV1,
    this.callV2FallbackUsed = false,
    this.callV2BlockerCode = 'none',
    this.acceptedCallkitId = '',
    this.lifecycleGeneration = 0,
    DateTime? createdAt,
    DateTime? lastTouchedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastTouchedAt = lastTouchedAt ?? createdAt ?? DateTime.now();

  final String inviteId;
  final String channel;
  final bool isVideo;
  final bool isCaller;
  final String otherUserId;
  final String otherUserName;
  final CallV2RealCallConnectionSystem connectionSystem;
  final bool callV2FallbackUsed;
  final String callV2BlockerCode;
  final String acceptedCallkitId;
  final int lifecycleGeneration;
  final DateTime createdAt;
  CallSessionPhase phase;
  CallInviteStatus status;
  DateTime lastTouchedAt;
  bool localJoined = false;
  bool remoteJoined = false;
  bool terminalSignalSent = false;
  Future<void>? terminalTransitionFuture;

  bool get isTerminal => phase == CallSessionPhase.terminal;
  String get callkitId {
    final exactId = acceptedCallkitId.trim();
    return exactId.isNotEmpty
        ? exactId
        : normalizeCallkitId(rawId: inviteId, fallback: channel);
  }

  bool matchesAcceptedPayload(CallInvitePayload payload) {
    return _matchesAcceptedCallIdentity(
      firstInviteId: inviteId,
      firstCallkitId: acceptedCallkitId,
      secondInviteId: payload.inviteId,
      secondCallkitId: payload.acceptedCallkitId,
    );
  }

  bool matchesAcceptedSession(_CallSession other) {
    return _matchesAcceptedCallIdentity(
      firstInviteId: inviteId,
      firstCallkitId: acceptedCallkitId,
      secondInviteId: other.inviteId,
      secondCallkitId: other.acceptedCallkitId,
    );
  }
}

class _DetachedCallSessionState {
  const _DetachedCallSessionState({
    required this.inviteId,
    required this.callkitId,
    required this.ownerGeneration,
  });

  final String inviteId;
  final String callkitId;
  final int ownerGeneration;
}

class _CallRouteOwner {
  _CallRouteOwner(this.session)
      : inviteId = session.inviteId,
        acceptedCallkitId = session.acceptedCallkitId,
        lifecycleGeneration = session.lifecycleGeneration;

  final _CallSession session;
  final String inviteId;
  final String acceptedCallkitId;
  final int lifecycleGeneration;

  bool ownsSession(_CallSession? candidate) {
    return identical(session, candidate) &&
        candidate?.inviteId == inviteId &&
        candidate?.acceptedCallkitId == acceptedCallkitId &&
        candidate?.lifecycleGeneration == lifecycleGeneration;
  }
}

class _AuthoritativeTerminalTransition {
  const _AuthoritativeTerminalTransition({
    required this.status,
    required this.endReason,
    required this.message,
    required this.isError,
    required this.writeApplied,
    required this.preservedExistingTerminal,
  });

  final CallInviteStatus status;
  final String endReason;
  final String message;
  final bool isError;
  final bool writeApplied;
  final bool preservedExistingTerminal;
}

class CallSessionManager {
  CallSessionManager._();

  static final CallSessionManager instance = CallSessionManager._();

  final ValueNotifier<CallTerminalSignal?> _terminalSignal =
      ValueNotifier<CallTerminalSignal?>(null);
  final Map<String, DateTime> _handledInviteExpiries = <String, DateTime>{};

  GlobalKey<NavigatorState>? _navigatorKey;
  NativeCallListProvider? _listNativeCalls;
  NativeCallEnder? _endNativeCall;
  NativeIncomingCallPresenter? _presentNativeIncomingCall;
  NativeInviteStateMarker? _markNativeInviteState;
  StoredAcceptedCallRecoveryClearer? _clearStoredAcceptedCallRecovery;
  AppForegroundProvider? _appForegroundProvider;
  Future<void> Function()? _afterOutgoingInviteWriteForTest;
  Future<Map<String, dynamic>?> Function(String inviteId)?
      _readInviteDataForTest;
  Future<void> Function(int attempt)? _beforeAcceptTransactionAttemptForTest;
  CallScreenOpenRecorderForTest? _callScreenOpenRecorderForTest;
  bool _skipActiveInviteBindingForTest = false;
  bool _skipAcceptedNativeWatchBindingForTest = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _incomingInviteSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _activeInviteSub;
  Timer? _ringingTimeoutTimer;
  Timer? _acceptedJoiningTimeoutTimer;
  Timer? _pendingIncomingPromptRetryTimer;
  Timer? _incomingListenerRebindTimer;
  Future<void>? _incomingListenerBindFuture;
  final CallV2IncomingListenerBackoff _incomingListenerBackoff =
      CallV2IncomingListenerBackoff();
  final CallV2CallLifecycleArbiter _callLifecycleArbiter =
      CallV2CallLifecycleArbiter();
  _CallSession? _current;
  String _lastDiagStage = '';
  String _lastDiagMeta = '';
  bool _openingCallRoute = false;
  bool _callRouteActive = false;
  _CallRouteOwner? _callRouteOwner;
  bool _incomingPromptActive = false;
  IncomingUiOwner _incomingUiOwner = IncomingUiOwner.none;
  String? _incomingPromptInviteId;
  CallInvitePayload? _pendingIncomingPromptPayload;
  String? _pendingIncomingPromptSource;
  _PendingAcceptedInviteIntent? _pendingAcceptedInviteIntent;
  _AcceptedRouteContinuation? _acceptedRouteContinuation;
  Future<AcceptedCallRecoveryResult>? _acceptedRouteContinuationFuture;
  _AcceptedNativeRouteWatch? _acceptedNativeRouteWatch;
  Future<void>? _acceptedNativeCleanupFuture;
  bool _pendingAcceptedRecorded = false;
  bool _pendingAcceptedClaimed = false;
  bool _pendingAcceptedContinuationStarted = false;
  bool _pendingAcceptedContinuationCompleted = false;
  bool _previousTeardownCompleted = false;
  bool _acceptedRouteResumeTriggered = false;
  bool _acceptedRouteAttemptInFlight = false;
  bool _acceptedRouteNavigatorUnavailable = false;
  bool _acceptedRouteOpened = false;
  bool _acceptedRouteDiscarded = false;
  bool _acceptedRouteAppResumed = false;
  bool _acceptedBridgeIngestionStarted = false;
  bool _acceptedOwnershipRecorded = false;
  bool _acceptedRouteDeadlineReached = false;
  bool _acceptedRouteTerminalObserved = false;
  String? _nativeAcceptedCallInviteId;
  bool _acceptedNativeWatchTerminalObserved = false;
  bool _acceptedNativeWatchDeadlineReached = false;
  bool _acceptedNativeExactIdPresent = false;
  bool _nativeEndRequested = false;
  bool _nativeEndVerified = false;
  bool _nativeEndEscalated = false;
  int _acceptedNativeMatchingCallCount = 0;
  String _acceptedNativeWatchBlockerCode = 'none';
  Duration _acceptedNativeWatchTimeout = _acceptedNativeRouteWatchTimeout;
  Duration _acceptedNativeEndVerificationDelay =
      _defaultAcceptedNativeEndVerificationDelay;
  String? _incomingListenerBoundUid;
  int _incomingListenerGeneration = 0;
  int _incomingListenerErrorCount = 0;
  int _incomingListenerRebindCount = 0;
  DateTime? _incomingListenerLastHealthyAt;
  int _acceptedRecoveryAttemptCount = 0;
  bool _acceptedRecoveryPending = false;
  bool _acceptedRecoveryAcknowledged = false;
  int _acceptedRecoveryRequestGeneration = 0;
  String _acceptedRecoveryRequestInviteId = '';
  String _acceptedRecoveryRequestCallkitId = '';
  bool? _iosCallkitOnlyIncomingUiForTest;
  AcceptedRouteReadinessCanceller? _cancelAcceptedRouteReadiness;
  NativeRouteOwnershipAcknowledger? _acknowledgeNativeRouteOwnership;
  int _callkitFallbackRequestedCount = 0;
  int _callkitPresentationCount = 0;
  int _flutterIncomingPromptCount = 0;
  int _iosFlutterIncomingPromptViolationCount = 0;
  int _callkitAcceptCount = 0;
  int _routeOpenCount = 0;
  int _rtcSetupOwnerCount = 0;
  int _authoritativeTerminalWriteCount = 0;
  int _staleRouteCompletionIgnoredCount = 0;
  bool _awaitingPushkit = false;

  ValueNotifier<CallTerminalSignal?> get terminalSignal => _terminalSignal;

  FirebaseFirestore get _db => HelperlyTestRuntime.firestore;
  String get _currentUid => HelperlyTestRuntime.currentUid ?? '';

  bool get hasPendingAcceptedRouteOwnership =>
      _pendingAcceptedInviteIntent != null ||
      _acceptedRouteContinuation != null;
  bool get isIdleForDebug =>
      _callLifecycleArbiter.isIdle &&
      _current == null &&
      !hasActiveUi &&
      _terminalSignal.value == null;
  bool get isSafeForDestructiveNavigation =>
      _callLifecycleArbiter.isIdle &&
      _current == null &&
      !_openingCallRoute &&
      !_callRouteActive &&
      _callRouteOwner == null &&
      !_incomingPromptActive &&
      !hasPendingAcceptedRouteOwnership;
  bool isOwnedCallRouteTerminal({
    required String inviteId,
    required int lifecycleGeneration,
    required String acceptedCallkitId,
  }) {
    final session = _current;
    return session != null &&
        _sessionMatchesOwnership(
          session,
          inviteId: inviteId,
          lifecycleGeneration:
              lifecycleGeneration == 0 ? null : lifecycleGeneration,
          acceptedCallkitId: acceptedCallkitId,
        ) &&
        (session.isTerminal || _isTerminalStatus(session.status));
  }

  String get debugLastDiagStage => _lastDiagStage;
  String get debugLastDiagMeta => _lastDiagMeta;
  Map<String, dynamic> debugSnapshot() => _sessionSnapshot();
  bool get _debugTestAccessEnabled {
    var enabled = HelperlyTestRuntime.isEnabled;
    assert(() {
      enabled = true;
      return true;
    }());
    return enabled;
  }

  Map<String, int> debugResourceCounts() {
    final incomingInviteListenerCount = _incomingInviteSub == null ? 0 : 1;
    final activeInviteListenerCount = _activeInviteSub == null ? 0 : 1;
    final activeCallSubscriptions =
        incomingInviteListenerCount + activeInviteListenerCount;
    final acceptedNativeWatchListenerCount =
        _acceptedNativeRouteWatch?.subscription == null ? 0 : 1;
    final activeListeners =
        activeCallSubscriptions + acceptedNativeWatchListenerCount;
    final ringingTimerCount =
        _ringingTimeoutTimer != null && _ringingTimeoutTimer!.isActive ? 1 : 0;
    final joiningTimerCount = _acceptedJoiningTimeoutTimer != null &&
            _acceptedJoiningTimeoutTimer!.isActive
        ? 1
        : 0;
    final pendingPromptTimerCount = _pendingIncomingPromptRetryTimer != null &&
            _pendingIncomingPromptRetryTimer!.isActive
        ? 1
        : 0;
    final incomingListenerRebindTimerCount =
        _incomingListenerRebindTimer != null &&
                _incomingListenerRebindTimer!.isActive
            ? 1
            : 0;
    final acceptedNativeWatchTimerCount =
        _acceptedNativeRouteWatch?.timeoutTimer?.isActive == true ? 1 : 0;
    final activeTimers = [
          _ringingTimeoutTimer,
          _acceptedJoiningTimeoutTimer,
          _pendingIncomingPromptRetryTimer,
          _incomingListenerRebindTimer,
        ].where((timer) => timer != null && timer.isActive).length +
        acceptedNativeWatchTimerCount;
    return <String, int>{
      'activeListeners': activeListeners,
      'activeTimers': activeTimers,
      'activeCallSubscriptions': activeCallSubscriptions,
      'activeChatSubscriptions': 0,
      'incomingInviteListenerCount': incomingInviteListenerCount,
      'activeInviteListenerCount': activeInviteListenerCount,
      'acceptedNativeWatchListenerCount': acceptedNativeWatchListenerCount,
      'ringingTimerCount': ringingTimerCount,
      'joiningTimerCount': joiningTimerCount,
      'pendingPromptTimerCount': pendingPromptTimerCount,
      'incomingListenerRebindTimerCount': incomingListenerRebindTimerCount,
      'acceptedNativeWatchTimerCount': acceptedNativeWatchTimerCount,
      'listenerBindingInProgress': _incomingListenerBindFuture == null ? 0 : 1,
      'listenerGeneration': _incomingListenerGeneration,
      'listenerErrorCount': _incomingListenerErrorCount,
      'listenerRebindCount': _incomingListenerRebindCount,
    };
  }

  Future<void> forceIdleForTest() async {
    final acceptedNativeWatch = _acceptedNativeRouteWatch;
    acceptedNativeWatch?.timeoutTimer?.cancel();
    await acceptedNativeWatch?.subscription?.cancel();
    _acceptedNativeRouteWatch = null;
    _acceptedNativeCleanupFuture = null;
    await _activeInviteSub?.cancel();
    _activeInviteSub = null;
    _cancelSessionTimers();
    _current = null;
    _terminalSignal.value = null;
    _openingCallRoute = false;
    _callRouteActive = false;
    _callRouteOwner = null;
    _incomingPromptActive = false;
    _incomingUiOwner = IncomingUiOwner.none;
    _incomingPromptInviteId = null;
    _pendingIncomingPromptRetryTimer?.cancel();
    _pendingIncomingPromptRetryTimer = null;
    _pendingIncomingPromptPayload = null;
    _pendingIncomingPromptSource = null;
    _pendingAcceptedInviteIntent = null;
    _acceptedRouteContinuation = null;
    _acceptedRouteContinuationFuture = null;
    _pendingAcceptedRecorded = false;
    _pendingAcceptedClaimed = false;
    _pendingAcceptedContinuationStarted = false;
    _pendingAcceptedContinuationCompleted = false;
    _previousTeardownCompleted = false;
    _acceptedRouteResumeTriggered = false;
    _acceptedRouteAttemptInFlight = false;
    _acceptedRouteNavigatorUnavailable = false;
    _acceptedRouteOpened = false;
    _acceptedRouteDiscarded = false;
    _acceptedRouteAppResumed = false;
    _acceptedBridgeIngestionStarted = false;
    _acceptedOwnershipRecorded = false;
    _acceptedRouteDeadlineReached = false;
    _acceptedRouteTerminalObserved = false;
    _nativeAcceptedCallInviteId = null;
    _acceptedNativeWatchTerminalObserved = false;
    _acceptedNativeWatchDeadlineReached = false;
    _acceptedNativeExactIdPresent = false;
    _nativeEndRequested = false;
    _nativeEndVerified = false;
    _nativeEndEscalated = false;
    _acceptedNativeMatchingCallCount = 0;
    _acceptedNativeWatchBlockerCode = 'none';
    _acceptedNativeWatchTimeout = _acceptedNativeRouteWatchTimeout;
    _acceptedNativeEndVerificationDelay = Duration.zero;
    _acceptedRecoveryPending = false;
    _acceptedRecoveryAcknowledged = false;
    _acceptedRecoveryAttemptCount = 0;
    _acceptedRecoveryRequestGeneration += 1;
    _acceptedRecoveryRequestInviteId = '';
    _acceptedRecoveryRequestCallkitId = '';
    _awaitingPushkit = false;
    _callkitFallbackRequestedCount = 0;
    _callkitPresentationCount = 0;
    _flutterIncomingPromptCount = 0;
    _iosFlutterIncomingPromptViolationCount = 0;
    _callkitAcceptCount = 0;
    _routeOpenCount = 0;
    _rtcSetupOwnerCount = 0;
    _authoritativeTerminalWriteCount = 0;
    _staleRouteCompletionIgnoredCount = 0;
    _afterOutgoingInviteWriteForTest = null;
    _readInviteDataForTest = null;
    _beforeAcceptTransactionAttemptForTest = null;
    _callScreenOpenRecorderForTest = null;
    _acknowledgeNativeRouteOwnership = null;
    _skipActiveInviteBindingForTest = false;
    _skipAcceptedNativeWatchBindingForTest = false;
    _iosCallkitOnlyIncomingUiForTest = null;
    _callLifecycleArbiter.forceIdleForTest();
  }

  void debugConfigureAcceptedNativeRouteWatchForTest({
    required Duration timeout,
    Duration endVerificationDelay = Duration.zero,
  }) {
    if (!_debugTestAccessEnabled) return;
    _acceptedNativeWatchTimeout = timeout;
    _acceptedNativeEndVerificationDelay = endVerificationDelay;
  }

  Future<void> debugAwaitAcceptedNativeRouteWatchCleanupForTest() async {
    if (!_debugTestAccessEnabled) return;
    final cleanup = _acceptedNativeRouteWatch?.cleanupFuture ??
        _acceptedNativeCleanupFuture;
    if (cleanup != null) await cleanup;
  }

  Future<void> _awaitAcceptedNativeTerminalCleanup() async {
    final cleanup = _acceptedNativeRouteWatch?.cleanupFuture ??
        _acceptedNativeCleanupFuture;
    if (cleanup != null) await cleanup;
  }

  String? get activeInviteId => _current?.inviteId;
  String? get activeChannel => _current?.channel;
  String get currentCallState =>
      (_current?.status ?? CallInviteStatus.unknown).name;
  bool get hasActiveUi =>
      _openingCallRoute || _callRouteActive || _incomingPromptActive;
  bool get hasActiveSession => _current != null && !_current!.isTerminal;
  bool get hasActiveUiOrSession => hasActiveUi || hasActiveSession;
  bool get _iosCallkitOnlyIncomingUi {
    final override = _iosCallkitOnlyIncomingUiForTest;
    if (override != null) return override;
    return _enableIosCallKit && defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _diagResourceCounts(String stage) async {
    final counters = debugResourceCounts();
    DiagnosticService.updateCounters(counters, uid: _currentUid);
    await _diagManager(stage, meta: {
      ...counters,
      ..._sessionSnapshot(),
    });
  }

  void configure({
    GlobalKey<NavigatorState>? navigatorKey,
    NativeCallListProvider? listNativeCalls,
    NativeCallEnder? endNativeCall,
    NativeIncomingCallPresenter? presentNativeIncomingCall,
    NativeInviteStateMarker? markNativeInviteState,
    StoredAcceptedCallRecoveryClearer? clearStoredAcceptedCallRecovery,
    AppForegroundProvider? appForegroundProvider,
    Future<void> Function()? afterOutgoingInviteWriteForTest,
    Future<Map<String, dynamic>?> Function(String inviteId)?
        readInviteDataForTest,
    Future<void> Function(int attempt)? beforeAcceptTransactionAttemptForTest,
    CallScreenOpenRecorderForTest? callScreenOpenRecorderForTest,
    bool? skipActiveInviteBindingForTest,
    bool? skipAcceptedNativeWatchBindingForTest,
    bool? iosCallkitOnlyIncomingUiForTest,
    AcceptedRouteReadinessCanceller? cancelAcceptedRouteReadiness,
    NativeRouteOwnershipAcknowledger? acknowledgeNativeRouteOwnership,
  }) {
    if (navigatorKey != null) {
      _navigatorKey = navigatorKey;
    }
    if (listNativeCalls != null) {
      _listNativeCalls = listNativeCalls;
    }
    if (endNativeCall != null) {
      _endNativeCall = endNativeCall;
    }
    if (presentNativeIncomingCall != null) {
      _presentNativeIncomingCall = presentNativeIncomingCall;
    }
    if (markNativeInviteState != null) {
      _markNativeInviteState = markNativeInviteState;
    }
    if (clearStoredAcceptedCallRecovery != null) {
      _clearStoredAcceptedCallRecovery = clearStoredAcceptedCallRecovery;
    }
    if (appForegroundProvider != null) {
      _appForegroundProvider = appForegroundProvider;
    }
    if (afterOutgoingInviteWriteForTest != null) {
      _afterOutgoingInviteWriteForTest = afterOutgoingInviteWriteForTest;
    }
    if (readInviteDataForTest != null) {
      _readInviteDataForTest = readInviteDataForTest;
    }
    if (beforeAcceptTransactionAttemptForTest != null) {
      _beforeAcceptTransactionAttemptForTest =
          beforeAcceptTransactionAttemptForTest;
    }
    if (callScreenOpenRecorderForTest != null) {
      _callScreenOpenRecorderForTest = callScreenOpenRecorderForTest;
    }
    if (skipActiveInviteBindingForTest != null) {
      _skipActiveInviteBindingForTest = skipActiveInviteBindingForTest;
    }
    if (skipAcceptedNativeWatchBindingForTest != null) {
      _skipAcceptedNativeWatchBindingForTest =
          skipAcceptedNativeWatchBindingForTest;
    }
    if (iosCallkitOnlyIncomingUiForTest != null) {
      _iosCallkitOnlyIncomingUiForTest = iosCallkitOnlyIncomingUiForTest;
    }
    if (cancelAcceptedRouteReadiness != null) {
      _cancelAcceptedRouteReadiness = cancelAcceptedRouteReadiness;
    }
    if (acknowledgeNativeRouteOwnership != null) {
      _acknowledgeNativeRouteOwnership = acknowledgeNativeRouteOwnership;
    }
  }

  Future<int> debugCreateHeldCallRouteForTest({
    required String inviteId,
    required String channel,
    String acceptedCallkitId = '',
    CallInviteStatus status = CallInviteStatus.connected,
    bool isCaller = true,
    bool isVideo = false,
  }) async {
    if (!_debugTestAccessEnabled) {
      throw StateError('debugCreateHeldCallRouteForTest is test-mode only');
    }
    final reservation = _callLifecycleArbiter.reserveOutgoing();
    if (!reservation.reserved) {
      throw StateError('Unable to reserve test lifecycle');
    }
    final owned = _callLifecycleArbiter.outgoingInviteCreated(
      generation: reservation.generation,
      inviteId: inviteId,
    );
    if (!owned) throw StateError('Unable to own test lifecycle');
    _callLifecycleArbiter.markConnected(reservation.generation);
    final session = _CallSession(
      inviteId: inviteId,
      channel: channel,
      isVideo: isVideo,
      isCaller: isCaller,
      otherUserId: 'test_remote',
      otherUserName: 'Test Remote',
      phase: CallSessionPhase.connected,
      status: status,
      acceptedCallkitId: acceptedCallkitId,
      lifecycleGeneration: reservation.generation,
    );
    _current = session;
    _callRouteOwner = _CallRouteOwner(session);
    _callRouteActive = true;
    return reservation.generation;
  }

  Future<void> Function() debugCaptureHeldRouteCompletionForTest({
    String source = 'debug_route_completion',
  }) {
    if (!_debugTestAccessEnabled) {
      throw StateError(
        'debugCaptureHeldRouteCompletionForTest is test-mode only',
      );
    }
    final owner = _callRouteOwner;
    if (owner == null) throw StateError('No held call route owner');
    return () => _completeCallRoute(owner, source: source);
  }

  Future<void> debugMarkHeldRouteTerminalForTest(String inviteId) async {
    if (!_debugTestAccessEnabled) {
      throw StateError('debugMarkHeldRouteTerminalForTest is test-mode only');
    }
    final session = _current;
    if (session == null || session.inviteId != inviteId) return;
    _callLifecycleArbiter.beginEnding(session.lifecycleGeneration);
    session.phase = CallSessionPhase.terminal;
    session.status = CallInviteStatus.ended;
  }

  Future<void> debugRunPreflightForTest(String reason) async {
    if (!_debugTestAccessEnabled) {
      throw StateError('debugRunPreflightForTest is test-mode only');
    }
    await _runPreflightSweepSafely(reason: reason);
  }

  Future<void> debugCloseHeldRouteForTest(String inviteId) async {
    if (!_debugTestAccessEnabled) {
      throw StateError('debugCloseHeldRouteForTest is test-mode only');
    }
    final owner = _callRouteOwner;
    if (owner != null && owner.inviteId == inviteId) {
      await _completeCallRoute(owner, source: 'debug_route_closed');
      return;
    }
    _openingCallRoute = false;
    await handleCallScreenClosed(inviteId);
  }

  void debugInvalidateLifecycleForTest() {
    if (!_debugTestAccessEnabled) {
      throw StateError('debugInvalidateLifecycleForTest is test-mode only');
    }
    _clearPendingAcceptedIntent();
    _callLifecycleArbiter.invalidateForProductionReset();
  }

  void clearStaleUiFlags() {
    if (hasActiveSession) return;
    _openingCallRoute = false;
    _callRouteActive = false;
    _callRouteOwner = null;
    _incomingPromptActive = false;
    _incomingPromptInviteId = null;
    _clearPendingAcceptedIntent();
    _callLifecycleArbiter.invalidateForProductionReset();
  }

  Future<void> bindIncomingInviteListener() async {
    final uid = _currentUid.trim();
    if (uid.isEmpty) {
      _incomingListenerGeneration += 1;
      _incomingListenerBoundUid = null;
      await _incomingInviteSub?.cancel();
      _incomingInviteSub = null;
      _incomingListenerRebindTimer?.cancel();
      _incomingListenerRebindTimer = null;
      return;
    }

    final existing = _incomingListenerBindFuture;
    if (existing != null) {
      await existing;
      if (_incomingListenerBoundUid == uid && _incomingInviteSub != null) {
        return;
      }
    }

    final generation = _incomingListenerBoundUid == uid
        ? _incomingListenerGeneration
        : _incomingListenerGeneration + 1;
    _incomingListenerGeneration = generation;
    final bindFuture = _bindIncomingInviteListenerForAuth(
      uid: uid,
      generation: generation,
    );
    _incomingListenerBindFuture = bindFuture;
    try {
      await bindFuture;
    } finally {
      if (identical(_incomingListenerBindFuture, bindFuture)) {
        _incomingListenerBindFuture = null;
      }
    }
  }

  Future<void> _bindIncomingInviteListenerForAuth({
    required String uid,
    required int generation,
  }) async {
    await _incomingInviteSub?.cancel();
    _incomingInviteSub = null;
    _incomingListenerRebindTimer?.cancel();
    _incomingListenerRebindTimer = null;

    if (_currentUid.trim() != uid ||
        generation != _incomingListenerGeneration) {
      return;
    }

    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
        subscription;
    subscription = _db
        .collection('callInvites')
        .where('toUid', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) async {
      if (_currentUid.trim() != uid ||
          generation != _incomingListenerGeneration) {
        await subscription.cancel();
        if (identical(_incomingInviteSub, subscription)) {
          _incomingInviteSub = null;
          _incomingListenerBoundUid = null;
        }
        return;
      }
      _incomingListenerBackoff.recordHealthySnapshot();
      _incomingListenerLastHealthyAt = DateTime.now();
      final changes = snapshot.docChanges;
      if (changes.isEmpty) {
        for (final doc in snapshot.docs) {
          await _handleIncomingInviteSnapshot(doc,
              source: 'firestore_listener');
        }
        return;
      }
      for (final change in changes) {
        if (change.type != DocumentChangeType.added &&
            change.type != DocumentChangeType.modified) {
          continue;
        }
        await _handleIncomingInviteSnapshot(change.doc,
            source: 'firestore_listener');
      }
    }, onError: (Object error) {
      if (_currentUid.trim() != uid ||
          generation != _incomingListenerGeneration) {
        unawaited(subscription.cancel());
        return;
      }
      _incomingListenerErrorCount += 1;
      unawaited(_diagManager('incoming_listener_error', meta: {
        'authReady': _currentUid.trim().isNotEmpty,
        'listenerGeneration': generation,
        'error': '$error',
      }));
      unawaited(FirestoreReadHelper.recoverNetwork(
        reason: 'incoming_listener_error',
        force: true,
      ));
      unawaited(_recoverIncomingInviteListenerAfterError(
        uid,
        generation,
        subscription,
      ));
    });
    if (_currentUid.trim() != uid ||
        generation != _incomingListenerGeneration) {
      await subscription.cancel();
      return;
    }
    _incomingInviteSub = subscription;
    _incomingListenerBoundUid = uid;
    await _diagResourceCounts('incoming_listener_bound');
    unawaited(recoverForegroundIncomingInvites(source: 'listener_bound'));
  }

  Future<void> _recoverIncomingInviteListenerAfterError(
    String uid,
    int generation,
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>> subscription,
  ) async {
    if (_currentUid.trim() != uid.trim() ||
        generation != _incomingListenerGeneration) {
      return;
    }
    await subscription.cancel();
    if (!identical(_incomingInviteSub, subscription)) {
      return;
    }
    _incomingInviteSub = null;
    _incomingListenerBoundUid = null;
    _scheduleIncomingInviteListenerRebind(uid, generation);
    await _diagResourceCounts('incoming_listener_rebind_scheduled');
  }

  void _scheduleIncomingInviteListenerRebind(String uid, int generation) {
    _incomingListenerRebindTimer?.cancel();
    final delay = _incomingListenerBackoff.recordErrorAndGetDelay();
    _incomingListenerRebindTimer = Timer(delay, () async {
      if (_currentUid.trim() != uid.trim() ||
          generation != _incomingListenerGeneration) {
        return;
      }
      _incomingListenerRebindCount += 1;
      await bindIncomingInviteListener();
    });
  }

  Future<void> recoverForegroundIncomingInvites({
    String source = 'manual',
  }) async {
    final uid = _currentUid.trim();
    if (uid.isEmpty) return;
    if (!await _isAppActuallyForeground()) return;
    await FirestoreReadHelper.recoverNetwork(
      reason: 'incoming_recovery:$source',
    );

    QuerySnapshot<Map<String, dynamic>>? snap;
    try {
      snap = await FirestoreReadHelper.getQuery(
        _db
            .collection('callInvites')
            .where('toUid', isEqualTo: uid)
            .where('status', isEqualTo: CallInviteStatus.ringing.name),
        timeout: const Duration(seconds: 5),
      );
    } catch (error) {
      await _diagManager('incoming_recovery_query_error', meta: {
        'uid': uid,
        'source': source,
        'query': 'toUid_status',
        'error': '$error',
      });
      try {
        snap = await FirestoreReadHelper.getQuery(
          _db.collection('callInvites').where('toUid', isEqualTo: uid),
          timeout: const Duration(seconds: 5),
        );
      } catch (fallbackError) {
        await _diagManager('incoming_recovery_query_error', meta: {
          'uid': uid,
          'source': source,
          'query': 'toUid_fallback',
          'error': '$fallbackError',
        });
      }
    }

    if (snap == null) return;
    for (final doc in snap.docs) {
      await _handleIncomingInviteSnapshot(doc, source: 'foreground_recovery');
    }
  }

  Future<void> clearForSignedOut() async {
    _afterOutgoingInviteWriteForTest = null;
    await _incomingInviteSub?.cancel();
    _incomingInviteSub = null;
    _incomingListenerRebindTimer?.cancel();
    _incomingListenerRebindTimer = null;
    _incomingListenerBindFuture = null;
    _incomingListenerGeneration += 1;
    _incomingListenerBoundUid = null;
    _incomingListenerLastHealthyAt = null;
    _incomingListenerBackoff.reset();
    _handledInviteExpiries.clear();
    await _diagResourceCounts('clear_for_signed_out_start');
    final acceptedNativeWatch = _acceptedNativeRouteWatch;
    if (acceptedNativeWatch != null) {
      await _resolveAcceptedNativeRouteWatch(
        acceptedNativeWatch,
        reason: 'signed_out',
        deadlineReached: false,
        markInviteFailed: false,
      );
    }
    _clearPendingAcceptedIntent();
    await _resetSessionState(
      reason: 'signed_out',
      endCurrentNativeCall: true,
      endUnownedNativeCalls: true,
      endAllNativeCallsForAppReset: true,
      clearStoredAcceptedRecovery: true,
      clearHandledInvites: true,
      forceClearUiFlags: true,
    );
    _callLifecycleArbiter.invalidateForProductionReset();
  }

  Future<void> hardResetForNewCall({
    String reason = 'hard_reset_for_new_call',
    String? expectedInviteId,
    String? expectedCallkitId,
  }) async {
    try {
      if (!_cleanupRequestOwnsCurrentSession(
        expectedInviteId: expectedInviteId,
        expectedCallkitId: expectedCallkitId,
      )) {
        await _diagManager('hard_reset_stale_owner_ignored', meta: {
          'reason': reason,
        });
        return;
      }
      final acceptedNativeWatch = _acceptedNativeRouteWatch;
      if (acceptedNativeWatch != null && !_callRouteActive) {
        await _resolveAcceptedNativeRouteWatch(
          acceptedNativeWatch,
          reason: reason,
          deadlineReached: false,
          markInviteFailed: false,
        );
      }
      final session = _current;
      if (session != null && !session.isTerminal) {
        await _diagManager('hard_reset_deferred_active_session', meta: {
          ..._sessionSnapshot(),
          'reason': reason,
        });
        return;
      }
      if (session != null && (_callRouteActive || _openingCallRoute)) {
        _callLifecycleArbiter.beginTeardown(session.lifecycleGeneration);
        await _activeInviteSub?.cancel();
        if (!identical(_current, session)) return;
        _activeInviteSub = null;
        _cancelSessionTimers();
        _terminalSignal.value = null;
        if (session.callkitId.isNotEmpty) {
          await _endNativeCallSafely(
            session.callkitId,
            reason: '$reason:end_current_native',
          );
        }
        if (!identical(_current, session)) return;
        await _endStaleNativeCalls(
          keepCallkitId: session.callkitId.isEmpty ? null : session.callkitId,
          reason: reason,
        );
        if (!identical(_current, session)) return;
        await _clearStoredAcceptedCallRecoverySafely(
          reason,
          inviteId: session.inviteId,
          callkitId: session.callkitId,
        );
        await _diagManager('hard_reset_deferred_until_route_closed', meta: {
          ..._sessionSnapshot(),
          'reason': reason,
        });
        return;
      }
      if (session != null) {
        await _finalizeTerminalSessionCleanup(
          inviteId: session.inviteId,
          reason: reason,
          forceClearUiFlags: true,
        );
      } else {
        _discardPendingAcceptedIntent();
        await _resetSessionState(
          reason: reason,
          endCurrentNativeCall: true,
          endUnownedNativeCalls: true,
          clearStoredAcceptedRecovery: true,
          forceClearUiFlags: true,
        );
      }
    } catch (e) {
      await _diagManager('hard_reset_error', meta: {
        'reason': reason,
        'error': '$e',
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _diagResourceCounts('hard_reset_done');
  }

  bool _cleanupRequestOwnsCurrentSession({
    required String? expectedInviteId,
    required String? expectedCallkitId,
  }) {
    final expectedInvite = (expectedInviteId ?? '').trim();
    final expectedCallkit = (expectedCallkitId ?? '').trim().toLowerCase();
    if (expectedInvite.isEmpty && expectedCallkit.isEmpty) return true;
    final session = _current;
    if (session == null) return false;
    if (expectedCallkit.isNotEmpty) {
      return session.callkitId.trim().toLowerCase() == expectedCallkit;
    }
    return session.inviteId == expectedInvite;
  }

  static String generateChannelName(String uid1, String uid2) {
    String clean(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');
    final a = clean(uid1);
    final b = clean(uid2);
    final pair = [a, b]..sort();

    final sa = pair[0].length > 12 ? pair[0].substring(0, 12) : pair[0];
    final sb = pair[1].length > 12 ? pair[1].substring(0, 12) : pair[1];
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);

    var name = 'c_${sa}_${sb}_$ts';
    if (name.length > 64) name = name.substring(0, 64);
    return name;
  }

  Future<bool> startOutgoingCall(
    BuildContext context, {
    required String toUid,
    required String toName,
    required bool isVideo,
    bool openScreen = true,
    CallV2RealCallFlowDecision callV2Decision =
        const CallV2RealCallFlowDecision.legacy(),
  }) async {
    final meUid = _currentUid.trim();
    if (meUid.isEmpty) {
      throw Exception('Not signed in');
    }
    final outgoingReservation = _callLifecycleArbiter.reserveOutgoing();
    if (!outgoingReservation.reserved) {
      await _diagManager('start_blocked', meta: {
        ..._sessionSnapshot(),
        'requestedIsVideo': isVideo,
        'reason': _callLifecycleArbiter.teardownInProgress
            ? 'teardown_in_progress'
            : 'active_ui_or_session',
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(_callLifecycleArbiter.teardownInProgress
              ? 'Finishing previous call...'
              : 'A call is already in progress.'),
        ),
      );
      return false;
    }
    await _diagManager('outgoing_tap', meta: {
      'isVideo': isVideo,
      'callV2Selected': callV2Decision.callV2Selected,
      'fallbackUsed': callV2Decision.fallbackUsed,
      'blockerCode': callV2Decision.blockerCode,
    });
    await FirestoreReadHelper.recoverNetwork(reason: 'outgoing_call_start');
    if (!_callLifecycleArbiter.ownsOutgoingReservation(
      outgoingReservation.generation,
    )) {
      await _diagManager('start_blocked', meta: {
        ..._sessionSnapshot(),
        'requestedIsVideo': isVideo,
        'reason': 'reservation_lost_before_preflight',
      });
      return false;
    }

    final channel = generateChannelName(meUid, toUid);
    final inviteRef = _db.collection('callInvites').doc();

    await _diagManager('preflight_start', meta: {
      'isVideo': isVideo,
      'callV2Selected': callV2Decision.callV2Selected,
    });
    await _runPreflightSweepSafely(
      reason: isVideo ? 'outgoing_video_preflight' : 'outgoing_audio_preflight',
      endUnownedNativeCalls: true,
    );
    if (!_callLifecycleArbiter.ownsOutgoingReservation(
      outgoingReservation.generation,
    )) {
      await _diagManager('start_blocked', meta: {
        ..._sessionSnapshot(),
        'requestedIsVideo': isVideo,
        'reason': 'reservation_lost_during_preflight',
      });
      return false;
    }
    await _diagManager('preflight_done', meta: {
      'isVideo': isVideo,
      'callV2Selected': callV2Decision.callV2Selected,
    });
    if (hasActiveUiOrSession) {
      final nativeCalls = await _listNativeCallsSafely();
      final blockedMeta = {
        ..._sessionSnapshot(nativeCalls: nativeCalls),
        'requestedIsVideo': isVideo,
        'reason': 'active_ui_or_session',
      };
      await _diagManager('start_blocked', meta: blockedMeta);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('A call is already in progress.')),
      );
      _callLifecycleArbiter.releaseOutgoingReservation(
        outgoingReservation.generation,
      );
      return false;
    }

    final authName = (HelperlyTestRuntime.currentDisplayName ?? '').trim();
    final fromName = authName.isEmpty ? 'Caller' : authName;

    await _diagManager('invite_write_start', meta: {
      'isVideo': isVideo,
      'callV2Selected': callV2Decision.callV2Selected,
    });
    if (!_callLifecycleArbiter.ownsOutgoingReservation(
      outgoingReservation.generation,
    )) {
      await _diagManager('start_blocked', meta: {
        ..._sessionSnapshot(),
        'requestedIsVideo': isVideo,
        'reason': 'reservation_lost_before_invite_write',
      });
      return false;
    }
    try {
      final inviteData = <String, dynamic>{
        'fromUid': meUid,
        'fromName': fromName,
        'toUid': toUid,
        'toName': toName,
        'channel': channel,
        'isVideo': isVideo,
        'status': CallInviteStatus.ringing.name,
        'createdAt': FieldValue.serverTimestamp(),
        'callerStage': 'ringing',
        'calleeStage': 'idle',
        'callerLastError': '',
        'calleeLastError': '',
        'endReason': '',
        'endedBy': '',
      };
      final connectionValue = callConnectionSystemToInviteValue(
        callV2Decision.connectionSystem,
      );
      if (connectionValue != null) {
        inviteData['callSystem'] = connectionValue;
        inviteData['callV2DevCallable'] = true;
      }
      await inviteRef.set({
        ...inviteData,
      }).timeout(const Duration(seconds: 8));
      if (_debugTestAccessEnabled) {
        await _afterOutgoingInviteWriteForTest?.call();
      }
      if (!_callLifecycleArbiter.ownsOutgoingReservation(
        outgoingReservation.generation,
      )) {
        await _cancelOrphanOutgoingInvite(inviteRef.id);
        _callLifecycleArbiter.recordOrphanInviteCancelled();
        await _diagManager('start_blocked', meta: {
          ..._sessionSnapshot(),
          'requestedIsVideo': isVideo,
          'reason': 'reservation_lost_after_invite_write',
        });
        return false;
      }
    } catch (error) {
      await _diagManager('failed', meta: {
        'source': 'invite_write',
        'error': '$error',
      });
      unawaited(FirestoreReadHelper.recoverNetwork(
        reason: 'invite_write_error',
        force: true,
      ));
      _callLifecycleArbiter.releaseOutgoingReservation(
        outgoingReservation.generation,
      );
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Unable to start call. Check your connection.'),
        ),
      );
      return false;
    }
    await _diagManager('invite_created', meta: {
      'isVideo': isVideo,
      'callV2Selected': callV2Decision.callV2Selected,
    });
    final inviteOwned = _callLifecycleArbiter.outgoingInviteCreated(
      generation: outgoingReservation.generation,
      inviteId: inviteRef.id,
    );
    if (!inviteOwned) {
      await _cancelOrphanOutgoingInvite(inviteRef.id);
      await _diagManager('start_blocked', meta: {
        ..._sessionSnapshot(),
        'requestedIsVideo': isVideo,
        'reason': 'reservation_lost_before_session_activation',
      });
      return false;
    }

    final session = _CallSession(
      inviteId: inviteRef.id,
      channel: channel,
      isVideo: isVideo,
      isCaller: true,
      otherUserId: toUid,
      otherUserName: toName,
      phase: CallSessionPhase.outgoingRinging,
      status: CallInviteStatus.ringing,
      connectionSystem: callV2Decision.connectionSystem,
      callV2FallbackUsed: callV2Decision.fallbackUsed,
      callV2BlockerCode: callV2Decision.blockerCode,
      lifecycleGeneration: outgoingReservation.generation,
    );

    final activationResult = await _activateSession(
      session,
      openScreen: openScreen,
      source: 'caller_start',
    );
    if (openScreen &&
        activationResult != _RouteOpenResult.opened &&
        activationResult != _RouteOpenResult.alreadyOpenSameInvite) {
      await _cancelOrphanOutgoingInvite(inviteRef.id);
      _callLifecycleArbiter.recordOrphanInviteCancelled();
      _callLifecycleArbiter.beginTeardown(outgoingReservation.generation);
      final teardownClaim =
          _callLifecycleArbiter.completeTeardownAndClaimPending(
        outgoingReservation.generation,
      );
      if (teardownClaim.claimed && teardownClaim.inviteId != null) {
        _callLifecycleArbiter.dropIncoming(
          generation: teardownClaim.generation,
          inviteId: teardownClaim.inviteId!,
        );
      }
      return false;
    }
    return true;
  }

  Future<String> startOutgoingCallForTest({
    required String toUid,
    required String toName,
    required bool isVideo,
  }) async {
    if (!HelperlyTestRuntime.isEnabled) {
      throw StateError('startOutgoingCallForTest is test-mode only');
    }
    final meUid = _currentUid.trim();
    if (meUid.isEmpty) {
      throw Exception('Not signed in');
    }

    await forceIdleForTest();
    final channel = generateChannelName(meUid, toUid);
    final inviteRef = _db.collection('callInvites').doc();
    final authName = (HelperlyTestRuntime.currentDisplayName ?? '').trim();
    final fromName = authName.isEmpty ? 'Caller' : authName;

    await inviteRef.set({
      'fromUid': meUid,
      'fromName': fromName,
      'toUid': toUid,
      'toName': toName,
      'channel': channel,
      'isVideo': isVideo,
      'status': CallInviteStatus.ringing.name,
      'createdAt': FieldValue.serverTimestamp(),
      'callerStage': 'ringing',
      'calleeStage': 'idle',
      'callerLastError': '',
      'calleeLastError': '',
      'endReason': '',
      'endedBy': '',
    });

    final session = _CallSession(
      inviteId: inviteRef.id,
      channel: channel,
      isVideo: isVideo,
      isCaller: true,
      otherUserId: toUid,
      otherUserName: toName,
      phase: CallSessionPhase.outgoingRinging,
      status: CallInviteStatus.ringing,
    );

    await _activateSession(session, openScreen: false, source: 'caller_start');
    return inviteRef.id;
  }

  Future<void> handleNotificationInviteTap({
    required String inviteId,
    required String channel,
    required bool isVideo,
    required String fromName,
    String? fromUid,
    bool autoAccept = false,
    required String source,
  }) async {
    final payload = await _loadInvitePayload(
      inviteId: inviteId,
      fallbackChannel: channel,
      fallbackIsVideo: isVideo,
      fallbackFromName: fromName,
      fallbackFromUid: fromUid ?? '',
    );
    if (payload == null) return;
    await _handleIncomingCandidate(
      payload,
      source: source,
      via: 'notification_tap',
      autoAccept: autoAccept,
    );
  }

  Future<AcceptedCallRecoveryResult> handleRecoveredAcceptedInvite({
    required String inviteId,
    required String channel,
    required bool isVideo,
    required String fromName,
    String? fromUid,
    String callkitId = '',
  }) async {
    final requestGeneration = _claimAcceptedRecoveryRequest(
      inviteId: inviteId,
      callkitId: callkitId,
    );
    _acceptedRecoveryAttemptCount += 1;
    _acceptedRecoveryPending = true;
    _acceptedRecoveryAcknowledged = false;
    final bridgePayload = CallInvitePayload(
      inviteId: inviteId.trim(),
      channel: channel.trim(),
      isVideo: isVideo,
      fromName: fromName,
      fromUid: (fromUid ?? '').trim(),
      toUid: _currentUid.trim(),
      acceptedCallkitId: callkitId.trim(),
    );
    final acceptedRouteContinuation = _acceptedRouteContinuation;
    if (acceptedRouteContinuation != null &&
        acceptedRouteContinuation.payload
            .matchesAcceptedIdentity(bridgePayload)) {
      final resumed = await resumePendingAcceptedRouteIfReady(
        source: 'callkit_recovery_duplicate',
      );
      if (!_ownsAcceptedRecoveryRequest(
        generation: requestGeneration,
        inviteId: inviteId,
        callkitId: callkitId,
      )) {
        return AcceptedCallRecoveryResult.busy;
      }
      switch (resumed) {
        case AcceptedCallRecoveryResult.opened:
        case AcceptedCallRecoveryResult.alreadyOpen:
        case AcceptedCallRecoveryResult.terminal:
        case AcceptedCallRecoveryResult.invalid:
        case AcceptedCallRecoveryResult.pendingAuth:
        case AcceptedCallRecoveryResult.pendingNetwork:
        case AcceptedCallRecoveryResult.failed:
          return resumed;
        case AcceptedCallRecoveryResult.pendingTeardown:
        case AcceptedCallRecoveryResult.pendingNavigator:
        case AcceptedCallRecoveryResult.busy:
          return AcceptedCallRecoveryResult.pendingTeardown;
      }
    }
    if (_currentUid.trim().isEmpty) {
      await _diagManager('accepted_recovery_pending', meta: {
        'authReady': false,
        'acceptedRecoveryAttemptCount': _acceptedRecoveryAttemptCount,
      });
      return AcceptedCallRecoveryResult.pendingAuth;
    }
    _acceptedBridgeIngestionStarted = true;
    final ownershipResult = await _handleIncomingCandidate(
      bridgePayload,
      source: 'callkit_recovery',
      via: 'callkit_recovery',
      autoAccept: true,
      deferAcceptedOpen: true,
    );
    if (!_ownsAcceptedRecoveryRequest(
      generation: requestGeneration,
      inviteId: inviteId,
      callkitId: callkitId,
    )) {
      return AcceptedCallRecoveryResult.busy;
    }
    if (ownershipResult == _IncomingCandidateResult.busy) {
      return AcceptedCallRecoveryResult.busy;
    }
    if (ownershipResult == _IncomingCandidateResult.opened ||
        ownershipResult == _IncomingCandidateResult.alreadyOpen) {
      _acceptedRecoveryPending = false;
      _acceptedRecoveryAcknowledged = true;
      return ownershipResult == _IncomingCandidateResult.alreadyOpen
          ? AcceptedCallRecoveryResult.alreadyOpen
          : AcceptedCallRecoveryResult.opened;
    }
    if (ownershipResult != _IncomingCandidateResult.acceptedPending) {
      return AcceptedCallRecoveryResult.failed;
    }
    final continuation = _acceptedRouteContinuation;
    if (continuation == null ||
        !continuation.payload.matchesAcceptedIdentity(bridgePayload)) {
      if (_acceptedRouteTerminalObserved) {
        await _awaitAcceptedNativeTerminalCleanup();
        return AcceptedCallRecoveryResult.terminal;
      }
      return AcceptedCallRecoveryResult.pendingTeardown;
    }

    final result = await resumePendingAcceptedRouteIfReady(
      source: 'callkit_recovery',
    );
    if (!_ownsAcceptedRecoveryRequest(
      generation: requestGeneration,
      inviteId: inviteId,
      callkitId: callkitId,
    )) {
      return AcceptedCallRecoveryResult.busy;
    }
    return result;
  }

  Future<bool> handleAcceptedNativeSafetyTerminated({
    required String inviteId,
    required String callkitId,
  }) async {
    final normalizedExactId = callkitId.trim();
    if (normalizedExactId.isEmpty) return false;
    final requestMatches = _matchesAcceptedCallIdentity(
      firstInviteId: _acceptedRecoveryRequestInviteId,
      firstCallkitId: _acceptedRecoveryRequestCallkitId,
      secondInviteId: inviteId,
      secondCallkitId: normalizedExactId,
    );
    final watch = _acceptedNativeRouteWatch;
    final watchMatches = watch != null &&
        _matchesAcceptedCallIdentity(
          firstInviteId: watch.payload.inviteId,
          firstCallkitId: watch.payload.acceptedCallkitId,
          secondInviteId: inviteId,
          secondCallkitId: normalizedExactId,
        );
    if (!requestMatches && !watchMatches) return false;
    if (requestMatches) {
      _acceptedRecoveryRequestGeneration += 1;
      _acceptedRecoveryRequestInviteId = '';
      _acceptedRecoveryRequestCallkitId = '';
    }
    if (watchMatches) {
      unawaited(_resolveAcceptedNativeRouteWatch(
        watch,
        reason: 'native_safety_terminal_verified',
        deadlineReached: true,
        markInviteFailed: true,
      ));
    }
    return true;
  }

  int _claimAcceptedRecoveryRequest({
    required String inviteId,
    required String callkitId,
  }) {
    final normalizedInviteId = inviteId.trim();
    final normalizedCallkitId = callkitId.trim().toLowerCase();
    final sameIdentity = _matchesAcceptedCallIdentity(
      firstInviteId: _acceptedRecoveryRequestInviteId,
      firstCallkitId: _acceptedRecoveryRequestCallkitId,
      secondInviteId: normalizedInviteId,
      secondCallkitId: normalizedCallkitId,
    );
    if (!sameIdentity) {
      _acceptedRecoveryRequestGeneration += 1;
    }
    _acceptedRecoveryRequestInviteId = normalizedInviteId;
    _acceptedRecoveryRequestCallkitId = normalizedCallkitId;
    return _acceptedRecoveryRequestGeneration;
  }

  bool _ownsAcceptedRecoveryRequest({
    required int generation,
    required String inviteId,
    required String callkitId,
  }) {
    if (generation != _acceptedRecoveryRequestGeneration) return false;
    return _matchesAcceptedCallIdentity(
      firstInviteId: _acceptedRecoveryRequestInviteId,
      firstCallkitId: _acceptedRecoveryRequestCallkitId,
      secondInviteId: inviteId,
      secondCallkitId: callkitId,
    );
  }

  Future<void> declineInvite({
    required String inviteId,
    String source = 'manual_decline',
  }) async {
    await _declineInviteTransaction(inviteId, source: source);
    await _markNativeInviteStateByIdsSafely(
      inviteId: inviteId,
      channel: '',
      state: 'terminal',
      reason: source,
    );
    await _terminalizeUnacceptedIncomingInvite(
      inviteId: inviteId,
      status: CallInviteStatus.declined,
      source: source,
    );
  }

  Future<void> handleSystemEndedInvite({
    required String inviteId,
    String source = 'system_end',
  }) async {
    final session = _current;
    if (session != null &&
        session.inviteId == inviteId &&
        !session.isTerminal) {
      await endCallFromLocalUser(inviteId: inviteId, source: source);
      return;
    }
    await _markNativeInviteStateByIdsSafely(
      inviteId: inviteId,
      channel: '',
      state: 'terminal',
      reason: source,
    );
    await _setInviteStatusIfCurrent(
      inviteId: inviteId,
      expectedStatuses: const <CallInviteStatus>{
        CallInviteStatus.ringing,
        CallInviteStatus.accepted,
        CallInviteStatus.joining,
        CallInviteStatus.connected,
      },
      updates: <String, dynamic>{
        'status': CallInviteStatus.ended.name,
        'endedAt': FieldValue.serverTimestamp(),
        'endReason': source,
        'endedBy': _currentUid,
      },
    );
    await _terminalizeUnacceptedIncomingInvite(
      inviteId: inviteId,
      status: CallInviteStatus.ended,
      source: source,
    );
  }

  Future<void> handleSystemTimeoutInvite({
    required String inviteId,
    String source = 'system_timeout',
  }) async {
    await _markNativeInviteStateByIdsSafely(
      inviteId: inviteId,
      channel: '',
      state: 'terminal',
      reason: source,
    );
    await _setInviteStatusIfCurrent(
      inviteId: inviteId,
      expectedStatuses: const <CallInviteStatus>{CallInviteStatus.ringing},
      updates: <String, dynamic>{
        'status': CallInviteStatus.missed.name,
        'missedAt': FieldValue.serverTimestamp(),
        'endedAt': FieldValue.serverTimestamp(),
        'endReason': source,
        'endedBy': _currentUid,
      },
    );
    await _terminalizeUnacceptedIncomingInvite(
      inviteId: inviteId,
      status: CallInviteStatus.missed,
      source: source,
    );
  }

  Future<void> _terminalizeUnacceptedIncomingInvite({
    required String inviteId,
    required CallInviteStatus status,
    required String source,
    String channel = '',
  }) async {
    final normalizedInviteId = inviteId.trim();
    if (normalizedInviteId.isEmpty) return;
    final session = _current;
    if (session != null &&
        session.inviteId == normalizedInviteId &&
        !session.isTerminal) {
      return;
    }

    final ownsPrompt = _incomingPromptInviteId == normalizedInviteId &&
        _incomingUiOwner != IncomingUiOwner.none;
    if (!ownsPrompt) {
      _callLifecycleArbiter.clearPendingInvite(normalizedInviteId);
      _clearPendingAcceptedIntent(inviteId: normalizedInviteId);
      _clearPendingIncomingPrompt(normalizedInviteId);
      await _markNativeInviteStateByIdsSafely(
        inviteId: normalizedInviteId,
        channel: channel,
        state: 'terminal',
        reason: source,
      );
      await _endNativeCallForInvite(
        inviteId: normalizedInviteId,
        channel: channel,
        reason: source,
      );
      return;
    }

    final generation = _callLifecycleArbiter.generation;
    if (!_callLifecycleArbiter.ownsIncoming(
      generation: generation,
      inviteId: normalizedInviteId,
    )) {
      return;
    }
    _callLifecycleArbiter.beginEnding(generation);
    _callLifecycleArbiter.beginTeardown(generation);
    final pendingPayload = _pendingIncomingPromptPayload;
    final pendingSource = _pendingIncomingPromptSource;
    _incomingPromptActive = false;
    _incomingPromptInviteId = null;
    _incomingUiOwner = IncomingUiOwner.none;
    _clearPendingIncomingPrompt(normalizedInviteId);
    _markInviteHandled(normalizedInviteId);
    await _markNativeInviteStateByIdsSafely(
      inviteId: normalizedInviteId,
      channel: channel,
      state: 'terminal',
      reason: source,
    );
    await _endNativeCallForInvite(
      inviteId: normalizedInviteId,
      channel: channel,
      reason: source,
    );

    final pendingClaim =
        _callLifecycleArbiter.completeTeardownAndClaimPending(generation);
    if (!pendingClaim.claimed) {
      await _diagManager('incoming_terminalized_idle', meta: {
        'source': source,
        'status': status.name,
      });
      return;
    }
    await _continueClaimedPendingIncoming(
      pendingClaim: pendingClaim,
      pendingPayload: pendingPayload,
      pendingSource: pendingSource,
      source: '$source:terminal_complete',
    );
  }

  Future<void> reportCallScreenBegan({
    required String inviteId,
    required bool isCaller,
  }) async {
    final session = _current;
    if (!_canApplyMediaProgress(session, inviteId: inviteId)) return;
    final generation = session!.lifecycleGeneration;
    CallV2PhysicalDiagnosticLedger.instance.record(
      CallV2PhysicalDiagnosticStage.rtcSetupStarted,
    );

    // The caller opens the call screen while the invite is still ringing.
    // Do not advance the session into the accepted/joining timeout path until
    // Firestore actually transitions away from ringing.
    if (isCaller && session.status == CallInviteStatus.ringing) {
      _touchSession(session);
      return;
    }

    if (!_callLifecycleArbiter.markJoining(generation)) return;
    session.phase = CallSessionPhase.joining;
    _touchSession(session);
    final updated = await _updateInviteForActor(
      inviteId: inviteId,
      isCaller: isCaller,
      stage: 'joining',
      expectedStatuses: const <CallInviteStatus>{
        CallInviteStatus.ringing,
        CallInviteStatus.accepted,
        CallInviteStatus.joining,
      },
      extra: <String, dynamic>{
        if (!isCaller) 'status': CallInviteStatus.joining.name,
        if (!isCaller) 'joiningAt': FieldValue.serverTimestamp(),
      },
    );
    if (!updated ||
        !_canApplyMediaProgressForGeneration(
          inviteId: inviteId,
          generation: generation,
        )) {
      return;
    }
    await _diagManager('joining', meta: {
      'inviteId': inviteId,
      'isCaller': isCaller,
    });
    _restartAcceptedJoiningTimeout();
  }

  Future<void> reportAgoraJoinSuccess({
    required String inviteId,
    required bool isCaller,
  }) async {
    final session = _current;
    if (!_canApplyMediaProgress(session, inviteId: inviteId)) return;
    final generation = session!.lifecycleGeneration;
    CallV2PhysicalDiagnosticLedger.instance.record(
      CallV2PhysicalDiagnosticStage.agoraJoinAttempted,
    );
    CallV2PhysicalDiagnosticLedger.instance.record(
      CallV2PhysicalDiagnosticStage.agoraJoined,
    );
    session.localJoined = true;
    if (session.phase != CallSessionPhase.connected &&
        (!isCaller || session.status != CallInviteStatus.ringing)) {
      if (!_callLifecycleArbiter.markJoining(generation)) return;
      session.phase = CallSessionPhase.joining;
    }
    _touchSession(session);
    final updated = await _updateInviteForActor(
      inviteId: inviteId,
      isCaller: isCaller,
      stage: 'joined_local',
      expectedStatuses: const <CallInviteStatus>{
        CallInviteStatus.ringing,
        CallInviteStatus.accepted,
        CallInviteStatus.joining,
        CallInviteStatus.connected,
      },
    );
    if (!updated ||
        !_canApplyMediaProgressForGeneration(
          inviteId: inviteId,
          generation: generation,
        )) {
      return;
    }

    // Same rule as reportCallScreenBegan: the caller may join Agora locally
    // before the callee accepts. Only arm the accepted/joining timeout once
    // the invite actually leaves ringing.
    if (!isCaller || session.status != CallInviteStatus.ringing) {
      _restartAcceptedJoiningTimeout();
    }
  }

  Future<void> reportRemoteJoined({
    required String inviteId,
    required bool isCaller,
  }) async {
    final session = _current;
    if (!_canApplyMediaProgress(session, inviteId: inviteId)) return;
    final generation = session!.lifecycleGeneration;
    CallV2PhysicalDiagnosticLedger.instance.record(
      CallV2PhysicalDiagnosticStage.remoteJoined,
    );
    session.remoteJoined = true;
    if (!_callLifecycleArbiter.markConnected(generation)) return;
    session.phase = CallSessionPhase.connected;
    session.status = CallInviteStatus.connected;
    _touchSession(session);
    _cancelSessionTimers();
    final updated = await _updateInviteForActor(
      inviteId: inviteId,
      isCaller: isCaller,
      stage: 'connected',
      expectedStatuses: const <CallInviteStatus>{
        CallInviteStatus.ringing,
        CallInviteStatus.accepted,
        CallInviteStatus.joining,
        CallInviteStatus.connected,
      },
      extra: <String, dynamic>{
        'status': CallInviteStatus.connected.name,
        'connectedAt': FieldValue.serverTimestamp(),
      },
    );
    if (!updated ||
        !_canApplyMediaProgressForGeneration(
          inviteId: inviteId,
          generation: generation,
        )) {
      return;
    }
    await _diagManager('connected', meta: {
      'inviteId': inviteId,
      'isCaller': isCaller,
    });
  }

  Future<void> reportRemoteOffline({
    required String inviteId,
    required bool wasConnected,
    required bool isCaller,
    required String reason,
  }) async {
    final session = _current;
    if (session == null || session.inviteId != inviteId) return;
    if (session.isTerminal) return;

    if (wasConnected || session.remoteJoined) {
      await _markTerminal(
        inviteId: inviteId,
        status: CallInviteStatus.ended,
        message: 'Call ended',
        isError: false,
        actorIsCaller: isCaller,
        endReason: 'remote_left:$reason',
      );
      return;
    }

    await _markTerminal(
      inviteId: inviteId,
      status: CallInviteStatus.failed,
      message: 'User unavailable',
      isError: true,
      actorIsCaller: isCaller,
      endReason: 'remote_unavailable:$reason',
      error: 'Remote user went offline before the call connected.',
    );
  }

  Future<void> reportJoinTimeout({
    required String inviteId,
    required bool isCaller,
  }) async {
    await _markTerminal(
      inviteId: inviteId,
      status: CallInviteStatus.failed,
      message: 'Call connection timed out. Please try again.',
      isError: true,
      actorIsCaller: isCaller,
      endReason: 'agora_join_timeout',
      error: 'Agora join watchdog timed out before the call connected.',
    );
  }

  Future<void> reportCallFailure({
    required String inviteId,
    required bool isCaller,
    required String message,
    String? error,
  }) async {
    await _markTerminal(
      inviteId: inviteId,
      status: CallInviteStatus.failed,
      message: message,
      isError: true,
      actorIsCaller: isCaller,
      endReason: 'agora_failure',
      error: error ?? message,
    );
  }

  Future<void> endCallFromLocalUser({
    required String inviteId,
    String source = 'local_end',
    int? lifecycleGeneration,
    String acceptedCallkitId = '',
  }) async {
    final session = _current;
    if (session == null ||
        !_sessionMatchesOwnership(
          session,
          inviteId: inviteId,
          lifecycleGeneration: lifecycleGeneration,
          acceptedCallkitId: acceptedCallkitId,
        )) {
      return;
    }
    if (session.isTerminal) return;

    await _markTerminal(
      inviteId: inviteId,
      status: CallInviteStatus.ended,
      message: 'Call ended',
      isError: false,
      actorIsCaller: session.isCaller,
      endReason: source,
      authoritativeLocalExit: true,
      expectedSession: session,
    );
  }

  Future<void> handleCallScreenClosed(
    String inviteId, {
    int? lifecycleGeneration,
    String acceptedCallkitId = '',
  }) async {
    final session = _current;
    if (session == null ||
        !_sessionMatchesOwnership(
          session,
          inviteId: inviteId,
          lifecycleGeneration: lifecycleGeneration,
          acceptedCallkitId: acceptedCallkitId,
        )) {
      return;
    }
    if (!session.isTerminal) {
      await endCallFromLocalUser(
        inviteId: inviteId,
        source: 'screen_closed',
        lifecycleGeneration: session.lifecycleGeneration,
        acceptedCallkitId: session.acceptedCallkitId,
      );
    }
    if (identical(_current, session) && session.isTerminal) {
      await _finalizeTerminalSessionCleanup(
        inviteId: inviteId,
        reason: 'call_screen_closed',
        forceClearUiFlags: true,
        expectedLifecycleGeneration: session.lifecycleGeneration,
        expectedCallkitId: session.acceptedCallkitId,
      );
    }
  }

  Future<void> _handleIncomingInviteSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String source,
  }) async {
    final data = doc.data();
    if (data == null) return;
    final inviteId = doc.id.trim();
    if (inviteId.isEmpty) return;

    final status = _parseStatus(data['status']);
    if (status != CallInviteStatus.ringing) {
      if (_isTerminalStatus(status) && _incomingPromptInviteId == inviteId) {
        await _terminalizeUnacceptedIncomingInvite(
          inviteId: inviteId,
          status: status,
          source: source,
          channel: (data['channel'] ?? '').toString().trim(),
        );
      }
      return;
    }

    final created = (data['createdAt'] as Timestamp?)?.toDate();
    if (created != null &&
        DateTime.now().difference(created) > const Duration(minutes: 2)) {
      return;
    }
    final toUid = (data['toUid'] ?? '').toString().trim();
    final currentUid = _currentUid.trim();
    if (currentUid.isEmpty || toUid != currentUid) return;
    if (_isInviteHandledRecently(inviteId) && activeInviteId != inviteId) {
      return;
    }

    final payload = CallInvitePayload(
      inviteId: inviteId,
      channel: (data['channel'] ?? '').toString().trim(),
      isVideo: _truthy(data['isVideo']),
      fromName: (data['fromName'] ?? 'Caller').toString(),
      fromUid: (data['fromUid'] ?? '').toString().trim(),
      toUid: toUid,
      connectionSystem: callConnectionSystemFromInviteValue(
        data['callSystem'],
      ),
    );
    if (payload.channel.isEmpty) return;
    await _handleIncomingCandidate(
      payload,
      source: source,
      via: 'firestore_snapshot',
    );
  }

  bool _recordPendingAcceptedIntent(
    CallInvitePayload payload, {
    required int ownerGeneration,
  }) {
    if (!_callLifecycleArbiter.recordPendingAcceptedIntent(
      generation: ownerGeneration,
      inviteId: payload.inviteId,
    )) {
      return false;
    }
    final current = _pendingAcceptedInviteIntent;
    if (current == null ||
        !current.matchesIdentity(payload) ||
        current.ownerGeneration != ownerGeneration) {
      _acceptedRouteContinuation = null;
      _pendingAcceptedInviteIntent = _PendingAcceptedInviteIntent(
        payload: payload,
        ownerGeneration: ownerGeneration,
      );
      _pendingAcceptedRecorded = true;
      _pendingAcceptedClaimed = false;
      _pendingAcceptedContinuationStarted = false;
      _pendingAcceptedContinuationCompleted = false;
      _acceptedRouteResumeTriggered = false;
      _acceptedRouteNavigatorUnavailable = false;
      _acceptedRouteOpened = false;
      _acceptedRouteDiscarded = false;
      _acceptedRouteAppResumed = false;
      _acceptedOwnershipRecorded = true;
      CallV2PhysicalDiagnosticLedger.instance.record(
        CallV2PhysicalDiagnosticStage.acceptedOwnershipRecorded,
        exactNativeKey: payload.acceptedCallkitId,
      );
    }
    _ensureAcceptedNativeRouteWatch(
      payload: payload,
      lifecycleGeneration: ownerGeneration,
      claimed: false,
    );
    return true;
  }

  _PendingAcceptedInviteIntent? _claimPendingAcceptedIntent(
    CallV2PendingClaim claim,
  ) {
    final claimedInviteId = claim.inviteId;
    if (!claim.acceptedIntent || claimedInviteId == null) return null;
    final current = _pendingAcceptedInviteIntent;
    if (current == null ||
        !current.matchesInvite(claimedInviteId) ||
        current.ownerGeneration + 1 != claim.generation) {
      return null;
    }
    final claimed = current.claimedBy(claim.generation);
    _pendingAcceptedInviteIntent = claimed;
    _pendingAcceptedClaimed = true;
    return claimed;
  }

  void _clearPendingAcceptedIntent({
    String? inviteId,
    int? claimedGeneration,
  }) {
    final current = _pendingAcceptedInviteIntent;
    if (current != null) {
      if (inviteId != null && !current.matchesInvite(inviteId)) return;
      if (claimedGeneration != null &&
          current.claimedGeneration != claimedGeneration) {
        return;
      }
      _pendingAcceptedInviteIntent = null;
    }
    final continuation = _acceptedRouteContinuation;
    if (continuation == null) return;
    if (inviteId != null && continuation.payload.inviteId != inviteId.trim()) {
      return;
    }
    if (claimedGeneration != null &&
        continuation.claimedGeneration != claimedGeneration) {
      return;
    }
    _acceptedRouteContinuation = null;
  }

  void _discardPendingAcceptedIntent() {
    final current = _pendingAcceptedInviteIntent;
    if (current != null) {
      _callLifecycleArbiter.clearPendingInvite(current.payload.inviteId);
      _clearPendingIncomingPrompt(current.payload.inviteId);
    }
    _clearPendingAcceptedIntent();
  }

  void _ownAcceptedRouteContinuation({
    required CallInvitePayload payload,
    required int claimedGeneration,
  }) {
    final current = _acceptedRouteContinuation;
    if (current != null &&
        current.matches(
          inviteId: payload.inviteId,
          generation: claimedGeneration,
        )) {
      return;
    }
    _acceptedRouteContinuation = _AcceptedRouteContinuation(
      payload: payload,
      claimedGeneration: claimedGeneration,
    );
    _acceptedRouteResumeTriggered = false;
    _acceptedRouteNavigatorUnavailable = false;
    _acceptedRouteOpened = false;
    _acceptedRouteDiscarded = false;
    _acceptedRouteAppResumed = false;
    _acceptedOwnershipRecorded = true;
    CallV2PhysicalDiagnosticLedger.instance.record(
      CallV2PhysicalDiagnosticStage.acceptedOwnershipRecorded,
      exactNativeKey: payload.acceptedCallkitId,
    );
    _ensureAcceptedNativeRouteWatch(
      payload: payload,
      lifecycleGeneration: claimedGeneration,
      claimed: true,
    );
  }

  void _recordAcceptedRouteStage(
    CallInvitePayload payload,
    CallV2PhysicalDiagnosticStage stage,
  ) {
    CallV2PhysicalDiagnosticLedger.instance.record(
      stage,
      exactNativeKey: payload.acceptedCallkitId,
    );
  }

  CallInvitePayload _authoritativeAcceptedPayload(
    CallInvitePayload bridgePayload,
    Map<String, dynamic> data,
  ) {
    return CallInvitePayload(
      inviteId: bridgePayload.inviteId,
      channel: (data['channel'] ?? '').toString().trim(),
      isVideo: _truthy(data['isVideo']),
      fromName: (data['fromName'] ?? bridgePayload.fromName).toString(),
      fromUid: (data['fromUid'] ?? '').toString().trim(),
      toUid: (data['toUid'] ?? '').toString().trim(),
      acceptedCallkitId: bridgePayload.acceptedCallkitId,
      connectionSystem: callConnectionSystemFromInviteValue(
        data['callSystem'],
      ),
    );
  }

  void _replaceAcceptedOwnershipPayload({
    required CallInvitePayload previous,
    required CallInvitePayload authoritative,
    required int generation,
  }) {
    final continuation = _acceptedRouteContinuation;
    if (continuation != null &&
        continuation.claimedGeneration == generation &&
        continuation.payload.matchesAcceptedIdentity(previous)) {
      continuation.payload = authoritative;
    }
    final pending = _pendingAcceptedInviteIntent;
    if (pending != null &&
        pending.matchesIdentity(previous) &&
        (pending.ownerGeneration == generation ||
            pending.claimedGeneration == generation)) {
      _pendingAcceptedInviteIntent = _PendingAcceptedInviteIntent(
        payload: authoritative,
        ownerGeneration: pending.ownerGeneration,
        claimedGeneration: pending.claimedGeneration,
      );
    }
    final watch = _acceptedNativeRouteWatch;
    if (watch != null && watch.matchesIdentity(previous)) {
      watch.payload = authoritative;
    }
  }

  void _ensureAcceptedNativeRouteWatch({
    required CallInvitePayload payload,
    required int lifecycleGeneration,
    required bool claimed,
  }) {
    final current = _acceptedNativeRouteWatch;
    if (current != null && current.matchesIdentity(payload)) {
      current.payload =
          payload.acceptedCallkitId.isEmpty ? current.payload : payload;
      current.lifecycleGeneration = lifecycleGeneration;
      current.claimed = current.claimed || claimed;
      _acceptedNativeExactIdPresent =
          current.payload.acceptedCallkitId.isNotEmpty;
      return;
    }
    if (current != null) {
      current.timeoutTimer?.cancel();
      unawaited(current.subscription?.cancel());
    }

    final watch = _AcceptedNativeRouteWatch(
      payload: payload,
      lifecycleGeneration: lifecycleGeneration,
      claimed: claimed,
      startedAt: DateTime.now(),
    );
    _acceptedNativeRouteWatch = watch;
    _acceptedNativeCleanupFuture = null;
    _acceptedNativeWatchTerminalObserved = false;
    _acceptedNativeWatchDeadlineReached = false;
    _acceptedNativeExactIdPresent = payload.acceptedCallkitId.isNotEmpty;
    _nativeEndRequested = false;
    _nativeEndVerified = false;
    _nativeEndEscalated = false;
    _acceptedNativeWatchBlockerCode = 'none';

    if (!_skipAcceptedNativeWatchBindingForTest) {
      watch.subscription = _db
          .collection('callInvites')
          .doc(payload.inviteId)
          .snapshots()
          .listen(
        (snapshot) {
          unawaited(_handleAcceptedNativeWatchSnapshot(watch, snapshot));
        },
        onError: (Object error) {
          if (!identical(_acceptedNativeRouteWatch, watch)) return;
          unawaited(_diagManager('accepted_native_watch_listener_error', meta: {
            'acceptedNativeWatchActive': true,
            'blockerCode': 'accepted_native_watch_listener_error',
          }));
        },
      );
    }
    watch.timeoutTimer = Timer(_acceptedNativeWatchTimeout, () {
      unawaited(_handleAcceptedNativeWatchDeadline(watch));
    });
    unawaited(_refreshAcceptedNativeMatchingCallCount(watch));
  }

  Future<void> _handleAcceptedNativeWatchSnapshot(
    _AcceptedNativeRouteWatch watch,
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) async {
    if (!identical(_acceptedNativeRouteWatch, watch) ||
        watch.routeOpened ||
        watch.terminal) {
      return;
    }
    if (_callRouteActive && activeInviteId == watch.payload.inviteId) {
      await _transferAcceptedNativeWatchToRoute(watch);
      return;
    }
    final status = _parseStatus(snapshot.data()?['status']);
    if (snapshot.exists && !_isTerminalStatus(status)) return;
    _acceptedNativeWatchTerminalObserved = true;
    _acceptedRouteTerminalObserved = true;
    await _resolveAcceptedNativeRouteWatch(
      watch,
      reason: 'accepted_native_authoritative_terminal',
      deadlineReached: false,
      markInviteFailed: false,
    );
  }

  Future<void> _handleAcceptedNativeWatchDeadline(
    _AcceptedNativeRouteWatch watch,
  ) async {
    if (!identical(_acceptedNativeRouteWatch, watch) ||
        watch.routeOpened ||
        watch.terminal) {
      return;
    }
    _acceptedNativeWatchDeadlineReached = true;
    Map<String, dynamic>? latest;
    try {
      latest = await _readInviteData(watch.payload.inviteId);
    } catch (_) {}
    if (!identical(_acceptedNativeRouteWatch, watch) || watch.routeOpened) {
      return;
    }
    final status = _parseStatus(latest?['status']);
    final terminal = latest == null || _isTerminalStatus(status);
    _acceptedNativeWatchTerminalObserved = terminal;
    _acceptedRouteTerminalObserved = terminal;
    await _resolveAcceptedNativeRouteWatch(
      watch,
      reason: 'accepted_native_watch_deadline',
      deadlineReached: true,
      markInviteFailed: !terminal,
    );
  }

  Future<void> _resolveAcceptedNativeRouteWatch(
    _AcceptedNativeRouteWatch watch, {
    required String reason,
    required bool deadlineReached,
    required bool markInviteFailed,
  }) async {
    final existing = watch.cleanupFuture;
    if (existing != null) return existing;
    late final Future<void> future;
    future = _performAcceptedNativeRouteWatchCleanup(
      watch,
      reason: reason,
      deadlineReached: deadlineReached,
      markInviteFailed: markInviteFailed,
    );
    watch.cleanupFuture = future;
    _acceptedNativeCleanupFuture = future;
    await future;
  }

  Future<void> _performAcceptedNativeRouteWatchCleanup(
    _AcceptedNativeRouteWatch watch, {
    required String reason,
    required bool deadlineReached,
    required bool markInviteFailed,
  }) async {
    if (!identical(_acceptedNativeRouteWatch, watch) || watch.routeOpened)
      return;
    if (_callRouteActive && activeInviteId == watch.payload.inviteId) {
      await _transferAcceptedNativeWatchToRoute(watch);
      return;
    }

    watch.terminal = true;
    watch.timeoutTimer?.cancel();
    watch.timeoutTimer = null;
    final subscription = watch.subscription;
    watch.subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    _cancelAcceptedRouteReadiness?.call();

    if (watch.claimed &&
        _callLifecycleArbiter.ownsGeneration(watch.lifecycleGeneration)) {
      _callLifecycleArbiter.beginEnding(watch.lifecycleGeneration);
      _callLifecycleArbiter.beginTeardown(watch.lifecycleGeneration);
    }

    if (markInviteFailed) {
      await _setInviteStatusIfCurrent(
        inviteId: watch.payload.inviteId,
        expectedStatuses: const <CallInviteStatus>{
          CallInviteStatus.ringing,
          CallInviteStatus.accepted,
          CallInviteStatus.joining,
          CallInviteStatus.connected,
        },
        updates: <String, dynamic>{
          'status': CallInviteStatus.failed.name,
          'calleeStage': CallInviteStatus.failed.name,
          'failedAt': FieldValue.serverTimestamp(),
          'endedBy': _currentUid,
          'endReason': 'accepted_native_route_watch_deadline',
        },
      );
    }

    await _markNativeInviteStateSafely(
      watch.payload,
      state: 'terminal',
      reason: reason,
    );
    await _endAcceptedNativeCallVerified(watch, reason: reason);
    await _clearStoredAcceptedCallRecoverySafely(
      reason,
      inviteId: watch.payload.inviteId,
      callkitId: watch.payload.acceptedCallkitId,
    );

    _clearPendingIncomingPrompt(watch.payload.inviteId);
    _callLifecycleArbiter.clearPendingInvite(watch.payload.inviteId);
    _clearPendingAcceptedIntent(
      inviteId: watch.payload.inviteId,
      claimedGeneration: watch.claimed ? watch.lifecycleGeneration : null,
    );
    _acceptedRouteDiscarded = true;
    _acceptedRecoveryPending = false;
    _acceptedRecoveryAcknowledged = true;

    if (watch.claimed &&
        _callLifecycleArbiter.ownsGeneration(watch.lifecycleGeneration)) {
      final currentSession = _current;
      if (currentSession != null && watch.matchesSession(currentSession)) {
        await _activeInviteSub?.cancel();
        _activeInviteSub = null;
        _cancelSessionTimers();
        _clearCallRouteOwnershipForSession(currentSession);
        _current = null;
        _openingCallRoute = false;
      }
      final pendingPayload = _pendingIncomingPromptPayload;
      final pendingSource = _pendingIncomingPromptSource;
      final pendingClaim = _callLifecycleArbiter
          .completeTeardownAndClaimPending(watch.lifecycleGeneration);
      await _continueClaimedPendingIncoming(
        pendingClaim: pendingClaim,
        pendingPayload: pendingPayload,
        pendingSource: pendingSource,
        source: '$reason:terminal_complete',
      );
    }

    if (identical(_acceptedNativeRouteWatch, watch)) {
      _acceptedNativeRouteWatch = null;
    }
    await _diagManager('accepted_native_watch_resolved', meta: {
      'acceptedNativeWatchActive': false,
      'acceptedNativeWatchTerminalObserved':
          _acceptedNativeWatchTerminalObserved,
      'acceptedNativeWatchDeadlineReached': deadlineReached,
      'acceptedNativeExactIdPresent': _acceptedNativeExactIdPresent,
      'nativeEndRequested': _nativeEndRequested,
      'nativeEndVerified': _nativeEndVerified,
      'nativeEndEscalated': _nativeEndEscalated,
      'matchingNativeCallCount': _acceptedNativeMatchingCallCount,
      'sessionIdle': isIdleForDebug,
      'blockerCode': _acceptedNativeWatchBlockerCode,
    });
  }

  Future<void> _transferAcceptedNativeWatchToRoute(
    _AcceptedNativeRouteWatch watch,
  ) async {
    if (!identical(_acceptedNativeRouteWatch, watch)) return;
    watch.routeOpened = true;
    watch.timeoutTimer?.cancel();
    watch.timeoutTimer = null;
    final subscription = watch.subscription;
    watch.subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    if (identical(_acceptedNativeRouteWatch, watch)) {
      _acceptedNativeRouteWatch = null;
    }
    _acceptedNativeCleanupFuture = null;
  }

  Future<void> _refreshAcceptedNativeMatchingCallCount(
    _AcceptedNativeRouteWatch watch,
  ) async {
    final exactId = watch.payload.acceptedCallkitId.trim().toLowerCase();
    if (exactId.isEmpty || !identical(_acceptedNativeRouteWatch, watch)) return;
    final active = await _listNativeCallsSafely();
    if (!identical(_acceptedNativeRouteWatch, watch)) return;
    _acceptedNativeMatchingCallCount = active
        .where((call) => call.callkitId.trim().toLowerCase() == exactId)
        .length;
  }

  Future<void> _endAcceptedNativeCallVerified(
    _AcceptedNativeRouteWatch watch, {
    required String reason,
  }) async {
    final exactId = watch.payload.acceptedCallkitId.trim();
    final fallbackId = exactId.isNotEmpty
        ? exactId
        : normalizeCallkitId(
            rawId: watch.payload.inviteId,
            fallback: watch.payload.channel,
          );
    if (fallbackId.isEmpty) {
      _acceptedNativeWatchBlockerCode = 'native_end_identifier_missing';
      return;
    }
    _nativeEndRequested = true;
    await _endNativeCallSafely(
      fallbackId,
      reason: '$reason:accepted_native_exact_end',
    );
    if (_acceptedNativeEndVerificationDelay > Duration.zero) {
      await Future<void>.delayed(_acceptedNativeEndVerificationDelay);
    }
    var active = await _listNativeCallsSafely();
    var matching = active.where((call) {
      return call.callkitId.trim().toLowerCase() == fallbackId.toLowerCase();
    }).length;
    _acceptedNativeMatchingCallCount = matching;
    if (matching > 0) {
      _nativeEndEscalated = true;
      await _endNativeCallSafely(
        fallbackId,
        reason: '$reason:accepted_native_exact_escalation',
      );
      if (_acceptedNativeEndVerificationDelay > Duration.zero) {
        await Future<void>.delayed(_acceptedNativeEndVerificationDelay);
      }
      active = await _listNativeCallsSafely();
      matching = active.where((call) {
        return call.callkitId.trim().toLowerCase() == fallbackId.toLowerCase();
      }).length;
      _acceptedNativeMatchingCallCount = matching;
    }
    _nativeEndVerified = matching == 0;
    if (!_nativeEndVerified) {
      _acceptedNativeWatchBlockerCode = 'native_end_unverified';
    }
  }

  Future<AcceptedCallRecoveryResult> resumePendingAcceptedRouteIfReady({
    String source = 'app_resumed',
  }) async {
    final continuation = _acceptedRouteContinuation;
    if (continuation == null) {
      if (_acceptedRouteTerminalObserved) {
        await _awaitAcceptedNativeTerminalCleanup();
        return AcceptedCallRecoveryResult.terminal;
      }
      return _pendingAcceptedInviteIntent == null
          ? AcceptedCallRecoveryResult.invalid
          : AcceptedCallRecoveryResult.pendingTeardown;
    }
    _acceptedRouteResumeTriggered = true;
    _acceptedRouteAppResumed = await _isAppActuallyForeground();

    final inFlight = _acceptedRouteContinuationFuture;
    if (inFlight != null) return inFlight;

    late final Future<AcceptedCallRecoveryResult> future;
    future = _resumeAcceptedRouteContinuation(
      continuation,
      source: source,
    );
    _acceptedRouteContinuationFuture = future;
    _acceptedRouteAttemptInFlight = true;
    try {
      return await future;
    } finally {
      if (identical(_acceptedRouteContinuationFuture, future)) {
        _acceptedRouteContinuationFuture = null;
        _acceptedRouteAttemptInFlight = false;
      }
    }
  }

  Future<AcceptedCallRecoveryResult> resolvePendingAcceptedRouteDeadline({
    String source = 'accepted_route_readiness_deadline',
  }) async {
    _acceptedRouteDeadlineReached = true;
    final acceptedNativeWatch = _acceptedNativeRouteWatch;
    if (acceptedNativeWatch != null) {
      await _resolveAcceptedNativeRouteWatch(
        acceptedNativeWatch,
        reason: source,
        deadlineReached: true,
        markInviteFailed: true,
      );
      return AcceptedCallRecoveryResult.terminal;
    }
    final continuation = _acceptedRouteContinuation;
    final intent = _pendingAcceptedInviteIntent;
    final payload = continuation?.payload ?? intent?.payload;
    if (payload == null) return AcceptedCallRecoveryResult.invalid;

    Map<String, dynamic>? latest;
    try {
      latest = await _readInviteData(payload.inviteId);
    } catch (_) {}
    final latestStatus = _parseStatus(latest?['status']);
    final authoritativeTerminal =
        latest == null || _isTerminalStatus(latestStatus);
    _acceptedRouteTerminalObserved = authoritativeTerminal;

    if (!authoritativeTerminal) {
      await _setInviteStatusIfCurrent(
        inviteId: payload.inviteId,
        expectedStatuses: const <CallInviteStatus>{
          CallInviteStatus.ringing,
          CallInviteStatus.accepted,
          CallInviteStatus.joining,
          CallInviteStatus.connected,
        },
        updates: <String, dynamic>{
          'status': CallInviteStatus.failed.name,
          'calleeStage': CallInviteStatus.failed.name,
          'failedAt': FieldValue.serverTimestamp(),
          'endedBy': _currentUid,
          'endReason': 'accepted_route_readiness_deadline',
        },
      );
    }

    _acceptedRouteDiscarded = true;
    _clearPendingIncomingPrompt(payload.inviteId);
    _callLifecycleArbiter.clearPendingInvite(payload.inviteId);
    _clearPendingAcceptedIntent(
      inviteId: payload.inviteId,
      claimedGeneration: continuation?.claimedGeneration,
    );
    await _markNativeInviteStateSafely(
      payload,
      state: 'terminal',
      reason: source,
    );
    await _endNativeCallForInvite(
      inviteId: payload.inviteId,
      channel: payload.channel,
      callkitId: payload.acceptedCallkitId,
      reason: source,
    );

    final generation = continuation?.claimedGeneration;
    if (generation != null &&
        _callLifecycleArbiter.ownsGeneration(generation)) {
      _callLifecycleArbiter.beginEnding(generation);
      _callLifecycleArbiter.beginTeardown(generation);
      final pendingPayload = _pendingIncomingPromptPayload;
      final pendingSource = _pendingIncomingPromptSource;
      final pendingClaim =
          _callLifecycleArbiter.completeTeardownAndClaimPending(generation);
      await _continueClaimedPendingIncoming(
        pendingClaim: pendingClaim,
        pendingPayload: pendingPayload,
        pendingSource: pendingSource,
        source: '$source:terminal_complete',
      );
    }

    _acceptedRecoveryPending = false;
    _acceptedRecoveryAcknowledged = true;
    await _clearStoredAcceptedCallRecoverySafely(
      source,
      inviteId: payload.inviteId,
      callkitId: payload.acceptedCallkitId,
    );
    await _diagManager('accepted_route_deadline_resolved', meta: {
      'acceptedRouteDeadlineReached': true,
      'acceptedRouteTerminalObserved': authoritativeTerminal,
      'acceptedRoutePending': hasPendingAcceptedRouteOwnership,
      'sessionIdle': isIdleForDebug,
    });
    return AcceptedCallRecoveryResult.terminal;
  }

  Future<AcceptedCallRecoveryResult> _resumeAcceptedRouteContinuation(
    _AcceptedRouteContinuation continuation, {
    required String source,
  }) async {
    _recordAcceptedRouteStage(
      continuation.payload,
      CallV2PhysicalDiagnosticStage.acceptedContinuationResumeStarted,
    );
    if (!identical(_acceptedRouteContinuation, continuation) ||
        !_callLifecycleArbiter.ownsGeneration(
          continuation.claimedGeneration,
        )) {
      _recordAcceptedRouteStage(
        continuation.payload,
        CallV2PhysicalDiagnosticStage.acceptedContinuationInvalidGeneration,
      );
      _acceptedRouteDiscarded = true;
      _clearPendingAcceptedIntent(
        inviteId: continuation.payload.inviteId,
        claimedGeneration: continuation.claimedGeneration,
      );
      return AcceptedCallRecoveryResult.invalid;
    }
    if (_callRouteActive && activeInviteId == continuation.payload.inviteId) {
      final watch = _acceptedNativeRouteWatch;
      if (watch != null && watch.matchesIdentity(continuation.payload)) {
        await _transferAcceptedNativeWatchToRoute(watch);
      }
      _acceptedRouteOpened = true;
      _pendingAcceptedContinuationCompleted = true;
      _clearPendingAcceptedIntent(
        inviteId: continuation.payload.inviteId,
        claimedGeneration: continuation.claimedGeneration,
      );
      return AcceptedCallRecoveryResult.alreadyOpen;
    }

    final result = continuation.acceptanceConfirmed
        ? await _openConfirmedAcceptedRoute(
            continuation,
            latestStatus: continuation.authoritativeStatus,
            source: source,
          )
        : await _acceptInviteAndOpen(
            continuation.payload,
            source: '$source:accepted_route_resume',
            lifecycleGeneration: continuation.claimedGeneration,
            preserveLifecycleOnNavigatorUnavailable: true,
          );
    if (result == _IncomingCandidateResult.opened ||
        result == _IncomingCandidateResult.alreadyOpen) {
      final watch = _acceptedNativeRouteWatch;
      if (watch != null && watch.matchesIdentity(continuation.payload)) {
        await _transferAcceptedNativeWatchToRoute(watch);
      }
      _acceptedRouteOpened = true;
      _pendingAcceptedContinuationCompleted = true;
      _acceptedRecoveryPending = false;
      _acceptedRecoveryAcknowledged = true;
      _clearPendingAcceptedIntent(
        inviteId: continuation.payload.inviteId,
        claimedGeneration: continuation.claimedGeneration,
      );
      await _clearStoredAcceptedCallRecoverySafely(
        'accepted_route_opened',
        inviteId: continuation.payload.inviteId,
        callkitId: continuation.payload.acceptedCallkitId,
      );
      await _diagManager('accepted_route_continuation_completed', meta: {
        'acceptedRouteOpened': true,
        'routeOpenCount': _routeOpenCount,
        'rtcSetupOwnerCount': _rtcSetupOwnerCount,
      });
      return result == _IncomingCandidateResult.alreadyOpen
          ? AcceptedCallRecoveryResult.alreadyOpen
          : AcceptedCallRecoveryResult.opened;
    }
    if (result == _IncomingCandidateResult.pending ||
        result == _IncomingCandidateResult.acceptedPending) {
      _acceptedRouteNavigatorUnavailable = true;
      await _diagManager('accepted_route_navigator_unavailable', meta: {
        'acceptedRoutePending': true,
        'acceptedRouteNavigatorUnavailable': true,
        'navigatorReady': _navigatorKey?.currentState?.mounted == true,
      });
      return AcceptedCallRecoveryResult.pendingNavigator;
    }
    if (result == _IncomingCandidateResult.busy) {
      return AcceptedCallRecoveryResult.busy;
    }
    if (result == _IncomingCandidateResult.networkPending) {
      _recordAcceptedRouteStage(
        continuation.payload,
        CallV2PhysicalDiagnosticStage.acceptedContinuationPendingNetwork,
      );
      return AcceptedCallRecoveryResult.pendingNetwork;
    }
    if (result == _IncomingCandidateResult.terminal) {
      await _awaitAcceptedNativeTerminalCleanup();
      return AcceptedCallRecoveryResult.terminal;
    }
    if (result == _IncomingCandidateResult.ignored) {
      if (_acceptedRouteTerminalObserved) {
        await _awaitAcceptedNativeTerminalCleanup();
        return AcceptedCallRecoveryResult.terminal;
      }
      _acceptedRouteDiscarded = true;
      _clearPendingAcceptedIntent(
        inviteId: continuation.payload.inviteId,
        claimedGeneration: continuation.claimedGeneration,
      );
      return AcceptedCallRecoveryResult.invalid;
    }
    return AcceptedCallRecoveryResult.failed;
  }

  Future<_IncomingCandidateResult> _openConfirmedAcceptedRoute(
    _AcceptedRouteContinuation continuation, {
    required CallInviteStatus latestStatus,
    required String source,
  }) async {
    if (!identical(_acceptedRouteContinuation, continuation) ||
        !_callLifecycleArbiter.ownsGeneration(
          continuation.claimedGeneration,
        )) {
      return _IncomingCandidateResult.ignored;
    }
    final payload = continuation.payload;
    final session = _CallSession(
      inviteId: payload.inviteId,
      channel: payload.channel,
      isVideo: payload.isVideo,
      isCaller: false,
      otherUserId: payload.fromUid,
      otherUserName: payload.fromName,
      phase: CallSessionPhase.accepted,
      status: latestStatus == CallInviteStatus.ringing
          ? CallInviteStatus.accepted
          : latestStatus,
      connectionSystem: payload.connectionSystem,
      acceptedCallkitId: payload.acceptedCallkitId,
      lifecycleGeneration: continuation.claimedGeneration,
    );
    _callLifecycleArbiter.markJoining(continuation.claimedGeneration);
    final routeResult = await _activateSession(
      session,
      openScreen: true,
      source: '$source:confirmed_accepted_route',
      deferUntilNavigatorReady: true,
    );
    if (routeResult == _RouteOpenResult.opened ||
        routeResult == _RouteOpenResult.alreadyOpenSameInvite) {
      final watch = _acceptedNativeRouteWatch;
      if (watch != null && watch.matchesIdentity(payload)) {
        await _transferAcceptedNativeWatchToRoute(watch);
      }
      await _markNativeInviteStateSafely(
        payload,
        state: 'active',
        reason: 'accepted_route_opened',
      );
      _acceptedRouteOpened = true;
      _pendingAcceptedContinuationCompleted = true;
      _clearPendingAcceptedIntent(
        inviteId: payload.inviteId,
        claimedGeneration: continuation.claimedGeneration,
      );
      return routeResult == _RouteOpenResult.alreadyOpenSameInvite
          ? _IncomingCandidateResult.alreadyOpen
          : _IncomingCandidateResult.opened;
    }
    if (routeResult == _RouteOpenResult.navigatorUnavailable ||
        routeResult == _RouteOpenResult.routeBusy) {
      return _IncomingCandidateResult.pending;
    }
    return _IncomingCandidateResult.failed;
  }

  Future<_IncomingCandidateResult> _handleIncomingCandidate(
    CallInvitePayload payload, {
    required String source,
    required String via,
    bool autoAccept = false,
    bool deferAcceptedOpen = false,
  }) async {
    final reservation = _callLifecycleArbiter.reserveIncoming(payload.inviteId);
    if (reservation.action == CallV2CallReservationAction.duplicate) {
      await _diagManager('incoming_duplicate_suppressed', meta: {
        'source': source,
        'via': via,
      });
      if (autoAccept &&
          _incomingPromptInviteId == payload.inviteId &&
          _incomingUiOwner == IncomingUiOwner.callkit) {
        _callLifecycleArbiter.incomingAccepted(
          generation: reservation.generation,
          inviteId: payload.inviteId,
        );
        _incomingPromptActive = false;
        _incomingPromptInviteId = null;
        _incomingUiOwner = IncomingUiOwner.none;
        _ownAcceptedRouteContinuation(
          payload: payload,
          claimedGeneration: reservation.generation,
        );
        if (deferAcceptedOpen) {
          return _IncomingCandidateResult.acceptedPending;
        }
        return _acceptInviteAndOpen(
          payload,
          source: source,
          lifecycleGeneration: reservation.generation,
          preserveLifecycleOnNavigatorUnavailable: true,
        );
      }
      if (autoAccept &&
          _recordPendingAcceptedIntent(
            payload,
            ownerGeneration: reservation.generation,
          )) {
        _schedulePendingIncomingPrompt(
          payload,
          source: source,
          reason: 'accepted_behind_${reservation.lifecycleState.name}',
        );
        await _diagManager('pending_accept_recorded', meta: {
          'pendingAcceptedRecorded': true,
          'pendingAcceptedIntent': true,
          'callLifecycleState': reservation.lifecycleState.name,
        });
        return _IncomingCandidateResult.acceptedPending;
      }
      final claimedAcceptedIntent = _pendingAcceptedInviteIntent;
      if (autoAccept &&
          claimedAcceptedIntent != null &&
          claimedAcceptedIntent.matchesIdentity(payload) &&
          claimedAcceptedIntent.claimedGeneration == reservation.generation &&
          _callLifecycleArbiter.ownsGeneration(reservation.generation)) {
        final resumed = await resumePendingAcceptedRouteIfReady(
          source: '$source:accepted_duplicate',
        );
        if (resumed == AcceptedCallRecoveryResult.opened) {
          return _IncomingCandidateResult.opened;
        }
        if (resumed == AcceptedCallRecoveryResult.alreadyOpen) {
          return _IncomingCandidateResult.alreadyOpen;
        }
        if (resumed == AcceptedCallRecoveryResult.terminal ||
            resumed == AcceptedCallRecoveryResult.invalid) {
          return _IncomingCandidateResult.ignored;
        }
        return _IncomingCandidateResult.acceptedPending;
      }
      if (_current?.matchesAcceptedPayload(payload) == true &&
          _callRouteActive) {
        return _IncomingCandidateResult.alreadyOpen;
      }
      return _IncomingCandidateResult.ignored;
    }
    if (reservation.action == CallV2CallReservationAction.busyDecline) {
      await _declineInviteTransaction(payload.inviteId,
          source: 'busy_active_call');
      await _endNativeCallForInvite(
        inviteId: payload.inviteId,
        channel: payload.channel,
        reason: 'busy_active_call',
      );
      _markInviteHandled(payload.inviteId);
      await _diagManager('incoming_busy_declined', meta: {
        'source': source,
        'via': via,
      });
      return _IncomingCandidateResult.busy;
    }
    if (reservation.action == CallV2CallReservationAction.pending) {
      final displacedInviteId = reservation.displacedInviteId;
      if (displacedInviteId != null) {
        final displacedWatch = _acceptedNativeRouteWatch;
        if (displacedWatch != null &&
            displacedWatch.matchesInvite(displacedInviteId)) {
          await _resolveAcceptedNativeRouteWatch(
            displacedWatch,
            reason: 'superseded_pending_invite',
            deadlineReached: false,
            markInviteFailed: false,
          );
        }
        _clearPendingAcceptedIntent(inviteId: displacedInviteId);
        await _declineInviteTransaction(
          displacedInviteId,
          source: 'superseded_pending_invite',
        );
        await _endNativeCallForInvite(
          inviteId: displacedInviteId,
          channel: '',
          reason: 'superseded_pending_invite',
        );
        _markInviteHandled(displacedInviteId);
        await _diagManager('incoming_pending_superseded', meta: {
          'source': source,
          'via': via,
        });
      }
      _schedulePendingIncomingPrompt(
        payload,
        source: source,
        reason: 'lifecycle_${reservation.lifecycleState.name}',
      );
      if (autoAccept &&
          _recordPendingAcceptedIntent(
            payload,
            ownerGeneration: reservation.generation,
          )) {
        await _diagManager('pending_accept_recorded', meta: {
          'pendingAcceptedRecorded': true,
          'pendingAcceptedIntent': true,
          'callLifecycleState': reservation.lifecycleState.name,
        });
        return _IncomingCandidateResult.acceptedPending;
      }
      await _diagManager('incoming_pending_recorded', meta: {
        'source': source,
        'via': via,
      });
      return _IncomingCandidateResult.pending;
    }
    if (!reservation.reserved) return _IncomingCandidateResult.ignored;

    if (_hasTrulyActiveCall()) {
      _callLifecycleArbiter.dropIncoming(
        generation: reservation.generation,
        inviteId: payload.inviteId,
      );
      _incomingPromptActive = false;
      _incomingPromptInviteId = null;
      _incomingUiOwner = IncomingUiOwner.none;
      await _declineInviteTransaction(payload.inviteId,
          source: 'busy_active_call');
      await _endNativeCallForInvite(
        inviteId: payload.inviteId,
        channel: payload.channel,
        reason: 'busy_active_call',
      );
      return _IncomingCandidateResult.busy;
    }

    if (autoAccept) {
      _callLifecycleArbiter.incomingAccepted(
        generation: reservation.generation,
        inviteId: payload.inviteId,
      );
      if (_callLifecycleArbiter.state != CallV2CallLifecycleState.joining ||
          !_callLifecycleArbiter.ownsGeneration(reservation.generation)) {
        return _IncomingCandidateResult.ignored;
      }
      _incomingPromptActive = false;
      _incomingPromptInviteId = null;
      _incomingUiOwner = IncomingUiOwner.none;
      _ownAcceptedRouteContinuation(
        payload: payload,
        claimedGeneration: reservation.generation,
      );
      if (deferAcceptedOpen) {
        return _IncomingCandidateResult.acceptedPending;
      }
    }

    await _diagManager('incoming_received', meta: {
      'source': source,
      'via': via,
      'isVideo': payload.isVideo,
      'callV2Selected':
          payload.connectionSystem == CallV2RealCallConnectionSystem.callV2Dev,
    });

    await _runPreflightSweepSafely(reason: 'incoming_candidate:$source');
    if (autoAccept) {
      if (!_canContinueAcceptedRouteGeneration(reservation.generation)) {
        return _IncomingCandidateResult.ignored;
      }
      return _acceptInviteAndOpen(
        payload,
        source: source,
        lifecycleGeneration: reservation.generation,
        preserveLifecycleOnNavigatorUnavailable: true,
      );
    }
    if (!_callLifecycleArbiter.ownsIncoming(
      generation: reservation.generation,
      inviteId: payload.inviteId,
    )) {
      return _IncomingCandidateResult.ignored;
    }
    final owner = await _resolveIncomingUiOwner(payload);
    if (!_callLifecycleArbiter.ownsIncoming(
      generation: reservation.generation,
      inviteId: payload.inviteId,
    )) {
      return _IncomingCandidateResult.ignored;
    }
    if (owner == IncomingUiOwner.callkit) {
      _incomingPromptActive = true;
      _incomingPromptInviteId = payload.inviteId;
      _incomingUiOwner = IncomingUiOwner.callkit;
      await _diagManager('incoming_callkit_owner_selected', meta: {
        'incomingUiOwner': _incomingUiOwner.name,
        'callkitMatchFound': true,
        'source': source,
      });
      return _IncomingCandidateResult.callkitOwned;
    }
    if (owner == IncomingUiOwner.none) {
      _callLifecycleArbiter.dropIncoming(
        generation: reservation.generation,
        inviteId: payload.inviteId,
      );
      _incomingPromptActive = false;
      _incomingPromptInviteId = null;
      _incomingUiOwner = IncomingUiOwner.none;
      await _diagManager('incoming_callkit_owner_unavailable', meta: {
        'source': source,
        'iosCallkitOnlyPolicy': _iosCallkitOnlyIncomingUi,
        'blockerCode': 'callkit_owner_unavailable',
      });
      return _IncomingCandidateResult.ignored;
    }
    _incomingPromptActive = true;
    _incomingPromptInviteId = payload.inviteId;
    _incomingUiOwner = IncomingUiOwner.flutter;
    await _presentIncomingPrompt(
      payload,
      source: source,
      lifecycleGeneration: reservation.generation,
    );
    return _IncomingCandidateResult.flutterPrompted;
  }

  Future<void> _presentIncomingPrompt(
    CallInvitePayload payload, {
    required String source,
    required int lifecycleGeneration,
  }) async {
    if (_iosCallkitOnlyIncomingUi) {
      _iosFlutterIncomingPromptViolationCount += 1;
      _incomingPromptActive = false;
      _incomingPromptInviteId = null;
      _incomingUiOwner = IncomingUiOwner.none;
      _callLifecycleArbiter.dropIncoming(
        generation: lifecycleGeneration,
        inviteId: payload.inviteId,
      );
      await _diagManager('ios_flutter_incoming_prompt_violation', meta: {
        'iosFlutterIncomingPromptViolation': true,
        'iosCallkitOnlyPolicy': true,
        'source': source,
      });
      return;
    }
    if (!_callLifecycleArbiter.ownsIncoming(
      generation: lifecycleGeneration,
      inviteId: payload.inviteId,
    )) return;

    await _waitForAppResumed();
    if (!_callLifecycleArbiter.ownsIncoming(
      generation: lifecycleGeneration,
      inviteId: payload.inviteId,
    )) return;
    if (!await _isAppActuallyForeground()) {
      _callLifecycleArbiter.dropIncoming(
        generation: lifecycleGeneration,
        inviteId: payload.inviteId,
      );
      _incomingPromptActive = false;
      _incomingPromptInviteId = null;
      _incomingUiOwner = IncomingUiOwner.none;
      _schedulePendingIncomingPrompt(
        payload,
        source: source,
        reason: 'app_not_foreground',
      );
      return;
    }

    final nav = await _waitForNavigator();
    if (!_callLifecycleArbiter.ownsIncoming(
      generation: lifecycleGeneration,
      inviteId: payload.inviteId,
    )) return;
    if (nav == null || !nav.mounted) {
      _callLifecycleArbiter.dropIncoming(
        generation: lifecycleGeneration,
        inviteId: payload.inviteId,
      );
      _incomingPromptActive = false;
      _incomingPromptInviteId = null;
      _incomingUiOwner = IncomingUiOwner.none;
      _schedulePendingIncomingPrompt(
        payload,
        source: source,
        reason: 'navigator_unavailable',
      );
      return;
    }

    Map<String, dynamic>? latest;
    try {
      latest = await _readInviteData(payload.inviteId);
    } catch (error) {
      await _diagManager('incoming_verify_fallback', meta: {
        'inviteId': payload.inviteId,
        'channel': payload.channel,
        'source': source,
        'error': '$error',
      });
    }
    if (!_callLifecycleArbiter.ownsIncoming(
      generation: lifecycleGeneration,
      inviteId: payload.inviteId,
    )) return;
    final latestStatus = _parseStatus(latest?['status']);
    if (latest != null && latestStatus != CallInviteStatus.ringing) {
      _callLifecycleArbiter.dropIncoming(
        generation: lifecycleGeneration,
        inviteId: payload.inviteId,
      );
      _incomingPromptActive = false;
      _incomingPromptInviteId = null;
      _incomingUiOwner = IncomingUiOwner.none;
      _clearPendingIncomingPrompt(payload.inviteId);
      return;
    }

    _clearPendingIncomingPrompt(payload.inviteId);
    _markInviteHandled(payload.inviteId);
    _flutterIncomingPromptCount += 1;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? promptSub;
    var routeClosed = false;
    try {
      if (!_callLifecycleArbiter.ownsIncoming(
        generation: lifecycleGeneration,
        inviteId: payload.inviteId,
      )) return;
      promptSub = _db
          .collection('callInvites')
          .doc(payload.inviteId)
          .snapshots()
          .listen((snap) {
        if (routeClosed) return;
        final data = snap.data();
        final status = _parseStatus(data?['status']);
        if (!snap.exists || status != CallInviteStatus.ringing) {
          routeClosed = true;
          if (nav.mounted && nav.canPop()) {
            nav.pop(false);
          }
        }
      }, onError: (Object error) {
        unawaited(_diagManager('incoming_prompt_listener_error', meta: {
          'inviteId': payload.inviteId,
          'channel': payload.channel,
          'source': source,
          'error': '$error',
        }));
      });

      final accepted = await nav.push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => IncomingCallScreen(
            channel: payload.channel,
            isVideo: payload.isVideo,
            fromName: payload.fromName,
          ),
        ),
      );
      routeClosed = true;

      if (accepted == true) {
        _callLifecycleArbiter.incomingAccepted(
          generation: lifecycleGeneration,
          inviteId: payload.inviteId,
        );
        if (_callLifecycleArbiter.state != CallV2CallLifecycleState.joining ||
            !_callLifecycleArbiter.ownsGeneration(lifecycleGeneration)) {
          return;
        }
        await _acceptInviteAndOpen(
          payload,
          source: '$source:prompt_accept',
          lifecycleGeneration: lifecycleGeneration,
        );
      } else {
        await _declineInviteTransaction(
          payload.inviteId,
          source: '$source:prompt_decline',
        );
        await _endNativeCallForInvite(
          inviteId: payload.inviteId,
          channel: payload.channel,
          reason: '$source:prompt_decline',
        );
        _callLifecycleArbiter.incomingDeclined(
          generation: lifecycleGeneration,
          inviteId: payload.inviteId,
        );
      }
    } finally {
      await promptSub?.cancel();
      if (_incomingPromptInviteId == payload.inviteId) {
        _incomingPromptActive = false;
        _incomingPromptInviteId = null;
        _incomingUiOwner = IncomingUiOwner.none;
      }
    }
  }

  Future<_IncomingCandidateResult> _acceptInviteAndOpen(
    CallInvitePayload payload, {
    required String source,
    int? lifecycleGeneration,
    bool preserveLifecycleOnNavigatorUnavailable = false,
  }) async {
    if (lifecycleGeneration != null &&
        !_canContinueAcceptedRouteGeneration(lifecycleGeneration)) {
      return _IncomingCandidateResult.ignored;
    }
    await _diagManager('accept_tap', meta: {
      'inviteId': payload.inviteId,
      'channel': payload.channel,
      'source': source,
    });
    await _runPreflightSweepSafely(
      reason: 'accept_preflight:$source',
      inviteId: payload.inviteId,
      channel: payload.channel,
    );
    if (lifecycleGeneration != null &&
        !_canContinueAcceptedRouteGeneration(lifecycleGeneration)) {
      return _IncomingCandidateResult.ignored;
    }
    if (_hasTrulyActiveCall() &&
        _current?.matchesAcceptedPayload(payload) != true) {
      await _declineInviteTransaction(payload.inviteId,
          source: 'busy_active_call');
      if (lifecycleGeneration != null) {
        _releaseFailedIncomingGeneration(lifecycleGeneration);
      }
      return _IncomingCandidateResult.busy;
    }

    final acceptResult = await _acceptInviteTransactionWithRetry(
      payload,
      source: source,
      lifecycleGeneration: lifecycleGeneration,
    );
    if (lifecycleGeneration != null &&
        !_canContinueAcceptedRouteGeneration(lifecycleGeneration)) {
      return _IncomingCandidateResult.ignored;
    }
    if (acceptResult.decision == _AcceptInviteDecision.superseded) {
      return _IncomingCandidateResult.ignored;
    }
    if (acceptResult.decision == _AcceptInviteDecision.unavailable) {
      return _IncomingCandidateResult.networkPending;
    }
    if (!acceptResult.accepted) {
      final terminal = acceptResult.decision == _AcceptInviteDecision.missing ||
          acceptResult.decision == _AcceptInviteDecision.terminal;
      final watch = _acceptedNativeRouteWatch;
      if (watch != null && watch.matchesIdentity(payload)) {
        await _resolveAcceptedNativeRouteWatch(
          watch,
          reason: 'accept_transaction_${acceptResult.decision.name}',
          deadlineReached: false,
          markInviteFailed: false,
        );
      } else if (lifecycleGeneration != null) {
        _releaseFailedIncomingGeneration(lifecycleGeneration);
      }
      return terminal
          ? _IncomingCandidateResult.terminal
          : _IncomingCandidateResult.ignored;
    }
    final authoritativePayload = acceptResult.authoritativePayload;
    if (authoritativePayload == null) {
      if (lifecycleGeneration != null) {
        _releaseFailedIncomingGeneration(lifecycleGeneration);
      }
      return _IncomingCandidateResult.failed;
    }
    final acceptedRouteContinuation = _acceptedRouteContinuation;
    if (lifecycleGeneration != null &&
        acceptedRouteContinuation != null &&
        acceptedRouteContinuation.matches(
          inviteId: payload.inviteId,
          generation: lifecycleGeneration,
        )) {
      _replaceAcceptedOwnershipPayload(
        previous: payload,
        authoritative: authoritativePayload,
        generation: lifecycleGeneration,
      );
      acceptedRouteContinuation.acceptanceConfirmed = true;
      acceptedRouteContinuation.authoritativeStatus =
          acceptResult.authoritativeStatus;
    }
    await _diagManager('accepted', meta: {
      'inviteId': payload.inviteId,
      'channel': payload.channel,
      'source': source,
      'result': acceptResult.decision.name,
    });
    if (lifecycleGeneration != null &&
        !_canContinueAcceptedRouteGeneration(lifecycleGeneration)) {
      return _IncomingCandidateResult.ignored;
    }
    if (source.contains('callkit')) {
      _callkitAcceptCount += 1;
    }
    await _markNativeInviteStateSafely(
      authoritativePayload,
      state: 'accepted',
      reason: 'accept_invite_and_open',
    );
    if (lifecycleGeneration != null &&
        !_canContinueAcceptedRouteGeneration(lifecycleGeneration)) {
      return _IncomingCandidateResult.ignored;
    }
    final latestStatus = acceptResult.authoritativeStatus;
    _recordAcceptedRouteStage(
      authoritativePayload,
      CallV2PhysicalDiagnosticStage.acceptedContinuationOpenRequested,
    );

    final generation = lifecycleGeneration ?? _callLifecycleArbiter.generation;
    final session = _CallSession(
      inviteId: authoritativePayload.inviteId,
      channel: authoritativePayload.channel,
      isVideo: authoritativePayload.isVideo,
      isCaller: false,
      otherUserId: authoritativePayload.fromUid,
      otherUserName: authoritativePayload.fromName,
      phase: CallSessionPhase.accepted,
      status: latestStatus == CallInviteStatus.ringing
          ? CallInviteStatus.accepted
          : latestStatus,
      connectionSystem: authoritativePayload.connectionSystem,
      acceptedCallkitId: authoritativePayload.acceptedCallkitId,
      lifecycleGeneration: generation,
    );

    _callLifecycleArbiter.markJoining(generation);
    final routeResult = await _activateSession(
      session,
      openScreen: true,
      source: source,
      deferUntilNavigatorReady: preserveLifecycleOnNavigatorUnavailable,
    );
    if (routeResult == _RouteOpenResult.opened) {
      final watch = _acceptedNativeRouteWatch;
      if (watch != null && watch.matchesIdentity(authoritativePayload)) {
        await _transferAcceptedNativeWatchToRoute(watch);
      }
      await _markNativeInviteStateSafely(
        authoritativePayload,
        state: 'active',
        reason: 'route_opened',
      );
      _pendingAcceptedContinuationCompleted =
          _pendingAcceptedInviteIntent?.matchesIdentity(authoritativePayload) ==
              true;
      _acceptedRouteOpened = _acceptedRouteContinuation?.matches(
            inviteId: payload.inviteId,
            generation: generation,
          ) ==
          true;
      _clearPendingAcceptedIntent(
        inviteId: authoritativePayload.inviteId,
        claimedGeneration: generation,
      );
      return _IncomingCandidateResult.opened;
    }
    if (routeResult == _RouteOpenResult.alreadyOpenSameInvite) {
      final watch = _acceptedNativeRouteWatch;
      if (watch != null && watch.matchesIdentity(authoritativePayload)) {
        await _transferAcceptedNativeWatchToRoute(watch);
      }
      await _markNativeInviteStateSafely(
        authoritativePayload,
        state: 'active',
        reason: 'route_already_open',
      );
      _pendingAcceptedContinuationCompleted =
          _pendingAcceptedInviteIntent?.matchesIdentity(authoritativePayload) ==
              true;
      _acceptedRouteOpened = _acceptedRouteContinuation?.matches(
            inviteId: payload.inviteId,
            generation: generation,
          ) ==
          true;
      _clearPendingAcceptedIntent(
        inviteId: authoritativePayload.inviteId,
        claimedGeneration: generation,
      );
      return _IncomingCandidateResult.alreadyOpen;
    }
    if (preserveLifecycleOnNavigatorUnavailable &&
        (routeResult == _RouteOpenResult.navigatorUnavailable ||
            routeResult == _RouteOpenResult.routeBusy)) {
      return _IncomingCandidateResult.pending;
    }
    if (preserveLifecycleOnNavigatorUnavailable &&
        routeResult == _RouteOpenResult.failed) {
      return _IncomingCandidateResult.failed;
    }
    _releaseFailedIncomingGeneration(generation);
    return routeResult == _RouteOpenResult.navigatorUnavailable
        ? _IncomingCandidateResult.pending
        : _IncomingCandidateResult.failed;
  }

  bool _canContinueAcceptedRouteGeneration(int lifecycleGeneration) {
    if (!_callLifecycleArbiter.ownsGeneration(lifecycleGeneration)) {
      return false;
    }
    return _callLifecycleArbiter.state != CallV2CallLifecycleState.idle &&
        _callLifecycleArbiter.state != CallV2CallLifecycleState.ending &&
        _callLifecycleArbiter.state != CallV2CallLifecycleState.teardown;
  }

  void _releaseFailedIncomingGeneration(int lifecycleGeneration) {
    _callLifecycleArbiter.beginTeardown(lifecycleGeneration);
    final claim = _callLifecycleArbiter.completeTeardownAndClaimPending(
      lifecycleGeneration,
    );
    final claimedInviteId = claim.inviteId;
    if (claim.claimed && claimedInviteId != null) {
      _callLifecycleArbiter.dropIncoming(
        generation: claim.generation,
        inviteId: claimedInviteId,
      );
    }
  }

  Future<_AcceptInviteTransactionResult> _acceptInviteTransactionWithRetry(
    CallInvitePayload payload, {
    required String source,
    int? lifecycleGeneration,
  }) async {
    const maxAttempts = 3;
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (lifecycleGeneration != null &&
          !_canContinueAcceptedRouteGeneration(lifecycleGeneration)) {
        return const _AcceptInviteTransactionResult(
          decision: _AcceptInviteDecision.superseded,
        );
      }
      _recordAcceptedRouteStage(
        payload,
        CallV2PhysicalDiagnosticStage.acceptedTransactionStarted,
      );
      await _diagManager('accept_transaction_start', meta: {
        'inviteId': payload.inviteId,
        'channel': payload.channel,
        'source': source,
        'attempt': attempt,
      });
      try {
        await _beforeAcceptTransactionAttemptForTest?.call(attempt);
        if (lifecycleGeneration != null &&
            !_canContinueAcceptedRouteGeneration(lifecycleGeneration)) {
          return const _AcceptInviteTransactionResult(
            decision: _AcceptInviteDecision.superseded,
          );
        }
        final result = await _db
            .runTransaction<_AcceptInviteTransactionResult>((tx) async {
          final ref = _db.collection('callInvites').doc(payload.inviteId);
          final snap = await tx.get(ref);
          if (!snap.exists) {
            return const _AcceptInviteTransactionResult(
              decision: _AcceptInviteDecision.missing,
            );
          }
          final data = snap.data() ?? const <String, dynamic>{};
          final status = _parseStatus(data['status']);
          final toUid = (data['toUid'] ?? '').toString().trim();
          final me = _currentUid.trim();
          if (me.isEmpty || toUid != me) {
            return const _AcceptInviteTransactionResult(
              decision: _AcceptInviteDecision.wrongRecipient,
            );
          }
          if (_isTerminalStatus(status)) {
            return _AcceptInviteTransactionResult(
              decision: _AcceptInviteDecision.terminal,
              authoritativeStatus: status,
            );
          }
          if (status != CallInviteStatus.ringing &&
              status != CallInviteStatus.accepted &&
              status != CallInviteStatus.joining &&
              status != CallInviteStatus.connected) {
            return _AcceptInviteTransactionResult(
              decision: _AcceptInviteDecision.invalidStatus,
              authoritativeStatus: status,
            );
          }
          final authoritativePayload = _authoritativeAcceptedPayload(
            payload,
            data,
          );
          if (authoritativePayload.channel.isEmpty ||
              authoritativePayload.fromUid.isEmpty) {
            return _AcceptInviteTransactionResult(
              decision: _AcceptInviteDecision.invalidPayload,
              authoritativeStatus: status,
            );
          }
          if (status == CallInviteStatus.ringing) {
            tx.set(
                ref,
                {
                  'status': CallInviteStatus.accepted.name,
                  'acceptedAt': FieldValue.serverTimestamp(),
                  'calleeStage': 'accepted',
                  'calleeLastError': '',
                },
                SetOptions(merge: true));
            return _AcceptInviteTransactionResult(
              decision: _AcceptInviteDecision.accepted,
              authoritativePayload: authoritativePayload,
              authoritativeStatus: CallInviteStatus.accepted,
            );
          }
          return _AcceptInviteTransactionResult(
            decision: _AcceptInviteDecision.alreadyAccepted,
            authoritativePayload: authoritativePayload,
            authoritativeStatus: status,
          );
        }).timeout(const Duration(seconds: 8));

        await _diagManager('accept_transaction_done', meta: {
          'inviteId': payload.inviteId,
          'channel': payload.channel,
          'source': source,
          'attempt': attempt,
          'result': result.decision.name,
        });
        if (result.accepted) {
          _recordAcceptedRouteStage(
            result.authoritativePayload ?? payload,
            CallV2PhysicalDiagnosticStage.acceptedTransactionSucceeded,
          );
        } else if (result.decision == _AcceptInviteDecision.wrongRecipient) {
          _recordAcceptedRouteStage(
            payload,
            CallV2PhysicalDiagnosticStage.acceptedTransactionRejectedRecipient,
          );
        } else {
          _recordAcceptedRouteStage(
            payload,
            CallV2PhysicalDiagnosticStage.acceptedTransactionRejectedTerminal,
          );
        }
        return result;
      } catch (error) {
        lastError = error;
        final recoverable = FirestoreReadHelper.isRecoverableError(error);
        _recordAcceptedRouteStage(
          payload,
          CallV2PhysicalDiagnosticStage.acceptedTransactionPendingNetwork,
        );
        await _diagManager('accept_transaction_retry', meta: {
          'inviteId': payload.inviteId,
          'channel': payload.channel,
          'source': source,
          'attempt': attempt,
          'recoverable': recoverable,
          'error': '$error',
        });
        if (!recoverable || attempt == maxAttempts) break;
        if (lifecycleGeneration != null &&
            !_canContinueAcceptedRouteGeneration(lifecycleGeneration)) {
          return const _AcceptInviteTransactionResult(
            decision: _AcceptInviteDecision.superseded,
          );
        }
        unawaited(FirestoreReadHelper.recoverNetwork(
          reason: 'accept_transaction',
          force: attempt >= 2,
        ));
        await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
      }
    }

    await _diagManager('accept_transaction_error', meta: {
      'inviteId': payload.inviteId,
      'channel': payload.channel,
      'source': source,
      'error': '$lastError',
    });
    return const _AcceptInviteTransactionResult(
      decision: _AcceptInviteDecision.unavailable,
    );
  }

  Future<_RouteOpenResult> _activateSession(
    _CallSession session, {
    required bool openScreen,
    required String source,
    bool deferUntilNavigatorReady = false,
  }) async {
    if (openScreen &&
        _callRouteActive &&
        _current?.matchesAcceptedSession(session) == true) {
      return _RouteOpenResult.alreadyOpenSameInvite;
    }
    if (openScreen && _openingCallRoute) {
      return _RouteOpenResult.routeBusy;
    }
    if (openScreen && deferUntilNavigatorReady) {
      final appReady = await _isAppActuallyForeground();
      final nav = _navigatorKey?.currentState;
      if (!appReady || nav == null || !nav.mounted) {
        return _RouteOpenResult.navigatorUnavailable;
      }
    }

    if (_current?.matchesAcceptedSession(session) != true) {
      await _activeInviteSub?.cancel();
      _activeInviteSub = null;
      _cancelSessionTimers();
      _terminalSignal.value = null;
    }

    _current = session;
    _touchSession(session);
    _markInviteHandled(session.inviteId);
    if (!_debugTestAccessEnabled || !_skipActiveInviteBindingForTest) {
      await _bindActiveInvite(session.inviteId);
    }
    _restartTimeoutsForStatus(session.status);

    if (!openScreen) return _RouteOpenResult.opened;
    final routeResult = await _openCallScreen(session, source: source);
    if (routeResult != _RouteOpenResult.opened &&
        routeResult != _RouteOpenResult.alreadyOpenSameInvite) {
      await _rollbackFailedRouteSession(
        session,
        source: source,
        routeResult: routeResult,
      );
    }
    return routeResult;
  }

  Future<_RouteOpenResult> _openCallScreen(
    _CallSession session, {
    required String source,
  }) async {
    if (_openingCallRoute) return _RouteOpenResult.routeBusy;
    if (_callRouteActive && _current?.matchesAcceptedSession(session) == true) {
      return _RouteOpenResult.alreadyOpenSameInvite;
    }

    _openingCallRoute = true;
    try {
      CallV2PhysicalDiagnosticLedger.instance.record(
        CallV2PhysicalDiagnosticStage.routeAttemptStarted,
      );
      await _waitForAppResumed();
      final nav = await _waitForNavigator();
      if (nav == null || !nav.mounted) {
        return _RouteOpenResult.navigatorUnavailable;
      }
      CallV2PhysicalDiagnosticLedger.instance.record(
        CallV2PhysicalDiagnosticStage.navigatorReady,
      );
      final routeOwner = _CallRouteOwner(session);
      _callRouteOwner = routeOwner;
      _callRouteActive = true;
      await _diagManager('route_push', meta: {
        'source': source,
        'callV2Selected': session.connectionSystem ==
            CallV2RealCallConnectionSystem.callV2Dev,
      });
      final testOpenRecorder =
          _debugTestAccessEnabled ? _callScreenOpenRecorderForTest : null;
      if (testOpenRecorder != null) {
        await testOpenRecorder(
          inviteId: session.inviteId,
          channel: session.channel,
          acceptedCallkitId: session.acceptedCallkitId,
          isVideo: session.isVideo,
          otherUserName: session.otherUserName,
          otherUserId: session.otherUserId.isEmpty ? null : session.otherUserId,
          isCaller: session.isCaller,
          connectionSystem: session.connectionSystem,
          callV2FallbackUsed: session.callV2FallbackUsed,
          callV2BlockerCode: session.callV2BlockerCode,
        );
        _routeOpenCount += 1;
        _rtcSetupOwnerCount += 1;
        CallV2PhysicalDiagnosticLedger.instance.record(
          CallV2PhysicalDiagnosticStage.routeOpened,
        );
        _acknowledgeAcceptedNativeRouteIfOwned(session);
        return _RouteOpenResult.opened;
      }
      final routeFuture = nav.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => AgoraCallScreen(
            channelName: session.channel,
            isVideo: session.isVideo,
            otherUserName: session.otherUserName,
            otherUserId:
                session.otherUserId.isEmpty ? null : session.otherUserId,
            inviteId: session.inviteId,
            acceptedCallkitId: session.acceptedCallkitId.isEmpty
                ? null
                : session.acceptedCallkitId,
            lifecycleGeneration: session.lifecycleGeneration,
            isCaller: session.isCaller,
            connectionSystem: session.connectionSystem,
            callV2FallbackUsed: session.callV2FallbackUsed,
            callV2BlockerCode: session.callV2BlockerCode,
          ),
        ),
      );
      unawaited(routeFuture.whenComplete(
        () => _completeCallRoute(routeOwner, source: source),
      ));
      _routeOpenCount += 1;
      _rtcSetupOwnerCount += 1;
      CallV2PhysicalDiagnosticLedger.instance.record(
        CallV2PhysicalDiagnosticStage.routeOpened,
      );
      _acknowledgeAcceptedNativeRouteIfOwned(session);
      return _RouteOpenResult.opened;
    } catch (error) {
      await _diagManager('route_push_failed', meta: {
        'source': source,
        'error': '$error',
      });
      return _RouteOpenResult.failed;
    } finally {
      _openingCallRoute = false;
    }
  }

  Future<void> _completeCallRoute(
    _CallRouteOwner owner, {
    required String source,
  }) async {
    if (!identical(_callRouteOwner, owner)) {
      _staleRouteCompletionIgnoredCount += 1;
      await _diagManager('stale_route_completion_ignored', meta: {
        'sameRouteOwner': false,
        'callRouteActive': _callRouteActive,
      });
      return;
    }

    final session = _current;
    if (!owner.ownsSession(session)) {
      _staleRouteCompletionIgnoredCount += 1;
      await _diagManager('stale_route_completion_ignored', meta: {
        'sameRouteOwner': true,
        'sameSessionOwner': false,
        'callRouteActive': _callRouteActive,
      });
      return;
    }

    _callRouteOwner = null;
    _callRouteActive = false;
    await _diagManager('route_pop', meta: {
      'source': source,
      'callV2Selected':
          session!.connectionSystem == CallV2RealCallConnectionSystem.callV2Dev,
    });
    await handleCallScreenClosed(
      owner.inviteId,
      lifecycleGeneration: owner.lifecycleGeneration,
      acceptedCallkitId: owner.acceptedCallkitId,
    );
  }

  void _acknowledgeAcceptedNativeRouteIfOwned(
    _CallSession session,
  ) {
    final watch = _acceptedNativeRouteWatch;
    if (watch == null ||
        !watch.matchesSession(session) ||
        watch.routeOpened ||
        watch.terminal) {
      return;
    }
    final exactNativeKey = watch.payload.acceptedCallkitId.trim();
    if (exactNativeKey.isEmpty) return;
    final acknowledge = _acknowledgeNativeRouteOwnership;
    if (acknowledge == null) return;
    unawaited(Future<bool>.sync(() => acknowledge(exactNativeKey)).catchError(
      (_) => false,
    ));
  }

  Future<void> _rollbackFailedRouteSession(
    _CallSession session, {
    required String source,
    required _RouteOpenResult routeResult,
  }) async {
    if (!identical(_current, session)) return;
    await _activeInviteSub?.cancel();
    _activeInviteSub = null;
    _cancelSessionTimers();
    _terminalSignal.value = null;
    _current = null;
    _openingCallRoute = false;
    _clearCallRouteOwnershipForSession(session);
    await _diagManager('route_activation_rolled_back', meta: {
      'source': source,
      'routeResult': routeResult.name,
    });
  }

  Future<void> _bindActiveInvite(String inviteId) async {
    await _activeInviteSub?.cancel();
    _activeInviteSub = _db
        .collection('callInvites')
        .doc(inviteId)
        .snapshots()
        .listen((snap) async {
      if (!snap.exists) {
        await _emitTerminalSignal(
          inviteId: inviteId,
          status: CallInviteStatus.ended,
          message: 'Call ended',
          isError: false,
        );
        return;
      }
      final data = snap.data() ?? const <String, dynamic>{};
      final status = _parseStatus(data['status']);
      final session = _current;
      if (session == null || session.inviteId != inviteId) return;

      if (_isTerminalStatus(status)) {
        await _emitTerminalSignal(
          inviteId: inviteId,
          status: status,
          message: _terminalMessageForStatus(status, data: data),
          isError: status == CallInviteStatus.failed,
        );
        return;
      }

      if (_isProgressStatus(status) &&
          !_canApplyMediaProgress(session, inviteId: inviteId)) {
        return;
      }

      if (status == CallInviteStatus.connected) {
        if (!_callLifecycleArbiter.markConnected(session.lifecycleGeneration)) {
          return;
        }
        session.status = status;
        session.phase = CallSessionPhase.connected;
        _touchSession(session);
        _restartTimeoutsForStatus(status);
        return;
      }

      if (status == CallInviteStatus.accepted ||
          status == CallInviteStatus.joining) {
        if (session.phase != CallSessionPhase.connected) {
          if (!_callLifecycleArbiter.markJoining(
            session.lifecycleGeneration,
          )) {
            return;
          }
          session.status = status;
          session.phase = CallSessionPhase.joining;
          _touchSession(session);
          _restartTimeoutsForStatus(status);
        }
        return;
      }

      if (status == CallInviteStatus.ringing) {
        session.status = status;
        _touchSession(session);
        _restartTimeoutsForStatus(status);
      }
    });
  }

  Future<void> _markTerminal({
    required String inviteId,
    required CallInviteStatus status,
    required String message,
    required bool isError,
    required bool actorIsCaller,
    required String endReason,
    String? error,
    bool authoritativeLocalExit = false,
    _CallSession? expectedSession,
  }) async {
    final session = _current;
    if (session == null ||
        session.inviteId != inviteId ||
        (expectedSession != null && !identical(session, expectedSession))) {
      return;
    }
    if (session.isTerminal) return;
    final existingTransition = session.terminalTransitionFuture;
    if (existingTransition != null) {
      await existingTransition;
      return;
    }

    _callLifecycleArbiter.beginEnding(session.lifecycleGeneration);
    late final Future<void> transitionFuture;
    transitionFuture = _performAuthoritativeTerminalTransition(
      session: session,
      requestedStatus: status,
      requestedMessage: message,
      requestedIsError: isError,
      actorIsCaller: actorIsCaller,
      requestedEndReason: endReason,
      error: error,
      authoritativeLocalExit: authoritativeLocalExit,
    );
    session.terminalTransitionFuture = transitionFuture;
    try {
      await transitionFuture;
    } finally {
      if (identical(session.terminalTransitionFuture, transitionFuture)) {
        session.terminalTransitionFuture = null;
      }
    }
  }

  Future<void> _performAuthoritativeTerminalTransition({
    required _CallSession session,
    required CallInviteStatus requestedStatus,
    required String requestedMessage,
    required bool requestedIsError,
    required bool actorIsCaller,
    required String requestedEndReason,
    required bool authoritativeLocalExit,
    String? error,
  }) async {
    final transition = await _resolveAuthoritativeTerminalTransition(
      session: session,
      requestedStatus: requestedStatus,
      requestedMessage: requestedMessage,
      requestedIsError: requestedIsError,
      actorIsCaller: actorIsCaller,
      requestedEndReason: requestedEndReason,
      error: error,
      authoritativeLocalExit: authoritativeLocalExit,
    );
    if (!identical(_current, session) ||
        !_callLifecycleArbiter.ownsGeneration(session.lifecycleGeneration)) {
      return;
    }

    if (transition.writeApplied) {
      _authoritativeTerminalWriteCount += 1;
    }
    session.phase = CallSessionPhase.terminal;
    session.status = transition.status;
    _touchSession(session);
    _cancelSessionTimers();

    await _diagManager(
      transition.status == CallInviteStatus.failed ? 'failed' : 'ended',
      meta: {
        'inviteId': session.inviteId,
        'status': transition.status.name,
        'message': transition.message,
        'endReason': transition.endReason,
        'authoritativeTerminalWrite': transition.writeApplied,
        'preservedExistingTerminal': transition.preservedExistingTerminal,
        if (error != null && error.isNotEmpty) 'error': error,
      },
    );
    await _markNativeInviteStateByIdsSafely(
      inviteId: session.inviteId,
      channel: session.channel,
      callkitId: session.callkitId,
      state: 'terminal',
      reason: transition.endReason,
    );
    await _endNativeCallForInvite(
      inviteId: session.inviteId,
      channel: session.channel,
      callkitId: session.callkitId,
      reason: transition.endReason,
    );

    await _emitTerminalSignal(
      inviteId: session.inviteId,
      status: transition.status,
      message: transition.message,
      isError: transition.isError,
    );
  }

  Future<_AuthoritativeTerminalTransition>
      _resolveAuthoritativeTerminalTransition({
    required _CallSession session,
    required CallInviteStatus requestedStatus,
    required String requestedMessage,
    required bool requestedIsError,
    required bool actorIsCaller,
    required String requestedEndReason,
    required bool authoritativeLocalExit,
    String? error,
  }) async {
    final fallback = _AuthoritativeTerminalTransition(
      status: requestedStatus,
      endReason: requestedEndReason,
      message: requestedMessage,
      isError: requestedIsError,
      writeApplied: false,
      preservedExistingTerminal: false,
    );
    try {
      return await _db.runTransaction<_AuthoritativeTerminalTransition>(
        (tx) async {
          final ref = _db.collection('callInvites').doc(session.inviteId);
          final snap = await tx.get(ref);
          if (!snap.exists) return fallback;
          final data = snap.data() ?? const <String, dynamic>{};
          final authoritativeStatus = _parseStatus(data['status']);
          if (_isTerminalStatus(authoritativeStatus)) {
            return _AuthoritativeTerminalTransition(
              status: authoritativeStatus,
              endReason: (data['endReason'] ?? requestedEndReason).toString(),
              message: _terminalMessageForStatus(
                authoritativeStatus,
                data: data,
              ),
              isError: authoritativeStatus == CallInviteStatus.failed,
              writeApplied: false,
              preservedExistingTerminal: true,
            );
          }

          final currentUid = _currentUid.trim();
          final fromUid = (data['fromUid'] ?? '').toString().trim();
          final toUid = (data['toUid'] ?? '').toString().trim();
          final participantFieldsPresent =
              fromUid.isNotEmpty || toUid.isNotEmpty;
          if (currentUid.isEmpty ||
              (participantFieldsPresent &&
                  currentUid != fromUid &&
                  currentUid != toUid)) {
            return fallback;
          }

          var effectiveStatus = requestedStatus;
          if (authoritativeLocalExit) {
            effectiveStatus =
                actorIsCaller && authoritativeStatus == CallInviteStatus.ringing
                    ? CallInviteStatus.cancelled
                    : CallInviteStatus.ended;
          } else if (authoritativeStatus != CallInviteStatus.ringing &&
              (requestedStatus == CallInviteStatus.cancelled ||
                  requestedStatus == CallInviteStatus.declined ||
                  requestedStatus == CallInviteStatus.missed)) {
            effectiveStatus = CallInviteStatus.ended;
          }

          if (!_isProgressStatus(authoritativeStatus)) return fallback;
          final actorPrefix = actorIsCaller ? 'caller' : 'callee';
          final update = <String, dynamic>{
            'status': effectiveStatus.name,
            '${actorPrefix}Stage': effectiveStatus.name,
            'endedAt': FieldValue.serverTimestamp(),
            'endedBy': currentUid,
            'endReason': requestedEndReason,
            if (effectiveStatus == CallInviteStatus.declined)
              'declinedAt': FieldValue.serverTimestamp(),
            if (effectiveStatus == CallInviteStatus.missed)
              'missedAt': FieldValue.serverTimestamp(),
            if (effectiveStatus == CallInviteStatus.cancelled)
              'cancelledAt': FieldValue.serverTimestamp(),
            if (effectiveStatus == CallInviteStatus.failed)
              'failedAt': FieldValue.serverTimestamp(),
            if (error != null && error.isNotEmpty)
              '${actorPrefix}LastError': _truncate(error),
          };
          tx.set(ref, update, SetOptions(merge: true));
          return _AuthoritativeTerminalTransition(
            status: effectiveStatus,
            endReason: requestedEndReason,
            message: effectiveStatus == requestedStatus
                ? requestedMessage
                : _terminalMessageForStatus(effectiveStatus),
            isError: effectiveStatus == requestedStatus
                ? requestedIsError
                : effectiveStatus == CallInviteStatus.failed,
            writeApplied: true,
            preservedExistingTerminal: false,
          );
        },
      );
    } catch (error) {
      await _diagManager('terminal_transaction_error', meta: {
        'status': requestedStatus.name,
        'endReason': requestedEndReason,
        'recoverable': FirestoreReadHelper.isRecoverableError(error),
      });
      return fallback;
    }
  }

  Future<void> _emitTerminalSignal({
    required String inviteId,
    required CallInviteStatus status,
    required String message,
    required bool isError,
  }) async {
    CallV2PhysicalDiagnosticLedger.instance.record(
      CallV2PhysicalDiagnosticStage.terminalObserved,
    );
    final session = _current;
    if (session != null && session.inviteId == inviteId) {
      if (session.terminalSignalSent && session.status == status) {
        return;
      }
      session.phase = CallSessionPhase.terminal;
      session.status = status;
      _touchSession(session);
      session.terminalSignalSent = true;
    }
    _cancelSessionTimers();
    _terminalSignal.value = CallTerminalSignal(
      inviteId: inviteId,
      status: status.name,
      message: message,
      isError: isError,
    );
    if (!_callRouteActive && !_openingCallRoute) {
      await _finalizeTerminalSessionCleanup(
        inviteId: inviteId,
        reason: 'terminal_signal_no_route',
      );
    }
  }

  Future<void> _runPreflightSweep({
    required String reason,
    bool endUnownedNativeCalls = false,
  }) async {
    final nativeCalls = await _listNativeCallsSafely();
    final session = _current;
    if (session != null && _shouldTreatSessionAsStale(session, nativeCalls)) {
      await _diagManager('stale_session_reset', meta: {
        ..._sessionSnapshot(nativeCalls: nativeCalls),
        'reason': reason,
      });
      if (_callRouteActive || _openingCallRoute) {
        _callLifecycleArbiter.beginTeardown(session.lifecycleGeneration);
        _callLifecycleArbiter.recordPreflightLifecycleMutationBlocked();
        await _diagManager('stale_session_reset_deferred_route_active', meta: {
          ..._sessionSnapshot(nativeCalls: nativeCalls),
          'reason': reason,
        });
        return;
      }
      if (session.isTerminal || _isTerminalStatus(session.status)) {
        await _finalizeTerminalSessionCleanup(
          inviteId: session.inviteId,
          reason: reason,
          forceClearUiFlags: true,
        );
        return;
      }
      _callLifecycleArbiter.beginTeardown(session.lifecycleGeneration);
      await _resetSessionState(
        reason: reason,
        endCurrentNativeCall: true,
        endUnownedNativeCalls: true,
        clearStoredAcceptedRecovery: true,
        forceClearUiFlags: true,
      );
      _callLifecycleArbiter.invalidateForProductionReset();
      return;
    }

    var hasLiveIncomingPrompt = false;
    if (session == null && hasActiveUi) {
      hasLiveIncomingPrompt = await _hasLiveIncomingPrompt();
      if (!hasLiveIncomingPrompt) {
        await _diagManager('stale_ui_flags_reset', meta: {
          ..._sessionSnapshot(nativeCalls: nativeCalls),
          'reason': reason,
        });
        await _resetSessionState(
          reason: reason,
          clearStoredAcceptedRecovery: true,
          forceClearUiFlags: true,
        );
        _callLifecycleArbiter.invalidateForProductionReset();
        if (endUnownedNativeCalls && nativeCalls.isNotEmpty) {
          await _endStaleNativeCalls(keepCallkitId: null, reason: reason);
        }
        return;
      }
    }

    if (!hasLiveIncomingPrompt &&
        !_hasTrulyActiveCall() &&
        endUnownedNativeCalls &&
        nativeCalls.isNotEmpty) {
      await _endStaleNativeCalls(keepCallkitId: null, reason: reason);
    }
  }

  Future<void> _runPreflightSweepSafely({
    required String reason,
    String inviteId = '',
    String channel = '',
    bool endUnownedNativeCalls = false,
  }) async {
    try {
      await _runPreflightSweep(
        reason: reason,
        endUnownedNativeCalls: endUnownedNativeCalls,
      );
    } catch (error) {
      await _diagManager('preflight_error_nonfatal', meta: {
        'reason': reason,
        if (inviteId.isNotEmpty) 'inviteId': inviteId,
        if (channel.isNotEmpty) 'channel': channel,
        'error': '$error',
      });
      unawaited(FirestoreReadHelper.recoverNetwork(
        reason: reason,
        force: FirestoreReadHelper.isRecoverableError(error),
      ));
    }
  }

  Future<void> _finalizeTerminalSessionCleanup({
    required String inviteId,
    required String reason,
    bool forceClearUiFlags = false,
    int? expectedLifecycleGeneration,
    String expectedCallkitId = '',
  }) async {
    final session = _current;
    if (session == null) {
      if (forceClearUiFlags && _callRouteOwner == null) {
        _openingCallRoute = false;
        _callRouteActive = false;
        _incomingPromptActive = false;
        _incomingPromptInviteId = null;
      }
      return;
    }
    if (!_sessionMatchesOwnership(
      session,
      inviteId: inviteId,
      lifecycleGeneration: expectedLifecycleGeneration,
      acceptedCallkitId: expectedCallkitId,
    )) {
      return;
    }
    if (!session.isTerminal && !_isTerminalStatus(session.status)) {
      return;
    }
    _callLifecycleArbiter.beginTeardown(session.lifecycleGeneration);
    final preservePendingAcceptedRecovery =
        _pendingAcceptedInviteIntent != null;
    final detached = await _detachSessionState(
      onlyInviteId: inviteId,
      forceClearUiFlags:
          forceClearUiFlags || (!_callRouteActive && !_openingCallRoute),
    );
    if (detached == null) return;
    if (_current != null ||
        !_callLifecycleArbiter.ownsGeneration(session.lifecycleGeneration)) {
      return;
    }
    _invalidateAcceptedRecoveryRequestForDetachedSession(detached);

    final deferredExactCleanup = _beginOwnershipReleasedExactCleanup(
      detached: detached,
      reason: reason,
      endCurrentNativeCall: true,
      clearStoredAcceptedRecovery: !preservePendingAcceptedRecovery,
    );
    await _diagResourceCounts('reset_session_state_done');
    if (_current != null ||
        !_callLifecycleArbiter.ownsGeneration(session.lifecycleGeneration)) {
      await deferredExactCleanup;
      return;
    }
    final pendingPayload = _pendingIncomingPromptPayload;
    final pendingSource = _pendingIncomingPromptSource;
    final pendingClaim = _callLifecycleArbiter.completeTeardownAndClaimPending(
      session.lifecycleGeneration,
    );
    final pendingContinuation = _continueClaimedPendingIncoming(
      pendingClaim: pendingClaim,
      pendingPayload: pendingPayload,
      pendingSource: pendingSource,
      source: '$reason:teardown_complete',
    );
    await Future.wait<void>(<Future<void>>[
      deferredExactCleanup,
      pendingContinuation,
    ]);
  }

  Future<void> _continueClaimedPendingIncoming({
    required CallV2PendingClaim pendingClaim,
    required CallInvitePayload? pendingPayload,
    required String? pendingSource,
    required String source,
  }) async {
    if (!pendingClaim.claimed) return;
    _previousTeardownCompleted = true;
    CallV2PhysicalDiagnosticLedger.instance.record(
      CallV2PhysicalDiagnosticStage.previousTeardownCompleted,
    );
    final claimedInviteId = pendingClaim.inviteId;
    final acceptedIntent = _claimPendingAcceptedIntent(pendingClaim);
    final effectivePayload = acceptedIntent?.payload ?? pendingPayload;
    final effectiveSource = pendingSource ?? 'accepted_pending';
    if (claimedInviteId == null ||
        effectivePayload == null ||
        effectivePayload.inviteId != claimedInviteId ||
        (acceptedIntent == null && pendingSource == null) ||
        (pendingClaim.acceptedIntent && acceptedIntent == null) ||
        !_callLifecycleArbiter.ownsIncoming(
          generation: pendingClaim.generation,
          inviteId: claimedInviteId,
        )) {
      if (claimedInviteId != null) {
        _callLifecycleArbiter.dropIncoming(
          generation: pendingClaim.generation,
          inviteId: claimedInviteId,
        );
      }
      return;
    }

    if (acceptedIntent != null) {
      _clearPendingIncomingPrompt(claimedInviteId);
      _incomingPromptActive = false;
      _incomingPromptInviteId = null;
      _incomingUiOwner = IncomingUiOwner.none;
      _pendingAcceptedContinuationStarted = true;
      _ownAcceptedRouteContinuation(
        payload: effectivePayload,
        claimedGeneration: pendingClaim.generation,
      );
      final accepted = _callLifecycleArbiter.incomingAccepted(
        generation: pendingClaim.generation,
        inviteId: claimedInviteId,
      );
      if (!accepted) return;
      await _diagManager('pending_accept_continuation_started', meta: {
        'pendingAcceptedClaimed': true,
        'pendingAcceptedContinuationStarted': true,
        'previousTeardownCompleted': true,
        'callLifecycleState': _callLifecycleArbiter.state.name,
      });
      final result = await resumePendingAcceptedRouteIfReady(
        source: '$effectiveSource:accepted_teardown_complete',
      );
      if (result == AcceptedCallRecoveryResult.opened ||
          result == AcceptedCallRecoveryResult.alreadyOpen) {
        await _diagManager('pending_accept_continuation_completed', meta: {
          'pendingAcceptedContinuationCompleted': true,
          'routeOpenCount': _routeOpenCount,
          'rtcSetupOwnerCount': _rtcSetupOwnerCount,
        });
      }
      return;
    }

    Map<String, dynamic>? latest;
    try {
      latest = await _readInviteData(claimedInviteId);
    } catch (error) {
      await _diagManager('incoming_pending_verify_error', meta: {
        'source': source,
        'errorType': error.runtimeType.toString(),
      });
      _schedulePendingIncomingPrompt(
        effectivePayload,
        source: effectiveSource,
        reason: 'claimed_verify_error',
      );
      return;
    }
    if (!_callLifecycleArbiter.ownsIncoming(
      generation: pendingClaim.generation,
      inviteId: claimedInviteId,
    )) {
      return;
    }
    final latestStatus = _parseStatus(latest?['status']);
    final canContinue =
        latest != null && latestStatus == CallInviteStatus.ringing;
    if (latest == null || !canContinue) {
      _incomingPromptActive = false;
      _incomingPromptInviteId = null;
      _incomingUiOwner = IncomingUiOwner.none;
      _clearPendingIncomingPrompt(claimedInviteId);
      _clearPendingAcceptedIntent(
        inviteId: claimedInviteId,
        claimedGeneration: pendingClaim.generation,
      );
      _markInviteHandled(claimedInviteId);
      await _endNativeCallForInvite(
        inviteId: claimedInviteId,
        channel: effectivePayload.channel,
        reason: source,
      );
      _callLifecycleArbiter.beginEnding(pendingClaim.generation);
      _callLifecycleArbiter.beginTeardown(pendingClaim.generation);
      final nextPendingPayload = _pendingIncomingPromptPayload;
      final nextPendingSource = _pendingIncomingPromptSource;
      final nextClaim = _callLifecycleArbiter.completeTeardownAndClaimPending(
        pendingClaim.generation,
      );
      await _continueClaimedPendingIncoming(
        pendingClaim: nextClaim,
        pendingPayload: nextPendingPayload,
        pendingSource: nextPendingSource,
        source: '$source:terminal_claimed_pending',
      );
      return;
    }
    final payload = CallInvitePayload(
      inviteId: claimedInviteId,
      channel:
          (latest['channel'] ?? effectivePayload.channel).toString().trim(),
      isVideo: _truthy(latest['isVideo']),
      fromName: (latest['fromName'] ?? effectivePayload.fromName).toString(),
      fromUid:
          (latest['fromUid'] ?? effectivePayload.fromUid).toString().trim(),
      toUid: (latest['toUid'] ?? effectivePayload.toUid).toString().trim(),
      acceptedCallkitId: effectivePayload.acceptedCallkitId,
      connectionSystem: callConnectionSystemFromInviteValue(
        latest['callSystem'],
      ),
    );
    if (payload.channel.isEmpty) {
      _callLifecycleArbiter.dropIncoming(
        generation: pendingClaim.generation,
        inviteId: claimedInviteId,
      );
      return;
    }

    final owner = await _resolveIncomingUiOwner(payload);
    if (!_callLifecycleArbiter.ownsIncoming(
      generation: pendingClaim.generation,
      inviteId: claimedInviteId,
    )) {
      return;
    }
    _clearPendingIncomingPrompt(claimedInviteId);
    _incomingPromptActive = true;
    _incomingPromptInviteId = claimedInviteId;
    _incomingUiOwner = owner;
    await _diagManager('incoming_pending_claimed_after_teardown', meta: {
      'source': source,
      'incomingUiOwner': owner.name,
      'callkitMatchFound': owner == IncomingUiOwner.callkit,
    });
    if (owner == IncomingUiOwner.callkit) return;
    if (owner == IncomingUiOwner.none) {
      _incomingPromptActive = false;
      _incomingPromptInviteId = null;
      _incomingUiOwner = IncomingUiOwner.none;
      _callLifecycleArbiter.dropIncoming(
        generation: pendingClaim.generation,
        inviteId: claimedInviteId,
      );
      return;
    }
    unawaited(_presentIncomingPrompt(
      payload,
      source: '$effectiveSource:teardown_complete',
      lifecycleGeneration: pendingClaim.generation,
    ));
  }

  Future<_DetachedCallSessionState?> _detachSessionState({
    String? onlyInviteId,
    bool clearHandledInvites = false,
    bool forceClearUiFlags = false,
  }) async {
    final session = _current;
    final normalizedInviteId = onlyInviteId?.trim() ?? '';
    if (normalizedInviteId.isNotEmpty &&
        session != null &&
        session.inviteId != normalizedInviteId) {
      return null;
    }

    final callkitId = session?.callkitId ??
        (normalizedInviteId.isEmpty
            ? ''
            : normalizeCallkitId(
                rawId: normalizedInviteId,
                fallback: session?.channel ?? '',
              ));
    final ownerGeneration = _callLifecycleArbiter.generation;

    await _activeInviteSub?.cancel();
    if (!identical(_current, session) ||
        !_callLifecycleArbiter.ownsGeneration(ownerGeneration)) {
      return null;
    }
    _activeInviteSub = null;
    _cancelSessionTimers();
    _pendingIncomingPromptRetryTimer?.cancel();
    _pendingIncomingPromptRetryTimer = null;
    if (!_callLifecycleArbiter.pendingIncomingPresent) {
      _pendingIncomingPromptPayload = null;
      _pendingIncomingPromptSource = null;
    }
    _current = null;
    _terminalSignal.value = null;

    if (forceClearUiFlags || !hasActiveSession) {
      _openingCallRoute = false;
      _clearCallRouteOwnershipForSession(session);
      _incomingPromptActive = false;
      _incomingPromptInviteId = null;
      _incomingUiOwner = IncomingUiOwner.none;
    }

    if (clearHandledInvites) {
      _handledInviteExpiries.clear();
    }

    return _DetachedCallSessionState(
      inviteId: session?.inviteId ?? normalizedInviteId,
      callkitId: callkitId,
      ownerGeneration: ownerGeneration,
    );
  }

  Future<void> _resetSessionState({
    required String reason,
    String? onlyInviteId,
    bool endCurrentNativeCall = false,
    bool endUnownedNativeCalls = false,
    bool endAllNativeCallsForAppReset = false,
    bool clearStoredAcceptedRecovery = false,
    bool clearHandledInvites = false,
    bool forceClearUiFlags = false,
  }) async {
    final detached = await _detachSessionState(
      onlyInviteId: onlyInviteId,
      clearHandledInvites: clearHandledInvites,
      forceClearUiFlags: forceClearUiFlags,
    );
    if (detached == null) return;
    final callkitId = detached.callkitId;
    final ownerGeneration = detached.ownerGeneration;

    if (endCurrentNativeCall && callkitId.isNotEmpty) {
      await _endNativeCallSafely(
        callkitId,
        reason: '$reason:end_current_native',
      );
    }
    if (_current != null ||
        !_callLifecycleArbiter.ownsGeneration(ownerGeneration)) {
      return;
    }
    if (endAllNativeCallsForAppReset) {
      await _endAllNativeCallsForAppReset(reason: reason);
    } else if (endUnownedNativeCalls) {
      await _endStaleNativeCalls(keepCallkitId: null, reason: reason);
    }
    if (_current != null ||
        !_callLifecycleArbiter.ownsGeneration(ownerGeneration)) {
      return;
    }
    if (clearStoredAcceptedRecovery) {
      await _clearStoredAcceptedCallRecoverySafely(
        reason,
        inviteId: detached.inviteId,
        callkitId: callkitId,
      );
      _acceptedRecoveryPending = false;
      _acceptedRecoveryAcknowledged = false;
      _acceptedRecoveryAttemptCount = 0;
    }
    await _diagResourceCounts('reset_session_state_done');
  }

  Future<void> _beginOwnershipReleasedExactCleanup({
    required _DetachedCallSessionState detached,
    required String reason,
    required bool endCurrentNativeCall,
    required bool clearStoredAcceptedRecovery,
  }) {
    final cleanups = <Future<void>>[];
    if (endCurrentNativeCall && detached.callkitId.isNotEmpty) {
      cleanups.add(_endNativeCallSafely(
        detached.callkitId,
        reason: '$reason:end_current_native',
      ));
    }
    if (clearStoredAcceptedRecovery) {
      cleanups.add(_clearStoredAcceptedCallRecoverySafely(
        reason,
        inviteId: detached.inviteId,
        callkitId: detached.callkitId,
      ));
      _acceptedRecoveryPending = false;
      _acceptedRecoveryAcknowledged = false;
      _acceptedRecoveryAttemptCount = 0;
    }
    return Future.wait<void>(cleanups);
  }

  void _invalidateAcceptedRecoveryRequestForDetachedSession(
    _DetachedCallSessionState detached,
  ) {
    if (!_matchesAcceptedCallIdentity(
      firstInviteId: _acceptedRecoveryRequestInviteId,
      firstCallkitId: _acceptedRecoveryRequestCallkitId,
      secondInviteId: detached.inviteId,
      secondCallkitId: detached.callkitId,
    )) {
      return;
    }
    _acceptedRecoveryRequestGeneration += 1;
    _acceptedRecoveryRequestInviteId = '';
    _acceptedRecoveryRequestCallkitId = '';
  }

  Future<void> _clearStoredAcceptedCallRecoverySafely(
    String reason, {
    required String inviteId,
    required String callkitId,
  }) async {
    final clearer = _clearStoredAcceptedCallRecovery;
    if (clearer == null) return;
    try {
      await clearer(inviteId: inviteId, callkitId: callkitId);
    } catch (e) {
      await _diagManager('accepted_recovery_clear_error', meta: {
        'reason': reason,
        'error': '$e',
      });
    }
  }

  Future<List<NativeCallSnapshot>> _listNativeCallsSafely() async {
    final provider = _listNativeCalls;
    if (provider == null) return const <NativeCallSnapshot>[];
    try {
      return await provider();
    } catch (e) {
      await _diagManager('native_call_list_error', meta: {'error': '$e'});
      return const <NativeCallSnapshot>[];
    }
  }

  Future<NativeCallSnapshot?> _matchingNativeCallForInvite({
    required String inviteId,
    required String channel,
  }) async {
    final normalizedInviteId = inviteId.trim();
    final normalizedChannel = channel.trim();
    final expectedCallkitId = normalizeCallkitId(
      rawId: normalizedInviteId,
      fallback: normalizedChannel,
    );
    final nativeCalls = await _listNativeCallsSafely();
    for (final call in nativeCalls) {
      final callkitMatches =
          call.callkitId.isNotEmpty && call.callkitId == expectedCallkitId;
      final inviteMatches =
          normalizedInviteId.isNotEmpty && call.inviteId == normalizedInviteId;
      final channelMatches =
          normalizedChannel.isNotEmpty && call.channel == normalizedChannel;
      if (callkitMatches || inviteMatches || channelMatches) {
        return call;
      }
    }
    return null;
  }

  Future<IncomingUiOwner> _resolveIncomingUiOwner(
    CallInvitePayload payload,
  ) async {
    var match = await _matchingNativeCallForInvite(
      inviteId: payload.inviteId,
      channel: payload.channel,
    );
    if (match != null) return IncomingUiOwner.callkit;
    if (_iosCallkitOnlyIncomingUi) {
      _awaitingPushkit = true;
      await _diagManager('incoming_awaiting_pushkit', meta: {
        'iosCallkitOnlyPolicy': true,
        'awaitingPushkit': true,
      });
      await Future<void>.delayed(_iosCallkitFallbackGrace);
      _awaitingPushkit = false;
      match = await _matchingNativeCallForInvite(
        inviteId: payload.inviteId,
        channel: payload.channel,
      );
      if (match != null) return IncomingUiOwner.callkit;
      final stillRinging = await _inviteStillRingingForCurrentUser(payload);
      if (!stillRinging) {
        _markInviteHandled(payload.inviteId);
        await _markNativeInviteStateSafely(
          payload,
          state: 'terminal',
          reason: 'callkit_fallback_not_ringing',
        );
        await _endNativeCallForInvite(
          inviteId: payload.inviteId,
          channel: payload.channel,
          reason: 'callkit_fallback_not_ringing',
        );
        return IncomingUiOwner.none;
      }
      final presenter = _presentNativeIncomingCall;
      if (presenter == null) {
        await _diagManager('incoming_callkit_fallback_missing', meta: {
          'iosCallkitOnlyPolicy': true,
          'blockerCode': 'native_presenter_unavailable',
        });
        return IncomingUiOwner.none;
      }
      _callkitFallbackRequestedCount += 1;
      final presented = await presenter(payload);
      if (!presented) {
        await _diagManager('incoming_callkit_fallback_failed', meta: {
          'iosCallkitOnlyPolicy': true,
          'blockerCode': 'native_presenter_failed',
        });
        return IncomingUiOwner.none;
      }
      _callkitPresentationCount += 1;
      return IncomingUiOwner.callkit;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    match = await _matchingNativeCallForInvite(
      inviteId: payload.inviteId,
      channel: payload.channel,
    );
    return match == null ? IncomingUiOwner.flutter : IncomingUiOwner.callkit;
  }

  Future<bool> _inviteStillRingingForCurrentUser(
      CallInvitePayload payload) async {
    Map<String, dynamic>? latest;
    try {
      latest = await _readInviteData(payload.inviteId);
    } catch (error) {
      await _diagManager('incoming_callkit_fallback_verify_error', meta: {
        'blockerCode': 'callkit_fallback_verify_failed',
      });
      return false;
    }
    if (latest == null) return false;
    final status = _parseStatus(latest['status']);
    if (status != CallInviteStatus.ringing) return false;
    final toUid = (latest['toUid'] ?? payload.toUid).toString().trim();
    return toUid.isNotEmpty && toUid == _currentUid.trim();
  }

  Future<void> _markNativeInviteStateSafely(
    CallInvitePayload payload, {
    required String state,
    required String reason,
  }) async {
    await _markNativeInviteStateByIdsSafely(
      inviteId: payload.inviteId,
      channel: payload.channel,
      callkitId: payload.acceptedCallkitId,
      state: state,
      reason: reason,
    );
  }

  Future<void> _markNativeInviteStateByIdsSafely({
    required String inviteId,
    required String channel,
    String callkitId = '',
    required String state,
    required String reason,
  }) async {
    if (state == 'accepted' || state == 'active') {
      _nativeAcceptedCallInviteId = inviteId.trim();
    } else if (state == 'terminal' &&
        _nativeAcceptedCallInviteId == inviteId.trim()) {
      _nativeAcceptedCallInviteId = null;
    }
    final marker = _markNativeInviteState;
    if (marker == null) return;
    try {
      await marker(
        inviteId: inviteId,
        channel: channel,
        callkitId: callkitId,
        state: state,
      );
    } catch (error) {
      await _diagManager('native_invite_state_mark_error', meta: {
        'state': state,
        'reason': reason,
        'blockerCode': 'native_state_mark_failed',
      });
    }
  }

  Future<void> _endNativeCallForInvite({
    required String inviteId,
    required String channel,
    String callkitId = '',
    required String reason,
  }) async {
    final normalizedInviteId = inviteId.trim();
    final normalizedChannel = channel.trim();
    final exactCallkitId = callkitId.trim();
    final match = exactCallkitId.isEmpty
        ? await _matchingNativeCallForInvite(
            inviteId: normalizedInviteId,
            channel: normalizedChannel,
          )
        : null;
    final resolvedCallkitId = exactCallkitId.isNotEmpty
        ? exactCallkitId
        : match?.callkitId ??
            (normalizedInviteId.isEmpty && normalizedChannel.isEmpty
                ? ''
                : normalizeCallkitId(
                    rawId: normalizedInviteId,
                    fallback: normalizedChannel,
                  ));
    if (resolvedCallkitId.isEmpty) return;
    await _endNativeCallSafely(
      resolvedCallkitId,
      reason: '$reason:end_matching_native',
    );
  }

  Future<void> _endNativeCallSafely(
    String callkitId, {
    required String reason,
  }) async {
    final ender = _endNativeCall;
    if (ender == null || callkitId.trim().isEmpty) return;
    try {
      await ender(callkitId);
    } catch (e) {
      await _diagManager('native_call_end_error', meta: {
        'callkitId': callkitId,
        'reason': reason,
        'error': '$e',
      });
    }
  }

  Future<void> _endStaleNativeCalls({
    required String? keepCallkitId,
    required String reason,
  }) async {
    final nativeCalls = await _listNativeCallsSafely();
    final keep = (keepCallkitId ?? '').trim();
    for (final call in nativeCalls) {
      if (_nativeCallHasOwnedIdentity(call, keepCallkitId: keep)) continue;
      if (!await _nativeCallIsProvablyStale(call)) continue;
      if (_nativeCallHasOwnedIdentity(call, keepCallkitId: keep)) continue;
      await _endNativeCallSafely(
        call.callkitId,
        reason: '$reason:end_stale_native',
      );
    }
  }

  Future<void> _endAllNativeCallsForAppReset({required String reason}) async {
    final nativeCalls = await _listNativeCallsSafely();
    for (final call in nativeCalls) {
      if (call.callkitId.trim().isEmpty) continue;
      await _endNativeCallSafely(
        call.callkitId,
        reason: '$reason:end_app_reset_native',
      );
    }
  }

  bool _nativeCallHasOwnedIdentity(
    NativeCallSnapshot call, {
    required String keepCallkitId,
  }) {
    final callkitId = call.callkitId.trim().toLowerCase();
    final protectedExactIds = <String>{
      keepCallkitId.trim().toLowerCase(),
      _current?.callkitId.trim().toLowerCase() ?? '',
      _pendingAcceptedInviteIntent?.payload.acceptedCallkitId
              .trim()
              .toLowerCase() ??
          '',
      _acceptedRouteContinuation?.payload.acceptedCallkitId
              .trim()
              .toLowerCase() ??
          '',
      _acceptedNativeRouteWatch?.payload.acceptedCallkitId
              .trim()
              .toLowerCase() ??
          '',
    }..remove('');
    if (callkitId.isNotEmpty && protectedExactIds.contains(callkitId)) {
      return true;
    }

    final inviteId = call.inviteId.trim();
    final channel = call.channel.trim();
    final ownedPayloads = <CallInvitePayload?>[
      _pendingIncomingPromptPayload,
      _pendingAcceptedInviteIntent?.payload,
      _acceptedRouteContinuation?.payload,
      _acceptedNativeRouteWatch?.payload,
    ];
    if (inviteId.isNotEmpty &&
        (_current?.inviteId == inviteId ||
            _incomingPromptInviteId == inviteId ||
            _nativeAcceptedCallInviteId == inviteId)) {
      return true;
    }
    if (channel.isNotEmpty && _current?.channel == channel) return true;
    for (final payload in ownedPayloads) {
      if (payload == null) continue;
      if (inviteId.isNotEmpty && payload.inviteId == inviteId) return true;
      if (channel.isNotEmpty && payload.channel == channel) return true;
    }
    return call.accepted;
  }

  Future<bool> _nativeCallIsProvablyStale(NativeCallSnapshot call) async {
    final inviteId = call.inviteId.trim();
    if (inviteId.isEmpty) return false;
    try {
      final data = _readInviteDataForTest != null
          ? await _readInviteDataForTest!(inviteId)
          : (await _db
                  .collection('callInvites')
                  .doc(inviteId)
                  .get(const GetOptions(source: Source.server))
                  .timeout(const Duration(seconds: 5)))
              .data();
      if (data == null) return true;
      return _isTerminalStatus(_parseStatus(data['status']));
    } catch (_) {
      return false;
    }
  }

  Future<bool> _hasLiveIncomingPrompt() async {
    if (!_incomingPromptActive) return false;
    final inviteId = (_incomingPromptInviteId ?? '').trim();
    if (inviteId.isEmpty) return false;
    Map<String, dynamic>? data;
    try {
      data = await _readInviteData(inviteId);
    } catch (error) {
      await _diagManager('incoming_prompt_verify_error', meta: {
        'inviteId': inviteId,
        'error': '$error',
      });
      // A read failure should not destroy a visible incoming prompt. Treat it
      // as still live so Accept can proceed to the guarded transaction path.
      return true;
    }
    if (data == null) return false;
    if (_parseStatus(data['status']) != CallInviteStatus.ringing) return false;
    final created = (data['createdAt'] as Timestamp?)?.toDate();
    if (created == null) return true;
    return DateTime.now().difference(created) <= const Duration(minutes: 2);
  }

  bool _shouldTreatSessionAsStale(
    _CallSession session,
    List<NativeCallSnapshot> nativeCalls,
  ) {
    if (session.isTerminal || _isTerminalStatus(session.status)) return true;

    final now = DateTime.now();
    final sessionAge = now.difference(session.createdAt);
    final touchAge = now.difference(session.lastTouchedAt);
    final hasMatchingNativeCall = nativeCalls.any((call) {
      return call.callkitId == session.callkitId ||
          (call.inviteId.isNotEmpty && call.inviteId == session.inviteId) ||
          (call.channel.isNotEmpty && call.channel == session.channel);
    });
    final hasManagedUi = _openingCallRoute ||
        _callRouteActive ||
        (_incomingPromptActive && _incomingPromptInviteId == session.inviteId);

    if (sessionAge > const Duration(minutes: 2)) return true;
    if (session.status == CallInviteStatus.ringing &&
        touchAge > _ringingTimeout + const Duration(seconds: 10)) {
      return true;
    }
    if ((session.status == CallInviteStatus.accepted ||
            session.status == CallInviteStatus.joining) &&
        touchAge > _acceptedJoiningTimeout + const Duration(seconds: 10)) {
      return true;
    }
    if (!hasMatchingNativeCall &&
        !hasManagedUi &&
        touchAge > const Duration(seconds: 20)) {
      return true;
    }
    return false;
  }

  void _touchSession(_CallSession session) {
    session.lastTouchedAt = DateTime.now();
  }

  Map<String, dynamic> _sessionSnapshot({
    List<NativeCallSnapshot>? nativeCalls,
  }) {
    final session = _current;
    return <String, dynamic>{
      'activeSessionPresent': session != null,
      'phase': session?.phase.name ?? CallSessionPhase.idle.name,
      'status': session?.status.name ?? CallInviteStatus.unknown.name,
      ..._callLifecycleArbiter.toSafeDebugMap(),
      'hasActiveUi': hasActiveUi,
      'hasActiveSession': hasActiveSession,
      'openingCallRoute': _openingCallRoute,
      'callRouteActive': _callRouteActive,
      'callRouteOwnerPresent': _callRouteOwner != null,
      'callRouteOwnerMatchesCurrent':
          _callRouteOwner?.ownsSession(session) ?? false,
      'incomingPromptActive': _incomingPromptActive,
      'incomingUiOwner': _incomingUiOwner.name,
      'iosCallkitOnlyPolicy': _iosCallkitOnlyIncomingUi,
      'awaitingPushkit': _awaitingPushkit,
      'callkitFallbackRequested': _callkitFallbackRequestedCount > 0,
      'callkitFallbackRequestedCount': _callkitFallbackRequestedCount,
      'callkitPresentationCount': _callkitPresentationCount,
      'flutterIncomingPromptCount': _flutterIncomingPromptCount,
      'iosFlutterIncomingPromptViolation':
          _iosFlutterIncomingPromptViolationCount > 0,
      'iosFlutterIncomingPromptViolationCount':
          _iosFlutterIncomingPromptViolationCount,
      'callkitAcceptCount': _callkitAcceptCount,
      'pendingAcceptedIntent': _pendingAcceptedInviteIntent != null,
      'pendingAcceptedRecorded': _pendingAcceptedRecorded,
      'pendingAcceptedClaimed': _pendingAcceptedClaimed,
      'pendingAcceptedContinuationStarted': _pendingAcceptedContinuationStarted,
      'pendingAcceptedContinuationCompleted':
          _pendingAcceptedContinuationCompleted,
      'previousTeardownCompleted': _previousTeardownCompleted,
      'acceptedRoutePending': _acceptedRouteContinuation != null,
      'acceptedRouteGenerationOwned': _acceptedRouteContinuation != null &&
          _callLifecycleArbiter.ownsGeneration(
            _acceptedRouteContinuation!.claimedGeneration,
          ),
      'acceptedRouteResumeTriggered': _acceptedRouteResumeTriggered,
      'acceptedRouteAttemptInFlight': _acceptedRouteAttemptInFlight,
      'acceptedRouteNavigatorUnavailable': _acceptedRouteNavigatorUnavailable,
      'acceptedRouteOpened': _acceptedRouteOpened,
      'acceptedRouteDiscarded': _acceptedRouteDiscarded,
      'appResumed': _acceptedRouteAppResumed,
      'acceptedBridgeIngestionStarted': _acceptedBridgeIngestionStarted,
      'acceptedOwnershipRecorded': _acceptedOwnershipRecorded,
      'acceptedRouteDeadlineReached': _acceptedRouteDeadlineReached,
      'acceptedRouteTerminalObserved': _acceptedRouteTerminalObserved,
      'nativeAcceptedCallActive': _nativeAcceptedCallInviteId != null,
      'acceptedNativeWatchActive': _acceptedNativeRouteWatch != null,
      'acceptedNativeWatchTerminalObserved':
          _acceptedNativeWatchTerminalObserved,
      'acceptedNativeWatchDeadlineReached': _acceptedNativeWatchDeadlineReached,
      'acceptedNativeExactIdPresent': _acceptedNativeExactIdPresent,
      'nativeEndRequested': _nativeEndRequested,
      'nativeEndVerified': _nativeEndVerified,
      'nativeEndEscalated': _nativeEndEscalated,
      'acceptedRecoverySingleFlight': _routeOpenCount <= 1,
      'routeOpenCount': _routeOpenCount,
      'rtcSetupOwnerCount': _rtcSetupOwnerCount,
      'authoritativeTerminalWriteCount': _authoritativeTerminalWriteCount,
      'staleRouteCompletionIgnoredCount': _staleRouteCompletionIgnoredCount,
      'terminalSignal': _terminalSignal.value?.status ?? '',
      'nativeCallCount': nativeCalls?.length ?? 0,
      'matchingNativeCallCount': nativeCalls == null
          ? _acceptedNativeMatchingCallCount
          : session == null
              ? _acceptedNativeMatchingCallCount
              : nativeCalls.where((call) {
                  return call.callkitId == session.callkitId ||
                      (call.inviteId.isNotEmpty &&
                          call.inviteId == session.inviteId) ||
                      (call.channel.isNotEmpty &&
                          call.channel == session.channel);
                }).length,
      'authReady': _currentUid.trim().isNotEmpty,
      'listenerBound': _incomingInviteSub != null,
      'listenerBoundToCurrentAuth': _incomingListenerBoundUid != null &&
          _incomingListenerBoundUid == _currentUid.trim(),
      'listenerBindingInProgress': _incomingListenerBindFuture != null,
      'listenerGeneration': _incomingListenerGeneration,
      'listenerHealthy': _incomingListenerLastHealthyAt != null,
      'listenerSnapshotReceived': _incomingListenerLastHealthyAt != null,
      'listenerErrorCount': _incomingListenerErrorCount,
      'listenerRebindCount': _incomingListenerRebindCount,
      'incomingInviteObserved': _incomingPromptInviteId != null ||
          _pendingIncomingPromptPayload != null,
      'callkitMatchFound': nativeCalls != null &&
          nativeCalls.any((call) =>
              session != null &&
              (call.callkitId == session.callkitId ||
                  call.inviteId == session.inviteId ||
                  call.channel == session.channel)),
      'callkitAcceptObserved': false,
      'acceptedRecoveryPending': _acceptedRecoveryPending,
      'acceptedRecoveryAttemptCount': _acceptedRecoveryAttemptCount,
      'acceptedRecoveryAcknowledged': _acceptedRecoveryAcknowledged,
      'navigatorReady': _navigatorKey?.currentState != null,
      'routeReservationOwned':
          _callLifecycleArbiter.toSafeDebugMap()['reservationStillOwned'] ==
              true,
      'routeOpened': _callRouteActive,
      'hiddenSessionDetected': session != null &&
          !_callRouteActive &&
          !_openingCallRoute &&
          !_incomingPromptActive,
      'terminalCleanupStarted': _callLifecycleArbiter.teardownInProgress,
      'terminalCleanupCompleted': isIdleForDebug,
      'sessionIdle': isIdleForDebug,
      'blockerCode': _acceptedNativeWatchBlockerCode,
    };
  }

  Future<void> _diagManager(
    String stage, {
    Map<String, dynamic>? meta,
  }) async {
    final safeMeta = _safeCallManagerDiagMeta(meta);
    final payload = safeMeta.toString();
    _lastDiagStage = stage;
    _lastDiagMeta = payload;
    debugPrint('[DIAG][call_manager] $stage meta=$payload');
    DiagnosticService.logCall(
      stage,
      uid: _currentUid,
      meta: safeMeta,
      counters: debugResourceCounts(),
    );
  }

  Future<bool> _updateInviteForActor({
    required String inviteId,
    required bool isCaller,
    required String stage,
    required Set<CallInviteStatus> expectedStatuses,
    Map<String, dynamic>? extra,
  }) async {
    if (inviteId.trim().isEmpty) return false;
    final prefix = isCaller ? 'caller' : 'callee';
    final update = <String, dynamic>{
      '${prefix}Stage': stage,
      ...?extra,
    };
    try {
      return await _db.runTransaction<bool>((tx) async {
        final ref = _db.collection('callInvites').doc(inviteId);
        final snap = await tx.get(ref);
        if (!snap.exists) return false;
        final data = snap.data() ?? const <String, dynamic>{};
        final status = _parseStatus(data['status']);
        if (!expectedStatuses.contains(status)) return false;
        tx.set(ref, update, SetOptions(merge: true));
        return true;
      });
    } catch (_) {
      return false;
    }
  }

  Future<void> _declineInviteTransaction(
    String inviteId, {
    required String source,
  }) async {
    if (inviteId.trim().isEmpty) return;
    try {
      await _db.runTransaction<void>((tx) async {
        final ref = _db.collection('callInvites').doc(inviteId);
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final data = snap.data() ?? const <String, dynamic>{};
        if (_parseStatus(data['status']) != CallInviteStatus.ringing) return;
        tx.set(
            ref,
            {
              'status': CallInviteStatus.declined.name,
              'declinedAt': FieldValue.serverTimestamp(),
              'endedAt': FieldValue.serverTimestamp(),
              'endedBy': _currentUid,
              'endReason': source,
              'calleeStage': 'declined',
            },
            SetOptions(merge: true));
      });
    } catch (_) {}
  }

  Future<void> _cancelOrphanOutgoingInvite(String inviteId) async {
    if (inviteId.trim().isEmpty) return;
    await _setInviteStatusIfCurrent(
      inviteId: inviteId,
      expectedStatuses: const <CallInviteStatus>{CallInviteStatus.ringing},
      updates: <String, dynamic>{
        'status': CallInviteStatus.cancelled.name,
        'cancelledAt': FieldValue.serverTimestamp(),
        'endedAt': FieldValue.serverTimestamp(),
        'endedBy': _currentUid,
        'endReason': 'orphan_outgoing_reservation_lost',
        'callerStage': 'cancelled',
      },
    );
  }

  Future<void> _setInviteStatusIfCurrent({
    required String inviteId,
    required Set<CallInviteStatus> expectedStatuses,
    required Map<String, dynamic> updates,
  }) async {
    if (inviteId.trim().isEmpty) return;
    try {
      await _db.runTransaction<void>((tx) async {
        final ref = _db.collection('callInvites').doc(inviteId);
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final data = snap.data() ?? const <String, dynamic>{};
        final status = _parseStatus(data['status']);
        if (!expectedStatuses.contains(status)) return;
        tx.set(ref, updates, SetOptions(merge: true));
      });
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _readInviteData(String inviteId) async {
    if (inviteId.trim().isEmpty) return null;
    final override = _readInviteDataForTest;
    if (override != null) {
      return override(inviteId);
    }
    final snap = await FirestoreReadHelper.getDoc(
      _db.collection('callInvites').doc(inviteId),
      timeout: const Duration(seconds: 5),
    );
    return snap.data();
  }

  Future<CallInvitePayload?> _loadInvitePayload({
    required String inviteId,
    required String fallbackChannel,
    required bool fallbackIsVideo,
    required String fallbackFromName,
    required String fallbackFromUid,
  }) async {
    final normalizedInviteId = inviteId.trim();
    Map<String, dynamic>? data;
    if (normalizedInviteId.isNotEmpty) {
      try {
        data = await _readInviteData(normalizedInviteId);
      } catch (error) {
        await _diagManager('invite_payload_read_fallback', meta: {
          'inviteId': normalizedInviteId,
          'channel': fallbackChannel,
          'error': '$error',
        });
      }
    }
    final currentUid = _currentUid.trim();
    final toUid = (data?['toUid'] ?? '').toString().trim();
    if (currentUid.isNotEmpty && toUid.isNotEmpty && toUid != currentUid) {
      return null;
    }
    final channel = (data?['channel'] ?? fallbackChannel).toString().trim();
    if (channel.isEmpty) return null;
    return CallInvitePayload(
      inviteId: normalizedInviteId.isEmpty ? channel : normalizedInviteId,
      channel: channel,
      isVideo: data == null ? fallbackIsVideo : _truthy(data['isVideo']),
      fromName: (data?['fromName'] ?? fallbackFromName).toString(),
      fromUid: (data?['fromUid'] ?? fallbackFromUid).toString().trim(),
      toUid: toUid,
      connectionSystem: callConnectionSystemFromInviteValue(
        data?['callSystem'],
      ),
    );
  }

  Future<NavigatorState?> _waitForNavigator() async {
    for (var i = 0; i < 20; i++) {
      final nav = _navigatorKey?.currentState;
      if (nav != null && nav.mounted) return nav;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return _navigatorKey?.currentState;
  }

  Future<void> _waitForAppResumed() async {
    for (var i = 0; i < 80; i++) {
      if (await _isAppActuallyForeground()) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<bool> _isAppActuallyForeground() async {
    final provider = _appForegroundProvider;
    if (provider != null) {
      try {
        return await provider();
      } catch (_) {}
    }
    return _appIsForeground;
  }

  bool get _appIsForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
  }

  bool _hasTrulyActiveCall() {
    final current = _current;
    if (current == null) return false;
    return !current.isTerminal;
  }

  bool _sessionMatchesOwnership(
    _CallSession? session, {
    required String inviteId,
    int? lifecycleGeneration,
    String acceptedCallkitId = '',
  }) {
    if (session == null || session.inviteId != inviteId.trim()) return false;
    if (lifecycleGeneration != null &&
        session.lifecycleGeneration != lifecycleGeneration) {
      return false;
    }
    final exactCallkitId = acceptedCallkitId.trim().toLowerCase();
    if (exactCallkitId.isNotEmpty &&
        session.acceptedCallkitId.trim().toLowerCase() != exactCallkitId) {
      return false;
    }
    return true;
  }

  void _clearCallRouteOwnershipForSession(_CallSession? session) {
    final owner = _callRouteOwner;
    if (owner != null && !owner.ownsSession(session)) return;
    _callRouteOwner = null;
    _callRouteActive = false;
  }

  bool _canApplyMediaProgress(
    _CallSession? session, {
    required String inviteId,
  }) {
    if (session == null || session.inviteId != inviteId) return false;
    return _canApplyMediaProgressForGeneration(
      inviteId: inviteId,
      generation: session.lifecycleGeneration,
    );
  }

  bool _canApplyMediaProgressForGeneration({
    required String inviteId,
    required int generation,
  }) {
    final session = _current;
    if (session == null || session.inviteId != inviteId) return false;
    if (session.lifecycleGeneration != generation) return false;
    if (session.isTerminal || _isTerminalStatus(session.status)) return false;
    if (!_callLifecycleArbiter.ownsGeneration(generation)) return false;
    final lifecycleState = _callLifecycleArbiter.state;
    return lifecycleState != CallV2CallLifecycleState.ending &&
        lifecycleState != CallV2CallLifecycleState.teardown;
  }

  static bool _isProgressStatus(CallInviteStatus status) {
    return status == CallInviteStatus.ringing ||
        status == CallInviteStatus.accepted ||
        status == CallInviteStatus.joining ||
        status == CallInviteStatus.connected;
  }

  void _cancelSessionTimers() {
    _ringingTimeoutTimer?.cancel();
    _ringingTimeoutTimer = null;
    _acceptedJoiningTimeoutTimer?.cancel();
    _acceptedJoiningTimeoutTimer = null;
  }

  void _schedulePendingIncomingPrompt(
    CallInvitePayload payload, {
    required String source,
    required String reason,
  }) {
    _pendingIncomingPromptPayload = payload;
    _pendingIncomingPromptSource = source;
    _pendingIncomingPromptRetryTimer?.cancel();
    _pendingIncomingPromptRetryTimer = Timer(
      const Duration(milliseconds: 600),
      () {
        unawaited(_retryPendingIncomingPrompt(reason: reason));
      },
    );
  }

  Future<void> _retryPendingIncomingPrompt({
    required String reason,
  }) async {
    final payload = _pendingIncomingPromptPayload;
    final source = _pendingIncomingPromptSource;
    if (payload == null || source == null) return;
    if (!_callLifecycleArbiter.isIdle || _hasTrulyActiveCall() || hasActiveUi) {
      _schedulePendingIncomingPrompt(
        payload,
        source: source,
        reason: 'retry_wait_${_callLifecycleArbiter.state.name}',
      );
      return;
    }
    Map<String, dynamic>? latest;
    try {
      latest = await _readInviteData(payload.inviteId);
    } catch (error) {
      await _diagManager('incoming_prompt_retry_read_error', meta: {
        'inviteId': payload.inviteId,
        'channel': payload.channel,
        'source': source,
        'reason': reason,
        'error': '$error',
      });
      _schedulePendingIncomingPrompt(
        payload,
        source: source,
        reason: 'retry_read_error',
      );
      return;
    }
    final status = _parseStatus(latest?['status']);
    if (latest == null || status != CallInviteStatus.ringing) {
      _clearPendingIncomingPrompt(payload.inviteId);
      return;
    }
    await _handleIncomingCandidate(
      payload,
      source: '$source:retry',
      via: 'pending_retry',
    );
  }

  void _clearPendingIncomingPrompt(String inviteId) {
    if (_pendingIncomingPromptPayload?.inviteId != inviteId) return;
    _pendingIncomingPromptRetryTimer?.cancel();
    _pendingIncomingPromptRetryTimer = null;
    _pendingIncomingPromptPayload = null;
    _pendingIncomingPromptSource = null;
  }

  void _restartTimeoutsForStatus(CallInviteStatus status) {
    _ringingTimeoutTimer?.cancel();
    _ringingTimeoutTimer = null;
    _acceptedJoiningTimeoutTimer?.cancel();
    _acceptedJoiningTimeoutTimer = null;

    final session = _current;
    if (session == null || session.isTerminal) return;

    if (status == CallInviteStatus.ringing) {
      _ringingTimeoutTimer = Timer(_ringingTimeout, () {
        unawaited(_markTerminal(
          inviteId: session.inviteId,
          status: CallInviteStatus.missed,
          message: 'No answer',
          isError: false,
          actorIsCaller: session.isCaller,
          endReason: 'ringing_timeout',
        ));
      });
      return;
    }

    if (status == CallInviteStatus.accepted ||
        status == CallInviteStatus.joining) {
      _restartAcceptedJoiningTimeout();
    }
  }

  void _restartAcceptedJoiningTimeout() {
    _acceptedJoiningTimeoutTimer?.cancel();
    final session = _current;
    if (session == null || session.isTerminal) return;
    _acceptedJoiningTimeoutTimer = Timer(_acceptedJoiningTimeout, () {
      unawaited(_markTerminal(
        inviteId: session.inviteId,
        status: CallInviteStatus.failed,
        message: 'Call connection timed out. Please try again.',
        isError: true,
        actorIsCaller: session.isCaller,
        endReason: 'accepted_joining_timeout',
        error: 'Invite stayed in accepted/joining without reaching connected.',
      ));
    });
  }

  void _pruneHandledInvites() {
    final now = DateTime.now();
    _handledInviteExpiries
        .removeWhere((_, expiresAt) => now.isAfter(expiresAt));
  }

  bool _isInviteHandledRecently(String inviteId) {
    _pruneHandledInvites();
    return _handledInviteExpiries.containsKey(inviteId.trim());
  }

  void _markInviteHandled(String inviteId) {
    final normalized = inviteId.trim();
    if (normalized.isEmpty) return;
    _pruneHandledInvites();
    _handledInviteExpiries[normalized] =
        DateTime.now().add(_callInviteHandledTtl);
  }

  static CallInviteStatus _parseStatus(dynamic raw) {
    switch ((raw ?? '').toString().trim().toLowerCase()) {
      case 'ringing':
        return CallInviteStatus.ringing;
      case 'accepted':
        return CallInviteStatus.accepted;
      case 'joining':
        return CallInviteStatus.joining;
      case 'connected':
        return CallInviteStatus.connected;
      case 'declined':
        return CallInviteStatus.declined;
      case 'missed':
        return CallInviteStatus.missed;
      case 'cancelled':
        return CallInviteStatus.cancelled;
      case 'ended':
        return CallInviteStatus.ended;
      case 'failed':
        return CallInviteStatus.failed;
      default:
        return CallInviteStatus.unknown;
    }
  }

  static bool _isTerminalStatus(CallInviteStatus status) {
    return status == CallInviteStatus.declined ||
        status == CallInviteStatus.missed ||
        status == CallInviteStatus.cancelled ||
        status == CallInviteStatus.ended ||
        status == CallInviteStatus.failed;
  }

  static bool _truthy(dynamic raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    return raw == true || value == 'true' || value == '1';
  }

  static Map<String, dynamic> _safeCallManagerDiagMeta(
    Map<String, dynamic>? meta,
  ) {
    if (meta == null || meta.isEmpty) return const <String, dynamic>{};
    final safe = <String, dynamic>{};
    for (final entry in meta.entries) {
      final key = entry.key;
      final lower = key.toLowerCase();
      if (lower.contains('uid') ||
          lower.contains('userid') ||
          lower.contains('inviteid') ||
          lower == 'channel' ||
          lower.contains('token') ||
          lower.contains('device')) {
        safe['identifierFieldPresent'] =
            entry.value.toString().trim().isNotEmpty;
        continue;
      }
      if (lower.contains('error')) {
        safe['errorCategory'] = _safeErrorCategory(entry.value);
        continue;
      }
      final value = entry.value;
      if (value == null || value is bool || value is num) {
        safe[key] = value;
      } else if (value is String) {
        safe[key] = _safeDiagString(value);
      } else if (value is Map || value is Iterable) {
        safe[key] = 'structured';
      } else {
        safe[key] = value.runtimeType.toString();
      }
    }
    return safe;
  }

  static String _safeDiagString(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    const allowed = <String>{
      'none',
      'disabled',
      'dev_callable_disabled',
      'active_ui_or_session',
      'caller_start',
      'manual_decline',
      'busy_active_call',
      'local_end',
      'screen_closed',
      'screen_closed_before_accept',
    };
    if (allowed.contains(trimmed)) return trimmed;
    if (RegExp(r'^[A-Za-z_]+:[A-Za-z_]+$').hasMatch(trimmed)) {
      return trimmed;
    }
    return trimmed.length > 64 ? 'text' : trimmed;
  }

  static String _safeErrorCategory(Object? value) {
    final text = (value ?? '').toString().toLowerCase();
    if (text.contains('timeout')) return 'timeout';
    if (text.contains('permission')) return 'permission';
    if (text.contains('network') || text.contains('unavailable')) {
      return 'network';
    }
    if (text.trim().isEmpty) return 'none';
    return 'error';
  }

  static String _truncate(String value, {int max = 300}) {
    final normalized = value.trim();
    if (normalized.length <= max) return normalized;
    return normalized.substring(0, max);
  }

  static String _terminalMessageForStatus(
    CallInviteStatus status, {
    Map<String, dynamic>? data,
  }) {
    switch (status) {
      case CallInviteStatus.declined:
        return 'Call declined';
      case CallInviteStatus.missed:
        return 'No answer';
      case CallInviteStatus.cancelled:
        return 'Call cancelled';
      case CallInviteStatus.failed:
        final reason = (data?['endReason'] ?? '').toString().trim();
        if (reason == 'accepted_joining_timeout' ||
            reason == 'agora_join_timeout') {
          return 'Call connection timed out. Please try again.';
        }
        return 'Call failed';
      case CallInviteStatus.ended:
      case CallInviteStatus.connected:
      case CallInviteStatus.accepted:
      case CallInviteStatus.joining:
      case CallInviteStatus.ringing:
      case CallInviteStatus.unknown:
        return 'Call ended';
    }
  }
}
