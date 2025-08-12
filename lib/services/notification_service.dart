import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../screens/call/agora_call_screen.dart';
import '../screens/chat/chat_screen.dart'; // <-- make sure this path is correct

class NotificationService {
  NotificationService({this.navigatorKey});

  final GlobalKey<NavigatorState>? navigatorKey;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  // Android channel
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
      alert: true, badge: true, sound: true, provisional: false,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('❌ Notification permission not granted');
      return;
    }
    debugPrint('✅ Notifications are enabled');

    // iOS: show notifications while app is foregrounded
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );

    // iOS categories (for action buttons)
    const iosSettings = DarwinInitializationSettings(
      notificationCategories: [
        DarwinNotificationCategory(
          'INCOMING_CALL',
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain('ACCEPT_CALL', 'Accept'),
            DarwinNotificationAction.plain(
              'DECLINE_CALL', 'Decline',
              options: {DarwinNotificationActionOption.destructive},
            ),
          ],
          options: {DarwinNotificationCategoryOption.customDismissAction},
        ),
      ],
    );

    // Init local notifications
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: iosSettings,
    );

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) async {
        final payload = resp.payload ?? '';
        final actionId = resp.actionId; // 'ACCEPT_CALL', 'DECLINE_CALL', or ''

        // Accept/Decline (local)
        if (payload.startsWith('incoming_call|')) {
          final parts = payload.split('|'); // incoming_call|channel|isVideo|fromName
          if (parts.length >= 4) {
            final channel = parts[1];
            final isVideo = parts[2] == 'true';
            final fromName = parts[3];

            if (actionId == 'DECLINE_CALL') {
              debugPrint('📞 Call declined');
              return;
            }
            _pushCallScreen(channel: channel, isVideo: isVideo, fromName: fromName);
            return;
          }
        }

        // Open chat from local notif
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

    // Foreground message → show local or route immediately
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await _handleMessage(message, showLocal: true);
    });

    // Background tap → open directly
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      await _handleMessage(message, showLocal: false);
    });

    // Terminated tap → open directly
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      await _handleMessage(initial, showLocal: false);
    }

    // Ensure APNs token on iOS
    String? apnsToken;
    int retries = 0;
    while (apnsToken == null && retries < 10) {
      apnsToken = await _fcm.getAPNSToken();
      await Future.delayed(const Duration(milliseconds: 300));
      retries++;
    }

    // Save FCM token
    final fcmToken = await _fcm.getToken();
    debugPrint('🔥 FCM Token: $fcmToken');
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && fcmToken != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'fcmToken': fcmToken,
          'fcmTokens': FieldValue.arrayUnion([fcmToken]),
        },
        SetOptions(merge: true),
      );
      debugPrint('✅ Token saved to Firestore for ${user.uid}');
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
        debugPrint('🔄 Token refreshed for ${currentUser.uid}');
      }
    });
  }

  Future<void> _handleMessage(RemoteMessage message, {required bool showLocal}) async {
    final data = message.data;
    final isCallInvite =
        (data['type'] == 'call_invite') || (data['action'] == 'incoming_call');

    if (isCallInvite) {
      final channel = (data['channel'] ?? '') as String;
      final isVideo = (data['isVideo'] ?? 'false').toString() == 'true';
      final fromName = (data['fromName'] ?? 'Caller') as String;
      final payload = 'incoming_call|$channel|$isVideo|$fromName';

      if (showLocal) {
        // Foreground: local notif with actions
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
                const AndroidNotificationAction(
                  'ACCEPT_CALL', 'Accept', showsUserInterface: true,
                ),
                const AndroidNotificationAction(
                  'DECLINE_CALL', 'Decline',
                  showsUserInterface: false, cancelNotification: true,
                ),
              ],
            ),
            iOS: const DarwinNotificationDetails(
              categoryIdentifier: 'INCOMING_CALL',
            ),
          ),
          payload: payload,
        );
      } else {
        _pushCallScreen(channel: channel, isVideo: isVideo, fromName: fromName);
      }
      return;
    }

    // Chat messages (from Cloud Function)
    if (data['type'] == 'chat_message') {
      final otherUserId = (data['otherUserId'] ?? '') as String;

      if (showLocal) {
        await _local.show(
          2,
          message.notification?.title ?? 'New Message',
          message.notification?.body ?? '',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel', 'High Importance Notifications',
              importance: Importance.max, priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          payload: 'open_chat|$otherUserId',
        );
      } else {
        _openChat(otherUserId);
      }
      return;
    }

    // Generic fallback
    if (showLocal && message.notification != null) {
      await _local.show(
        3,
        message.notification?.title ?? 'Notification',
        message.notification?.body ?? '',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', 'High Importance Notifications',
            importance: Importance.max, priority: Priority.high,
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
    nav.push(MaterialPageRoute(
      builder: (_) => ChatScreen(otherUserId: otherUserId),
    ));
  }
}
