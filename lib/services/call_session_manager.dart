import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

enum _AcceptInviteResult {
  accepted,
  alreadyAccepted,
  notAllowed,
  unavailable,
}

enum IncomingUiOwner {
  none,
  callkit,
  flutter,
}

enum AcceptedCallRecoveryResult {
  opened,
  alreadyOpen,
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
  pending,
  callkitOwned,
  flutterPrompted,
  busy,
  ignored,
  failed,
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
    this.connectionSystem = CallV2RealCallConnectionSystem.legacyV1,
  });

  final String inviteId;
  final String channel;
  final bool isVideo;
  final String fromName;
  final String fromUid;
  final String toUid;
  final CallV2RealCallConnectionSystem connectionSystem;
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
typedef StoredAcceptedCallRecoveryClearer = Future<void> Function();
typedef AppForegroundProvider = Future<bool> Function();

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
  final int lifecycleGeneration;
  final DateTime createdAt;
  CallSessionPhase phase;
  CallInviteStatus status;
  DateTime lastTouchedAt;
  bool localJoined = false;
  bool remoteJoined = false;
  bool terminalSignalSent = false;

  bool get isTerminal => phase == CallSessionPhase.terminal;
  String get callkitId =>
      normalizeCallkitId(rawId: inviteId, fallback: channel);
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
  StoredAcceptedCallRecoveryClearer? _clearStoredAcceptedCallRecovery;
  AppForegroundProvider? _appForegroundProvider;
  Future<void> Function()? _afterOutgoingInviteWriteForTest;
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
  bool _incomingPromptActive = false;
  IncomingUiOwner _incomingUiOwner = IncomingUiOwner.none;
  String? _incomingPromptInviteId;
  CallInvitePayload? _pendingIncomingPromptPayload;
  String? _pendingIncomingPromptSource;
  String? _incomingListenerBoundUid;
  int _incomingListenerGeneration = 0;
  int _incomingListenerErrorCount = 0;
  int _incomingListenerRebindCount = 0;
  DateTime? _incomingListenerLastHealthyAt;
  int _acceptedRecoveryAttemptCount = 0;
  bool _acceptedRecoveryPending = false;
  bool _acceptedRecoveryAcknowledged = false;

  ValueNotifier<CallTerminalSignal?> get terminalSignal => _terminalSignal;

  FirebaseFirestore get _db => HelperlyTestRuntime.firestore;
  String get _currentUid => HelperlyTestRuntime.currentUid ?? '';
  bool get isIdleForDebug =>
      _callLifecycleArbiter.isIdle &&
      _current == null &&
      !hasActiveUi &&
      _terminalSignal.value == null;
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
    final activeListeners = activeCallSubscriptions;
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
    final activeTimers = [
      _ringingTimeoutTimer,
      _acceptedJoiningTimeoutTimer,
      _pendingIncomingPromptRetryTimer,
      _incomingListenerRebindTimer,
    ].where((timer) => timer != null && timer.isActive).length;
    return <String, int>{
      'activeListeners': activeListeners,
      'activeTimers': activeTimers,
      'activeCallSubscriptions': activeCallSubscriptions,
      'activeChatSubscriptions': 0,
      'incomingInviteListenerCount': incomingInviteListenerCount,
      'activeInviteListenerCount': activeInviteListenerCount,
      'ringingTimerCount': ringingTimerCount,
      'joiningTimerCount': joiningTimerCount,
      'pendingPromptTimerCount': pendingPromptTimerCount,
      'incomingListenerRebindTimerCount': incomingListenerRebindTimerCount,
      'listenerBindingInProgress': _incomingListenerBindFuture == null ? 0 : 1,
      'listenerGeneration': _incomingListenerGeneration,
      'listenerErrorCount': _incomingListenerErrorCount,
      'listenerRebindCount': _incomingListenerRebindCount,
    };
  }

  Future<void> forceIdleForTest() async {
    await _activeInviteSub?.cancel();
    _activeInviteSub = null;
    _cancelSessionTimers();
    _current = null;
    _terminalSignal.value = null;
    _openingCallRoute = false;
    _callRouteActive = false;
    _incomingPromptActive = false;
    _incomingUiOwner = IncomingUiOwner.none;
    _incomingPromptInviteId = null;
    _pendingIncomingPromptRetryTimer?.cancel();
    _pendingIncomingPromptRetryTimer = null;
    _pendingIncomingPromptPayload = null;
    _pendingIncomingPromptSource = null;
    _acceptedRecoveryPending = false;
    _acceptedRecoveryAcknowledged = false;
    _acceptedRecoveryAttemptCount = 0;
    _afterOutgoingInviteWriteForTest = null;
    _callLifecycleArbiter.forceIdleForTest();
  }

  String? get activeInviteId => _current?.inviteId;
  String? get activeChannel => _current?.channel;
  String get currentCallState =>
      (_current?.status ?? CallInviteStatus.unknown).name;
  bool get hasActiveUi =>
      _openingCallRoute || _callRouteActive || _incomingPromptActive;
  bool get hasActiveSession => _current != null && !_current!.isTerminal;
  bool get hasActiveUiOrSession => hasActiveUi || hasActiveSession;

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
    StoredAcceptedCallRecoveryClearer? clearStoredAcceptedCallRecovery,
    AppForegroundProvider? appForegroundProvider,
    Future<void> Function()? afterOutgoingInviteWriteForTest,
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
    if (clearStoredAcceptedCallRecovery != null) {
      _clearStoredAcceptedCallRecovery = clearStoredAcceptedCallRecovery;
    }
    if (appForegroundProvider != null) {
      _appForegroundProvider = appForegroundProvider;
    }
    if (afterOutgoingInviteWriteForTest != null) {
      _afterOutgoingInviteWriteForTest = afterOutgoingInviteWriteForTest;
    }
  }

  Future<int> debugCreateHeldCallRouteForTest({
    required String inviteId,
    required String channel,
    CallInviteStatus status = CallInviteStatus.connected,
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
    _current = _CallSession(
      inviteId: inviteId,
      channel: channel,
      isVideo: false,
      isCaller: true,
      otherUserId: 'test_remote',
      otherUserName: 'Test Remote',
      phase: CallSessionPhase.connected,
      status: status,
      lifecycleGeneration: reservation.generation,
    );
    _callRouteActive = true;
    return reservation.generation;
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
    _callRouteActive = false;
    _openingCallRoute = false;
    await _finalizeTerminalSessionCleanup(
      inviteId: inviteId,
      reason: 'debug_route_closed',
      forceClearUiFlags: true,
    );
  }

  void debugInvalidateLifecycleForTest() {
    if (!_debugTestAccessEnabled) {
      throw StateError('debugInvalidateLifecycleForTest is test-mode only');
    }
    _callLifecycleArbiter.invalidateForProductionReset();
  }

  void clearStaleUiFlags() {
    if (hasActiveSession) return;
    _openingCallRoute = false;
    _callRouteActive = false;
    _incomingPromptActive = false;
    _incomingPromptInviteId = null;
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

    final subscription = _db
        .collection('callInvites')
        .where('toUid', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) async {
      if (_currentUid.trim() != uid ||
          generation != _incomingListenerGeneration) {
        await _incomingInviteSub?.cancel();
        _incomingInviteSub = null;
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
      unawaited(_recoverIncomingInviteListenerAfterError(uid, generation));
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
  ) async {
    if (_currentUid.trim() != uid.trim() ||
        generation != _incomingListenerGeneration) {
      return;
    }
    await _incomingInviteSub?.cancel();
    _incomingInviteSub = null;
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
    await _resetSessionState(
      reason: 'signed_out',
      endCurrentNativeCall: true,
      endUnownedNativeCalls: true,
      clearStoredAcceptedRecovery: true,
      clearHandledInvites: true,
      forceClearUiFlags: true,
    );
    _callLifecycleArbiter.invalidateForProductionReset();
  }

  Future<void> hardResetForNewCall({
    String reason = 'hard_reset_for_new_call',
  }) async {
    try {
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
        _activeInviteSub = null;
        _cancelSessionTimers();
        _terminalSignal.value = null;
        if (session.callkitId.isNotEmpty) {
          await _endNativeCallSafely(
            session.callkitId,
            reason: '$reason:end_current_native',
          );
        }
        await _endStaleNativeCalls(
          keepCallkitId: session.callkitId.isEmpty ? null : session.callkitId,
          reason: reason,
        );
        await _clearStoredAcceptedCallRecoverySafely(reason);
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
  }) async {
    _acceptedRecoveryAttemptCount += 1;
    _acceptedRecoveryPending = true;
    _acceptedRecoveryAcknowledged = false;
    if (_currentUid.trim().isEmpty) {
      await _diagManager('accepted_recovery_pending', meta: {
        'authReady': false,
        'acceptedRecoveryAttemptCount': _acceptedRecoveryAttemptCount,
      });
      return AcceptedCallRecoveryResult.pendingAuth;
    }
    final nav = _navigatorKey?.currentState;
    if (nav == null || !nav.mounted) {
      await _diagManager('accepted_recovery_pending', meta: {
        'authReady': true,
        'navigatorReady': false,
        'acceptedRecoveryAttemptCount': _acceptedRecoveryAttemptCount,
      });
      return AcceptedCallRecoveryResult.pendingNavigator;
    }
    final payload = await _loadInvitePayload(
      inviteId: inviteId,
      fallbackChannel: channel,
      fallbackIsVideo: isVideo,
      fallbackFromName: fromName,
      fallbackFromUid: fromUid ?? '',
    );
    if (payload == null) {
      await _endNativeCallForInvite(
        inviteId: inviteId,
        channel: channel,
        reason: 'accepted_recovery_invalid',
      );
      _acceptedRecoveryPending = false;
      _acceptedRecoveryAcknowledged = true;
      await _clearStoredAcceptedCallRecoverySafely('accepted_recovery_invalid');
      return AcceptedCallRecoveryResult.invalid;
    }
    final latest = await _readInviteData(payload.inviteId);
    final status = _parseStatus(latest?['status']);
    if (latest == null || _isTerminalStatus(status)) {
      await _endNativeCallForInvite(
        inviteId: payload.inviteId,
        channel: payload.channel,
        reason: 'accepted_recovery_terminal',
      );
      _acceptedRecoveryPending = false;
      _acceptedRecoveryAcknowledged = true;
      await _clearStoredAcceptedCallRecoverySafely(
        'accepted_recovery_terminal',
      );
      return AcceptedCallRecoveryResult.terminal;
    }
    final result = await _handleIncomingCandidate(
      payload,
      source: 'callkit_recovery',
      via: 'callkit_recovery',
      autoAccept: true,
    );
    if (result == _IncomingCandidateResult.opened ||
        result == _IncomingCandidateResult.alreadyOpen) {
      _acceptedRecoveryPending = false;
      _acceptedRecoveryAcknowledged = true;
      await _clearStoredAcceptedCallRecoverySafely('accepted_recovery_opened');
      return result == _IncomingCandidateResult.alreadyOpen
          ? AcceptedCallRecoveryResult.alreadyOpen
          : AcceptedCallRecoveryResult.opened;
    }
    if (result == _IncomingCandidateResult.busy) {
      return AcceptedCallRecoveryResult.busy;
    }
    if (result == _IncomingCandidateResult.pending) {
      return AcceptedCallRecoveryResult.pendingNavigator;
    }
    return AcceptedCallRecoveryResult.failed;
  }

  Future<void> declineInvite({
    required String inviteId,
    String source = 'manual_decline',
  }) async {
    await _declineInviteTransaction(inviteId, source: source);
    await _endNativeCallForInvite(
      inviteId: inviteId,
      channel: '',
      reason: source,
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
    await _endNativeCallForInvite(
      inviteId: inviteId,
      channel: '',
      reason: source,
    );
  }

  Future<void> handleSystemTimeoutInvite({
    required String inviteId,
    String source = 'system_timeout',
  }) async {
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
    await _endNativeCallForInvite(
      inviteId: inviteId,
      channel: '',
      reason: source,
    );
  }

  Future<void> reportCallScreenBegan({
    required String inviteId,
    required bool isCaller,
  }) async {
    final session = _current;
    if (!_canApplyMediaProgress(session, inviteId: inviteId)) return;
    final generation = session!.lifecycleGeneration;

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
  }) async {
    final session = _current;
    if (session == null || session.inviteId != inviteId) return;
    if (session.isTerminal) return;

    final status =
        session.isCaller && session.status == CallInviteStatus.ringing
            ? CallInviteStatus.cancelled
            : CallInviteStatus.ended;
    final message =
        status == CallInviteStatus.cancelled ? 'Call cancelled' : 'Call ended';

    await _markTerminal(
      inviteId: inviteId,
      status: status,
      message: message,
      isError: false,
      actorIsCaller: session.isCaller,
      endReason: source,
    );
  }

  Future<void> handleCallScreenClosed(String inviteId) async {
    final session = _current;
    if (session == null || session.inviteId != inviteId) return;
    if (!session.isTerminal) {
      await endCallFromLocalUser(
        inviteId: inviteId,
        source: session.isCaller && session.status == CallInviteStatus.ringing
            ? 'screen_closed_before_accept'
            : 'screen_closed',
      );
    }
    if (_current?.inviteId == inviteId && _current!.isTerminal) {
      await _finalizeTerminalSessionCleanup(
        inviteId: inviteId,
        reason: 'call_screen_closed',
        forceClearUiFlags: true,
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
    if (status != CallInviteStatus.ringing) return;

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

  Future<_IncomingCandidateResult> _handleIncomingCandidate(
    CallInvitePayload payload, {
    required String source,
    required String via,
    bool autoAccept = false,
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
        return _acceptInviteAndOpen(
          payload,
          source: source,
          lifecycleGeneration: reservation.generation,
        );
      }
      if (_current?.inviteId == payload.inviteId && _callRouteActive) {
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
      await _diagManager('incoming_pending_recorded', meta: {
        'source': source,
        'via': via,
      });
      return _IncomingCandidateResult.pending;
    }
    if (!reservation.reserved) return _IncomingCandidateResult.ignored;

    await _diagManager('incoming_received', meta: {
      'source': source,
      'via': via,
      'isVideo': payload.isVideo,
      'callV2Selected':
          payload.connectionSystem == CallV2RealCallConnectionSystem.callV2Dev,
    });

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

    await _runPreflightSweepSafely(reason: 'incoming_candidate:$source');
    if (!_callLifecycleArbiter.ownsIncoming(
      generation: reservation.generation,
      inviteId: payload.inviteId,
    )) {
      return _IncomingCandidateResult.ignored;
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
      return _acceptInviteAndOpen(
        payload,
        source: source,
        lifecycleGeneration: reservation.generation,
      );
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
  }) async {
    if (lifecycleGeneration != null &&
        !_callLifecycleArbiter.ownsGeneration(lifecycleGeneration)) {
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
        !_callLifecycleArbiter.ownsGeneration(lifecycleGeneration)) {
      return _IncomingCandidateResult.ignored;
    }
    if (_hasTrulyActiveCall() && _current?.inviteId != payload.inviteId) {
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
    );
    if (lifecycleGeneration != null &&
        !_callLifecycleArbiter.ownsGeneration(lifecycleGeneration)) {
      return _IncomingCandidateResult.ignored;
    }
    if (acceptResult != _AcceptInviteResult.accepted &&
        acceptResult != _AcceptInviteResult.alreadyAccepted) {
      if (lifecycleGeneration != null) {
        _releaseFailedIncomingGeneration(lifecycleGeneration);
      }
      return _IncomingCandidateResult.failed;
    }
    await _diagManager('accepted', meta: {
      'inviteId': payload.inviteId,
      'channel': payload.channel,
      'source': source,
      'result': acceptResult.name,
    });

    Map<String, dynamic>? latest;
    try {
      latest = await _readInviteData(payload.inviteId);
    } catch (error) {
      await _diagManager('accepted_verify_fallback', meta: {
        'inviteId': payload.inviteId,
        'channel': payload.channel,
        'source': source,
        'error': '$error',
      });
    }
    if (lifecycleGeneration != null &&
        !_callLifecycleArbiter.ownsGeneration(lifecycleGeneration)) {
      return _IncomingCandidateResult.ignored;
    }
    final latestStatus = latest == null
        ? CallInviteStatus.accepted
        : _parseStatus(latest['status']);
    if (!(latestStatus == CallInviteStatus.accepted ||
        latestStatus == CallInviteStatus.joining ||
        latestStatus == CallInviteStatus.connected ||
        latestStatus == CallInviteStatus.ringing)) {
      if (lifecycleGeneration != null) {
        _releaseFailedIncomingGeneration(lifecycleGeneration);
      }
      await _endNativeCallForInvite(
        inviteId: payload.inviteId,
        channel: payload.channel,
        reason: 'accept_latest_terminal',
      );
      return _IncomingCandidateResult.ignored;
    }

    final generation = lifecycleGeneration ?? _callLifecycleArbiter.generation;
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
      lifecycleGeneration: generation,
    );

    _callLifecycleArbiter.markJoining(generation);
    final routeResult = await _activateSession(
      session,
      openScreen: true,
      source: source,
    );
    if (routeResult == _RouteOpenResult.opened) {
      return _IncomingCandidateResult.opened;
    }
    if (routeResult == _RouteOpenResult.alreadyOpenSameInvite) {
      return _IncomingCandidateResult.alreadyOpen;
    }
    _releaseFailedIncomingGeneration(generation);
    return routeResult == _RouteOpenResult.navigatorUnavailable
        ? _IncomingCandidateResult.pending
        : _IncomingCandidateResult.failed;
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

  Future<_AcceptInviteResult> _acceptInviteTransactionWithRetry(
    CallInvitePayload payload, {
    required String source,
  }) async {
    const maxAttempts = 3;
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      await _diagManager('accept_transaction_start', meta: {
        'inviteId': payload.inviteId,
        'channel': payload.channel,
        'source': source,
        'attempt': attempt,
      });
      try {
        final result =
            await _db.runTransaction<_AcceptInviteResult>((tx) async {
          final ref = _db.collection('callInvites').doc(payload.inviteId);
          final snap = await tx.get(ref);
          if (!snap.exists) return _AcceptInviteResult.notAllowed;
          final data = snap.data() ?? const <String, dynamic>{};
          final status = _parseStatus(data['status']);
          final toUid = (data['toUid'] ?? '').toString().trim();
          final me = _currentUid.trim();
          if (me.isEmpty || toUid != me) return _AcceptInviteResult.notAllowed;
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
            return _AcceptInviteResult.accepted;
          }
          if (status == CallInviteStatus.accepted ||
              status == CallInviteStatus.joining ||
              status == CallInviteStatus.connected) {
            return _AcceptInviteResult.alreadyAccepted;
          }
          return _AcceptInviteResult.notAllowed;
        }).timeout(const Duration(seconds: 8));

        await _diagManager('accept_transaction_done', meta: {
          'inviteId': payload.inviteId,
          'channel': payload.channel,
          'source': source,
          'attempt': attempt,
          'result': result.name,
        });
        return result;
      } catch (error) {
        lastError = error;
        final recoverable = FirestoreReadHelper.isRecoverableError(error);
        await _diagManager('accept_transaction_retry', meta: {
          'inviteId': payload.inviteId,
          'channel': payload.channel,
          'source': source,
          'attempt': attempt,
          'recoverable': recoverable,
          'error': '$error',
        });
        if (!recoverable || attempt == maxAttempts) break;
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
    return _AcceptInviteResult.unavailable;
  }

  Future<_RouteOpenResult> _activateSession(
    _CallSession session, {
    required bool openScreen,
    required String source,
  }) async {
    if (openScreen && _callRouteActive && activeInviteId == session.inviteId) {
      return _RouteOpenResult.alreadyOpenSameInvite;
    }
    if (openScreen && _openingCallRoute) {
      return _RouteOpenResult.routeBusy;
    }

    if (_current?.inviteId != session.inviteId) {
      await _activeInviteSub?.cancel();
      _activeInviteSub = null;
      _cancelSessionTimers();
      _terminalSignal.value = null;
    }

    _current = session;
    _touchSession(session);
    _markInviteHandled(session.inviteId);
    await _bindActiveInvite(session.inviteId);
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
    if (_callRouteActive && activeInviteId == session.inviteId) {
      return _RouteOpenResult.alreadyOpenSameInvite;
    }

    _openingCallRoute = true;
    try {
      await _waitForAppResumed();
      final nav = await _waitForNavigator();
      if (nav == null || !nav.mounted) {
        return _RouteOpenResult.navigatorUnavailable;
      }
      _callRouteActive = true;
      await _diagManager('route_push', meta: {
        'source': source,
        'callV2Selected': session.connectionSystem ==
            CallV2RealCallConnectionSystem.callV2Dev,
      });
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
            isCaller: session.isCaller,
            connectionSystem: session.connectionSystem,
            callV2FallbackUsed: session.callV2FallbackUsed,
            callV2BlockerCode: session.callV2BlockerCode,
          ),
        ),
      );
      unawaited(routeFuture.whenComplete(() async {
        _callRouteActive = false;
        if (_current?.inviteId == session.inviteId) {
          await _diagManager('route_pop', meta: {
            'source': source,
            'callV2Selected': session.connectionSystem ==
                CallV2RealCallConnectionSystem.callV2Dev,
          });
          await handleCallScreenClosed(session.inviteId);
        }
      }));
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

  Future<void> _rollbackFailedRouteSession(
    _CallSession session, {
    required String source,
    required _RouteOpenResult routeResult,
  }) async {
    if (_current?.inviteId != session.inviteId) return;
    await _activeInviteSub?.cancel();
    _activeInviteSub = null;
    _cancelSessionTimers();
    _terminalSignal.value = null;
    _current = null;
    _openingCallRoute = false;
    _callRouteActive = false;
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
  }) async {
    final session = _current;
    if (session == null || session.inviteId != inviteId) return;
    if (session.isTerminal) return;

    _callLifecycleArbiter.beginEnding(session.lifecycleGeneration);
    session.phase = CallSessionPhase.terminal;
    session.status = status;
    _touchSession(session);
    _cancelSessionTimers();

    final actorPrefix = actorIsCaller ? 'caller' : 'callee';
    final update = <String, dynamic>{
      'status': status.name,
      '${actorPrefix}Stage': status.name,
      'endedAt': FieldValue.serverTimestamp(),
      'endedBy': _currentUid,
      'endReason': endReason,
      if (status == CallInviteStatus.accepted)
        'acceptedAt': FieldValue.serverTimestamp(),
      if (status == CallInviteStatus.joining)
        'joiningAt': FieldValue.serverTimestamp(),
      if (status == CallInviteStatus.connected)
        'connectedAt': FieldValue.serverTimestamp(),
      if (status == CallInviteStatus.declined)
        'declinedAt': FieldValue.serverTimestamp(),
      if (status == CallInviteStatus.missed)
        'missedAt': FieldValue.serverTimestamp(),
      if (status == CallInviteStatus.cancelled)
        'cancelledAt': FieldValue.serverTimestamp(),
      if (status == CallInviteStatus.failed)
        'failedAt': FieldValue.serverTimestamp(),
      if (error != null && error.isNotEmpty)
        '${actorPrefix}LastError': _truncate(error),
    };

    try {
      await _db
          .collection('callInvites')
          .doc(inviteId)
          .set(update, SetOptions(merge: true));
    } catch (_) {}

    await _diagManager(
      status == CallInviteStatus.failed ? 'failed' : 'ended',
      meta: {
        'inviteId': inviteId,
        'status': status.name,
        'message': message,
        'endReason': endReason,
        if (error != null && error.isNotEmpty) 'error': error,
      },
    );
    await _endNativeCallForInvite(
      inviteId: inviteId,
      channel: session.channel,
      reason: endReason,
    );

    await _emitTerminalSignal(
      inviteId: inviteId,
      status: status,
      message: message,
      isError: isError,
    );
  }

  Future<void> _emitTerminalSignal({
    required String inviteId,
    required CallInviteStatus status,
    required String message,
    required bool isError,
  }) async {
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
  }) async {
    final session = _current;
    if (session == null || session.inviteId != inviteId) {
      if (forceClearUiFlags) {
        _openingCallRoute = false;
        _callRouteActive = false;
        _incomingPromptActive = false;
        _incomingPromptInviteId = null;
      }
      return;
    }
    if (!session.isTerminal && !_isTerminalStatus(session.status)) {
      return;
    }
    _callLifecycleArbiter.beginTeardown(session.lifecycleGeneration);
    final pendingPayload = _pendingIncomingPromptPayload;
    final pendingSource = _pendingIncomingPromptSource;
    await _resetSessionState(
      reason: reason,
      onlyInviteId: inviteId,
      endCurrentNativeCall: true,
      clearStoredAcceptedRecovery: true,
      forceClearUiFlags:
          forceClearUiFlags || (!_callRouteActive && !_openingCallRoute),
    );
    final pendingClaim = _callLifecycleArbiter.completeTeardownAndClaimPending(
      session.lifecycleGeneration,
    );
    if (!pendingClaim.claimed) return;
    final claimedInviteId = pendingClaim.inviteId;
    if (claimedInviteId == null ||
        pendingPayload == null ||
        pendingPayload.inviteId != claimedInviteId ||
        pendingSource == null) {
      if (claimedInviteId != null) {
        _callLifecycleArbiter.dropIncoming(
          generation: pendingClaim.generation,
          inviteId: claimedInviteId,
        );
      }
      return;
    }
    _incomingPromptActive = true;
    _incomingPromptInviteId = pendingPayload.inviteId;
    await _diagManager('incoming_pending_claimed_after_teardown', meta: {
      'source': pendingSource,
    });
    unawaited(_presentIncomingPrompt(
      pendingPayload,
      source: '$pendingSource:teardown_complete',
      lifecycleGeneration: pendingClaim.generation,
    ));
  }

  Future<void> _resetSessionState({
    required String reason,
    String? onlyInviteId,
    bool endCurrentNativeCall = false,
    bool endUnownedNativeCalls = false,
    bool clearStoredAcceptedRecovery = false,
    bool clearHandledInvites = false,
    bool forceClearUiFlags = false,
  }) async {
    final session = _current;
    final normalizedInviteId = onlyInviteId?.trim() ?? '';
    if (normalizedInviteId.isNotEmpty &&
        session != null &&
        session.inviteId != normalizedInviteId) {
      return;
    }

    final callkitId = session?.callkitId ??
        (normalizedInviteId.isEmpty
            ? ''
            : normalizeCallkitId(
                rawId: normalizedInviteId,
                fallback: session?.channel ?? '',
              ));

    await _activeInviteSub?.cancel();
    _activeInviteSub = null;
    _cancelSessionTimers();
    _pendingIncomingPromptRetryTimer?.cancel();
    _pendingIncomingPromptRetryTimer = null;
    _pendingIncomingPromptPayload = null;
    _pendingIncomingPromptSource = null;
    _current = null;
    _terminalSignal.value = null;

    if (forceClearUiFlags || !hasActiveSession) {
      _openingCallRoute = false;
      _callRouteActive = false;
      _incomingPromptActive = false;
      _incomingPromptInviteId = null;
      _incomingUiOwner = IncomingUiOwner.none;
    }

    if (clearHandledInvites) {
      _handledInviteExpiries.clear();
    }

    if (endCurrentNativeCall && callkitId.isNotEmpty) {
      await _endNativeCallSafely(
        callkitId,
        reason: '$reason:end_current_native',
      );
    }
    if (endUnownedNativeCalls) {
      await _endStaleNativeCalls(keepCallkitId: null, reason: reason);
    }
    if (clearStoredAcceptedRecovery) {
      await _clearStoredAcceptedCallRecoverySafely(reason);
      _acceptedRecoveryPending = false;
      _acceptedRecoveryAcknowledged = false;
      _acceptedRecoveryAttemptCount = 0;
    }
    await _diagResourceCounts('reset_session_state_done');
  }

  Future<void> _clearStoredAcceptedCallRecoverySafely(String reason) async {
    final clearer = _clearStoredAcceptedCallRecovery;
    if (clearer == null) return;
    try {
      await clearer();
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
    await Future<void>.delayed(const Duration(milliseconds: 250));
    match = await _matchingNativeCallForInvite(
      inviteId: payload.inviteId,
      channel: payload.channel,
    );
    return match == null ? IncomingUiOwner.flutter : IncomingUiOwner.callkit;
  }

  Future<void> _endNativeCallForInvite({
    required String inviteId,
    required String channel,
    required String reason,
  }) async {
    final normalizedInviteId = inviteId.trim();
    final normalizedChannel = channel.trim();
    final match = await _matchingNativeCallForInvite(
      inviteId: normalizedInviteId,
      channel: normalizedChannel,
    );
    final callkitId = match?.callkitId ??
        (normalizedInviteId.isEmpty && normalizedChannel.isEmpty
            ? ''
            : normalizeCallkitId(
                rawId: normalizedInviteId,
                fallback: normalizedChannel,
              ));
    if (callkitId.isEmpty) return;
    await _endNativeCallSafely(
      callkitId,
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
      if (keep.isNotEmpty && call.callkitId == keep) continue;
      await _endNativeCallSafely(
        call.callkitId,
        reason: '$reason:end_stale_native',
      );
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
      'incomingPromptActive': _incomingPromptActive,
      'incomingUiOwner': _incomingUiOwner.name,
      'terminalSignal': _terminalSignal.value?.status ?? '',
      'nativeCallCount': nativeCalls?.length ?? 0,
      'matchingNativeCallCount': session == null || nativeCalls == null
          ? 0
          : nativeCalls.where((call) {
              return call.callkitId == session.callkitId ||
                  (call.inviteId.isNotEmpty &&
                      call.inviteId == session.inviteId) ||
                  (call.channel.isNotEmpty && call.channel == session.channel);
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
      'blockerCode': 'none',
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
