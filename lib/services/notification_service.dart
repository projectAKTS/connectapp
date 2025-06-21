import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // 1️⃣ Request notification permissions
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print("✅ Notifications are enabled");
    } else {
      print("❌ Notification permission not granted");
      return;
    }

    // 2️⃣ Initialize local notifications (Android + iOS)
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: iosSettings,
    );
    await _localNotificationsPlugin.initialize(initSettings);

    // 3️⃣ Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showNotification(message);
    });

    // 4️⃣ Handle background tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("🔔 Notification opened: ${message.data}");
    });

    // 5️⃣ 🔐 Wait for APNs token before getting FCM token
    String? apnsToken;
    int retries = 0;
    while (apnsToken == null && retries < 10) {
      apnsToken = await _firebaseMessaging.getAPNSToken();
      await Future.delayed(const Duration(milliseconds: 300));
      retries++;
    }

    if (apnsToken == null) {
      print("❌ APNs token not available after retries.");
      return;
    }

    // 6️⃣ Get FCM token
    final fcmToken = await _firebaseMessaging.getToken();
    print("🔥 FCM Token: $fcmToken");

    // 7️⃣ Update Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && fcmToken != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'fcmToken': fcmToken,
      });
      print("✅ Token saved to Firestore for ${user.uid}");
    } else {
      print("⚠️ User not logged in, token not saved.");
    }

    // 8️⃣ Handle token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({'fcmToken': newToken});
        print("🔄 Token refreshed for ${currentUser.uid}");
      }
    });
  }

  Future<void> _showNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
    );
    const platformDetails = NotificationDetails(android: androidDetails);

    await _localNotificationsPlugin.show(
      0,
      message.notification?.title ?? 'New Notification',
      message.notification?.body ?? 'You have a new message',
      platformDetails,
    );
  }
}
