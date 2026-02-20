// lib/services/notification_service.dart
import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:uuid/uuid.dart';

import '../screens/call/agora_call_screen.dart';
import '../screens/chat/chat_screen.dart';
import 'current_chat.dart';

class NotificationService {
  NotificationService({this.navigatorKey});

  final GlobalKey<NavigatorState>? navigatorKey;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Used for important notifications.',
    importance: Importance.max,
  );

  bool _initialized = false;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<CallEvent?>? _callkitSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _inviteSub;
  final Uuid _uuid = const Uuid();
  bool _openingCallScreen = false;
  final Set<String> _handledCallInviteIds = <String>{};

  /// Call once after Firebase is initialized and user signed in.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Ask permission (iOS)
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('❌ Notification permission not granted');
    }

    // iOS foreground behavior
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

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

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) async {
        final payload = resp.payload ?? '';
        final actionId = resp.actionId;

        // Deep-link: incoming call
        if (payload.startsWith('incoming_call|')) {
          final parts = payload.split('|'); // incoming_call|channel|isVideo|fromName
          if (parts.length >= 4) {
            final channel = parts[1];
            final isVideo = parts[2] == 'true';
            final fromName = parts[3];

            if (actionId == 'DECLINE_CALL') return;
            _pushCallScreen(channel: channel, isVideo: isVideo, fromName: fromName);
            return;
          }
        }

        // Deep-link: open chat
        if (payload.startsWith('open_chat|')) {
          final otherUserId = payload.split('|').elementAt(1);
          _openChat(otherUserId);
        }
      },
    );

    // Android channel
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // iOS CallKit events
    _bindCallkitEvents();
    _bindInviteListener();
    if (Platform.isIOS) {
      try {
        final voipToken = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
        if (voipToken != null && '$voipToken'.isNotEmpty) {
          debugPrint('📲 VoIP token (CallKit): $voipToken');
          await _registerVoipToken('$voipToken');
        }
      } catch (e) {
        debugPrint('⚠️ Could not fetch VoIP token: $e');
      }
    }

    // Foreground + tap handlers
    FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) => _handleMessage(message, showLocal: true),
    );
    FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) => _handleMessage(message, showLocal: false),
    );

    // App opened from terminated via push
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      await _handleMessage(initial, showLocal: false);
    }

    // Register token now
    await _registerFcmToken();

    // Keep user doc in sync on token refresh
    _tokenSub?.cancel();
    _tokenSub = _fcm.onTokenRefresh.listen((newToken) async {
      await _registerFcmToken(forceToken: newToken);
    });
  }

  Future<void> dispose() async {
    await _tokenSub?.cancel();
    _tokenSub = null;
    await _callkitSub?.cancel();
    _callkitSub = null;
    await _inviteSub?.cancel();
    _inviteSub = null;
  }

  void _bindCallkitEvents() {
    _callkitSub?.cancel();
    _callkitSub = FlutterCallkitIncoming.onEvent.listen((event) async {
      if (event == null) return;
      final body = _eventBody(event.body);
      final extra = _eventExtra(body);
      final channel = _stringField(extra, body, 'channel');
      final fromName = _stringField(extra, body, 'fromName', fallback: 'Caller');
      final isVideo = _boolField(extra, body, 'isVideo');
      final id = _stringField(extra, body, 'id', fallback: channel);
      final fromUid = _stringField(extra, body, 'fromUid');
      final inviteId = _stringField(extra, body, 'inviteId', fallback: id);

      if (event.event == Event.actionDidUpdateDevicePushTokenVoip) {
        final token = _stringField(extra, body, 'deviceToken');
        if (token.isNotEmpty) {
          await _registerVoipToken(token);
        }
      }

      if (event.event == Event.actionCallAccept && channel.isNotEmpty) {
        if (id.isNotEmpty) {
          try {
            await FlutterCallkitIncoming.endCall(id);
          } catch (_) {}
        }
        _pushCallScreen(
          channel: channel,
          isVideo: isVideo,
          fromName: fromName,
          fromUid: fromUid,
          inviteId: inviteId,
        );
      }
      if (event.event == Event.actionCallDecline ||
          event.event == Event.actionCallEnded ||
          event.event == Event.actionCallTimeout) {
        if (id.isNotEmpty) {
          try {
            await FlutterCallkitIncoming.endCall(id);
          } catch (_) {}
        }
      }
    });
  }

  void _bindInviteListener() {
    _inviteSub?.cancel();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    _inviteSub = FirebaseFirestore.instance
        .collection('callInvites')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final id = change.doc.id;
        if (_handledCallInviteIds.contains(id)) continue;

        final data = change.doc.data() ?? const <String, dynamic>{};
        final status = (data['status'] ?? '').toString();
        if (status.isNotEmpty && status != 'ringing') continue;
        final createdAt = data['createdAt'];
        final created = createdAt is Timestamp ? createdAt.toDate() : null;
        if (created != null &&
            DateTime.now().difference(created) > const Duration(minutes: 2)) {
          continue;
        }

        final channel = (data['channel'] ?? '').toString();
        if (channel.isEmpty) continue;
        final isVideo = data['isVideo'] == true;
        final fromName = (data['fromName'] ?? 'Caller').toString();
        final fromUid = (data['fromUid'] ?? '').toString();

        _handledCallInviteIds.add(id);

        if (Platform.isIOS) {
          await _showIncomingCallKit(
            channel: channel,
            isVideo: isVideo,
            fromName: fromName,
            fromUid: fromUid,
            inviteId: id,
          );
        } else {
          await _local.show(
            1000,
            isVideo ? 'Incoming Video Call' : 'Incoming Audio Call',
            'From $fromName',
            NotificationDetails(
              android: AndroidNotificationDetails(
                _androidChannel.id,
                _androidChannel.name,
                channelDescription: _androidChannel.description,
                importance: Importance.max,
                priority: Priority.high,
              ),
              iOS: const DarwinNotificationDetails(
                  categoryIdentifier: 'INCOMING_CALL'),
            ),
            payload: 'incoming_call|$channel|$isVideo|$fromName',
          );
        }
      }
    });
  }

  Future<void> _registerFcmToken({String? forceToken}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = forceToken ?? await _fcm.getToken();
      if (token == null || token.isEmpty) return;

      final app = FirebaseFirestore.instance.app;
      debugPrint('📡 registerFcmToken() project=${app.options.projectId}, appId=${app.options.appId}');

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'fcmToken': token,
          'fcmTokens': FieldValue.arrayUnion([token]),
        },
        SetOptions(merge: true),
      );

      debugPrint('✅ FCM token saved uid=${user.uid}');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint('⚠️ Skipping FCM token write (permission denied). Check /users allowlist.');
        return;
      }
      debugPrint('❌ FCM token write failed: code=${e.code} message=${e.message}');
      rethrow;
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
          'voipTokens': FieldValue.arrayUnion([token]),
        },
        SetOptions(merge: true),
      );
      debugPrint('✅ VoIP token saved uid=${user.uid}');
    } on FirebaseException catch (e) {
      debugPrint('⚠️ VoIP token write failed: code=${e.code} message=${e.message}');
    }
  }

  /// Central handler for all incoming FCMs.
  /// - Suppresses **self** chat notifications (authorId == my uid)
  /// - Suppresses notifications when the chat with that user is already open
  Future<void> _handleMessage(RemoteMessage message, {required bool showLocal}) async {
    final data = message.data;

    // ===== CALL INVITE ======================================================
    final isCallInvite = (data['type'] == 'call_invite') || (data['action'] == 'incoming_call');
    if (isCallInvite) {
      final channel = (data['channel'] ?? '') as String;
      final isVideo = (data['isVideo'] ?? 'false').toString() == 'true';
      final fromName = (data['fromName'] ?? 'Caller') as String;
      final fromUid = (data['fromUid'] ?? '').toString();
      final callId = (data['callId'] ?? channel).toString();
      if (callId.isNotEmpty && _handledCallInviteIds.contains(callId)) {
        return;
      }
      if (callId.isNotEmpty) _handledCallInviteIds.add(callId);
      final payload = 'incoming_call|$channel|$isVideo|$fromName';

      if (showLocal) {
        if (Platform.isIOS) {
          await _showIncomingCallKit(
            channel: channel,
            isVideo: isVideo,
            fromName: fromName,
            fromUid: fromUid,
            inviteId: callId,
          );
        } else {
          await _local.show(
            1000, // stable id for call invites
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
                  const AndroidNotificationAction('ACCEPT_CALL', 'Accept', showsUserInterface: true),
                  const AndroidNotificationAction(
                    'DECLINE_CALL',
                    'Decline',
                    showsUserInterface: false,
                    cancelNotification: true,
                  ),
                ],
              ),
              iOS: const DarwinNotificationDetails(categoryIdentifier: 'INCOMING_CALL'),
            ),
            payload: payload,
          );
        }
      } else {
        _pushCallScreen(
          channel: channel,
          isVideo: isVideo,
          fromName: fromName,
          fromUid: fromUid,
          inviteId: callId,
        );
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

      final otherUserId = (data['otherUserId'] ?? '') as String;

      // If already inside this chat, don't show a banner
      if (CurrentChat.otherUserId == otherUserId) return;

      // If system push already shows a foreground banner (iOS), avoid double banner
      final systemAlreadyShowing = message.notification != null;

      if (showLocal && !systemAlreadyShowing) {
        await _local.show(
          2000, // stable id for chat notifications
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
          payload: 'open_chat|$otherUserId',
        );
      } else if (!showLocal) {
        _openChat(otherUserId);
      }
      return;
    }

    // ===== GENERIC ==========================================================
    if (showLocal && message.notification != null) {
      await _local.show(
        3000,
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

  void _pushCallScreen({
    required String channel,
    required bool isVideo,
    required String fromName,
    String? fromUid,
    String? inviteId,
  }) {
    final nav = navigatorKey?.currentState;
    if (nav == null || _openingCallScreen) return;
    final normalizedFromUid = (fromUid ?? '').trim();
    final normalizedInviteId = (inviteId ?? '').trim();
    _openingCallScreen = true;
    nav.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AgoraCallScreen(
          channelName: channel,
          isVideo: isVideo,
          otherUserName: fromName,
          otherUserId: normalizedFromUid.isEmpty ? null : normalizedFromUid,
          inviteId: normalizedInviteId.isEmpty ? null : normalizedInviteId,
          isCaller: false,
        ),
      ),
    ).whenComplete(() {
      _openingCallScreen = false;
    });
  }

  void _openChat(String otherUserId) {
    final nav = navigatorKey?.currentState;
    if (nav == null || otherUserId.isEmpty) return;

    nav.push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(otherUserId: otherUserId),
      ),
    );
  }

  Future<void> _showIncomingCallKit({
    required String channel,
    required bool isVideo,
    required String fromName,
    String? fromUid,
    String? inviteId,
  }) async {
    final id = (inviteId != null && inviteId.trim().isNotEmpty)
        ? inviteId.trim()
        : (channel.isNotEmpty ? channel : _uuid.v4());
    final params = CallKitParams(
      id: id,
      nameCaller: fromName,
      appName: 'Helperly',
      handle: isVideo ? 'Video call' : 'Audio call',
      type: isVideo ? 1 : 0,
      duration: 45000,
      textAccept: 'Accept',
      textDecline: 'Decline',
      extra: <String, dynamic>{
        'id': id,
        'channel': channel,
        'isVideo': isVideo,
        'fromName': fromName,
        'fromUid': fromUid ?? '',
        'inviteId': inviteId ?? '',
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
      await _local.show(
        1000,
        isVideo ? 'Incoming Video Call' : 'Incoming Audio Call',
        'From $fromName',
        const NotificationDetails(
          iOS: DarwinNotificationDetails(categoryIdentifier: 'INCOMING_CALL'),
        ),
        payload: 'incoming_call|$channel|$isVideo|$fromName',
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
    final va = a[key];
    if (va is bool) return va;
    if (va is String) return va.toLowerCase() == 'true';
    final vb = b[key];
    if (vb is bool) return vb;
    if (vb is String) return vb.toLowerCase() == 'true';
    return false;
  }
}
