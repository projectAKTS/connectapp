// lib/services/notification_service.dart
import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:permission_handler/permission_handler.dart';

import 'call_session_manager.dart';
import 'callkit_id.dart';
import 'current_chat.dart';
import 'diagnostic_service.dart';
import 'firestore_read_helper.dart';

class NotificationService with WidgetsBindingObserver {
  NotificationService({this.navigatorKey}) {
    CallSessionManager.instance.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: _listActiveCallkitCalls,
      endNativeCall: _endActiveCallkitCall,
      clearStoredAcceptedCallRecovery: _clearStoredAcceptedCallRecovery,
      appForegroundProvider: _isAppActuallyForeground,
    );
  }

  final GlobalKey<NavigatorState>? navigatorKey;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static const MethodChannel _pushTokenChannel =
      MethodChannel('connectapp/pushTokens');

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Used for important notifications.',
    importance: Importance.max,
  );

  bool _initialized = false;
  bool _observerBound = false;
  bool _notificationsAllowed = false;
  bool _localInitialized = false;
  bool _nativePushHandlerBound = false;
  String? _boundUid;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<CallEvent?>? _callkitSub;
  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _chatSubParticipants;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _chatSubUsers;
  final Map<String, DateTime> _recentCallkitTerminalEvents =
      <String, DateTime>{};
  final Map<String, DateTime> _recentAcceptedCallkitCalls =
      <String, DateTime>{};
  final Map<String, DateTime> _chatLastNotifiedAt = <String, DateTime>{};
  bool _appleTokensRegisteredForSession = false;
  bool _apnsRetryScheduled = false;
  Timer? _appleTokenRetryTimer;
  int _appleTokenRetryAttempts = 0;
  bool _messageHandlersBound = false;
  bool _chatListenerBindingInFlight = false;
  bool _resumeSyncInFlight = false;
  DateTime? _lastResumeSyncAt;
  bool _callPermissionsPrimed = false;
  bool _recoveringAcceptedCall = false;
  String? _lastRecoveredAcceptedAt;
  String? _pendingChatOpenOtherUserId;
  String? _pendingChatOpenChatId;
  bool _chatNavigationInFlight = false;
  static const bool _enableIosCallKit =
      bool.fromEnvironment('ENABLE_IOS_CALLKIT', defaultValue: true);
  static const bool _diagEnabled =
      bool.fromEnvironment('ENABLE_RUNTIME_DIAG', defaultValue: false);
  static const int _maxAppleTokenRetryAttempts = 8;

  int _notificationIdFrom(String seed) {
    final hash = seed.hashCode & 0x7fffffff;
    return hash == 0
        ? DateTime.now().millisecondsSinceEpoch & 0x7fffffff
        : hash;
  }

  int _nextNotificationId() =>
      DateTime.now().millisecondsSinceEpoch & 0x7fffffff;

  bool get _appIsActive {
    final state = WidgetsBinding.instance.lifecycleState;
    // iOS frequently enters `inactive` while still visibly foregrounded.
    // Treat it as active so incoming calls use the in-app accept screen
    // instead of falling back to a compact system banner.
    return state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
  }

  Future<bool> _isAppActuallyForeground() async {
    if (!Platform.isIOS) return _appIsActive;
    try {
      final rawState =
          await _pushTokenChannel.invokeMethod<String>('getApplicationState');
      switch ((rawState ?? '').trim().toLowerCase()) {
        case 'active':
        case 'inactive':
          return true;
        case 'background':
          return false;
      }
    } catch (_) {}
    return _appIsActive;
  }

  bool get _hasActiveIncomingUi =>
      CallSessionManager.instance.hasActiveUiOrSession;

  Future<void> _clearStoredAcceptedCallRecovery() async {
    if (!Platform.isIOS) return;
    try {
      await _pushTokenChannel.invokeMethod('clearStoredAcceptedCall');
    } catch (_) {}
  }

  Future<List<NativeCallSnapshot>> _listActiveCallkitCalls() async {
    if (!Platform.isIOS || !_enableIosCallKit) {
      return const <NativeCallSnapshot>[];
    }
    try {
      final activeCalls = await FlutterCallkitIncoming.activeCalls();
      if (activeCalls is! List) return const <NativeCallSnapshot>[];
      final snapshots = <NativeCallSnapshot>[];
      for (final raw in activeCalls) {
        if (raw is! Map) continue;
        final body = Map<String, dynamic>.from(raw);
        final extra = _eventExtra(body);
        final channel = _stringField(extra, body, 'channel');
        final inviteId = _stringField(
          extra,
          body,
          'inviteId',
          fallback: _stringField(
            extra,
            body,
            'callId',
            fallback: _stringField(
              extra,
              body,
              'id',
              fallback: _stringField(extra, body, 'uuid'),
            ),
          ),
        );
        final rawCallkitId = _stringField(
          extra,
          body,
          'id',
          fallback: _stringField(
            extra,
            body,
            'callkitId',
            fallback: _stringField(extra, body, 'uuid', fallback: channel),
          ),
        );
        snapshots.add(NativeCallSnapshot(
          callkitId: normalizeCallkitId(
            rawId: rawCallkitId,
            fallback: channel,
          ),
          inviteId: inviteId.trim(),
          channel: channel.trim(),
          accepted: _boolField(extra, body, 'accepted') ||
              _boolField(extra, body, 'isAccepted'),
        ));
      }
      return snapshots;
    } catch (e) {
      await _diagPush('callkit_active_calls_list_error', meta: {'error': '$e'});
      return const <NativeCallSnapshot>[];
    }
  }

  Future<void> _endActiveCallkitCall(
    String callkitId, {
    bool aggressive = true,
    String source = 'notification_service',
  }) async {
    if (!Platform.isIOS || !_enableIosCallKit) return;
    final normalized = callkitId.trim();
    final before = await _listActiveCallkitCalls();
    await _diagPush('callkit_cleanup_start', meta: {
      'callkitId': normalized,
      'source': source,
      'aggressive': aggressive,
    });
    await _diagPush('callkit_active_before', meta: {
      'callkitId': normalized,
      'count': before.length,
      'ids': before.map((call) => call.callkitId).join(','),
      'source': source,
      'aggressive': aggressive,
    });
    try {
      if (normalized.isNotEmpty) {
        await FlutterCallkitIncoming.endCall(normalized);
      }
      if (aggressive) {
        await FlutterCallkitIncoming.endAllCalls();
        await _diagPush('callkit_end_all_done', meta: {
          'callkitId': normalized,
          'source': source,
        });
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final remaining = await _listActiveCallkitCalls();
      for (final call in remaining) {
        if (call.callkitId.isEmpty) continue;
        if (!aggressive && call.callkitId != normalized) continue;
        try {
          await FlutterCallkitIncoming.endCall(call.callkitId);
        } catch (_) {}
      }
      if (remaining.any((call) => aggressive || call.callkitId == normalized)) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
      final after = await _listActiveCallkitCalls();
      await _diagPush('callkit_active_after', meta: {
        'callkitId': normalized,
        'count': after.length,
        'ids': after.map((call) => call.callkitId).join(','),
        'source': source,
        'aggressive': aggressive,
      });
    } catch (e) {
      await _diagPush('callkit_end_call_error', meta: {
        'callkitId': normalized,
        'error': '$e',
        'source': source,
        'aggressive': aggressive,
      });
      rethrow;
    }
  }

  Future<bool> _resetStaleIncomingUiIfNeeded() async {
    if (!Platform.isIOS || !_enableIosCallKit || !_hasActiveIncomingUi) {
      return false;
    }
    try {
      final activeCalls = await FlutterCallkitIncoming.activeCalls();
      final hasActiveCalls = activeCalls is List && activeCalls.isNotEmpty;
      if (hasActiveCalls) return false;
      final staleInviteId = CallSessionManager.instance.activeInviteId ?? '';
      CallSessionManager.instance.clearStaleUiFlags();
      _lastRecoveredAcceptedAt = null;
      await _clearStoredAcceptedCallRecovery();
      await _diagPush('stale_incoming_ui_reset', meta: {
        'inviteId': staleInviteId,
        'hadManagerUiOrSession': true,
      });
      return true;
    } catch (e) {
      await _diagPush('stale_incoming_ui_reset_error', meta: {'error': '$e'});
      return false;
    }
  }

  bool _isRecentIsoTimestamp(String value, Duration maxAge) {
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) return false;
    return DateTime.now().difference(parsed) <= maxAge;
  }

  bool _isRecentAcceptedCallTimestamp(String value) {
    return _isRecentIsoTimestamp(value, const Duration(minutes: 2));
  }

  Future<void> _diagResourceCounts(String stage) async {
    final activeCallSubscriptions = [
      _callkitSub,
    ].where((sub) => sub != null).length;
    final activeChatSubscriptions = [
      _chatSubParticipants,
      _chatSubUsers,
    ].where((sub) => sub != null).length;
    final activeListeners = [
      _tokenSub,
      _callkitSub,
      _messageSub,
      _messageOpenedSub,
      _chatSubParticipants,
      _chatSubUsers,
    ].where((sub) => sub != null).length;
    final activeTimers = [
      _appleTokenRetryTimer,
    ].where((timer) => timer != null && timer.isActive).length;
    final counters = <String, int>{
      'activeListeners': activeListeners,
      'activeTimers': activeTimers,
      'activeCallSubscriptions': activeCallSubscriptions,
      'activeChatSubscriptions': activeChatSubscriptions,
    };
    DiagnosticService.updateCounters(
      counters,
      uid: FirebaseAuth.instance.currentUser?.uid,
    );
    await _diagPush(stage, meta: {
      ...counters,
      'boundUid': _boundUid ?? '',
      'initialized': _initialized,
    });
  }

  String _tokenSuffix(String token) {
    final value = token.trim();
    if (value.isEmpty) return '';
    return value.length <= 12 ? value : value.substring(value.length - 12);
  }

  bool _shouldProcessCallkitTerminalEvent(
    Object event,
    String inviteId,
    String callkitId,
  ) {
    final now = DateTime.now();
    _recentCallkitTerminalEvents.removeWhere(
      (_, seenAt) => now.difference(seenAt) > const Duration(seconds: 10),
    );
    final key = '${event.toString()}|${inviteId.trim()}|${callkitId.trim()}';
    final seenAt = _recentCallkitTerminalEvents[key];
    if (seenAt != null &&
        now.difference(seenAt) < const Duration(seconds: 10)) {
      return false;
    }
    _recentCallkitTerminalEvents[key] = now;
    return true;
  }

  void _rememberAcceptedCallkitCall(String inviteId, String callkitId) {
    final now = DateTime.now();
    _recentAcceptedCallkitCalls.removeWhere(
      (_, seenAt) => now.difference(seenAt) > const Duration(seconds: 20),
    );
    final trimmedInviteId = inviteId.trim();
    final trimmedCallkitId = callkitId.trim();
    if (trimmedInviteId.isNotEmpty) {
      _recentAcceptedCallkitCalls['invite:$trimmedInviteId'] = now;
    }
    if (trimmedCallkitId.isNotEmpty) {
      _recentAcceptedCallkitCalls['callkit:$trimmedCallkitId'] = now;
    }
  }

  bool _wasRecentlyAcceptedCallkitCall(String inviteId, String callkitId) {
    final now = DateTime.now();
    _recentAcceptedCallkitCalls.removeWhere(
      (_, seenAt) => now.difference(seenAt) > const Duration(seconds: 20),
    );
    final trimmedInviteId = inviteId.trim();
    final trimmedCallkitId = callkitId.trim();
    final inviteSeenAt = trimmedInviteId.isEmpty
        ? null
        : _recentAcceptedCallkitCalls['invite:$trimmedInviteId'];
    if (inviteSeenAt != null &&
        now.difference(inviteSeenAt) < const Duration(seconds: 20)) {
      return true;
    }
    final callkitSeenAt = trimmedCallkitId.isEmpty
        ? null
        : _recentAcceptedCallkitCalls['callkit:$trimmedCallkitId'];
    if (callkitSeenAt != null &&
        now.difference(callkitSeenAt) < const Duration(seconds: 20)) {
      return true;
    }
    return false;
  }

  bool _shouldIgnoreSyntheticAcceptedCallkitEnd(
      String inviteId, String callkitId) {
    if (!_wasRecentlyAcceptedCallkitCall(inviteId, callkitId)) {
      return false;
    }
    return CallSessionManager.instance.hasActiveUiOrSession ||
        _recoveringAcceptedCall;
  }

  String _otherUserIdFromChatId(String chatId, String currentUid) {
    final id = chatId.trim();
    final me = currentUid.trim();
    if (id.isEmpty || me.isEmpty) return '';

    final prefix = '${me}_';
    if (id.startsWith(prefix) && id.length > prefix.length) {
      return id.substring(prefix.length);
    }
    final suffix = '_$me';
    if (id.endsWith(suffix) && id.length > suffix.length) {
      return id.substring(0, id.length - suffix.length);
    }

    final parts = id.split('_');
    if (parts.length == 2) {
      return parts.first == me ? parts.last : parts.first;
    }
    return '';
  }

  Future<void> _diagPush(
    String stage, {
    Map<String, dynamic>? meta,
  }) async {
    debugPrint('[DIAG][push] $stage meta=${meta ?? const {}}');
    DiagnosticService.logPush(
      stage,
      uid: FirebaseAuth.instance.currentUser?.uid,
      meta: meta,
    );
  }

  Future<void> _pruneLegacyDiagTrailIfNeeded() async {
    if (_diagEnabled) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'diag.callTrail': FieldValue.delete(),
        'diag.pushTrail': FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Call once after Firebase is initialized and user signed in.
  Future<void> initialize() async {
    if (!_observerBound) {
      WidgetsBinding.instance.addObserver(this);
      _observerBound = true;
    }

    final appActuallyForeground = await _isAppActuallyForeground();
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      debugPrint(
        'ℹ️ Notification init continuing while lifecycle='
        '${WidgetsBinding.instance.lifecycleState}; foreground=$appActuallyForeground',
      );
    }

    if (_initialized) {
      DiagnosticService.logLifecycle(
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
        uid: FirebaseAuth.instance.currentUser?.uid,
        counters: <String, int>{
          'activeListeners': [
            _tokenSub,
            _callkitSub,
            _messageSub,
            _messageOpenedSub,
            _chatSubParticipants,
            _chatSubUsers,
          ].where((sub) => sub != null).length,
          'activeTimers': [
            _appleTokenRetryTimer,
          ].where((timer) => timer != null && timer.isActive).length,
          'activeCallSubscriptions': [
            _callkitSub,
          ].where((sub) => sub != null).length,
          'activeChatSubscriptions': [
            _chatSubParticipants,
            _chatSubUsers,
          ].where((sub) => sub != null).length,
        },
      );
      await _rebindForCurrentUser();
      await _recoverAcceptedCallkitCall();
      return;
    }
    _initialized = true;
    await _pruneLegacyDiagTrailIfNeeded();
    DiagnosticService.logLifecycle(
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
      uid: FirebaseAuth.instance.currentUser?.uid,
      counters: <String, int>{
        'activeListeners': [
          _tokenSub,
          _callkitSub,
          _messageSub,
          _messageOpenedSub,
          _chatSubParticipants,
          _chatSubUsers,
        ].where((sub) => sub != null).length,
        'activeTimers': [
          _appleTokenRetryTimer,
        ].where((timer) => timer != null && timer.isActive).length,
        'activeCallSubscriptions': [
          _callkitSub,
        ].where((sub) => sub != null).length,
        'activeChatSubscriptions': [
          _chatSubParticipants,
          _chatSubUsers,
        ].where((sub) => sub != null).length,
      },
    );
    await _diagPush('initialize_start');

    try {
      final existingSettings = await _fcm.getNotificationSettings();
      final existingStatus = existingSettings.authorizationStatus;
      if (existingStatus != AuthorizationStatus.notDetermined) {
        _notificationsAllowed =
            existingStatus == AuthorizationStatus.authorized ||
                existingStatus == AuthorizationStatus.provisional;
      } else if (appActuallyForeground) {
        final requested = await _fcm.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        _notificationsAllowed = requested.authorizationStatus ==
                AuthorizationStatus.authorized ||
            requested.authorizationStatus == AuthorizationStatus.provisional;
      } else {
        _notificationsAllowed = false;
      }
    } catch (e) {
      debugPrint('⚠️ requestPermission failed: $e');
      _notificationsAllowed = false;
      await _diagPush('permission_error', meta: {'error': '$e'});
    }
    await _diagPush('permission_result', meta: {
      'allowed': _notificationsAllowed,
    });
    if (Platform.isIOS) {
      await _refreshNativePushRegistrations();
    }

    // iOS categories (for call actions)
    final iosInit = DarwinInitializationSettings(
      notificationCategories: [
        DarwinNotificationCategory(
          'INCOMING_CALL',
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain('ACCEPT_CALL', 'Accept'),
            DarwinNotificationAction.plain(
              'DECLINE_CALL',
              'Decline',
              options: {DarwinNotificationActionOption.destructive},
            ),
          ],
          options: {DarwinNotificationCategoryOption.customDismissAction},
        ),
      ],
    );

    final initSettings = InitializationSettings(
      android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: iosInit,
    );

    if (_notificationsAllowed) {
      try {
        await _fcm.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (e) {
        debugPrint('⚠️ Foreground presentation setup failed: $e');
      }

      try {
        await _local.initialize(
          initSettings,
          onDidReceiveNotificationResponse: (resp) async {
            final payload = resp.payload ?? '';
            final actionId = resp.actionId;

            if (payload.startsWith('incoming_call2|')) {
              final parts = payload.split('|');
              if (parts.length >= 6) {
                final channel = parts[1];
                final isVideo = parts[2] == 'true';
                final fromName = parts[3];
                final fromUid = parts[4];
                final inviteId = parts[5];

                if (actionId == 'DECLINE_CALL') {
                  await CallSessionManager.instance.declineInvite(
                    inviteId: inviteId,
                    source: 'local_notification_decline',
                  );
                  return;
                }
                await CallSessionManager.instance.handleNotificationInviteTap(
                  inviteId: inviteId,
                  channel: channel,
                  isVideo: isVideo,
                  fromName: fromName,
                  fromUid: fromUid.isEmpty ? null : fromUid,
                  autoAccept: actionId == 'ACCEPT_CALL',
                  source: actionId == 'ACCEPT_CALL'
                      ? 'local_notification_accept'
                      : 'local_notification_tap',
                );
                return;
              }
            }

            if (payload.startsWith('incoming_call|')) {
              final parts =
                  payload.split('|'); // incoming_call|channel|isVideo|fromName
              if (parts.length >= 4) {
                final channel = parts[1];
                final isVideo = parts[2] == 'true';
                final fromName = parts[3];

                await CallSessionManager.instance.handleNotificationInviteTap(
                  inviteId: '',
                  channel: channel,
                  isVideo: isVideo,
                  fromName: fromName,
                  autoAccept: actionId == 'ACCEPT_CALL',
                  source: actionId == 'ACCEPT_CALL'
                      ? 'legacy_local_notification_accept'
                      : 'legacy_local_notification_tap',
                );
                return;
              }
            }

            if (payload.startsWith('open_chat|')) {
              final parts = payload.split('|');
              final otherUserId = parts.length >= 2 ? parts[1] : '';
              final chatId = parts.length >= 3 ? parts[2] : '';
              _openChat(otherUserId, chatId: chatId);
            }
          },
        );
        _localInitialized = true;
      } catch (e) {
        debugPrint('⚠️ Local notifications init failed: $e');
        await _diagPush('local_init_error', meta: {'error': '$e'});
      }

      try {
        await _local
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_androidChannel);
      } catch (e) {
        debugPrint('⚠️ Android notification channel create failed: $e');
        await _diagPush('android_channel_error', meta: {'error': '$e'});
      }
    }

    if (!_nativePushHandlerBound) {
      _pushTokenChannel.setMethodCallHandler(_handleNativePushMethodCall);
      _nativePushHandlerBound = true;
    }

    if (Platform.isIOS) {
      await _bindCallkitEvents();
    }
    await CallSessionManager.instance.bindIncomingInviteListener();
    await _bindChatListener();

    // Foreground + tap handlers
    if (!_messageHandlersBound) {
      await _messageSub?.cancel();
      await _messageOpenedSub?.cancel();
      _messageSub = FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) => _handleMessage(message, showLocal: true),
      );
      _messageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage message) => _handleMessage(message, showLocal: false),
      );
      _messageHandlersBound = true;
    }
    await _diagResourceCounts('initialize_handlers_bound');

    // App opened from terminated via push
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      await _diagPush('initial_message_received');
      await _handleMessage(initial, showLocal: false);
    }

    // Token registration should run regardless of local notification permission,
    // otherwise closed-app push delivery can silently break.
    if (Platform.isIOS) {
      await _registerApplePushTokens(force: true);
    }
    await _registerFcmToken();
    _boundUid = FirebaseAuth.instance.currentUser?.uid;

    // Keep user doc in sync on token refresh
    _tokenSub?.cancel();
    _tokenSub = _fcm.onTokenRefresh.listen((newToken) async {
      await _diagPush('token_refresh');
      await _registerFcmToken(forceToken: newToken);
    });
    await _primeCallPermissionsIfNeeded();
    await _recoverAcceptedCallkitCall();
    await _flushPendingChatOpen();
    await _diagPush('initialize_done');
  }

  Future<void> _clearUserBindings() async {
    await _diagResourceCounts('clear_user_bindings_start');
    await CallSessionManager.instance.clearForSignedOut();
    await _chatSubParticipants?.cancel();
    _chatSubParticipants = null;
    await _chatSubUsers?.cancel();
    _chatSubUsers = null;
    _chatListenerBindingInFlight = false;
    _recentCallkitTerminalEvents.clear();
    _recentAcceptedCallkitCalls.clear();
    _chatLastNotifiedAt.clear();
    _appleTokensRegisteredForSession = false;
    _apnsRetryScheduled = false;
    _appleTokenRetryTimer?.cancel();
    _appleTokenRetryTimer = null;
    _appleTokenRetryAttempts = 0;
    _boundUid = null;
    await _diagResourceCounts('clear_user_bindings_done');
  }

  Future<void> onSignedOut() async {
    await _clearUserBindings();
  }

  Future<void> _rebindForCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      await _clearUserBindings();
      return;
    }

    if (_boundUid == uid &&
        (_chatSubParticipants != null || _chatSubUsers != null)) {
      await CallSessionManager.instance.bindIncomingInviteListener();
      await _bindChatListener();
      await _pruneLegacyDiagTrailIfNeeded();
      await _diagResourceCounts('rebind_same_user');
      if (Platform.isIOS) {
        await _registerApplePushTokens(force: true);
      }
      await _registerFcmToken();
      return;
    }

    await _clearUserBindings();
    _boundUid = uid;
    await _refreshNativePushRegistrations();
    await CallSessionManager.instance.bindIncomingInviteListener();
    await _bindChatListener();
    if (Platform.isIOS) {
      await _registerApplePushTokens(force: true);
    }
    await _pruneLegacyDiagTrailIfNeeded();
    await _registerFcmToken();
    await _diagPush('rebind_done', meta: {'uid': uid});
  }

  Future<void> dispose() async {
    await _diagResourceCounts('notification_dispose_start');
    if (_observerBound) {
      WidgetsBinding.instance.removeObserver(this);
      _observerBound = false;
    }
    await _tokenSub?.cancel();
    _tokenSub = null;
    await _callkitSub?.cancel();
    _callkitSub = null;
    await _messageSub?.cancel();
    _messageSub = null;
    await _messageOpenedSub?.cancel();
    _messageOpenedSub = null;
    _messageHandlersBound = false;
    await _chatSubParticipants?.cancel();
    _chatSubParticipants = null;
    await _chatSubUsers?.cancel();
    _chatSubUsers = null;
    _recentCallkitTerminalEvents.clear();
    _recentAcceptedCallkitCalls.clear();
    _chatLastNotifiedAt.clear();
    _appleTokensRegisteredForSession = false;
    _apnsRetryScheduled = false;
    _appleTokenRetryTimer?.cancel();
    _appleTokenRetryTimer = null;
    _appleTokenRetryAttempts = 0;
    if (_nativePushHandlerBound) {
      _pushTokenChannel.setMethodCallHandler(null);
      _nativePushHandlerBound = false;
    }
    _boundUid = null;
    _initialized = false;
  }

  Future<dynamic> _handleNativePushMethodCall(MethodCall call) async {
    if (call.method == 'incomingVoipForeground') {
      final rawArgs = call.arguments;
      if (rawArgs is! Map) return null;
      final data = Map<String, dynamic>.from(rawArgs.cast<dynamic, dynamic>());
      final channel = (data['channel'] ?? '').toString().trim();
      final inviteId =
          ((data['inviteId'] ?? data['callId'] ?? channel)).toString().trim();
      final fromName = (data['fromName'] ?? 'Caller').toString();
      final fromUid = (data['fromUid'] ?? '').toString().trim();
      final isVideo = _videoField(data, const <String, dynamic>{});
      await _diagPush('pushkit_foreground_handoff_received', meta: {
        'inviteId': inviteId,
        'channel': channel,
        'fromUid': fromUid,
        'isVideo': isVideo,
        'appState': (data['appState'] ?? '').toString(),
      });
      if (channel.isEmpty || inviteId.isEmpty) return null;

      // Return to native before invoking any plugin or method channel. Calling
      // back into iOS while handling an iOS -> Flutter method call can deadlock
      // the channel and prevent the invite from ever reaching the manager.
      unawaited(
        Future<void>.delayed(Duration.zero, () async {
          try {
            await _diagPush('pushkit_foreground_handoff_dispatched', meta: {
              'inviteId': inviteId,
              'channel': channel,
            });
            await CallSessionManager.instance.handleNotificationInviteTap(
              inviteId: inviteId,
              channel: channel,
              isVideo: isVideo,
              fromName: fromName,
              fromUid: fromUid.isEmpty ? null : fromUid,
              source: 'pushkit_foreground_handoff',
            );
          } catch (error) {
            await _diagPush('pushkit_foreground_handoff_error', meta: {
              'inviteId': inviteId,
              'channel': channel,
              'error': '$error',
            });
          }
        }),
      );
      return true;
    }
    return null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    DiagnosticService.logLifecycle(
      state,
      uid: FirebaseAuth.instance.currentUser?.uid,
      counters: <String, int>{
        'activeListeners': [
          _tokenSub,
          _callkitSub,
          _messageSub,
          _messageOpenedSub,
          _chatSubParticipants,
          _chatSubUsers,
        ].where((sub) => sub != null).length,
        'activeTimers': [
          _appleTokenRetryTimer,
        ].where((timer) => timer != null && timer.isActive).length,
        'activeCallSubscriptions': [
          _callkitSub,
        ].where((sub) => sub != null).length,
        'activeChatSubscriptions': [
          _chatSubParticipants,
          _chatSubUsers,
        ].where((sub) => sub != null).length,
      },
    );
    if (state != AppLifecycleState.resumed) return;
    unawaited(FirestoreReadHelper.recoverNetwork(reason: 'app_resumed'));
    if (!_initialized) {
      unawaited(initialize());
      return;
    }
    unawaited(_syncOnResume());
  }

  Future<void> _syncOnResume() async {
    final now = DateTime.now();
    final lastSync = _lastResumeSyncAt;
    if (_resumeSyncInFlight) return;
    if (lastSync != null &&
        now.difference(lastSync) < const Duration(seconds: 3)) {
      return;
    }
    _resumeSyncInFlight = true;
    try {
      await FirestoreReadHelper.recoverNetwork(reason: 'resume_sync');
      await _rebindForCurrentUser();
      await CallSessionManager.instance
          .recoverForegroundIncomingInvites(source: 'resume_sync');
      await _primeCallPermissionsIfNeeded();
      await _resetStaleIncomingUiIfNeeded();
      await _recoverAcceptedCallkitCall();
      await _flushPendingChatOpen();
    } finally {
      _lastResumeSyncAt = DateTime.now();
      _resumeSyncInFlight = false;
    }
  }

  Future<void> _primeCallPermissionsIfNeeded() async {
    if (!Platform.isIOS || _callPermissionsPrimed) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _callPermissionsPrimed = true;
    try {
      final micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted && !micStatus.isPermanentlyDenied) {
        await Permission.microphone.request();
      }
    } catch (_) {}
    try {
      final cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted && !cameraStatus.isPermanentlyDenied) {
        await Permission.camera.request();
      }
    } catch (_) {}
  }

  Future<void> _refreshNativePushRegistrations() async {
    if (!Platform.isIOS) return;
    try {
      await _pushTokenChannel.invokeMethod('refreshPushRegistrations');
      await _diagPush('native_push_refresh_requested');
    } catch (e) {
      await _diagPush('native_push_refresh_error', meta: {'error': '$e'});
    }
  }

  Future<void> _bindChatListener() async {
    if (_chatListenerBindingInFlight) return;
    _chatListenerBindingInFlight = true;
    try {
      await _chatSubParticipants?.cancel();
      _chatSubParticipants = null;
      await _chatSubUsers?.cancel();
      _chatSubUsers = null;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        return;
      }

      Future<void> process(QuerySnapshot<Map<String, dynamic>> snap) async {
        final appActive = await _isAppActuallyForeground();
        for (final change in snap.docChanges) {
          if (change.type != DocumentChangeType.added &&
              change.type != DocumentChangeType.modified) {
            continue;
          }
          final data = change.doc.data() ?? const <String, dynamic>{};
          final updated = _timestampToDate(data['updatedAt']) ??
              _timestampToDate(data['lastMessageAt']);
          if (updated == null) continue;
          final last = _chatLastNotifiedAt[change.doc.id];
          if (last != null && !updated.isAfter(last)) continue;
          _chatLastNotifiedAt[change.doc.id] = updated;

          final author = (data['lastMessageAuthorId'] ?? '').toString();
          if (author.isEmpty || author == uid) continue;

          final users = <String>{
            ...((data['users'] as List?) ?? const []).map((e) => '$e'),
            ...((data['participants'] as List?) ?? const []).map((e) => '$e'),
          }.toList();
          String otherUid = users.firstWhere((e) => e != uid, orElse: () => '');
          if (otherUid.isEmpty) {
            otherUid = _otherUserIdFromChatId(change.doc.id, uid);
          }
          if (otherUid.isEmpty) continue;
          if (CurrentChat.otherUserId == otherUid) continue;
          if (!_localInitialized) continue;
          if (!appActive) {
            continue;
          }

          await _diagPush('chat_firestore_local_notification', meta: {
            'chatId': change.doc.id,
            'otherUserId': otherUid,
          });
          try {
            final notifId = _notificationIdFrom(
              'chat_firestore_${change.doc.id}_${updated.millisecondsSinceEpoch}',
            );
            await _local.show(
              notifId,
              'New Message',
              'You received a new message',
              NotificationDetails(
                android: AndroidNotificationDetails(
                  _androidChannel.id,
                  _androidChannel.name,
                  channelDescription: _androidChannel.description,
                  importance: Importance.max,
                  priority: Priority.high,
                ),
                iOS: const DarwinNotificationDetails(),
              ),
              payload: 'open_chat|$otherUid|${change.doc.id}',
            );
          } catch (_) {}
        }
      }

      _chatSubParticipants = FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: uid)
          .snapshots()
          .listen((snap) => process(snap), onError: (_) {});
      _chatSubUsers = FirebaseFirestore.instance
          .collection('chats')
          .where('users', arrayContains: uid)
          .snapshots()
          .listen((snap) => process(snap), onError: (_) {});
      await _diagResourceCounts('chat_listener_bound');
    } finally {
      _chatListenerBindingInFlight = false;
    }
  }

  Future<void> _bindCallkitEvents() async {
    await _callkitSub?.cancel();
    _callkitSub = FlutterCallkitIncoming.onEvent.listen((event) async {
      if (event == null) return;
      final body = _eventBody(event.body);
      final extra = _eventExtra(body);
      final channel = _stringField(extra, body, 'channel');
      final fromName =
          _stringField(extra, body, 'fromName', fallback: 'Caller');
      final isVideo = _videoField(extra, body);
      final id = _stringField(
        extra,
        body,
        'id',
        fallback: _stringField(extra, body, 'callkitId', fallback: channel),
      );
      final fromUid = _stringField(extra, body, 'fromUid');
      final inviteId = _stringField(
        extra,
        body,
        'inviteId',
        fallback: _stringField(extra, body, 'callId', fallback: id),
      );
      await _diagPush('callkit_event_received', meta: {
        'event': event.event.toString(),
        'inviteId': inviteId,
        'callkitId': id,
        'channel': channel,
      });

      if (event.event == Event.actionDidUpdateDevicePushTokenVoip) {
        final token = _stringField(extra, body, 'deviceToken');
        if (token.isNotEmpty) {
          await _registerVoipToken(token);
        }
      }

      if (!_enableIosCallKit) return;

      if (event.event == Event.actionCallAccept && channel.isNotEmpty) {
        _rememberAcceptedCallkitCall(inviteId, id);
        await _diagPush('callkit_accept', meta: {
          'inviteId': inviteId,
          'callkitId': id,
          'channel': channel,
        });
        await CallSessionManager.instance.handleNotificationInviteTap(
          inviteId: inviteId,
          channel: channel,
          isVideo: isVideo,
          fromName: fromName,
          fromUid: fromUid,
          autoAccept: true,
          source: 'callkit_accept',
        );
        return;
      }
      if (event.event == Event.actionCallDecline) {
        await _diagPush('callkit_decline', meta: {
          'inviteId': inviteId,
          'callkitId': id,
          'channel': channel,
        });
        if (!_shouldProcessCallkitTerminalEvent(event.event, inviteId, id)) {
          return;
        }
        if (inviteId.isNotEmpty) {
          await CallSessionManager.instance.declineInvite(
            inviteId: inviteId,
            source: 'callkit_decline',
          );
        }
      }
      if (event.event == Event.actionCallEnded) {
        await _diagPush('callkit_end', meta: {
          'inviteId': inviteId,
          'callkitId': id,
          'channel': channel,
        });
        if (_shouldIgnoreSyntheticAcceptedCallkitEnd(inviteId, id)) {
          await _diagPush('callkit_end_ignored_recent_accept', meta: {
            'inviteId': inviteId,
            'callkitId': id,
            'channel': channel,
            'hasActiveManagedCall':
                CallSessionManager.instance.hasActiveUiOrSession,
            'recoveringAcceptedCall': _recoveringAcceptedCall,
          });
          return;
        }
        if (!_shouldProcessCallkitTerminalEvent(event.event, inviteId, id)) {
          return;
        }
        if (inviteId.isNotEmpty) {
          await CallSessionManager.instance.handleSystemEndedInvite(
            inviteId: inviteId,
            source: 'callkit_end',
          );
        }
      }
      if (event.event == Event.actionCallTimeout && inviteId.isNotEmpty) {
        await _diagPush('callkit_end', meta: {
          'inviteId': inviteId,
          'callkitId': id,
          'channel': channel,
          'timeout': true,
        });
        if (!_shouldProcessCallkitTerminalEvent(event.event, inviteId, id)) {
          return;
        }
        await CallSessionManager.instance.handleSystemTimeoutInvite(
          inviteId: inviteId,
          source: 'callkit_timeout',
        );
      }
    });
  }

  Future<void> _registerFcmToken({String? forceToken}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (Platform.isIOS && (forceToken == null || forceToken.isEmpty)) {
        final apnsReady = await _hasApnsTokenReady();
        if (!apnsReady) {
          await _diagPush('fcm_waiting_for_apns');
          _scheduleAppleTokenRetry();
          return;
        }
      }

      String? token = forceToken;
      if (token == null || token.isEmpty) {
        token = await _fcm.getToken();
      }
      if (token == null || token.isEmpty) return;

      final app = FirebaseFirestore.instance.app;
      debugPrint(
          '📡 registerFcmToken() project=${app.options.projectId}, appId=${app.options.appId}');

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'fcmToken': token,
          'fcmTokens': [token],
          if (Platform.isIOS) 'fcmTokensIos': [token],
          if (!Platform.isIOS) 'fcmTokensAndroid': [token],
        },
        SetOptions(merge: true),
      );

      debugPrint('✅ FCM token saved uid=${user.uid}');
      await _diagPush('fcm_token_saved');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint(
            '⚠️ Skipping FCM token write (permission denied). Check /users allowlist.');
        return;
      }
      if (Platform.isIOS && _isApnsNotSetError(e)) {
        await _diagPush('fcm_waiting_for_apns_error', meta: {
          'code': e.code,
          'message': e.message ?? '',
        });
        _scheduleAppleTokenRetry();
        return;
      }
      debugPrint(
          '❌ FCM token write failed: code=${e.code} message=${e.message}');
      await _diagPush('fcm_token_error', meta: {
        'code': e.code,
        'message': e.message ?? '',
      });
    }
  }

  void _scheduleAppleTokenRetry() {
    if (!Platform.isIOS) return;
    if (_appleTokenRetryAttempts >= _maxAppleTokenRetryAttempts) return;
    _appleTokenRetryTimer?.cancel();
    _appleTokenRetryTimer = Timer(const Duration(seconds: 8), () async {
      _appleTokenRetryAttempts++;
      await _diagPush('apple_token_retry_attempt', meta: {
        'attempt': _appleTokenRetryAttempts,
      });
      await _registerApplePushTokens(force: true);
    });
  }

  Future<Map<String, String>> _readNativePushTokens() async {
    try {
      final raw = await _pushTokenChannel.invokeMapMethod<String, dynamic>(
        'getStoredPushTokens',
      );
      if (raw == null) return const <String, String>{};
      final apns = (raw['apnsToken'] ?? '').toString().trim();
      final apnsSuffix = (raw['apnsTokenSuffix'] ?? '').toString().trim();
      final voip = (raw['voipToken'] ?? '').toString().trim();
      final voipSuffix = (raw['voipTokenSuffix'] ?? '').toString().trim();
      final apnsError = (raw['apnsError'] ?? '').toString().trim();
      final lastPushkitIncomingAt =
          (raw['lastPushkitIncomingAt'] ?? '').toString().trim();
      final lastPushkitIncomingCallId =
          (raw['lastPushkitIncomingCallId'] ?? '').toString().trim();
      final lastPushkitIncomingChannel =
          (raw['lastPushkitIncomingChannel'] ?? '').toString().trim();
      final lastPushkitIncomingCallkitId =
          (raw['lastPushkitIncomingCallkitId'] ?? '').toString().trim();
      final lastPushkitStage =
          (raw['lastPushkitStage'] ?? '').toString().trim();
      final lastPushkitDetail =
          (raw['lastPushkitDetail'] ?? '').toString().trim();
      final lastPushkitPayloadType =
          (raw['lastPushkitPayloadType'] ?? '').toString().trim();
      final lastCallkitAcceptedAt =
          (raw['lastCallkitAcceptedAt'] ?? '').toString().trim();
      final lastCallkitAcceptedInviteId =
          (raw['lastCallkitAcceptedInviteId'] ?? '').toString().trim();
      final lastCallkitAcceptedChannel =
          (raw['lastCallkitAcceptedChannel'] ?? '').toString().trim();
      final lastCallkitAcceptedCallkitId =
          (raw['lastCallkitAcceptedCallkitId'] ?? '').toString().trim();
      final lastCallkitAcceptedFromName =
          (raw['lastCallkitAcceptedFromName'] ?? '').toString().trim();
      final lastCallkitAcceptedFromUid =
          (raw['lastCallkitAcceptedFromUid'] ?? '').toString().trim();
      final lastCallkitAcceptedIsVideo =
          (raw['lastCallkitAcceptedIsVideo'] ?? '').toString().trim();
      final lastCallkitEvent =
          (raw['lastCallkitEvent'] ?? '').toString().trim();
      final lastCallkitEventAt =
          (raw['lastCallkitEventAt'] ?? '').toString().trim();
      final lastCallkitEventCallkitId =
          (raw['lastCallkitEventCallkitId'] ?? '').toString().trim();
      final lastCallkitEventInviteId =
          (raw['lastCallkitEventInviteId'] ?? '').toString().trim();
      final lastCallkitEventChannel =
          (raw['lastCallkitEventChannel'] ?? '').toString().trim();
      return <String, String>{
        'apnsToken': apns,
        'apnsTokenSuffix': apnsSuffix,
        'voipToken': voip,
        'voipTokenSuffix': voipSuffix,
        'apnsError': apnsError,
        'lastPushkitIncomingAt': lastPushkitIncomingAt,
        'lastPushkitIncomingCallId': lastPushkitIncomingCallId,
        'lastPushkitIncomingChannel': lastPushkitIncomingChannel,
        'lastPushkitIncomingCallkitId': lastPushkitIncomingCallkitId,
        'lastPushkitStage': lastPushkitStage,
        'lastPushkitDetail': lastPushkitDetail,
        'lastPushkitPayloadType': lastPushkitPayloadType,
        'lastCallkitAcceptedAt': lastCallkitAcceptedAt,
        'lastCallkitAcceptedInviteId': lastCallkitAcceptedInviteId,
        'lastCallkitAcceptedChannel': lastCallkitAcceptedChannel,
        'lastCallkitAcceptedCallkitId': lastCallkitAcceptedCallkitId,
        'lastCallkitAcceptedFromName': lastCallkitAcceptedFromName,
        'lastCallkitAcceptedFromUid': lastCallkitAcceptedFromUid,
        'lastCallkitAcceptedIsVideo': lastCallkitAcceptedIsVideo,
        'lastCallkitEvent': lastCallkitEvent,
        'lastCallkitEventAt': lastCallkitEventAt,
        'lastCallkitEventCallkitId': lastCallkitEventCallkitId,
        'lastCallkitEventInviteId': lastCallkitEventInviteId,
        'lastCallkitEventChannel': lastCallkitEventChannel,
      };
    } catch (e) {
      await _diagPush('native_push_tokens_read_error', meta: {'error': '$e'});
      return const <String, String>{};
    }
  }

  Future<void> _syncNativePushDiagnostics(
      Map<String, String> nativeTokens) async {
    if (!Platform.isIOS) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'diag.push.apnsTokenSuffix':
              _normalizeTokenLikeValue(nativeTokens['apnsTokenSuffix']),
          'diag.push.voipTokenSuffix':
              _normalizeTokenLikeValue(nativeTokens['voipTokenSuffix']),
          'diag.push.lastPushkitIncomingAt':
              _normalizeTokenLikeValue(nativeTokens['lastPushkitIncomingAt']),
          'diag.push.lastPushkitIncomingCallId': _normalizeTokenLikeValue(
              nativeTokens['lastPushkitIncomingCallId']),
          'diag.push.lastPushkitIncomingChannel': _normalizeTokenLikeValue(
              nativeTokens['lastPushkitIncomingChannel']),
          'diag.push.lastPushkitIncomingCallkitId': _normalizeTokenLikeValue(
              nativeTokens['lastPushkitIncomingCallkitId']),
          'diag.push.lastPushkitStage':
              _normalizeTokenLikeValue(nativeTokens['lastPushkitStage']),
          'diag.push.lastPushkitDetail':
              _normalizeTokenLikeValue(nativeTokens['lastPushkitDetail']),
          'diag.push.lastPushkitPayloadType':
              _normalizeTokenLikeValue(nativeTokens['lastPushkitPayloadType']),
          'diag.push.lastCallkitAcceptedAt':
              _normalizeTokenLikeValue(nativeTokens['lastCallkitAcceptedAt']),
          'diag.push.lastCallkitAcceptedInviteId': _normalizeTokenLikeValue(
              nativeTokens['lastCallkitAcceptedInviteId']),
          'diag.push.lastCallkitAcceptedChannel': _normalizeTokenLikeValue(
              nativeTokens['lastCallkitAcceptedChannel']),
          'diag.push.lastCallkitAcceptedCallkitId': _normalizeTokenLikeValue(
              nativeTokens['lastCallkitAcceptedCallkitId']),
          'diag.push.lastCallkitAcceptedFromName': _normalizeTokenLikeValue(
              nativeTokens['lastCallkitAcceptedFromName']),
          'diag.push.lastCallkitAcceptedFromUid': _normalizeTokenLikeValue(
              nativeTokens['lastCallkitAcceptedFromUid']),
          'diag.push.lastCallkitAcceptedIsVideo': _normalizeTokenLikeValue(
              nativeTokens['lastCallkitAcceptedIsVideo']),
          'diag.push.lastCallkitEvent':
              _normalizeTokenLikeValue(nativeTokens['lastCallkitEvent']),
          'diag.push.lastCallkitEventAt':
              _normalizeTokenLikeValue(nativeTokens['lastCallkitEventAt']),
          'diag.push.lastCallkitEventCallkitId': _normalizeTokenLikeValue(
              nativeTokens['lastCallkitEventCallkitId']),
          'diag.push.lastCallkitEventInviteId': _normalizeTokenLikeValue(
              nativeTokens['lastCallkitEventInviteId']),
          'diag.push.lastCallkitEventChannel':
              _normalizeTokenLikeValue(nativeTokens['lastCallkitEventChannel']),
          'diag.push.nativeSnapshotAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      await _diagPush('native_push_diag_sync_error', meta: {'error': '$e'});
    }
  }

  String _normalizeTokenLikeValue(dynamic raw) {
    final token = (raw ?? '').toString().trim();
    if (token.isEmpty) return '';
    final lowered = token.toLowerCase();
    if (lowered == 'null' || lowered == '(null)') return '';
    return token;
  }

  bool _isApnsNotSetError(FirebaseException e) {
    if (e.code == 'apns-token-not-set') return true;
    final msg = (e.message ?? '').toLowerCase();
    return msg.contains('apns token has not been set');
  }

  Future<bool> _hasApnsTokenReady() async {
    if (!Platform.isIOS) return true;
    try {
      final apnsToken = _normalizeTokenLikeValue(await _fcm.getAPNSToken());
      if (apnsToken.isNotEmpty) return true;
    } catch (_) {}
    final native = await _readNativePushTokens();
    final nativeApns = _normalizeTokenLikeValue(native['apnsToken']);
    return nativeApns.isNotEmpty;
  }

  Future<void> _registerApplePushTokens({bool force = false}) async {
    if (!Platform.isIOS) return;
    if (_appleTokensRegisteredForSession && !force) return;
    _appleTokensRegisteredForSession = true;
    var hasApns = false;
    var hasVoip = false;

    if (force) {
      await _refreshNativePushRegistrations();
    }

    final nativeTokens = await _readNativePushTokens();
    await _syncNativePushDiagnostics(nativeTokens);
    final nativeApns = _normalizeTokenLikeValue(nativeTokens['apnsToken']);
    if (nativeApns.isNotEmpty) {
      await _registerApnsToken(nativeApns);
      hasApns = true;
      debugPrint(
          'Helperly APNS native token seen suffix=${_tokenSuffix(nativeApns)}');
      await _diagPush('apns_token_saved_native');
    }
    final nativeVoip = _normalizeTokenLikeValue(nativeTokens['voipToken']);
    if (nativeVoip.isNotEmpty) {
      await _registerVoipToken(nativeVoip);
      hasVoip = true;
      debugPrint(
          'Helperly VoIP native token seen suffix=${_tokenSuffix(nativeVoip)}');
      await _diagPush('voip_token_saved_native');
    }
    final nativeApnsError = _normalizeTokenLikeValue(nativeTokens['apnsError']);
    if (nativeApnsError.isNotEmpty) {
      await _diagPush('apns_register_error_native', meta: {
        'error': nativeApnsError,
      });
    }

    try {
      final apnsToken = _normalizeTokenLikeValue(await _fcm.getAPNSToken());
      if (apnsToken.isNotEmpty) {
        await _registerApnsToken(apnsToken);
        hasApns = true;
      } else {
        await _diagPush('apns_token_missing');
        if (!_apnsRetryScheduled) {
          _apnsRetryScheduled = true;
          Future<void>.delayed(const Duration(seconds: 5), () async {
            try {
              final retryToken =
                  _normalizeTokenLikeValue(await _fcm.getAPNSToken());
              if (retryToken.isNotEmpty) {
                await _registerApnsToken(retryToken);
                hasApns = true;
                await _diagPush('apns_token_saved_retry');
              } else {
                await _diagPush('apns_token_missing_retry');
              }
            } catch (e) {
              await _diagPush('apns_token_retry_error', meta: {'error': '$e'});
            } finally {
              _apnsRetryScheduled = false;
            }
          });
        }
      }
    } catch (e) {
      await _diagPush('apns_token_error', meta: {'error': '$e'});
    }

    if (hasApns) {
      await _registerFcmToken();
    }

    try {
      final voipToken = _normalizeTokenLikeValue(
        await FlutterCallkitIncoming.getDevicePushTokenVoIP(),
      );
      if (voipToken.isNotEmpty) {
        debugPrint('📲 VoIP token: $voipToken');
        await _registerVoipToken(voipToken);
        hasVoip = true;
      } else {
        await _diagPush('voip_token_missing');
      }
    } catch (e) {
      debugPrint('⚠️ Could not fetch VoIP token: $e');
      await _diagPush('voip_token_error', meta: {'error': '$e'});
    }

    if (hasApns && hasVoip) {
      _appleTokenRetryTimer?.cancel();
      _appleTokenRetryTimer = null;
      _appleTokenRetryAttempts = 0;
      await _diagPush('apple_tokens_ready');
      return;
    }

    _scheduleAppleTokenRetry();
  }

  Future<void> _registerApnsToken(String token) async {
    if (!Platform.isIOS) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || token.isEmpty) return;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'apnsToken': token,
          'apnsTokens': [token],
          'diag.push.apnsTokenSuffix': _tokenSuffix(token),
          'diag.push.apnsTokenSavedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      debugPrint(
          'Helperly APNS token saved uid=${user.uid} suffix=${_tokenSuffix(token)}');
      await _diagPush('apns_token_saved');
    } on FirebaseException catch (e) {
      debugPrint(
          '⚠️ APNs token write failed: code=${e.code} message=${e.message}');
      await _diagPush('apns_token_write_error', meta: {
        'code': e.code,
        'message': e.message ?? '',
      });
    }
  }

  Future<void> _registerVoipToken(String token) async {
    if (!Platform.isIOS) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || token.isEmpty) return;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'voipToken': token,
          'voipTokens': [token],
          'diag.push.voipTokenSuffix': _tokenSuffix(token),
          'diag.push.voipTokenSavedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      debugPrint(
          'Helperly VoIP token saved uid=${user.uid} suffix=${_tokenSuffix(token)}');
    } on FirebaseException catch (e) {
      debugPrint(
          '⚠️ VoIP token write failed: code=${e.code} message=${e.message}');
    }
  }

  /// Central handler for all incoming FCMs.
  /// - Suppresses **self** chat notifications (authorId == my uid)
  /// - Suppresses notifications when the chat with that user is already open
  Future<void> _handleMessage(RemoteMessage message,
      {required bool showLocal}) async {
    final data = message.data;
    await _diagPush('fcm_message_received', meta: {
      'type': (data['type'] ?? '').toString(),
      'showLocal': showLocal,
    });

    // ===== CALL INVITE ======================================================
    final isCallInvite =
        (data['type'] == 'call_invite') || (data['action'] == 'incoming_call');
    if (isCallInvite) {
      final channel = (data['channel'] ?? '') as String;
      final isVideo = _videoField(data, const <String, dynamic>{});
      final fromName = (data['fromName'] ?? 'Caller') as String;
      final fromUid = (data['fromUid'] ?? '').toString();
      final callId = (data['callId'] ?? channel).toString();
      final payload =
          'incoming_call2|$channel|$isVideo|$fromName|$fromUid|$callId';
      await _diagPush('push_call_invite_received', meta: {
        'callId': callId,
        'channel': channel,
        'isVideo': isVideo,
        'showLocal': showLocal,
      });

      if (showLocal) {
        final appActive = await _isAppActuallyForeground();
        if (appActive) {
          await _clearStoredAcceptedCallRecovery();
          await CallSessionManager.instance.handleNotificationInviteTap(
            inviteId: callId,
            channel: channel,
            isVideo: isVideo,
            fromName: fromName,
            fromUid: fromUid,
            source: 'fcm_foreground_invite',
          );
          return;
        }

        if (Platform.isIOS && _enableIosCallKit) {
          await _showIncomingCallKit(
            channel: channel,
            isVideo: isVideo,
            fromName: fromName,
            fromUid: fromUid,
            inviteId: callId,
          );
        } else if (_localInitialized) {
          final notifId = _notificationIdFrom('invite_fcm_$callId');
          await _local.show(
            notifId,
            isVideo ? 'Incoming Video Call' : 'Incoming Audio Call',
            'From $fromName',
            NotificationDetails(
              android: AndroidNotificationDetails(
                _androidChannel.id,
                _androidChannel.name,
                channelDescription: _androidChannel.description,
                importance: Importance.max,
                priority: Priority.high,
                actions: <AndroidNotificationAction>[
                  const AndroidNotificationAction('ACCEPT_CALL', 'Accept',
                      showsUserInterface: true),
                  const AndroidNotificationAction(
                    'DECLINE_CALL',
                    'Decline',
                    showsUserInterface: false,
                    cancelNotification: true,
                  ),
                ],
              ),
              iOS: const DarwinNotificationDetails(
                  categoryIdentifier: 'INCOMING_CALL'),
            ),
            payload: payload,
          );
        }
      } else {
        await _diagPush('push_call_invite_received', meta: {
          'callId': callId,
          'channel': channel,
          'isVideo': isVideo,
          'showLocal': showLocal,
          'openedFromTap': true,
        });
        await CallSessionManager.instance.handleNotificationInviteTap(
          inviteId: callId,
          channel: channel,
          isVideo: isVideo,
          fromName: fromName,
          fromUid: fromUid,
          source: 'fcm_notification_tap',
        );
      }
      return;
    }

    // ===== CALL END / CANCEL ===============================================
    final isCallEnd =
        (data['type'] == 'call_end') || (data['action'] == 'call_end');
    if (isCallEnd) {
      final channel = (data['channel'] ?? '').toString();
      final callId = (data['callId'] ?? data['inviteId'] ?? channel).toString();
      final status = (data['status'] ?? '').toString();
      await _diagPush('push_call_end_received', meta: {
        'callId': callId,
        'channel': channel,
        'status': status,
      });
      if (Platform.isIOS && _enableIosCallKit) {
        final callkitId = normalizeCallkitId(
          rawId: callId,
          fallback: channel,
        );
        try {
          await _endActiveCallkitCall(
            callkitId,
            aggressive: false,
            source: 'call_end_message',
          );
        } catch (e) {
          await _diagPush('call_end_message_endcall_error', meta: {
            'callId': callId,
            'channel': channel,
            'error': '$e',
          });
        }
      }
      return;
    }

    // ===== CHAT MESSAGE =====================================================
    if (data['type'] == 'chat_message') {
      final me = FirebaseAuth.instance.currentUser?.uid;

      // REQUIRE your server payload to include authorId
      final authorId = (data['authorId'] ?? '') as String;
      if (me != null && authorId.isNotEmpty && authorId == me) {
        // 🛑 Don't notify for my own messages
        return;
      }
      final otherUserId =
          (data['otherUserId'] ?? data['authorId'] ?? '').toString();
      final chatId = (data['chatId'] ?? '').toString();

      // If already inside this chat, don't show a banner
      if (CurrentChat.otherUserId == otherUserId) return;

      if (showLocal && _localInitialized) {
        await _diagPush('chat_local_notification_show', meta: {
          'otherUserId': otherUserId,
        });
        final notifId = _notificationIdFrom(
          'chat_fcm_${otherUserId}_${DateTime.now().millisecondsSinceEpoch}',
        );
        await _local.show(
          notifId,
          message.notification?.title ?? 'New Message',
          message.notification?.body ?? '',
          NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannel.id,
              _androidChannel.name,
              channelDescription: _androidChannel.description,
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          payload: 'open_chat|$otherUserId|$chatId',
        );
      } else if (!showLocal) {
        _openChat(otherUserId, chatId: chatId);
      }
      return;
    }

    // ===== GENERIC ==========================================================
    if (showLocal && message.notification != null) {
      await _local.show(
        _nextNotificationId(),
        message.notification?.title ?? 'Notification',
        message.notification?.body ?? '',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    }
  }

  Future<NavigatorState?> _waitForNavigator() async {
    for (var i = 0; i < 20; i++) {
      final nav = navigatorKey?.currentState;
      if (nav != null && nav.mounted) return nav;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return navigatorKey?.currentState;
  }

  Future<void> _recoverAcceptedCallkitCall() async {
    if (!Platform.isIOS || !_enableIosCallKit) return;
    if (_recoveringAcceptedCall) return;
    if (_hasActiveIncomingUi && !(await _resetStaleIncomingUiIfNeeded())) {
      return;
    }

    _recoveringAcceptedCall = true;
    try {
      final nativeTokens = await _readNativePushTokens();
      await _syncNativePushDiagnostics(nativeTokens);
      final acceptedAt =
          _normalizeTokenLikeValue(nativeTokens['lastCallkitAcceptedAt']);
      final acceptedChannel =
          _normalizeTokenLikeValue(nativeTokens['lastCallkitAcceptedChannel']);
      final acceptedInviteId =
          _normalizeTokenLikeValue(nativeTokens['lastCallkitAcceptedInviteId']);
      final acceptedCallkitId = _normalizeTokenLikeValue(
          nativeTokens['lastCallkitAcceptedCallkitId']);
      final lastCallkitEvent =
          _normalizeTokenLikeValue(nativeTokens['lastCallkitEvent'])
              .toLowerCase();
      final lastCallkitEventInviteId =
          _normalizeTokenLikeValue(nativeTokens['lastCallkitEventInviteId']);
      final lastCallkitEventCallkitId =
          _normalizeTokenLikeValue(nativeTokens['lastCallkitEventCallkitId']);
      final hasTerminalCallkitEvent = lastCallkitEvent == 'decline' ||
          lastCallkitEvent == 'end' ||
          lastCallkitEvent == 'timeout';
      final terminalMatchesAcceptedCall = (acceptedInviteId.isNotEmpty &&
              acceptedInviteId == lastCallkitEventInviteId) ||
          (acceptedCallkitId.isNotEmpty &&
              acceptedCallkitId == lastCallkitEventCallkitId);
      if (acceptedAt.isNotEmpty &&
          !_isRecentAcceptedCallTimestamp(acceptedAt)) {
        await _diagPush('accepted_call_recovery_cleared_stale', meta: {
          'acceptedAt': acceptedAt,
          'acceptedInviteId': acceptedInviteId,
          'acceptedChannel': acceptedChannel,
        });
        await _clearStoredAcceptedCallRecovery();
        return;
      }
      if (hasTerminalCallkitEvent && terminalMatchesAcceptedCall) {
        await _clearStoredAcceptedCallRecovery();
        return;
      }
      if (acceptedAt.isNotEmpty &&
          acceptedAt != _lastRecoveredAcceptedAt &&
          acceptedChannel.isNotEmpty &&
          !(hasTerminalCallkitEvent && terminalMatchesAcceptedCall)) {
        _lastRecoveredAcceptedAt = acceptedAt;
        final fromName = _normalizeTokenLikeValue(
            nativeTokens['lastCallkitAcceptedFromName']);
        final fromUid = _normalizeTokenLikeValue(
            nativeTokens['lastCallkitAcceptedFromUid']);
        final isVideo = _truthyValue(
          _normalizeTokenLikeValue(nativeTokens['lastCallkitAcceptedIsVideo']),
        );
        await _clearStoredAcceptedCallRecovery();
        await CallSessionManager.instance.handleRecoveredAcceptedInvite(
          inviteId: acceptedInviteId,
          channel: acceptedChannel,
          isVideo: isVideo,
          fromName: fromName.isEmpty ? 'Caller' : fromName,
          fromUid: fromUid,
        );
        return;
      }

      final activeCalls = await FlutterCallkitIncoming.activeCalls();
      if (activeCalls is! List) return;

      for (final raw in activeCalls.reversed) {
        if (raw is! Map) continue;
        final body = Map<String, dynamic>.from(raw);
        final extra = _eventExtra(body);
        final accepted = _boolField(extra, body, 'accepted') ||
            _boolField(extra, body, 'isAccepted');
        if (!accepted) continue;

        final channel = _stringField(extra, body, 'channel');
        if (channel.isEmpty) continue;

        final fromName = _stringField(
          extra,
          body,
          'fromName',
          fallback: _stringField(extra, body, 'nameCaller', fallback: 'Caller'),
        );
        final fromUid = _stringField(extra, body, 'fromUid');
        final inviteId = _stringField(
          extra,
          body,
          'inviteId',
          fallback: _stringField(
            extra,
            body,
            'callId',
            fallback: _stringField(
              extra,
              body,
              'id',
              fallback: _stringField(extra, body, 'uuid'),
            ),
          ),
        );
        final isVideo = _videoField(extra, body);

        await CallSessionManager.instance.handleRecoveredAcceptedInvite(
          inviteId: inviteId,
          channel: channel,
          isVideo: isVideo,
          fromName: fromName,
          fromUid: fromUid,
        );
        return;
      }
    } catch (e) {
      debugPrint('⚠️ accepted CallKit recovery failed: $e');
    } finally {
      _recoveringAcceptedCall = false;
    }
  }

  void _openChat(String otherUserId, {String? chatId}) {
    if (otherUserId.isEmpty) return;
    _pendingChatOpenOtherUserId = otherUserId;
    _pendingChatOpenChatId = (chatId ?? '').trim();
    unawaited(() async {
      await _flushPendingChatOpen();
    }());
  }

  Future<void> debugSimulateForegroundVoipForTest({
    required String inviteId,
    required String channel,
    required String fromName,
    required String fromUid,
    required bool isVideo,
    String appState = 'active',
  }) async {
    await _handleNativePushMethodCall(
      MethodCall('incomingVoipForeground', <String, dynamic>{
        'inviteId': inviteId,
        'callId': inviteId,
        'channel': channel,
        'fromName': fromName,
        'fromUid': fromUid,
        'isVideo': isVideo,
        'appState': appState,
      }),
    );
  }

  Future<void> debugOpenChatFromTapForTest({
    required String otherUserId,
    String? chatId,
  }) async {
    _openChat(otherUserId, chatId: chatId);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> _flushPendingChatOpen() async {
    if (_chatNavigationInFlight) return;
    final pendingOtherUserId = (_pendingChatOpenOtherUserId ?? '').trim();
    if (pendingOtherUserId.isEmpty) return;

    _chatNavigationInFlight = true;
    try {
      for (var i = 0; i < 80; i++) {
        final otherUserId = (_pendingChatOpenOtherUserId ?? '').trim();
        if (otherUserId.isEmpty) return;
        if (!await _isAppActuallyForeground()) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          continue;
        }
        final nav = await _waitForNavigator();
        if (nav == null || !nav.mounted) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          continue;
        }
        final chatId = (_pendingChatOpenChatId ?? '').trim();
        _pendingChatOpenOtherUserId = null;
        _pendingChatOpenChatId = null;
        await _diagPush('chat_open_from_tap', meta: {
          'otherUserId': otherUserId,
          if (chatId.isNotEmpty) 'chatId': chatId,
          'queued': true,
        });
        nav.pushNamedAndRemoveUntil(
          '/chat',
          (route) => route.isFirst,
          arguments: <String, dynamic>{
            'otherUserId': otherUserId,
            if (chatId.isNotEmpty) 'chatId': chatId,
          },
        );
        return;
      }
    } finally {
      _chatNavigationInFlight = false;
      if ((_pendingChatOpenOtherUserId ?? '').trim().isNotEmpty) {
        unawaited(_flushPendingChatOpen());
      }
    }
  }

  Future<void> _showIncomingCallKit({
    required String channel,
    required bool isVideo,
    required String fromName,
    String? fromUid,
    String? inviteId,
  }) async {
    final rawInviteId = (inviteId ?? '').trim();
    final rawCallId = rawInviteId.isNotEmpty ? rawInviteId : channel.trim();
    final callkitId = normalizeCallkitId(
      rawId: rawCallId,
      fallback: channel,
    );
    final params = CallKitParams(
      id: callkitId,
      nameCaller: fromName,
      appName: 'Helperly',
      handle: isVideo ? 'Video call' : 'Audio call',
      type: isVideo ? 1 : 0,
      duration: 45000,
      textAccept: 'Accept',
      textDecline: 'Decline',
      extra: <String, dynamic>{
        'id': callkitId,
        'callkitId': callkitId,
        'callId': rawCallId,
        'channel': channel,
        'isVideo': isVideo,
        'fromName': fromName,
        'fromUid': fromUid ?? '',
        'inviteId': rawInviteId,
      },
      ios: IOSParams(
        // Must be a regular image asset name, not AppIcon appiconset.
        iconName: 'LaunchImage',
        handleType: 'generic',
        supportsVideo: isVideo,
        supportsDTMF: false,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
      ),
      android: const AndroidParams(
        isShowFullLockedScreen: true,
        isImportant: true,
        incomingCallNotificationChannelName: 'Incoming Call',
        missedCallNotificationChannelName: 'Missed Call',
      ),
    );
    try {
      await FlutterCallkitIncoming.showCallkitIncoming(params);
    } catch (e) {
      debugPrint('⚠️ CallKit incoming failed, fallback to local notif: $e');
      final notifId = _notificationIdFrom('callkit_fallback_$callkitId');
      await _local.show(
        notifId,
        isVideo ? 'Incoming Video Call' : 'Incoming Audio Call',
        'From $fromName',
        const NotificationDetails(
          iOS: DarwinNotificationDetails(categoryIdentifier: 'INCOMING_CALL'),
        ),
        payload:
            'incoming_call2|$channel|$isVideo|$fromName|${fromUid ?? ''}|$rawInviteId',
      );
    }
  }

  Map<String, dynamic> _eventBody(dynamic rawBody) {
    if (rawBody is Map) return Map<String, dynamic>.from(rawBody);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _eventExtra(Map<String, dynamic> body) {
    final raw = body['extra'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  String _stringField(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
    String key, {
    String fallback = '',
  }) {
    final va = a[key];
    if (va is String && va.isNotEmpty) return va;
    final vb = b[key];
    if (vb is String && vb.isNotEmpty) return vb;
    return fallback;
  }

  bool _boolField(Map<String, dynamic> a, Map<String, dynamic> b, String key) {
    if (_truthyValue(a[key])) return true;
    if (_truthyValue(b[key])) return true;
    return false;
  }

  bool _videoField(Map<String, dynamic> a, Map<String, dynamic> b) {
    return _videoLikeValue(a['isVideo']) ||
        _videoLikeValue(b['isVideo']) ||
        _videoLikeValue(a['type']) ||
        _videoLikeValue(b['type']) ||
        _videoLikeValue(a['callType']) ||
        _videoLikeValue(b['callType']);
  }

  bool _truthyValue(dynamic raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  bool _videoLikeValue(dynamic raw) {
    if (_truthyValue(raw)) return true;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      return normalized == 'video';
    }
    return false;
  }

  DateTime? _timestampToDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }
}
