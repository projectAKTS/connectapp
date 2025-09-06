// lib/services/notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../screens/call/agora_call_screen.dart';
import '../screens/call/incoming_call_screen.dart';
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

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final settings = await _fcm.requestPermission(
      alert: true, badge: true, sound: true, provisional: false,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('❌ Notification permission not granted');
    }

    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );

    // iOS categories (no const)
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

        if (payload.startsWith('open_chat|')) {
          final otherUserId = payload.split('|').elementAt(1);
          _openChat(otherUserId);
        }
      },
    );

    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) => _handleMessage(message, showLocal: true),
    );
    FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) => _handleMessage(message, showLocal: false),
    );

    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      await _handleMessage(initial, showLocal: false);
    }

    // APNs stabilization loop (iOS)
    String? apnsToken;
    int retries = 0;
    while (apnsToken == null && retries < 10) {
      apnsToken = await _fcm.getAPNSToken();
      await Future.delayed(const Duration(milliseconds: 300));
      retries++;
    }

    await _registerFcmToken();

    _fcm.onTokenRefresh.listen((newToken) async {
      await _registerFcmToken(forceToken: newToken);
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

      final before = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      debugPrint('📡 user doc exists=${before.exists} keys=${before.data()?.keys.toList()}');

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'fcmToken': token,
          'fcmTokens': FieldValue.arrayUnion([token]),
        },
        SetOptions(merge: true),
      );
      debugPrint('✅ FCM token write OK for uid=${user.uid}');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint('⚠️ Skipping FCM token write (permission denied). Check /users keys whitelist and project.');
        return;
      }
      debugPrint('❌ FCM token write failed: code=${e.code} message=${e.message}');
      rethrow;
    }
  }

  Future<void> _handleMessage(RemoteMessage message, {required bool showLocal}) async {
    final data = message.data;

    // CALL INVITE
    final isCallInvite = (data['type'] == 'call_invite') || (data['action'] == 'incoming_call');

    if (isCallInvite) {
      final channel = (data['channel'] ?? '') as String;
      final isVideo = (data['isVideo'] ?? 'false').toString() == 'true';
      final fromName = (data['fromName'] ?? 'Caller') as String;
      final payload = 'incoming_call|$channel|$isVideo|$fromName';

      if (showLocal) {
        await _local.show(
          0,
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
                AndroidNotificationAction('ACCEPT_CALL', 'Accept', showsUserInterface: true),
                AndroidNotificationAction('DECLINE_CALL', 'Decline', showsUserInterface: false, cancelNotification: true),
              ],
            ),
            iOS: const DarwinNotificationDetails(
              categoryIdentifier: 'INCOMING_CALL',
            ),
          ),
          payload: payload,
        );
      } else {
        final nav = navigatorKey?.currentState;
        if (nav != null) {
          nav.push(MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => IncomingCallScreen(
              channel: channel,
              isVideo: isVideo,
              fromName: fromName,
            ),
          ));
        }
      }
      return;
    }

    // CHAT MESSAGE
    if (data['type'] == 'chat_message') {
      final otherUserId = (data['otherUserId'] ?? '') as String;

      if (CurrentChat.otherUserId == otherUserId) return;

      final systemAlreadyShowing = message.notification != null;

      if (showLocal && !systemAlreadyShowing) {
        await _local.show(
          2,
          message.notification?.title ?? 'New Message',
          message.notification?.body ?? '',
          NotificationDetails(
            android: const AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              importance: Importance.max, priority: Priority.high,
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

    // Generic
    if (showLocal && message.notification != null) {
      await _local.show(
        3,
        message.notification?.title ?? 'Notification',
        message.notification?.body ?? '',
        NotificationDetails(
          android: const AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            importance: Importance.max, priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    }
  }

  void _pushCallScreen({required String channel, required bool isVideo, required String fromName}) {
    final nav = navigatorKey?.currentState;
    if (nav == null) return;
    nav.push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AgoraCallScreen(
        channelName: channel,
        isVideo: isVideo,
        otherUserName: fromName,
      ),
    ));
  }

  void _openChat(String otherUserId) {
    final nav = navigatorKey?.currentState;
    if (nav == null || otherUserId.isEmpty) return;
    nav.push(MaterialPageRoute(builder: (_) => ChatScreen(otherUserId: otherUserId)));
  }
}
