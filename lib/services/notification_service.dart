import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../screens/call/agora_call_screen.dart';
import '../screens/call/incoming_call_screen.dart';
import '../screens/chat/chat_screen.dart';
import 'current_chat.dart'; // used to suppress chat banners when already in that chat

class NotificationService {
  NotificationService({this.navigatorKey});

  final GlobalKey<NavigatorState>? navigatorKey;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Used for important notifications.',
    importance: Importance.max,
  );

  Future<void> initialize() async {
    // Ask permission
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('❌ Notification permission not granted');
      return;
    }

    // iOS: show banners even when app is foregrounded
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // iOS categories for action buttons on local notifs
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
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: iosInit,
    );

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) async {
        final payload = resp.payload ?? '';
        final actionId = resp.actionId; // 'ACCEPT_CALL', 'DECLINE_CALL', or ''

        // Local call notification actions
        if (payload.startsWith('incoming_call|')) {
          final parts = payload.split('|'); // incoming_call|channel|isVideo|fromName
          if (parts.length >= 4) {
            final channel = parts[1];
            final isVideo = parts[2] == 'true';
            final fromName = parts[3];

            if (actionId == 'DECLINE_CALL') {
              debugPrint('📞 Call declined (local action)');
              return;
            }
            _pushCallScreen(channel: channel, isVideo: isVideo, fromName: fromName);
            return;
          }
        }

        // Local chat notification tap
        if (payload.startsWith('open_chat|')) {
          final otherUserId = payload.split('|').elementAt(1);
          _openChat(otherUserId);
        }
      },
    );

    // Android channel
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // FCM listeners
    FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) => _handleMessage(message, showLocal: true),
    );
    FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) => _handleMessage(message, showLocal: false),
    );

    // If app was launched from a terminated push
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      await _handleMessage(initial, showLocal: false);
    }

    // iOS: ensure APNs token (stabilizes FCM delivery)
    String? apnsToken;
    int retries = 0;
    while (apnsToken == null && retries < 10) {
      apnsToken = await _fcm.getAPNSToken();
      await Future.delayed(const Duration(milliseconds: 300));
      retries++;
    }

    // Save FCM token to user doc
    final fcmToken = await _fcm.getToken();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && fcmToken != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'fcmToken': fcmToken,
          'fcmTokens': FieldValue.arrayUnion([fcmToken]),
        },
        SetOptions(merge: true),
      );
    }

    // Token refresh
    _fcm.onTokenRefresh.listen((newToken) async {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set(
          {
            'fcmToken': newToken,
            'fcmTokens': FieldValue.arrayUnion([newToken]),
          },
          SetOptions(merge: true),
        );
      }
    });
  }

  Future<void> _handleMessage(RemoteMessage message, {required bool showLocal}) async {
    final data = message.data;

    // ===== CALL INVITE =====
    final isCallInvite =
        (data['type'] == 'call_invite') || (data['action'] == 'incoming_call');

    if (isCallInvite) {
      final channel = (data['channel'] ?? '') as String;
      final isVideo = (data['isVideo'] ?? 'false').toString() == 'true';
      final fromName = (data['fromName'] ?? 'Caller') as String;
      final payload = 'incoming_call|$channel|$isVideo|$fromName';

      if (showLocal) {
        // App in foreground → show local with actions
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
                AndroidNotificationAction(
                  'DECLINE_CALL',
                  'Decline',
                  showsUserInterface: false,
                  cancelNotification: true,
                ),
              ],
            ),
            iOS: DarwinNotificationDetails(
              categoryIdentifier: 'INCOMING_CALL',
            ),
          ),
          payload: payload,
        );
      } else {
        // Tapped the system banner (background/terminated) → show Accept/Decline screen
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

    // ===== CHAT MESSAGE =====
    if (data['type'] == 'chat_message') {
      // IMPORTANT: Cloud Function should include otherUserId (the *sender* id relative to the current user)
      final otherUserId = (data['otherUserId'] ?? '') as String;

      // 🔕 Suppress banner if we’re already viewing that chat
      if (CurrentChat.otherUserId == otherUserId) return;

      // If the FCM already includes a system notification, don’t show a duplicate local banner.
      final systemAlreadyShowing = message.notification != null;

      if (showLocal && !systemAlreadyShowing) {
        await _local.show(
          2,
          message.notification?.title ?? 'New Message',
          message.notification?.body ?? '',
          NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          payload: 'open_chat|$otherUserId',
        );
      } else if (!showLocal) {
        _openChat(otherUserId);
      }
      return;
    }

    // ===== Generic fallback =====
    if (showLocal && message.notification != null) {
      await _local.show(
        3,
        message.notification?.title ?? 'Notification',
        message.notification?.body ?? '',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }
  }

  void _pushCallScreen({
    required String channel,
    required bool isVideo,
    required String fromName,
  }) {
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
